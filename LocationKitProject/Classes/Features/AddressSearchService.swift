//
//  AddressSearchService.swift
//  LocationKit
//
//  地址搜索服务 - 使用 MKLocalSearchCompleter 实现边输边跳的联想效果
//

import Foundation
import CoreLocation
import MapKit

// MARK: - AddressSearchService

/// 地址搜索服务
/// 提供地址联想、周边地址获取、历史记录管理功能
///
/// 使用 MKLocalSearchCompleter 实现实时搜索联想
public final class AddressSearchService: NSObject, @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// 共享实例
    public static let shared = AddressSearchService()
    
    // MARK: - Properties
    
    /// 搜索补全器
    private var searchCompleter: MKLocalSearchCompleter
    
    /// 当前搜索区域（用于优化搜索结果）
    private var currentRegion: MKCoordinateRegion?
    
    /// 搜索结果回调
    private var completionHandler: (([AddressSearchResult]) -> Void)?
    
    /// 错误回调
    private var errorHandler: ((Error) -> Void)?
    
    /// 历史记录存储 Key
    private let historyStorageKey = "LocationKit_AddressSearchHistory"
    
    /// 最大历史记录数
    private let maxHistoryCount = 20
    
    /// 搜索结果缓存
    private var lastResults: [MKLocalSearchCompletion] = []
    
    // MARK: - Initialization
    
    public override init() {
        self.searchCompleter = MKLocalSearchCompleter()
        super.init()
        
        setupCompleter()
    }
    
    private func setupCompleter() {
        searchCompleter.delegate = self
        
        // 设置结果类型：地址和POI
        if #available(iOS 13.0, *) {
            searchCompleter.resultTypes = [.address, .pointOfInterest]
        }
    }
    
    // MARK: - Public API: 搜索联想
    
    /// 更新搜索关键词（边输边搜）
    /// - Parameters:
    ///   - query: 用户输入的搜索文字
    ///   - completion: 搜索结果回调
    ///   - onError: 错误回调
    public func updateSearchQuery(
        _ query: String,
        completion: @escaping ([AddressSearchResult]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        self.completionHandler = completion
        self.errorHandler = onError
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            // 空查询返回空结果
            completion([])
            return
        }
        
        print("🔍 [AddressSearch] Query: \(trimmed)")
        searchCompleter.queryFragment = trimmed
    }
    
    /// 设置搜索区域（优化搜索结果，优先显示该区域内的地址）
    /// - Parameter region: 搜索区域
    public func setSearchRegion(_ region: MKCoordinateRegion) {
        self.currentRegion = region
        searchCompleter.region = region
    }
    
    /// 根据当前位置设置搜索区域
    /// - Parameter location: 当前位置
    /// - Parameter radiusMeters: 搜索半径（米），默认 5000
    public func setSearchRegion(around location: CLLocation, radiusMeters: Double = 5000) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        setSearchRegion(region)
    }
    
    /// 取消当前搜索
    public func cancelSearch() {
        searchCompleter.queryFragment = ""
        completionHandler = nil
        errorHandler = nil
    }
    
    // MARK: - Public API: 异步搜索
    
    /// 搜索地址（异步）
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - region: 搜索区域（可选）
    /// - Returns: 搜索结果列表
    public func search(query: String, region: MKCoordinateRegion? = nil) async throws -> [AddressSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return []
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // 创建新的 completer 避免状态冲突
            let completer = MKLocalSearchCompleter()
            completer.queryFragment = trimmed
            
            if #available(iOS 13.0, *) {
                completer.resultTypes = [.address, .pointOfInterest]
            }
            
            if let region = region ?? self.currentRegion {
                completer.region = region
            }
            
            let delegate = AsyncSearchDelegate { result in
                switch result {
                case .success(let completions):
                    let results = completions.map { completion in
                        AddressSearchResult(
                            title: completion.title,
                            subtitle: completion.subtitle,
                            searchCompletion: completion
                        )
                    }
                    continuation.resume(returning: results)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // 保持 delegate 引用
            objc_setAssociatedObject(completer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            completer.delegate = delegate
        }
    }
    
    // MARK: - Public API: 获取地址详情
    
    /// 获取搜索结果的完整地址信息
    /// - Parameter result: 搜索结果
    /// - Returns: 完整的地址信息
    public func getAddressDetails(from result: AddressSearchResult) async throws -> AddressInfo? {
        guard let searchCompletion = result.searchCompletion else {
            return nil
        }
        
        let request = MKLocalSearch.Request(completion: searchCompletion)
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else {
                return nil
            }
            
            return AddressInfo.from(mapItem: mapItem)
        } catch {
            throw AddressSearchError.searchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Public API: 周边地址（反向地理编码）
    
    /// 获取当前位置周边的地址列表
    /// - Parameter location: 当前位置
    /// - Returns: 周边地址列表
    public func getNearbyAddresses(around location: CLLocation) async throws -> [AddressInfo] {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            return placemarks.compactMap { placemark in
                AddressInfo.from(placemark: placemark, location: location)
            }
        } catch {
            throw AddressSearchError.geocodingFailed(error.localizedDescription)
        }
    }
    
    /// 获取当前位置的主要地址（用于默认显示）
    /// - Parameter location: 当前位置
    /// - Returns: 主要地址信息
    public func getCurrentAddress(for location: CLLocation) async throws -> AddressInfo? {
        let addresses = try await getNearbyAddresses(around: location)
        return addresses.first
    }
    
    // MARK: - Public API: 历史记录
    
    /// 获取搜索历史记录
    /// - Returns: 历史记录列表
    public func getSearchHistory() -> [AddressInfo] {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey),
              let history = try? JSONDecoder().decode([AddressInfo].self, from: data) else {
            return []
        }
        return history
    }
    
    /// 添加到搜索历史
    /// - Parameter address: 地址信息
    public func addToHistory(_ address: AddressInfo) {
        var history = getSearchHistory()
        
        // 移除重复项
        history.removeAll { $0.id == address.id || $0.formattedAddress == address.formattedAddress }
        
        // 添加到开头
        history.insert(address, at: 0)
        
        // 限制数量
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        // 保存
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyStorageKey)
        }
    }
    
    /// 清除搜索历史
    public func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyStorageKey)
    }
    
    /// 从历史记录中删除指定地址
    /// - Parameter address: 要删除的地址
    public func removeFromHistory(_ address: AddressInfo) {
        var history = getSearchHistory()
        history.removeAll { $0.id == address.id }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyStorageKey)
        }
    }
    
    // MARK: - Public API: 默认展示内容
    
    /// 获取默认展示的地址列表（当前位置 + 历史记录）
    /// - Parameter currentLocation: 当前位置（可选）
    /// - Returns: 默认展示的地址列表
    public func getDefaultAddresses(currentLocation: CLLocation? = nil) async -> [AddressInfo] {
        var results: [AddressInfo] = []
        
        // 1. 当前位置的地址
        if let location = currentLocation {
            do {
                if let currentAddress = try await getCurrentAddress(for: location) {
                    var address = currentAddress
                    address.isCurrentLocation = true
                    results.append(address)
                }
            } catch {
                print("⚠️ [AddressSearch] Failed to get current address: \(error)")
            }
        }
        
        // 2. 历史记录
        let history = getSearchHistory()
        results.append(contentsOf: history)
        
        return results
    }
    
    // MARK: - Public API: 周边兴趣点 (Nearby POI)
    
    /// 获取周边兴趣点（不需要搜索关键词）
    /// 用于搜索框为空时显示附近的地点
    /// - Parameters:
    ///   - location: 中心位置
    ///   - radius: 搜索半径（米），默认 500
    ///   - limit: 返回数量上限，默认 20
    /// - Returns: 周边兴趣点列表
    public func getNearbyPOI(
        around location: CLLocation,
        radius: Double = 500,
        limit: Int = 20
    ) async throws -> [AddressInfo] {
        
        print("📍 [AddressSearch] Getting nearby POI - Radius: \(radius)m, Limit: \(limit)")
        print("📍 [AddressSearch] Center: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        // 使用 MKLocalPointsOfInterestRequest（无需关键词）
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        
        // 包含所有 POI 类型
        request.pointOfInterestFilter = MKPointOfInterestFilter.includingAll
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            print("📍 [AddressSearch] Found \(response.mapItems.count) nearby POI")
            
            var results = response.mapItems.compactMap { mapItem -> AddressInfo? in
                var info = AddressInfo.from(mapItem: mapItem)
                
                // 计算距离
                let itemLocation = CLLocation(latitude: info.latitude, longitude: info.longitude)
                let distance = location.distance(from: itemLocation)
                
                // 过滤超出半径的结果
                if distance > radius {
                    return nil
                }
                
                info.distance = distance
                return info
            }
            
            // 按距离排序
            results.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
            
            print("📍 [AddressSearch] Found \(results.count) nearby POI within \(radius)m")
            return Array(results.prefix(limit))
            
        } catch {
            print("⚠️ [AddressSearch] getNearbyPOI failed: \(error)")
            throw AddressSearchError.searchFailed(error.localizedDescription)
        }
    }
    
    /// 获取周边多类型兴趣点
    /// 同时搜索多种类型的 POI
    /// - Parameters:
    ///   - location: 中心位置
    ///   - radius: 搜索半径（米）
    ///   - categories: POI 类型列表（如 ["餐厅", "咖啡", "超市"]）
    ///   - limitPerCategory: 每种类型返回的数量上限
    /// - Returns: 周边兴趣点列表（按距离排序）
    public func getNearbyPOIByCategories(
        around location: CLLocation,
        radius: Double = 500,
        categories: [String] = ["餐厅", "咖啡", "超市", "银行", "药店"],
        limitPerCategory: Int = 5
    ) async -> [AddressInfo] {
        
        print("📍 [AddressSearch] Getting POI by categories - Radius: \(radius)m")
        
        var allResults: [AddressInfo] = []
        
        // 并发搜索各类型
        await withTaskGroup(of: [AddressInfo].self) { group in
            for category in categories {
                group.addTask {
                    do {
                        return try await self.searchPOIByKeyword(
                            keyword: category,
                            location: location,
                            radius: radius,
                            limit: limitPerCategory
                        )
                    } catch {
                        print("⚠️ [AddressSearch] Failed to search \(category): \(error)")
                        return []
                    }
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        // 去重（相同坐标的地点）
        var seen = Set<String>()
        allResults = allResults.filter { info in
            let key = "\(info.latitude),\(info.longitude)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
        
        // 按距离排序
        allResults.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
        
        print("📍 [AddressSearch] Total unique POI: \(allResults.count)")
        return allResults
    }
    
    /// 根据关键词搜索周边 POI
    /// - Parameters:
    ///   - keyword: 搜索关键词
    ///   - location: 中心位置
    ///   - radius: 搜索半径（米）
    ///   - limit: 返回数量上限
    /// - Returns: POI 列表
    public func searchPOIByKeyword(
        keyword: String,
        location: CLLocation,
        radius: Double = 500,
        limit: Int = 20
    ) async throws -> [AddressInfo] {
        
        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.naturalLanguageQuery = keyword
        
        if #available(iOS 13.0, *) {
            request.resultTypes = .pointOfInterest
        }
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            var results = response.mapItems.compactMap { mapItem -> AddressInfo? in
                var info = AddressInfo.from(mapItem: mapItem)
                info.category = keyword
                
                // 计算距离
                let itemLocation = CLLocation(latitude: info.latitude, longitude: info.longitude)
                let distance = location.distance(from: itemLocation)
                
                // 过滤超出半径的结果
                if distance > radius {
                    return nil
                }
                
                info.distance = distance
                return info
            }
            
            // 按距离排序
            results.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
            
            return Array(results.prefix(limit))
            
        } catch {
            throw AddressSearchError.searchFailed(error.localizedDescription)
        }
    }
    
    /// 获取默认展示内容（增强版）
    /// 包含：当前位置 + 周边 POI + 历史记录
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - nearbyRadius: 周边 POI 搜索半径（米），默认 200
    ///   - nearbyLimit: 周边 POI 数量上限，默认 10
    /// - Returns: 默认展示的地址列表
    public func getDefaultAddressesWithNearbyPOI(
        currentLocation: CLLocation?,
        nearbyRadius: Double = 200,
        nearbyLimit: Int = 10
    ) async -> [AddressInfo] {
        var results: [AddressInfo] = []
        
        // 1. 当前位置的地址
        if let location = currentLocation {
            do {
                if let currentAddress = try await getCurrentAddress(for: location) {
                    var address = currentAddress
                    address.isCurrentLocation = true
                    results.append(address)
                }
            } catch {
                print("⚠️ [AddressSearch] Failed to get current address: \(error)")
            }
            
            // 2. 周边 POI
            do {
                let nearbyPOI = try await getNearbyPOI(
                    around: location,
                    radius: nearbyRadius,
                    limit: nearbyLimit
                )
                results.append(contentsOf: nearbyPOI)
            } catch {
                print("⚠️ [AddressSearch] Failed to get nearby POI: \(error)")
            }
        }
        
        // 3. 历史记录
        let history = getSearchHistory()
        
        // 去重：如果历史记录中的地址已经在周边 POI 中，则不重复添加
        let existingCoords = Set(results.map { "\($0.latitude),\($0.longitude)" })
        let filteredHistory = history.filter { addr in
            !existingCoords.contains("\(addr.latitude),\(addr.longitude)")
        }
        
        for var addr in filteredHistory {
            addr.isFromHistory = true
            results.append(addr)
        }
        
        return results
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension AddressSearchService: MKLocalSearchCompleterDelegate {
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        lastResults = completer.results
        
        let results = completer.results.map { completion in
            AddressSearchResult(
                title: completion.title,
                subtitle: completion.subtitle,
                searchCompletion: completion
            )
        }
        
        print("🔍 [AddressSearch] Found \(results.count) results")
        
        DispatchQueue.main.async { [weak self] in
            self?.completionHandler?(results)
        }
    }
    
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("⚠️ [AddressSearch] Error: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            if let mkError = error as? MKError, mkError.code == .placemarkNotFound {
                // 没有找到结果，返回空数组
                self?.completionHandler?([])
            } else {
                self?.errorHandler?(AddressSearchError.searchFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Async Search Delegate

private final class AsyncSearchDelegate: NSObject, MKLocalSearchCompleterDelegate {
    
    private let completion: (Result<[MKLocalSearchCompletion], Error>) -> Void
    private var hasCompleted = false
    
    init(completion: @escaping (Result<[MKLocalSearchCompletion], Error>) -> Void) {
        self.completion = completion
        super.init()
        
        // 设置超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, !self.hasCompleted else { return }
            self.hasCompleted = true
            self.completion(.failure(AddressSearchError.timeout))
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(.success(completer.results))
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        if let mkError = error as? MKError, mkError.code == .placemarkNotFound {
            completion(.success([]))
        } else {
            completion(.failure(AddressSearchError.searchFailed(error.localizedDescription)))
        }
    }
}

// MARK: - Data Models

/// 地址搜索结果（联想项）
public struct AddressSearchResult: Identifiable, Hashable, Sendable {
    public let id: UUID
    
    /// 主标题（地点名称）
    public let title: String
    
    /// 副标题（详细地址）
    public let subtitle: String
    
    /// 完整文本
    public var fullText: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
    
    /// 内部搜索结果（用于获取详情）
    internal let searchCompletion: MKLocalSearchCompletion?
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        searchCompletion: MKLocalSearchCompletion? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.searchCompletion = searchCompletion
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AddressSearchResult, rhs: AddressSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// 完整地址信息
public struct AddressInfo: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    
    /// 地点名称（如 "星巴克咖啡"）
    public var name: String?
    
    /// 格式化的完整地址
    public var formattedAddress: String
    
    /// 城市
    public var city: String?
    
    /// 区/县
    public var district: String?
    
    /// 街道
    public var street: String?
    
    /// 门牌号
    public var streetNumber: String?
    
    /// 纬度
    public var latitude: Double
    
    /// 经度
    public var longitude: Double
    
    /// 距离（米）
    public var distance: Double?
    
    /// POI 类别
    public var category: String?
    
    /// 是否为当前位置
    public var isCurrentLocation: Bool
    
    /// 是否为历史记录
    public var isFromHistory: Bool
    
    /// 坐标
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// CLLocation
    public var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// 格式化距离字符串
    public var distanceString: String? {
        guard let d = distance else { return nil }
        if d < 1000 {
            return String(format: "%.0f m", d)
        } else {
            return String(format: "%.1f km", d / 1000)
        }
    }
    
    public init(
        id: UUID = UUID(),
        name: String? = nil,
        formattedAddress: String,
        city: String? = nil,
        district: String? = nil,
        street: String? = nil,
        streetNumber: String? = nil,
        latitude: Double,
        longitude: Double,
        distance: Double? = nil,
        category: String? = nil,
        isCurrentLocation: Bool = false,
        isFromHistory: Bool = false
    ) {
        self.id = id
        self.name = name
        self.formattedAddress = formattedAddress
        self.city = city
        self.district = district
        self.street = street
        self.streetNumber = streetNumber
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
        self.category = category
        self.isCurrentLocation = isCurrentLocation
        self.isFromHistory = isFromHistory
    }
    
    /// 从 MKMapItem 创建
    static func from(mapItem: MKMapItem) -> AddressInfo {
        let placemark = mapItem.placemark
        
        let addressParts = [
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country
        ].compactMap { $0 }
        
        let formattedAddress = addressParts.isEmpty
            ? (mapItem.name ?? "Unknown")
            : addressParts.joined(separator: " ")
        
        return AddressInfo(
            name: mapItem.name,
            formattedAddress: formattedAddress,
            city: placemark.locality,
            district: placemark.subLocality,
            street: placemark.thoroughfare,
            streetNumber: placemark.subThoroughfare,
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }
    
    /// 从 CLPlacemark 创建
    static func from(placemark: CLPlacemark, location: CLLocation) -> AddressInfo {
        let addressParts = [
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country
        ].compactMap { $0 }
        
        let formattedAddress = addressParts.isEmpty
            ? (placemark.name ?? "Unknown")
            : addressParts.joined(separator: " ")
        
        return AddressInfo(
            name: placemark.name,
            formattedAddress: formattedAddress,
            city: placemark.locality,
            district: placemark.subLocality,
            street: placemark.thoroughfare,
            streetNumber: placemark.subThoroughfare,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AddressInfo, rhs: AddressInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// 地址搜索错误
public enum AddressSearchError: LocalizedError, Equatable {
    case searchFailed(String)
    case geocodingFailed(String)
    case noResults
    case timeout
    case invalidQuery
    
    public var errorDescription: String? {
        switch self {
        case .searchFailed(let reason):
            return "搜索失败: \(reason)"
        case .geocodingFailed(let reason):
            return "地理编码失败: \(reason)"
        case .noResults:
            return "未找到匹配的地址"
        case .timeout:
            return "搜索超时，请重试"
        case .invalidQuery:
            return "无效的搜索关键词"
        }
    }
}
