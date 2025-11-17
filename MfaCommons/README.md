[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# Ping SDK - MFA Commons Module

The MFA Commons module provides the core foundation and shared functionality for all Multi-Factor Authentication (MFA) modules within the Ping Identity iOS SDK. It includes base implementations for MFA Policies and other common utilities that are leveraged by specialized MFA modules like OATH, Push, and FIDO2.

## Getting Started

### Prerequisites

- **iOS**: 13.0+
- **Swift**: 5.7+
- **Xcode**: 15.0+

### Installation

#### CocoaPods

The MFA Commons module is typically included as a transitive dependency when you add other MFA or binding modules. However, you can also add it explicitly to your `Podfile`:

```ruby
pod 'PingMfaCommons', '~> 1.3.1-beta1'
```

Then run:

```bash
pod install
```

**Note:** This module is automatically included when you install:
- `PingBinding` - Device binding and signing
- `PingOath` - OATH-based MFA
- `PingPush` - Push notification MFA

#### Swift Package Manager

Add the Ping iOS SDK to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "1.3.1-beta1")
]
```

Then add the MFA Commons module to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "PingMfaCommons", package: "ping-ios-sdk")
        ]
    )
]
```

Alternatively, in Xcode:
1. Go to **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/ForgeRock/ping-ios-sdk.git`
3. Select version 1.3.1-beta1 or later
4. Add the `PingMfaCommons` library to your target

**Dependencies:** PingMfaCommons depends on `PingLogger` which will be automatically installed.

## Usage

The MFA Commons module is not intended to be used directly by applications. Instead, it provides the underlying functionality for the other MFA modules. For usage examples, please refer to the documentation for the specific MFA module you are using:

- [OATH Module](../Oath/README.md)
- [Push Module](../Push/README.md)


## License

Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

