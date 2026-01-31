//
//  LocationModels.swift
//  LocationKit
//
//  Data models for LocationKit component
//

import Foundation
import CoreLocation

// MARK: - Geocoded Address

/// Structured address data from reverse geocoding
public struct GeocodedAddress: Equatable, Sendable {
    /// Full formatted address string
    public let formattedAddress: String
    
    /// Country name
    public let country: String?
    
    /// Country code (ISO 3166-1 alpha-2)
    public let countryCode: String?
    
    /// Administrative area (state/province)
    public let administrativeArea: String?
    
    /// Sub-administrative area (county)
    public let subAdministrativeArea: String?
    
    /// Locality (city/town)
    public let locality: String?
    
    /// Sub-locality (district/neighborhood)
    public let subLocality: String?
    
    /// Street name
    public let thoroughfare: String?
    
    /// Street number
    public let subThoroughfare: String?
    
    /// Postal code
    public let postalCode: String?
    
    /// Areas of interest (landmarks, etc.)
    public let areasOfInterest: [String]?
    
    /// Original placemark name
    public let name: String?
    
    /// Location coordinate
    public let coordinate: CLLocationCoordinate2D?
    
    /// Initialize with all fields
    public init(
        formattedAddress: String,
        country: String? = nil,
        countryCode: String? = nil,
        administrativeArea: String? = nil,
        subAdministrativeArea: String? = nil,
        locality: String? = nil,
        subLocality: String? = nil,
        thoroughfare: String? = nil,
        subThoroughfare: String? = nil,
        postalCode: String? = nil,
        areasOfInterest: [String]? = nil,
        name: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil
    ) {
        self.formattedAddress = formattedAddress
        self.country = country
        self.countryCode = countryCode
        self.administrativeArea = administrativeArea
        self.subAdministrativeArea = subAdministrativeArea
        self.locality = locality
        self.subLocality = subLocality
        self.thoroughfare = thoroughfare
        self.subThoroughfare = subThoroughfare
        self.postalCode = postalCode
        self.areasOfInterest = areasOfInterest
        self.name = name
        self.coordinate = coordinate
    }
    
    /// Initialize from CLPlacemark
    public init(from placemark: CLPlacemark) {
        // Build formatted address
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country
        ].compactMap { $0 }
        
        self.formattedAddress = components.joined(separator: ", ")
        self.country = placemark.country
        self.countryCode = placemark.isoCountryCode
        self.administrativeArea = placemark.administrativeArea
        self.subAdministrativeArea = placemark.subAdministrativeArea
        self.locality = placemark.locality
        self.subLocality = placemark.subLocality
        self.thoroughfare = placemark.thoroughfare
        self.subThoroughfare = placemark.subThoroughfare
        self.postalCode = placemark.postalCode
        self.areasOfInterest = placemark.areasOfInterest
        self.name = placemark.name
        self.coordinate = placemark.location?.coordinate
    }
    
    /// Get city name (locality or administrative area as fallback)
    public var cityName: String? {
        locality ?? administrativeArea
    }
    
    /// Get short address (landmark + city)
    public var shortAddress: String {
        let landmark = areasOfInterest?.first ?? name ?? ""
        let city = cityName ?? ""
        return [landmark, city]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
    
    /// Get street address
    public var streetAddress: String? {
        guard let thoroughfare = thoroughfare else { return nil }
        if let number = subThoroughfare {
            return "\(number) \(thoroughfare)"
        }
        return thoroughfare
    }
}

// MARK: - Location Data

/// Wrapper for location data with additional metadata
public struct LocationData: Equatable, Sendable {
    /// The CLLocation coordinate
    public let coordinate: CLLocationCoordinate2D
    
    /// Altitude in meters
    public let altitude: Double
    
    /// Horizontal accuracy in meters
    public let horizontalAccuracy: Double
    
    /// Vertical accuracy in meters
    public let verticalAccuracy: Double
    
    /// Timestamp of the location reading
    public let timestamp: Date
    
    /// Speed in meters per second (-1 if invalid)
    public let speed: Double
    
