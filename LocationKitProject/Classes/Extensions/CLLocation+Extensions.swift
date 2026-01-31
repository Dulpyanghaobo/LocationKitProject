//
//  CLLocation+Extensions.swift
//  LocationKit
//
//  Convenient extensions for CLLocation and related types
//

import Foundation
import CoreLocation

// MARK: - CLLocation Extensions

public extension CLLocation {
    
    /// Check if location is valid (has reasonable accuracy)
    var isValid: Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy < 1000
    }
    
    /// Check if altitude data is valid
    var isAltitudeValid: Bool {
        verticalAccuracy >= 0 && verticalAccuracy < 100
    }
    
    /// Check if location is recent (within specified seconds)
    func isRecent(within seconds: TimeInterval = 60) -> Bool {
        Date().timeIntervalSince(timestamp) < seconds
    }
    
    /// Get age of location in seconds
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    /// Convert to LocationData
    func toLocationData() -> LocationData {
        LocationData(from: self)
    }
    
    /// Get formatted coordinate string
    var coordinateString: String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
    
    /// Get formatted coordinate string with direction
    var coordinateStringWithDirection: String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.4f°%@ %.4f°%@",
                      abs(coordinate.latitude), latDirection,
                      abs(coordinate.longitude), lonDirection)
    }
    
    /// Get formatted altitude string
    func formattedAltitude(unit: AltitudeUnit = .meters, precision: Int = 1) -> String {
        let value = unit.convert(meters: altitude)
        let format = "%.\(precision)f %@"
        return String(format: format, value, unit.symbol)
    }
    
    /// Get formatted speed string
    func formattedSpeed() -> String? {
        guard speed >= 0 else { return nil }
        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }
    
    /// Get formatted course string
    func formattedCourse() -> String? {
        guard course >= 0 else { return nil }
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((course + 22.5).truncatingRemainder(dividingBy: 360) / 45.0)
        return String(format: "%.0f° (%@)", course, directions[index])
    }
    
    /// Calculate distance to another location
    func distanceTo(_ other: CLLocation) -> CLLocationDistance {
        distance(from: other)
    }
    
    /// Calculate distance to coordinate
    func distanceTo(_ coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return distance(from: otherLocation)
    }
}

// MARK: - CLLocationCoordinate2D Extensions

public extension CLLocationCoordinate2D {
    
    /// Check if coordinate is valid
    var isValid: Bool {
        CLLocationCoordinate2DIsValid(self)
    }
    
    /// Get formatted string
    var formatted: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
    
    /// Get formatted string with direction
    var formattedWithDirection: String {
        let latDirection = latitude >= 0 ? "N" : "S"
        let lonDirection = longitude >= 0 ? "E" : "W"
        return String(format: "%.4f°%@ %.4f°%@",
                      abs(latitude), latDirection,
                      abs(longitude), lonDirection)
    }
    
    /// Convert to CLLocation
    func toCLLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Calculate distance to another coordinate
    func distanceToCoordinate(_ other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
    
    /// Zero coordinate
    static var zero: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    /// Check if coordinate is zero (0, 0)
    var isZero: Bool {
        latitude == 0 && longitude == 0
    }
}

// MARK: - CLAuthorizationStatus Extensions

public extension CLAuthorizationStatus {
    
    /// Check if authorized
    var isAuthorized: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
    
    /// Human-readable description
    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Icon name for status
    var iconName: String {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        case .notDetermined:
            return "location"
        @unknown default:
            return "location"
        }
    }
}

// MARK: - CLLocationAccuracy Presets

public extension CLLocationAccuracy {
    
    /// Best for navigation (highest accuracy, highest power)
    static let navigation = kCLLocationAccuracyBestForNavigation
    
    /// Best general accuracy
    static let best = kCLLocationAccuracyBest
    
    /// Within 10 meters
    static let nearestTenMeters = kCLLocationAccuracyNearestTenMeters
    
    /// Within 100 meters (good for city-level)
    static let hundredMeters = kCLLocationAccuracyHundredMeters
    
    /// Within 1 kilometer (low power)
    static let kilometer = kCLLocationAccuracyKilometer
    
    /// Within 3 kilometers (lowest power)
    static let threeKilometers = kCLLocationAccuracyThreeKilometers
    
    /// Reduced accuracy (iOS 14+, respects user's approximate location choice)
    @available(iOS 14.0, *)
    static let reduced = kCLLocationAccuracyReduced
}