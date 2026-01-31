//
//  LocationManager.swift
//  LocationKit
//
//  Core location manager implementation
//

import Foundation
import Combine
import CoreLocation
import UIKit

// MARK: - LocationManager

/// Core location manager that wraps CLLocationManager
/// Provides a modern, protocol-based interface with Combine support
public final class LocationManager: NSObject, LocationKitServiceProtocol {
    
    // MARK: - Singleton
    
    /// Shared instance for convenience
    public static let shared = LocationManager()
    
    // MARK: - Private Properties
    
    private let clLocationManager = CLLocationManager()
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let authorizationSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    private let errorSubject = PassthroughSubject<LocationKitError, Never>()
    
    private var currentLocation: CLLocation?
    private var configuration: LocationConfiguration
    
    // MARK: - Public Properties (LocationServiceProtocol)
    
    public var coordinate: CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }
    
    public var altitude: Double? {
        currentLocation?.altitude
    }
    
    public var horizontalAccuracy: Double? {
        currentLocation?.horizontalAccuracy
    }
    
    public var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Additional Publishers
    
    /// Publisher for authorization status changes
    public var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for errors
    public var errorPublisher: AnyPublisher<LocationKitError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    /// Current authorization status
    public var authorizationStatus: CLAuthorizationStatus {
        clLocationManager.authorizationStatus
    }
    
    /// Check if location services are enabled
    public var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }
    
    /// Current location (if available)
    public var location: CLLocation? {
        currentLocation
    }
    
    /// Weak delegate for callback-style usage
    public weak var delegate: LocationKitDelegate?
    
    // MARK: - Initialization
    
    /// Initialize with default configuration
    public override init() {
        self.configuration = .default
        super.init()
        setupLocationManager()
    }
    
    /// Initialize with custom configuration
    public init(configuration: LocationConfiguration) {
        self.configuration = configuration
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        clLocationManager.delegate = self
        applyConfiguration(configuration)
    }
    
    // MARK: - Configuration
    
    /// Update configuration
    public func configure(_ configuration: LocationConfiguration) {
        self.configuration = configuration
        applyConfiguration(configuration)
    }
    
    private func applyConfiguration(_ config: LocationConfiguration) {
        clLocationManager.desiredAccuracy = config.desiredAccuracy
        clLocationManager.distanceFilter = config.distanceFilter
        clLocationManager.activityType = config.activityType
        clLocationManager.pausesLocationUpdatesAutomatically = config.pausesLocationUpdatesAutomatically
        
        if config.allowsBackgroundUpdates {
            clLocationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    // MARK: - LocationServiceProtocol Methods
    
    /// Request a single location update
    public func requestLocationUpdate() {
        guard checkAuthorization() else { return }
        clLocationManager.requestLocation()
    }
    
    /// Start continuous location updates
    public func startUpdatingLocation() {
        guard checkAuthorization() else { return }
        clLocationManager.startUpdatingLocation()
    }
    
    /// Stop continuous location updates
    public func stopUpdatingLocation() {
        clLocationManager.stopUpdatingLocation()
    }
    
    // MARK: - Permission Methods
    
    /// Request when-in-use authorization
    public func requestWhenInUseAuthorization() {
        clLocationManager.requestWhenInUseAuthorization()
    }
    
    /// Request always authorization
    public func requestAlwaysAuthorization() {
        clLocationManager.requestAlwaysAuthorization()
    }
    
    /// Check if app has required authorization
    public func hasRequiredAuthorization(minimum: CLAuthorizationStatus = .authorizedWhenInUse) -> Bool {
        let status = authorizationStatus
        switch minimum {
        case .authorizedWhenInUse:
            return status == .authorizedWhenInUse || status == .authorizedAlways
        case .authorizedAlways:
            return status == .authorizedAlways
        default:
            return false
        }
    }
    
    // MARK: - Async Methods
    
    /// Get current location asynchronously
    public func getCurrentLocation() async throws -> CLLocation {
        // Check authorization first
        guard isLocationServicesEnabled else {
            throw LocationKitError.locationServicesDisabled
        }
        
        if let error = LocationKitError.from(authorizationStatus) {
            throw error
        }
        
        // If we have a recent location, return it
        if let location = currentLocation,
           Date().timeIntervalSince(location.timestamp) < 30 {
            return location
        }
        
        // Otherwise, request a new one
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var errorCancellable: AnyCancellable?
            var isCompleted = false
            
            errorCancellable = errorPublisher
                .first()
                .sink { error in
                    guard !isCompleted else { return }
                    isCompleted = true
                    cancellable?.cancel()
                    errorCancellable?.cancel()
                    continuation.resume(throwing: error)
                }
            
            cancellable = locationSubject
                .first()
                .timeout(.seconds(30), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        guard !isCompleted else { return }
                        isCompleted = true
                        errorCancellable?.cancel()
                        if case .failure = completion {
                            continuation.resume(throwing: LocationKitError.timeout)
                        }
                    },
                    receiveValue: { location in
                        guard !isCompleted else { return }
                        isCompleted = true
                        errorCancellable?.cancel()
                        cancellable?.cancel()
                        continuation.resume(returning: location)
                    }
                )
            
            self.requestLocationUpdate()
        }
    }
    
    /// Request permission and wait for result
    public func requestPermission(type: AuthorizationType = .whenInUse) async -> CLAuthorizationStatus {
        // If already determined, return current status
        if authorizationStatus != .notDetermined {
            return authorizationStatus
        }
        
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = authorizationSubject
                .first()
                .sink { status in
                    cancellable?.cancel()
                    continuation.resume(returning: status)
                }
            
            switch type {
            case .whenInUse:
                requestWhenInUseAuthorization()
            case .always:
                requestAlwaysAuthorization()
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func checkAuthorization() -> Bool {
        guard isLocationServicesEnabled else {
            errorSubject.send(.locationServicesDisabled)
            delegate?.locationKit(didFailWithError: .locationServicesDisabled)
            return false
        }
        
        if let error = LocationKitError.from(authorizationStatus) {
            errorSubject.send(error)
            delegate?.locationKit(didFailWithError: error)
            return false
        }
        
        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        locationSubject.send(location)
        delegate?.locationKit(didUpdateLocation: location)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError: LocationKitError
        
        if let clError = error as? CLError {
            locationError = .from(clError)
        } else {
            locationError = .unknown(error)
        }
        
        errorSubject.send(locationError)
        delegate?.locationKit(didFailWithError: locationError)
        
        print("⚠️ LocationManager didFailWithError: \(error.localizedDescription)")
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationSubject.send(status)
        delegate?.locationKit(didChangeAuthorization: status)
    }
}

// MARK: - Supporting Types

public enum AuthorizationType {
    case whenInUse
    case always
}

// MARK: - LocationManager + Convenience

public extension LocationManager {
    
    /// Quick check if location permission is granted
    var isAuthorized: Bool {
        let status = authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    /// Open app settings for location permission
    static func openAppSettings() {
        guard let url = URL(string: UIApplicationOpenSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    /// Get formatted coordinate string
    var coordinateString: String? {
        guard let coord = coordinate else { return nil }
        return String(format: "%.6f, %.6f", coord.latitude, coord.longitude)
    }
    
    /// Get formatted altitude string
    func formattedAltitude(unit: AltitudeUnit = .meters) -> String? {
        guard let alt = altitude else { return nil }
        let value = unit.convert(meters: alt)
        return String(format: "%.1f %@", value, unit.symbol)
    }
}
