//
//  NearbySearchModels.swift
//  LocationKit
//
//  Data models for nearby place search functionality
//

import Foundation
import CoreLocation
import MapKit

// MARK: - NearbyPlace

/// Nearby place/POI model
/// Represents a point of interest returned from nearby search
public struct NearbyPlace: Identifiable, Hashable, Sendable {
    
    /// Unique identifier
    public let id: UUID
    
    /// POI name (e.g., "Starbucks", "Apple Store")
    public let name: String
    
    /// Location coordinates
    public let location: CLLocation
    
    /// Distance from search center (meters)
    public let distance: Double?
    
    /// Full address string
    public let address: String?
    
    /// City name
    public let city: String?
    
    /// Street name
    public let street: String?
    
    /// POI category (e.g., "Restaurant", "Cafe")
    public let category: String?
    
    /// Phone number (if available)
    public let phoneNumber: String?
    
    /// Website URL (if available)
    public let url: URL?
    
    // MARK: - Computed Properties
    
    /// Formatted distance string (e.g., "500 m", "1.2 km")
    public var distanceString: String? {
        guard let d = distance else { return nil }
        if d < 1000 {
            return String(format: "%.0f m", d)
        } else {
            return String(format: "%.1f km", d / 1000)
        }
    }
    
    /// Coordinate for convenience
    public var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
    
    /// Combined address for display
    public var displayAddress: String {
        [street, city].compactMap { $0 }.joined(separator: ", ")
    }
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        name: String,
        location: CLLocation,
        distance: Double? = nil,
        address: String? = nil,
        city: String? = nil,
        street: String? = nil,
        category: String? = nil,
        phoneNumber: String? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.distance = distance
        self.address = address
        self.city = city
        self.street = street
        self.category = category
        self.phoneNumber = phoneNumber
        self.url = url
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: NearbyPlace, rhs: NearbyPlace) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - NearbyPlace + MKMapItem

extension NearbyPlace {
    
    /// Create NearbyPlace from MKMapItem
    /// - Parameters:
    ///   - mapItem: The MKMapItem from search results
    ///   - centerLocation: The search center location for distance calculation
    /// - Returns: NearbyPlace instance
    static func from(mapItem: MKMapItem, centerLocation: CLLocation?) -> NearbyPlace {
        let placemark = mapItem.placemark
        let placeLocation = placemark.location ?? CLLocation(
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
        
        // Calculate distance if center is provided
        let distance: Double?
        if let center = centerLocation {
            distance = placeLocation.distance(from: center)
        } else {
            distance = nil
        }
        
        // Build address components
        let addressParts = [
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ].compactMap { $0 }
        let fullAddress = addressParts.isEmpty ? nil : addressParts.joined(separator: " ")
        
        // Get category from point of interest category
        var categoryName: String? = nil
        if #available(iOS 13.0, *) {
            categoryName = mapItem.pointOfInterestCategory?.rawValue
                .replacingOccurrences(of: "MKPOICategory", with: "")
        }
        
        return NearbyPlace(
            name: mapItem.name ?? placemark.name ?? "Unknown",
            location: placeLocation,
            distance: distance,
            address: fullAddress,
            city: placemark.locality,
            street: placemark.thoroughfare,
            category: categoryName,
            phoneNumber: mapItem.phoneNumber,
            url: mapItem.url
        )
    }
}

// MARK: - AddressCompletion

/// Address search completion/suggestion model
/// Used for autocomplete functionality
public struct AddressCompletion: Identifiable, Hashable, Sendable {
    
    /// Unique identifier
    public let id: UUID
    
    /// Main title (e.g., "Apple Park")
    public let title: String
    
    /// Subtitle (e.g., "Cupertino, CA")
    public let subtitle: String?
    
    /// The underlying search completion (for further operations)
    internal let searchCompletion: MKLocalSearchCompletion?
    
    // MARK: - Computed Properties
    
    /// Combined full text for display
    public var fullText: String {
        [title, subtitle].compactMap { $0 }.joined(separator: ", ")
    }
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        searchCompletion: MKLocalSearchCompletion? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.searchCompletion = searchCompletion
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AddressCompletion, rhs: AddressCompletion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AddressCompletion + MKLocalSearchCompletion

extension AddressCompletion {
    
    /// Create AddressCompletion from MKLocalSearchCompletion
    static func from(completion: MKLocalSearchCompletion) -> AddressCompletion {
        AddressCompletion(
            title: completion.title,
            subtitle: completion.subtitle.isEmpty ? nil : completion.subtitle,
            searchCompletion: completion
        )
    }
}

// MARK: - NearbySearchError

/// Errors specific to nearby search operations
public enum NearbySearchError: LocalizedError, Equatable {
    
    /// Location is not available for search
    case locationUnavailable
    
    /// Search request failed
    case searchFailed(underlying: String)
    
    /// No results found
    case noResults
    
    /// Invalid search parameters
    case invalidParameters(reason: String)
    
    /// Search was cancelled
    case cancelled
    
    /// Rate limited by the service
    case rateLimited
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Location is not available for nearby search."
        case .searchFailed(let underlying):
            return "Search failed: \(underlying)"
        case .noResults:
            return "No places found nearby."
        case .invalidParameters(let reason):
            return "Invalid search parameters: \(reason)"
        case .cancelled:
            return "Search was cancelled."
        case .rateLimited:
            return "Too many search requests. Please try again later."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .locationUnavailable:
            return "Ensure location services are enabled and try again."
        case .noResults:
            return "Try a different search keyword or increase the search radius."
        case .rateLimited:
            return "Wait a few seconds before searching again."
        default:
            return nil
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: NearbySearchError, rhs: NearbySearchError) -> Bool {
        switch (lhs, rhs) {
        case (.locationUnavailable, .locationUnavailable),
             (.noResults, .noResults),
             (.cancelled, .cancelled),
             (.rateLimited, .rateLimited):
            return true
        case (.searchFailed(let l), .searchFailed(let r)):
            return l == r
        case (.invalidParameters(let l), .invalidParameters(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - NearbySearchResult

/// Result wrapper for nearby search operations
public struct NearbySearchResult: Sendable {
    
    /// List of found places
    public let places: [NearbyPlace]
    
    /// Whether results came from cache
    public let isFromCache: Bool
    
    /// Search center location used
    public let searchCenter: CLLocation
    
    /// Search radius used (meters)
    public let searchRadius: Double
    
    /// Keyword used for search (if any)
    public let keyword: String?
    
    /// Timestamp when search was performed
    public let timestamp: Date
    
    public init(
        places: [NearbyPlace],
        isFromCache: Bool = false,
        searchCenter: CLLocation,
        searchRadius: Double,
        keyword: String? = nil,
        timestamp: Date = Date()
    ) {
        self.places = places
        self.isFromCache = isFromCache
        self.searchCenter = searchCenter
        self.searchRadius = searchRadius
        self.keyword = keyword
        self.timestamp = timestamp
    }
}