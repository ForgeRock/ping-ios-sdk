//
//  PushService.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger
import PingCommons
import PingOrchestrate
#if canImport(UIKit)
import UIKit
#endif

/// Internal service actor that encapsulates Push MFA business logic.
///
/// Responsibilities include credential lifecycle management, notification processing,
/// device token synchronization, and policy enforcement. The public `PushClient`
/// exposes a subset of these capabilities to consumers.
actor PushService {

    // MARK: - Internal Types

    private enum Constants {
        static let registrationFailureMessage = "Failed to register push credential"
        static let deviceTokenNotSetMessage = "Device token has not been set"
    }

    private enum HandlerKeys {
        static let deviceName = "deviceName"
    }

    private enum NotificationKeys {
        static let credentialId = "credentialId"
        static let messageId = "messageId"
        static let messageText = "messageText"
        static let customPayload = "customPayload"
        static let challenge = "challenge"
        static let numbersChallenge = "numbersChallenge"
        static let loadBalancer = "amlbCookie"
        static let contextInfo = "contextInfo"
        static let ttl = "ttl"
        static let pushType = "pushType"
        static let timeInterval = "timeInterval"
        static let userId = "userId"
        static let additionalData = "additionalData"
    }

    private enum NotificationDefaults {
        static let ttl = 120
        static let deviceName = "iOS Device"
    }

    // MARK: - Stored Properties

    private let storage: any PushStorage
    private let configuration: PushConfiguration
    private let httpClient: HttpClient
    private let policyEvaluator: MfaPolicyEvaluator
    private let logger: Logger?
    private let deviceTokenManager: PushDeviceTokenManager
    private let enableCredentialCache: Bool

    /// In-memory cache for credentials when caching is enabled.
    private var credentialsCache: [String: PushCredential] = [:]

    /// Dispatch table of push handlers keyed by platform identifier.
    private let pushHandlers: [String: PushHandler]

    // MARK: - Initialization

    /// Creates a new instance of `PushService`.
    ///
    /// - Parameters:
    ///   - storage: Storage implementation responsible for persisting credentials, notifications, and device tokens.
    ///   - configuration: Push configuration containing runtime options, logger, and custom handlers.
    ///   - httpClient: HTTP client used for responder operations.
    ///   - policyEvaluator: Policy evaluator for enforcing device security policies.
    ///   - deviceTokenManager: Optional device token manager override (primarily for testing).
    ///   - handlers: Optional preconstructed handler map (used by tests to inject fakes).
    init(
        storage: any PushStorage,
        configuration: PushConfiguration,
        httpClient: HttpClient,
        policyEvaluator: MfaPolicyEvaluator,
        deviceTokenManager: PushDeviceTokenManager? = nil,
        handlers: [String: PushHandler]? = nil
    ) {
        self.storage = storage
        self.configuration = configuration
        self.httpClient = httpClient
        self.policyEvaluator = policyEvaluator
        self.logger = configuration.logger
        self.enableCredentialCache = configuration.enableCredentialCache

        self.deviceTokenManager = deviceTokenManager ?? PushDeviceTokenManager(
            storage: storage,
            logger: logger
        )

        if let handlers {
            var map: [String: PushHandler] = [:]
            for (key, handler) in handlers {
                map[key] = handler
            }
            self.pushHandlers = map
        } else {
            self.pushHandlers = Self.makeHandlers(
                configuration: configuration,
                httpClient: httpClient,
                logger: logger
            )
        }

        logger?.d("PushService initialized")
    }

    // MARK: - Handler Initialization

    /// Builds the handler dispatch table using default and custom handlers.
    ///
    /// Default handlers are always registered first, and custom handlers take precedence when they
    /// provide an implementation for an existing platform identifier.
    private static func makeHandlers(
        configuration: PushConfiguration,
        httpClient: HttpClient,
        logger: Logger?
    ) -> [String: PushHandler] {
        var defaults: [String: PushHandler] = [
            PushPlatform.pingAM.rawValue: PingAMPushHandler(httpClient: httpClient, logger: logger)
        ]

        if !configuration.customPushHandlers.isEmpty {
            for (key, handler) in configuration.customPushHandlers {
                if let typedHandler = handler as? PushHandler {
                    defaults[key] = typedHandler
                } else {
                    logger?.w("Custom handler for key \(key) does not conform to PushHandler", error: nil)
                }
            }
            logger?.d("Registered \(configuration.customPushHandlers.count) custom push handler(s)")
        }

        return defaults
    }

    /// Returns the number of registered push handlers.
    func handlerCount() -> Int {
        pushHandlers.count
    }

    /// Provides the type name for the handler registered under the supplied identifier.
    ///
    /// - Parameter platformId: Platform identifier (e.g. `PushPlatform.pingAM.rawValue`).
    /// - Returns: Handler type name or `nil` when no handler is registered.
    func handlerTypeName(for platformId: String) -> String? {
        guard let handler = pushHandlers[platformId] else {
            return nil
        }
        return String(describing: type(of: handler))
    }

    // MARK: - Credential Management

    /// Registers and stores a push credential parsed from a pushauth:// URI.
    ///
    /// - Parameter uri: The enrollment URI typically obtained from a QR code.
    /// - Returns: The stored credential (potentially locked by policy).
    /// - Throws: `PushError` when parsing, registration, or storage fails.
    func addCredentialFromUri(_ uri: String) async throws -> PushCredential {
        logger?.d("Adding Push credential from URI")

        do {
            let credential = try await PushUriParser.parse(uri)

            if let policies = credential.policies, !policies.isEmpty {
                logger?.d("Evaluating policies for new credential \(credential.id)")
                let policyResult = await policyEvaluator.evaluate(credentialPolicies: policies)
                if policyResult.isFailure {
                    let policyName = policyResult.nonCompliancePolicyName ?? "unknown"
                    logger?.w("Credential registration blocked by policy: \(policyName)", error: nil)
                    throw PushError.policyViolation(
                        "This credential cannot be registered on this device. It violates policy: \(policyName)"
                    )
                }
                logger?.d("Policies passed for credential \(credential.id)")
            }

            guard let deviceToken = try await deviceTokenManager.getDeviceTokenId() else {
                logger?.w("Device token not set; cannot register credential", error: nil)
                throw PushError.deviceTokenNotSet
            }

            var registrationParams = try await PushUriParser.registrationParameters(uri)
            registrationParams["deviceId"] = deviceToken
            registrationParams["deviceName"] = await Self.currentDeviceName()

            let platformId = credential.platform.rawValue
            guard let handler = pushHandlers[platformId] else {
                logger?.w("No handler available for platform \(platformId)", error: nil)
                throw PushError.noHandlerForPlatform(platformId)
            }

            var handlerParams: [String: Any] = [:]
            for (key, value) in registrationParams {
                handlerParams[key] = value
            }

            let registrationSucceeded = try await handler.register(
                credential: credential,
                params: handlerParams
            )

            guard registrationSucceeded else {
                logger?.w("Push handler reported registration failure for \(credential.id)", error: nil)
                throw PushError.registrationFailed(Constants.registrationFailureMessage)
            }

            logger?.d("Credential \(credential.id) registered successfully; storing locally")
            return try await addCredential(credential)
        } catch let error as PushError {
            throw error
        } catch let error as PushStorageError {
            logger?.e("Storage failure while adding credential from URI", error: error)
            throw PushError.storageFailure("Failed to add credential from URI", error)
        } catch {
            logger?.e("Unexpected error while adding credential from URI", error: error)
            throw PushError.networkFailure("Failed to add credential from URI", error)
        }
    }

    /// Stores a credential after performing policy evaluation and optional caching.
    ///
    /// - Parameter credential: The credential to persist.
    /// - Returns: The stored credential (potentially locked).
    /// - Throws: `PushError.storageFailure` when persistence fails.
    func addCredential(_ credential: PushCredential) async throws -> PushCredential {
        logger?.d("Adding Push credential \(credential.id)")

        do {
            var updatedCredential = credential
            try await evaluateAndUpdateCredentialPolicies(&updatedCredential, store: false)

            try await storage.storePushCredential(updatedCredential)

            if enableCredentialCache {
                credentialsCache[updatedCredential.id] = updatedCredential
            }

            logger?.d("Stored Push credential \(updatedCredential.id) (locked: \(updatedCredential.isLocked))")
            return updatedCredential
        } catch let error as PushError {
            throw error
        } catch let error as PushStorageError {
            logger?.e("Storage failure while adding credential \(credential.id)", error: error)
            throw PushError.storageFailure("Failed to add push credential", error)
        } catch {
            logger?.e("Unexpected error while adding credential \(credential.id)", error: error)
            throw PushError.storageFailure("Failed to add push credential", error)
        }
    }

    /// Retrieves all stored credentials, evaluating policies and updating the optional cache.
    ///
    /// - Returns: Array of stored credentials.
    /// - Throws: `PushError.storageFailure` when persistence operations fail.
    func getCredentials() async throws -> [PushCredential] {
        if enableCredentialCache, !credentialsCache.isEmpty {
            logger?.d("Returning \(credentialsCache.count) cached Push credential(s)")
            return Array(credentialsCache.values)
        }

        do {
            let storedCredentials = try await storage.getAllPushCredentials()
            var evaluatedCredentials: [PushCredential] = []
            evaluatedCredentials.reserveCapacity(storedCredentials.count)

            for var credential in storedCredentials {
                try await evaluateAndUpdateCredentialPolicies(&credential, store: true)
                evaluatedCredentials.append(credential)

                if enableCredentialCache {
                    credentialsCache[credential.id] = credential
                }
            }

            logger?.d("Retrieved \(evaluatedCredentials.count) Push credential(s) from storage")
            return evaluatedCredentials
        } catch let error as PushError {
            throw error
        } catch let error as PushStorageError {
            logger?.e("Storage failure while retrieving credentials", error: error)
            throw PushError.storageFailure("Failed to retrieve push credentials", error)
        } catch {
            logger?.e("Unexpected error while retrieving credentials", error: error)
            throw PushError.storageFailure("Failed to retrieve push credentials", error)
        }
    }

    /// Retrieves a credential by identifier, consulting the cache when enabled.
    ///
    /// - Parameter credentialId: Identifier of the credential.
    /// - Returns: The credential when found, otherwise `nil`.
    /// - Throws: `PushError.storageFailure` when persistence operations fail.
    func getCredential(credentialId: String) async throws -> PushCredential? {
        if enableCredentialCache, let cached = credentialsCache[credentialId] {
            logger?.d("Returning cached credential \(credentialId)")
            return cached
        }

        do {
            guard var credential = try await storage.retrievePushCredential(credentialId: credentialId) else {
                logger?.d("Credential \(credentialId) not found in storage")
                return nil
            }

            try await evaluateAndUpdateCredentialPolicies(&credential, store: true)

            if enableCredentialCache {
                credentialsCache[credentialId] = credential
            }

            logger?.d("Retrieved credential \(credentialId) from storage")
            return credential
        } catch let error as PushError {
            throw error
        } catch let error as PushStorageError {
            logger?.e("Storage failure while retrieving credential \(credentialId)", error: error)
            throw PushError.storageFailure("Failed to retrieve push credential", error)
        } catch {
            logger?.e("Unexpected error while retrieving credential \(credentialId)", error: error)
            throw PushError.storageFailure("Failed to retrieve push credential", error)
        }
    }

    /// Removes a credential and updates the in-memory cache when enabled.
    ///
    /// - Parameter credentialId: Identifier of the credential to remove.
    /// - Returns: `true` when the credential existed and was removed.
    /// - Throws: `PushError.storageFailure` when persistence operations fail.
    @discardableResult
    func removeCredential(credentialId: String) async throws -> Bool {
        if enableCredentialCache {
            credentialsCache.removeValue(forKey: credentialId)
        }

        do {
            let removed = try await storage.removePushCredential(credentialId: credentialId)
            if removed {
                logger?.d("Removed Push credential \(credentialId)")
            } else {
                logger?.d("No Push credential found for removal: \(credentialId)")
            }
            return removed
        } catch let error as PushStorageError {
            logger?.e("Storage failure while removing credential \(credentialId)", error: error)
            throw PushError.storageFailure("Failed to remove push credential", error)
        } catch {
            logger?.e("Unexpected error while removing credential \(credentialId)", error: error)
            throw PushError.storageFailure("Failed to remove push credential", error)
        }
    }

    // MARK: - Device Token Management

    /// Sets the device token for push notifications, optionally targeting a specific credential.
    ///
    /// - Parameters:
    ///   - deviceToken: Raw APNs device token string.
    ///   - credentialId: Optional credential identifier to scope the update. When `nil`, all credentials are updated.
    /// - Returns: `true` when all updates succeed, `false` when any handler reports a failure.
    func setDeviceToken(
        _ deviceToken: String,
        credentialId: String? = nil
    ) async throws -> Bool {
        let trimmedToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            logger?.w("setDeviceToken called with an empty token", error: nil)
            throw PushError.invalidParameterValue("Device token cannot be empty")
        }

        do {
            let tokenChanged = try await deviceTokenManager.hasTokenChanged(trimmedToken)

            if !tokenChanged {
                logger?.d("Device token unchanged; skipping update")
                return true
            }

            try await deviceTokenManager.storeDeviceToken(trimmedToken)
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to persist device token locally", error: error)
            throw PushError.storageFailure("Failed to store device token", error)
        }

        return try await updateDeviceTokensOnServer(
            deviceToken: trimmedToken,
            credentialId: credentialId
        )
    }

    /// Retrieves the currently stored device token, if any.
    func getDeviceToken() async throws -> String? {
        do {
            return try await deviceTokenManager.getDeviceTokenId()
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to retrieve stored device token", error: error)
            throw PushError.storageFailure("Failed to retrieve device token", error)
        }
    }

    // MARK: - Notification Processing

    /// Processes a push notification represented as a dictionary payload.
    ///
    /// The service identifies the appropriate handler, parses the incoming payload, checks for duplicate
    /// notifications using `messageId`, persists new notifications, and backfills credential metadata when needed.
    ///
    /// - Parameter messageData: Raw push payload received from APNs or a remote service.
    /// - Returns: The stored `PushNotification`, or `nil` when no handler can process the payload.
    /// - Throws: `PushError` when parsing or persistence fails.
    func processNotification(messageData: [String: Any]) async throws -> PushNotification? {
        guard let platformId = identifyPlatform(messageData: messageData) else {
            logger?.d("No push handler could handle incoming message data")
            return nil
        }

        guard let handler = pushHandlers[platformId] else {
            logger?.w("Handler dictionary missing entry for platform \(platformId)", error: nil)
            throw PushError.noHandlerForPlatform(platformId)
        }

        do {
            let parsed = try handler.parseMessage(messageData: messageData)
            return try await processParsedNotification(parsed)
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to process notification from message data", error: error)
            throw PushError.messageParsingFailed("Failed to process notification: \(error.localizedDescription)")
        }
    }

    /// Processes a push notification represented as a string message (typically JWT payload).
    ///
    /// Behaviour mirrors `processNotification(messageData:)`: the correct handler is selected, the message
    /// is parsed, duplicates are filtered, and new notifications are written to storage.
    ///
    /// - Parameter message: Encoded push notification string.
    /// - Returns: The stored `PushNotification`, or `nil` when no handler supports the message.
    /// - Throws: `PushError` when parsing or persistence fails.
    func processNotification(message: String) async throws -> PushNotification? {
        guard let platformId = identifyPlatform(message: message) else {
            logger?.d("No push handler could handle incoming string message")
            return nil
        }

        guard let handler = pushHandlers[platformId] else {
            logger?.w("Handler dictionary missing entry for platform \(platformId)", error: nil)
            throw PushError.noHandlerForPlatform(platformId)
        }

        do {
            let parsed = try handler.parseMessage(message: message)
            return try await processParsedNotification(parsed)
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to process notification from string", error: error)
            throw PushError.messageParsingFailed("Failed to process notification string: \(error.localizedDescription)")
        }
    }

    /// Processes a push notification using an iOS `userInfo` dictionary from `UNNotification`.
    ///
    /// The method bridges Foundation's `[AnyHashable: Any]` map to `[String: Any]` and forwards the work to
    /// `processNotification(messageData:)` so the full duplicate detection and persistence logic is reused.
    ///
    /// - Parameter userInfo: `UNNotification` payload.
    /// - Returns: The stored `PushNotification`, or `nil` when unsupported by registered handlers.
    /// - Throws: `PushError` surfaced from the underlying processing pipeline.
    func processNotification(userInfo: [AnyHashable: Any]) async throws -> PushNotification? {
        let messageData = userInfo.reduce(into: [String: Any]()) { result, element in
            if let key = element.key as? String {
                result[key] = element.value
            }
        }

        return try await processNotification(messageData: messageData)
    }

    // MARK: - Notification Responses

    /// Approves a pending push notification by delegating to the registered handler.
    ///
    /// The method validates notification state, ensures the associated credential is available and not
    /// locked by policy, forwards the response through the handler, and updates local storage to reflect
    /// the new status.
    ///
    /// - Parameters:
    ///   - notificationId: Identifier of the notification to approve.
    ///   - params: Optional additional parameters passed to the handler.
    /// - Returns: `true` when the handler reports success, `false` when the notification was already handled
    ///   or the handler reported failure.
    /// - Throws: `PushError` when storage access fails, the notification or credential is missing, the
    ///   credential is locked, no handler is available, or the handler throws an error.
    func approveNotification(
        notificationId: String,
        params: [String: any Sendable] = [:]
    ) async throws -> Bool {
        logger?.d("Approving push notification \(notificationId)")

        let notification = try await fetchNotification(notificationId: notificationId)

        guard notification.pending else {
            logger?.d("Notification \(notification.id) already responded; skipping approval")
            return false
        }

        let credential = try await fetchCredential(credentialId: notification.credentialId)

        guard !credential.isLocked else {
            let policy = credential.lockingPolicy ?? "unknown"
            logger?.w(
                "Credential \(credential.id) locked by policy \(policy); cannot approve notification \(notification.id)",
                error: nil
            )
            throw PushError.credentialLocked(credential.id)
        }

        guard let handler = pushHandlers[credential.platform.rawValue] else {
            logger?.w("No handler available for platform \(credential.platform.rawValue)", error: nil)
            throw PushError.noHandlerForPlatform(credential.platform.rawValue)
        }

        let result: Bool
        let paramsToSend = params.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value
        }
        do {
            result = try await handler.sendApproval(
                credential: credential,
                notification: notification,
                params: paramsToSend
            )
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to send approval for notification \(notification.id)", error: error)
            throw PushError.networkFailure("Failed to send approval", error)
        }

        guard result else {
            logger?.w("Handler reported approval failure for notification \(notification.id)", error: nil)
            return false
        }

        var updatedNotification = notification
        updatedNotification.markApproved()

        do {
            try await storage.updatePushNotification(updatedNotification)
            logger?.d("Notification \(notification.id) marked as approved")
        } catch let error as PushStorageError {
            logger?.e("Failed to persist approved notification \(notification.id)", error: error)
            throw PushError.storageFailure("Failed to update notification", error)
        } catch {
            logger?.e("Unexpected error updating notification \(notification.id)", error: error)
            throw PushError.storageFailure("Failed to update notification", error)
        }

        return true
    }

    /// Denies a pending push notification by delegating to the registered handler.
    ///
    /// Behaviour mirrors `approveNotification(notificationId:params:)`, updating local storage only when the
    /// handler reports success.
    ///
    /// - Parameters:
    ///   - notificationId: Identifier of the notification to deny.
    ///   - params: Optional additional parameters passed to the handler.
    /// - Returns: `true` when the handler reports success, `false` when the notification was already handled
    ///   or the handler reported failure.
    /// - Throws: `PushError` mirroring the approval method.
    func denyNotification(
        notificationId: String,
        params: [String: any Sendable] = [:]
    ) async throws -> Bool {
        logger?.d("Denying push notification \(notificationId)")

        let notification = try await fetchNotification(notificationId: notificationId)

        guard notification.pending else {
            logger?.d("Notification \(notification.id) already responded; skipping denial")
            return false
        }

        let credential = try await fetchCredential(credentialId: notification.credentialId)

        guard !credential.isLocked else {
            let policy = credential.lockingPolicy ?? "unknown"
            logger?.w(
                "Credential \(credential.id) locked by policy \(policy); cannot deny notification \(notification.id)",
                error: nil
            )
            throw PushError.credentialLocked(credential.id)
        }

        guard let handler = pushHandlers[credential.platform.rawValue] else {
            logger?.w("No handler available for platform \(credential.platform.rawValue)", error: nil)
            throw PushError.noHandlerForPlatform(credential.platform.rawValue)
        }

        let result: Bool
        let paramsToSend = params.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value
        }
        do {
            result = try await handler.sendDenial(
                credential: credential,
                notification: notification,
                params: paramsToSend
            )
        } catch let error as PushError {
            throw error
        } catch {
            logger?.e("Failed to send denial for notification \(notification.id)", error: error)
            throw PushError.networkFailure("Failed to send denial", error)
        }

        guard result else {
            logger?.w("Handler reported denial failure for notification \(notification.id)", error: nil)
            return false
        }

        var updatedNotification = notification
        updatedNotification.markDenied()

        do {
            try await storage.updatePushNotification(updatedNotification)
            logger?.d("Notification \(notification.id) marked as denied")
        } catch let error as PushStorageError {
            logger?.e("Failed to persist denied notification \(notification.id)", error: error)
            throw PushError.storageFailure("Failed to update notification", error)
        } catch {
            logger?.e("Unexpected error updating notification \(notification.id)", error: error)
            throw PushError.storageFailure("Failed to update notification", error)
        }

        return true
    }

    /// Retrieves all pending push notifications from storage.
    ///
    /// - Returns: Array of notifications that remain pending.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    func getPendingNotifications() async throws -> [PushNotification] {
        do {
            return try await storage.getPendingPushNotifications()
        } catch let error as PushStorageError {
            logger?.e("Failed to fetch pending notifications", error: error)
            throw PushError.storageFailure("Failed to fetch pending notifications", error)
        } catch {
            logger?.e("Unexpected error fetching pending notifications", error: error)
            throw PushError.storageFailure("Failed to fetch pending notifications", error)
        }
    }

    /// Retrieves all stored push notifications.
    ///
    /// - Returns: Array of all notifications.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    func getAllNotifications() async throws -> [PushNotification] {
        do {
            return try await storage.getAllPushNotifications()
        } catch let error as PushStorageError {
            logger?.e("Failed to fetch all notifications", error: error)
            throw PushError.storageFailure("Failed to fetch notifications", error)
        } catch {
            logger?.e("Unexpected error fetching all notifications", error: error)
            throw PushError.storageFailure("Failed to fetch notifications", error)
        }
    }

    /// Retrieves a push notification by identifier.
    ///
    /// - Parameter notificationId: Identifier of the requested notification.
    /// - Returns: The `PushNotification` when found, otherwise `nil`.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    func getNotification(notificationId: String) async throws -> PushNotification? {
        do {
            return try await storage.retrievePushNotification(notificationId: notificationId)
        } catch let error as PushStorageError {
            logger?.e("Failed to fetch notification \(notificationId)", error: error)
            throw PushError.storageFailure("Failed to fetch notification", error)
        } catch {
            logger?.e("Unexpected error fetching notification \(notificationId)", error: error)
            throw PushError.storageFailure("Failed to fetch notification", error)
        }
    }

    /// Clears the in-memory credential cache maintained by the service.
    ///
    /// This should be invoked when callers need to force subsequent credential operations
    /// to consult persistent storage (e.g., after external mutations or sign-out flows).
    func clearCache() {
        guard enableCredentialCache else {
            return
        }

        credentialsCache.removeAll()
        logger?.d("Cleared Push credential cache")
    }

    // MARK: - Helpers

    @MainActor private static func currentDeviceName() -> String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        NotificationDefaults.deviceName
        #endif
    }

    private func evaluateAndUpdateCredentialPolicies(
        _ credential: inout PushCredential,
        store: Bool
    ) async throws {
        guard let policies = credential.policies, !policies.isEmpty else {
            return
        }

        let result = await policyEvaluator.evaluate(credentialPolicies: policies)

        if !credential.isLocked && result.isFailure {
            let policyName = result.nonCompliancePolicyName ?? "unknown"
            logger?.w("Locking credential \(credential.id) due to policy violation: \(policyName)", error: nil)
            credential.lockCredential(policyName: policyName)
            if store {
                try await persistCredentialState(credential)
            }
        } else if credential.isLocked && result.isSuccess {
            logger?.i("Unlocking credential \(credential.id); policies now compliant")
            credential.unlockCredential()
            if store {
                try await persistCredentialState(credential)
            }
        } else if credential.isLocked && result.isFailure {
            let updatedPolicy = result.nonCompliancePolicyName ?? "unknown"
            if credential.lockingPolicy != updatedPolicy {
                logger?.w(
                    "Updating locking policy for credential \(credential.id) to \(updatedPolicy)",
                    error: nil
                )
                credential.lockCredential(policyName: updatedPolicy)
                if store {
                    try await persistCredentialState(credential)
                }
            }
        }
    }

    private func persistCredentialState(_ credential: PushCredential) async throws {
        do {
            try await storage.storePushCredential(credential)
        } catch let error as PushStorageError {
            throw PushError.storageFailure("Failed to persist credential state", error)
        } catch {
            throw PushError.storageFailure("Failed to persist credential state", error)
        }
    }

    private func processParsedNotification(_ parsedData: [String: Any]) async throws -> PushNotification? {
        guard let credentialId = parsedData[NotificationKeys.credentialId] as? String else {
            logger?.e("Parsed notification missing credentialId", error: nil)
            throw PushError.messageParsingFailed("Parsed notification missing credential identifier")
        }

        if let messageId = (parsedData[NotificationKeys.messageId] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !messageId.isEmpty {
            if let existing = try await storage.getNotificationByMessageId(messageId: messageId) {
                logger?.d("Notification with messageId=\(messageId) already exists; returning cached instance")
                return existing
            }
        }

        if let userId = (parsedData[NotificationKeys.userId] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !userId.isEmpty {
            try await updateCredentialUserIdIfNeeded(credentialId: credentialId, userId: userId)
        }

        let notification = try createNotification(from: parsedData, credentialId: credentialId)
        try await storeNotification(notification)
        return notification
    }

    private func fetchNotification(notificationId: String) async throws -> PushNotification {
        do {
            guard let notification = try await storage.retrievePushNotification(notificationId: notificationId) else {
                logger?.w("Notification \(notificationId) not found", error: nil)
                throw PushError.notificationNotFound(notificationId)
            }
            return notification
        } catch let error as PushStorageError {
            logger?.e("Storage failure retrieving notification \(notificationId)", error: error)
            throw PushError.storageFailure("Failed to retrieve notification", error)
        } catch {
            logger?.e("Unexpected error retrieving notification \(notificationId)", error: error)
            throw PushError.storageFailure("Failed to retrieve notification", error)
        }
    }

    private func fetchCredential(credentialId: String) async throws -> PushCredential {
        if enableCredentialCache, let cached = credentialsCache[credentialId] {
            return cached
        }

        do {
            guard var credential = try await storage.retrievePushCredential(credentialId: credentialId) else {
                logger?.w("Credential \(credentialId) not found", error: nil)
                throw PushError.credentialNotFound(credentialId)
            }

            try await evaluateAndUpdateCredentialPolicies(&credential, store: true)

            if enableCredentialCache {
                credentialsCache[credentialId] = credential
            }

            return credential
        } catch let error as PushError {
            throw error
        } catch let error as PushStorageError {
            logger?.e("Storage failure retrieving credential \(credentialId)", error: error)
            throw PushError.storageFailure("Failed to retrieve credential", error)
        } catch {
            logger?.e("Unexpected error retrieving credential \(credentialId)", error: error)
            throw PushError.storageFailure("Failed to retrieve credential", error)
        }
    }

    private func identifyPlatform(messageData: [String: Any]) -> String? {
        for (platformId, handler) in pushHandlers where handler.canHandle(messageData: messageData) {
            return platformId
        }
        return nil
    }

    private func identifyPlatform(message: String) -> String? {
        for (platformId, handler) in pushHandlers where handler.canHandle(message: message) {
            return platformId
        }
        return nil
    }

    private func createNotification(from parsedData: [String: Any], credentialId: String) throws -> PushNotification {
        let messageId = (parsedData[NotificationKeys.messageId] as? String) ?? ""
        let messageText = parsedData[NotificationKeys.messageText] as? String
        let customPayload = stringValue(parsedData[NotificationKeys.customPayload])
        let challenge = parsedData[NotificationKeys.challenge] as? String
        let numbersChallenge = parsedData[NotificationKeys.numbersChallenge] as? String
        let loadBalancer = parsedData[NotificationKeys.loadBalancer] as? String
        let contextInfo = parsedData[NotificationKeys.contextInfo] as? String
        let ttl = intValue(parsedData[NotificationKeys.ttl], defaultValue: NotificationDefaults.ttl) ?? NotificationDefaults.ttl

        let pushType: PushType
        if let type = parsedData[NotificationKeys.pushType] as? PushType {
            pushType = type
        } else if let typeString = parsedData[NotificationKeys.pushType] as? String,
                  let parsedType = try? PushType.fromString(typeString) {
            pushType = parsedType
        } else {
            pushType = .default
        }

        let sentAt: Date?
        if let intervalValue = parsedData[NotificationKeys.timeInterval] {
            if let milliseconds = intValue(intervalValue, defaultValue: nil) {
                sentAt = Date(timeIntervalSince1970: Double(milliseconds) / 1000.0)
            } else if let doubleValue = intervalValue as? Double {
                sentAt = Date(timeIntervalSince1970: doubleValue / 1000.0)
            } else {
                sentAt = nil
            }
        } else {
            sentAt = nil
        }

        let additionalData = parsedData[NotificationKeys.additionalData] as? [String: Any]

        return PushNotification(
            credentialId: credentialId,
            ttl: ttl,
            messageId: messageId,
            messageText: messageText,
            customPayload: customPayload,
            challenge: challenge,
            numbersChallenge: numbersChallenge,
            loadBalancer: loadBalancer,
            contextInfo: contextInfo,
            pushType: pushType,
            createdAt: Date(),
            sentAt: sentAt,
            additionalData: additionalData
        )
    }

    private func storeNotification(_ notification: PushNotification) async throws {
        do {
            try await storage.storePushNotification(notification)
            logger?.d("Stored push notification \(notification.id)")
        } catch let error as PushStorageError {
            logger?.e("Failed to store push notification", error: error)
            throw PushError.storageFailure("Failed to store push notification", error)
        } catch {
            logger?.e("Failed to store push notification", error: error)
            throw PushError.storageFailure("Failed to store push notification", error)
        }
    }

    private func updateCredentialUserIdIfNeeded(credentialId: String, userId: String) async throws {
        do {
            guard let existing = try await storage.retrievePushCredential(credentialId: credentialId) else {
                return
            }

            if let current = existing.userId, !current.isEmpty {
                return
            }

            let updated = PushCredential(
                id: existing.id,
                userId: userId,
                resourceId: existing.resourceId,
                issuer: existing.issuer,
                displayIssuer: existing.displayIssuer,
                accountName: existing.accountName,
                displayAccountName: existing.displayAccountName,
                serverEndpoint: existing.serverEndpoint,
                sharedSecret: existing.sharedSecret,
                createdAt: existing.createdAt,
                imageURL: existing.imageURL,
                backgroundColor: existing.backgroundColor,
                policies: existing.policies,
                lockingPolicy: existing.lockingPolicy,
                isLocked: existing.isLocked,
                platform: existing.platform,
                additionalData: existing.additionalData
            )

            try await storage.storePushCredential(updated)

            if enableCredentialCache {
                credentialsCache[credentialId] = updated
            }
        } catch let error as PushStorageError {
            logger?.e("Failed to update credential userId for \(credentialId)", error: error)
        } catch {
            logger?.e("Unexpected error updating credential userId for \(credentialId)", error: error)
        }
    }

    private func intValue(_ value: Any?, defaultValue: Int?) -> Int? {
        guard let value else { return defaultValue }

        if let intValue = value as? Int {
            return intValue
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        if let stringValue = value as? String, let parsed = Int(stringValue) {
            return parsed
        }

        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }

        return defaultValue
    }

    private func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }

        if let string = value as? String {
            return string
        }

        if let data = value as? Data {
            return String(data: data, encoding: .utf8)
        }

        if let dictionary = value as? [String: Any], JSONSerialization.isValidJSONObject(dictionary),
           let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) {
            return String(data: data, encoding: .utf8)
        }

        if let array = value as? [Any], JSONSerialization.isValidJSONObject(array),
           let data = try? JSONSerialization.data(withJSONObject: array, options: []) {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    private func updateDeviceTokensOnServer(
        deviceToken: String,
        credentialId: String?
    ) async throws -> Bool {
        let deviceName = await Self.currentDeviceName()
        let params: [String: Any] = [HandlerKeys.deviceName: deviceName]

        if let credentialId {
            logger?.d("Updating device token for credential \(credentialId)")

            guard let credential = try await storage.retrievePushCredential(credentialId: credentialId) else {
                logger?.w("Credential \(credentialId) not found while updating device token", error: nil)
                return false
            }

            let platformId = credential.platform.rawValue
            guard let handler = pushHandlers[platformId] else {
                logger?.w("No handler available for platform \(platformId)", error: nil)
                throw PushError.noHandlerForPlatform(platformId)
            }

            do {
                return try await handler.setDeviceToken(
                    credential: credential,
                    deviceToken: deviceToken,
                    params: params
                )
            } catch let error as PushError {
                throw error
            } catch {
                logger?.e("Failed to update device token with handler for credential \(credentialId)", error: error)
                throw PushError.networkFailure("Failed to update device token with handler", error)
            }
        } else {
            logger?.d("Updating device token for all credentials")

            let credentials: [PushCredential]
            do {
                credentials = try await storage.getAllPushCredentials()
            } catch let error as PushStorageError {
                throw PushError.storageFailure("Failed to fetch credentials for device token update", error)
            } catch {
                logger?.e("Unexpected error fetching credentials for device token update", error: error)
                throw PushError.storageFailure("Failed to fetch credentials for device token update", error)
            }

            if credentials.isEmpty {
                logger?.d("No credentials registered; nothing to update")
                return true
            }

            var allSucceeded = true

            for credential in credentials {
                let platformId = credential.platform.rawValue
                guard let handler = pushHandlers[platformId] else {
                    logger?.w("Skipping credential \(credential.id); no handler for platform \(platformId)", error: nil)
                    continue
                }

                do {
                    let success = try await handler.setDeviceToken(
                        credential: credential,
                        deviceToken: deviceToken,
                        params: params
                    )

                    if !success {
                        allSucceeded = false
                        logger?.w("Handler reported failure updating device token for credential \(credential.id)", error: nil)
                    }
                } catch let error as PushError {
                    allSucceeded = false
                    logger?.e("Handler threw PushError while updating credential \(credential.id)", error: error)
                } catch {
                    allSucceeded = false
                    logger?.e("Unexpected error updating credential \(credential.id)", error: error)
                }
            }

            return allSucceeded
        }
    }
}
