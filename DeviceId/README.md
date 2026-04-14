<p align="center">
  <a href="https://github.com/ForgeRock/ping-ios-sdk">
    <img src="https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg" alt="Logo">
  </a>
  <hr/>
</p>

# Device ID Module for Swift

The Device ID module for Swift provides a robust and secure method for generating and managing a unique identifier for a device. It leverages the iOS Keychain to persistently store a cryptographic key pair, ensuring the identifier remains stable across app installations and device backups.

The core implementation, `DefaultDeviceIdentifier`, is built as a Swift `actor` to guarantee thread-safe access in concurrent environments.

***

## Features

- **🔑 Keychain-Based Persistence**: Generates an RSA key pair and stores it securely in the device's Keychain.
- **🔄 Stable Identifier**: The ID persists even if the user uninstalls and reinstalls the application.
- **🔒 Concurrency-Safe**: Implemented as a Swift `actor` to prevent race conditions when accessing the identifier from multiple threads.
- **⚙️ Configurable**: Allows customization of the Keychain account name, key size, and optional data encryption.
- **⚡️ Asynchronous API**: Fully embraces modern Swift concurrency with an `async/await` interface.
- **🧩 Extensible**: Define your own identifier strategy by conforming to the `DeviceIdentifier` protocol.
- **🔄 Legacy Migration**: Automatically migrates device identifiers from FRAuth SDK format, ensuring seamless transition for existing users.

***

## Installation

Add dependency to your project
To integrate the DeviceId module into your iOS project, add the following dependency to your Podfile or Package.swift file:

```
pod 'PingDeviceId', '<version>'
```
or for Swift Package Manager:

```
.package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
```

Replace `<version>` with the latest version of the SDK.

Select the `PingDeviceId` library from the list of package products.

***

## Usage

### Retrieving the Device Identifier

Instantiate `DefaultDeviceIdentifier` and access the `id` property. The identifier is generated on its first use and subsequently retrieved from the cache or Keychain.

For newly generated identifiers, the `id` is a SHA-256 hash of the RSA public key, providing a stable and unique representation of the device's identity key.

```swift
import PingDeviceId

let deviceIdentifier = try DefaultDeviceIdentifier()

// Access the identifier in an async context
Task {
    do {
        let id = try await deviceIdentifier.id
        print("Device ID: \(id)")
    } catch {
        print("Error retrieving device ID: \(error)")
    }
}
```

### Usage with Configuration

You can customize the behavior, such as specifying a Keychain account name, key size, or encryption settings.

```swift
import PingDeviceId

// Define a custom configuration
let config = DeviceIdentifierConfiguration(
    keychainAccount: "com.mycompany.myapp.deviceid",
    useEncryption: true,
    keySize: 2048
)

do {
    let deviceIdentifier = try DefaultDeviceIdentifier(configuration: config)
    let id = try await deviceIdentifier.id
    print("Custom Device ID: \(id)")
} catch {
    // Handle potential initialization or retrieval errors
}
```

#### Predefined Configurations

The module provides two predefined configurations for common use cases:

```swift
// Default configuration with 2048-bit RSA keys and encryption enabled
let defaultIdentifier = try DefaultDeviceIdentifier(configuration: .default)

// High security configuration with 4096-bit RSA keys and encryption enabled
let secureIdentifier = try DefaultDeviceIdentifier(configuration: .highSecurity)
```

**Configuration Options:**
- `keySize`: RSA key size in bits (2048 for `.default`, 4096 for `.highSecurity`)
- `keychainAccount`: Custom keychain account identifier for storage isolation
- `useEncryption`: Whether to encrypt the stored key pair (recommended: `true`)

### Regenerating the Identifier

If needed, you can explicitly delete the existing key pair from the Keychain and generate a new one. This also clears any legacy identifier storage to ensure a completely fresh identifier is generated.

```swift
// In an async context
do {
    let newId = try await deviceIdentifier.regenerateIdentifier()
    print("New Device ID: \(newId)")
} catch {
    print("Error regenerating ID: \(error)")
}
```

**Note:** Regenerating the identifier will:
- Clear the in-memory cache
- Delete the current identifier from keychain storage
- Delete any legacy FRAuth SDK identifier storage
- Generate a completely new RSA key pair and identifier

-----

## Legacy Migration

The module automatically handles migration from the legacy FRAuth SDK device identifier format. When retrieving a device identifier for the first time, the system will:

1. **Check for existing identifier** in the new PingDeviceId format
2. **Search for legacy identifier** from FRAuth SDK if not found
3. **Migrate the legacy identifier** to the new storage format while preserving the original value
4. **Generate a new identifier** only if no legacy identifier exists

This ensures that existing users maintain the same device identifier when transitioning from FRAuth to PingDeviceId, providing continuity across SDK versions.

### How Legacy Migration Works

The legacy FRAuth SDK stored device identifiers using:
- **Hashing Algorithm**: SHA-1 hash of the RSA public key as the identifier
- **Keychain Storage**: 
  - Identifier stored at account `com.forgerock.ios.device-identifier.hash-base64-string-identifier`
  - Public key data stored separately at account `com.forgerock.ios.device-identifier.pubic-key.data`
- **No Encryption**: Keys and identifiers stored in plain format

The new PingDeviceId module:
- **Hashing Algorithm**: SHA-256 hash of the RSA public key for newly generated identifiers
- **Legacy Preservation**: Preserves legacy SHA-1 identifiers when migrating (no re-hashing)
- **Unified Storage**: Stores both the identifier and key pair in a single structured format
- **Optional Encryption**: Supports encryption for enhanced security (enabled by default)
- **Graceful Fallback**: Attempts to regenerate legacy identifier from public key if main identifier is missing

### Migration Example

