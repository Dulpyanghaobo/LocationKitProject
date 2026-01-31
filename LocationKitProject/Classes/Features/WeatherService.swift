//
//  WeatherService.swift
//  LocationKit
//
//  Weather service layer with WeatherKit integration
//  Provides protocol-based abstraction for testability
//

import Foundation
import CoreLocation

// MARK: - Weather Service Protocol

/// Protocol defining weather service capabilities
/// Enables dependency injection and testability
public protocol WeatherServiceProtocol: Sendable {
    /// Fetch current weather for a given location
    /// - Parameter location: The location to fetch weather for
    /// - Returns: WeatherInfo with current conditions and attribution
    /// - Throws: Error if weather data cannot be fetched
    func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherInfo
}

// MARK: - Weather Service Error

/// Errors that can occur during weather fetching
public enum WeatherServiceError: Error, LocalizedError {
    case notAvailable
    case locationInvalid
    case networkError(underlying: Error)
    case unauthorized
    case rateLimited
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "WeatherKit is not available on this device"
        case .locationInvalid:
            return "Invalid location provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "WeatherKit authorization failed. Check your App ID configuration."
        case .rateLimited:
            return "WeatherKit rate limit exceeded"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Apple Weather Service (Real Implementation)

#if canImport(WeatherKit)
import WeatherKit

/// Real WeatherKit implementation
/// Uses Apple's WeatherKit framework to fetch live weather data
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public final class AppleWeatherService: WeatherServiceProtocol, @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// Shared instance for production use
    public static let shared = AppleWeatherService()
    
    // MARK: - Properties
    
    /// WeatherKit service instance
    private let weatherService = WeatherService.shared
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - WeatherServiceProtocol
    
