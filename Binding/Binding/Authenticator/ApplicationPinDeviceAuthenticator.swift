
import UIKit
import LocalAuthentication

/// An authenticator that uses an application PIN for user verification.
/// This class provides an implementation for generating PIN-protected keys and authenticating the user by prompting for the PIN.
class ApplicationPinDeviceAuthenticator: DefaultDeviceAuthenticator {
    
    /// The type of authenticator, specifically `.applicationPin`.
    override func type() -> DeviceBindingAuthenticationType {
        return .applicationPin
    }
    
    /// Generates a new cryptographic key pair protected by an application PIN.
    /// The key's access control is configured to require an application password, which will be the PIN provided by the user.
    /// - Throws: `DeviceBindingError.unknown` if access control creation fails.
    ///           `CryptoKeyError` if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    override func generateKeys() throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)
        
        // Create access control flags that require an application password for private key usage.
        guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                  kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                  .applicationPassword,
                                                                  nil) else {
            throw DeviceBindingError.unknown
        }
        
        // Generate the key pair with the specified access control.
        return try cryptoKey.generateKeyPair(attestation: .none, accessControl: accessControl)
    }
    
    /// Authenticates the user by prompting for their application PIN.
    /// This method displays a `UIAlertController` to get the PIN from the user and then uses it to access the private key.
    /// - Parameter keyTag: The unique identifier of the private key to be accessed.
    /// - Returns: The `SecKey` representing the private key if authentication is successful.
    /// - Throws: `DeviceBindingError.authenticationFailed` if the user cancels or provides an incorrect PIN.
    ///           `DeviceBindingError.unknown` for other unexpected errors.
    override func authenticate(keyTag: String) async throws -> SecKey {
        // The UI must be presented on the main thread.
        guard let pin = await promptForPin() else {
            throw DeviceBindingError.authenticationFailed
        }
        
        guard !pin.isEmpty else {
            throw DeviceBindingError.authenticationFailed
        }
        
        guard let pinData = pin.data(using: .utf8) else {
            throw DeviceBindingError.unknown
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
            throw DeviceBindingError.authenticationFailed
        }
        
        return keyItem as! SecKey
    }
    
    /// Checks if the authenticator is supported. Since it's a software-based PIN, it is always supported.
    /// - Parameter attestation: The attestation type (currently ignored).
    /// - Returns: `true`.
    override func isSupported(attestation: Attestation) -> Bool {
        return true
    }
    
    /// Deletes all keys associated with the application PIN authenticator.
    /// - Throws: `UserKeysStorageError` or `CryptoKeyError` if deletion fails.
    override func deleteKeys() async throws {
        let userKeys = try UserKeysStorage(config: UserKeyStorageConfig()).findAll()
        for userKey in userKeys {
            if userKey.authType == .applicationPin {
                try CryptoKey(keyTag: userKey.keyTag).deleteKeyPair()
            }
        }
    }
    
    /// Presents a `UIAlertController` to the user to enter their PIN.
    /// - Returns: The entered PIN string, or `nil` if the user cancels.
    @MainActor
    private func promptForPin() async -> String? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        
        let title = prompt?.title ?? "Enter PIN"
        let message = prompt?.description ?? "Please enter your application PIN to continue."
        
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "PIN"
                textField.isSecureTextEntry = true
                textField.keyboardType = .numberPad
            }
            
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                let pin = alert.textFields?.first?.text
                continuation.resume(returning: pin)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: nil)
            }
            
            alert.addAction(okAction)
            alert.addAction(cancelAction)
            
            rootViewController.present(alert, animated: true)
        }
    }
}
