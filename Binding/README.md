# PingBinding SDK

The PingBinding SDK provides device binding and signing capabilities for native applications.

## Installation

The PingBinding SDK is available via Swift Package Manager. To install it, add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/pingidentity/pingidentity-ios-sdk.git", from: "1.2.0")
```

Then, add `PingBinding` to your target's dependencies.

## Usage

### Registering the Binding Module

Before using any of the PingBinding features, you must register the module with the `CallbackRegistry`. This is typically done in your `AppDelegate` or main `App` struct:

```swift
import PingBinding

@main
struct MyApp: App {
    
    init() {
        BindingModule.register()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Binding a Device

To bind a device, you'll receive a `DeviceBindingCallback` from the PingFederate authentication flow. You can then call the `bind()` method on the callback to handle the binding process.

```swift
import PingBinding
import PingJourney

func handleDeviceBinding(callback: DeviceBindingCallback, viewModel: JourneyViewModel) {
    Task {
        do {
            try await callback.bind()
            print("Device bound successfully")
            viewModel.advance()
        } catch {
            print("Device binding failed: \(error.localizedDescription)")
            viewModel.error = error
        }
    }
}
```

### Signing a Transaction

To sign a transaction, you'll receive a `DeviceSigningVerifierCallback`. Call the `sign()` method on the callback to sign the data.

```swift
import PingBinding
import PingJourney

func handleDeviceSigning(callback: DeviceSigningVerifierCallback, viewModel: JourneyViewModel) {
    Task {
        do {
            try await callback.sign()
            print("Signing successful")
            viewModel.advance()
        } catch {
            print("Signing failed: \(error.localizedDescription)")
            viewModel.error = error
        }
    }
}
```

### Customization

The `PingBinder` can be configured with custom storage and device authenticators.

#### Custom Storage

By default, `PingBinder` uses a `UserKeysStorage` instance that stores keys in the keychain. You can provide your own implementation of the `UserKeysStorageProtocol`.

```swift
public protocol UserKeysStorageProtocol {
    func save(userKey: UserKey) throws
    func find(userId: String) throws -> UserKey?
    func delete(userId: String) throws
    func getAll() throws -> [UserKey]
}
```

#### Custom Device Authenticator

The SDK uses the device's local authentication (Face ID, Touch ID, or passcode) by default. You can provide a custom authenticator by implementing the `DeviceAuthenticatorProtocol`.

```swift
public protocol DeviceAuthenticatorProtocol {
    func
	authenticate(completion: @escaping (Result<Void, Error>) -> Void)
}
```

You can then initialize `PingBinder` with your custom implementations:

```swift
let customStorage = MyCustomKeyStorage()
let customAuthenticator = MyCustomAuthenticator()
let config = DeviceBindingConfig(userKeysStorage: customStorage, deviceAuthenticator: customAuthenticator)
let binder = PingBinder(config: config)
```

## License

The PingBinding SDK is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).