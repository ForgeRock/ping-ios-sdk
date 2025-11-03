#if canImport(UIKit)
import UIKit
#endif
import LocalAuthentication

/// An authenticator that uses an application PIN for user verification.
/// This class provides an implementation for generating PIN-protected keys and authenticating the user by prompting for the PIN.
public class AppPinAuthenticator: DefaultDeviceAuthenticator {
    
    private var pin: String?
    private let pinCollector: PinCollector
    
    /// Initializes the authenticator with a `PinCollector`.
    /// - Parameter pinCollector: The `PinCollector` to use for gathering the user's PIN.
    public init(pinCollector: PinCollector) {
        self.pinCollector = pinCollector
        super.init()
    }
    
    /// The type of authenticator, specifically `.applicationPin`.
    public override func type() -> DeviceBindingAuthenticationType {
        return .applicationPin
    }
    
    /// Generates a new cryptographic key pair protected by an application PIN.
    /// The key's access control is configured to require an application password, which will be the PIN provided by the user.
    /// - Throws: `DeviceBindingError.unknown` if access control creation fails.
    ///           `CryptoKeyError` if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    public override func register() async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)

        let userPin: String?
        if let pin = self.pin, !pin.isEmpty {
            userPin = pin
        } else {
            userPin = await promptForPin()
            self.pin = userPin
        }
        
        guard let userPin = userPin, !userPin.isEmpty else {
            throw DeviceBindingError.authenticationFailed
        }
        
        // Create access control flags that require an application password for private key usage.
#if !targetEnvironment(simulator)
        guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [.applicationPassword, .privateKeyUsage], nil) else {
            throw DeviceBindingError.unknown
        }
#else
        guard let accessControl =  SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [.applicationPassword], nil) else {
            throw DeviceBindingError.unknown
        }
#endif
        // Generate the key pair with the specified access control.
        return try cryptoKey.generateKeyPair(attestation: .none, accessControl: accessControl, pin: userPin)
    }
    
    /// - Returns: A `Result` containing the `SecKey` on success, or an `Error` on failure.
    public override func authenticate(keyTag: String) async -> Result<SecKey, Error> {
        // The UI must be presented on the main thread.
        let userPin: String?
        if let pin = self.pin, !pin.isEmpty {
            userPin = pin
        } else {
            userPin = await promptForPin()
            self.pin = userPin
        }
        
        guard let pinData = userPin?.data(using: .utf8) else {
            return .failure(DeviceBindingError.authenticationFailed)
        }
        
        // The LAContext will hold the PIN credential.
        let context = LAContext()
        context.setCredential(pinData, type: .applicationPassword)
        
        // When getPrivateKey is called, it will use the context to authorize access.
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context // Provide the context with the PIN
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyItem = item else {
            return .failure(DeviceBindingError.authenticationFailed)
        }
        
        return .success(keyItem as! SecKey)
    }
    
    /// Checks if the authenticator is supported. Since it's a software-based PIN, it is always supported.
    /// - Parameter attestation: The attestation type (currently ignored).
    /// - Returns: `true`.
    public override func isSupported(attestation: Attestation) -> Bool {
        return true
    }
    
    /// Deletes all keys associated with the application PIN authenticator.
    /// - Throws: `UserKeysStorageError` or `CryptoKeyError` if deletion fails.
    public override func deleteKeys() async throws {
        let userKeys = try await UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            if userKey.authType == .applicationPin {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
    
    /// Presents a `UIAlertController` to the user to enter their PIN.
    /// - Returns: The entered PIN string, or `nil` if the user cancels.
    private func promptForPin() async -> String? {
        return await withCheckedContinuation { continuation in
            let prompt = Prompt(title: "Enter PIN", subtitle: "", description: "Please enter your application PIN to continue.")
            self.pinCollector.collectPin(prompt: prompt) { pin in
                continuation.resume(returning: pin)
            }
        }
    }
}
