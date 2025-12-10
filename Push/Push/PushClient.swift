//
//  PushClient.swift
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

/// Public-facing client that orchestrates Push MFA operations.
///
/// The client exposes high-level APIs for credential management, notification
/// processing, and response handling while delegating business logic to the
/// internal ``PushService``. Clients should create instances using the DSL-style
/// factory methods which encapsulate configuration defaults and dependency setup.
public final class PushClient: @unchecked Sendable {

    // MARK: - Stored Properties

    private let configuration: PushConfiguration
    private let storage: any PushStorage
    private let httpClient: HttpClient
    private let pushService: PushService
    private let cleanupManager: NotificationCleanupManager
    private let logger: Logger?

    private var isInitialized: Bool = false

    // MARK: - Internal Accessors (for testing)

    /// Exposes the resolved configuration to unit tests.
    internal var configurationSnapshot: PushConfiguration { configuration }

    /// Exposes the resolved storage implementation to unit tests.
    internal var storageProvider: any PushStorage { storage }

    // MARK: - Factory Methods

    /// Creates a `PushClient` using a DSL-style configuration closure.
    ///
    /// - Parameter configure: Closure that mutates a fresh `PushConfiguration`.
    /// - Returns: A fully initialized `PushClient`.
    /// - Throws: `PushError.initializationFailed` when dependency setup fails.
    public static func createClient(
        configure: (PushConfiguration) -> Void = { _ in }
    ) async throws -> PushClient {
        let configuration = PushConfiguration.build(configure)
        return try await createClient(configuration: configuration)
    }

    /// Creates a `PushClient` from an existing `PushConfiguration` instance.
    ///
    /// - Parameter configuration: Pre-constructed configuration object.
    /// - Returns: A fully initialized `PushClient`.
    /// - Throws: `PushError.initializationFailed` when dependency setup fails.
    public static func createClient(
        configuration: PushConfiguration
    ) async throws -> PushClient {
        return try await PushClient(configuration: configuration)
    }

    // MARK: - Initialization

    /// Initializes the client by resolving dependencies and wiring the internal service layer.
    ///
    /// - Parameter configuration: The configuration object to use.
    /// - Throws: `PushError.initializationFailed` when dependency setup fails.
    private init(configuration: PushConfiguration) async throws {
        self.configuration = configuration
        self.logger = configuration.logger

        do {
            let resolvedStorage = try PushClient.resolveStorage(
                for: configuration,
                logger: logger
            )
            self.storage = resolvedStorage

            let client = try PushClient.makeHttpClient(
                timeoutMs: configuration.timeoutMs,
                logger: logger
            )
            self.httpClient = client

            let evaluator = try PushClient.makePolicyEvaluator(using: configuration)

            self.pushService = try PushClient.makePushService(
                storage: resolvedStorage,
                configuration: configuration,
                httpClient: client,
                policyEvaluator: evaluator
            )

            self.cleanupManager = NotificationCleanupManager(
                storage: resolvedStorage,
                config: configuration.notificationCleanupConfig,
                logger: logger
            )

            isInitialized = true
            logger?.d("PushClient initialized successfully")
        } catch let error as PushError {
            logger?.e("Failed to initialize PushClient: \(error)", error: error)
            throw PushError.initializationFailed("Failed to initialize PushClient", error)
        } catch {
            logger?.e("Failed to initialize PushClient: \(error)", error: error)
            throw PushError.initializationFailed("Failed to initialize PushClient", error)
        }
    }

    // MARK: - Internal Helpers

    /// Validates that the client has completed initialization.
    ///
    /// - Throws: `PushError.notInitialized` when the client is not ready for use.
    @inline(__always)
    internal func checkInitialized() throws {
        guard isInitialized else {
            logger?.w("PushClient used before initialization completed", error: nil)
            throw PushError.notInitialized
        }
    }

    // MARK: - Credential Operations

