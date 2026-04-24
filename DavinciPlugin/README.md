[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingDavinciPlugin

The `PingDavinciPlugin` is a lightweight abstraction layer for the `PingDavinci` SDK. It defines a set of protocols and interfaces that encapsulate the core functionalities of the `PingDavinci` SDK, providing a high-level API for other modules.

The main purpose of this plugin is to decouple modules from the concrete implementation of the `PingDavinci` SDK, allowing them to interact with its features through a stable, abstract API.

## Getting Started

### Prerequisites

- PingOne DaVinci
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

Then add the `PingDavinciPlugin` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingDavinciPlugin', '~> <version>'
```

### Import the Module

```swift
import PingDavinciPlugin
```

## Architecture

`PingDavinciPlugin` is designed to promote a decoupled architecture within your application. Modules that need to interact with `PingDavinci`'s features can depend on `PingDavinciPlugin` instead of the full `PingDavinci` SDK.

-   **`PingDavinciPlugin`**: Defines the contracts (e.g., protocols, public models). It has no dependency on `PingDavinci`.
-   **`PingDavinci`**: Depends on `PingDavinciPlugin` and provides the concrete implementation for the contracts defined within it.
-   **Consumer Module**: Depends only on `PingDavinciPlugin` to access Davinci functionalities. The actual implementation from `PingDavinci` is provided at runtime, typically through dependency injection.

This setup promotes separation of concerns, improves modularity, and makes consumer modules independent of `PingDavinci`'s implementation details.

## Key Components

The `PingDavinciPlugin` module consists of several key files that define its core functionality:

- **`Collector.swift`**: Defines the fundamental protocols for data collection within a DaVinci flow.
  - `Collector<T>`: A generic protocol for creating different types of collectors that handle specific data payloads.
  - `AnyFieldCollector`: A protocol for type-erased collectors, allowing them to be handled generically.

- **`CollectorFactory.swift`**: A thread-safe actor that acts as a factory and registry for `Collector` types. It is responsible for creating collector instances from the JSON responses provided by the DaVinci server.

- **`ContinueNode.swift`**: An extension on `PingOrchestrate`'s `ContinueNode` that adds a convenience property `collectors` to easily access all collector instances within a node.

- **`DaVinciAware.swift`**: Defines the `DaVinciAware` protocol. Types conforming to this protocol can be injected with the main `DaVinci` workflow instance, allowing them to interact with the overall authentication flow.

- **`Validator.swift` & `ValidationError.swift`**: These files provide a simple validation framework. `Validator` is a protocol for objects that can be validated, and `ValidationError` is an enum representing specific validation failures.

- **`SubmitCollectorProtocol.swift` & `FlowCollectorProtocol.swift`**: These protocols define contracts for specific types of collectors, such as buttons that submit a form (`SubmitCollectorProtocol`) or trigger a specific flow (`FlowCollectorProtocol`).

- **`Constants.swift`**: Contains a centralized enumeration of string constants used throughout the DaVinci integration, such as JSON keys, collector types, and event names. This helps avoid typos and magic strings.


## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All rights reserved.
