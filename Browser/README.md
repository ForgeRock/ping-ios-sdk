[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingBrowser

Ping Browser is a library that allows you to instantiate and use an in-app browser for performing OIDC flows. 
This library act as a plugin to the `ExternalIdp` module,
and it provides the necessary configuration to launch the browser to authenticate with the External IDP.

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

Then add the `PingBrowser` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingBrowser', '~> <version>'
```

### Import the Module

```swift
import PingBrowser
```

## Usage

The `PingBrowser` is used internally in the `External_idp` module. You can use the `PingBrowser` in standalone mode by calling the following:
```swift
await BrowserLauncher.currentBrowser?.launch(url: request.urlRequest.url!, customParams: nil, browserType: .authSession, browserMode: .login, callbackURLScheme: callbackURLScheme)
```


### BrowserLauncher configuration

The `BrowserLauncher` has the following public methods:
1. `Reset()`
2. `launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String) async throws -> URL`

The `BrowserLauncher` supports the following types of `BrowserMode` (Not fully implemented yet):
1. `login`
2. `logout`
3. `custom`

The `BrowserLauncher` supports the following types of `BrowserType` (Not fully implemented yet):
1. `authSession` <-- Default
2. `sfViewController`
3. `nativeBrowserApp`
4. `ephemeralAuthSession`

At the current time only `authSession` and `ephemeralAuthSession` are implemented. Both types rely on the `ASWebAuthenticationSession` in-app browser type.

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved.
