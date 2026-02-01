# LocationKit

[![Version](https://img.shields.io/cocoapods/v/LocationKitProject.svg?style=flat)](https://cocoapods.org/pods/LocationKitProject)
[![License](https://img.shields.io/cocoapods/l/LocationKitProject.svg?style=flat)](https://cocoapods.org/pods/LocationKitProject)
[![Platform](https://img.shields.io/cocoapods/p/LocationKitProject.svg?style=flat)](https://cocoapods.org/pods/LocationKitProject)

A **high-performance, layered architecture** location component for iOS with **WeatherKit integration**, **smart burst-mode caching**, and **address search capabilities**. Designed for watermark camera, travel camera, and address picker scenarios.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🏗️ **Facade Pattern** | Single entry point via `LocationKit.shared` — no need to manage multiple services |
| 📸 **Smart Burst Cache** | Reuses geo-data within 20m/120s, but auto-updates timestamps for burst photography |
| 🌤️ **WeatherKit Integration** | Real Apple Weather data with automatic mock fallback on simulator |
| 🔍 **Address Search** | Real-time address autocomplete with `MKLocalSearchCompleter` |
| 🏪 **Nearby POI** | Get nearby points of interest without keywords |
| 🧪 **Protocol-Based DI** | All services are protocol-based for easy unit testing and mocking |
| ⚡ **Modern Concurrency** | 100% `async/await` with `TaskGroup` for parallel data fetching |
| 🛡️ **Timeout Protection** | 3-second circuit breaker for weather requests to prevent UI blocking |

---

## 📁 Directory Structure

```
LocationKitProject/Classes/
├── Core/                           # Foundation layer
│   ├── LocationKitError.swift      # Unified error types
│   ├── LocationKitProtocols.swift  # Service protocols (DI interfaces)
│   ├── LocationManager.swift       # Core CLLocationManager wrapper
│   └── LocationModels.swift        # GeocodedAddress, LocationData, etc.
│
├── Features/                       # Business logic layer
│   ├── LocationKit.swift           # 🎯 Main Facade (entry point)
│   ├── LocationKit+Models.swift    # CameraLocationContext, Scene, Mode
│   ├── WeatherService.swift        # WeatherKit + MockWeatherService
│   ├── GeocodingService.swift      # Reverse geocoding with cache
│   ├── AddressSearchService.swift  # 🔍 Address search & POI
│   ├── NearbySearchService.swift   # Nearby places search
│   ├── NearbySearchModels.swift    # NearbyPlace model
│   ├── AltitudeService.swift       # Altitude formatting
│   └── DistanceCalculator.swift    # Distance utilities
│
└── Extensions/                     # Utility extensions
    └── CLLocation+Extensions.swift # Coordinate formatting helpers
```

---

## 🚀 Quick Start

### 1. Installation

**CocoaPods**
```ruby
pod 'LocationKitProject'
```

**Swift Package Manager**
```swift
dependencies: [
    .package(url: "https://github.com/Dulpyanghaobo/LocationKitProject.git", from: "1.0.0")
]
```

### 2. Basic Usage - Camera Context

```swift
import LocationKitProject

// ✅ RECOMMENDED: Use the Facade
let context = try await LocationKit.shared.fetchCameraContext(
    scene: .travel,  // or .work
    mode: .accurate  // or .fast
)

// Access display-ready data
print(context.display.title)       // "Beijing, Chaoyang"
print(context.display.subtitle)    // "Sanlitun SOHO"
print(context.display.weatherStr)  // "Sunny 25°C"
print(context.display.timeStr)     // "2026-01-31 18:30:00"
print(context.display.altitudeStr) // "50.0 m"
print(context.display.coordinateStr) // "39.9042°N, 116.4074°E"

// Check status flags
print(context.flags.isCache)       // true if from cache
print(context.flags.isMock)        // true on simulator
```

### 3. Convenience Methods

```swift
// Quick fetch for specific scenarios
let workContext = try await LocationKit.shared.fetchWorkContext()
let travelContext = try await LocationKit.shared.fetchTravelContext()

// Burst mode (for continuous shooting)
let burstContext = try await LocationKit.shared.fetchBurstContext()
```

---

## 🔍 Address Search API

### Real-time Search Autocomplete

Use this for "type-as-you-search" address input:

```swift
// Real-time search with callbacks
LocationKit.shared.searchAddressRealtime("星巴克") { results in
    // results: [AddressSearchResult]
    for result in results {
        print("\(result.title) - \(result.subtitle)")
    }
} onError: { error in
    print("Search error: \(error)")
}
```

### Async Search

```swift
// Async/await search
let results = try await LocationKit.shared.searchAddress(query: "星巴克")

for result in results {
    print("\(result.title) - \(result.subtitle)")
}

// Get full address details from a search result
if let firstResult = results.first {
    let addressInfo = try await LocationKit.shared.getAddressDetails(from: firstResult)
    print("Full address: \(addressInfo?.formattedAddress ?? "")")
    print("Coordinates: \(addressInfo?.latitude ?? 0), \(addressInfo?.longitude ?? 0)")
}
```

### Current Location Address

```swift
// Get address for current location
if let currentAddress = try await LocationKit.shared.getCurrentLocationAddress() {
    print("Name: \(currentAddress.name ?? "")")
    print("Address: \(currentAddress.formattedAddress)")
    print("City: \(currentAddress.city ?? "")")
    print("District: \(currentAddress.district ?? "")")
}
```

---

## 🏪 Nearby POI API

### Get Nearby Points of Interest

```swift
// Get all POI within 200 meters (no keyword needed)
let pois = try await LocationKit.shared.getNearbyPOI(radius: 200, limit: 20)

for poi in pois {
    print("\(poi.name ?? "Unknown") - \(poi.distanceString ?? "")")
    print("  Address: \(poi.formattedAddress)")
}
```

### Search POI by Keyword

```swift
// Search for specific type of POI
let cafes = try await LocationKit.shared.getPOIByKeyword("咖啡", radius: 500, limit: 10)

for cafe in cafes {
    print("\(cafe.name ?? "") - \(cafe.distanceString ?? "")")
}
```

### Get POI by Multiple Categories

```swift
// Search multiple categories at once
let categories = ["餐厅", "咖啡", "超市", "银行"]
let pois = await LocationKit.shared.getNearbyPOIByCategories(
    radius: 500,
    categories: categories,
    limitPerCategory: 5
)

for poi in pois {
    print("\(poi.name ?? "") [\(poi.category ?? "")] - \(poi.distanceString ?? "")")
}
```

---

## 📋 Default Address List (For Address Picker)

### Get Default Content (Current Location + POI + History)

Perfect for showing default content when the search box is empty:

```swift
// Get default addresses with nearby POI
let addresses = await LocationKit.shared.getDefaultAddressesWithPOI(
    nearbyRadius: 200,   // Search POI within 200m
    nearbyLimit: 10      // Max 10 POI
)

for address in addresses {
    if address.isCurrentLocation {
        print("📍 Current: \(address.name ?? address.formattedAddress)")
    } else if address.isFromHistory {
        print("🕐 History: \(address.name ?? address.formattedAddress)")
    } else {
        print("🏪 POI: \(address.name ?? "") - \(address.distanceString ?? "")")
    }
}
```

### Search History Management

```swift
// Add to search history
LocationKit.shared.addAddressToHistory(addressInfo)

// Get search history
let history = LocationKit.shared.getAddressSearchHistory()

// Clear all history
LocationKit.shared.clearAddressSearchHistory()
```

---

## 📊 Data Models

### `CameraLocationContext`

The main return type for camera watermark scenarios:

```swift
public struct CameraLocationContext {
    var display: Display {
        let title: String          // "Beijing, Chaoyang"
        let subtitle: String       // "Sanlitun SOHO"
        let weatherStr: String     // "Sunny 25°C"
        var timeStr: String        // "2026-01-31 18:30:00"
        let altitudeStr: String    // "50.0 m"
        let coordinateStr: String  // "39.9042°N, 116.4074°E"
    }
    
    var raw: Raw {
        let location: CLLocation
        let address: GeocodedAddress?
        let poiList: [POIItem]
        var timestamp: Date
        let weather: WeatherInfo?
    }
    
    var flags: Flags {
        var isCache: Bool
        let isMock: Bool
        let weatherTimedOut: Bool
        let scene: LocationScene
        let mode: LocationMode
    }
}
```

### `AddressSearchResult`

Result from address search autocomplete:

```swift
public struct AddressSearchResult {
    let title: String      // "星巴克咖啡(三里屯店)"
    let subtitle: String   // "北京市朝阳区三里屯路"
    var fullText: String   // Combined title + subtitle
}
```

### `AddressInfo`

Complete address information:

```swift
public struct AddressInfo {
    var name: String?           // "星巴克咖啡"
    var formattedAddress: String // Full formatted address
    var city: String?           // "北京市"
    var district: String?       // "朝阳区"
    var street: String?         // "三里屯路"
    var latitude: Double
    var longitude: Double
    var distance: Double?       // Distance in meters
    var distanceString: String? // "500 m" or "1.2 km"
    var category: String?       // POI category
    var isCurrentLocation: Bool
    var isFromHistory: Bool
}
```

### `LocationScene` & `LocationMode`

```swift
enum LocationScene {
    case work    // Watermark camera - focus on address & timestamps
    case travel  // Travel camera - focus on POI & weather
}

enum LocationMode {
    case fast     // 5s timeout, prioritize speed
    case accurate // 15s timeout, prioritize precision
}
```

---

## 🔄 Smart Burst Cache

The cache strategy is optimized for burst photography:

```
┌─────────────────────────────────────────────────────────┐
│                    CACHE LOGIC                          │
├─────────────────────────────────────────────────────────┤
│  Distance < 20m  AND  Time < 120s  →  CACHE HIT         │
│                                                         │
│  On CACHE HIT:                                          │
│  • Reuse: address, weather, POI data                    │
│  • Update: timestamp & timeStr (for photo EXIF)         │
│  • Flag: isCache = true                                 │
└─────────────────────────────────────────────────────────┘
```

---

## ⚙️ Configuration

### Required `Info.plist` Keys

```xml
<!-- Location Permission (Required) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to add geographic information to your photos.</string>

<!-- Optional: Background Location -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to track your travel route.</string>
```

### WeatherKit Capability

1. In **Xcode** → Select your target → **Signing & Capabilities**
2. Click **+ Capability** → Add **WeatherKit**
3. Ensure your **App ID** has WeatherKit enabled in Apple Developer Portal

> ⚠️ WeatherKit requires a paid Apple Developer account. The library automatically falls back to `MockWeatherService` on simulator.

---

## 🎨 UI Binding Example

### UIKit

```swift
func updateWatermarkUI(with context: CameraLocationContext) {
    titleLabel.text = context.display.title
    subtitleLabel.text = context.display.subtitle
    weatherLabel.text = context.display.weatherStr
    timeLabel.text = context.display.timeStr
    
    if let weather = context.raw.weather {
        weatherIcon.image = UIImage(systemName: weather.iconName)
    }
    
    // ⚠️ REQUIRED: Display Apple Weather attribution
    if let logoURL = context.raw.weather?.attributionLogoURL {
        loadAttributionLogo(from: logoURL)
    }
}
```

### SwiftUI

```swift
struct LocationWatermarkView: View {
    @State private var context: CameraLocationContext?
    
    var body: some View {
        VStack {
            if let ctx = context {
                Text(ctx.display.title).font(.headline)
                Text(ctx.display.subtitle).font(.subheadline)
                Text(ctx.display.weatherStr)
                Text(ctx.display.timeStr).font(.caption)
            }
        }
        .task {
            context = try? await LocationKit.shared.fetchTravelContext()
        }
    }
}
```

---

## 🧹 Cache Management

```swift
// Clear camera context cache
LocationKit.shared.clearCache()

// Clear nearby POI cache
LocationKit.shared.clearNearbyCache()

// Clear address search history
LocationKit.shared.clearAddressSearchHistory()

// Check cache status
let status = LocationKit.shared.cacheStatus
print("Has cache: \(status.hasCache)")
print("Last time: \(status.lastTime?.description ?? "none")")
```

---

## ❓ FAQ

### Q: Why does my app crash on simulator with "WeatherKit not available"?

**A:** WeatherKit cannot run on simulator. LocationKit automatically uses `MockWeatherService` instead when running on simulator.

### Q: Does the cache update the timestamp?

**A:** **Yes!** When cache hits occur, `timeStr` and `timestamp` are always updated to current time, ensuring each photo has a unique timestamp.

### Q: What happens if weather request times out?

**A:** The weather request has a 3-second timeout. If it times out:
- `context.flags.weatherTimedOut` will be `true`
- `context.display.weatherStr` will be `"-- 0°C"`
- Other data (location, address, POI) will still be available

### Q: How do I display the Apple Weather attribution?

**A:** Apple requires displaying their logo when using WeatherKit data:

```swift
if let logoURL = context.raw.weather?.attributionLogoURL {
    AsyncImage(url: logoURL).frame(height: 20)
}
if let legalURL = context.raw.weather?.attributionURL {
    Link("Weather", destination: legalURL)
}
```

---

## 📄 License

LocationKitProject is available under the MIT license. See the LICENSE file for more info.

---

## 👨‍💻 Author

Dulpyanghaobo

---

## 🙏 Acknowledgments

- Apple WeatherKit for weather data
- Apple CoreLocation for location services
- Apple MapKit for address search and POI