# PingBinding Module

The PingBinding Module provides device binding and signing capabilities for native applications. 

## Cryptographic Algorithm

The PingBinding Module uses **ES256** (ECDSA with P-256 curve and SHA-256) for all signing operations. This algorithm is compatible with iOS Secure Enclave, providing hardware-backed security for private keys.

## Installation

The PingBinding Module is available via Swift Package Manager and CocoaPods.

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "1.3.0")
```

Then, add `PingBinding` to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "PingBinding", package: "ping-ios-sdk")
    ]
)
```

Alternatively, in Xcode:
1. Go to **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/ForgeRock/ping-ios-sdk.git`
3. Select the version (1.3.0 or later)
4. Add the `PingBinding` library to your target

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'PingBinding', '~> 1.3.0'
```

Then run:

```bash
pod install
```

#### Dependencies

PingBinding has the following dependencies which will be automatically installed:

| Dependency | Version | Description |
|------------|---------|-------------|
| `PingOrchestrate` | ~> 1.3.0 | Core orchestration framework |
| `PingOidc` | ~> 1.3.0 | OIDC authentication support |
| `PingJourney` | ~> 1.3.0 | Journey-based authentication flow management |
| `PingMfaCommons` | ~> 1.3.0 | Common MFA utilities including JWT signing |
| `PingStorage` | ~> 1.3.0 | Secure storage capabilities |
| `PingLogger` | ~> 1.3.0 | Logging framework |

These dependencies provide the foundation for device binding operations, including secure key storage, JWT signing, and authentication flow management.

## Migration from Legacy SDK

The PingBinding Module includes automatic migration capabilities to seamlessly upgrade from legacy SDK versions (prior to 1.3.0) to the new storage format. This ensures that existing device bindings and user keys are preserved when upgrading your application.

### What Gets Migrated

The migration process handles:

- **User Key Metadata**: Migrates all user key information including user IDs, usernames, key identifiers, and authentication types
- **Key References**: Preserves references to cryptographic keys stored in the keychain
- **Authentication Types**: Maintains the configured authentication method (biometric, application PIN, etc.)

### Automatic Migration

Migration is **automatically triggered** when the PingBinding module is initialized. This happens when:

1. The Journey framework registers callbacks internally, OR
2. You manually call `BindingModule.registerCallbacks()`

The migration runs in the background and does not block your application. If no legacy data is found, the migration is silently skipped.

### Migration Process

The migration follows these steps:

1. **Check for Legacy Data**: Verifies if data exists in the legacy keychain location (`com.forgerock.ios.devicebinding.keychainservice`)
2. **Read User Keys**: Retrieves all user key metadata from the legacy storage
3. **Migrate to New Storage**: Saves keys to the new storage format, avoiding duplicates
4. **Cleanup**: Removes legacy keychain data after successful migration (optional)

### Manual Migration

If you need more control over the migration process, you can trigger it manually:

```swift
import PingBinding
import PingLogger

// Basic migration
Task {
    do {
        try await BindingMigration.migrate()
        print("Migration completed successfully")
    } catch MigrationError.noLegacyDataFound {
        print("No legacy data to migrate")
    } catch {
        print("Migration failed: \(error)")
    }
}
```

### Advanced Migration Options

You can customize the migration behavior with additional parameters:

```swift
import PingBinding

Task {
    try await BindingMigration.migrate(
        accessGroup: "com.myapp.shared",     // Keychain access group if configured
        logger: Logger.standard,              // Logger for debugging
        cleanupLegacyData: true,             // Remove legacy data after migration
        storageConfig: nil                    // Custom storage configuration (optional)
    )
}
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `accessGroup` | `String?` | `nil` | The keychain access group that was configured in the legacy SDK. Only needed if your app uses keychain access groups for sharing data. |
| `logger` | `Logger?` | `nil` | Optional logger for debugging and monitoring migration progress. |
| `cleanupLegacyData` | `Bool` | `true` | Whether to delete legacy keychain data after successful migration. Set to `false` if you want to preserve the legacy data. |
| `storageConfig` | `UserKeyStorageConfig?` | `nil` | Custom storage configuration. If not provided, uses the default configuration. |

### Migration Error Handling

The migration can throw the following errors:

| Error | Description |
|-------|-------------|
| `MigrationError.noLegacyDataFound` | No legacy data exists to migrate. This is normal for new installations or apps that have already been migrated. |
| `MigrationError.invalidLegacyData` | Legacy data is corrupted or in an unexpected format. |
| `MigrationError.failedToReadLegacyKeys` | Unable to read legacy keychain data due to keychain access errors. |
| `MigrationError.failedToSaveKeys` | Unable to save migrated keys to new storage. |
| `MigrationError.failedToDeleteLegacyData` | Unable to delete legacy data after migration (migration still succeeded). |

### Logging Migration Progress

To monitor the migration process, provide a logger:

```swift
import PingBinding
import PingLogger

// Set logger for automatic migration via BindingModule
BindingModule.setLogger(Logger.standard)

// Or for manual migration
Task {
    try await BindingMigration.migrate(logger: Logger.standard)
}
```

The migration logs include:
- Migration start and completion
- Number of keys found and migrated
- Duplicate key detection
- Cleanup status
- Any errors encountered

### Migration Guarantees

The migration process is:

- **Idempotent**: Can be run multiple times safely without duplicating data
- **Non-blocking**: Runs asynchronously in the background
- **Safe**: Does not modify or delete legacy data until migration succeeds
- **Duplicate-aware**: Checks for existing keys before migrating to prevent duplicates

### Testing Migration

For testing purposes, you can reset the migration state:

```swift
// Only use in test environments
await BindingMigration.resetMigrationState()
```

**Warning**: This should only be used in test code. Resetting the migration state in production code may cause the migration to run multiple times.

## Usage

### Callback Registration

PingBinding callbacks (`DeviceBindingCallback` and `DeviceSigningVerifierCallback`) are **automatically registered** when you use the Journey framework. The callbacks are registered when `CallbackRegistry.shared.registerDefaultCallbacks()` is called internally by the Journey initialization.

**No explicit registration is required** in your application code when using Journey flows.

#### Manual Registration (Optional)

If you need to use PingBinding callbacks outside of the Journey framework, you can manually register them:

```swift
import PingBinding

@main
struct MyApp: App {
    