    public func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherInfo {
        do {
            // Fetch current weather
            let currentWeather = try await weatherService.weather(for: location, including: .current)
            
            // Fetch attribution separately
            let attribution = try await weatherService.attribution
            
            // Map WeatherKit condition to our model
            let condition = mapCondition(currentWeather.condition)
            let iconName = mapIconName(currentWeather.symbolName)
            
            // Convert temperature to Celsius
            let temperatureCelsius = currentWeather.temperature.converted(to: UnitTemperature.celsius).value
            
            // Get humidity as percentage (0-100)
            let humidity = Int(currentWeather.humidity * 100)
            
            // Extract attribution URLs (required by WeatherKit TOS)
            let attributionURL = attribution.legalPageURL
            let attributionLogoURL = attribution.combinedMarkDarkURL
            
            print("🌤️ [WeatherKit] Fetched: \(condition), \(String(format: "%.1f", temperatureCelsius))°C, \(humidity)% humidity")
            
            return WeatherInfo(
                condition: condition,
                temperature: temperatureCelsius,
                humidity: humidity,
                iconName: iconName,
                attributionURL: attributionURL,
                attributionLogoURL: attributionLogoURL
            )
            
        } catch let error as WeatherError {
            throw mapWeatherKitError(error)
        } catch {
            throw WeatherServiceError.unknown(underlying: error)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Map WeatherKit condition to localized string
    private func mapCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return "Clear"
        case .mostlyClear:
            return "Mostly Clear"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .mostlyCloudy:
            return "Mostly Cloudy"
        case .cloudy:
            return "Cloudy"
        case .rain:
            return "Rain"
        case .heavyRain:
            return "Heavy Rain"
        case .drizzle:
            return "Drizzle"
        case .snow:
            return "Snow"
        case .heavySnow:
            return "Heavy Snow"
        case .sleet:
            return "Sleet"
        case .freezingRain:
            return "Freezing Rain"
        case .thunderstorms:
            return "Thunderstorms"
        case .strongStorms:
            return "Strong Storms"
        case .windy:
            return "Windy"
        case .foggy:
            return "Foggy"
        case .haze:
            return "Haze"
        case .hot:
            return "Hot"
        case .frigid:
            return "Frigid"
        case .blowingDust:
            return "Blowing Dust"
        case .tropicalStorm:
            return "Tropical Storm"
        case .hurricane:
            return "Hurricane"
        case .sunShowers:
            return "Sun Showers"
        case .flurries:
            return "Flurries"
        case .blizzard:
            return "Blizzard"
        case .blowingSnow:
            return "Blowing Snow"
        case .freezingDrizzle:
            return "Freezing Drizzle"
        case .scatteredThunderstorms:
            return "Scattered Thunderstorms"
        case .isolatedThunderstorms:
            return "Isolated Thunderstorms"
        case .smoky:
            return "Smoky"
        case .breezy:
            return "Breezy"
        case .wintryMix:
            return "Wintry Mix"
        case .hail:
            return "Hail"
        case .sunFlurries:
            return "Sun Flurries"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Map WeatherKit symbol name to SF Symbol
    /// WeatherKit already provides SF Symbol names, but we can customize if needed
    private func mapIconName(_ symbolName: String) -> String {
        // WeatherKit provides SF Symbol names directly
        // We can add custom mapping here if needed
        return symbolName
    }
    
    /// Map WeatherKit errors to our error type
    private func mapWeatherKitError(_ error: WeatherError) -> WeatherServiceError {
        // WeatherError cases vary by iOS version, use a general approach
        let errorDescription = String(describing: error).lowercased()
        
        if errorDescription.contains("network") {
            return .networkError(underlying: error)
        } else if errorDescription.contains("location") {
            return .locationInvalid
        } else if errorDescription.contains("permission") || errorDescription.contains("unauthorized") {
            return .unauthorized
        } else {
            return .unknown(underlying: error)
        }
    }
}

#endif

// MARK: - Mock Weather Service (For Testing)

/// Mock weather service for testing and simulator use
public actor MockWeatherService: WeatherServiceProtocol {
    
    // MARK: - Configuration
    
    /// Simulated delay range (min, max) in seconds
    public var delayRange: ClosedRange<Double> = 0.5...4.0
    
    /// Whether to simulate random failures
    public var simulateFailures: Bool = false
    
    /// Failure probability (0.0 - 1.0)
    public var failureProbability: Double = 0.2
    
    // MARK: - Initialization
    
    public init() {}
    
    /// Initialize with custom configuration
    public init(delayRange: ClosedRange<Double>, simulateFailures: Bool = false) {
        self.delayRange = delayRange
        self.simulateFailures = simulateFailures
    }
    
    // MARK: - WeatherServiceProtocol
    
    public func fetchCurrentWeather(for location: CLLocation) async throws -> WeatherInfo {
        // Simulate network delay
        let delay = Double.random(in: delayRange)
        print("🌤️ [MockWeather] Request started (delay: \(String(format: "%.1f", delay))s)")
        
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Simulate random failures if enabled
        if simulateFailures && Double.random(in: 0...1) < failureProbability {
            throw WeatherServiceError.networkError(underlying: NSError(
                domain: "MockWeatherService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated network failure"]
            ))
        }
        
        // Generate random weather
        let conditions: [(String, String, Double)] = [
            ("Sunny", "sun.max.fill", 25.0),
            ("Cloudy", "cloud.fill", 20.0),
            ("Partly Cloudy", "cloud.sun.fill", 22.0),
            ("Rainy", "cloud.rain.fill", 18.0),
            ("Windy", "wind", 16.0),
            ("Thunderstorms", "cloud.bolt.rain.fill", 15.0),
            ("Snow", "snowflake", 0.0),
            ("Foggy", "cloud.fog.fill", 12.0)
        ]
        
        let selected = conditions.randomElement()!
        let temperature = selected.2 + Double.random(in: -5...5)
        let humidity = Int.random(in: 40...80)
        
        let weather = WeatherInfo(
            condition: selected.0,
            temperature: temperature,
            humidity: humidity,
            iconName: selected.1,
            attributionURL: URL(string: "https://weather.apple.com/legal"),
            attributionLogoURL: URL(string: "https://weather.apple.com/assets/attribution/combined-mark-dark.png")
        )
        
        print("🌤️ [MockWeather] Completed: \(weather.displayString)")
        return weather
    }
}

// MARK: - Weather Service Factory

/// Factory for creating weather service instances
public enum WeatherServiceFactory {
    
    /// Create the appropriate weather service based on environment
    /// - Parameter forceMock: Force use of mock service (for testing)
    /// - Returns: A weather service instance
    public static func createService(forceMock: Bool = false) -> any WeatherServiceProtocol {
        #if targetEnvironment(simulator)
        // Always use mock on simulator (WeatherKit requires entitlements)
        print("🌤️ [WeatherService] Using MockWeatherService (Simulator)")
        return MockWeatherService()
        #else
        if forceMock {
            print("🌤️ [WeatherService] Using MockWeatherService (Forced)")
            return MockWeatherService()
        }
        
        #if canImport(WeatherKit)
        if #available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *) {
            print("🌤️ [WeatherService] Using AppleWeatherService")
            return AppleWeatherService.shared
        }
        #endif
        
        // Fallback for older iOS versions
        print("🌤️ [WeatherService] Using MockWeatherService (Fallback)")
        return MockWeatherService()
        #endif
    }
}
