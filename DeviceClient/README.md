#  # DeviceClient - iOS SDK

Comprehensive device management SDK for Ping AIC, providing type-safe access to user device management operations.

## Overview

DeviceClient is a module that simplifies device management operations for Ping AIC. It provides a clean, type-safe API for managing authentication devices including OATH, Push, Bound, Profile, and WebAuthn devices.

## Features

### Supported Device Types

| Device Type | Operations | Description |
|-------------|------------|-------------|
| **Oath** | Read, Delete | TOTP/HOTP authenticator devices |
| **Push** | Read, Delete | Push notification devices |
| **Bound** | Read, Update, Delete | Device binding for 2FA |
| **Profile** | Read, Update, Delete | Device profiling data |
| **WebAuthn** | Read, Update, Delete | FIDO2/WebAuthn credentials |

### Dependencies

- `PingOrchestrate` - HTTP networking
- `PingLogger` - Logging infrastructure

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk", from: "<version>")
]
```

### CocoaPods

```ruby
pod 'PingDeviceClient', '~> <version>'
```

## Quick Start

### 1. Import the SDK

```swift
import PingDeviceClient
```

### 2. Configure and Initialize

```swift
// Obtain user ID and session token from your authentication flow
let userId = "demo"  // From authentication response or userinfo endpoint
let sessionToken = "AQIC5w..."  // From successful login

// Create configuration
let config = DeviceClientConfig(
    serverUrl: "https://openam.example.com",
    realm: "alpha",
    cookieName: "iPlanetDirectoryPro",
    userId: userId,
    ssoToken: sessionToken
)

// Initialize client
let deviceClient = DeviceClient(config: config)
```

### 3. Perform Operations

```swift
// Fetch devices
let oathDevices = try await deviceClient.oath.get()
print("Found \(oathDevices.count) OATH devices")

// Update a device (for mutable types)
if var device = boundDevices.first {
    device.deviceName = "My Updated Device"
    try await deviceClient.bound.update(device)
}

// Delete a device
try await deviceClient.oath.delete(oathDevices.first!)
```

## Configuration

### DeviceClientConfig

The configuration struct contains all parameters needed for device management:

```swift
public struct DeviceClientConfig {
    /// Base URL of the ForgeRock/Ping server
    let serverUrl: String
    
    /// Realm for authentication
    let realm: String
    
    /// HTTP header name for session token
    let cookieName: String
    
    /// User ID for device management
    let userId: String
    
    /// SSO session token
    let ssoToken: String
    
    /// HTTP client (optional)
    let httpClient: HttpClient
}
```

### Obtaining User ID and Session Token

#### From PingJourney/PingOidc

```swift
import PingJourney
import PingOidc

// After successful authentication
let journeyUser = // ... your authenticated user

// Get user ID from userinfo endpoint
let userInfoResult = await journeyUser.userinfo(cache: false)
switch userInfoResult {
case .success(let userInfo):
    let userId = userInfo["sub"] as? String
    
case .failure(let error):
    print("Failed to get user info: \(error)")
}

// Get session token
let sessionToken = await journey.session()?.value

// Create configuration
let config = DeviceClientConfig(
    serverUrl: "https://openam.example.com",
    realm: "alpha",
    cookieName: "iPlanetDirectoryPro",
    userId: userId!,
    ssoToken: sessionToken!
)
```

## Usage

### Fetching Devices

```swift
// Oath devices (authenticator apps)
let oathDevices = try await deviceClient.oath.get()
for device in oathDevices {
    print("Device: \(device.deviceName)")
    print("  UUID: \(device.uuid)")
    print("  Created: \(Date(timeIntervalSince1970: device.createdDate / 1000))")
}

// Other device types
let pushDevices = try await deviceClient.push.get()
let boundDevices = try await deviceClient.bound.get()
let profileDevices = try await deviceClient.profile.get()
let webAuthnDevices = try await deviceClient.webAuthn.get()
```

### Updating Devices

Only mutable device types (Bound, Profile, WebAuthn) support updates:

```swift
// Update a Bound device
var boundDevice = boundDevices.first!
boundDevice.deviceName = "My iPhone 15"
try await deviceClient.bound.update(boundDevice)

// Update a Profile device
var profileDevice = profileDevices.first!
profileDevice.deviceName = "Updated Profile"
try await deviceClient.profile.update(profileDevice)

// Update a WebAuthn device
var webAuthnDevice = webAuthnDevices.first!
webAuthnDevice.deviceName = "YubiKey 5C"
try await deviceClient.webAuthn.update(webAuthnDevice)
```

### Deleting Devices

All device types support deletion:

```swift
try await deviceClient.oath.delete(oathDevice)
try await deviceClient.push.delete(pushDevice)
try await deviceClient.bound.delete(boundDevice)
try await deviceClient.profile.delete(profileDevice)
try await deviceClient.webAuthn.delete(webAuthnDevice)
```

## Device Types

### Oath Device

```swift
struct OathDevice: Device {
    let id: String
    let deviceName: String
    let uuid: String
    let createdDate: TimeInterval
    let lastAccessDate: TimeInterval
}
```

### Push Device

```swift
struct PushDevice: Device {
    let id: String
    let deviceName: String
    let uuid: String
    let createdDate: TimeInterval
    let lastAccessDate: TimeInterval
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
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double
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
}
```

## Error Handling

All operations throw `DeviceError`:

```swift
do {
    let devices = try await deviceClient.oath.get()
} catch let error as DeviceError {
    switch error {
    case .networkError(let underlyingError):
        print("Network error: \(underlyingError)")
        
    case .requestFailed(let statusCode, let message):
        if statusCode == 401 {
            print("Session expired - please log in again")
        } else if statusCode == 404 {
            print("Device not found")
        } else {
            print("Server error: \(message)")
        }
        
    case .invalidToken(let message):
        print("Invalid token: \(message)")
        
    default:
        print("Error: \(error.localizedDescription)")
        print("Suggestion: \(error.recoverySuggestion ?? "")")
    }
}
```

### Error Types

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
