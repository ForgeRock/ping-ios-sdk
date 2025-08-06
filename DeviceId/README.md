
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

***

## Installation

Add dependency to your project
To integrate Journey into your iOS project, add the following dependency to your Podfile or Package.swift file:

```
pod 'PingJourney', '<version>'
```
or for Swift Package Manager:

```
.package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
```

Replace <version> with the latest version of the Journey SDK.

Select the `DeviceId` library from the list of package products.

***

## Usage

### Retrieving the Device Identifier

Instantiate `DefaultDeviceIdentifier` and access the `id` property. The identifier is generated on its first use and subsequently retrieved from the cache or Keychain.

The `id` is a SHA-256 hash of the public key, providing a stable and unique representation of the device's identity key.

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
````

### Usage with Configuration

You can customize the behavior, such as specifying a Keychain account name or disabling encryption (not recommended for production).

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

### Regenerating the Identifier

If needed, you can explicitly delete the existing key pair from the Keychain and generate a new one.

```swift
// In an async context
do {
    let newId = try await deviceIdentifier.regenerateIdentifier()
    print("New Device ID: \(newId)")
} catch {
    print("Error regenerating ID: \(error)")
}
```

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

-----
## Fallback to a simple UUIDDeviceIDentifier

In case of errors or if it required to create a simpler less secure DeviceIdentifier the provided `UUIDDeviceIdentifier` can be used.

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
````

## Custom Implementation

For advanced use cases, you can create a custom identifier generator by conforming to the `DeviceIdentifier` protocol.

```swift
import PingDeviceId

public protocol DeviceIdentifier: Sendable {
    var id: String { get async throws }
}

// Example: A custom identifier that uses UUID
struct CustomDeviceIdentifier: DeviceIdentifier {
    var id: String {
        // This is a simple example; for persistence, you would need
        // to save and retrieve the UUID from a storage mechanism.
        return UUID().uuidString
    }
}
```