# LocationKit

> 可复用的 iOS 定位组件，提供位置获取、海拔测量、地理编码等功能。

---

## 📋 概述

LocationKit 是从 TimeProof 项目中抽取的独立定位组件，设计目标是：
- **可复用性**: 独立于业务逻辑，可被其他项目直接使用
- **类型安全**: 使用 Swift 强类型和协议设计
- **现代化 API**: 基于 Combine + async/await
- **缓存优化**: 地理编码结果带缓存，减少 API 调用

---

## 📁 目录结构

```
LocationKit/
├── README.md                    # 本文档
├── Core/                        # 核心层
│   ├── LocationKitProtocols.swift   # 协议定义
│   ├── LocationModels.swift         # 数据模型
│   ├── LocationKitError.swift       # 错误类型
│   └── LocationManager.swift        # 核心定位管理器
├── Features/                    # 功能服务
│   ├── GeocodingService.swift       # 地理编码服务(带缓存)
│   ├── AltitudeService.swift        # 海拔服务
│   └── DistanceCalculator.swift     # 距离计算工具
└── Extensions/                  # 扩展
    └── CLLocation+Extensions.swift  # CLLocation 便捷扩展
```

---

## 🚀 快速开始

### 1. 添加到 Xcode 项目

**方法 A: 使用 Ruby 脚本（推荐）**

```bash
cd TimeProof
gem install xcodeproj  # 如果没有安装
ruby scripts/add_locationkit_to_xcode.rb
```

**方法 B: 手动添加**

1. 打开 `TimeProof.xcworkspace`
2. 在 Project Navigator 中右键 `TimeProof` 组
3. 选择 "Add Files to TimeProof..."
4. 选择 `TimeProof/LocationKit` 整个文件夹
5. 勾选 "Create groups" 和 "Add to targets: TimeProof"

### 2. 基本使用

```swift
import CoreLocation

// 获取位置管理器单例
let locationManager = LocationManager.shared

// 订阅位置更新
locationManager.locationPublisher
    .sink { location in
        print("新位置: \(location.coordinate)")
        print("海拔: \(location.altitude)m")
    }
    .store(in: &cancellables)

// 开始更新位置
locationManager.startUpdatingLocation()

// 获取当前坐标
if let coordinate = locationManager.coordinate {
    print("当前坐标: \(coordinate)")
}

// 获取当前海拔
if let altitude = locationManager.altitude {
    print("当前海拔: \(altitude)m")
}
```

### 3. 地理编码

```swift
let geocodingService = GeocodingService.shared

// 逆向地理编码（坐标 → 地址）
Task {
    do {
        let location = CLLocation(latitude: 39.9042, longitude: 116.4074)
        let address = try await geocodingService.reverseGeocode(location: location)
        print("城市: \(address.locality ?? "")")
        print("地区: \(address.subLocality ?? "")")
    } catch {
        print("编码失败: \(error)")
    }
}

// 正向地理编码（地址 → 坐标）
Task {
    let locations = try await geocodingService.forwardGeocode(address: "北京市天安门")
    if let first = locations.first {
        print("坐标: \(first.coordinate)")
    }
}
```

### 4. 海拔服务

```swift
let altitudeService = AltitudeService.shared

// 获取当前海拔（实时）
if let altitude = altitudeService.currentAltitude {
    print("海拔: \(altitude)m")
}

// 获取格式化的海拔字符串
let formatted = altitudeService.formattedAltitude
print("海拔: \(formatted)")  // 例: "158m" 或 "N/A"

// 订阅海拔变化
altitudeService.altitudePublisher
    .sink { altitude in
        print("海拔更新: \(altitude)m")
    }
    .store(in: &cancellables)
```

### 5. 距离计算

```swift
// 两点之间的距离
let distance = DistanceCalculator.distance(
    from: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
    to: CLLocationCoordinate2D(latitude: 31.2, longitude: 121.5)
)
print("距离: \(distance)m")

// 格式化距离
let formatted = DistanceCalculator.formattedDistance(distanceInMeters: 1500)
print(formatted)  // "1.5 km"

// 判断是否在范围内
let isNearby = DistanceCalculator.isWithinRadius(
    from: location1,
    to: location2,
    radius: 1000  // 1km
)
```

---

## 🔧 API 参考

### LocationManager

| 属性/方法 | 说明 |
|----------|------|
| `shared` | 单例实例 |
| `coordinate` | 当前坐标 (CLLocationCoordinate2D?) |
| `altitude` | 当前海拔 (Double?) |
| `currentLocation` | 当前位置 (CLLocation?) |
| `isAuthorized` | 是否已授权 |
| `locationPublisher` | 位置更新 Publisher |
| `startUpdatingLocation()` | 开始持续更新 |
| `stopUpdatingLocation()` | 停止更新 |
| `requestLocationUpdate()` | 请求单次更新 |
| `requestPermission(type:)` | 请求权限 |

### GeocodingService

