# PingJourneyPlugin

[![Version](https://img.shields.io/cocoapods/v/PingJourneyPlugin.svg?style=flat)](https://cocoapods.org/pods/PingJourneyPlugin)
[![License](https://img.shields.io/cocoapods/l/PingJourneyPlugin.svg?style=flat)](https://cocoapods.org/pods/PingJourneyPlugin)

## Overview

The `PingJourneyPlugin` is a lightweight abstraction layer for the `PingJourney` SDK. It defines a set of protocols and interfaces that encapsulate the core functionalities of the `PingJourney` SDK, providing a high-level API for other modules.

The main purpose of this plugin is to decouple modules from the concrete implementation of the `PingJourney` SDK, allowing them to interact with its features through a stable, abstract API.

## Architecture

`PingJourneyPlugin` is designed to promote a decoupled architecture within your application. Modules that need to interact with `PingJourney`'s features can depend on `PingJourneyPlugin` instead of the full `PingJourney` SDK.

-   **`PingJourneyPlugin`**: Defines the contracts (e.g., protocols, public models). It has no dependency on `PingJourney`.
-   **`PingJourney`**: Depends on `PingJourneyPlugin` and provides the concrete implementation for the contracts defined within it.
-   **Consumer Module**: Depends only on `PingJourneyPlugin` to access journey functionalities. The actual implementation from `PingJourney` is provided at runtime, typically through dependency injection.

This setup promotes separation of concerns, improves modularity, and makes consumer modules independent of `PingJourney`'s implementation details.

## Installation

### CocoaPods

`PingJourneyPlugin` is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your `Podfile`:

```ruby
pod 'PingJourneyPlugin', '~> 1.0.0'
```

Then, run the command:
```bash
pod install
```

## Usage

Your application modules can interact with the `PingJourney` functionality through the protocols exposed by this plugin.

For example, a module can get a reference to a service protocol from `PingJourneyPlugin` and use it, without knowing about the underlying implementation provided by the `PingJourney` SDK.


## Dependencies

-   [PingLogger](https://github.com/ForgeRock/ping-ios-sdk) (~> 1.3.1)

## License

`PingJourneyPlugin` is available under the MIT license. See the LICENSE file for more info.
