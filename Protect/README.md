<p align="center">
  <a href="https://github.com/ForgeRock/ping-android-sdk">
    <img src="https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg" alt="Logo">
  </a>
  <hr/>
</p>

# PingProtect Module: Advanced Security Integration

## Overview

The `PingProtect` module is a powerful component of the Ping Identity iOS SDK, designed to seamlessly integrate Ping
Identity's Protect service into your mobile applications. It provides comprehensive tools for real-time behavioral data
collection, sophisticated risk analysis, and adaptive authentication strategies. By leveraging this module, developers
can significantly enhance application security, detect and mitigate fraudulent activities, and create a more secure and
user-friendly authentication experience.

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manager

## Usage

### DaVinci Integration:

The `ProtectCollector` class, implementing the `Collector` protocol, is a critical component for gathering
behavioral risk data. It enables real-time risk assessment during DaVinci flows.

**Detailed Data Collection Process:**

```swift
node.collectors.forEach { collector in
    switch collector {
    case let protectCollector as ProtectCollector:
        let result = await protectCollector.collect()
        switch result {
        case .success:
            // Data collection successful: Proceed to the next node in the DaVinci flow.
            node.next()
        case .failure:
            // Data collection failed: Implement robust error handling.
            // Example: Log the error, display an informative message, or implement a retry mechanism.
            break
        }
    // ... Handle other collector types (e.g., OidcCollector, etc.)
    default:
        break
    }
}
```

The `collect()` method triggers the risk data collection, returning a `.success` or `.failure` result. Upon
success, `node.next()` advances the DaVinci flow. In case of failure, implement detailed error handling to maintain a
smooth user experience.

**Out of scope**

The PingProtect module's data collection results in a payload size that exceeds the practical limits for URL parameters in a
GET request. Consequently, the data cannot be included during DaVinci's start. Instead, the collect() function is
employed to retrieve the necessary data when required by the flow.

## Journey Integration

To be Implemented

## PingProtect SDK Initialization

Proper initialization is crucial for the PingProtect SDK's functionality. The SDK offers multiple initialization methods to
suit various application architectures and requirements.

### Direct Initialization Using the `Protect` Interface: Fine-Grained Control

For maximum control over SDK configuration, use the `Protect` interface directly:

```swift
await Protect.config { protectConfig in
    protectConfig.isBehavioralDataCollection = true // Enable behavioral data collection.
    protectConfig.isLazyMetadata = true // Enable lazy loading of device metadata.
    protectConfig.envId = URL(string: "https://api.pingone.com")?.host // Set the PingOne environment ID.
    protectConfig.deviceAttributesToIgnore = ["deviceId", "androidId", "serialNumber"] // Exclude sensitive device attributes.
    protectConfig.isConsoleLogEnabled = true // Enable detailed console logging for debugging.
}

try await Protect.initialize() // Initialize the Protect SDK with the provided configuration.

print("Protect SDK initialized.")

await Protect.pauseBehavioralData() // Temporarily pause behavioral data collection.
await Protect.resumeBehavioralData() // Resume behavioral data collection.
}
```

**Configuration Parameters Explained:**

* `isBehavioralDataCollection`: Enables or disables the collection of user behavioral data.
* `isLazyMetadata`: Enables lazy loading of device metadata, improving performance by deferring metadata retrieval until
  needed.
* `envId`: Specifies the PingOne environment ID, essential for connecting to your PingOne tenant.
* `deviceAttributesToIgnore`: Provides a list of device attributes to exclude from data collection, enhancing privacy
  and security.
* `customHost`: Allows specifying a custom host for the Protect API, useful in specific deployment scenarios.
* `isConsoleLogEnabled`: Enables detailed console logging, aiding in debugging and troubleshooting.

```mermaid
sequenceDiagram
    participant App
    participant Protect
    participant DaVinci
    participant ProtectCollector
    App ->> Protect: config()
    App ->> Protect: init()
    App ->> DaVinci: start()
    DaVinci ->> ProtectCollector: create()
    DaVinci ->> App: ProtectCollector
    App ->> ProtectCollector: collect()
    ProtectCollector ->> Protect: data()
    Protect ->> ProtectCollector: data
    App ->> DaVinci: next()
    note over App: Other interfaces for App
    App ->> Protect: pauseBehavioralData()
    App ->> Protect: resumeBehavioralData()
```

### Automatic Initialization with the `ProtectLifecycle` Module: Simplified Management

The `ProtectLifecycle` module automates the SDK's lifecycle management, simplifying its integration within DaVinci
flows:

```swift
let davinci = DaVinci.createDaVinci { config in
    config.module(OidcModule.config) { oidcValue in
        oidcValue.clientId = "dummy"
        // ... Other Oidc configurations
    }
    config.module(ProtectLifecycleModule.config) { protectValue in
        protectValue.isBehavioralDataCollection = true // Default: true
        protectValue.isLazyMetadata = true // Default: false
        protectValue.envId = "api.pingone.com" // Default: null
        protectValue.deviceAttributesToIgnore = ["deviceId"] // Default: empty list
        protectValue.customHost = "https://api.pingone.com" // Default: null
        protectValue.isConsoleLogEnabled = true // Default: false
        protectValue.pauseBehavioralDataOnSuccess = true // Pause data collection after successful authentication.
        protectValue.resumeBehavioralDataOnStart = true // Resume data collection on application start.
        
    }
}
```

```mermaid
sequenceDiagram
    participant App
    participant DaVinci
    participant Protect
    participant ProtectCollector
    App ->> DaVinci: start()
    DaVinci ->> Protect: config()
    DaVinci ->> Protect: init()
    DaVinci ->> Protect: resumeBehavioralData()
    DaVinci ->> ProtectCollector: create()
    DaVinci ->> App: ProtectCollector
    App ->> ProtectCollector: collect()
    ProtectCollector ->> Protect: data()
    Protect ->> ProtectCollector: data
    ProtectCollector ->> App: data
    App ->> DaVinci: next()
    alt isSuccess
        DaVinci ->> Protect: pauseBehavioralData()
    end
```

### Lazy Initialization: On-Demand SDK Activation

The SDK employs lazy initialization, meaning it only activates when triggered by server responses, such as the
instantiation of Collector or Callback objects. This approach conserves resources and accelerates application startup.
However, the initial interaction with the PingProtect SDK might experience a slight delay. Furthermore, if behavioral data
collection is active, the initial lack of SDK activation could result in incomplete data capture, potentially requiring
data collection later in the application flow.

```mermaid
sequenceDiagram
    participant App
    participant DaVinci
    participant Protect
    participant ProtectCollector
    App ->> DaVinci: start()
    DaVinci ->> ProtectCollector: create()
    DaVinci ->> App: ProtectCollector
    App ->> ProtectCollector: collect()
    ProtectCollector ->> Protect: config()
    ProtectCollector ->> Protect: init()
    ProtectCollector ->> Protect: data()
    Protect ->> ProtectCollector: data
    ProtectCollector ->> App: data
    App ->> DaVinci: next()
```

> [!WARNING]
> The Signal SDK, used internally by the Protect SDK, employs a Singleton pattern. This means it can only be initialized
> once. Subsequent `init()` calls are ignored.

### Pause and Resume Behavioral Data Collection: Granular Control

Control behavioral data collection with the following methods:

```swift
await Protect.pauseBehavioralData() // Pause data collection.
await Protect.resumeBehavioralData() // Resume data collection.
```

These methods allow for granular control over data collection, enabling you to pause collection during sensitive
operations or when required by user privacy preferences.
