[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingExternalIdPGoogle

Ping External IDP Google is a library that allows you to authenticate with External IDP for Google using the [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) SDK for Native iOS experience.
This library acts as a plugin to the `PingExternalIdP` library, and it provides the necessary configuration to authenticate with Google Sign In natively.

<img src="images/GoogleSignIn-step1.png" width="250"> <img src="images/GoogleSignIn-step2.png" width="250">

## Getting Started

### Prerequisites

- PingOne DaVinci or Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
- iOS 16.0+
- Swift 6.0+
- Xcode 15+
- A Google Cloud Platform project with an iOS OAuth client configured

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

Then add the `PingExternalIdPGoogle` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingExternalIdPGoogle', '~> <version>'
```

### Import the Module

```swift
import PingExternalIdPGoogle
```


## Usage

To use the `PingExternalIdPGoogle` with `IdpCollector` (DaVinci) or `IdpCallback` (Journey), you need to integrate with the `PingDavinci` or `PingJourney` module respectively.
Read more about Configuration and Usage in [PingExternalIdP](/ExternalIdP/README.md)

If the library is present in the project, calling `IdpCollector.authorize()` (DaVinci) or `IdpCallback.authorize()` (Journey) will use the Google Sign In SDK to perform the authentication.

## Google Developer Console Configuration for Native Integration

For Google native sign-in to work correctly, you need to configure **iOS client** credentials in your Google Cloud Platform project.

<img src="images/GoogleClient-iOS.png" width="500">

## Configuring `Info.plist`

Add the following strings to your app's Info file, replacing the placeholders with your
actual Google Client ID and Google Server Client ID:

```xml

  <key>GIDClientID</key>
	<string>[your_google_client_id]</string>
	<key>GIDServerClientID</key>
	<string>[your_google_server_client_id]</string>

  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>[your_dot_reversed_google_client_id]</string>
      </array>
    </dict>
  </array>

```

## Handle the authentication redirect URL

### UIKit: UIApplicationDelegate

```swift
func application(
  _ app: UIApplication,
  open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]
) -> Bool {
  var handled = GoogleRequestHandler.handleOpenURL(UIApplication.shared, url: url, options: nil)
  if handled {
    return true
  }
...
}
```

### SwiftUI

```swift
@main
struct MyApp: App {

  var body: some Scene {
    WindowGroup {
      ContentView()
        // ...
        .onOpenURL { url in
          GoogleRequestHandler.handleOpenURL(UIApplication.shared, url: url, options: nil)
        }
    }
  }
}
}
```

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
