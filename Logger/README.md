<p align="center">
  <a href="https://github.com/ForgeRock/ping-ios-sdk">
    <img src="https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg" alt="Logo">
  </a>
  <hr/>
</p>

# PingLogger SDK

The PingLogger SDK provides a versatile logging interface and a set of common loggers for the Ping
SDKs.

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manager

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
