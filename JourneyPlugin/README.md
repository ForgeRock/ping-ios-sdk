[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingJourneyPlugin

The `PingJourneyPlugin` is a lightweight abstraction layer for the `PingJourney` SDK. It defines a set of protocols and interfaces that encapsulate the core functionalities of the `PingJourney` SDK, providing a high-level API for other modules.

The main purpose of this plugin is to decouple modules from the concrete implementation of the `PingJourney` SDK, allowing them to interact with its features through a stable, abstract API.

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

Then add the `PingJourneyPlugin` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingJourneyPlugin', '~> <version>'
```

### Import the Module

```swift
import PingJourneyPlugin
```

## Architecture

`PingJourneyPlugin` is designed to promote a decoupled architecture within your application. Modules that need to interact with `PingJourney`'s features can depend on `PingJourneyPlugin` instead of the full `PingJourney` SDK.

-   **`PingJourneyPlugin`**: Defines the contracts (e.g., protocols, public models). It has no dependency on `PingJourney`.
-   **`PingJourney`**: Depends on `PingJourneyPlugin` and provides the concrete implementation for the contracts defined within it.
-   **Consumer Module**: Depends only on `PingJourneyPlugin` to access journey functionalities. The actual implementation from `PingJourney` is provided at runtime, typically through dependency injection.

This setup promotes separation of concerns, improves modularity, and makes consumer modules independent of `PingJourney`'s implementation details.

## Key Components

The `PingJourneyPlugin` module is built around a few core concepts that enable its functionality:

- **`Callbacks.swift`**: This is the central file defining the `Callback` protocol, which is the base for all Journey callbacks. It also defines `JourneyContinueNode`, a specialized `ContinueNode` for handling Journey-specific payloads and requests.

- **`AbstractCallback.swift`**: A base class that provides common functionality for all callbacks, including handling of input and output values from the JSON payload. Most concrete callback implementations subclass this.

- **`CallbackRegistry.swift`**: A thread-safe actor that serves as a factory and registry for all `Callback` types. It is responsible for instantiating the correct callback objects based on the JSON response from the Journey server.

- **`JourneyAware.swift`**: Defines the `JourneyAware` protocol. Callbacks or other types that conform to this protocol can be injected with the `Journey` workflow instance, allowing them to interact with the authentication flow.

- **`JourneyPlugin.swift`**: This file contains the main `Journey` typealias (which maps to `Workflow`) and the `JourneyConfig` class, which holds configuration parameters like the server URL and realm.

- **`Constants.swift`**: A centralized enum that holds all the string constants used in Journey flows, such as callback type names, JSON keys, and API parameters. This improves code maintainability and reduces errors from typos.

## Usage

Your application modules can interact with the `PingJourney` functionality through the protocols exposed by this plugin.

For example, a module can get a reference to a service protocol from `PingJourneyPlugin` and use it, without knowing about the underlying implementation provided by the `PingJourney` SDK.


## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All rights reserved.
