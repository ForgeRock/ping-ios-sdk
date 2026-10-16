[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../../../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingExample

A comprehensive iOS sample application demonstrating the Ping Orchestration SDK for iOS modules — Journey and DaVinci orchestration, OIDC (web) login, MFA (OATH, Push, PingOne MFA), device management, and developer tools.

The app's UI is built on the [PingDesignSystem](https://github.com/ForgeRock/ping-ios-design-system) Swift package — the shared Ping-branded design language (semantic tokens, view modifiers, components, and button styles) documented in that repo's [README](https://github.com/ForgeRock/ping-ios-design-system) and [DESIGN_SYSTEM.md](https://github.com/ForgeRock/ping-ios-design-system/blob/main/DESIGN_SYSTEM.md). The design system is a remote Swift Package Manager dependency; its documentation lives in that repository, not here.

## Getting Started

### Prerequisites

- A PingOne, Ping Advanced Identity Cloud / PingAM, or PingOne DaVinci environment to authenticate against — see [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker).
- iOS 16.0+
- Swift 6.0+
- Xcode 15+

### Running the App

1. Open `SampleApps/Ping.xcworkspace` (adds the SDK modules and the `PingDesignSystem` package to the `PingExample` project).
2. Select the `PingExample` scheme and a simulator or device.
3. Build and run.

### Configuring a Server

`Configurations.swift` ships with placeholder entries — they are not usable as-is and must be filled in with your own environment's values before running the sample flows. To configure the app, either:

- Use the in-app **Developer Tools > Configurations** screen to add, edit, or select a configuration at runtime — no rebuild required, or
- Fill in a `Configuration` entry in `defaultConfigurations` in `Configurations.swift` with your client ID, scopes, redirect URI, discovery endpoint, and server URL.

## Overview

`PingExample` is organized into five sections, navigable from the main screen:

| Section         | Demonstrates                                                                                  |
|-----------------|-------------------------------------------------------------------------------------------------|
| Authentication  | DaVinci, Journey, Backchannel Auth, OIDC (Web) login, and RFC 8628 Device Flow                  |
| User Management | Access token, user info, device management, and logout                                          |
| MFA             | QR-based device pairing, OATH (TOTP/HOTP) and Push account registration, and push notifications |
| PingOne MFA     | QR code registration, PingOne MFA accounts, one-time passcodes, and mobile payloads             |
| Developer Tools | Device info, logger, secure storage, binding keys, legacy-credential migration, and server configurations |

Each screen renders the callbacks/collectors returned by the corresponding SDK module (e.g. `PingJourney` callbacks, `PingDavinci` collectors) using SwiftUI views built on the `PingDesignSystem`.

### PingOneMFA

The **PingOne MFA** section demonstrates the `PingOneMFA` module, both directly and through DaVinci flows:

| Flow             | Summary                                                                                                                                                                                                                     |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| QR Code Registration  | Scans a PingOne MFA pairing QR code with the camera (or accepts the pairing key typed in manually) and pairs this device with `PingOneMFA.pair(pairingKey:)`.                                                                   |
| MFA Accounts          | Lists the accounts paired with this device (name, ID, and region). Pull to refresh, or use the scan button to pair another account; an empty list prompts you to scan a QR code.                                              |
| One-Time Passcode     | Shows the current one-time passcode for your paired account with a live countdown, and refreshes it automatically when it expires.                                                                                              |
| Mobile Payload        | Generates the mobile payload used for authentication and registration (`PingOneMFA.generateMobilePayload()`) and lets you copy it.                                                                                              |
| DaVinci Pairing       | Runs a DaVinci flow in which a `MobilePairingCollector` pairs this device with PingOne MFA, then returns to the main menu when pairing completes. Requires a DaVinci configuration.                                            |
| DaVinci Authorization | Runs a DaVinci flow that sends this device's mobile payload to DaVinci, then checks the device-authentication result the flow returns. It reports success only when the status is `COMPLETED` and the authenticators include both `swk` and `mfa`. Requires a DaVinci configuration. |

## License

This software may be modified and distributed under the terms of the MIT license. See the [LICENSE](../../../LICENSE) file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
