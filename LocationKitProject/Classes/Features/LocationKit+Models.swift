//
//  LocationKit+Models.swift
//  LocationKit
//
//  Data models for LocationKit Facade layer
//  Designed for watermark camera and travel camera scenarios
//

import Foundation
import CoreLocation

// MARK: - Location Scene

/// Usage scenarios for camera location features
public enum LocationScene: String, CaseIterable, Sendable {
    /// Work mode - watermark camera (水印相机)
    /// Focus: accurate address for work check-in, timestamps
    case work
    
    /// Travel mode - travel camera (旅行相机)
    /// Focus: scenic spots, POI recommendations, weather
    case travel
    
    /// POI search keywords based on scene
    var poiKeywords: [String] {
        switch self {
        case .work:
            return ["office", "building", "company", "business"]
        case .travel:
            return ["scenic", "landmark", "restaurant", "attraction", "hotel"]
        }
    }
    
    /// Display name
    public var displayName: String {
        switch self {
        case .work:
            return "Work Mode"
        case .travel:
            return "Travel Mode"
        }
    }
}

// MARK: - Location Mode

/// Location accuracy modes
public enum LocationMode: String, CaseIterable, Sendable {
    /// Fast mode - prioritize speed over accuracy
    case fast
    
    /// Accurate mode - prioritize accuracy over speed
    case accurate
    
    /// Timeout duration for location request
    var timeout: TimeInterval {
        switch self {
        case .fast:
            return 5.0
        case .accurate:
            return 15.0
        }
    }
    
    /// Display name
    public var displayName: String {
        switch self {
        case .fast:
            return "Fast"
        case .accurate:
            return "Accurate"
        }
    }
}

// MARK: - Camera Location Context

/// Complete location context for camera watermark
/// Contains all information needed to display on photo watermark
public struct CameraLocationContext: Sendable {
    
    // MARK: - Display Data
    
    /// Formatted display data for UI
    public struct Display: Sendable, Equatable {
        /// Main title (e.g., "北京市朝阳区" or "Chaoyang District, Beijing")
        public let title: String
        
        /// Subtitle (e.g., "三里屯太古里" or street address)
        public let subtitle: String
        
        /// Weather string (e.g., "晴 25°C" or "Sunny 77°F")
        public let weatherStr: String
        
        /// Formatted time string (e.g., "2026-01-31 18:30:00")
        public var timeStr: String
        
        /// Altitude string (e.g., "50m" or "164ft")
        public let altitudeStr: String
        
        /// Coordinate string (e.g., "39.9042°N, 116.4074°E")
        public let coordinateStr: String
        
        public init(
            title: String,
            subtitle: String,
            weatherStr: String,
            timeStr: String,
            altitudeStr: String = "",
            coordinateStr: String = ""
        ) {
            self.title = title
            self.subtitle = subtitle
            self.weatherStr = weatherStr
            self.timeStr = timeStr
            self.altitudeStr = altitudeStr
            self.coordinateStr = coordinateStr
        }
    }
    
    // MARK: - Raw Data
    
    /// Raw data for advanced usage
    public struct Raw: Sendable {
        /// Original CLLocation
        public let location: CLLocation
        
        /// Geocoded address information
        public let address: GeocodedAddress?
        
        /// List of nearby POIs
        public let poiList: [POIItem]
        
        /// Timestamp when this context was created
        public var timestamp: Date
        
        /// Weather data
        public let weather: WeatherInfo?
        
        public init(
            location: CLLocation,
            address: GeocodedAddress? = nil,
            poiList: [POIItem] = [],
            timestamp: Date = Date(),
            weather: WeatherInfo? = nil
        ) {
            self.location = location
            self.address = address
            self.poiList = poiList
            self.timestamp = timestamp
            self.weather = weather
        }
    }
    
    // MARK: - Flags
    
    /// Status flags for debugging and analytics
    public struct Flags: Sendable, Equatable {
        /// Whether this context was loaded from cache
        public var isCache: Bool
        
