[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingPush

## Overview

The Push module facilitates multi-factor authentication using push notifications, supporting both PingAM and Ping AIC formats. This module is responsible for securely storing push credentials, allowing applications to register devices for push notifications, and processing incoming notifications.

## Getting Started

### Prerequisites

- Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
- APNS configured for your application
- Push Notification Service configured for PingAM or Ping AIC
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

Add the `PingPush` product to your target dependencies.

#### CocoaPods

```ruby
pod 'PingPush', '~> <version>'
```

### Import the Module

```swift
import PingPush
```

## Usage

### Configuration & Initialization

Use the DSL-style factory to create a `PushClient` with optional overrides:

```swift
let pushClient = try await PushClient.createClient { config in
    config.logger = PingLogger(logLevel: .debug)
    config.enableCredentialCache = true
    config.notificationCleanupConfig = .hybrid(
        maxNotifications: 50,
        maxNotificationAgeDays: 14
    )
}
```

If `config.storage` or `config.policyEvaluator` are not provided, the client wires in `PushKeychainStorage` and `MfaPolicyEvaluator.create()` automatically.

### Credential Lifecycle

Register via pushauth URI (e.g. QR code) and manage stored credentials:

```swift
let credential = try await pushClient.addCredentialFromUri(enrollmentUri)

let credentials = try await pushClient.getCredentials()
let specific = try await pushClient.getCredential(credentialId: credential.id)

try await pushClient.deleteCredential(credentialId: credential.id)
```

Policy evaluation occurs during registration and retrieval. Failing policies lock credentials (`PushError.credentialLocked`) until compliance is restored.

### Device Token Management

```swift
try await pushClient.setDeviceToken(apnsTokenString)
let currentToken = try await pushClient.getDeviceToken()
```

Passing `credentialId` updates only that credential; otherwise the token is propagated to every stored credential via the configured handlers.

### Notification Processing

Supports APNs payloads, string (JWT) payloads, and `userInfo` dictionaries:

```swift
if let notification = try await pushClient.processNotification(messageData: apnsPayload) {
    // render notification to user
}

let jwtNotification = try await pushClient.processNotification(message: jwtString)
let userInfoNotification = try await pushClient.processNotification(userInfo: userInfo)
```

Automatic cleanup runs after each successful parse based on `NotificationCleanupConfig`.

### Notification Responses

```swift
try await pushClient.approveNotification(notificationId)
try await pushClient.approveChallengeNotification(notificationId, challengeResponse: "1234")
try await pushClient.approveBiometricNotification(notificationId, authenticationMethod: "face")
try await pushClient.denyNotification(notificationId)
```

Responses are routed through the registered `PushHandler` for the credential’s platform. Empty challenge responses or authentication methods throw `PushError.invalidParameterValue`.

### Notification Queries & Cleanup

```swift
let pending = try await pushClient.getPendingNotifications()
let all = try await pushClient.getAllNotifications()
let specificNotification = try await pushClient.getNotification(notificationId: id)

let removed = try await pushClient.cleanupNotifications(credentialId: optionalCredentialId)
await pushClient.close() // clears caches and runs global cleanup
```

`close()` should be invoked when the client is no longer needed (e.g., user sign-out) to clear caches and run a final cleanup pass.

### APNs Integration Checklist

1. Register for remote notifications and obtain the APNs token.
2. Pass the raw device token string to `setDeviceToken`.
3. Ensure the token is updated on every launch and whenever APNs indicates a change.
4. Forward payloads received in `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` or `userNotificationCenter(_:didReceive:withCompletionHandler:)` to `processNotification`.

### Error Handling

`PushClient` surfaces domain-specific `PushError` cases:

- `.invalidUri`, `.invalidParameterValue`
- `.deviceTokenNotSet`, `.credentialLocked`
- `.messageParsingFailed`, `.networkFailure`, `.storageFailure`

Most methods throw; callers should `try`/`catch` and map to user-facing messaging or retry logic. Integration tests exercise both success and failure flows to match Android parity.

## Testing Strategy

- `PushIntegrationTests` cover registration, notification processing, device token updates, policy enforcement, and error scenarios.
- `PushServiceTests` focus on service-level business logic and caching.
- Unit utilities such as `TestInMemoryPushStorage` and `IntegrationPushHandler` keep tests deterministic.
- Recommended command:

```bash
xcodebuild test \\
  -scheme PingTestHost \\
  -workspace SampleApps/Ping.xcworkspace \\
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \\
  -only-testing:PushTests/PushIntegrationTests
```

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All rights reserved.
