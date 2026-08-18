[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

# PingOne MFA

## Overview

The `PingOneMFA` module wraps the PingOne MFA native SDK [PingOneSDK](https://github.com/pingidentity/pingone-mobile-sdk-ios) behind a clean, async/await Swift API. It is the adapter layer between your application and the PingOne MFA platform. All PingOne SDK callbacks are bridged to `async throws` functions — callers never need to work with raw callback closures.

---

## Features

- **Device Pairing** — pair new MFA accounts by scanning a QR code or entering a pairing key
- **OTP** — retrieve the current one-time passcode and its remaining validity window
- **Push Notifications (foreground)** — approve or deny incoming authentication requests while the app is active
- **Push Notifications (banner actions)** — handle Approve/Deny taps on system notification banners via `processRemoteNotificationAction`; register the required categories with `getNotificationCategories`
- **Mobile Payload** — generate a cryptographic mobile payload for server-side authentication flows

---

## Getting Started

### Prerequisites

- iOS 16 or higher
- A PingOne environment with push notifications and/or MFA configured. For documentation on setting up PingOne MFA, see [PingOne MFA documentation](https://docs.pingidentity.com/pingone/strong_authentication_mfa/p1_strong_authentication_configure_mobile_applications.html).

---

## Architecture Overview

```
┌──────────────────────────────────────────────────┐
│               Your Application                   │
│                                                  │
│   ┌────────────────────────────────────────────┐ │
│   │         Push / OTP / Pairing Handlers      │ │
│   │              (your app code)               │ │
│   └──────────────────────┬─────────────────────┘ │
│                          │                       │
│   ┌──────────────────────▼─────────────────────┐ │
│   │           PingOneMFA module                │ │
│   │         PingOneMFA (class)                 │ │
│   └──────────────────────┬─────────────────────┘ │
└──────────────────────────┼──────────────────────-┘
                           │
              ┌────────────▼─────────┐
              │   PingOne MFA SDK    │
              └──────────────────────┘
```

---

## Add Dependency

Add the package via Swift Package Manager in Xcode:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk", from: "<version>")
]
```

Then add `PingOneMFA` to your target's dependencies.

---

## Setup and Configuration

### 1. Initialize the SDK

Call `initialize()` once at application startup, before any other call. Pass the `Geo` that matches your PingOne environment's service region. The call is idempotent — repeated calls after a successful initialisation return immediately without re-entering the native SDK.

```swift
do {
    try await PingOneMFA.initialize(geo: .northAmerica)
} catch {
    print("Initialisation failed: \(error.localizedDescription)")
}
```

Supported regions:

| `Geo` | PingOne region |
|---|---|
| `.northAmerica` | North America |
| `.europe` | Europe |
| `.canada` | Canada |
| `.australia` | Australia |
| `.singapore` | Singapore |

### 2. Register the APNS Push Token

Call `setDeviceToken()` each time the system delivers a new push token — typically from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`. `initialize(geo:)` must have completed successfully before this call; `setDeviceToken` passes the token directly to the native PingOne SDK without re-initializing.

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Task {
        do {
            try await ensurePingOneMFAInitialized()
            try await PingOneMFA.setDeviceToken(deviceToken)
        } catch {
            print("Token registration failed: \(error.localizedDescription)")
        }
    }
}
```

Uses `.sandbox` token type in `DEBUG` builds and `.production` otherwise.

### 3. Register Notification Categories

At app launch, register PingOneMFA's notification categories with `UNUserNotificationCenter` so that actionable banner notifications are delivered correctly:

```swift
let categories = PingOneMFA.getNotificationCategories()
UNUserNotificationCenter.current().setNotificationCategories(categories)
```

---

## Usage

### Device Pairing

```swift
do {
    try await PingOneMFA.pair(pairingKey: pairingKey)
    // Pairing succeeded — update UI as needed
} catch {
    print("Pairing failed: \(error.localizedDescription)")
}
```

### Retrieve Paired Accounts

```swift
do {
    let deviceInfo = try await PingOneMFA.getDeviceInfo()
    for account in deviceInfo.accounts {
        print("\(account.name) \(account.family) | region: \(account.region)")
    }
    if let errors = deviceInfo.errors, !errors.isEmpty {
        print("Retrieved accounts with diagnostics: \(errors)")
    }
} catch {
    print("Failed to retrieve accounts: \(error.localizedDescription)")
}
```

### OTP

```swift
do {
    let otp = try await PingOneMFA.getOneTimePasscode()
    showCode(otp.code, otp.secondsRemaining)
} catch {
    print("OTP failed: \(error.localizedDescription)")
}
```

`OtpCodeInfo.secondsRemaining` is a non-negative snapshot computed at call time. Re-call `getOneTimePasscode()` when it reaches zero to receive the next code.

### Mobile Payload

```swift
do {
    let payload = try await PingOneMFA.generateMobilePayload()
    // Submit payload to your server-side authentication flow
} catch {
    print("Mobile payload failed: \(error.localizedDescription)")
}
```

### Push Notifications — Foreground

When your app is in the foreground, process the incoming notification and present the appropriate UI based on push type:

```swift
// In application(_:didReceiveRemoteNotification:fetchCompletionHandler:):
do {
    if let push = try await PingOneMFA.processRemoteNotification(userInfo: userInfo) {
        switch push.pushType {
            case .default:   showApproveDenyUI(push)
            case .challenge: showNumberChallengeUI(push)
            case .dry:       break // test push — no user action required
        }
    }
} catch {
    print("Push processing failed: \(error.localizedDescription)")
}
```

After the user responds:

```swift
// Approve (pass numberChallenge for .challenge type, nil for .default)
do {
    try await push.approveNotification(authMethod: "user", numberChallenge: selectedNumber) // or "biometric", depending on your UI
} catch {
    print("Approve failed: \(error.localizedDescription)")
}

// Deny
do {
    try await push.denyNotification()
} catch {
    print("Deny failed: \(error.localizedDescription)")
}
```

For number-matching challenge pushes, retrieve the options provided by the server:

```swift
let options: [Int] = push.getNumbersChallenge
// empty array when the server expects free-form digit entry
```

### Push Notifications — Notification Banner Actions

When the user taps Approve or Deny on the system notification banner, handle the action via `UNUserNotificationCenterDelegate`:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                             didReceive response: UNNotificationResponse,
                             withCompletionHandler completionHandler: @escaping () -> Void) {
    Task {
        do {
            let push = try await PingOneMFA.processRemoteNotificationAction(
                identifier: response.actionIdentifier,
                authenticationMethod: nil,
                userInfo: response.notification.request.content.userInfo
            )
            // push is nil when the SDK handled the action internally (no UI needed)
            if let push = push {
                // present approve/deny UI
            }
        } catch {
            print("Notification action failed: \(error.localizedDescription)")
        }
        completionHandler()
    }
}
```

---

## Error Handling

All `async` functions throw `PingOneMFAError` on failure. The native `PingOneSDKError` type is not exposed, so your app does not need a direct dependency on the `PingOneSDK` framework.

```swift
do {
    try await PingOneMFA.pair(pairingKey: pairingKey)
} catch let error as PingOneMFAError {
    print(error.message)
    error.internalErrorsList?.forEach { e in
        print("code=\(e.code) message=\(e.message)")
    }
} catch {
    print(error.localizedDescription)
}
```

---

## Sample Application

PingOne MFA functionality is demonstrated in the [PingExample](../SampleApps/PingExample) sample app under the **PINGONE MFA** section:

- QR code scanning for device pairing
- Paired accounts list
- OTP display with live countdown
- Push notification handling for DEFAULT, CHALLENGE, and DRY push types

See the [PingExample README](../SampleApps/PingExample/README.md) for build instructions.

---

## API Reference

### `PingOneMFA`

| Function | Returns | Description |
|---|---|---|
| `initialize(geo:)` | `async throws` | Configure the PingOne SDK for the selected service region. Idempotent after first success. |
| `setDeviceToken(_:)` | `async throws` | Register or refresh the APNS push token with PingOne. |
| `pair(pairingKey:)` | `async throws` | Pair a new MFA account. |
| `getDeviceInfo()` | `async throws -> PingOneMFADeviceInfo` | Return all paired accounts and any non-fatal diagnostic errors. |
| `getOneTimePasscode()` | `async throws -> OtpCodeInfo` | Return the current TOTP code and its remaining validity window. |
| `processRemoteNotification(userInfo:)` | `async throws -> PushNotification?` | Convert an APNS `userInfo` payload to a typed `PushNotification`. |
| `processRemoteNotificationAction(identifier:authenticationMethod:userInfo:)` | `async throws -> PushNotification?` | Handle a notification banner action; returns `nil` when the SDK handled it internally. |
| `generateMobilePayload()` | `async throws -> String` | Generate a mobile payload for server-side authentication. |
| `getNotificationCategories()` | `Set<UNNotificationCategory>` | Return notification categories to register with `UNUserNotificationCenter`. |

### `PingOneMFADeviceInfo`

| Field | Type | Description |
|---|---|---|
| `accounts` | `[PingOneMfaAccount]` | Parsed paired accounts found on this device |
| `errors` | `[PingOneMFAError]?` | Non-fatal diagnostic errors returned by the upstream SDK while account data was still available |

### `PingOneMfaAccount`

| Field | Type | Description |
|---|---|---|
| `region` | `String` | Region key from the PingOne response (e.g. `"NorthAmerica"`, `"Europe"`) |
| `id` | `String` | PingOne user ID |
| `deviceId` | `String` | Device ID within PingOne |
| `environmentId` | `String` | PingOne environment ID |
| `name` | `String` | User's given name |
| `family` | `String` | User's family name |

### `OtpCodeInfo`

| Field | Type | Description |
|---|---|---|
| `code` | `String` | Current TOTP passcode |
| `secondsRemaining` | `Int` | Non-negative seconds until the code expires (0 if already expired, snapshot at call time) |

### `PushNotification`

| Method / Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique identifier (UUID) for this notification instance |
| `approveNotification(authMethod:numberChallenge:)` | `async throws` | Approve the push authentication request |
| `denyNotification()` | `async throws` | Deny the push authentication request |
| `getNumbersChallenge` | `[Int]` | Options for a number-matching CHALLENGE push; empty array when free-form digit entry is expected |
| `pushType` | `PushType` | The interaction model required by this push (see `PushType`) |
| `isCancelAuthentication` | `Bool` | `true` when the notification type is `.authCanceled` |
| `title` | `String?` | Notification title extracted from the APNS payload |
| `message` | `String?` | Notification body extracted from the APNS payload |

### `PushType`

| Value | Description |
|---|---|
| `.default` | Standard authentication request — the user approves or denies with a single tap |
| `.challenge` | Number-matching push — present the options from `getNumbersChallenge`; an empty array means free-form digit entry is expected |
| `.dry` | Silent test push sent by the server to verify push registration — no user action required |

### `PingOneMFAError`

Thrown by all `async` functions on failure. The native `PingOneSDKError` is not exposed.

| Field | Type | Description |
|---|---|---|
| `message` | `String` | Human-readable error message; also surfaced via `localizedDescription` |
| `internalErrorsList` | `[PingOneMFAInternalError]?` | Structured list of individual SDK errors; `nil` when the failure did not originate from the native SDK |

### `PingOneMFAInternalError`

Individual error entry within `PingOneMFAError.internalErrorsList`.

| Field | Type | Description |
|---|---|---|
| `code` | `Int` | Numeric error code returned by the PingOne MFA native SDK |
| `message` | `String` | Human-readable error message returned by the native SDK |
| `userInfo` | `[String: String]` | Additional diagnostic key/value pairs returned by the server; may be empty |

---

## Troubleshooting

**Push notifications not received:**
- Verify the device token was registered via `PingOneMFA.setDeviceToken(_:)`.
- Confirm push notification entitlements and capabilities are enabled in your Xcode project.
- Check that the PingOne environment has APNS configured.

**`getOneTimePasscode()` fails with a device-not-paired error:**
- Ensure `PingOneMFA.pair(pairingKey:)` was called and succeeded before requesting an OTP.

**`generateMobilePayload()` fails:**
- Ensure `PingOneMFA.initialize(geo:)` was called and succeeded before this call.
- Check network connectivity and PingOne service status.

---

## License

Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.

This software may be modified and distributed under the terms of the MIT license. See the [LICENSE](../LICENSE) file for details.