        /// Whether mock data was used (for testing/demo)
        public let isMock: Bool
        
        /// Whether weather data timed out
        public let weatherTimedOut: Bool
        
        /// Scene used for this request
        public let scene: LocationScene
        
        /// Mode used for this request
        public let mode: LocationMode
        
        public init(
            isCache: Bool = false,
            isMock: Bool = false,
            weatherTimedOut: Bool = false,
            scene: LocationScene = .work,
            mode: LocationMode = .fast
        ) {
            self.isCache = isCache
            self.isMock = isMock
            self.weatherTimedOut = weatherTimedOut
            self.scene = scene
            self.mode = mode
        }
    }
    
    // MARK: - Properties
    
    /// Display formatted data
    public var display: Display
    
    /// Raw underlying data
    public var raw: Raw
    
    /// Status flags
    public var flags: Flags
    
    // MARK: - Initialization
    
    public init(display: Display, raw: Raw, flags: Flags) {
        self.display = display
        self.raw = raw
        self.flags = flags
    }
    
    // MARK: - Convenience Methods
    
    /// Create a cache-hit copy with updated timestamp
    /// - Returns: New context with updated timestamp but same location data
    public func withUpdatedTimestamp() -> CameraLocationContext {
        let newTime = Date()
        let newTimeStr = Self.formatTime(newTime)
        
        var newDisplay = self.display
        newDisplay.timeStr = newTimeStr
        
        var newRaw = self.raw
        newRaw.timestamp = newTime
        
        var newFlags = self.flags
        newFlags.isCache = true
        
        return CameraLocationContext(
            display: newDisplay,
            raw: newRaw,
            flags: newFlags
        )
    }
    
    /// Format timestamp for display
    /// - Parameter date: Date to format
    /// - Returns: Formatted string "yyyy-MM-dd HH:mm:ss"
    public static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

// MARK: - POI Item

/// Point of Interest item
public struct POIItem: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let distance: Double // in meters
    public let coordinate: CLLocationCoordinate2D?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        distance: Double,
        coordinate: CLLocationCoordinate2D? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.distance = distance
        self.coordinate = coordinate
    }
    
    /// Formatted distance string
    public var distanceStr: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - Weather Info

/// Weather information
public struct WeatherInfo: Sendable, Equatable {
    /// Weather condition (e.g., "Sunny", "Cloudy", "Rainy")
    public let condition: String
    
    /// Temperature in Celsius
    public let temperature: Double
    
    /// Humidity percentage (0-100)
    public let humidity: Int
    
    /// Weather icon name (SF Symbol name)
    public let iconName: String
    
    // MARK: - WeatherKit Attribution (Required by Apple)
    
    /// Legal attribution page URL (required by WeatherKit Terms of Service)
    public let attributionURL: URL?
    
    /// Apple Weather logo URL for attribution display
    public let attributionLogoURL: URL?
    
    public init(
        condition: String,
        temperature: Double,
        humidity: Int,
        iconName: String = "sun.max",
        attributionURL: URL? = nil,
        attributionLogoURL: URL? = nil
    ) {
        self.condition = condition
        self.temperature = temperature
        self.humidity = humidity
        self.iconName = iconName
        self.attributionURL = attributionURL
        self.attributionLogoURL = attributionLogoURL
    }
    
    /// Formatted weather string for display
    public var displayString: String {
        "\(condition) \(Int(temperature))°C"
    }
    
    /// Empty weather (used when timeout or unavailable)
    public static let empty = WeatherInfo(
        condition: "--",
        temperature: 0,
        humidity: 0,
        iconName: "questionmark",
        attributionURL: nil,
        attributionLogoURL: nil
    )
}

// MARK: - CLLocationCoordinate2D Sendable

// Note: CLLocation Sendable conformance is now provided by the system in iOS 16+
// Only extending CLLocationCoordinate2D if needed
#if swift(<5.9)
extension CLLocationCoordinate2D: @unchecked Sendable {}
extension CLLocation: @unchecked Sendable {}
#endif
