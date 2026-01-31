# LocationKit AI Skill Pack

> **Purpose**: This document serves as the core knowledge base for AI assistants (Claude, Cursor, etc.) to understand and correctly use the LocationKit library.

---

## 🧠 Mental Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              YOUR APP                                   │
│                                 │                                       │
│                                 ▼                                       │
│    ┌────────────────────────────────────────────────────────────────┐   │
│    │                    LocationKit.shared                          │   │
│    │                     (FACADE LAYER)                             │   │
│    │                                                                │   │
│    │   ┌──────────────────────────────────────────────────────┐    │   │
│    │   │  fetchCameraContext(scene:mode:) -> CameraContext    │    │   │
│    │   │  fetchWorkContext()              -> CameraContext    │    │   │
│    │   │  fetchTravelContext()            -> CameraContext    │    │   │
│    │   │  fetchBurstContext()             -> CameraContext    │    │   │
│    │   └──────────────────────────────────────────────────────┘    │   │
│    │                           │                                    │   │
│    │           ┌───────────────┼───────────────┐                    │   │
│    │           ▼               ▼               ▼                    │   │
│    │   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │   │
│    │   │   Weather   │ │  Geocoding  │ │    Core     │              │   │
│    │   │   Service   │ │   Service   │ │  Location   │              │   │
│    │   │             │ │             │ │   Manager   │              │   │
│    │   │ WeatherKit  │ │ CLGeocoder  │ │CLLocation-  │              │   │
│    │   │   + Mock    │ │  + Cache    │ │  Manager    │              │   │
│    │   └─────────────┘ └─────────────┘ └─────────────┘              │   │
│    │        ⚠️              ⚠️              ⚠️                       │   │
│    │   INTERNAL ONLY   INTERNAL ONLY   INTERNAL ONLY                │   │
│    └────────────────────────────────────────────────────────────────┘   │
│                                 │                                       │
│                                 ▼                                       │
│                    CameraLocationContext                                │
│              ┌──────────────────────────────────┐                       │
│              │  display: Display                │                       │
│              │    ├─ title: String              │  ← UI Ready           │
│              │    ├─ subtitle: String           │                       │
│              │    ├─ weatherStr: String         │                       │
│              │    ├─ timeStr: String            │                       │
│              │    ├─ altitudeStr: String        │                       │
│              │    └─ coordinateStr: String      │                       │
│              │                                  │                       │
│              │  raw: Raw                        │                       │
│              │    ├─ location: CLLocation       │  ← Raw Data           │
│              │    ├─ address: GeocodedAddress?  │                       │
│              │    ├─ poiList: [POIItem]         │                       │
│              │    ├─ timestamp: Date            │                       │
│              │    └─ weather: WeatherInfo?      │                       │
│              │                                  │                       │
│              │  flags: Flags                    │                       │
│              │    ├─ isCache: Bool              │  ← Status Info        │
│              │    ├─ isMock: Bool               │                       │
│              │    ├─ weatherTimedOut: Bool      │                       │
│              │    ├─ scene: LocationScene       │                       │
│              │    └─ mode: LocationMode         │                       │
│              └──────────────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────┘

LEGEND:
  ───────────────────────────────────────────────────
  LocationKit.shared    = ✅ THE ONLY ENTRY POINT
  Internal Services     = ⛔ NEVER ACCESS DIRECTLY
  CameraLocationContext = 📦 THE RETURN TYPE
  ───────────────────────────────────────────────────
```

---

## 🔑 Core Concepts

### 1. Burst Cache (Smart Caching for Burst Photography)

```
┌────────────────────────────────────────────────────────────────────┐
│                     BURST CACHE ALGORITHM                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  CACHE HIT CONDITIONS:                                             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Distance from last location  <  20 meters                   │  │
│  │                    AND                                       │  │
│  │  Time since last fetch        <  120 seconds                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ON CACHE HIT:                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  ✅ REUSE: address, weather, POI data                        │  │
│  │  ✅ UPDATE: timestamp, timeStr (always current)              │  │
│  │  ✅ FLAG: context.flags.isCache = true                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  PURPOSE: Optimize burst photography scenarios where user takes    │
│           multiple photos rapidly in the same location.            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

