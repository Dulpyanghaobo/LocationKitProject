//
//  GeocodingService.swift
//  LocationKit
//
//  Geocoding service for address <-> coordinate conversion
//

import Foundation
import CoreLocation

// MARK: - GeocodingService

/// Service for geocoding operations (address <-> coordinate conversion)
/// Uses Apple's CLGeocoder with caching support
public final class GeocodingService: GeocodingServiceProtocol {
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = GeocodingService()
    
    // MARK: - Private Properties
    
    private let geocoder = CLGeocoder()
    
    // Cache for reverse geocoding results
    private var reverseGeocodeCache: [String: CacheEntry<GeocodedAddress>] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 hour
    private let cacheQueue = DispatchQueue(label: "com.locationkit.geocoding.cache")
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - GeocodingServiceProtocol
    
    /// Reverse geocode: coordinates -> address
    public func reverseGeocode(location: CLLocation) async throws -> GeocodedAddress {
        try await reverseGeocode(location: location, locale: nil)
    }
    
    /// Reverse geocode: coordinates -> address with preferred locale
    public func reverseGeocode(location: CLLocation, locale: Locale?) async throws -> GeocodedAddress {
        let cacheKey = generateCacheKey(for: location, locale: locale)
        
        // Check cache
        if let cached = getCachedAddress(for: cacheKey) {
            return cached
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        // Perform geocoding
        do {
            let placemarks: [CLPlacemark]
            
            if let locale = locale {
                placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
            } else {
                placemarks = try await geocoder.reverseGeocodeLocation(location)
            }
            
            guard let placemark = placemarks.first else {
                throw LocationKitError.geocodingNoResults
            }
            
            let address = GeocodedAddress(from: placemark)
            
            // Cache the result
            cacheAddress(address, for: cacheKey)
            
            return address
        } catch let error as CLError {
            throw LocationKitError.from(error)
        } catch let error as LocationKitError {
            throw error
        } catch {
            throw LocationKitError.geocodingFailed(error)
        }
    }
    
    /// Forward geocode: address string -> coordinates
    public func geocode(addressString: String) async throws -> [CLLocation] {
        try await geocode(addressString: addressString, in: nil)
    }
    
    /// Forward geocode with region hint
    public func geocode(addressString: String, in region: CLRegion?) async throws -> [CLLocation] {
        guard !addressString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationKitError.invalidAddress
        }
        
        // Rate limiting
        try await enforceRateLimit()
        
        do {
            let placemarks: [CLPlacemark]
            
            if let region = region {
                placemarks = try await geocoder.geocodeAddressString(addressString, in: region)
            } else {
                placemarks = try await geocoder.geocodeAddressString(addressString)
            }
            
            let locations = placemarks.compactMap { $0.location }
            
            if locations.isEmpty {
                throw LocationKitError.geocodingNoResults
            }
            
            return locations
        } catch let error as CLError {
            throw LocationKitError.from(error)
        } catch let error as LocationKitError {
            throw error
        } catch {
            throw LocationKitError.geocodingFailed(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Get city name from location
    public func getCityName(for location: CLLocation) async throws -> String {
        let address = try await reverseGeocode(location: location)
        return address.cityName ?? ""
    }
    
    /// Get short address (landmark + city) from location
    public func getShortAddress(for location: CLLocation) async throws -> String {
        let address = try await reverseGeocode(location: location)
        return address.shortAddress
    }
    
    /// Get full address from location
    public func getFullAddress(for location: CLLocation) async throws -> String {
        let address = try await reverseGeocode(location: location)
        return address.formattedAddress
    }
    
    /// Get address components with Chinese locale
    public func getChineseAddress(for location: CLLocation) async throws -> GeocodedAddress {
        try await reverseGeocode(location: location, locale: Locale(identifier: "zh-Hans"))
    }
    
    /// Cancel any ongoing geocoding requests
    public func cancelGeocoding() {
        geocoder.cancelGeocode()
    }
    
    /// Check if geocoding is in progress
    public var isGeocoding: Bool {
        geocoder.isGeocoding
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached addresses
    public func clearCache() {
        cacheQueue.async { [weak self] in
            self?.reverseGeocodeCache.removeAll()
        }
    }
    
    /// Remove expired cache entries
    public func cleanupCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            self.reverseGeocodeCache = self.reverseGeocodeCache.filter { _, entry in
                now.timeIntervalSince(entry.timestamp) < self.cacheTTL
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func generateCacheKey(for location: CLLocation, locale: Locale?) -> String {
        let localeId = locale?.identifier ?? "default"
        // Round to 5 decimal places (~1m precision)
        return String(format: "%.5f,%.5f_%@", location.coordinate.latitude, location.coordinate.longitude, localeId)
    }
    
    private func getCachedAddress(for key: String) -> GeocodedAddress? {
        cacheQueue.sync {
            guard let entry = reverseGeocodeCache[key] else { return nil }
            
            // Check if expired
            if Date().timeIntervalSince(entry.timestamp) > cacheTTL {
                reverseGeocodeCache.removeValue(forKey: key)
                return nil
            }
            
            return entry.value
        }
    }
    
    private func cacheAddress(_ address: GeocodedAddress, for key: String) {
        cacheQueue.async { [weak self] in
            self?.reverseGeocodeCache[key] = CacheEntry(value: address, timestamp: Date())
        }
    }
    
    private func enforceRateLimit() async throws {
        let now = Date()
        
        if let lastRequest = lastRequestTime {
            let elapsed = now.timeIntervalSince(lastRequest)
            if elapsed < minRequestInterval {
                let delay = minRequestInterval - elapsed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        lastRequestTime = Date()
    }
}

// MARK: - Cache Entry

private struct CacheEntry<T> {
    let value: T
    let timestamp: Date
}

// MARK: - GeocodedAddress Extension

public extension GeocodedAddress {
    
    /// Create a Chinese-formatted address string
    var chineseFormattedAddress: String {
        // Chinese addresses are typically: Province City District Street Number
        let components = [
            administrativeArea,
            locality,
            subLocality,
            thoroughfare,
            subThoroughfare
        ].compactMap { $0 }
        
        return components.joined()
    }
    
    /// Get address suitable for display on watermark
    func watermarkDisplayAddress(style: AddressDisplayStyle = .short) -> String {
        switch style {
        case .short:
            return shortAddress
        case .cityOnly:
            return cityName ?? ""
        case .landmark:
            return areasOfInterest?.first ?? name ?? shortAddress
        case .full:
            return formattedAddress
        }
    }
}

/// Style for displaying address
public enum AddressDisplayStyle {
    case short      // Landmark + City
    case cityOnly   // Just the city
    case landmark   // Just the landmark/POI
    case full       // Full formatted address
}