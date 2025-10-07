
# PingFido

This module provides FIDO2 functionality for the Ping Identity iOS SDK, utilizing native iOS APIs (`AuthenticationServices`) to support Passkeys and locally stored keys.

## Concept

The FIDO2 module serves as a bridge between Ping Identity's authentication flows (DaVinci and Journey) and Apple's native FIDO2 capabilities through the `AuthenticationServices` framework. The `PingFido` class acts as a proxy, abstracting the complexity of the underlying credential management system while providing a clean, consistent API for authentication operations.

## Structure

The module is organized into the following structure:

- **Fido/Fido**: Contains the source code for the module.
  - **PingFido.swift**: The main class that orchestrates the FIDO2 registration and authentication processes.
  - **FidoModels.swift**: Contains the data models for FIDO2 requests and responses.
  - **FidoConstants.swift**: Defines the constants used in the FIDO2 implementation.
  - **PingFido.h**: The header file for the module.
  - **Journey**: Contains the Journey callbacks for FIDO2 operations.
    - `Fido2Callback.swift`: Base class for FIDO2 callbacks.
    - `Fido2RegistrationCallback.swift`: Handles FIDO2 registration.
    - `Fido2AuthenticationCallback.swift`: Handles FIDO2 authentication.
    - `CallbackInitializer.swift`: Registers the FIDO2 callbacks with the Journey framework.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "1.2.0")
]
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'PingFido', '~> 1.2.0'
```

Then run `pod install`.
