[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# Ping SDK - Commons Module

The Commons module provides the core foundation and shared functionality for all  modules within the Ping Identity iOS SDK. It includes base implementations for MFA Policies and other common utilities that are leveraged by other modules, including specialized MFA modules like Oath, Push, and Fido.

## Getting Started

### Installation

#### CocoaPods

The Commons module is typically included as a transitive dependency when you add other modules using it. However, you can also add it explicitly to your `Podfile`:

```ruby
pod 'PingCommons', '~> 1.3.1'
```

Then run:

```bash
pod install
```

**Note:** This module is automatically included when you install:
- `PingBinding`
- `PingOath`
- `PingPush`
- `DeviceClient`
- `ReCaptchaEnterprise`
- `DeviceProfile`
- `Journey`
- `Davinci`
- `Fido`
- `Oidc`

#### Swift Package Manager

Add the Ping iOS SDK to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "1.3.1")
]
```

Then add the Commons module to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "PingCommons", package: "ping-ios-sdk")
        ]
    )
]
```

Alternatively, in Xcode:
1. Go to **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/ForgeRock/ping-ios-sdk.git`
3. Select version 1.3.1 or later
4. Add the `PingCommons` library to your target

**Dependencies:** PingCommons depends on `PingLogger` which will be automatically installed.

## Usage

The Commons module is not intended to be used directly by applications. Instead, it provides the underlying functionality for the other  modules. For usage examples, please refer to the documentation for the specific module you are using:



## License

Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