    init() {
        // Only needed if NOT using Journey framework
        BindingModule.registerCallbacks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Binding a Device

To bind a device, you'll receive a `DeviceBindingCallback` from the AIC authentication flow. You can then call the `bind()` method on the callback to handle the binding process.

```swift
import PingBinding
import PingJourney

func handleDeviceBinding(callback: DeviceBindingCallback, onNext: @escaping () -> Void) {
    Task {
        do {
            try await callback.bind()
            print("Device bound successfully")
        } catch {
            print("Device binding failed: \(error.localizedDescription)")
            viewModel.error = error
        }
        // Continue to the next node
        onNext()
    }
}
```

### Signing a Transaction

To sign a transaction, you'll receive a `DeviceSigningVerifierCallback`. Call the `sign()` method on the callback to sign the data.

```swift
import PingBinding
import PingJourney

func handleDeviceSigning(callback: DeviceSigningVerifierCallback, onNext: @escaping () -> Void) {
    Task {
        let result = await callback.sign()
        switch result {
        case .success:
            print("Signing successful")
        case .failure(let error):
            print("Signing failed: \(error.localizedDescription)")
        }
        // Continue to the next node
        onNext()
    }
}
```

### Advanced Usage & Customization

The SDK allows for customization of the device authentication process, particularly for handling Application PIN authentication with a custom user interface.

#### Using a Custom PIN Collector

By default, if Application PIN authentication is required, the SDK presents a system alert to collect the PIN. You can override this behavior by providing a custom implementation of the `PinCollector` protocol. This allows you to present your own UI for PIN entry.

Here is a step-by-step guide to implementing a custom PIN collector:

**Step 1: Create a Custom UI for PIN Collection**

First, create a view that will serve as your PIN entry screen. This example uses SwiftUI to create a simple view that collects a 4-digit PIN.

```swift
// In your application, e.g., PinCollectorView.swift
import SwiftUI
import PingBinding

struct PinCollectorView: View {
    let prompt: Prompt
    let completion: (String?) -> Void
    
    @State private var pin: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(prompt.title)
                .font(.title)
            Text(prompt.description)
                .font(.subheadline)
            
            TextField("4-digit PIN", text: $pin)
                .keyboardType(.numberPad)
                .padding()
            
            HStack {
                Button("Cancel") { completion(nil) }
                Button("Submit") { completion(pin) }
                    .disabled(pin.count != 4)
            }
        }
        .padding()
    }
}
```

**Step 2: Implement the `PinCollector` Protocol**

Next, create a class that conforms to the `PinCollector` protocol. This class is responsible for presenting your custom UI and returning the collected PIN via the completion handler.

```swift
// In your application, e.g., CustomPinCollector.swift
import UIKit
import SwiftUI
import PingBinding

class CustomPinCollector: PinCollector {
    func collectPin(prompt: Prompt, completion: @escaping @Sendable (String?) -> Void) {
        DispatchQueue.main.async {
            guard let topVC = UIApplication.shared.windows.first?.rootViewController else {
                completion(nil)
                return
            }
            
            let pinView = PinCollectorView(prompt: prompt) { pin in
                topVC.dismiss(animated: true) {
                    completion(pin)
                }
            }
            
            let hostingController = UIHostingController(rootView: pinView)
            topVC.present(hostingController, animated: true)
        }
    }
}
```

**Step 3: Use the Custom Collector During Binding and Signing**

Finally, when you handle the `DeviceBindingCallback` or `DeviceSigningVerifierCallback`, you can provide a custom PIN collector through the configuration.

**For Device Binding:**

```swift
// In your view that handles the DeviceBindingCallback
import PingBinding

func handleDeviceBinding(callback: DeviceBindingCallback, onNext: @escaping () -> Void) {
    Task {
        let result = await callback.bind { config in
            // Customize the PIN collector for application PIN authentication
            config.pinCollector = CustomPinCollector()
        }
        
        // Handle result...
        onNext()
    }
}
```

**For Device Signing:**

```swift
// In your view that handles the DeviceSigningVerifierCallback
import PingBinding

func handleDeviceSigning(callback: DeviceSigningVerifierCallback, onNext: @escaping () -> Void) {
    Task {
        let result = await callback.sign { config in
            // Customize the PIN collector for application PIN authentication
            config.pinCollector = CustomPinCollector()
        }
        
        // Handle result...
        onNext()
    }
}
```

### Advanced Authenticator Configuration

You can further customize authenticators by providing configuration objects:

**AppPinAuthenticator Configuration:**

```swift
import PingBinding

let result = await callback.bind { config in
    // Create a custom AppPinConfig
    let appPinConfig = AppPinConfig(
        logger: myCustomLogger,
        prompt: Prompt(title: "Enter PIN", subtitle: "Security", description: "Enter your 4-digit PIN"),
        pinRetry: 5,
        keyTag: "my-custom-key-tag",
        keySizeInBits: 256, // P-256 curve for ES256 algorithm
        pinCollector: CustomPinCollector()
    )
    
    // Use the custom authenticator with the config
    config.deviceAuthenticator = AppPinAuthenticator(config: appPinConfig)
}
```

**Note:** The `keySizeInBits` parameter should always be set to `256` for compatibility with iOS Secure Enclave. This is the default value and typically doesn't need to be specified.

**BiometricAuthenticator Configuration:**

```swift
import PingBinding

let result = await callback.bind { config in
    // Create a custom BiometricAuthenticatorConfig
    let biometricConfig = BiometricAuthenticatorConfig(
        logger: myCustomLogger,
        keyTag: "my-biometric-key-tag",
        keySizeInBits: 256 // P-256 curve for ES256 algorithm
    )
    
    // Set the authenticator config - the appropriate authenticator (BiometricOnlyAuthenticator 
    // or BiometricDeviceCredentialAuthenticator) will be used based on the callback type
    config.authenticatorConfig = biometricConfig
}
```

**Note:** The `keySizeInBits` parameter should always be set to `256` for compatibility with iOS Secure Enclave. This is the default value and typically doesn't need to be specified.

### Custom User Key Selection

When signing with a device and the callback doesn't specify a userId, or when multiple keys are available for the same user, the SDK needs to determine which key to use. By default, the SDK presents a system alert (UIAlertController with action sheet) for the user to choose. You can customize this behavior by implementing the `UserKeySelector` protocol.

This is particularly useful when:
- Multiple users have bound their devices on the same physical device
- You want to provide a branded UI for key selection
- You need to display additional context about each key

**Step 1: Create a Custom UI for Key Selection**

First, create a SwiftUI view that will display the available keys and allow the user to select one:

```swift
// In your application, e.g., UserKeySelectorView.swift
import SwiftUI
import PingBinding

struct UserKeySelectorView: View {
    let userKeys: [UserKey]
    let prompt: Prompt
    let completion: (UserKey?) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !prompt.description.isEmpty {
                    Text(prompt.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                List(userKeys, id: \.id) { userKey in
                    Button(action: {
                        completion(userKey)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            if !userKey.username.isEmpty {
                                Text(userKey.username)
                                    .font(.headline)
                            }
                            if !userKey.userId.isEmpty {
                                Text("User ID: \(userKey.userId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("Auth: \(userKey.authType.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(prompt.title.isEmpty ? "Select Device Key" : prompt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        completion(nil)
                    }
                }
            }
        }
    }
}
```

**Step 2: Implement the `UserKeySelector` Protocol**

Create a class that conforms to the `UserKeySelector` protocol. This class is responsible for presenting your custom UI and returning the selected key:

```swift
// In your application, e.g., CustomUserKeySelector.swift
import UIKit
import SwiftUI
import PingBinding

class CustomUserKeySelector: UserKeySelector {
    func selectKey(userKeys: [UserKey], prompt: Prompt) async -> UserKey? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topVC = self.getTopViewController() else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let selectorView = UserKeySelectorView(
                    userKeys: userKeys,
                    prompt: prompt
                ) { selectedKey in
                    topVC.dismiss(animated: true) {
                        continuation.resume(returning: selectedKey)
                    }
                }
                
                let hostingController = UIHostingController(rootView: selectorView)
                hostingController.modalPresentationStyle = .formSheet
                topVC.present(hostingController, animated: true)
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
}
```

**Step 3: Use the Custom Selector During Signing**

When handling the `DeviceSigningVerifierCallback`, provide your custom key selector through the configuration:

```swift
import PingBinding

func handleDeviceSigning(callback: DeviceSigningVerifierCallback, onNext: @escaping () -> Void) {
    Task {
        let result = await callback.sign { config in
            // Use custom UI for selecting from multiple device keys
            config.userKeySelector = CustomUserKeySelector()
        }
        
        switch result {
        case .success:
            print("Signing successful")
        case .failure(let error):
            print("Signing failed: \(error.localizedDescription)")
        }
        
        onNext()
    }
}
```

**Note:** The default `DefaultUserKeySelector` presents a system alert with an action sheet showing the available keys. You only need to implement a custom selector if you want a different UI experience.

## License

The PingBinding SDK is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).