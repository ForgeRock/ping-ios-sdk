//
//  Device.swift
//  Device
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

@preconcurrency import Foundation
import PingOrchestrate
import CommonCrypto
import PingLogger
import PingStorage

/// A protocol that defines a unique identifier for a device.
public protocol DeviceIdentifier: Sendable {
    /// Returns a unique identifier for the device.
    var id: String { get async throws }
}

/// A struct representing a key pair for device identifier.
public struct DeviceIdentifierKeyPair: Codable, Sendable {
    /// The private key data.
    let privateKey: Data
    /// The public key data.
    let publicKey: Data
}

/// A class that implements the DeviceIdentifier protocol.
final class DeviceIdentifierImpl: DeviceIdentifier, Sendable, Codable {
    /// The key pair for the device identifier.
    let deviceIdentifierKeyPair: DeviceIdentifierKeyPair
    /// The unique identifier for the device.
    let id: String
    
    /// Initializes a DeviceIdentifierImpl with the given identifier and key pair.
    /// - Parameters:
    ///  - id: The unique identifier for the device.
    ///  - deviceIdentifierKeyPair: The key pair for the device identifier.
    init(id: String, deviceIdentifierKeyPair: DeviceIdentifierKeyPair) {
        self.id = id
        self.deviceIdentifierKeyPair = deviceIdentifierKeyPair
    }
}

/// A default implementation of the DeviceIdentifier protocol that generates and manages a device identifier using RSA key pairs.
/// This implementation uses the Keychain to store the generated keys and identifier securely.
/// It conforms to the DeviceIdentifier protocol and provides a unique identifier for the device.
/// It also provides methods to generate a key pair, retrieve the identifier, and hash data using SHA1.
public struct DefaultDeviceIdentifier: DeviceIdentifier, Sendable {
    /// RSA Key types enumeration
    ///
    /// - privateKey: Private Key for RSA Key Pair
    /// - publicKey: Public Key for RSA Key Pair
    enum DeviceIdentifierKeyType {
        case privateKey
        case publicKey
    }
    /// Constant Device Identifier Key
    let deviceIdentifierKey = "com.pingidentity.deviceIdentifier"
    /// Constant Public Key tag
    let publicKeyTag = "com.pingidentity.deviceIdentifier.public-key".data(using: .utf8)!
    /// Constant Private Key tag
    let privateKeyTag = "com.pingidentity.deviceIdentifier.private-key".data(using: .utf8)!
    /// Constant Key Pair type
    let keychainKeyType = kSecAttrKeyTypeRSA
    /// Constant RSA Key Pair size
    let keychainKeySize = 2048
    /// KeychainService instance to persist, and manage generated identifier
    var keychainService: any Storage<DeviceIdentifierImpl>
    /// Optional Logger for logging purposes
    var logger: Logger?
    
    /// Unique identifier for the device
    public var id: String {
        get async throws {
            return try await getIdentifier()
        }
    }
    
