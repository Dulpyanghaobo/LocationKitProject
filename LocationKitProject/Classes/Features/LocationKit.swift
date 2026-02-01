//
//  LocationKit.swift
//  LocationKit
//
//  High-level Facade for camera location features
//  Serves watermark camera and travel camera scenarios
//

import Foundation
import CoreLocation
import MapKit

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

// MARK: - LocationKit + Nearby Search

public extension LocationKit {
    
    /// Search for nearby places/POIs
    /// - Parameters:
    ///   - center: Search center coordinate (optional, defaults to current location)
    ///   - radius: Search radius in meters (default: 500)
    ///   - keyword: Search keyword (e.g., "restaurant", "cafe", or user input)
    ///   - limit: Maximum number of results (default: 20)
    ///   - useCache: Whether to use cached results (default: true, TTL: 15 minutes)
    /// - Returns: Array of nearby places sorted by distance
    /// - Throws: NearbySearchError or LocationKitError
    ///
    /// Usage:
    /// ```swift
    /// // Search nearby restaurants
    /// let places = try await LocationKit.shared.searchNearbyPlaces(
    ///     keyword: "restaurant",
    ///     radius: 500
    /// )
    ///
    /// // Display results
    /// for place in places {
    ///     print("\(place.name) - \(place.distanceString ?? "?")")
    /// }
    /// ```
    func searchNearbyPlaces(
        center: CLLocationCoordinate2D? = nil,
        radius: Double = 500,
        keyword: String? = nil,
        limit: Int = 20,
        useCache: Bool = true
    ) async throws -> [NearbyPlace] {
        
        // Get center coordinate
        let searchCenter: CLLocationCoordinate2D
        if let center = center {
            searchCenter = center
        } else {
            // Use current location
            let location = try await locationManager.getCurrentLocation()
            searchCenter = location.coordinate
        }
        
        print("📍 [LocationKit] Nearby search - Center: \(searchCenter.latitude), \(searchCenter.longitude), Radius: \(radius)m")
        
        return try await NearbySearchService.shared.searchNearby(
            center: searchCenter,
            radius: radius,
            keyword: keyword,
            limit: limit,
            useCache: useCache
        )
    }
    
    /// Search for nearby places with simplified parameters
    /// - Parameters:
    ///   - keyword: Search keyword (e.g., "restaurant", "cafe")
    ///   - radius: Search radius in meters (default: 500)
    /// - Returns: Array of nearby places sorted by distance
    /// - Throws: NearbySearchError or LocationKitError
    ///
    /// Usage:
    /// ```swift
    /// let cafes = try await LocationKit.shared.searchNearby(keyword: "cafe", radius: 1000)
    /// ```
    func searchNearby(
        keyword: String,
        radius: Double = 500
    ) async throws -> [NearbyPlace] {
        try await searchNearbyPlaces(
            center: nil,
            radius: radius,
            keyword: keyword,
            limit: 20,
            useCache: true
        )
    }
    
    /// Search for nearby places with full result metadata
    /// - Parameters:
    ///   - center: Search center coordinate (optional, defaults to current location)
    ///   - radius: Search radius in meters (default: 500)
    ///   - keyword: Search keyword
    ///   - limit: Maximum number of results (default: 20)
    ///   - useCache: Whether to use cached results (default: true)
    /// - Returns: NearbySearchResult with places and metadata
    /// - Throws: NearbySearchError or LocationKitError
    func searchNearbyWithResult(
        center: CLLocationCoordinate2D? = nil,
        radius: Double = 500,
        keyword: String? = nil,
        limit: Int = 20,
        useCache: Bool = true
    ) async throws -> NearbySearchResult {
        
        // Get center coordinate
        let searchCenter: CLLocationCoordinate2D
        if let center = center {
            searchCenter = center
        } else {
            let location = try await locationManager.getCurrentLocation()
            searchCenter = location.coordinate
        }
        
        return try await NearbySearchService.shared.searchNearbyWithResult(
            center: searchCenter,
            radius: radius,
            keyword: keyword,
            limit: limit,
            useCache: useCache
        )
    }
    
