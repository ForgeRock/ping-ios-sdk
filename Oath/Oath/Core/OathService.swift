//
//  OathService.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingCommons
import PingLogger

/// Internal service class that provides OATH functionality including credential management
/// and OTP code generation with policy enforcement.
///
/// This actor ensures thread-safe access to OATH operations and manages the credential
/// lifecycle with optional in-memory caching for performance optimization.
///
/// - Note: This is an internal service and should not be used directly by client code.
actor OathService {

    // MARK: - Properties

    /// The configuration for OATH operations.
    private let configuration: OathConfiguration

    /// The storage implementation for persisting credentials.
    private let storage: any OathStorage

    /// The policy evaluator for credential policy validation.
    private let policyEvaluator: MfaPolicyEvaluator

    /// Logger for logging service operations.
    private let logger: Logger

    /// In-memory cache for credentials, only used if enableCredentialCache is true.
    private var credentialsCache: [String: OathCredential] = [:]

    
    // MARK: - Initialization

    /// Creates a new OATH service instance.
    /// - Parameters:
    ///   - configuration: The OATH configuration containing storage, logger, and other settings.
    ///   - policyEvaluator: The policy evaluator for credential validation.
    init(
        configuration: OathConfiguration,
        policyEvaluator: MfaPolicyEvaluator
    ) {
        self.configuration = configuration
        self.storage = configuration.storage ?? OathKeychainStorage()
        self.policyEvaluator = policyEvaluator
        self.logger = configuration.logger
    }
    

    // MARK: - URI Operations

    /// Parse an OATH URI string into an OathCredential.
    /// - Parameter uri: The URI string to parse.
    /// - Returns: A new OathCredential instance.
    /// - Throws: `OathError.invalidUri` if the URI is malformed.
    /// - Throws: `OathError.policyViolation` if policies are violated during registration.
    func parseUri(_ uri: String) async throws -> OathCredential {
        logger.d("Parsing OATH URI")

        do {
            let credential = try await OathUriParser.parse(uri)
            logger.d("Successfully parsed OATH URI for issuer: \(credential.issuer)")
            
            // Evaluate policies during registration if policies are present
            // Block registration if policies fail
            if let policiesString = credential.policies, !policiesString.isEmpty {
                logger.d("Evaluating policies for new OATH credential")
                let policyResult = await policyEvaluator.evaluate(credentialPolicies: policiesString)
                
                if policyResult.isFailure {
                    let policyName = policyResult.nonCompliancePolicyName ?? "unknown"
                    logger.w("OATH credential registration blocked by policy: \(policyName)", error: nil)
                    throw OathError.policyViolation(
                        "This credential cannot be registered on this device. It violates the following policy: \(policyName)",
                        credential.id
                    )
                } else {
                    logger.d("All policies passed for new OATH credential")
                }
            }
            
            return credential
        } catch {
            logger.e("Failed to parse OATH URI: \(error)", error: error)
            throw error
        }
    }

    /// Format an OathCredential into a URI string.
    /// - Parameter credential: The credential to format.
    /// - Returns: A URI string representation.
    /// - Throws: `OathError.uriFormatting` if formatting fails.
    func formatUri(_ credential: OathCredential) async throws -> String {
        logger.d("Formatting OATH credential to URI: \(credential.id)")

        do {
            let uri = try await OathUriParser.format(credential)
            logger.d("Successfully formatted OATH credential to URI")
            return uri
        } catch {
            logger.e("Failed to format OATH credential to URI: \(error)", error: error)
            throw error
        }
    }

    
    // MARK: - Credential Management

    /// Add and store a new credential.
    /// - Parameter credential: The credential to add.
    /// - Returns: The stored credential with any updates.
    /// - Throws: `OathError.policyViolation` if policies are not met.
    /// - Throws: `OathStorageError` if storage operations fail.
    func addCredential(_ credential: OathCredential) async throws -> OathCredential {
        logger.d("Adding new OATH credential: \(credential.id)")
        // Validate credential
        try credential.validate()

        // Evaluate policies before adding
        let updatedCredential = try await evaluateAndUpdateCredentialPolicies(credential)

        // Store the credential
        try await storage.storeOathCredential(updatedCredential)

        // Update cache if enabled
        if configuration.enableCredentialCache {
            credentialsCache[updatedCredential.id] = updatedCredential
        }

        logger.d("Successfully added OATH credential: \(updatedCredential.id)")
        return updatedCredential
    }

    /// Retrieve all stored credentials.
    /// - Returns: Array of all stored credentials.
    /// - Throws: `OathStorageError` if storage operations fail.
    func getCredentials() async throws -> [OathCredential] {
        logger.d("Retrieving all OATH credentials")

        do {
            let credentials = try await storage.getAllOathCredentials()

            // Evaluate policies for each credential at runtime (following Android pattern)
            var updatedCredentials: [OathCredential] = []
            for credential in credentials {
                let updatedCredential = try await evaluateAndUpdateCredentialPolicies(credential, store: true)
                updatedCredentials.append(updatedCredential)
                
                // Update cache if enabled
                if configuration.enableCredentialCache {
                    credentialsCache[updatedCredential.id] = updatedCredential
                }
            }

            logger.d("Successfully retrieved \(updatedCredentials.count) OATH credentials")
            return updatedCredentials
        } catch {
            logger.e("Failed to retrieve OATH credentials: \(error)", error: error)
            throw error
        }
    }

    /// Retrieve a single credential by ID.
    /// - Parameter credentialId: The ID of the credential to retrieve.
    /// - Returns: The credential if found, nil otherwise.
    /// - Throws: `OathStorageError` if storage operations fail.
    func getCredential(credentialId: String) async throws -> OathCredential? {
        logger.d("Retrieving OATH credential: \(credentialId)")

        // Check cache first if enabled
        if configuration.enableCredentialCache, let cachedCredential = credentialsCache[credentialId] {
            logger.d("Retrieved OATH credential from cache: \(credentialId)")
            return cachedCredential
        }

        do {
            let credential = try await storage.retrieveOathCredential(credentialId: credentialId)

            // Update cache if enabled and credential found
            if configuration.enableCredentialCache, let credential = credential {
                credentialsCache[credentialId] = credential
            }

            if credential != nil {
                logger.d("Successfully retrieved OATH credential: \(credentialId)")
            } else {
                logger.d("OATH credential not found: \(credentialId)")
            }

            return credential
        } catch {
            logger.e("Failed to retrieve OATH credential \(credentialId): \(error)", error: error)
            throw error
        }
    }

    /// Remove a credential by ID.
    /// - Parameter credentialId: The ID of the credential to remove.
    /// - Returns: true if removed, false if not found.
    /// - Throws: `OathStorageError` if storage operations fail.
    func removeCredential(credentialId: String) async throws -> Bool {
        logger.d("Removing OATH credential: \(credentialId)")

        do {
            let removed = try await storage.removeOathCredential(credentialId: credentialId)

            // Remove from cache if enabled
            if configuration.enableCredentialCache {
                credentialsCache.removeValue(forKey: credentialId)
            }

            if removed {
                logger.d("Successfully removed OATH credential: \(credentialId)")
            } else {
                logger.d("OATH credential not found for removal: \(credentialId)")
            }

            return removed
        } catch {
            logger.e("Failed to remove OATH credential \(credentialId): \(error)", error: error)
            throw error
        }
    }
    

    // MARK: - Code Generation

    /// Generate an OTP code for a given credential.
    /// - Parameter credential: The credential to generate code for.
    /// - Returns: Generated code information.
    /// - Throws: `OathError.credentialLocked` if the credential is locked.
    /// - Throws: `OathError.codeGenerationFailed` if code generation fails.
    func generateCode(for credential: OathCredential) async throws -> OathCodeInfo {
        logger.d("Generating OTP code for credential: \(credential.id)")

        // Check if credential is locked
        guard !credential.isLocked else {
            logger.w("Cannot generate code for locked credential: \(credential.id)", error: nil)
            throw OathError.credentialLocked(credential.id)
        }

        do {
            let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)
            logger.d("Successfully generated OTP code for credential: \(credential.id)")
            return codeInfo
        } catch {
            logger.e("Failed to generate OTP code for credential \(credential.id): \(error)", error: error)
            throw OathError.codeGenerationFailed("Code generation failed", error)
        }
    }

    /// Generate an OTP code for a credential by ID.
    /// - Parameter credentialId: The ID of the credential.
    /// - Returns: Generated code information.
    /// - Throws: `OathError.credentialNotFound` if credential doesn't exist.
    /// - Throws: `OathError.credentialLocked` if the credential is locked.
    /// - Throws: `OathError.codeGenerationFailed` if code generation fails.
    func generateCodeForCredential(credentialId: String) async throws -> OathCodeInfo {
        logger.d("Generating OTP code for credential ID: \(credentialId)")

        guard var credential = try await getCredential(credentialId: credentialId) else {
            logger.w("Credential not found for code generation: \(credentialId)", error: nil)
            throw OathError.credentialNotFound(credentialId)
        }

        let codeInfo = try await generateCode(for: credential)

        // For HOTP, update the counter after successful code generation
        if credential.oathType == .hotp {
            credential.counter += 1
            try await storage.storeOathCredential(credential)

            // Update cache if enabled
            if configuration.enableCredentialCache {
                credentialsCache[credentialId] = credential
            }

            logger.d("Updated HOTP counter for credential: \(credentialId)")
        }

        return codeInfo
    }

    
    // MARK: - Policy Evaluation

    /// Evaluate and update credential policies at runtime.
    /// Following Android pattern: locks credentials that violate policies but doesn't throw.
    /// This allows graceful degradation - locked credentials are stored but cannot generate codes.
    /// - Parameters:
    ///   - credential: The credential to evaluate.
    ///   - store: Whether to store the updated credential (default: true).
    /// - Returns: Updated credential with policy results.
    private func evaluateAndUpdateCredentialPolicies(
        _ credential: OathCredential,
        store: Bool = true
    ) async throws -> OathCredential {
        logger.d("Evaluating policies for credential: \(credential.id)")

        // If no policies, return credential as-is
        guard let policiesString = credential.policies, !policiesString.isEmpty else {
            return credential
        }

        var updatedCredential = credential
        let result = await policyEvaluator.evaluate(credentialPolicies: policiesString)

        // If credential is not locked but policies fail, lock it
        if !updatedCredential.isLocked && result.isFailure {
            let policyName = result.nonCompliancePolicyName ?? "unknown"
            logger.w("Locking OATH credential \(credential.id) due to policy violation: \(policyName)", error: nil)
            updatedCredential.isLocked = true
            updatedCredential.lockingPolicy = policyName
            
            // Update storage with locked status
            if store {
                try await storage.storeOathCredential(updatedCredential)
            }
        }
        // If credential is locked but policies are now compliant, unlock it
        else if updatedCredential.isLocked && result.isSuccess {
            logger.i("Unlocking previously locked OATH credential \(credential.id): all policies are compliant")
            updatedCredential.isLocked = false
            updatedCredential.lockingPolicy = nil
            
            // Update storage with unlocked status
            if store {
                try await storage.storeOathCredential(updatedCredential)
            }
        }
        // If credential is locked and policies fail with a different policy, update the locking policy
        else if updatedCredential.isLocked && result.isFailure {
            let newPolicyName = result.nonCompliancePolicyName ?? "unknown"
            let currentLockingPolicy = updatedCredential.lockingPolicy
            
            if newPolicyName != currentLockingPolicy {
                logger.w("Updating locking policy for OATH credential \(credential.id) from '\(currentLockingPolicy ?? "nil")' to '\(newPolicyName)'", error: nil)
                updatedCredential.lockingPolicy = newPolicyName
                
                if store {
                    try await storage.storeOathCredential(updatedCredential)
                }
            }
        }

        logger.d("Policy evaluation completed for credential: \(credential.id)")
        return updatedCredential
    }

    
    // MARK: - Cache Management

    /// Clear the in-memory credential cache.
    func clearCache() {
        logger.d("Clearing credential cache")
        credentialsCache.removeAll()
    }
}
