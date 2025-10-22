[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# Ping SDK - MFA OATH Module

[![Swift Version](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

PingOath is a comprehensive iOS SDK module that provides One-Time Password (OTP) authentication functionality, including support for both TOTP (Time-based One-Time Password) and HOTP (HMAC-based One-Time Password) authentication mechanisms following RFC 4226 and RFC 6238 standards.

## Features

- OATH credential management (add, retrieve, delete)
- TOTP and HOTP support
- Multiple hashing algorithms (SHA1, SHA256, SHA512)
- Customizable digit lengths (6-8 digits)
- Customizable periods for TOTP
- URI parsing and formatting
- Secure iOS Keychain storage for credentials
- Policy-based credential locking and validation

### Standard Compliance
- Full RFC 4226 (HOTP) and RFC 6238 (TOTP) compliance
- Configurable code length (6-8 digits) and time periods
- Base32 secret key encoding/decoding

## Getting Started

### Prerequisites

- **iOS**: 13.0+
- **Swift**: 5.7+
- **Xcode**: 15.0+

### Installation

#### Swift Package Manager

Add PingOath to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/pingidentity/ping-ios-sdk", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select PingOath module

#### CocoaPods

```ruby
pod 'PingOath'
```

## Usage

### Initialize the OATH Client

Before using the OATH MFA functionality, you need to initialize the `OathClient`. There are several ways to create and initialize an OathClient:

#### Basic Initialization
```swift
import PingOath

// Create an OATH client
let client = try await OathClient.createClient { config in
    config.logger = LogManager.logger
    config.enableCredentialCache = false
}

// Add a credential from URI (e.g., QR code scan)
let credential = try await client.addCredentialFromUri(
    "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
)

// Generate OTP code
let code = try await client.generateCode(credential.id)
print("OTP Code: \(code)")

// Clean up when done
try await client.close()
```

### Advanced Configuration

```swift
let client = try await OathClient.createClient { config in
    // Use custom storage
    config.storage = OathKeychainStorage(
        service: "com.myapp.oath",
        accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    )

    // Enable caching for performance
    config.enableCredentialCache = true

    // Configure logging
    config.logger = MyCustomLogger()

    // Set network timeout
    config.timeoutMs = 30.0

    // Enable data encryption
    config.encryptionEnabled = true
}
```

### Add a Credential from URI

Add a new OATH credential from a URI:

```swift
// HOTP credentials automatically increment counter
let hotpUri = "otpauth://hotp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&counter=0"
let hotpCredential = try await client.addCredentialFromUri(hotpUri)
```

### Generate OTP Code

Generate a one-time password for an OATH credential:

#### HOTP

```swift
// Generate code (counter increments automatically)
let code1 = try await client.generateCode(hotpCredential.id)  // Counter = 1
let code2 = try await client.generateCode(hotpCredential.id)  // Counter = 2
```

#### TOTP

```swift
// Get code with timing and validity information
let codeInfo = try await client.generateCodeWithValidity(credential.id)

print("Code: \(codeInfo.code)")
print("Time remaining: \(codeInfo.timeRemaining) seconds")
print("Progress: \(codeInfo.progress * 100)%")
```

## Storage Options

### OathKeychainStorage (Default)

Secure storage using iOS Keychain Services:

```swift
let storage = OathKeychainStorage(
    service: "com.myapp.oath",                                    // Keychain service
    accessGroup: "group.myapp",                                   // Shared keychain access
    accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly   // Security level
)
```

### Custom Storage

Implement the `OathStorage` protocol for custom storage solutions:

```swift
class MyCustomStorage: OathStorage {
    func storeOathCredential(_ credential: OathCredential) async throws { }
    func retrieveOathCredential(credentialId: String) async throws -> OathCredential? { }
    func getAllOathCredentials() async throws -> [OathCredential] { }
    func removeOathCredential(credentialId: String) async throws -> Bool { }
    func clearOathCredentials() async throws { }
}
```

## URI Formats

### Supported URI Schemes

**TOTP (Time-based)**
```
otpauth://totp/Issuer:Account?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30
```

**HOTP (Counter-based)**
```
otpauth://hotp/Issuer:Account?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&counter=0
```

**MFA Extensions**
```
mfauth://totp/Issuer:Account?secret=SECRET&issuer=Issuer&uid=USER_ID&oid=DEVICE_ID
```

### URI Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `secret` | ✅ | Base32 encoded secret key | - |
| `issuer` | ❌ | Service provider name | - |
| `algorithm` | ❌ | HMAC algorithm (SHA1/SHA256/SHA512) | SHA1 |
| `digits` | ❌ | Code length (4-8) | 6 |
| `period` | ❌ | TOTP validity period in seconds | 30 |
| `counter` | ❌ | HOTP counter value | 0 |
| `uid` | ❌ | Base64 encoded user ID | - |
| `oid` | ❌ | Device/resource ID | - |
| `image` | ❌ | Logo URL | - |

## Error Handling

### Error Types

The SDK provides comprehensive error handling:

```swift
do {
    let credential = try await client.addCredentialFromUri(uri)
} catch let error as OathError {
    switch error {
    case .invalidUri(let message):
        print("Invalid URI: \(message)")
    case .credentialNotFound(let id):
        print("Credential not found: \(id)")
    case .credentialLocked(let id):
        print("Credential is locked: \(id)")
    case .codeGenerationFailed(let message, let underlying):
        print("Code generation failed: \(message)")
    case .initializationFailed(let message, let underlying):
        print("Client initialization failed: \(message)")
    }
} catch let error as OathStorageError {
    switch error {
    case .storageFailure(let message, let underlying):
        print("Storage error: \(message)")
    }
}
```

## License

Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.