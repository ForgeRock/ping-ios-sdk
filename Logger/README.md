[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingLogger

The PingLogger SDK provides a versatile logging interface and a set of common loggers for the Ping
SDKs.

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

Then add the `PingLogger` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingLogger', '~> <version>'
```

### Import the Module

```swift
import PingLogger
```

## How to Use the SDK

### Logging to the iOS Console

To log messages to the console, use the `standard` logger:

```swift
import PingLogger

let logger = LogManager.standard
logger.i("Hello World")
```

With the default the log will Tag with the SDK Version:
```
Ping SDK <Version>
```

### Disabling Logging

The PingLogger SDK provides a `none` logger that does not log any messages:

```swift
import PingLogger

let logger = LogManager.none
logger.i("Hello World") // This message will not be logged
```

### Creating a Custom Logger

You can create a custom logger to suit your specific needs. For example, here's how to create a
logger that only logs
warning and error messages:

```swift
struct WarningErrorOnlyLogger: Logger {

  func i(_ message: String) {
  }

  func d(_ message: String) {
  }

  func w(_ message: String, error: Error?) {
    if let error = error {
      print("\(message): \(error)")
    } else {
      print(message)
    }
  }

  func e(_ message: String, error: Error?) {
    if let error = error {
      print("\(message): \(error)")
    } else {
      print(message)
    }
  }
}

extension LogManager {
  static var warningErrorOnly: Logger {
    return WarningErrorOnlyLogger()
  }
}
```

To use your custom logger:

```swift
let logger = LogManager.warningErrorOnly
logger.i("Hello World") // This message will not be logged
```

## Shared Logger

LogManager also provides a global shared logger: `LogManager.logger`. Default value for the `LogManager.logger` is `none`, however any type conforming to `Logger` protocol can be assigned to it, including the `standard` and `warning` loggers and any custom logger.

## Available Loggers

The PingLogger SDK provides the following loggers:

| Logger   | Description                                           |
|----------|-------------------------------------------------------|
| standard | Logs messages to iOS Console                          |
| warning  | Logs warning and error messages to iOS Console        |
| none     | Disables logging                                      |

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
