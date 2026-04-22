[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingDeviceProfile

The Device Profile module provides a structured framework for collecting device information in
iOS applications. It uses a modular collector system that makes it easy to gather, extend, and
customize the device data you need with modern Swift async/await patterns.

## Getting Started

### Prerequisites

- Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
- iOS 16.0+
- Swift 6.0+
- Xcode 15+

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

Then add the `PingDeviceProfile` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingDeviceProfile', '~> <version>'
```

### Import the Module

```swift
import PingDeviceProfile
```

### Permissions

The module respects iOS's permission model. Some collectors may require specific permissions:

```xml
<!-- Required in Info.plist for LocationCollector -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to enhance security and provide personalized experiences.</string>

<!-- Optional: For always-on location access -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to enhance security and provide personalized experiences.</string>

<!-- Note: LocationCollector handles permission requests automatically -->
```

### Basic Usage

1. **Add the module dependency** to your project as described above.

2. **Create collectors** and collect device information:

```swift
func collectDeviceProfile() async {
    // Initialize collectors with default set
    let collectors = DefaultDeviceCollector.defaultDeviceCollectors()

    do {
        // Collect device information
        let deviceProfile = try await collectors.collect()
        
        // Use the collected profile (Dictionary)
        print("Device Profile: \(deviceProfile)")
    } catch {
        print("Collection failed: \(error)")
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI

struct ContentView: View {
    @State private var deviceProfile: [String: Any] = [:]
    @State private var isCollecting = false
    
    var body: some View {
        VStack {
            if isCollecting {
                ProgressView("Collecting device information...")
            } else {
                Button("Collect Device Profile") {
                    Task {
                        await collectProfile()
                    }
                }
            }
        }
    }
    
    private func collectProfile() async {
        isCollecting = true
        defer { isCollecting = false }
        
        let collectors = DefaultDeviceCollector.defaultDeviceCollectors()
        
        do {
            deviceProfile = try await collectors.collect()
        } catch {
            print("Collection error: \(error)")
        }
    }
}
```

### Example Output

```json
{
  "platform": {
    "platform": "iOS",
    "version": "17.0.1",
    "device": "iPhone",
    "deviceName": "John's iPhone",
    "model": "iPhone15,2",
    "brand": "Apple",
    "locale": "en",
    "timeZone": "America/New_York",
    "jailBreakScore": 0.0
  },
  "hardware": {
    "manufacturer": "Apple",
    "memory": 6144,
    "cpu": 6,
    "display": {
      "width": 393,
      "height": 852,
      "orientation": 1
    },
    "camera": {
      "numberOfCameras": 3
    }
  },
  "network": {
    "connected": true
  },
  "telephony": {
    "networkCountryIso": "US",
    "carrierName": "Verizon"
  },
  "browser": {
    "userAgent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15..."
  },
  "bluetooth": {
    "supported": true
  }
}
```

---

## Built-in Collectors

The module provides several built-in collectors out of the box:

### PlatformCollector
Gathers platform and device identification information:
```json
{
   "platform": {
      "platform": "iOS",
      "version": "17.0.1",
      "device": "iPhone",
      "deviceName": "John's iPhone",
      "model": "iPhone15,2",
      "brand": "Apple",
      "locale": "en",
      "timeZone": "America/New_York",
      "jailBreakScore": 0.0
   }
}
```

### HardwareCollector
Collects comprehensive hardware specifications:
```json
{
   "hardware": {
      "manufacturer": "Apple",
      "memory": 6144,
      "cpu": 6,
      "display": {
         "width": 393,
         "height": 852,
         "orientation": 1
      },
      "camera": {
         "numberOfCameras": 3
      }
   }
}
```

### NetworkCollector
Determines current network connectivity status:
```json
{
   "network": {
      "connected": true
   }
}
```

### TelephonyCollector
Collects carrier and network information with multi-SIM support:
```json
{
   "telephony": {
      "networkCountryIso": "US", 
      "carrierName": "Verizon"
   }
}
```

### BrowserCollector
Collects WebKit user agent information:
```json
{
   "browser": {
      "userAgent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15..."
   }
}
```

### BluetoothCollector
Detects Bluetooth Low Energy capability:
```json
{
   "bluetooth": {
      "supported": true
   }
}
```

### LocationCollector
Collects GPS coordinates with automatic permission handling:
```json
{
   "location": {
      "latitude": 37.7749,
      "longitude": -122.4194
   }
}
```

**Location Privacy Features:**
- Automatically requests permissions when needed
- Handles both "when in use" and "always" authorization types
- Gracefully handles permission denials
- Includes intelligent caching (5-second validity)
- Returns nil if location is unavailable or denied

---

## Customization

### Using Built-in Collectors

The module comes with several built-in collectors that you can use:

```swift
// Use all default collectors
let collectors = DefaultDeviceCollector.defaultDeviceCollectors()

// Or manually select specific collectors
let customCollectors: [any DeviceCollector] = [
    PlatformCollector(),
    HardwareCollector(),
    NetworkCollector(),
    TelephonyCollector(),
    BrowserCollector(),
    BluetoothCollector()
    // LocationCollector() // Add separately if needed
]
```

### Creating Custom Collectors

You can create your own collectors to gather specific device information:

```swift
struct BatteryCollector: DeviceCollector {
    typealias DataType = BatteryInfo
    
    let key = "battery"
    
    func collect() async throws -> BatteryInfo? {
        return BatteryInfo(
            level: UIDevice.current.batteryLevel,
            state: UIDevice.current.batteryState.rawValue
        )
    }
}

struct BatteryInfo: Codable {
    let level: Float
    let state: Int
}
```

---

## AIC Journey Integration

The `DeviceProfileCallback` class provides a specialized way to collect device information
specifically for integration with AIC Journeys. It creates device profiles in the format expected by
AIC Journeys and integrates seamlessly with the Ping Journey framework.

### Setup

PingJourney module will automatically register DeviceProfileCallback if PingDeviceProfile module is imported

### Basic Usage with DeviceProfileCallback

When the server requests device profiling during a journey, the callback will automatically be created and configured:

```swift
// This happens automatically within a Ping Journey flow
// The callback receives server configuration for metadata and location collection

// Collect with default collectors
let result = await callback.collect()
```

### Customizing AIC Journey Device Profile Collection

You can customize which collectors are used during the callback collection:

```swift
let result = await deviceProfileCallback.collect { config in
    // Configure custom collectors for enhanced AIC risk assessment
    config.collectors {
        return [
            PlatformCollector(),
            HardwareCollector(),
            NetworkCollector(),
            BrowserCollector(),
            BluetoothCollector(),
            SecurityCollector() // Custom collector
        ]
    }
}

// Handle the result
result
    .onSuccess { profile in
        // Device profile automatically submitted to AIC service
        print("Profile collected successfully")
    }
    .onFailure { error in
        print("Collection failed: \(error)")
    }
```

### AIC Profile Structure

When using `DeviceProfileCallback`, the output is structured specifically for AIC consumption:

```json
{
  "identifier": "unique-device-id",
  "metadata": {
    "platform": {
      "platform": "iOS",
      "version": "17.0.1",
      "device": "iPhone"
    },
    "hardware": {
      "manufacturer": "Apple",
      "memory": 6144,
      "cpu": 6
    },
    "network": {
      "connected": true
    }
  },
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194
  }
}
```

### Server Configuration

The server can configure what data to collect:

- **metadata**: Controls whether device metadata should be collected
- **location**: Controls whether location data should be collected
- **message**: Optional message with instructions or context

```swift
// These properties are automatically set based on server configuration
print("Metadata collection: \(callback.metadata)")
print("Location collection: \(callback.location)")
print("Server message: \(callback.message)")
```

---

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
