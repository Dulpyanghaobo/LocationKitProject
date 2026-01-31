//
//  AltitudeService.swift
//  LocationKit
//
//  Service for altitude-related operations
//

import Foundation
import Combine
import CoreLocation

// MARK: - AltitudeService

/// Service for altitude-related operations
/// Provides altitude data from GPS with formatting utilities
public final class AltitudeService: AltitudeServiceProtocol {
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = AltitudeService()
    
    // MARK: - Private Properties
    
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private let altitudeSubject = PassthroughSubject<Double, Never>()
    
    // MARK: - Public Properties
    
    /// Current altitude from GPS (in meters)
    public var currentAltitude: Double? {
        locationManager.altitude
    }
    
    /// Publisher for altitude updates
    public var altitudePublisher: AnyPublisher<Double, Never> {
        altitudeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(locationManager: LocationManager = .shared) {
        self.locationManager = locationManager
        setupAltitudeUpdates()
    }
    
    private func setupAltitudeUpdates() {
        locationManager.locationPublisher
            .compactMap { $0.altitude }
            .sink { [weak self] altitude in
                self?.altitudeSubject.send(altitude)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - AltitudeServiceProtocol
    
    /// Format altitude for display
    public func formatAltitude(_ altitude: Double, unit: AltitudeUnit) -> String {
        let convertedValue = unit.convert(meters: altitude)
        return String(format: "%.1f %@", convertedValue, unit.symbol)
    }
    
    // MARK: - Convenience Methods
    
    /// Get current altitude formatted
    public func getCurrentAltitudeFormatted(unit: AltitudeUnit = .meters) -> String? {
        guard let altitude = currentAltitude else { return nil }
        return formatAltitude(altitude, unit: unit)
    }
    
    /// Get altitude with precision
    public func formatAltitude(_ altitude: Double, unit: AltitudeUnit, precision: Int) -> String {
        let convertedValue = unit.convert(meters: altitude)
        let format = "%.\(precision)f %@"
        return String(format: format, convertedValue, unit.symbol)
    }
    
    /// Get altitude as integer
    public func formatAltitudeRounded(_ altitude: Double, unit: AltitudeUnit) -> String {
        let convertedValue = unit.convert(meters: altitude)
        return "\(Int(convertedValue.rounded())) \(unit.symbol)"
    }
    
    /// Check if altitude data is reliable
    public func isAltitudeReliable(location: CLLocation) -> Bool {
        // Vertical accuracy should be positive and reasonably low
        return location.verticalAccuracy >= 0 && location.verticalAccuracy < 50
    }
    
    /// Get altitude relative to sea level description
    public func getAltitudeDescription(_ altitude: Double) -> String {
        if altitude > 2500 {
            return "High altitude"
        } else if altitude > 1000 {
            return "Mountain"
        } else if altitude > 500 {
            return "Hills"
        } else if altitude > 100 {
            return "Above sea level"
        } else if altitude > 0 {
            return "Near sea level"
        } else {
            return "Below sea level"
        }
    }
}

// MARK: - AltitudeUnit Extension

public extension AltitudeUnit {
    
    /// Get user's preferred altitude unit based on locale
    static var preferred: AltitudeUnit {
        // US, UK, and a few other countries use feet
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == .metric
        return usesMetric ? .meters : .feet
    }
    
    /// Convert from this unit back to meters
    func toMeters(from value: Double) -> Double {
        switch self {
        case .meters:
            return value
        case .feet:
            return value / 3.28084
        }
    }
}