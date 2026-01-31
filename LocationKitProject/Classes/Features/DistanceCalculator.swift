//
//  DistanceCalculator.swift
//  LocationKit
//
//  Service for distance calculations between locations
//

import Foundation
import CoreLocation

// MARK: - DistanceCalculator

/// Utility for calculating and formatting distances between locations
public struct DistanceCalculator: DistanceCalculatorProtocol {
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = DistanceCalculator()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - DistanceCalculatorProtocol
    
    /// Calculate distance between two locations (in meters)
    public func distance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        from.distance(from: to)
    }
    
    /// Calculate distance between two coordinates (in meters)
    public func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// Check if two locations are within a certain distance
    public func isWithinDistance(_ distance: CLLocationDistance, from: CLLocation, to: CLLocation) -> Bool {
        self.distance(from: from, to: to) <= distance
    }
    
    /// Format distance for display
    public func formatDistance(_ distance: CLLocationDistance, unit: DistanceUnit) -> String {
        let convertedValue = convert(meters: distance, to: unit)
        
        switch unit {
        case .meters:
            return String(format: "%.0f %@", convertedValue, unit.symbol)
        case .kilometers:
            return String(format: "%.1f %@", convertedValue, unit.symbol)
        case .miles:
            return String(format: "%.1f %@", convertedValue, unit.symbol)
        case .feet:
            return String(format: "%.0f %@", convertedValue, unit.symbol)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Format distance with automatic unit selection
    public func formatDistanceAuto(_ distance: CLLocationDistance) -> String {
        let usesMetric = Locale.current.measurementSystem == .metric
        
        if usesMetric {
            if distance >= 1000 {
                return formatDistance(distance, unit: .kilometers)
            } else {
                return formatDistance(distance, unit: .meters)
            }
        } else {
            let miles = convert(meters: distance, to: .miles)
            if miles >= 0.1 {
                return formatDistance(distance, unit: .miles)
            } else {
                return formatDistance(distance, unit: .feet)
            }
        }
    }
    
    /// Convert meters to another unit
    public func convert(meters: Double, to unit: DistanceUnit) -> Double {
        switch unit {
        case .meters:
            return meters
        case .kilometers:
            return meters / 1000.0
        case .miles:
            return meters / 1609.344
        case .feet:
            return meters * 3.28084
        }
    }
    
    /// Convert from a unit back to meters
    public func convertToMeters(value: Double, from unit: DistanceUnit) -> Double {
        switch unit {
        case .meters:
            return value
        case .kilometers:
            return value * 1000.0
        case .miles:
            return value * 1609.344
        case .feet:
            return value / 3.28084
        }
    }
    
    /// Calculate bearing between two coordinates (in degrees, 0-360)
    public func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians
        let lon1 = from.longitude.toRadians
        let lat2 = to.latitude.toRadians
        let lon2 = to.longitude.toRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x).toDegrees
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        return bearing
    }
    
    /// Get compass direction from bearing
    public func compassDirection(from bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5).truncatingRemainder(dividingBy: 360) / 45.0)
        return directions[index]
    }
    
    /// Calculate intermediate point between two coordinates
    public func intermediatePoint(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let lat1 = from.latitude.toRadians
        let lon1 = from.longitude.toRadians
        let lat2 = to.latitude.toRadians
        let lon2 = to.longitude.toRadians
        
        let d = distance(from: from, to: to) / 6371000 // Earth radius in meters
        
        let a = sin((1 - fraction) * d) / sin(d)
        let b = sin(fraction * d) / sin(d)
        
        let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
        let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
        let z = a * sin(lat1) + b * sin(lat2)
        
        let lat = atan2(z, sqrt(x * x + y * y))
        let lon = atan2(y, x)
        
        return CLLocationCoordinate2D(latitude: lat.toDegrees, longitude: lon.toDegrees)
    }
}

// MARK: - DistanceUnit Extension

public extension DistanceUnit {
    
    /// Get user's preferred distance unit based on locale
    static var preferred: DistanceUnit {
        let usesMetric = Locale.current.measurementSystem == .metric
        return usesMetric ? .kilometers : .miles
    }
}

// MARK: - Double Extensions for Radians/Degrees

private extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}