| 属性/方法 | 说明 |
|----------|------|
| `shared` | 单例实例 |
| `reverseGeocode(location:)` | 坐标 → 地址 |
| `forwardGeocode(address:)` | 地址 → 坐标列表 |
| `clearCache()` | 清除缓存 |

### AltitudeService

| 属性/方法 | 说明 |
|----------|------|
| `shared` | 单例实例 |
| `currentAltitude` | 当前海拔 (Double?) |
| `formattedAltitude` | 格式化海拔字符串 |
| `altitudePublisher` | 海拔更新 Publisher |

---

## 📦 迁移指南

### 从旧 LocationService 迁移

**旧代码:**
```swift
// 旧方式
let locationService = LocationService()
let coordinate = locationService.coordinate
locationService.publisher.sink { ... }
```

**新代码:**
```swift
// 新方式 - 使用 LocationKit
let locationManager = LocationManager.shared
let coordinate = locationManager.coordinate
locationManager.locationPublisher.sink { location in
    // 使用 location.coordinate
}
```

### 迁移对照表

| 旧 API (LocationService) | 新 API (LocationKit) |
|--------------------------|----------------------|
| `LocationService()` | `LocationManager.shared` |
| `locationService.coordinate` | `locationManager.coordinate` |
| `locationService.altitude` | `locationManager.altitude` |
| `locationService.publisher` | `locationManager.locationPublisher` |
| `CLGeocoder().reverseGeocodeLocation` | `GeocodingService.shared.reverseGeocode` |

### 逐步迁移策略

1. **第一阶段**: 添加 LocationKit 到项目（当前阶段）
2. **第二阶段**: 新功能使用 LocationKit API
3. **第三阶段**: 逐步将旧代码迁移到 LocationKit
4. **第四阶段**: 移除旧的 LocationService（当所有依赖迁移完成）

---

## ⚠️ 注意事项

### Info.plist 权限配置

确保 `Info.plist` 中包含以下权限描述：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>用于在水印中显示您的位置信息</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>用于在水印中显示您的位置信息</string>
```

### 线程安全

- `LocationManager` 使用 `@MainActor` 确保主线程安全
- 所有 Publisher 都在主线程发送事件
- 异步方法（async/await）可以在任意线程调用

### 内存管理

```swift
// 正确: 使用 weak self 避免循环引用
locationManager.locationPublisher
    .sink { [weak self] location in
        self?.handleLocation(location)
    }
    .store(in: &cancellables)

// 不再需要位置更新时停止
locationManager.stopUpdatingLocation()
```

---

## 🔮 后续规划

- [ ] 添加地理围栏支持
- [ ] 支持后台位置更新
- [ ] 添加位置历史记录
- [ ] 抽取为独立 Swift Package
- [ ] 添加单元测试

---

## 🔍 附近地点搜索 API (Nearby Search)

### 搜索附近地点

```swift
// 搜索附近 500 米内的餐厅
let places = try await LocationKit.shared.searchNearbyPlaces(
    keyword: "restaurant",
    radius: 500,
    limit: 10
)

for place in places {
    print("\(place.name) - \(place.distanceString ?? "?")")
    print("  地址: \(place.address ?? "N/A")")
    print("  类别: \(place.category ?? "Unknown")")
}
```

### 简化 API

```swift
// 简化版本，默认当前位置
let cafes = try await LocationKit.shared.searchNearby(keyword: "cafe", radius: 1000)
```

### 带元数据的搜索结果

```swift
let result = try await LocationKit.shared.searchNearbyWithResult(
    radius: 500,
    keyword: "convenience store"
)
print("是否来自缓存: \(result.isFromCache)")
print("搜索半径: \(result.searchRadius)m")
print("找到: \(result.places.count) 个地点")
```

### 地址自动补全

```swift
// 用户输入 "星巴克"
let completions = try await LocationKit.shared.searchAddressCompletions(query: "星巴克")
for completion in completions {
    print("\(completion.title) - \(completion.subtitle ?? "")")
}

// 获取地点详情
if let place = try await LocationKit.shared.getPlaceDetails(from: completions.first!) {
    print("地址: \(place.address ?? "N/A")")
    print("坐标: \(place.coordinate.latitude), \(place.coordinate.longitude)")
}
```

### NearbyPlace 数据模型

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识符 |
| `name` | String | POI 名称 |
| `location` | CLLocation | 位置坐标 |
| `distance` | Double? | 距离（米） |
| `distanceString` | String? | 格式化距离 (如 "500 m", "1.2 km") |
| `address` | String? | 完整地址 |
| `city` | String? | 城市 |
| `street` | String? | 街道 |
| `category` | String? | POI 类别 |

### 缓存策略

- **缓存 TTL**: 15 分钟
- **最大缓存数**: 50 条
- **缓存 Key**: 坐标 + 半径 + 关键词

---

**版本**: 1.1  
**最后更新**: 2026-02-01  
**维护者**: TimeProof iOS Team
