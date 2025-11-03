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

func handleDeviceSigning(callback: DeviceSigningVerifierCallback, onNext: @escaping () -> Void) {
    Task {
        let result = await callback.sign()
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
        pinCollector: CustomPinCollector()
    )
    
    // Use the custom authenticator with the config
    config.deviceAuthenticator = AppPinAuthenticator(config: appPinConfig)
}
```

**BiometricAuthenticator Configuration:**

```swift
import PingBinding

let result = await callback.bind { config in
    // Create a custom BiometricAuthenticatorConfig
    let biometricConfig = BiometricAuthenticatorConfig(
        logger: myCustomLogger,
        keyTag: "my-biometric-key-tag"
    )
    
    // Set the authenticator config - the appropriate authenticator (BiometricOnlyAuthenticator 
    // or BiometricDeviceCredentialAuthenticator) will be used based on the callback type
    config.authenticatorConfig = biometricConfig
}
```

## License

The PingBinding SDK is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

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