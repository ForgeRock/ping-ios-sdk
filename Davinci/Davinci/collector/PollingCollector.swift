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

/// Represents the status of a polling operation.
public enum PollingStatus: Sendable {
    /// Polling is in progress.
    /// - Parameters:
    ///   - retryCount: The current retry count (1-based).
    ///   - maxRetries: The maximum number of retries configured.
    case continuing(retryCount: Int, maxRetries: Int)

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
/// The `value` property is updated automatically before each status is yielded:
/// - `.complete` → the server status string (e.g. `"approved"` or `"continue"`)
/// - `.timedOut` → `"timedOut"`
/// - `.expired` → `"expired"`
/// - `.error` → `"error"`
/// - `.continuing` → `"continue"`
public class PollingCollector: SingleValueCollector, Submittable, ContinueNodeAware, DaVinciAware, Closeable, @unchecked Sendable {

    // MARK: - ContinueNodeAware

    /// The continue node providing configuration context (links, interactionId) for challenge polling.
    /// Declared `weak` to break the retain cycle: `ContinueNode → PollingCollector → ContinueNode`.
    /// The node is kept alive by the view layer that is currently displaying it, so the weak
    /// reference is always valid for the duration of an active polling session.
    /// When set, restores `retriesAllowed` from FlowContext if a value was persisted by a previous
    /// polling cycle (i.e. after a rewindStateToLastRenderedUI event creates a fresh collector).
    public weak var continueNode: ContinueNode? {
        didSet {
            guard let node = continueNode else { return }

            // Restore retry count persisted by a previous polling cycle after a rewind event.
            if let remaining = node.context.flowContext
                .get(key: SharedContext.Keys.pollingRetriesRemaining) as? Int {
                retriesAllowed = remaining
            }

            // The server places `pollChallengeStatus` and `challenge` at the root of the
            // response JSON, not inside the individual field dict that is passed to init.
            // Read them from continueNode.input as a fallback so challenge-polling works
            // even when those keys are absent from the field-level JSON.
            if !pollChallengeStatus {
                pollChallengeStatus = node.input[Constants.pollChallengeStatus] as? Bool ?? false
            }
            if challenge.isEmpty {
                challenge = node.input[Constants.challenge] as? String ?? ""
            }
        }
    }

    // MARK: - DaVinciAware

    /// The DaVinci workflow instance providing access to the HTTP client.
    public var davinci: DaVinci?

    // MARK: - Properties

    /// Polling interval in milliseconds between each attempt. Default: `"2000"`.
    public private(set) var pollInterval: String = "2000"

    /// Maximum number of polling attempts before timing out. Default: `"60"`.
    public private(set) var pollRetries: String = "60"

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
        pollInterval = Self.jsonString(json, key: Constants.pollInterval) ?? "2000"
        pollRetries  = Self.jsonString(json, key: Constants.pollRetries)  ?? "60"
        pollChallengeStatus = json[Constants.pollChallengeStatus] as? Bool ?? false
        challenge = json[Constants.challenge] as? String ?? ""
        retriesAllowed = Int(pollRetries) ?? 60
    }

