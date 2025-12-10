//
//  OathClient.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingCommons

/// Main public interface for OATH functionality.
/// This client handles TOTP and HOTP credential management and code generation.
///
/// The OathClient provides a high-level interface for managing OATH credentials,
/// including adding credentials from URIs, generating OTP codes, and managing
/// credential storage with policy enforcement.
///
/// Example usage:
/// ```swift
/// let client = try await OathClient.createClient { config in
///     config.storage = OathKeychainStorage()
///     config.enableCredentialCache = false
///     config.logger = LogManager.logger
/// }
///
/// let credential = try await client.addCredentialFromUri("otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP")
/// let code = try await client.generateCode(credential.id)
/// ```
public final class OathClient: @unchecked Sendable {

    // MARK: - Properties

    /// The configuration used by this client.
    private let configuration: OathConfiguration

    /// The internal service that handles OATH operations.
    private let oathService: OathService

    
    // MARK: - Factory Methods

    /// Factory method to create and initialize an OathClient instance.
    /// - Parameter configure: A closure to configure the OathConfiguration.
    /// - Returns: A fully initialized OathClient instance.
    /// - Throws: `OathError.initializationFailed` if client initialization fails.
    ///
    /// Example usage:
    /// ```swift
    /// let client = try await OathClient.createClient { config in
    ///     config.encryptionEnabled = false
    ///     config.logger = LogManager.logger
    ///     config.storage = OathKeychainStorage()
    /// }
    /// ```
    public static func createClient(
        configure: (OathConfiguration) -> Void = { _ in }
    ) async throws -> OathClient {
        let config = OathConfiguration.build(configure)
        return try await OathClient(configuration: config)
    }

    
    // MARK: - Initialization

    /// Private initializer for OathClient.
    /// - Parameter configuration: The configuration to use for this client.
    /// - Throws: `OathError.initializationFailed` if initialization fails.
    private init(configuration: OathConfiguration) async throws {
        self.configuration = configuration

        // Initialize default storage if none provided
        configuration.storage = configuration.storage ?? OathKeychainStorage()

        // Initialize policy evaluator if none provided
        let policyEvaluator = configuration.policyEvaluator ?? MfaPolicyEvaluator.create()

        // Initialize service layer
        self.oathService = OathService(
            configuration: configuration,
            policyEvaluator: policyEvaluator
        )

        configuration.logger.d("OATH client initialized successfully")
    }

    
    // MARK: - Credential Management

    /// Creates an OATH credential from a standard otpauth:// URI.
    /// - Parameter uri: The otpauth:// or mfauth:// URI string.
    /// - Returns: The created and stored OathCredential.
    /// - Throws: `OathError.invalidUri` if the URI is malformed.
    /// - Throws: `OathError.policyViolation` if credential policies are not met.
    /// - Throws: `OathStorageError` if storage operations fail.
    ///
    /// Supported URI formats:
    /// - `otpauth://totp/Issuer:Account?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30`
    /// - `otpauth://hotp/Issuer:Account?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&counter=0`
    /// - `mfauth://totp/Issuer:Account?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30`
    public func addCredentialFromUri(_ uri: String) async throws -> OathCredential {
        configuration.logger.d("Adding credential from URI")

        do {
            let credential = try await oathService.parseUri(uri)
            let storedCredential = try await oathService.addCredential(credential)

            configuration.logger.i("Successfully added credential: \(storedCredential.issuer)")
            return storedCredential
        } catch {
            configuration.logger.e("Failed to add credential from URI: \(error)", error: error)
            throw error
        }
    }

    /// Saves or updates an OATH credential in storage.
    /// - Parameter credential: The credential to save or update.
    /// - Returns: The saved credential with any policy updates applied.
    /// - Throws: `OathError.policyViolation` if credential policies are not met.
    /// - Throws: `OathStorageError` if storage operations fail.
    public func saveCredential(_ credential: OathCredential) async throws -> OathCredential {
        configuration.logger.d("Saving credential: \(credential.id)")

        do {
            let savedCredential = try await oathService.addCredential(credential)
            configuration.logger.i("Successfully saved credential: \(savedCredential.id)")
            return savedCredential
        } catch {
            configuration.logger.e("Failed to save credential \(credential.id): \(error)", error: error)
            throw error
        }
    }