**Example Flow:**
```
Photo 1  →  CACHE MISS  →  Full fetch  →  timeStr: "18:30:00"
Photo 2  →  CACHE HIT   →  Reuse data  →  timeStr: "18:30:01" (updated!)
Photo 3  →  CACHE HIT   →  Reuse data  →  timeStr: "18:30:02" (updated!)
Photo 4  →  CACHE HIT   →  Reuse data  →  timeStr: "18:30:03" (updated!)
...
```

### 2. Smart Timestamp (Always Current, Even from Cache)

The `timeStr` and `timestamp` fields are **ALWAYS** updated to the current time, even when data is served from cache. This ensures:

- Each photo in a burst sequence has a **unique timestamp**
- EXIF data is always accurate
- Watermark displays real capture time, not cached time

```swift
// This is what happens internally:
func withUpdatedTimestamp() -> CameraLocationContext {
    var newDisplay = self.display
    newDisplay.timeStr = Self.formatTime(Date())  // ← ALWAYS NOW
    
    var newRaw = self.raw
    newRaw.timestamp = Date()  // ← ALWAYS NOW
    
    var newFlags = self.flags
    newFlags.isCache = true  // ← Indicates data was cached
    
    return CameraLocationContext(display: newDisplay, raw: newRaw, flags: newFlags)
}
```

---

## 🚨 Critical Rules (The "Must Do's")

### Rule 1: STRICT FACADE USAGE

```swift
// ⛔ FORBIDDEN - NEVER DO THIS
import CoreLocation
let manager = CLLocationManager()  // ❌
let manager = LocationManager()    // ❌
let geo = GeocodingService.shared  // ❌
let weather = AppleWeatherService.shared  // ❌

// ✅ CORRECT - ALWAYS DO THIS
import LocationKitProject
let context = try await LocationKit.shared.fetchCameraContext(scene: .work, mode: .fast)
```

**Why?** The Facade orchestrates:
- Concurrent data fetching (weather, geocoding, POI in parallel)
- Smart caching logic
- Timeout protection (3s circuit breaker for weather)
- Mock service fallback on simulator

### Rule 2: ASYNC/AWAIT ONLY

```swift
// ⛔ WRONG - Completion handlers
LocationKit.shared.fetch { result in ... }  // ❌ Does not exist

// ⛔ WRONG - Combine
LocationKit.shared.contextPublisher  // ❌ Does not exist

// ✅ CORRECT - async/await
Task {
    let context = try await LocationKit.shared.fetchCameraContext(scene: .work, mode: .fast)
}
```

### Rule 3: WEATHERKIT LEGAL COMPLIANCE ⚖️

**Apple requires attribution when displaying WeatherKit data.** This is NOT optional.

```swift
// ✅ MANDATORY - Display Apple Weather attribution
func displayWeather(context: CameraLocationContext) {
    // Show weather data
    weatherLabel.text = context.display.weatherStr
    
    // REQUIRED: Show Apple Weather logo
    if let logoURL = context.raw.weather?.attributionLogoURL {
        AsyncImage(url: logoURL) { image in
            image.resizable().scaledToFit()
        }
        .frame(height: 20)
    }
    
    // REQUIRED: Provide access to legal page
    if let legalURL = context.raw.weather?.attributionURL {
        Link("Weather data", destination: legalURL)
    }
}
```

**Failure to comply may result in App Store rejection or legal action.**

---

## 📝 Code Patterns

### Pattern 1: Standard Usage

```swift
import LocationKitProject

class PhotoCaptureService {
    
    /// Fetch location context for photo watermark
    func captureWithLocation() async throws -> CameraLocationContext {
        // One line - that's it!
        return try await LocationKit.shared.fetchCameraContext(
            scene: .travel,   // or .work
            mode: .accurate   // or .fast
        )
    }
    
    /// Convenience for work scenarios
    func fetchForWatermark() async throws -> CameraLocationContext {
        return try await LocationKit.shared.fetchWorkContext()
    }
    
    /// Convenience for travel scenarios  
    func fetchForTravel() async throws -> CameraLocationContext {
        return try await LocationKit.shared.fetchTravelContext()
    }
    
    /// Optimized for burst shooting
    func fetchForBurst() async throws -> CameraLocationContext {
        return try await LocationKit.shared.fetchBurstContext()
    }
}
```

### Pattern 2: UI Binding (UIKit)

