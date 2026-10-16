[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingFido

This module provides FIDO functionality for the Ping Orchestration SDK for iOS, utilizing native iOS APIs (`AuthenticationServices`) to support Passkeys and locally stored keys.

## Getting Started

### Prerequisites

- PingOne DaVinci or Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
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

Then add the `PingFido` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingFido', '~> <version>'
```

### Import the Module

```swift
import PingFido
```

## Overview

The FIDO module serves as a bridge between Ping Identity's authentication flows (DaVinci and Journey) and Apple's native FIDO capabilities through the `AuthenticationServices` framework. The `Fido` class acts as a proxy, abstracting the complexity of the underlying credential management system while providing a clean, consistent API for authentication operations.

### Structure

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

## Usage

### DaVinci Integration

To use the FIDO module with DaVinci, you will need to handle the JSON payload from the server and use the appropriate collector.

1.  **Get the JSON payload** from the DaVinci server.
2.  **Create the collector** using the `AbstractFidoCollector.getCollector(with:)` factory method.
3.  **Perform the FIDO operation** by calling `register()` or `authenticate()` on the collector.
4.  **Send the payload** back to the DaVinci server.

**Example:**

```swift
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

### Trigger behaviour

The DaVinci FIDO2 form field carries a `trigger` property that tells the client whether the FIDO ceremony should be launched by a button press or automatically on render. `AbstractFidoCollector` (and therefore both `FidoRegistrationCollector` and `FidoAuthenticationCollector`) exposes this as:

- `collector.trigger` — the raw server-supplied value, or an empty string when the server omits the field.
- `collector.isAutomatic` — a derived convenience:
  - `trigger == "BUTTON"` (case-insensitive) → `false`, render a button.
  - any other non-empty `trigger` value → `true`, launch the ceremony immediately.
  - an absent/empty `trigger` → `false`, preserving the existing button-gated default so payloads that predate this property keep behaving as before.

The SDK cannot launch the ceremony itself in automatic mode — `register(window:)` and `authenticate(window:)` require an `ASPresentationAnchor` that only the host app owns. Host apps should launch the ceremony from a `.task`, guarded so it fires at most once per view/collector instance:

```swift
struct FidoRegistrationCollectorView: View {
    var collector: FidoRegistrationCollector
    let onNext: () -> Void

    // Guards against re-launching the ceremony while one is already in flight, or after
    // the view re-renders. A fresh collector instance (e.g. after the server re-renders the
    // step) should come with a fresh view — see the `.id(ObjectIdentifier(collector))` note below.
    @State private var hasLaunched = false

    var body: some View {
        VStack {
            if collector.isAutomatic {
                ProgressView("Waiting for passkey…")
            } else {
                Button(collector.label.isEmpty ? "Register with FIDO" : collector.label) {
                    Task { await performRegistration() }
                }
            }
        }
        .task {
            guard collector.isAutomatic, !hasLaunched else { return }
            hasLaunched = true
            await performRegistration()
        }
    }

    private func performRegistration() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let result = await collector.register(window: window)
        switch result {
        case .success:
            onNext()
        case .failure:
            // In automatic mode, avoid silently calling onNext() on failure — surface the
            // error and let the user choose to retry or continue so the flow doesn't loop.
            break
        }
    }
}
```

> If the DaVinci server can re-render the same step with a new collector instance (for example after a cancelled ceremony), attach `.id(ObjectIdentifier(collector))` to the view so SwiftUI restarts the `.task` instead of reusing the previous instance's state.

### Journey Integration

To use the FIDO module with Journey, you need to register the FIDO callbacks and then handle them when they are received from the server.

1.  **Register the callbacks** at the start of your application.
2.  **Handle the callbacks** when they are received from the Journey server.
3.  **Perform the FIDO operation** by calling `register()` or `authenticate()` on the callback.

**Example:**

**1. Register Callbacks:**

```swift
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

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