    /// Initializes DeviceIdentifier
    ///
    /// - Parameter keychainService: Designated KeychainService to persist, and manage generated Key Pair, and Identifier
    public init(logger: Logger? = nil) {
        self.keychainService = KeychainStorage<DeviceIdentifierImpl>(account: deviceIdentifierKey, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
    
    /// Generates, or retrieves an identifier, returns
    ///
    /// - Returns: Uniquely generated Identifier as per Keychain Sharing Access Group
    @discardableResult func getIdentifier() async throws -> String {
        
        if let deviceIdentifier = try await self.keychainService.get() {
            logger?.i("Device Identifier is retrieved from Device Identifier Store")
            // If the identifier was found from KeychainService
            return deviceIdentifier.id
        }
        do {
            let deviceIdentifierKeyPair = try self.generateKeyPair()
            let identifier = self.hashAndBase64Data(deviceIdentifierKeyPair.publicKey)
            let deviceIdentifier = DeviceIdentifierImpl(id: identifier, deviceIdentifierKeyPair: deviceIdentifierKeyPair)
            try await self.keychainService.save(item: deviceIdentifier)
            
            return deviceIdentifier.id
        } catch {
            logger?.e("Failed to generate Key Pair for Device Identifier", error: error)
            logger?.i("For some reason Identifier was not found, and Key Pair generation and/or store process failed, we will use randomly generated UUID instead")
            let uuid = UUID().uuidString
            let uuidData = uuid.data(using: .utf8)!
            // Hash UUID string, and persists it
            let identifier = self.hashAndBase64Data(uuidData)
            let emptyData = DeviceIdentifierKeyPair(privateKey: Data(), publicKey: Data())
            let deviceIdentifier = DeviceIdentifierImpl(id: identifier, deviceIdentifierKeyPair: emptyData)
            try await self.keychainService.save(item: deviceIdentifier)
            
            return deviceIdentifier.id
        }
    }
    
    
    /// Hashes given Data using SHA1
    ///
    /// - Parameter data: Data to be hashed
    /// - Returns: Hashed String of given Data
    func hashAndBase64Data(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hexString = Data(bytes: digest, count: digest.count).toHexString()
        return hexString
    }
    
    
    /// Generates Key Pair, and persists generated Keys
    ///
    /// - Returns: A boolean result of whether Key Pair generation, and store process was successful or not
    func generateKeyPair() throws -> DeviceIdentifierKeyPair {
        logger?.i("Generating KeyPair for Device Identifier")
        let publicKeyPairAttr: [String: Any] = self.buildKeyAttr(.publicKey)
        let privateKeyPairAttr: [String: Any] = self.buildKeyAttr(.privateKey)
        
        let keyPairAttr: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPublicKeyAttrs as String: publicKeyPairAttr,
            kSecPrivateKeyAttrs as String: privateKeyPairAttr
        ]
        
        var publicKey: SecKey?
        var privateKey: SecKey?
        let status = SecKeyGeneratePair(keyPairAttr as CFDictionary, &publicKey, &privateKey)
        
        if status == noErr, let _ = privateKey, let _ = publicKey {
            let publicKeyQuery = self.buildQuery(.publicKey)
            var publicKeyDataRef: CFTypeRef?
            let publicKeyStatus = SecItemCopyMatching(publicKeyQuery as CFDictionary, &publicKeyDataRef)
            let privateKeyQuery = self.buildQuery(.privateKey)
            var privateKeyDataRef: CFTypeRef?
            let privateKeyStatus = SecItemCopyMatching(privateKeyQuery as CFDictionary, &privateKeyDataRef)
            
            if publicKeyStatus == noErr, let publicKeyData = publicKeyDataRef as? Data, privateKeyStatus == noErr, let privateKeyData = privateKeyDataRef as? Data {
                
                return DeviceIdentifierKeyPair(privateKey: privateKeyData, publicKey: publicKeyData)
            }
            else {
                throw NSError(domain: "DeviceIdentifierError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve Key Pairs from Keychain Service"])
            }
        }
        else {
            throw NSError(domain: "DeviceIdentifierError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to generate Key Pair using SecKeyGeneratePair()"])
        }
    }
    
    
    /// Builds Dictionary of Keychain operation attributes for Key Pair generation based on given Key Type
    ///
    /// - Parameter keyType: RSA Key Type whether Public or Private Key
    /// - Returns: A dictionary of Keychain operation attributes
    func buildKeyAttr(_ keyType: DeviceIdentifierKeyType) -> [String: Any] {
        var query: [String: Any] = [:]
        
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrIsPermanent as String] = true
        
        switch keyType {
        case .privateKey:
            query[kSecAttrLabel as String] = "Ping SDK Device identifier private key"
            query[kSecAttrApplicationTag as String] = self.privateKeyTag
            break
        case .publicKey:
            query[kSecAttrLabel as String] = "Ping SDK Device identifier public key"
            query[kSecAttrApplicationTag as String] = self.publicKeyTag
            break
        }
        
        return query
    }
    
    
    /// Builds Dictionary of Keychain operation attributes for retrieving Key based on given Key Type
    ///
    /// - Parameter keyType: RSA Key Type whether Public or Private Key
    /// - Returns: A dictionary of Keychain operation attributes
    func buildQuery(_ keyType: DeviceIdentifierKeyType) -> [String: Any] {
        var query: [String: Any] = [:]
        query[kSecClass as String] = kSecClassKey
        query[kSecAttrKeyType as String] = self.keychainKeyType
        query[kSecReturnData as String] = true
        
        switch keyType {
        case .privateKey:
            query[kSecAttrApplicationTag as String] = self.privateKeyTag
            break
        case .publicKey:
            query[kSecAttrApplicationTag as String] = self.publicKeyTag
            break
        }
        
        return query
    }
}


extension Data {
    /// Converts Data to a hexadecimal string representation.
    func toHexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
