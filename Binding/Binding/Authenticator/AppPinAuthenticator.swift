#if canImport(UIKit)
import UIKit
#endif
import LocalAuthentication
import PingLogger

/// An authenticator that uses an application PIN for user verification.
/// This class provides an implementation for generating PIN-protected keys and authenticating the user by prompting for the PIN.
public class AppPinAuthenticator: DefaultDeviceAuthenticator {
    
    private let config: AppPinConfig
    
    /// Initializes the authenticator with an `AppPinConfig`.
    /// - Parameter config: The configuration object for the authenticator.
    public init(config: AppPinConfig) {
        self.config = config
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
        let cryptoKey = CryptoKey(keyTag: config.keyTag)
        
        guard let userPin = await promptForPin(prompt: config.prompt), !userPin.isEmpty else {
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
        for _ in 0..<config.pinRetry {
            let userPin = await promptForPin(prompt: config.prompt)
            
            guard let pinData = userPin?.data(using: .utf8) else {
                return .failure(DeviceBindingError.userCanceled)
            }
            
            let context = LAContext()
            let success = context.setCredential(pinData, type: .applicationPassword)
            
            if !success {
                // The call succeeded but returned false (e.g., credential could not be set)
                return .failure(DeviceBindingError.deviceNotSupported)
            }
            
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8) ?? Data(),
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef as String: true,
                kSecUseAuthenticationContext as String: context
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            if status == errSecSuccess, let keyItem = item {
                return .success(keyItem as! SecKey)
            } else {
                config.logger?.w("Failed to retrieve key with tag \(keyTag). Retrying...", error: nil)
            }
        }
        
        return .failure(DeviceBindingError.authenticationFailed)
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
    
    /// Presents a UI to the user to enter their PIN.
    /// - Returns: The entered PIN string, or `nil` if the user cancels.
    private func promptForPin(prompt: Prompt) async -> String? {
#if canImport(UIKit)
        return await withCheckedContinuation { continuation in
            config.pinCollector.collectPin(prompt: prompt) { pin in
                continuation.resume(returning: pin)
            }
        }
#else
        return nil
#endif
    }
}
