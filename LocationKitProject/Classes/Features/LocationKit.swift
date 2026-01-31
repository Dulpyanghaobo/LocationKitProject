//
//  LocationKit.swift
//  LocationKit
//
//  High-level Facade for camera location features
//  Serves watermark camera and travel camera scenarios
//

import Foundation
import CoreLocation

// MARK: - LocationKit Facade

/// High-level Facade for camera location features
/// Provides a simple API for fetching complete location context
///
/// Features:
/// - Smart caching for burst mode photography
/// - Concurrent fetching with timeout protection
/// - WeatherKit integration with mock fallback for testing
/// - Protocol-based dependency injection for testability
///
/// Usage:
/// ```swift
/// let context = try await LocationKit.shared.fetchCameraContext(scene: .travel, mode: .fast)
/// print(context.display.title)      // "Beijing, Chaoyang"
/// print(context.display.timeStr)    // "2026-01-31 18:30:00"
/// print(context.flags.isCache)      // false
/// ```
public final class LocationKit: @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// Shared instance (uses real services in production, mock on simulator)
    public static let shared = LocationKit()
    
    // MARK: - Dependencies
    
    private let locationManager: LocationManager
    private let geocodingService: GeocodingService
    private let altitudeService: AltitudeService
    private let weatherService: any WeatherServiceProtocol
    private let poiService: POIServiceMock
    
    // MARK: - Cache Properties
    
    /// Last fetched location for cache comparison
    private var lastLocation: CLLocation?
    
    /// Last fetched context for cache reuse
    private var lastContext: CameraLocationContext?
    
    /// Cache lock for thread safety
    private let cacheLock = NSLock()
    
    // MARK: - Configuration
    
    /// Cache distance threshold in meters
    private let cacheDistanceThreshold: Double = 20.0
    
    /// Cache time threshold in seconds
    private let cacheTimeThreshold: TimeInterval = 120.0
    
    /// Weather request timeout in seconds
    private let weatherTimeout: TimeInterval = 3.0
    
    /// Whether using mock weather service
    private let isUsingMockWeather: Bool
    
    // MARK: - Initialization
    
    /// Initialize with default services
    /// - Uses WeatherKit on real devices (iOS 16+)
    /// - Uses MockWeatherService on simulator or older iOS versions
    public init(
        locationManager: LocationManager = .shared,
        geocodingService: GeocodingService = .shared,
        altitudeService: AltitudeService = .shared
    ) {
        self.locationManager = locationManager
        self.geocodingService = geocodingService
        self.altitudeService = altitudeService
        self.weatherService = WeatherServiceFactory.createService()
        self.poiService = POIServiceMock()
        
        #if targetEnvironment(simulator)
        self.isUsingMockWeather = true
        #else
        #if canImport(WeatherKit)
        if #available(iOS 16.0, *) {
            self.isUsingMockWeather = false
        } else {
            self.isUsingMockWeather = true
        }
        #else
        self.isUsingMockWeather = true
        #endif
        #endif
    }
    
    /// Initialize with custom weather service (for dependency injection/testing)
    /// - Parameters:
    ///   - locationManager: Location manager instance
    ///   - geocodingService: Geocoding service instance
    ///   - altitudeService: Altitude service instance
    ///   - weatherService: Custom weather service (use MockWeatherService for testing)
    public init(
        locationManager: LocationManager = .shared,
        geocodingService: GeocodingService = .shared,
        altitudeService: AltitudeService = .shared,
        weatherService: any WeatherServiceProtocol
    ) {
        self.locationManager = locationManager
        self.geocodingService = geocodingService
        self.altitudeService = altitudeService
        self.weatherService = weatherService
        self.poiService = POIServiceMock()
        self.isUsingMockWeather = weatherService is MockWeatherService
    }
    
    // MARK: - Public API
    
    /// Fetch complete camera location context
    /// - Parameters:
    ///   - scene: Usage scenario (.work or .travel)
    ///   - mode: Location accuracy mode (.fast or .accurate)
    /// - Returns: Complete location context for camera watermark
    /// - Throws: LocationKitError if location fetch fails
    public func fetchCameraContext(
        scene: LocationScene,
        mode: LocationMode
    ) async throws -> CameraLocationContext {
        
        print("📍 [LocationKit] Fetching context - Scene: \(scene.rawValue), Mode: \(mode.rawValue)")
        
        // Step 1: Get current location
        let location = try await locationManager.getCurrentLocation()
        print("📍 [LocationKit] Location acquired: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Step 2: Check cache
        if let cachedContext = checkCache(for: location) {
            print("✅ [LocationKit] Cache HIT - Reusing data with updated timestamp")
            return cachedContext
        }
        
        print("🔄 [LocationKit] Cache MISS - Fetching fresh data")
        
        // Step 3: Fetch all data concurrently
        let context = await fetchAllData(location: location, scene: scene, mode: mode)
        
        // Step 4: Update cache
        updateCache(location: location, context: context)
        
        return context
    }
    
    /// Clear the location cache
    public func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        lastLocation = nil
        lastContext = nil
        print("🗑️ [LocationKit] Cache cleared")
    }
    
    /// Get cache status for debugging
    public var cacheStatus: (hasCache: Bool, lastTime: Date?) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        return (lastContext != nil, lastContext?.raw.timestamp)
    }
    
    // MARK: - Private Methods
    
    /// Check if we should use cached data
    /// - Parameter currentLocation: Current location to compare
    /// - Returns: Cached context with updated timestamp if cache hit, nil otherwise
    private func checkCache(for currentLocation: CLLocation) -> CameraLocationContext? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let lastLoc = lastLocation,
              let lastCtx = lastContext else {
            return nil
        }
        
        // Calculate distance
        let distance = currentLocation.distance(from: lastLoc)
        
        // Calculate time interval using system time
        let timeInterval = Date().timeIntervalSince(lastCtx.raw.timestamp)
        
        print("📊 [LocationKit] Cache check - Distance: \(String(format: "%.1f", distance))m, Time: \(String(format: "%.1f", timeInterval))s")
        
        // Check thresholds: distance < 20m AND time < 120s
        if distance < cacheDistanceThreshold && timeInterval < cacheTimeThreshold {
            // Cache HIT: Reuse data but UPDATE timestamp
            return lastCtx.withUpdatedTimestamp()
        }
        
        return nil
    }
    
    /// Update cache with new data
    private func updateCache(location: CLLocation, context: CameraLocationContext) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        lastLocation = location
        lastContext = context
    }
    
    /// Fetch all data concurrently using TaskGroup
    private func fetchAllData(
        location: CLLocation,
        scene: LocationScene,
        mode: LocationMode
    ) async -> CameraLocationContext {
        
        // Use system time - NO NTP
        let currentTime = Date()
        let timeStr = CameraLocationContext.formatTime(currentTime)
        
        // Results containers
        var address: GeocodedAddress?
        var weather: WeatherInfo?
        var poiList: [POIItem] = []
        var weatherTimedOut = false
        
        // Concurrent fetching using TaskGroup
        await withTaskGroup(of: FetchResult.self) { group in
            
            // Task 1: Reverse geocoding (real API)
            group.addTask {
                do {
                    let addr = try await self.geocodingService.reverseGeocode(location: location)
                    return .address(addr)
                } catch {
                    print("⚠️ [LocationKit] Geocoding failed: \(error.localizedDescription)")
                    return .address(nil)
                }
            }
            
            // Task 2: Weather (WeatherKit or Mock with 3s timeout)
            group.addTask {
                do {
                    let weatherData = try await self.fetchWeatherWithTimeout(for: location)
                    return .weather(weatherData, timedOut: false)
                } catch {
                    print("⚠️ [LocationKit] Weather timed out or failed: \(error.localizedDescription)")
                    return .weather(nil, timedOut: true)
                }
            }
            
            // Task 3: POI (Mock - can be replaced with real service later)
            group.addTask {
                let pois = await self.poiService.fetchPOI(
                    coordinate: location.coordinate,
                    keywords: scene.poiKeywords
                )
                return .poi(pois)
            }
            
            // Collect results
            for await result in group {
                switch result {
                case .address(let addr):
                    address = addr
                case .weather(let w, let timedOut):
                    weather = w
                    weatherTimedOut = timedOut
                case .poi(let pois):
                    poiList = pois
                }
            }
        }
        
        // Build context
        return buildContext(
            location: location,
            address: address,
            weather: weather,
            poiList: poiList,
            timestamp: currentTime,
            timeStr: timeStr,
            weatherTimedOut: weatherTimedOut,
            scene: scene,
            mode: mode
        )
    }
    
    /// Fetch weather with timeout protection
    /// - Parameter location: Location to fetch weather for
    /// - Returns: Weather info or throws timeout error
    private func fetchWeatherWithTimeout(for location: CLLocation) async throws -> WeatherInfo {
        try await withThrowingTaskGroup(of: WeatherInfo.self) { group in
            // Weather fetch task using injected service
            group.addTask {
                return try await self.weatherService.fetchCurrentWeather(for: location)
            }
            
            // Timeout task (3 second circuit breaker)
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.weatherTimeout * 1_000_000_000))
                throw LocationKitError.timeout
            }
            
            // Return first completed, cancel others
            guard let result = try await group.next() else {
                throw LocationKitError.timeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Build CameraLocationContext from fetched data
    private func buildContext(
        location: CLLocation,
        address: GeocodedAddress?,
        weather: WeatherInfo?,
        poiList: [POIItem],
        timestamp: Date,
        timeStr: String,
        weatherTimedOut: Bool,
        scene: LocationScene,
        mode: LocationMode
    ) -> CameraLocationContext {
        
        // Build display title
        let title: String
        if let addr = address {
            if let city = addr.locality, let district = addr.subLocality {
                title = "\(city) \(district)"
            } else if let city = addr.locality {
                title = city
            } else if let admin = addr.administrativeArea {
                title = admin
            } else {
                title = addr.formattedAddress
            }
        } else {
            title = formatCoordinate(location.coordinate)
        }
        
        // Build subtitle
        let subtitle: String
        if let addr = address {
            subtitle = addr.areasOfInterest?.first ?? addr.thoroughfare ?? addr.name ?? ""
        } else if let firstPOI = poiList.first {
            subtitle = firstPOI.name
        } else {
            subtitle = ""
        }
        
        // Weather string
        let weatherStr = weather?.displayString ?? WeatherInfo.empty.displayString
        
        // Altitude string
        let altitudeStr = altitudeService.formatAltitude(location.altitude, unit: .meters)
        
        // Coordinate string
        let coordinateStr = formatCoordinate(location.coordinate)
        
        // Build display
        let display = CameraLocationContext.Display(
            title: title,
            subtitle: subtitle,
            weatherStr: weatherStr,
            timeStr: timeStr,
            altitudeStr: altitudeStr,
            coordinateStr: coordinateStr
        )
        
        // Build raw
        let raw = CameraLocationContext.Raw(
            location: location,
            address: address,
            poiList: poiList,
            timestamp: timestamp,
            weather: weather
        )
        
        // Build flags
        let flags = CameraLocationContext.Flags(
            isCache: false,
            isMock: isUsingMockWeather, // true if using mock weather service
            weatherTimedOut: weatherTimedOut,
            scene: scene,
            mode: mode
        )
        
        return CameraLocationContext(display: display, raw: raw, flags: flags)
    }
    
    /// Format coordinate for display
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.4f°%@, %.4f°%@",
                      abs(coordinate.latitude), latDirection,
                      abs(coordinate.longitude), lonDirection)
    }
}

