![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# Ping SDK – MFA Auth Migration Module

[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

## Overview

<!-- Brief description of what the module does and its architecture. -->

## Features

<!-- Bullet list of key features. -->

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "2.0.0")
]
```

Add the `PingAuthMigration` product to your target dependencies.

### CocoaPods

```ruby
pod 'PingAuthMigration', '~> 2.0.0'
```

## Usage

<!-- Quick-start code examples showing initialization and basic operations. -->

## Error Handling

<!-- Document module-specific error types and recovery strategies. -->

## Testing Strategy

<!-- Describe test suites, what they cover, and how to run them. -->

Recommended command:

```bash
xcodebuild test \
  -scheme PingTestHost \
  -workspace SampleApps/Ping.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:AuthMigrationTests
```

## License

PingAuthMigration is released under the [MIT License](../LICENSE).
