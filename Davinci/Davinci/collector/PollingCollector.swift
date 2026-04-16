//
//  PollingCollector.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinciPlugin
import PingOrchestrate
import PingNetwork
import PingLogger

/// Represents the status of a polling operation.
public enum PollingStatus: Sendable {
    /// Polling is in progress.
    /// - Parameters:
    ///   - retryCount: The current retry count (1-based).
    ///   - maxRetries: The maximum number of retries configured.
    case `continue`(retryCount: Int, maxRetries: Int)

    /// Polling timed out because the maximum number of retries was reached.
    case timedOut

    /// The challenge expired. Emitted when the server returns HTTP 400,
    /// indicating the challenge has expired on the server side.
    case expired

    /// An error occurred during polling (network error, JSON parse failure, etc.).
    case error(Error)

    /// Polling completed successfully.
    /// - Parameter status: The status string returned by the server (e.g. `"approved"`).
    ///   In simple polling mode this will be `"continue"`.
    case complete(status: String)
}

/// A collector that handles asynchronous polling operations in DaVinci authentication flows.
///
/// Used for scenarios that require waiting for user action on another device or channel,
/// such as push notification authentication, QR code scanning, or email verification.
///
/// ## Polling Modes
///
/// ### Simple Polling Mode
/// When `pollChallengeStatus` is `false` or `challenge` is empty: waits for `pollInterval` ms,
/// decrements `retriesAllowed`, emits `.complete(status: "continue")` while retries remain,
/// and `.timedOut` when retries are exhausted.
///
/// ### Challenge Status Polling Mode
/// When `pollChallengeStatus` is `true` and `challenge` is non-empty: repeatedly POSTs to
/// `{baseUrl}/davinci/user/credentials/challenge/{challenge}/status` until the challenge
/// completes, expires, times out, or an error occurs.
///
/// ## Value Assignment
/// The `value` property is updated automatically before each terminal status is yielded:
/// - `.complete` → the server status string (e.g. `"approved"` or `"continue"`)
/// - `.timedOut` → `"timedOut"`
/// - `.expired` → `"expired"`
/// - `.error` → `"error"`
/// - `.continue` → `"continue"` 
public class PollingCollector: SingleValueCollector, Submittable, ContinueNodeAware, DaVinciAware, Closeable, @unchecked Sendable {

    /// Serialises access to mutable state (`value`, `retriesAllowed`) that is written by the
    /// background polling `Task` and read from the main actor (SwiftUI views, form submission).
    private let lock = NSLock()

    // MARK: - ContinueNodeAware

    /// The continue node providing configuration context (links, interactionId) for challenge polling.
    /// Declared `weak` to break the retain cycle: `ContinueNode → PollingCollector → ContinueNode`.
    /// The node is kept alive by the view layer that is currently displaying it, so the weak
    /// reference is always valid for the duration of an active polling session.
    public weak var continueNode: ContinueNode? {
        didSet {
            guard let node = continueNode else { return }

            // Each polling cycle causes a DaVinci re-submission that produces a fresh
            // PollingCollector parsed from JSON (retriesAllowed resets to pollRetries).
            // Restore the persisted count so the counter continues from where it left off.
            // The FlowContext key is scoped to both the connector id and the field key:
            // - connector id changes between different polling steps in the flow, so two
            //   sequential steps that both use key="polling-field" never share state.
            // - field key disambiguates collectors on the same form (rare but safe).
            let connectorId = node.input[Constants.id] as? String ?? ""
            let contextKey = SharedContext.Keys.pollingRetriesRemaining(connectorId: connectorId, fieldKey: key)
            if let remaining = node.context.flowContext.get(key: contextKey) as? Int {
                lock.withLock { retriesAllowed = remaining }
            }
        }
    }

    // MARK: - DaVinciAware

    /// The DaVinci workflow instance providing access to the HTTP client.
    public var davinci: DaVinci?

    // MARK: - Properties

    /// Polling interval in milliseconds between each attempt. Default: `2000`.
    public private(set) var pollInterval: Int = Constants.defaultPollInterval

    /// Maximum number of polling attempts before timing out. Default: `60`.
    public private(set) var pollRetries: Int = Constants.defaultPollRetries

    /// Whether to actively poll the server endpoint for challenge completion. Default: `false`.
    public private(set) var pollChallengeStatus: Bool = false

    /// The challenge identifier used to construct the polling endpoint URL. Default: `""`.
    public private(set) var challenge: String = ""

    /// Remaining attempts for simple polling mode.
    /// Initialized from `pollRetries` and decremented on each interval.
    public var retriesAllowed: Int = 0

    // MARK: - Init

