[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingStorage

The PingStorage SDK provides a flexible storage interface and a set of common storage solutions for the Ping SDKs.

## Getting Started

### Prerequisites

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

Then add the `PingStorage` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingStorage', '~> <version>'
```

### Import the Module

```swift
import PingStorage
```

## How to Use the SDK

### Creating and Using a Storage Instance

To create a storage instance and use it to persist and retrieve data, follow the example below:

```swift
// Define the data type that you want to persist
struct Dog: Codable {
    let name: String
    let type: String
}

  let storage = KeychainStorage<Dog>(account: "myId") // Create the storage
  try? await storage.save(item: Dog(name: "Lucky", type: "Golden Retriever")) // Persist the item
  let storedData = try? await storage.get() // Retrieve the item
```

Keychain is a storage solution that
uses iOS Keychain to store data securely.

### Enabling Cache for the Storage

You can enable cache for the storage as follows, by default cache is disabled:

```swift
  let storage = KeychainStorage<Dog>(account: "myId", cacheStrategy: .CACHE) // Create the Storage with cache enabled
```

### Adding Encryption to the Storage

You can add encryption by specifying the encryptor (`Encryptor` instance) as follows, by default `NoEncryptor` is used:

```swift
  let storage = KeychainStorage<Dog>(account: "myId", encryptor: SecuredKeyEncryptor() ?? NoEncryptor(), cacheStrategy: .CACHE) // Create the Storage with `SecuredKeyEncryptor`
```

You can create your custom encryptor by implementing the `Encryptor` protocol:

```swift
struct MyEncryptor: Encryptor {
  func encrypt(data: Data) async throws -> Data {
    // Implement the encryption logic
  }

  func decrypt(data: Data) async throws -> Data {
    // Implement the decryption logic
  }
}
```

### Creating a Custom Storage

You can create a custom storage by implementing the `Storage` interface. This could be useful for creating
file-based storage, cloud storage, etc. Here is an example of creating a custom memory storage:

```swift
public class CustomStorage<T: Codable>: Storage {
  private var data: T?

  public func save(item: T) async throws {
    data = item
  }

  public func get() async throws -> T?  {
    return data
  }

  public func delete() async throws {
    data = nil
  }

}

public class CustomStorageDelegate<T: Codable>: StorageDelegate<T> {
  public init(cacheStrategy: .CACHE) {
    super.init(delegate: CustomStorage<T>(), cacheStrategy: cacheStrategy)
  }
}

```

## Available Storage Solutions

The PingStorage SDK provides the following storage solutions:

| Storage          | Description                                                                                                                                 |
|------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| KeychainStorage  | Storage that stores data in iOS Keychain.                                                                                                    |
| MemoryStorage    | Storage that stores data in memory.                                                                                                          |

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved.
