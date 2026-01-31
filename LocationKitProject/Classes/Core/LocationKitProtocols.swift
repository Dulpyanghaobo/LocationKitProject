//
//  LocationKitProtocols.swift
//  LocationKit
//
//  Core protocols for LocationKit component
//  Designed for reusability across different iOS projects
//

import Foundation
import Combine
import CoreLocation

// MARK: - Location Service Protocol

/// Core protocol for location services
/// Provides basic location functionality with Combine support
public protocol LocationKitServiceProtocol: AnyObject {
    /// Current coordinate (latitude/longitude)
    var coordinate: CLLocationCoordinate2D? { get }
    
    /// Current altitude in meters
    var altitude: Double? { get }
    
    /// Current location accuracy
    var horizontalAccuracy: Double? { get }
    
    /// Publisher that emits when location updates
    var locationPublisher: AnyPublisher<CLLocation, Never> { get }
    
    /// Request a single location update
    func requestLocationUpdate()
    
    /// Start continuous location updates
    func startUpdatingLocation()
    
    /// Stop continuous location updates
    func stopUpdatingLocation()
}

// MARK: - Geocoding Service Protocol

/// Protocol for geocoding operations (address <-> coordinates)
public protocol GeocodingServiceProtocol {
    /// Reverse geocode: coordinates -> address
    func reverseGeocode(location: CLLocation) async throws -> GeocodedAddress
    
    /// Reverse geocode: coordinates -> address with preferred locale
    func reverseGeocode(location: CLLocation, locale: Locale?) async throws -> GeocodedAddress
    
    /// Forward geocode: address string -> coordinates
    func geocode(addressString: String) async throws -> [CLLocation]
    
    /// Forward geocode with region hint
    func geocode(addressString: String, in region: CLRegion?) async throws -> [CLLocation]
}

// MARK: - Altitude Service Protocol

/// Protocol for altitude-related operations
public protocol AltitudeServiceProtocol {
    /// Get current altitude from GPS
    var currentAltitude: Double? { get }
    
    /// Publisher for altitude updates
    var altitudePublisher: AnyPublisher<Double, Never> { get }
    
    /// Format altitude for display
    func formatAltitude(_ altitude: Double, unit: AltitudeUnit) -> String
}

/// Altitude unit options
public enum AltitudeUnit {
    case meters
    case feet
    
    public var symbol: String {
        switch self {
        case .meters: return "m"
        case .feet: return "ft"
        }
    }
    
    public func convert(meters: Double) -> Double {
        switch self {
        case .meters: return meters
        case .feet: return meters * 3.28084
        }
    }
}

// MARK: - Permission Manager Protocol

/// Protocol for managing location permissions
public protocol LocationPermissionManagerProtocol {
    /// Current authorization status
    var authorizationStatus: CLAuthorizationStatus { get }
    
    /// Publisher for authorization status changes
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    
    /// Check if location services are enabled on device
    var isLocationServicesEnabled: Bool { get }
    
    /// Request when-in-use authorization
    func requestWhenInUseAuthorization()
    
    /// Request always authorization (for background updates)
    func requestAlwaysAuthorization()
}

// MARK: - Distance Calculator Protocol

/// Protocol for distance calculations
public protocol DistanceCalculatorProtocol {
    /// Calculate distance between two locations
    func distance(from: CLLocation, to: CLLocation) -> CLLocationDistance
    
    /// Calculate distance between two coordinates
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance
    
    /// Check if two locations are within a certain distance
    func isWithinDistance(_ distance: CLLocationDistance, from: CLLocation, to: CLLocation) -> Bool
    
    /// Format distance for display
    func formatDistance(_ distance: CLLocationDistance, unit: DistanceUnit) -> String
}

/// Distance unit options
public enum DistanceUnit {
    case meters
    case kilometers
    case miles
    case feet
    
    public var symbol: String {
        switch self {
        case .meters: return "m"
        case .kilometers: return "km"
        case .miles: return "mi"
        case .feet: return "ft"
        }
    }
}

// MARK: - Location Manager Delegate Protocol

/// Delegate protocol for location manager events
public protocol LocationKitDelegate: AnyObject {
    /// Called when location is updated
    func locationKit(didUpdateLocation location: CLLocation)
    
    /// Called when authorization status changes
    func locationKit(didChangeAuthorization status: CLAuthorizationStatus)
    
    /// Called when an error occurs
    func locationKit(didFailWithError error: LocationKitError)
}

// MARK: - Optional delegate methods (via extension)

public extension LocationKitDelegate {
    func locationKit(didUpdateLocation location: CLLocation) {}
    func locationKit(didChangeAuthorization status: CLAuthorizationStatus) {}
    func locationKit(didFailWithError error: LocationKitError) {}
}
