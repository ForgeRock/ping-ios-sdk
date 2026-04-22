[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingExternalIdPApple

Ping External IDP Apple is a library that allows you to authenticate with External IDP for Apple using native Sign in With Apple.
This library acts as a plugin to the `PingExternalIdP` library, and it provides the necessary configuration to authenticate with `Sign In with Apple` natively.

<img src="images/SignInwithApple.png" width="250">

## Getting Started

### Prerequisites

- PingOne DaVinci or Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
- iOS 16.0+
- Swift 6.0+
- Xcode 15+
- Sign in with Apple capability enabled in your Xcode project

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

Then add the `PingExternalIdPApple` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingExternalIdPApple', '~> <version>'
```

### Import the Module

```swift
import PingExternalIdPApple
```

## Usage

To use the `PingExternalIdPApple` with `IdpCollector` (DaVinci) or `IdpCallback` (Journey), you need to integrate with the `PingDavinci` or `PingJourney` module respectively.
Read more about Configuration and Usage in [PingExternalIdP](/ExternalIdP/README.md)

If the library is present in the project, calling `IdpCollector.authorize()` (DaVinci) or `IdpCallback.authorize()` (Journey) will use native Sign in With Apple to perform the authentication.

### Enable the SIWA capability in Xcode

In the App project file go to `Target -> Signing and Capabilities` file, add the `Sign in with Apple` capability.

Follow the PingOne and DaVinci documentation to configuring the External IDP or Davinci Connector with Apple for a Sign in with Apple integration.

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