    /// Search for address completions (autocomplete)
    /// - Parameters:
    ///   - query: User input query string
    ///   - region: Optional region to bias results (defaults to current location area)
    /// - Returns: Array of address completions
    /// - Throws: NearbySearchError
    ///
    /// Usage:
    /// ```swift
    /// // User types "Apple"
    /// let completions = try await LocationKit.shared.searchAddressCompletions(query: "Apple")
    /// for completion in completions {
    ///     print("\(completion.title) - \(completion.subtitle ?? "")")
    /// }
    /// ```
    func searchAddressCompletions(
        query: String,
        region: MKCoordinateRegion? = nil
    ) async throws -> [AddressCompletion] {
        
        // If no region provided, try to use current location
        var searchRegion = region
        if searchRegion == nil {
            do {
                let location = try await locationManager.getCurrentLocation()
                searchRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
            } catch {
                // Continue without region bias if location fails
                print("⚠️ [LocationKit] Could not get location for address completion bias")
            }
        }
        
        return try await NearbySearchService.shared.searchAddressCompletions(
            query: query,
            region: searchRegion
        )
    }
    
    /// Get place details from an address completion
    /// - Parameter completion: The address completion to get details for
    /// - Returns: NearbyPlace with full details, or nil if not found
    /// - Throws: NearbySearchError
    func getPlaceDetails(from completion: AddressCompletion) async throws -> NearbyPlace? {
        try await NearbySearchService.shared.getPlaceDetails(from: completion)
    }
    
    /// Clear the nearby search cache
    func clearNearbyCache() {
        NearbySearchService.shared.clearCache()
    }
    
    /// Get nearby search cache statistics
    var nearbyCacheStats: (count: Int, oldestAge: TimeInterval?) {
        NearbySearchService.shared.cacheStats
    }
}

// MARK: - LocationKit + Address Search

public extension LocationKit {
    
    // MARK: - 地址搜索联想
    
    /// 搜索地址（边输边搜联想）
    /// 使用 MKLocalSearchCompleter 实现实时搜索联想
    /// - Parameters:
    ///   - query: 用户输入的搜索文字
    ///   - region: 搜索区域（可选，默认使用当前位置周边）
    /// - Returns: 地址搜索结果列表
    /// - Throws: AddressSearchError
    ///
    /// Usage:
    /// ```swift
    /// // 用户输入 "星巴克"
    /// let results = try await LocationKit.shared.searchAddress(query: "星巴克")
    /// for result in results {
    ///     print("\(result.title) - \(result.subtitle)")
    /// }
    /// ```
    func searchAddress(query: String, region: MKCoordinateRegion? = nil) async throws -> [AddressSearchResult] {
        // 如果没有提供区域，尝试使用当前位置
        var searchRegion = region
        if searchRegion == nil {
            do {
                let location = try await locationManager.getCurrentLocation()
                searchRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
            } catch {
                print("⚠️ [LocationKit] Could not get location for search region bias")
            }
        }
        
        return try await AddressSearchService.shared.search(query: query, region: searchRegion)
    }
    