```swift
import UIKit
import LocationKitProject

class WatermarkViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var weatherLabel: UILabel!
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var attributionImageView: UIImageView!
    
    func refreshLocation() {
        Task {
            do {
                let context = try await LocationKit.shared.fetchCameraContext(
                    scene: .work,
                    mode: .fast
                )
                await MainActor.run {
                    bindToUI(context)
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    
    private func bindToUI(_ context: CameraLocationContext) {
        // ✅ Use display properties - they're pre-formatted
        titleLabel.text = context.display.title
        subtitleLabel.text = context.display.subtitle
        weatherLabel.text = context.display.weatherStr
        timeLabel.text = context.display.timeStr
        
        // Weather icon (SF Symbol)
        if let weather = context.raw.weather {
            weatherIcon.image = UIImage(systemName: weather.iconName)
        }
        
        // ⚠️ REQUIRED: Weather attribution
        if let logoURL = context.raw.weather?.attributionLogoURL {
            loadImage(from: logoURL) { [weak self] image in
                self?.attributionImageView.image = image
            }
        }
    }
}
```

### Pattern 3: UI Binding (SwiftUI)

```swift
import SwiftUI
import LocationKitProject

struct LocationWatermarkView: View {
    @State private var context: CameraLocationContext?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ctx = context {
                // Main info
                Text(ctx.display.title)
                    .font(.headline)
                Text(ctx.display.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Weather
                HStack {
                    if let weather = ctx.raw.weather {
                        Image(systemName: weather.iconName)
                    }
                    Text(ctx.display.weatherStr)
                }
                
                // Time
                Text(ctx.display.timeStr)
                    .font(.caption)
                
                // ⚠️ REQUIRED: Apple Weather attribution
                if let logoURL = ctx.raw.weather?.attributionLogoURL {
                    AsyncImage(url: logoURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        }
                    }
                    .frame(height: 20)
                }
                
                if let legalURL = ctx.raw.weather?.attributionURL {
                    Link("", destination: legalURL)
                }
            }
        }
        .task {
            await fetchLocation()
        }
    }
    
    private func fetchLocation() async {
        isLoading = true
        do {
            context = try await LocationKit.shared.fetchCameraContext(
                scene: .travel,
                mode: .accurate
            )
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
```

### Pattern 4: Error Handling

```swift
func fetchWithErrorHandling() async {
    do {
        let context = try await LocationKit.shared.fetchCameraContext(
            scene: .work,
            mode: .fast
        )
        // Success path
        updateUI(with: context)
        
    } catch let error as LocationKitError {
        // Handle specific errors
        switch error {
        case .locationServicesDisabled:
            showAlert("Please enable Location Services in Settings")
            
        case .permissionDenied:
            showAlert("Location permission denied. Tap to open Settings.")
            
        case .permissionRestricted:
            showAlert("Location access is restricted on this device")
            
        case .timeout:
            showAlert("Location request timed out. Please try again.")
            
        case .geocodingFailed, .geocodingNoResults:
            // Graceful degradation: show coordinates instead of address
            showCoordinateFallback()
            
        default:
            showAlert("An error occurred: \(error.localizedDescription)")
        }
        
    } catch {
        // Generic error
        showAlert("Unexpected error: \(error.localizedDescription)")
    }
}
```

---

## 🔧 Troubleshooting Checklist

### Issue: Location Permission Missing

**Symptoms:**
- `LocationKitError.permissionDenied` thrown
- `LocationKitError.permissionRestricted` thrown
- Location features don't work

**AI Self-Check:**
1. ☐ Is `NSLocationWhenInUseUsageDescription` in `Info.plist`?
2. ☐ Is `NSLocationAlwaysAndWhenInUseUsageDescription` in `Info.plist` (if background needed)?
3. ☐ Is permission requested before fetching location?
4. ☐ Is there UI to guide user to Settings if permission was denied?

**Quick Fix Code:**
```swift
// Check permission before fetching
if !LocationManager.shared.isAuthorized {
    let status = await LocationManager.shared.requestPermission(type: .whenInUse)
    guard status == .authorizedWhenInUse || status == .authorizedAlways else {
        // Show permission denied UI
        return
    }
}

let context = try await LocationKit.shared.fetchCameraContext(scene: .work, mode: .fast)
```

### Issue: WeatherKit Attribution Missing

