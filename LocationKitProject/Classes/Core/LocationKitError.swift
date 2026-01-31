//
//  LocationKitError.swift
//  LocationKit
//
//  Error types for LocationKit component
//

import Foundation
import CoreLocation

// MARK: - LocationKit Error

/// Comprehensive error type for LocationKit operations
public enum LocationKitError: LocalizedError, Equatable {
    
    // MARK: - Permission Errors
    
    /// Location services are disabled on device
    case locationServicesDisabled
    
    /// Authorization denied by user
    case authorizationDenied
    
    /// Authorization restricted (parental controls, MDM, etc.)
    case authorizationRestricted
    
    /// Authorization not determined yet
    case authorizationNotDetermined
    
    // MARK: - Location Errors
    
    /// Failed to get location
    case locationUnavailable
    
    /// Location accuracy is too low
    case lowAccuracy(accuracy: Double)
    
    /// Location request timed out
    case timeout
    
    /// Location is stale (too old)
    case staleLocation(age: TimeInterval)
    
    // MARK: - Geocoding Errors
    
    /// Geocoding failed with no results
    case geocodingNoResults
    
    /// Geocoding failed with error
    case geocodingFailed(Error)
    
    /// Geocoding rate limited (too many requests)
    case geocodingRateLimited
    
    /// Invalid address string
    case invalidAddress
    
    // MARK: - Region Monitoring Errors
    
    /// Region monitoring not supported
    case regionMonitoringNotSupported
    
    /// Maximum number of monitored regions reached
    case regionMonitoringLimitReached
    
    /// Failed to monitor region
    case regionMonitoringFailed(identifier: String)
    
    // MARK: - General Errors
    
    /// Unknown error
    case unknown(Error)
    
    /// Custom error with message
    case custom(String)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location services are disabled. Please enable them in Settings."
        case .authorizationDenied:
            return "Location access was denied. Please grant permission in Settings."
        case .authorizationRestricted:
            return "Location access is restricted on this device."
        case .authorizationNotDetermined:
            return "Location permission has not been requested yet."
        case .locationUnavailable:
            return "Unable to determine your location."
        case .lowAccuracy(let accuracy):
            return "Location accuracy is too low (\(Int(accuracy))m)."
        case .timeout:
            return "Location request timed out."
        case .staleLocation(let age):
            return "Location is outdated (\(Int(age))s old)."
        case .geocodingNoResults:
            return "No address found for this location."
        case .geocodingFailed(let error):
            return "Failed to get address: \(error.localizedDescription)"
        case .geocodingRateLimited:
            return "Too many address requests. Please try again later."
        case .invalidAddress:
            return "The provided address is invalid."
        case .regionMonitoringNotSupported:
            return "Region monitoring is not supported on this device."
        case .regionMonitoringLimitReached:
            return "Maximum number of monitored regions reached."
        case .regionMonitoringFailed(let identifier):
            return "Failed to monitor region: \(identifier)"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        case .custom(let message):
            return message
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location services are turned off in device settings."
        case .authorizationDenied:
            return "User denied location permission."
        case .authorizationRestricted:
            return "Parental controls or device management policy restricts location access."
        case .timeout:
            return "The location request took too long to complete."
        case .geocodingRateLimited:
            return "Apple's geocoding service has a rate limit."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .locationServicesDisabled:
            return "Go to Settings > Privacy > Location Services and turn them on."
        case .authorizationDenied:
            return "Go to Settings > Privacy > Location Services > [App Name] and select 'While Using' or 'Always'."
        case .authorizationNotDetermined:
            return "Please tap 'Allow' when prompted for location access."
        case .timeout:
            return "Try again in an area with better GPS signal."
        case .geocodingRateLimited:
            return "Wait a few seconds before trying again."
        default:
            return nil
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: LocationKitError, rhs: LocationKitError) -> Bool {
        switch (lhs, rhs) {
        case (.locationServicesDisabled, .locationServicesDisabled),
             (.authorizationDenied, .authorizationDenied),
             (.authorizationRestricted, .authorizationRestricted),
             (.authorizationNotDetermined, .authorizationNotDetermined),
             (.locationUnavailable, .locationUnavailable),
             (.timeout, .timeout),
             (.geocodingNoResults, .geocodingNoResults),
             (.geocodingRateLimited, .geocodingRateLimited),
             (.invalidAddress, .invalidAddress),
             (.regionMonitoringNotSupported, .regionMonitoringNotSupported),
             (.regionMonitoringLimitReached, .regionMonitoringLimitReached):
            return true
        case (.lowAccuracy(let a1), .lowAccuracy(let a2)):
            return a1 == a2
        case (.staleLocation(let a1), .staleLocation(let a2)):
            return a1 == a2
        case (.regionMonitoringFailed(let i1), .regionMonitoringFailed(let i2)):
            return i1 == i2
        case (.custom(let m1), .custom(let m2)):
            return m1 == m2
        case (.geocodingFailed(let e1), .geocodingFailed(let e2)):
            return e1.localizedDescription == e2.localizedDescription
        case (.unknown(let e1), .unknown(let e2)):
            return e1.localizedDescription == e2.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Error Conversion

public extension LocationKitError {
    /// Create error from CLError
    static func from(_ clError: CLError) -> LocationKitError {
        switch clError.code {
        case .locationUnknown:
            return .locationUnavailable
        case .denied:
            return .authorizationDenied
        case .network:
            return .geocodingFailed(clError)
        case .geocodeFoundNoResult:
            return .geocodingNoResults
        case .geocodeFoundPartialResult:
            return .geocodingNoResults
        case .geocodeCanceled:
            return .custom("Geocoding was cancelled")
        case .regionMonitoringDenied:
            return .authorizationDenied
        case .regionMonitoringFailure:
            return .regionMonitoringFailed(identifier: "unknown")
        case .regionMonitoringSetupDelayed:
            return .regionMonitoringFailed(identifier: "delayed")
        case .regionMonitoringResponseDelayed:
            return .regionMonitoringFailed(identifier: "response_delayed")
        default:
            return .unknown(clError)
        }
    }
    
    /// Create error from authorization status
    static func from(_ status: CLAuthorizationStatus) -> LocationKitError? {
        switch status {
        case .notDetermined:
            return .authorizationNotDetermined
        case .restricted:
            return .authorizationRestricted
        case .denied:
            return .authorizationDenied
        case .authorizedAlways, .authorizedWhenInUse:
            return nil
        @unknown default:
            return .unknown(NSError(domain: "LocationKit", code: -1))
        }
    }
}

// MARK: - Error Helper Extensions

public extension Error {
    /// Convert any error to LocationKitError
    var asLocationKitError: LocationKitError {
        if let locationError = self as? LocationKitError {
            return locationError
        }
        if let clError = self as? CLError {
            return .from(clError)
        }
        return .unknown(self)
    }
}