    /// Registers a Push credential from a `pushauth://` URI (typically obtained via QR code).
    ///
    /// - Parameter uri: Enrollment URI containing credential details and registration parameters.
    /// - Returns: The stored ``PushCredential`` instance.
    /// - Throws: `PushError` when parsing, policy evaluation, registration, or storage fails.
    public func addCredentialFromUri(_ uri: String) async throws -> PushCredential {
        try checkInitialized()
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger?.w("addCredentialFromUri called with empty URI", error: nil)
            throw PushError.invalidUri("Enrollment URI cannot be empty")
        }

        return try await pushService.addCredentialFromUri(trimmed)
    }

    /// Persists a Push credential that was created or fetched externally.
    ///
    /// - Parameter credential: The credential to store.
    /// - Returns: The stored credential (potentially updated by policy evaluation).
    /// - Throws: `PushError.storageFailure` when persistence fails.
    public func saveCredential(_ credential: PushCredential) async throws -> PushCredential {
        try checkInitialized()
        return try await pushService.addCredential(credential)
    }

    /// Retrieves all stored Push credentials.
    ///
    /// - Returns: Array of credentials currently known to the client.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    public func getCredentials() async throws -> [PushCredential] {
        try checkInitialized()
        return try await pushService.getCredentials()
    }

    /// Retrieves a single Push credential by identifier.
    ///
    /// - Parameter credentialId: Identifier of the credential to fetch.
    /// - Returns: The credential when found, otherwise `nil`.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    public func getCredential(credentialId: String) async throws -> PushCredential? {
        try checkInitialized()
        return try await pushService.getCredential(credentialId: credentialId)
    }

    /// Deletes a Push credential and any associated cached state.
    ///
    /// - Parameter credentialId: Identifier of the credential to remove.
    /// - Returns: `true` when a credential was removed, `false` when it did not exist.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    public func deleteCredential(credentialId: String) async throws -> Bool {
        try checkInitialized()
        return try await pushService.removeCredential(credentialId: credentialId)
    }

    // MARK: - Device Token Management

    /// Updates the APNs device token used for Push notifications.
    ///
    /// - Parameters:
    ///   - deviceToken: Raw APNs device token string.
    ///   - credentialId: Optional credential identifier to scope the update. When `nil`,
    ///     all registered credentials are updated.
    /// - Returns: `true` when the handler reports success for all updates (or the token is unchanged).
    /// - Throws: `PushError` when validation, storage, or handler operations fail.
    public func setDeviceToken(
        _ deviceToken: String,
        credentialId: String? = nil
    ) async throws -> Bool {
        try checkInitialized()
        return try await pushService.setDeviceToken(deviceToken, credentialId: credentialId)
    }

    /// Retrieves the currently stored APNs device token, if available.
    ///
    /// - Returns: The device token string or `nil` when no token has been stored.
    /// - Throws: `PushError.storageFailure` when storage access fails.
    public func getDeviceToken() async throws -> String? {
        try checkInitialized()
        return try await pushService.getDeviceToken()
    }

    // MARK: - Notification Processing

    /// Processes a push notification represented as a dictionary payload (e.g. APNs `userInfo`).
    ///
    /// - Parameter messageData: Raw notification payload.
    /// - Returns: The stored ``PushNotification`` (or `nil` when the payload is unsupported).
    /// - Throws: `PushError` when parsing or persistence fails.
    public func processNotification(messageData: [String: Any]) async throws -> PushNotification? {
        try checkInitialized()

        let payload = UnsafeMessagePayload(value: messageData)
        let notification = try await pushService.processNotification(messageData: payload.value)
        if let notification {
            let credentialId = notification.credentialId
            Task { [weak self] in
                await self?.runAutoCleanup(credentialId: credentialId)
            }
        }
        return notification
    }

    /// Processes a push notification represented as a string payload (typically JWT).
    ///
    /// - Parameter message: Encoded notification payload.
    /// - Returns: The stored ``PushNotification`` (or `nil` when the payload is unsupported).
    /// - Throws: `PushError` when parsing or persistence fails.
    public func processNotification(message: String) async throws -> PushNotification? {
        try checkInitialized()

        let notification = try await pushService.processNotification(message: message)
        if let notification {
            let credentialId = notification.credentialId
            Task { [weak self] in
                await self?.runAutoCleanup(credentialId: credentialId)
            }
        }
        return notification
    }

    /// Processes a push notification using a `UNNotification`-style `userInfo` dictionary.
    ///
    /// - Parameter userInfo: Notification payload in `[AnyHashable: Any]` form.
    /// - Returns: The stored ``PushNotification`` (or `nil` when unsupported).
    /// - Throws: `PushError` when parsing or persistence fails.
    public func processNotification(userInfo: [AnyHashable: Any]) async throws -> PushNotification? {
        let messageData = userInfo.reduce(into: [String: Any]()) { partialResult, pair in
            if let key = pair.key as? String {
                partialResult[key] = pair.value
            }
        }
        return try await processNotification(messageData: messageData)
    }

    // MARK: - Notification Responses

    /// Approves a pending notification identified by `notificationId`.
    ///
    /// - Parameter notificationId: Identifier of the notification to approve.
    /// - Returns: `true` when the approval succeeds, `false` when the notification is no longer pending
    ///   or the handler reports failure.
    /// - Throws: `PushError` when the client is not initialized, the notification cannot be found, or
    ///   handler/storage operations fail.
    public func approveNotification(_ notificationId: String) async throws -> Bool {
        try checkInitialized()
        return try await pushService.approveNotification(
            notificationId: notificationId,
            params: [:] as [String: any Sendable]
        )
    }

    /// Approves a challenge-based notification by supplying the challenge response.
    ///
    /// - Parameters:
    ///   - notificationId: Identifier of the notification to approve.
    ///   - challengeResponse: User-provided response required for number-matching flows.
    /// - Returns: `true` when the approval succeeds.
    /// - Throws: `PushError.invalidParameterValue` when the response is empty, or `PushError` surfaced
    ///   by the underlying service.
    public func approveChallengeNotification(
        _ notificationId: String,
        challengeResponse: String
    ) async throws -> Bool {
        try checkInitialized()

        let trimmed = challengeResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger?.w("approveChallengeNotification called with empty response", error: nil)
            throw PushError.invalidParameterValue("Challenge response cannot be empty")
        }

        let params: [String: any Sendable] = ["challengeResponse": trimmed]
        return try await pushService.approveNotification(notificationId: notificationId, params: params)
    }

    /// Approves a biometric notification by indicating the authentication method used.
    ///
    /// - Parameters:
    ///   - notificationId: Identifier of the notification to approve.
    ///   - authenticationMethod: Method used to authenticate the user (for example, "face" or "fingerprint").
    /// - Returns: `true` when the approval succeeds.
    /// - Throws: `PushError.invalidParameterValue` when the method is empty, or any `PushError` from the service.
    public func approveBiometricNotification(
        _ notificationId: String,
        authenticationMethod: String
    ) async throws -> Bool {
        try checkInitialized()

        let trimmed = authenticationMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger?.w("approveBiometricNotification called with empty authentication method", error: nil)
            throw PushError.invalidParameterValue("Authentication method cannot be empty")
        }

        let params: [String: any Sendable] = ["authenticationMethod": trimmed]
        return try await pushService.approveNotification(notificationId: notificationId, params: params)
    }

    /// Denies a pending notification.
    ///
    /// - Parameter notificationId: Identifier of the notification to deny.
    /// - Returns: `true` when the denial succeeds.
    /// - Throws: `PushError` surfaced from the underlying service operations.
    public func denyNotification(_ notificationId: String) async throws -> Bool {
        try checkInitialized()
        return try await pushService.denyNotification(
            notificationId: notificationId,
            params: [:] as [String: any Sendable]
        )
    }

    // MARK: - Notification Queries & Cleanup

    /// Retrieves all pending notifications awaiting user action.
    ///
    /// - Returns: Array of pending notifications.
    /// - Throws: `PushError` surfaced from storage operations.
    public func getPendingNotifications() async throws -> [PushNotification] {
        try checkInitialized()
        return try await pushService.getPendingNotifications()
    }

    /// Retrieves all stored notifications, regardless of status.
    ///
    /// - Returns: Array of notifications.
    /// - Throws: `PushError` surfaced from storage operations.
    public func getAllNotifications() async throws -> [PushNotification] {
        try checkInitialized()
        return try await pushService.getAllNotifications()
    }

    /// Retrieves a specific notification by identifier.
    ///
    /// - Parameter notificationId: Identifier of the notification to fetch.
    /// - Returns: The notification when found, otherwise `nil`.
    /// - Throws: `PushError` surfaced from storage operations.
    public func getNotification(notificationId: String) async throws -> PushNotification? {
        try checkInitialized()
        return try await pushService.getNotification(notificationId: notificationId)
    }

    /// Runs notification cleanup according to the configured strategy.
    ///
    /// - Parameter credentialId: Optional credential identifier to scope the cleanup.
    /// - Returns: The number of notifications removed during cleanup.
    /// - Throws: `PushError` when storage operations fail.
    public func cleanupNotifications(credentialId: String? = nil) async throws -> Int {
        try checkInitialized()
        return try await cleanupManager.runCleanup(credentialId: credentialId)
    }

    /// Clears cached state and marks the client as uninitialized.
    public func close() async {
        guard isInitialized else { return }

        await pushService.clearCache()

        do {
            _ = try await cleanupManager.runCleanup(credentialId: nil)
        } catch {
            logger?.w("Error running cleanup during close: \(error.localizedDescription)", error: error)
        }

        isInitialized = false
        logger?.d("PushClient closed")
    }

    // MARK: - Private Factory Helpers

    private static func resolveStorage(
        for configuration: PushConfiguration,
        logger: Logger?
    ) throws -> any PushStorage {
        if let storage = configuration.storage {
            return storage
        }

        let defaultStorage = PushKeychainStorage(logger: logger)
        configuration.storage = defaultStorage
        return defaultStorage
    }

    private static func makeHttpClient(
        timeoutMs: Int,
        logger: Logger?
    ) throws -> HttpClient {
        let client = HttpClient()
        client.timeoutIntervalForRequest = TimeInterval(timeoutMs) / 1000.0
        return client
    }

    private static func makePolicyEvaluator(
        using configuration: PushConfiguration
    ) throws -> MfaPolicyEvaluator {
        if let evaluator = configuration.policyEvaluator {
            return evaluator
        }

        let evaluator = MfaPolicyEvaluator.create()
        configuration.policyEvaluator = evaluator
        return evaluator
    }

    private static func makePushService(
        storage: any PushStorage,
        configuration: PushConfiguration,
        httpClient: HttpClient,
        policyEvaluator: MfaPolicyEvaluator
    ) throws -> PushService {
        return PushService(
            storage: storage,
            configuration: configuration,
            httpClient: httpClient,
            policyEvaluator: policyEvaluator
        )
    }

    private func runAutoCleanup(credentialId: String?) async {
        let cleanupConfig = configuration.notificationCleanupConfig
        guard cleanupConfig.cleanupMode != .none else {
            return
        }

        do {
            let removed = try await cleanupManager.runCleanup(credentialId: credentialId)
            if removed > 0 {
                logger?.d(
                    "Auto-cleanup removed \(removed) notification(s) using mode \(cleanupConfig.cleanupMode.rawValue)"
                )
            }
        } catch {
            logger?.w("Auto-cleanup failed: \(error.localizedDescription)", error: error)
        }
    }
}
private struct UnsafeMessagePayload: @unchecked Sendable { let value: [String: Any] }