    /// Course/heading in degrees (0-360, -1 if invalid)
    public let course: Double
    
    /// Floor level (if available)
    public let floor: Int?
    
    /// Initialize from CLLocation
    public init(from location: CLLocation) {
        self.coordinate = location.coordinate
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.timestamp = location.timestamp
        self.speed = location.speed
        self.course = location.course
        self.floor = location.floor?.level
    }
    
    /// Initialize with all fields
    public init(
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 0,
        horizontalAccuracy: Double = 0,
        verticalAccuracy: Double = 0,
        timestamp: Date = Date(),
        speed: Double = -1,
        course: Double = -1,
        floor: Int? = nil
    ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
        self.floor = floor
    }
    
    /// Convert to CLLocation
    public func toCLLocation() -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp
        )
    }
    
    /// Check if location is valid (has reasonable accuracy)
    public var isValid: Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy < 1000
    }
    
    /// Check if altitude is valid
    public var isAltitudeValid: Bool {
        verticalAccuracy >= 0 && verticalAccuracy < 100
    }
}

// MARK: - Location Configuration

/// Configuration options for location services
public struct LocationConfiguration: Equatable, Sendable {
    /// Desired accuracy level
    public let desiredAccuracy: CLLocationAccuracy
    
    /// Distance filter for updates (in meters)
    public let distanceFilter: CLLocationDistance
    
    /// Activity type for power optimization
    public let activityType: CLActivityType
    
    /// Whether to allow background updates
    public let allowsBackgroundUpdates: Bool
    
    /// Whether to pause updates automatically
    public let pausesLocationUpdatesAutomatically: Bool
    
    /// Default configuration for general use
    public static let `default` = LocationConfiguration(
        desiredAccuracy: kCLLocationAccuracyBest,
        distanceFilter: kCLDistanceFilterNone,
        activityType: .other,
        allowsBackgroundUpdates: false,
        pausesLocationUpdatesAutomatically: true
    )
    
    /// High accuracy configuration (for navigation)
    public static let highAccuracy = LocationConfiguration(
        desiredAccuracy: kCLLocationAccuracyBestForNavigation,
        distanceFilter: 5,
        activityType: .automotiveNavigation,
        allowsBackgroundUpdates: true,
        pausesLocationUpdatesAutomatically: false
    )
    
    /// Low power configuration (for general tracking)
    public static let lowPower = LocationConfiguration(
        desiredAccuracy: kCLLocationAccuracyHundredMeters,
        distanceFilter: 100,
        activityType: .other,
        allowsBackgroundUpdates: false,
        pausesLocationUpdatesAutomatically: true
    )
    
    /// City-level accuracy configuration
    public static let cityLevel = LocationConfiguration(
        desiredAccuracy: kCLLocationAccuracyKilometer,
        distanceFilter: 1000,
        activityType: .other,
        allowsBackgroundUpdates: false,
        pausesLocationUpdatesAutomatically: true
    )
    
    public init(
        desiredAccuracy: CLLocationAccuracy,
        distanceFilter: CLLocationDistance,
        activityType: CLActivityType,
        allowsBackgroundUpdates: Bool,
        pausesLocationUpdatesAutomatically: Bool
    ) {
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
        self.activityType = activityType
        self.allowsBackgroundUpdates = allowsBackgroundUpdates
        self.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
    }
}

// MARK: - Location Region

/// Wrapper for monitoring circular regions
public struct LocationRegion: Equatable, Identifiable, Sendable {
    public let id: String
    public let center: CLLocationCoordinate2D
    public let radius: CLLocationDistance
    public let notifyOnEntry: Bool
    public let notifyOnExit: Bool
    
    public init(
        id: String,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = true
    ) {
        self.id = id
        self.center = center
        self.radius = radius
        self.notifyOnEntry = notifyOnEntry
        self.notifyOnExit = notifyOnExit
    }
    
    /// Convert to CLCircularRegion
    public func toCLRegion() -> CLCircularRegion {
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        return region
    }
}

// MARK: - CLLocationCoordinate2D Equatable

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - CLActivityType Sendable

extension CLActivityType: @unchecked @retroactive Sendable {}