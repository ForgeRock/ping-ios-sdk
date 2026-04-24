[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingAuthMigration

`PingAuthMigration` migrates OATH (TOTP/HOTP) and Push credentials from the legacy `FRAuthenticator` SDK Keychain storage to the modern `PingOath` / `PingPush` storage format.

## Getting Started

### Prerequisites

- Ping Advanced Identity Cloud / PingAM [Supported Versions](https://support.pingidentity.com/s/article/Ping-Identity-EOL-Tracker)
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

Then add the `PingAuthMigration` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingAuthMigration', '~> <version>'
```

### Import the Module

```swift
import PingAuthMigration
```

## Usage

### Quick Start — Fire and Forget

Call this once at app startup (e.g., in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or a SwiftUI `App.init`):

```swift
import PingAuthMigration

Task {
    let didMigrate = await AuthMigration.migrateIfNeeded()
    if didMigrate {
        print("FRAuthenticator credentials migrated successfully")
    }
}
```

`migrateIfNeeded()` returns `true` if migration ran, `false` if no legacy data was found.

### With Progress Tracking

```swift
import PingAuthMigration
import PingCommons

Task {
    let stream = AuthMigration.start { config in
        config.logger = LogManager.logger          // Optional logger
        config.cleanupLegacyData = true            // Delete legacy data after migration (default)
    }

    for await progress in stream {
        switch progress {
        case .started:
            showLoadingIndicator()

        case .inProgress(let step, let current, let total):
            updateProgressBar(Float(current) / Float(total))
            updateStatus("Step \(current)/\(total): \(step)")

        case .stepCompleted(let step):
            print("Completed: \(step)")

        case .success(let message):
            hideLoadingIndicator()
            print(message)  // e.g. "Migrated 3 OATH + 1 Push credentials"

        case .error(let step, let error):
            hideLoadingIndicator()
            handleMigrationError(step: step, error: error)
        }
    }
}
```

### Check Before Migrating

```swift
let needed = await AuthMigration.isMigrationNeeded()
if needed {
    // Show a migration progress screen before continuing
}
```

## Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `accessGroup` | `String?` | `nil` | Keychain access group used by the legacy SDK |
| `logger` | `Logger?` | `nil` | Migration diagnostic logger |
| `cleanupLegacyData` | `Bool` | `true` | Delete legacy Keychain entries after migration |
| `oathStorage` | `(any OathStorage)?` | `nil` | Custom OATH storage (defaults to `OathKeychainStorage`) |
| `pushStorage` | `(any PushStorage)?` | `nil` | Custom Push storage (defaults to `PushKeychainStorage`) |

## Migration Scope

| Legacy Type | New Type | Notes |
|------------|----------|-------|
| `TOTPMechanism` | `OathCredential` (`.totp`) | Period, digits, algorithm preserved |
| `HOTPMechanism` | `OathCredential` (`.hotp`) | Counter preserved |
| `PushMechanism` | `PushCredential` | Auth endpoint query params stripped |
| Notification entries | Skipped | Not migrated |
| Device token entries | Skipped | Not migrated |

## Error Handling

```swift
case .error(let step, let error):
    if let migrationError = error as? AuthMigrationError {
        switch migrationError {
        case .noLegacyDataFound:
            // Normal on clean installs or after first migration
            break
        case .failedToDecryptLegacyData(let inner):
            logger.e("Decryption failed: \(inner)")
        case .failedToSaveOathCredentials(let inner):
            logger.e("OATH save failed: \(inner)")
        default:
            logger.e("Migration error: \(migrationError.localizedDescription)")
        }
    }
```

## Testing

```bash
xcodebuild test \
  -scheme PingTestHost \
  -workspace SampleApps/Ping.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
  -only-testing:AuthMigrationTests
```

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All rights reserved.