    /// Reads a value from a JSON dict as a `String`, accepting both quoted (`"3"`) and
    /// unquoted (`3`) JSON representations.
    private static func jsonString(_ json: [String: Any], key: String) -> String? {
        if let s = json[key] as? String  { return s }
        if let n = json[key] as? Int     { return String(n) }
        if let d = json[key] as? Double  { return String(Int(d)) }
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
            let next = links[Constants.next] as? [String: Any],
            let nextHref = next[Constants.href] as? String,
            let interactionId = node.input[Constants.interactionId] as? String
        else {
            value = Constants.pollingValueError
            continuation.yield(.error(PollingError.missingConfiguration))
            return
        }

        // Derive the HTTP client from the workflow stored in the ContinueNode rather than
        // relying on DaVinciAware injection, which may not fire for closure-registered collectors.
        let httpClient = node.workflow.config.httpClient!

        let baseUrl = nextHref.components(separatedBy: Constants.davinciConnectionsPathSegment).first ?? nextHref
        let pollingUrl = "\(baseUrl)\(Constants.challengeStatusPathPrefix)\(challenge)\(Constants.challengeStatusPathSuffix)"
        let maxRetries = Int(pollRetries) ?? 60
        let intervalNs = UInt64((Double(pollInterval) ?? 2000) * 1_000_000)

        guard maxRetries > 0 else {
            value = Constants.pollingValueTimedOut
            continuation.yield(.timedOut)
            return
        }

        // Loop internally until the challenge resolves, times out, or a fatal error occurs.
        // Unlike simple polling, challenge polling does NOT trigger a DaVinci re-submit between
        // cycles — the status endpoint is polled directly until isChallengeComplete is true.
        for retryCount in 1...maxRetries {
            // Emit the current attempt before sleeping so the UI counter updates immediately.
            value = Constants.pollingValueContinue
            continuation.yield(.continuing(retryCount: retryCount, maxRetries: maxRetries))

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

                // HTTP 400 means the challenge has expired on the server side.
                // Other non-200 responses are transient — keep polling.
                guard response.status == 200 else {
                    if response.status == 400 {
                        value = Constants.pollingValueExpired
                        continuation.yield(.expired)
                        return
                    }
                    value = Constants.pollingValueError
                    continue
                }

                let bodyString = response.bodyAsString()
                guard
                    let data = bodyString.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    value = Constants.pollingValueError
                    continue
                }

                let isChallengeComplete = json[Constants.isChallengeComplete] as? Bool ?? false
                if isChallengeComplete {
                    let serverStatus = json[Constants.status] as? String ?? ""
                    value = serverStatus
                    continuation.yield(.complete(status: serverStatus))
                    return
                }
                // Not yet complete — loop to next retry.
            } catch {
                value = Constants.pollingValueError
                continuation.yield(.error(error))
                return
            }
        }

        value = Constants.pollingValueTimedOut
        continuation.yield(.timedOut)
    }

    private func pollSimple(continuation: AsyncStream<PollingStatus>.Continuation) async {
        let interval = Double(pollInterval) ?? 0
        guard interval > 0 else {
            value = Constants.pollingValueError
            continuation.yield(.error(PollingError.invalidInterval))
            return
        }

        // Capture the node strongly before suspending. continueNode is weak to break the
        // ContinueNode ↔ PollingCollector retain cycle; the local let keeps it alive for
        // the duration of this single polling cycle.
        let node = continueNode
        let totalRetries = Int(pollRetries) ?? 60
        let currentAttempt = totalRetries - retriesAllowed + 1

        // Emit current attempt immediately so the UI updates the counter before sleeping.
        continuation.yield(.continuing(retryCount: currentAttempt, maxRetries: totalRetries))

        do {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000))
        } catch {
            // Task.sleep only throws CancellationError.
            return
        }

        retriesAllowed -= 1

        // Persist remaining retries so the fresh PollingCollector created after a rewind event
        // can restore the counter and continue counting down correctly via continueNode.didSet.
        node?.context.flowContext.set(
            key: SharedContext.Keys.pollingRetriesRemaining, value: retriesAllowed)

        if retriesAllowed <= 0 {
            value = Constants.pollingValueTimedOut
            continuation.yield(.timedOut)
        } else {
            value = Constants.pollingValueContinue
            continuation.yield(.complete(status: Constants.pollingValueContinue))
        }
    }

    // MARK: - Closeable

    public func close() {
        value = ""
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

extension SharedContext.Keys {
    /// Key used to persist remaining retry count across rewind-triggered polling cycles.
    static let pollingRetriesRemaining = "com.pingidentity.davinci.POLLING_RETRIES_REMAINING"
}
