#if canImport(UIKit)
import UIKit
#endif
import LocalAuthentication

/// An authenticator that uses an application PIN for user verification.
/// This class provides an implementation for generating PIN-protected keys and authenticating the user by prompting for the PIN.
#if canImport(UIKit)
public class ApplicationPinDeviceAuthenticator: DefaultDeviceAuthenticator {
    
    private var pin: String?
    
    /// The type of authenticator, specifically `.applicationPin`.
    public override func type() -> DeviceBindingAuthenticationType {
        return .applicationPin
    }
    
    /// Generates a new cryptographic key pair protected by an application PIN.
    /// The key's access control is configured to require an application password, which will be the PIN provided by the user.
    /// - Throws: `DeviceBindingError.unknown` if access control creation fails.
    ///           `CryptoKeyError` if key generation fails.
    /// - Returns: A `KeyPair` containing the newly generated public and private keys.
    public override func generateKeys() async throws -> KeyPair {
        let cryptoKey = CryptoKey(keyTag: UUID().uuidString)

        let userPin: String?
        if let pin = self.pin, !pin.isEmpty {
            userPin = pin
        } else {
            userPin = await promptForPin()
            self.pin = userPin
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
    
    /// Authenticates the user by prompting for their application PIN.
    /// This method displays a `UIAlertController` to get the PIN from the user and then uses it to access the private key.
    /// - Parameter keyTag: The unique identifier of the private key to be accessed.
    /// - Returns: The `SecKey` representing the private key if authentication is successful.
    /// - Throws: `DeviceBindingError.authenticationFailed` if the user cancels or provides an incorrect PIN.
    ///           `DeviceBindingError.unknown` for other unexpected errors.
    public override func authenticate(keyTag: String) async throws -> SecKey {
        // The UI must be presented on the main thread.
        let userPin: String?
        if let pin = self.pin, !pin.isEmpty {
            userPin = pin
        } else {
            userPin = await promptForPin()
            self.pin = userPin
        }
        
        guard let pinData = userPin?.data(using: .utf8) else {
            throw DeviceBindingError.unknown
        }
        
        // The LAContext will hold the PIN credential.
        let context = LAContext()
        context.setCredential(pinData, type: .applicationPassword)
        
        //        let context = LAContext()
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
    @MainActor
    private func promptForPin() async -> String? {
        guard let windowScene =  UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController =  windowScene.windows.first?.rootViewController else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: "Enter PIN", message: "Please enter your application PIN to continue.", preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.isSecureTextEntry = true
                textField.keyboardType = .numberPad
            }
            
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                continuation.resume(returning: alert.textFields?.first?.text)
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
#endif