// MARK: - Fetch Result Enum

/// Internal enum for TaskGroup results
private enum FetchResult: Sendable {
    case address(GeocodedAddress?)
    case weather(WeatherInfo?, timedOut: Bool)
    case poi([POIItem])
}

// MARK: - POI Service Mock

/// Mock POI service for testing
/// Can be replaced with real MapKit/POI service in the future
private actor POIServiceMock {
    
    /// Fetch mock POI data with random delay (0.5s - 2s)
    /// - Parameters:
    ///   - coordinate: Location coordinate
    ///   - keywords: Search keywords based on scene
    /// - Returns: List of mock POI items
    func fetchPOI(coordinate: CLLocationCoordinate2D, keywords: [String]) async -> [POIItem] {
        // Random delay between 0.5s and 2s
        let delay = Double.random(in: 0.5...2.0)
        print("📍 [MockPOI] Request started (delay: \(String(format: "%.1f", delay))s)")
        
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch {
            // Task cancelled
            return []
        }
        
        // Generate mock POIs based on keywords
        let mockPOIs: [POIItem]
        
        if keywords.contains("office") || keywords.contains("business") {
            // Work mode POIs
            mockPOIs = [
                POIItem(name: "SAP Labs China", category: "Office Building", distance: 50),
                POIItem(name: "Tech Park Tower A", category: "Business Center", distance: 120),
                POIItem(name: "Innovation Hub", category: "Co-working Space", distance: 200),
                POIItem(name: "City Center Mall", category: "Shopping", distance: 350)
            ]
        } else {
            // Travel mode POIs
            mockPOIs = [
                POIItem(name: "Forbidden City", category: "Historic Site", distance: 500),
                POIItem(name: "Tiananmen Square", category: "Landmark", distance: 800),
                POIItem(name: "Wangfujing Street", category: "Shopping District", distance: 1200),
                POIItem(name: "Beijing Duck Restaurant", category: "Restaurant", distance: 300),
                POIItem(name: "Temple of Heaven", category: "Tourist Attraction", distance: 2500)
            ]
        }
        
        print("📍 [MockPOI] Completed: \(mockPOIs.count) items")
        return mockPOIs
    }
}

// MARK: - LocationKit + Convenience

public extension LocationKit {
    
    /// Quick fetch for work mode (watermark camera)
    func fetchWorkContext() async throws -> CameraLocationContext {
        try await fetchCameraContext(scene: .work, mode: .fast)
    }
    
    /// Quick fetch for travel mode (travel camera)
    func fetchTravelContext() async throws -> CameraLocationContext {
        try await fetchCameraContext(scene: .travel, mode: .accurate)
    }
    
    /// Burst mode fetch - optimized for continuous shooting
    /// Will use cache if available within thresholds
    func fetchBurstContext() async throws -> CameraLocationContext {
        try await fetchCameraContext(scene: .work, mode: .fast)
    }
}