    /// Retrieves all stored OATH credentials.
    /// - Returns: An array of all stored OathCredential objects.
    /// - Throws: `OathStorageError` if storage operations fail.
    public func getCredentials() async throws -> [OathCredential] {
        configuration.logger.d("Retrieving all credentials")

        do {
            let credentials = try await oathService.getCredentials()
            configuration.logger.d("Retrieved \(credentials.count) credentials")
            return credentials
        } catch {
            configuration.logger.e("Failed to retrieve credentials: \(error)", error: error)
            throw error
        }
    }

    /// Retrieves a specific OATH credential by its ID.
    /// - Parameter credentialId: The unique identifier of the credential.
    /// - Returns: The OathCredential if found, nil otherwise.
    /// - Throws: `OathStorageError` if storage operations fail.
    public func getCredential(_ credentialId: String) async throws -> OathCredential? {
        configuration.logger.d("Retrieving credential: \(credentialId)")

        do {
            let credential = try await oathService.getCredential(credentialId: credentialId)
            if credential != nil {
                configuration.logger.d("Found credential: \(credentialId)")
            } else {
                configuration.logger.d("Credential not found: \(credentialId)")
            }
            return credential
        } catch {
            configuration.logger.e("Failed to retrieve credential \(credentialId): \(error)", error: error)
            throw error
        }
    }

    /// Deletes an OATH credential by its ID.
    /// - Parameter credentialId: The unique identifier of the credential to delete.
    /// - Returns: true if the credential was deleted, false if it wasn't found.
    /// - Throws: `OathStorageError` if storage operations fail.
    public func deleteCredential(_ credentialId: String) async throws -> Bool {
        configuration.logger.d("Deleting credential: \(credentialId)")

        do {
            let deleted = try await oathService.removeCredential(credentialId: credentialId)
            if deleted {
                configuration.logger.i("Successfully deleted credential: \(credentialId)")
            } else {
                configuration.logger.d("Credential not found for deletion: \(credentialId)")
            }
            return deleted
        } catch {
            configuration.logger.e("Failed to delete credential \(credentialId): \(error)", error: error)
            throw error
        }
    }

    
    // MARK: - Code Generation

    /// Generates a one-time password (OTP) for a given credential.
    /// - Parameter credentialId: The unique identifier of the credential.
    /// - Returns: The generated OTP code as a string.
    /// - Throws: `OathError.credentialNotFound` if the credential doesn't exist.
    /// - Throws: `OathError.credentialLocked` if the credential is locked.
    /// - Throws: `OathError.codeGenerationFailed` if code generation fails.
    ///
    /// For HOTP credentials, this method will automatically increment the counter.
    /// For TOTP credentials, the code is valid for the current time period.
    public func generateCode(_ credentialId: String) async throws -> String {
        configuration.logger.d("Generating code for credential: \(credentialId)")

        do {
            let codeInfo = try await oathService.generateCodeForCredential(credentialId: credentialId)
            configuration.logger.d("Successfully generated code for credential: \(credentialId)")
            return codeInfo.code
        } catch {
            configuration.logger.e("Failed to generate code for credential \(credentialId): \(error)", error: error)
            throw error
        }
    }

    /// Generates an OTP with additional information about its validity.
    /// - Parameter credentialId: The unique identifier of the credential.
    /// - Returns: OathCodeInfo containing the code and validity information.
    /// - Throws: `OathError.credentialNotFound` if the credential doesn't exist.
    /// - Throws: `OathError.credentialLocked` if the credential is locked.
    /// - Throws: `OathError.codeGenerationFailed` if code generation fails.
    ///
    /// This method provides additional information such as:
    /// - For TOTP: time remaining before expiration and progress through the time window
    /// - For HOTP: the counter value used for generation
    public func generateCodeWithValidity(_ credentialId: String) async throws -> OathCodeInfo {
        configuration.logger.d("Generating code with validity for credential: \(credentialId)")

        do {
            let codeInfo = try await oathService.generateCodeForCredential(credentialId: credentialId)
            configuration.logger.d("Successfully generated code with validity for credential: \(credentialId)")
            return codeInfo
        } catch {
            configuration.logger.e("Failed to generate code with validity for credential \(credentialId): \(error)", error: error)
            throw error
        }
    }

    
    // MARK: - Lifecycle Management

    /// Clean up resources used by the OATH client.
    /// This method should be called when the client is no longer needed to ensure
    /// proper cleanup of resources and cached data.
    /// - Throws: `OathError.cleanupFailed` if cleanup operations fail.
    public func close() async throws {
        configuration.logger.d("Closing OATH client")
        await oathService.clearCache()
        configuration.logger.i("OATH client closed successfully")
    }
}