    public required init(with json: [String: Any]) {
        super.init(with: json)
        // Accept both String ("2000") and numeric (2000) JSON representations so the collector
        // is robust regardless of whether the server quotes these values.
        pollInterval = Self.jsonInt(json, key: Constants.pollInterval) ?? Constants.defaultPollInterval
        pollRetries  = Self.jsonInt(json, key: Constants.pollRetries)  ?? Constants.defaultPollRetries
        pollChallengeStatus = json[Constants.pollChallengeStatus] as? Bool ?? false
        challenge = json[Constants.challenge] as? String ?? ""
        retriesAllowed = pollRetries
    }

    /// Reads a value from a JSON dict as an `Int`, accepting both quoted (`"3"`) and
    /// unquoted (`3`) JSON representations.
    private static func jsonInt(_ json: [String: Any], key: String) -> Int? {
        if let s = json[key] as? String  { return Int(s) }
        if let n = json[key] as? Int     { return n }
        if let d = json[key] as? Double  { return Int(d) }
        return nil
    }

    // MARK: - Submittable

    /// Returns the event type for submission.
    public func eventType() -> String {
        return Constants.pollingEventType
    }

    // MARK: - Polling

    /// Starts polling and returns an `AsyncStream` of `PollingStatus` updates.
    ///
    /// The stream finishes when polling reaches a terminal state
    /// (`.complete`, `.timedOut`, `.expired`, or `.error`).
    /// The `value` property is updated automatically before each status is yielded.
    public func poll() -> AsyncStream<PollingStatus> {
        AsyncStream { continuation in
            Task {
                if pollChallengeStatus && !challenge.isEmpty {
                    await pollForChallengeStatus(continuation: continuation)
                } else {
                    await pollSimple(continuation: continuation)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private

    private func pollForChallengeStatus(continuation: AsyncStream<PollingStatus>.Continuation) async {
        guard
            let node = continueNode,
            let links = node.input[Constants._links] as? [String: Any],
            let selfLink = links[Constants._self] as? [String: Any],
            let selfHref = selfLink[Constants.href] as? String,
            let interactionId = node.input[Constants.interactionId] as? String
        else {
            davinci?.config.logger.w("Missing selfHref or interactionId for challenge polling", error: PollingError.missingConfiguration)
            lock.withLock { value = Constants.pollingValueError }
            continuation.yield(.error(PollingError.missingConfiguration))
            return
        }

        // Derive the HTTP client from the workflow stored in the ContinueNode rather than
        // relying on DaVinciAware injection, which may not fire for closure-registered collectors.
        guard let httpClient = node.workflow.config.httpClient else {
            lock.withLock { value = Constants.pollingValueError }
            continuation.yield(.error(PollingError.missingConfiguration))
            return
        }

        let baseUrl = selfHref.components(separatedBy: Constants.davinciConnectionsPathSegment).first ?? selfHref
        // Use a character set that excludes '/' so slashes in the challenge are percent-encoded
        // as %2F, preventing them from being interpreted as path separators.
        var challengeAllowed = CharacterSet.urlPathAllowed
        challengeAllowed.remove("/")
        guard
            let encodedChallenge = challenge.addingPercentEncoding(withAllowedCharacters: challengeAllowed),
            let urlComponents = URLComponents(string: "\(baseUrl)\(Constants.challengeStatusPathPrefix)\(encodedChallenge)\(Constants.challengeStatusPathSuffix)"),
            urlComponents.url != nil,
            let pollingUrl = urlComponents.url?.absoluteString
        else {
            lock.withLock { value = Constants.pollingValueError }
            continuation.yield(.error(PollingError.missingConfiguration))
            return
        }
        
        let maxRetries = pollRetries
        let intervalNs = UInt64(pollInterval) * 1_000_000

        guard maxRetries > 0 else {
            lock.withLock { value = Constants.pollingValueTimedOut }
            continuation.yield(.timedOut)
            return
        }

        // Loop internally until the challenge resolves, times out, or a fatal error occurs.
        // Unlike simple polling, challenge polling does NOT trigger a DaVinci re-submit between
        // cycles — the status endpoint is polled directly until isChallengeComplete is true.
        for retryCount in 1...maxRetries {
            // Emit the current attempt before sleeping so the UI counter updates immediately.
            lock.withLock { value = Constants.pollingValueContinue }
            continuation.yield(.continue(retryCount: retryCount, maxRetries: maxRetries))

            do {
                try await Task.sleep(nanoseconds: intervalNs)
            } catch {
                // Task.sleep only throws CancellationError.
                return
            }

            if Task.isCancelled { return }

            do {
                let response = try await httpClient.request { req in
                    req.url = pollingUrl
                    req.setHeader(name: Constants.interactionId, value: interactionId)
                    req.post(json: [:])
                }

                // Any HTTP 400 means the challenge has expired on the server side.
                // Other non-200 responses are transient — keep polling.
                guard response.status.isSuccess() else {
                    davinci?.config.logger.i("Server returned non-200 response: \(response.status), \(response.bodyAsString())")
                    if response.status.isClientError() {
                        lock.withLock { value = Constants.pollingValueExpired }
                        continuation.yield(.expired)
                        return
                    }
                    lock.withLock { value = Constants.pollingValueError }
                    continue
                }

                let bodyString = response.bodyAsString()
                guard
                    let data = bodyString.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    lock.withLock { value = Constants.pollingValueError }
                    continuation.yield(.error(PollingError.invalidResponse))
                    return
                }

                let isChallengeComplete = json[Constants.isChallengeComplete] as? Bool ?? false
                if isChallengeComplete {
                    let serverStatus = json[Constants.status] as? String ?? ""
                    lock.withLock { value = serverStatus }
                    continuation.yield(.complete(status: serverStatus))
                    return
                }
                // Not yet complete — loop to next retry.
            } catch {
                davinci?.config.logger.w("Error polling challenge status", error: error)
                lock.withLock { value = Constants.pollingValueError }
                continuation.yield(.error(error))
                return
            }
        }

        lock.withLock { value = Constants.pollingValueTimedOut }
        continuation.yield(.timedOut)
    }

    private func pollSimple(continuation: AsyncStream<PollingStatus>.Continuation) async {
        guard pollInterval > 0 else {
            lock.withLock { value = Constants.pollingValueError }
            continuation.yield(.error(PollingError.invalidInterval))
            return
        }

        let currentAttempt = lock.withLock { pollRetries - retriesAllowed + 1 }

        // Emit current attempt immediately so the UI updates the counter before sleeping.
        continuation.yield(.continue(retryCount: currentAttempt, maxRetries: pollRetries))

        do {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000)
        } catch {
            // Task.sleep only throws CancellationError.
            return
        }

        // Atomically decrement retriesAllowed and determine the terminal status + value.
        let (updatedRetries, status): (Int, PollingStatus) = lock.withLock {
            retriesAllowed -= 1
            if retriesAllowed <= 0 {
                value = Constants.pollingValueTimedOut
                return (retriesAllowed, .timedOut)
            } else {
                value = Constants.pollingValueContinue
                return (retriesAllowed, .complete(status: Constants.pollingValueContinue))
            }
        }

        // Persist the updated count so the next fresh PollingCollector instance (created after
        // DaVinci re-submits and returns the same form) can restore the correct position.
        let connectorId = continueNode?.input[Constants.id] as? String ?? ""
        continueNode?.context.flowContext.set(
            key: SharedContext.Keys.pollingRetriesRemaining(connectorId: connectorId, fieldKey: key),
            value: updatedRetries)

        continuation.yield(status)
    }

    // MARK: - Payload

    /// Thread-safe read of `value` for form submission.
    public override func payload() -> String? {
        lock.withLock { value.isEmpty ? nil : value }
    }

    // MARK: - Closeable

    public func close() {
        lock.withLock { value = "" }
    }
}

/// Errors specific to `PollingCollector` operations.
public enum PollingError: Error, LocalizedError, Sendable {
    /// Required configuration (`nextHref` or `interactionId`) is missing from the continue node.
    case missingConfiguration
    /// The `pollInterval` value is invalid or non-positive.
    case invalidInterval
    /// The polling response body could not be parsed as JSON.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Required polling configuration (nextHref or interactionId) is missing."
        case .invalidInterval:
            return "The pollInterval value is invalid or zero."
        case .invalidResponse:
            return "The polling response body could not be parsed."
        }
    }
}

fileprivate extension Constants {
    static let defaultPollInterval = 2000
    static let defaultPollRetries = 60
}

extension SharedContext.Keys {
    /// Returns the FlowContext key used to persist `retriesAllowed` for a given polling field.
    ///
    /// Scoping by both connector id and field key ensures correctness even when multiple
    /// polling steps in the same flow reuse the same generic field key (e.g. `"polling-field"`):
    /// - `connectorId` changes between different nodes, so step 1 and step 2 each get their
    ///   own entry even if their field keys are identical.
    /// - `fieldKey` further disambiguates collectors that appear on the same form.
    ///
    /// - Parameters:
    ///   - connectorId: The `id` of the enclosing connector (e.g. `"czys1qteu6"`).
    ///   - fieldKey: The `key` value of the `PollingCollector` (e.g. `"polling-field"`).
    static func pollingRetriesRemaining(connectorId: String, fieldKey: String) -> String {
        return "com.pingidentity.davinci.POLLING_RETRIES_REMAINING.\(connectorId).\(fieldKey)"
    }
}

