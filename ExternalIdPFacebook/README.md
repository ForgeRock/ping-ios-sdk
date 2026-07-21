[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingExternalIdPFacebook

Ping External IDP Facebook is a library that allows you to authenticate with External IDP for Facebook using the [facebook-ios-sdk](hhttps://github.com/facebook/facebook-ios-sdk) for Native iOS experience.
This library acts as a plugin to the `PingExternalIdP` library, and it provides the necessary configuration to authenticate with Facebook Login natively.

<img src="images/FacebookLogin-step1.png" width="250"> <img src="images/FacebookLogin-step2.png" width="250">

## Getting Started

### Prerequisites

- PingOne DaVinci or Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
- iOS 16.0+
- Swift 6.0+
- Xcode 15+
- A Facebook Developer account with a configured application

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

```swift
.package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
```

Then add the `PingExternalIdPFacebook` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingExternalIdPFacebook', '~> <version>'
```

Replace `<version>` with the latest version of the SDK.

### Import the Module

```swift
import PingExternalIdPFacebook
```

## Usage

To use the `PingExternalIdPFacebook` with `IdpCollector` (DaVinci) or `IdpCallback` (Journey), you need to integrate with the `PingDavinci` or `PingJourney` module respectively.
Read more about Configuration and Usage in [PingExternalIdP](/ExternalIdP/README.md)

If the library is present in the project, calling `IdpCollector.authorize()` (DaVinci) or `IdpCallback.authorize()` (Journey) will use the Facebook iOS SDK to perform the authentication.

## Facebook Developer Console Configuration for Native Integration

Follow the official documentation provided by
the [Facebook Developer Console](https://developers.facebook.com/docs/facebook-login/ios) to set up your Facebook
app and integrate the Facebook SDK. This involves:

1. **Creating a Facebook App:** Register your application on the Facebook for Developers platform.
2. **Adding Facebook Login Product:** Enable the Facebook Login product for your app.
3. **Configuring iOS Platform:** Add your iOS platform details, including your app's Bundle ID.

Ensure that you have added the necessary permissions, such as `email` and `public_profile`, to your Facebook app
settings. These permissions will be requested from the user during the login process.

<img src="images/FacebookScope.png" width="500">

#### Configuring `Info.plist`

Add the following strings to your app's Info file, replacing the placeholders with your
actual Facebook App ID and Client Token:

```xml

    <key>FacebookAppID</key>
	<string>[your_facebook_app_id]</string>
	<key>FacebookClientToken</key>
	<string>[your_client_token]</string>

    <array>
    		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>fb[your_facebook_app_id]</string>
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
  FacebookRequestHandler.handleOpenURL(UIApplication.shared, url: url, options: nil)
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
          FacebookRequestHandler.handleOpenURL(UIApplication.shared, url: url, options: nil)
        }
    }
  }
}
}
```

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
