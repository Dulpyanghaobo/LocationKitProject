# LocationKit

[![Version](https://img.shields.io/cocoapods/v/LocationKitProject.svg?style=flat)](https://cocoapods.org/pods/LocationKitProject)
[![License](https://img.shields.io/cocoapods/l/LocationKitProject.svg?style=flat)](https://cocoapods.org/pods/LocationKitProject)
[![Platform](https://img.shields.io/cocoapods/p/LocationKitProject.svg?style=flat)](https://cocoapods.org/pods/LocationKitProject)

A **high-performance, layered architecture** location component for iOS with **WeatherKit integration** and **smart burst-mode caching**. Designed for watermark camera and travel camera scenarios.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🏗️ **Facade Pattern** | Single entry point via `LocationKit.shared` — no need to manage multiple services |
| 📸 **Smart Burst Cache** | Reuses geo-data within 20m/120s, but auto-updates timestamps for burst photography |
| 🌤️ **WeatherKit Integration** | Real Apple Weather data with automatic mock fallback on simulator |
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

### 2. Basic Usage

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

### 4. Binding to UI

```swift
func updateWatermarkUI(with context: CameraLocationContext) {
    // Direct UI binding - no transformation needed
    titleLabel.text = context.display.title
    subtitleLabel.text = context.display.subtitle
    weatherLabel.text = context.display.weatherStr
    timeLabel.text = context.display.timeStr
    
    // Weather icon (SF Symbol)
    if let weather = context.raw.weather {
        weatherIcon.image = UIImage(systemName: weather.iconName)
    }
    
    // ⚠️ IMPORTANT: Display Apple Weather attribution
    if let logoURL = context.raw.weather?.attributionLogoURL {
        loadAttributionLogo(from: logoURL)
    }
}
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
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### WeatherKit Capability (For Real Weather Data)

1. In **Xcode** → Select your target → **Signing & Capabilities**
2. Click **+ Capability** → Add **WeatherKit**
3. Ensure your **App ID** has WeatherKit enabled in [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers)

> ⚠️ **Note**: WeatherKit requires a paid Apple Developer account and is NOT available on simulator. The library automatically falls back to `MockWeatherService` on simulator.

---

## 📊 Data Models

### `CameraLocationContext`

The main return type containing everything needed for a camera watermark:

```swift
public struct CameraLocationContext {
    // UI-ready display strings
    var display: Display {
        let title: String          // "Beijing, Chaoyang"
        let subtitle: String       // "Sanlitun SOHO"
        let weatherStr: String     // "Sunny 25°C"
        var timeStr: String        // "2026-01-31 18:30:00" (mutable for cache)
        let altitudeStr: String    // "50.0 m"
        let coordinateStr: String  // "39.9042°N, 116.4074°E"
    }
    
    // Raw underlying data
    var raw: Raw {
        let location: CLLocation
        let address: GeocodedAddress?
        let poiList: [POIItem]
        var timestamp: Date
        let weather: WeatherInfo?
    }
    
    // Status flags
    var flags: Flags {
        var isCache: Bool           // From burst cache?
        let isMock: Bool            // Using mock weather?
        let weatherTimedOut: Bool   // Weather request timed out?
        let scene: LocationScene    // .work or .travel
        let mode: LocationMode      // .fast or .accurate
    }
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

**Example Burst Test:**
```
Call #1: 🔄 CACHE MISS  TimeStr: "2026-01-31 18:30:00"
Call #2: ✅ CACHE HIT   TimeStr: "2026-01-31 18:30:01"  
Call #3: ✅ CACHE HIT   TimeStr: "2026-01-31 18:30:02"
Call #4: ✅ CACHE HIT   TimeStr: "2026-01-31 18:30:03"
Call #5: ✅ CACHE HIT   TimeStr: "2026-01-31 18:30:04"
```

---

## 🧪 Testing & Mocking

### Dependency Injection for Tests

```swift
// Create a custom mock weather service
let mockWeather = MockWeatherService()

// Inject into LocationKit
let testKit = LocationKit(
    locationManager: .shared,
    geocodingService: .shared,
    altitudeService: .shared,
    weatherService: mockWeather  // Inject mock
)

// Now use testKit for testing
let context = try await testKit.fetchCameraContext(scene: .work, mode: .fast)
XCTAssertTrue(context.flags.isMock)
```

### Configure Mock Behavior

```swift
let mockWeather = MockWeatherService()
await mockWeather.setDelayRange(0.1...0.5)  // Fast responses
await mockWeather.setSimulateFailures(true, probability: 0.3)  // 30% failure rate
```

---

## ❓ FAQ

### Q: Why does my app crash on simulator with "WeatherKit not available"?

**A:** WeatherKit requires device entitlements and cannot run on simulator. LocationKit automatically detects this and uses `MockWeatherService` instead. If you see this error, ensure you're using `LocationKit.shared` (which handles this automatically) rather than instantiating `AppleWeatherService` directly.

### Q: Does the cache update the timestamp?

**A:** **Yes!** This is a key feature. When cache hits occur:
- Geographic data (address, weather, POI) is reused
- But `timeStr` and `timestamp` are **always updated** to current time
- This ensures each photo in a burst sequence has a unique timestamp

### Q: How do I display the Apple Weather attribution?

**A:** Apple requires displaying their logo when using WeatherKit data. Use the provided URLs:

```swift
if let weather = context.raw.weather {
    // Load and display the Apple Weather logo
    if let logoURL = weather.attributionLogoURL {
        loadImage(from: logoURL) { image in
            self.attributionImageView.image = image
        }
    }
    
    // Make the legal page accessible
    if let legalURL = weather.attributionURL {
        self.attributionButton.addAction(UIAction { _ in
            UIApplication.shared.open(legalURL)
        }, for: .touchUpInside)
    }
}
```

### Q: What happens if weather request times out?

**A:** The weather request has a 3-second timeout (circuit breaker). If it times out:
- `context.flags.weatherTimedOut` will be `true`
- `context.display.weatherStr` will be `"-- 0°C"`
- Other data (location, address, POI) will still be available

### Q: Can I clear the cache manually?

**A:** Yes:
```swift
LocationKit.shared.clearCache()
```

### Q: How do I check current cache status?

**A:**
```swift
let status = LocationKit.shared.cacheStatus
print("Has cache: \(status.hasCache)")
print("Last time: \(status.lastTime?.description ?? "none")")
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