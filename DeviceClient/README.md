[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingDeviceClient

PingDeviceClient module simplifies device management operations for Ping AIC. It provides a clean, type-safe, Result-based API for managing authentication devices including OATH, Push, Bound, Profile, and WebAuthn devices.

## Getting Started

### Prerequisites

- Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
- iOS 16.0+
- Swift 6.0+
- Xcode 15+

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

#### CocoaPods

```ruby
pod 'PingDeviceClient', '~> <version>'
```

### Import the Module

```swift
import PingDeviceClient
```

## Usage

### 2. Configure and Initialize

```swift
// Obtain session token from your authentication flow
let sessionToken = "AQIC5w..."  // From successful login

// Create configuration (minimal required parameters)
let config = DeviceClientConfig(
    serverUrl: "https://openam.example.com",
    ssoToken: sessionToken
)

// Initialize client
let deviceClient = DeviceClient(config: config)
```

### 3. Perform Operations with Result API

```swift
// Fetch devices - returns Result
let result = await deviceClient.oath.get()

switch result {
case .success(let devices):
    print("Found \(devices.count) OATH devices")
    for device in devices {
        print("- \(device.deviceName)")
    }
    
case .failure(let error):
    print("Error: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
}

// Update a device
if case .success(var devices) = await deviceClient.bound.get(),
   var device = devices.first {
    device.deviceName = "My Updated Device"
    
    let updateResult = await deviceClient.bound.update(device)
    if case .success = updateResult {
        print("Device updated successfully")
    }
}

// Delete a device
if case .success(let devices) = await deviceClient.oath.get(),
   let device = devices.first {
    let deleteResult = await deviceClient.oath.delete(device)
    if case .success = deleteResult {
        print("Device deleted successfully")
    }
}
```

## Configuration

### DeviceClientConfig

The configuration struct contains parameters needed for device management:

```swift
public struct DeviceClientConfig {
    /// Base URL of the ForgeRock/Ping server
    /// Example: "https://openam.example.com"
    let serverUrl: String
    
    /// Realm for authentication (default: "root")
    /// Example: "alpha", "root"
    let realm: String
    
    /// HTTP header name for session token (default: "iPlanetDirectoryPro")
    let cookieName: String
    
    /// SSO session token
    /// Must be valid and non-expired
    let ssoToken: String
    
    /// HTTP client (optional)
    let httpClient: HttpClient
}
```

### Configuration Examples

#### Basic Configuration (Using Defaults)

```swift
let config = DeviceClientConfig(
    serverUrl: "https://openam.example.com",
    ssoToken: sessionToken
)
// Uses defaults:
// - realm: "root"
// - cookieName: "iPlanetDirectoryPro"
```

#### Full Configuration

```swift
let config = DeviceClientConfig(
    serverUrl: "https://openam.example.com",
    realm: "alpha",
    cookieName: "iPlanetDirectoryPro",
    ssoToken: sessionToken
)
```

#### With Custom HTTP Client

```swift
let customHttpClient = HttpClient()
customHttpClient.timeoutIntervalForRequest = 30

let config = DeviceClientConfig(
    serverUrl: "https://openam.example.com",
    realm: "alpha",
    cookieName: "iPlanetDirectoryPro",
    ssoToken: sessionToken,
    httpClient: customHttpClient
)
```

### Automatic User ID Fetching

DeviceClient automatically fetches the user ID from the session endpoint on first use and caches it for subsequent requests. You don't need to provide or manage the user ID manually.

```swift
// First operation - fetches userId from session endpoint
let result1 = await deviceClient.oath.get()  // Makes 2 calls: session + devices

// Subsequent operations - uses cached userId
let result2 = await deviceClient.push.get()  // Makes 1 call: devices only
```

## Usage

### 1. Import the SDK

### Fetching Devices (Result API)

```swift
// Oath devices (authenticator apps)
let result = await deviceClient.oath.get()

switch result {
case .success(let devices):
    for device in devices {
        print("Device: \(device.deviceName)")
        print("  UUID: \(device.uuid)")
        print("  Created: \(Date(timeIntervalSince1970: device.createdDate))")
    }
    
case .failure(let error):
    handleError(error)
}

// Other device types
let pushResult = await deviceClient.push.get()
let boundResult = await deviceClient.bound.get()
let profileResult = await deviceClient.profile.get()
let webAuthnResult = await deviceClient.webAuthn.get()
```

### Updating Devices

All device types support updates:

```swift
// Update a Bound device
let fetchResult = await deviceClient.bound.get()

if case .success(var devices) = fetchResult,
   var device = devices.first {
    device.deviceName = "My iPhone 15"
    
    let updateResult = await deviceClient.bound.update(device)
    
    switch updateResult {
    case .success:
        print("Device updated successfully")
    case .failure(let error):
        print("Update failed: \(error.localizedDescription)")
    }
}

// Update a Profile device
if case .success(var devices) = await deviceClient.profile.get(),
   var device = devices.first {
    device.deviceName = "Updated Profile"
    
    let result = await deviceClient.profile.update(device)
    if case .success = result {
        print("Profile updated")
    }
}

// Update a WebAuthn device
if case .success(var devices) = await deviceClient.webAuthn.get(),
   var device = devices.first {
    device.deviceName = "YubiKey 5C"
    await deviceClient.webAuthn.update(device)
}
```

### Deleting Devices

All device types support deletion:

```swift
// Delete an Oath device
let fetchResult = await deviceClient.oath.get()

if case .success(let devices) = fetchResult,
   let device = devices.first {
    let deleteResult = await deviceClient.oath.delete(device)
    
    switch deleteResult {
    case .success:
        print("Device deleted")
    case .failure(let error):
        print("Delete failed: \(error)")
    }
}

// Delete other device types
await deviceClient.push.delete(pushDevice)
await deviceClient.bound.delete(boundDevice)
await deviceClient.profile.delete(profileDevice)
await deviceClient.webAuthn.delete(webAuthnDevice)
```

## Device Types

### Oath Device

```swift
struct OathDevice: Device {
    let id: String
    var deviceName: String      // Mutable
    let uuid: String
    let createdDate: TimeInterval
    let lastAccessDate: TimeInterval
    let urlSuffix: String
}

// Usage
let result = await client.oath.get()
if case .success(let devices) = result {
    for device in devices {
        print("\(device.deviceName): \(device.uuid)")
    }
}
```

### Push Device

```swift
struct PushDevice: Device {
    let id: String
    var deviceName: String      // Mutable
    let uuid: String
    let createdDate: TimeInterval
    let lastAccessDate: TimeInterval
    let urlSuffix: String
}
```

### Bound Device

```swift
struct BoundDevice: Device {
    let id: String
    var deviceName: String      // Mutable
    let deviceId: String
    let uuid: String
    let createdDate: TimeInterval
    let lastAccessDate: TimeInterval
    let urlSuffix: String
}
```

### Profile Device

```swift
struct ProfileDevice: Device {
    let id: String
    var deviceName: String      // Mutable
    let identifier: String
    let metadata: [String: any Sendable]  // Complex metadata
    let location: Location?
    let lastSelectedDate: TimeInterval
    let urlSuffix: String
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double
}

// Usage - Access metadata
let result = await client.profile.get()
if case .success(let devices) = result, let device = devices.first {
    print("Platform: \(device.metadata["platform"] as? String ?? "Unknown")")
    if let location = device.location {
        print("Location: \(location.latitude), \(location.longitude)")
    }
}
```

### WebAuthn Device

```swift
struct WebAuthnDevice: Device {
    let id: String
    var deviceName: String      // Mutable
    let credentialId: String
    let uuid: String
    let createdDate: TimeInterval
    let lastAccessDate: TimeInterval
    let urlSuffix: String
}
```

## Error Handling

### Result-Based Error Handling

All operations return `Result<Success, DeviceError>`:

```swift
let result = await deviceClient.oath.get()

switch result {
case .success(let devices):
    // Handle success
    processDevices(devices)
    
case .failure(let error):
    // Handle error
    switch error {
    case .networkError(let underlyingError):
        print("Network error: \(underlyingError.localizedDescription)")
        showOfflineMessage()
        
    case .requestFailed(let statusCode, let message):
        if statusCode == 401 {
            print("Session expired - please log in again")
            triggerReAuthentication()
        } else if statusCode == 404 {
            print("Device not found")
        } else {
            print("Server error \(statusCode): \(message)")
        }
        
    case .invalidToken(let message):
        print("Invalid token: \(message)")
        refreshToken()
        
    case .decodingFailed(let error):
        print("Failed to parse response: \(error)")
        reportBug()
        
    default:
        print("Error: \(error.localizedDescription)")
        if let suggestion = error.recoverySuggestion {
            print("Suggestion: \(suggestion)")
        }
    }
}
```

### DeviceError Types

```swift
public enum DeviceError: LocalizedError {
    case networkError(error: Error)
    case requestFailed(statusCode: Int, message: String)
    case invalidUrl(url: String)
    case decodingFailed(error: Error)
    case encodingFailed(message: String)
    case invalidResponse(message: String)
    case invalidToken(message: String)
    case missingConfiguration(message: String)
}
```

### Error Properties

```swift
// Each error provides:
error.errorDescription      // Main error message
error.failureReason        // Why the error occurred
error.recoverySuggestion   // How to fix it
```

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
