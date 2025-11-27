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

## Installation

### CocoaPods

`PingDavinciPlugin` is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your `Podfile`:

```ruby
pod 'PingDavinciPlugin', '~> 1.3.1'
```

Then, run the command:
```bash
pod install
```

## Dependencies

-   [PingLogger](https://github.com/ForgeRock/ping-ios-sdk) (~> 1.3.1)

## License

`PingDavinciPlugin` is available under the MIT license. See the LICENSE file for more info.
