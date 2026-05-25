[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingCommons

The Commons module provides the core foundation and shared functionality for all  modules within the Ping Orchestration SDK for iOS. It includes base implementations for MFA Policies and other common utilities that are leveraged by other modules, including specialized MFA modules like Oath, Push, and Fido.

## Getting Started

### Prerequisites

- iOS 16.0+
- Swift 6.0+
- Xcode 15+

### Installation

The Commons module is typically included as a transitive dependency when you add other modules using it. However, you can also add it explicitly into your iOS project, add the dependency to your `Package.swift` or `Podfile` file.

**Dependencies:** PingCommons depends on `PingLogger` which will be automatically installed.

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

Then add the `PingCommons` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingCommons', '~> <version>'
```

## Usage

The Commons module is not intended to be used directly by applications. Instead, it provides the underlying functionality for the other modules. For usage examples, please refer to the documentation for the specific module you are using.

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved.

