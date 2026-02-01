//
//  NearbySearchService.swift
//  LocationKit
//
//  Service for searching nearby places using MapKit
//

import Foundation
import CoreLocation
import MapKit

// MARK: - NearbySearchService

/// Service for searching nearby places and address completions
/// Uses MapKit's MKLocalSearch for POI and address search functionality
public final class NearbySearchService: @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = NearbySearchService()
    
    // MARK: - Cache Properties
    
    /// Cache for nearby search results
    private var nearbyCache: [String: CachedNearbyResult] = [:]
    
    /// Cache lock for thread safety
    private let cacheLock = NSLock()
    
    /// Cache TTL in seconds (15 minutes)
    private let cacheTTL: TimeInterval = 15 * 60
    
    // MARK: - Search Completer
    
    /// Search completer for address autocomplete
    private var searchCompleter: MKLocalSearchCompleter?
    
    /// Completer delegate wrapper
    private var completerDelegate: SearchCompleterDelegate?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public API: Nearby Search
    
    /// Search for nearby places/POIs
    /// - Parameters:
    ///   - center: Search center coordinate
    ///   - radius: Search radius in meters (default: 500)
    ///   - keyword: Search keyword (e.g., "restaurant", "cafe")
    ///   - limit: Maximum number of results (default: 20)
    ///   - useCache: Whether to use cached results (default: true)
    /// - Returns: Array of nearby places sorted by distance
    public func searchNearby(
        center: CLLocationCoordinate2D,
        radius: Double = 500,
        keyword: String? = nil,
        limit: Int = 20,
        useCache: Bool = true
    ) async throws -> [NearbyPlace] {
        
        // Validate parameters
        guard CLLocationCoordinate2DIsValid(center) else {
            throw NearbySearchError.invalidParameters(reason: "Invalid coordinate")
        }
        
        guard radius > 0 && radius <= 50000 else {
            throw NearbySearchError.invalidParameters(reason: "Radius must be between 0 and 50000 meters")
        }
        
        let effectiveKeyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = generateCacheKey(center: center, radius: radius, keyword: effectiveKeyword)
        
        // Check cache
        if useCache, let cachedResult = getCachedResult(for: cacheKey) {
            print("🔍 [NearbySearch] Cache HIT for key: \(cacheKey)")
            return Array(cachedResult.places.prefix(limit))
        }
        
        print("🔍 [NearbySearch] Searching - Center: \(center.latitude), \(center.longitude), Radius: \(radius)m, Keyword: \(effectiveKeyword ?? "nil")")
        
        // Perform search
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let mapItems = try await performLocalSearch(
            center: center,
            radius: radius,
            keyword: effectiveKeyword
        )
        
        // Convert to NearbyPlace
        var places = mapItems.map { NearbyPlace.from(mapItem: $0, centerLocation: centerLocation) }
        
        // Sort by distance
        places.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
        
        // Cache results
        if useCache {
            cacheResult(places: places, for: cacheKey)
        }
        
        print("🔍 [NearbySearch] Found \(places.count) places")
        return Array(places.prefix(limit))
    }
    
    /// Search for nearby places with result wrapper
    /// - Parameters:
    ///   - center: Search center coordinate
    ///   - radius: Search radius in meters
    ///   - keyword: Search keyword
    ///   - limit: Maximum number of results
    ///   - useCache: Whether to use cached results
    /// - Returns: Search result with metadata
    public func searchNearbyWithResult(
        center: CLLocationCoordinate2D,
        radius: Double = 500,
        keyword: String? = nil,
        limit: Int = 20,
        useCache: Bool = true
    ) async throws -> NearbySearchResult {
        
        let cacheKey = generateCacheKey(center: center, radius: radius, keyword: keyword)
        let isFromCache = useCache && hasCachedResult(for: cacheKey)
        
        let places = try await searchNearby(
            center: center,
            radius: radius,
            keyword: keyword,
            limit: limit,
            useCache: useCache
        )
        
        return NearbySearchResult(
            places: places,
            isFromCache: isFromCache,
            searchCenter: CLLocation(latitude: center.latitude, longitude: center.longitude),
            searchRadius: radius,
            keyword: keyword
        )
    }
    
    // MARK: - Public API: Address Completion
    
    /// Search for address completions (autocomplete)
    /// - Parameters:
    ///   - query: User input query string
    ///   - region: Optional region to bias results
    /// - Returns: Array of address completions
    public func searchAddressCompletions(
        query: String,
        region: MKCoordinateRegion? = nil
    ) async throws -> [AddressCompletion] {
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            return []
        }
        
        print("🔍 [AddressCompletion] Searching for: \(trimmedQuery)")
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create new completer
            let completer = MKLocalSearchCompleter()
            completer.queryFragment = trimmedQuery
            
            if #available(iOS 13.0, *) {
                completer.resultTypes = [.address, .pointOfInterest]
            }
            
            if let region = region {
                completer.region = region
            }
            
            // Create delegate
            let delegate = SearchCompleterDelegate { result in
                switch result {
                case .success(let completions):
                    let addressCompletions = completions.map { AddressCompletion.from(completion: $0) }
                    print("🔍 [AddressCompletion] Found \(addressCompletions.count) completions")
                    continuation.resume(returning: addressCompletions)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Store references to prevent deallocation
            self.searchCompleter = completer
            self.completerDelegate = delegate
            completer.delegate = delegate
        }
    }
    
    /// Get place details from address completion
    /// - Parameter completion: The address completion to get details for
    /// - Returns: NearbyPlace with full details
    public func getPlaceDetails(from completion: AddressCompletion) async throws -> NearbyPlace? {
        guard let searchCompletion = completion.searchCompletion else {
            return nil
        }
        
        let request = MKLocalSearch.Request(completion: searchCompletion)
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                return NearbyPlace.from(mapItem: mapItem, centerLocation: nil)
            }
            return nil
        } catch {
            throw NearbySearchError.searchFailed(underlying: error.localizedDescription)
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear the nearby search cache
    public func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        nearbyCache.removeAll()
        print("🗑️ [NearbySearch] Cache cleared")
    }
    
    /// Get cache statistics
    public var cacheStats: (count: Int, oldestAge: TimeInterval?) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard !nearbyCache.isEmpty else {
            return (0, nil)
        }
        
        let oldest = nearbyCache.values.min { $0.timestamp < $1.timestamp }
        let oldestAge = oldest.map { Date().timeIntervalSince($0.timestamp) }
        
        return (nearbyCache.count, oldestAge)
    }
    
    // MARK: - Private: MKLocalSearch
    
    private func performLocalSearch(
        center: CLLocationCoordinate2D,
        radius: Double,
        keyword: String?
    ) async throws -> [MKMapItem] {
        
        let request = MKLocalSearch.Request()
        
        // Set search region
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        // Set result types
        if #available(iOS 13.0, *) {
            request.resultTypes = .pointOfInterest
        }
        
        // Set natural language query
        // Default to general POI search if no keyword
        request.naturalLanguageQuery = keyword ?? "point of interest"
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems
        } catch let error as MKError {
            switch error.code {
            case .placemarkNotFound:
                throw NearbySearchError.noResults
            case .serverFailure:
                throw NearbySearchError.searchFailed(underlying: "Server error")
            case .loadingThrottled:
                throw NearbySearchError.rateLimited
            case .directionsNotFound:
                throw NearbySearchError.noResults
            default:
                throw NearbySearchError.searchFailed(underlying: error.localizedDescription)
            }
        } catch {
            throw NearbySearchError.searchFailed(underlying: error.localizedDescription)
        }
    }
    
    // MARK: - Private: Cache
    
    private func generateCacheKey(
        center: CLLocationCoordinate2D,
        radius: Double,
        keyword: String?
    ) -> String {
        // Round coordinates to reduce cache fragmentation
        let lat = String(format: "%.4f", center.latitude)
        let lon = String(format: "%.4f", center.longitude)
        let rad = Int(radius)
        let kw = keyword?.lowercased() ?? "default"
        return "\(lat),\(lon)_\(rad)_\(kw)"
    }
    
    private func getCachedResult(for key: String) -> CachedNearbyResult? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cached = nearbyCache[key] else {
            return nil
        }
        
        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > cacheTTL {
            nearbyCache.removeValue(forKey: key)
            return nil
        }
        
        return cached
    }
    
    private func hasCachedResult(for key: String) -> Bool {
        getCachedResult(for: key) != nil
    }
    
    private func cacheResult(places: [NearbyPlace], for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        nearbyCache[key] = CachedNearbyResult(
            places: places,
            timestamp: Date()
        )
        
        // Cleanup old cache entries (keep max 50)
        if nearbyCache.count > 50 {
            cleanupOldCacheEntries()
        }
    }
    
    private func cleanupOldCacheEntries() {
        // Remove entries older than TTL
        let now = Date()
        nearbyCache = nearbyCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) < cacheTTL
        }
        
        // If still too many, remove oldest
        if nearbyCache.count > 50 {
            let sorted = nearbyCache.sorted { $0.value.timestamp > $1.value.timestamp }
            nearbyCache = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(50)))
        }
    }
}

// MARK: - Cache Model

private struct CachedNearbyResult {
    let places: [NearbyPlace]
    let timestamp: Date
}

// MARK: - Search Completer Delegate

private final class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    
    private let completion: (Result<[MKLocalSearchCompletion], Error>) -> Void
    private var hasCompleted = false
    
    init(completion: @escaping (Result<[MKLocalSearchCompletion], Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(.success(completer.results))
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        if let mkError = error as? MKError {
            switch mkError.code {
            case .placemarkNotFound:
                completion(.success([]))
            default:
                completion(.failure(NearbySearchError.searchFailed(underlying: error.localizedDescription)))
            }
        } else {
            completion(.failure(NearbySearchError.searchFailed(underlying: error.localizedDescription)))
        }
    }
}