```swift
import PingDeviceId

// On first access after upgrading from FRAuth SDK
let deviceIdentifier = try DefaultDeviceIdentifier()

Task {
    // This will automatically detect and migrate the legacy identifier
    let id = try await deviceIdentifier.id
    print("Device ID: \(id)")
    // Output will be the same identifier as in FRAuth SDK
}
```

**Important Notes:**
- Legacy identifiers are preserved exactly as they were in FRAuth SDK (SHA-1 hashed)
- Only newly generated identifiers use the improved SHA-256 hashing algorithm
- Migration happens transparently on first access - no manual intervention required
- After migration, the identifier is stored in the new encrypted format (if encryption is enabled)

-----

## Identifier Characteristics & Lifespan

The identifier's behavior is determined by its storage in the iOS Keychain.

| Scenario | Behavior |
| :--- | :--- |
| **App Uninstall/Reinstall** | The identifier **persists**. The Keychain is not cleared when an app is deleted, so the new installation can access the same key. |
| **App Data Cleared** | This is not a standard user action on iOS. Deleting the app is the closest equivalent (see above). |
| **Device Backup & Restore** | The identifier **persists** if the device is restored from an encrypted iCloud or local backup, as these backups include Keychain data. |
| **Factory Reset** | The identifier is **permanently deleted** as the entire device storage, including the Keychain, is wiped. |
| **Sharing Across Apps** | The identifier can be shared across apps from the same developer by using the same **Keychain Access Group** in the configuration. |
| **Migration from FRAuth** | Legacy identifiers are **automatically migrated** and preserved, ensuring continuity for existing users. The original SHA-1 hash is maintained. |
| **Regeneration** | Calling `regenerateIdentifier()` **deletes both new and legacy** storage, generating a completely fresh identifier with a new key pair. |

### Hashing Algorithms

| Identifier Type | Hashing Algorithm | When Used |
| :--- | :--- | :--- |
| **Legacy (FRAuth SDK)** | SHA-1 | Migrated identifiers from FRAuth SDK (preserved as-is) |
| **New (PingDeviceId)** | SHA-256 | Newly generated identifiers in PingDeviceId module |

-----

## Fallback to a simple UUIDDeviceIdentifier

In case of errors or if a simpler, less secure DeviceIdentifier is required, the provided `UUIDDeviceIdentifier` can be used.

```swift
import PingDeviceId

let deviceIdentifier = try UUIDDeviceIdentifier()

// Access the identifier in an async context
Task {
    do {
        let id = try await deviceIdentifier.id
        print("Device ID: \(id)")
    } catch {
        print("Error retrieving device ID: \(error)")
    }
}
```

**Note**: `UUIDDeviceIdentifier` generates a random UUID-based identifier that persists in the keychain. While simpler, it offers less cryptographic strength than the RSA-based approach and does not support legacy migration.

-----

## Custom Implementation

For advanced use cases, you can create a custom identifier generator by conforming to the `DeviceIdentifier` protocol.

```swift
import PingDeviceId

public protocol DeviceIdentifier: Sendable {
    var id: String { get async throws }
}

// Example: A custom identifier that uses a timestamp-based UUID
actor CustomDeviceIdentifier: DeviceIdentifier {
    private let storage: KeychainStorage<String>
    
    init() {
        self.storage = KeychainStorage<String>(
            account: "com.mycompany.custom.deviceid",
            encryptor: NoEncryptor()
        )
    }
    
    var id: String {
        get async throws {
            if let stored = try await storage.get() {
                return stored
            }
            
            // Generate custom identifier
            let customId = "\(Date().timeIntervalSince1970)-\(UUID().uuidString)"
            try await storage.save(item: customId)
            return customId
        }
    }
}
```

-----

## Error Handling

The module defines specific error cases for various failure scenarios:

```swift
public enum DeviceIdentifierError: Error {
    case encryptionInitializationFailed  // Encryption setup failed
    case keyGenerationFailed(Error)      // RSA key generation failed
    case publicKeyExtractionFailed       // Could not extract public key
    case externalRepresentationFailed(Error)  // Key export failed
    case keychainItemNotFound            // Item not in keychain
    case keychainUnexpectedData          // Keychain data malformed
    case keychainUnexpectedStatus(OSStatus)  // Unexpected keychain status
}
```

Example error handling:

```swift
do {
    let id = try await deviceIdentifier.id
    print("Device ID: \(id)")
} catch DeviceIdentifierError.encryptionInitializationFailed {
    print("Failed to initialize encryption - consider using unencrypted storage")
} catch DeviceIdentifierError.keyGenerationFailed(let error) {
    print("Key generation failed: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

-----

## Thread Safety

`DefaultDeviceIdentifier` is implemented as a Swift `actor`, providing the following guarantees:

- **Race Condition Prevention**: Multiple concurrent calls to `id` will not trigger duplicate key generation
- **Task Deduplication**: If key generation is in progress, subsequent callers await the same result
- **Cache Coherency**: In-memory cache is protected from concurrent access issues

This makes it safe to use from multiple parts of your application without additional synchronization.

-----

## Performance Considerations

- **First Access**: Initial identifier generation involves RSA key pair creation, which may take 100-500ms depending on key size
- **Subsequent Access**: Cached in memory after first retrieval - sub-millisecond performance
- **Background Generation**: Key generation runs on a background task to avoid blocking the main thread
- **Encryption Overhead**: When encryption is enabled, there's minimal overhead for keychain operations (typically <10ms)

**Recommendations:**
- Access the identifier early in app lifecycle to warm the cache
- Use `.default` configuration (2048-bit keys) for most applications
- Reserve `.highSecurity` configuration (4096-bit keys) for high-security requirements

-----

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.
© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