**Symptoms:**
- App may face App Store rejection
- Legal compliance violation

**AI Self-Check:**
1. ☐ Is `attributionLogoURL` being loaded and displayed?
2. ☐ Is `attributionURL` accessible to users (link or button)?
3. ☐ Is the attribution visible when weather data is shown?
4. ☐ Is attribution shown in both light and dark mode?

**Quick Fix Code:**
```swift
// ALWAYS include this when showing weather
if let weather = context.raw.weather {
    // Show weather data
    Text(context.display.weatherStr)
    
    // REQUIRED: Attribution logo
    if let logoURL = weather.attributionLogoURL {
        AsyncImage(url: logoURL)
            .frame(height: 20)
    }
    
    // REQUIRED: Legal link
    if let legalURL = weather.attributionURL {
        Link("", destination: legalURL)
    }
}
```

### Issue: Cache Not Working as Expected

**Symptoms:**
- Every call triggers a full fetch
- Or cache never invalidates

**AI Self-Check:**
1. ☐ Is the device moving more than 20 meters between calls?
2. ☐ Is more than 120 seconds passing between calls?
3. ☐ Is `clearCache()` being called unnecessarily?
4. ☐ Check `context.flags.isCache` to verify cache status

**Debug Code:**
```swift
let context = try await LocationKit.shared.fetchCameraContext(scene: .work, mode: .fast)

// Check cache status
print("Is from cache: \(context.flags.isCache)")

// Check cache state
let status = LocationKit.shared.cacheStatus
print("Has cache: \(status.hasCache)")
print("Last cache time: \(status.lastTime?.description ?? "none")")
```

---

## 📊 Quick Reference Card

```
┌────────────────────────────────────────────────────────────────────┐
│                    LOCATIONKIT QUICK REFERENCE                      │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ENTRY POINT (The ONLY way to use LocationKit):                    │
│  ─────────────────────────────────────────────────                 │
│  LocationKit.shared.fetchCameraContext(scene:mode:)                │
│                                                                    │
│  SCENE OPTIONS:                                                    │
│  ─────────────────────────────────────────────────                 │
│  .work   → Watermark camera (address focus)                        │
│  .travel → Travel camera (POI & weather focus)                     │
│                                                                    │
│  MODE OPTIONS:                                                     │
│  ─────────────────────────────────────────────────                 │
│  .fast     → 5s timeout, speed priority                            │
│  .accurate → 15s timeout, accuracy priority                        │
│                                                                    │
│  CONVENIENCE METHODS:                                              │
│  ─────────────────────────────────────────────────                 │
│  fetchWorkContext()   → scene: .work, mode: .fast                  │
│  fetchTravelContext() → scene: .travel, mode: .accurate            │
│  fetchBurstContext()  → scene: .work, mode: .fast (cache optimized)│
│                                                                    │
│  CACHE MANAGEMENT:                                                 │
│  ─────────────────────────────────────────────────                 │
│  LocationKit.shared.clearCache()                                   │
│  LocationKit.shared.cacheStatus // (hasCache, lastTime)            │
│                                                                    │
│  UI BINDING (Always use display properties):                       │
│  ─────────────────────────────────────────────────                 │
│  context.display.title         // "Beijing, Chaoyang"              │
│  context.display.subtitle      // "Sanlitun SOHO"                  │
│  context.display.weatherStr    // "Sunny 25°C"                     │
│  context.display.timeStr       // "2026-01-31 18:30:00"            │
│  context.display.altitudeStr   // "50.0 m"                         │
│  context.display.coordinateStr // "39.9042°N, 116.4074°E"          │
│                                                                    │
│  STATUS FLAGS:                                                     │
│  ─────────────────────────────────────────────────                 │
│  context.flags.isCache         // Data from cache?                 │
│  context.flags.isMock          // Mock weather service?            │
│  context.flags.weatherTimedOut // Weather request timed out?       │
│                                                                    │
│  WEATHER ATTRIBUTION (LEGALLY REQUIRED):                           │
│  ─────────────────────────────────────────────────                 │
│  context.raw.weather?.attributionLogoURL  // Apple Weather logo    │
│  context.raw.weather?.attributionURL      // Legal page link       │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 🏷️ Version

- **LocationKit Version**: 1.0.0
- **Skill Pack Version**: 1.0.0
- **Last Updated**: 2026-01-31