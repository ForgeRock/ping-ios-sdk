# PingDavinciPlugin

[![Version](https://img.shields.io/cocoapods/v/PingDavinciPlugin.svg?style=flat)](https://cocoapods.org/pods/PingDavinciPlugin)
[![License](https://img.shields.io/cocoapods/l/PingDavinciPlugin.svg?style=flat)](https://cocoapods.org/pods/PingDavinciPlugin)

## Overview

The `PingDavinciPlugin` is a lightweight abstraction layer for the `PingDavinci` SDK. It defines a set of protocols and interfaces that encapsulate the core functionalities of the `PingDavinci` SDK, providing a high-level API for other modules.

The main purpose of this plugin is to decouple modules from the concrete implementation of the `PingDavinci` SDK, allowing them to interact with its features through a stable, abstract API.

## Architecture

`PingDavinciPlugin` is designed to promote a decoupled architecture within your application. Modules that need to interact with `PingDavinci`'s features can depend on `PingDavinciPlugin` instead of the full `PingDavinci` SDK.

-   **`PingDavinciPlugin`**: Defines the contracts (e.g., protocols, public models). It has no dependency on `PingDavinci`.
-   **`PingDavinci`**: Depends on `PingDavinciPlugin` and provides the concrete implementation for the contracts defined within it.
-   **Consumer Module**: Depends only on `PingDavinciPlugin` to access Davinci functionalities. The actual implementation from `PingDavinci` is provided at runtime, typically through dependency injection.

This setup promotes separation of concerns, improves modularity, and makes consumer modules independent of `PingDavinci`'s implementation details.

## Installation

### CocoaPods

`PingDavinciPlugin` is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your `Podfile`:

```ruby
pod 'PingDavinciPlugin', '~> 1.0.0'
```

Then, run the command:
```bash
pod install
```

## Usage

Your application modules can interact with the `PingDavinci` functionality through the protocols exposed by this plugin.

### Conceptual Example

Let's assume `PingDavinciPlugin` defines a `DavinciService` protocol:

```swift
// In PingDavinciPlugin
public protocol DavinciService {
    func start(policyId: String, completion: @escaping (Error?) -> Void)
}
```

The `PingDavinci` SDK would provide a concrete implementation for this service. Your application can then obtain an instance of this service and use it.

```swift
import PingDavinciPlugin

class MyViewModel {
    
    // The service is injected, providing an implementation from PingDavinci
    private let davinciService: DavinciService

    init(davinciService: DavinciService) {
        self.davinciService = davinciService
    }

    func beginDavinciFlow(policyId: String) {
        davinciService.start(policyId: policyId) { error in
            if let error = error {
                print("Davinci flow failed: \(error.localizedDescription)")
            } else {
                print("Davinci flow started successfully.")
            }
        }
    }
}
```

## Dependencies

-   [PingLogger](https://github.com/ForgeRock/ping-ios-sdk) (~> 1.3.1)

## License

`PingDavinciPlugin` is available under the MIT license. See the LICENSE file for more info.
