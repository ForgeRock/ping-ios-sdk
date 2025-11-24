
# PingFido

This module provides FIDO functionality for the Ping Identity iOS SDK, utilizing native iOS APIs (`AuthenticationServices`) to support Passkeys and locally stored keys.

## Concept

The FIDO module serves as a bridge between Ping Identity's authentication flows (DaVinci and Journey) and Apple's native FIDO capabilities through the `AuthenticationServices` framework. The `Fido` class acts as a proxy, abstracting the complexity of the underlying credential management system while providing a clean, consistent API for authentication operations.

## Structure

The module is organized into the following structure:

- **Fido/Fido**: Contains the source code for the module.
  - `Fido.swift`: The main class that orchestrates the FIDO registration and authentication processes.
  - `FidoModels.swift`: Contains the data models for FIDO requests and responses.
  - `FidoConstants.swift`: Defines the constants used in the FIDO implementation.
  - `PingFido.h`: The header file for the module.
  - **Davinci**: Contains the DaVinci collectors for FIDO operations.
    - `AbstractFidoCollector.swift`: A factory class for creating FIDO collectors.
    - `FidoRegistrationCollector.swift`: Handles FIDO registration.
    - `FidoAuthenticationCollector.swift`: Handles FIDO authentication.
  - **Journey**: Contains the Journey callbacks for FIDO operations.
    - `FidoCallback.swift`: Base class for FIDO callbacks.
    - `FidoRegistrationCallback.swift`: Handles FIDO registration.
    - `FidoAuthenticationCallback.swift`: Handles FIDO authentication.
    - `CallbackInitializer.swift`: Registers the FIDO callbacks with the Journey framework.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "1.3.1")
]
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'PingFido', '~> 1.3.1'
```

Then run `pod install`.

## Usage

### DaVinci Integration

To use the FIDO module with DaVinci, you will need to handle the JSON payload from the server and use the appropriate collector.

1.  **Get the JSON payload** from the DaVinci server.
2.  **Create the collector** using the `AbstractFidoCollector.getCollector(with:)` factory method.
3.  **Perform the FIDO operation** by calling `register()` or `authenticate()` on the collector.
4.  **Send the payload** back to the DaVinci server.

**Example:**

```swift
import PingFido

func handleDaVinciFido(json: [String: Any]) {
    do {
        let collector = try AbstractFidoCollector.getCollector(with: json)
        
        if let registrationCollector = collector as? FidoRegistrationCollector {
            registrationCollector.register(window: window) { result in
                switch result {
                case .success(let attestationValue):
                    // Send attestationValue to the server
                    break
                case .failure(let error):
                    // Handle error
                    break
                }
            }
        } else if let authenticationCollector = collector as? FidoAuthenticationCollector {
            authenticationCollector.authenticate(window: window) { result in
                switch result {
                case .success(let assertionValue):
                    // Send assertionValue to the server
                    break
                case .failure(let error):
                    // Handle error
                    break
                }
            }
        }
    } catch {
        // Handle error
    }
}
```

### Journey Integration

To use the FIDO module with Journey, you need to register the FIDO callbacks and then handle them when they are received from the server.

1.  **Register the callbacks** at the start of your application.
2.  **Handle the callbacks** when they are received from the Journey server.
3.  **Perform the FIDO operation** by calling `register()` or `authenticate()` on the callback.

**Example:**

**1. Register Callbacks:**

```swift
import PingFido

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    CallbackInitializer.registerCallbacks()
    return true
}
```

**2. Handle Callbacks:**

```swift
import PingJourney
import PingFido

func handleJourneyNode(node: Node) {
    if let callback = node.getCallback(FidoRegistrationCallback.self) {
        callback.register(window: self.view.window!) { error in
            if let error = error {
                // Handle error
            }
        } else if let callback = node.getCallback(FidoAuthenticationCallback.self) {
            callback.authenticate(window: self.view.window!) { error in
                if let error = error {
                    // Handle error
                }
            }
        }
    }
}
```