    /// 实时搜索地址（边输边搜，使用回调）
    /// - Parameters:
    ///   - query: 用户输入的搜索文字
    ///   - completion: 搜索结果回调
    ///   - onError: 错误回调
    func searchAddressRealtime(
        _ query: String,
        completion: @escaping ([AddressSearchResult]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        AddressSearchService.shared.updateSearchQuery(query, completion: completion, onError: onError)
    }
    
    /// 取消当前地址搜索
    func cancelAddressSearch() {
        AddressSearchService.shared.cancelSearch()
    }
    
    /// 设置地址搜索区域
    /// - Parameter region: 搜索区域
    func setAddressSearchRegion(_ region: MKCoordinateRegion) {
        AddressSearchService.shared.setSearchRegion(region)
    }
    
    /// 根据当前位置设置搜索区域
    func setAddressSearchRegionToCurrent() async {
        do {
            let location = try await locationManager.getCurrentLocation()
            AddressSearchService.shared.setSearchRegion(around: location)
        } catch {
            print("⚠️ [LocationKit] Could not set search region: \(error)")
        }
    }
    
    // MARK: - 获取地址详情
    
    /// 获取搜索结果的完整地址信息
    /// - Parameter result: 搜索结果
    /// - Returns: 完整的地址信息
    func getAddressDetails(from result: AddressSearchResult) async throws -> AddressInfo? {
        try await AddressSearchService.shared.getAddressDetails(from: result)
    }
    
    // MARK: - 周边地址（反向地理编码）
    
    /// 获取当前位置的地址
    /// - Returns: 当前位置的地址信息
    func getCurrentLocationAddress() async throws -> AddressInfo? {
        let location = try await locationManager.getCurrentLocation()
        return try await AddressSearchService.shared.getCurrentAddress(for: location)
    }
    
    /// 获取指定位置的地址
    /// - Parameter location: 位置
    /// - Returns: 地址信息
    func getAddress(for location: CLLocation) async throws -> AddressInfo? {
        try await AddressSearchService.shared.getCurrentAddress(for: location)
    }
    
    /// 获取周边地址列表
    /// - Parameter location: 位置（可选，默认当前位置）
    /// - Returns: 周边地址列表
    func getNearbyAddresses(location: CLLocation? = nil) async throws -> [AddressInfo] {
        let targetLocation: CLLocation
        if let location = location {
            targetLocation = location
        } else {
            targetLocation = try await locationManager.getCurrentLocation()
        }
        return try await AddressSearchService.shared.getNearbyAddresses(around: targetLocation)
    }
    
    // MARK: - 默认展示内容
    
    /// 获取地址选择器的默认展示内容
    /// 包含：当前位置地址 + 历史记录
    /// - Returns: 默认展示的地址列表
    func getDefaultAddresses() async -> [AddressInfo] {
        var currentLocation: CLLocation?
        do {
            currentLocation = try await locationManager.getCurrentLocation()
        } catch {
            print("⚠️ [LocationKit] Could not get current location for default addresses")
        }
        return await AddressSearchService.shared.getDefaultAddresses(currentLocation: currentLocation)
    }
    
    // MARK: - 搜索历史
    
    /// 获取地址搜索历史
    /// - Returns: 历史记录列表
    func getAddressSearchHistory() -> [AddressInfo] {
        AddressSearchService.shared.getSearchHistory()
    }
    
    /// 添加地址到搜索历史
    /// - Parameter address: 地址信息
    func addAddressToHistory(_ address: AddressInfo) {
        AddressSearchService.shared.addToHistory(address)
    }
    
    /// 清除地址搜索历史
    func clearAddressSearchHistory() {
        AddressSearchService.shared.clearHistory()
    }
    
    /// 从历史记录中删除地址
    /// - Parameter address: 要删除的地址
    func removeAddressFromHistory(_ address: AddressInfo) {
        AddressSearchService.shared.removeFromHistory(address)
    }
    
    // MARK: - 周边兴趣点 (Nearby POI)
    
    /// 获取周边兴趣点（搜索框为空时使用）
    /// 用于在用户未输入搜索内容时显示附近的地点
    /// - Parameters:
    ///   - location: 中心位置（可选，默认当前位置）
    ///   - radius: 搜索半径（米），默认 500
    ///   - limit: 返回数量上限，默认 20
    /// - Returns: 周边兴趣点列表（按距离排序）
    /// - Throws: AddressSearchError
    ///
    /// Usage:
    /// ```swift
    /// // 获取当前位置 500m 内的兴趣点
    /// let pois = try await LocationKit.shared.getNearbyPOI(radius: 500)
    /// for poi in pois {
    ///     print("\(poi.name ?? "") - \(poi.distanceString ?? "")")
    /// }
    /// ```
    func getNearbyPOI(
        location: CLLocation? = nil,
        radius: Double = 500,
        limit: Int = 20
    ) async throws -> [AddressInfo] {
        let targetLocation: CLLocation
        if let location = location {
            targetLocation = location
        } else {
            targetLocation = try await locationManager.getCurrentLocation()
        }
        
        return try await AddressSearchService.shared.getNearbyPOI(
            around: targetLocation,
            radius: radius,
            limit: limit
        )
    }
    
    /// 根据关键词获取周边 POI
    /// - Parameters:
    ///   - keyword: 搜索关键词（如 "餐厅"、"咖啡"）
    ///   - location: 中心位置（可选，默认当前位置）
    ///   - radius: 搜索半径（米），默认 500
    ///   - limit: 返回数量上限，默认 20
    /// - Returns: POI 列表（按距离排序）
    ///
    /// Usage:
    /// ```swift
    /// // 搜索 200m 内的餐厅
    /// let restaurants = try await LocationKit.shared.getPOIByKeyword("餐厅", radius: 200)
    /// ```
    func getPOIByKeyword(
        _ keyword: String,
        location: CLLocation? = nil,
        radius: Double = 500,
        limit: Int = 20
    ) async throws -> [AddressInfo] {
        let targetLocation: CLLocation
        if let location = location {
            targetLocation = location
        } else {
            targetLocation = try await locationManager.getCurrentLocation()
        }
        
        return try await AddressSearchService.shared.searchPOIByKeyword(
            keyword: keyword,
            location: targetLocation,
            radius: radius,
            limit: limit
        )
    }
    
    /// 获取多类型周边 POI
    /// 同时搜索多种类型的兴趣点
    /// - Parameters:
    ///   - location: 中心位置（可选，默认当前位置）
    ///   - radius: 搜索半径（米），默认 500
    ///   - categories: POI 类型列表，默认 ["餐厅", "咖啡", "超市", "银行", "药店"]
    ///   - limitPerCategory: 每种类型返回的数量上限，默认 5
    /// - Returns: 周边兴趣点列表（按距离排序，已去重）
    ///
    /// Usage:
    /// ```swift
    /// // 获取 500m 内的各类 POI
    /// let pois = await LocationKit.shared.getNearbyPOIByCategories(
    ///     radius: 500,
    ///     categories: ["餐厅", "咖啡", "便利店"]
    /// )
    /// ```
    func getNearbyPOIByCategories(
        location: CLLocation? = nil,
        radius: Double = 500,
        categories: [String] = ["餐厅", "咖啡", "超市", "银行", "药店"],
        limitPerCategory: Int = 5
    ) async -> [AddressInfo] {
        var targetLocation: CLLocation
        if let location = location {
            targetLocation = location
        } else {
            do {
                targetLocation = try await locationManager.getCurrentLocation()
            } catch {
                print("⚠️ [LocationKit] Could not get current location for POI search")
                return []
            }
        }
        
        return await AddressSearchService.shared.getNearbyPOIByCategories(
            around: targetLocation,
            radius: radius,
            categories: categories,
            limitPerCategory: limitPerCategory
        )
    }
    
    /// 获取增强版默认地址列表
    /// 包含：当前位置 + 周边 POI + 历史记录
    /// 适合在地址选择器搜索框为空时使用
    /// - Parameters:
    ///   - nearbyRadius: 周边 POI 搜索半径（米），默认 200
    ///   - nearbyLimit: 周边 POI 数量上限，默认 10
    /// - Returns: 默认展示的地址列表
    ///
    /// Usage:
    /// ```swift
    /// // 用户打开地址选择器，搜索框为空
    /// let addresses = await LocationKit.shared.getDefaultAddressesWithPOI(
    ///     nearbyRadius: 100,
    ///     nearbyLimit: 10
    /// )
    /// ```
    func getDefaultAddressesWithPOI(
        nearbyRadius: Double = 200,
        nearbyLimit: Int = 10
    ) async -> [AddressInfo] {
        var currentLocation: CLLocation?
        do {
            currentLocation = try await locationManager.getCurrentLocation()
        } catch {
            print("⚠️ [LocationKit] Could not get current location for default addresses")
        }
        
        return await AddressSearchService.shared.getDefaultAddressesWithNearbyPOI(
            currentLocation: currentLocation,
            nearbyRadius: nearbyRadius,
            nearbyLimit: nearbyLimit
        )
    }
}
