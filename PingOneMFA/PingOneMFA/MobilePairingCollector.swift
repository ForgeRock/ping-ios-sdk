//
//  MobilePairingCollector.swift
//  PingOneMFA
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import Foundation
import PingDavinciPlugin
import PingLogger
import PingOrchestrate

/// String constants used by the `MOBILE_PAIRING` collector.
enum MobilePairingConstants {
    /// Collector type key used both in the DaVinci node JSON and as the registration
    /// key in `CollectorFactory`.
    static let type = Constants.MOBILE_PAIRING
    /// Server field carrying the pairing key to claim.
    static let pairingKey = "pairingKey"
    /// Payload key holding the pairing outcome status.
    static let status = "status"
    /// Status value indicating the pairing key was claimed successfully.
    static let claimed = "CLAIMED"
    /// Fallback error code when no native SDK error code is available.
    static let internalError = "INTERNAL_ERROR"
    /// Error code stored in the payload when `cancel(message:)` is called.
    static let userCancelled = "USER_CANCELLED"
    /// Fallback error message for pairing failures.
    static let pairingFailed = "Pairing failed"
    /// Default cancellation message for `cancel(message:)`.
    static let cancellationMessage = "User canceled the pairing flow"
}

/// A DaVinci field collector for the `MOBILE_PAIRING` node type.
///
/// When a DaVinci flow presents a `MOBILE_PAIRING` collector, the server supplies a
/// `pairingKey` in the node JSON. This collector reads that key, claims it by calling
/// `MobilePairingClient.pair(pairingKey:)` (backed by the PingOne MFA native SDK), and
/// posts the outcome back to the server in the resume POST.
///
/// ## Resume envelope
/// Conforming to `Submittable` and returning `"action"` from `eventType()` causes the
/// DaVinci core to emit `parameters.eventType: "action"` on the resume POST, and to place
/// `payload()` under `parameters.data.formData[id]` (`id` returns `key`). The final
/// envelope shape is:
///
/// - Success: `formData.mobilePairing = ["status": "CLAIMED"]`
/// - Failure: `formData.mobilePairing = ["error": ["code": "<code>", "message": "<message>"]]`,
///   where `<code>` is the numeric native SDK error code as a string (e.g. `"10005"`), or
///   `"INTERNAL_ERROR"` for unexpected failures.
/// - Cancel:  `formData.mobilePairing = ["error": ["code": "USER_CANCELLED", "message": "…"]]`
///
/// ## Lifecycle
/// 1. `CollectorInitializer.registerCollectors()` registers this class with
///    `CollectorFactory.shared` at app startup under the key `"MOBILE_PAIRING"`.
/// 2. When the DaVinci engine receives a node containing a `MOBILE_PAIRING` collector,
///    the factory instantiates this class from the server-provided JSON object.
/// 3. The UI calls `collect()` to perform pairing (show a loading indicator while it is
///    in progress), or `cancel(message:)` if the user abandons the flow.
/// 4. The DaVinci engine reads `payload()` when the node is submitted and includes the
///    outcome in the resume POST body.
///
/// ## Cancellation semantics
/// `cancel(message:)` only changes what `payload()` reports to DaVinci — it does not abort
/// an in-flight native pairing. Any pairing already in flight runs to completion in the
/// background and its outcome is discarded, so the user-cancelled payload is preserved.
/// Use `close()` (invoked by the DaVinci engine when the node is torn down) to cancel the
/// in-flight task itself.
///
/// This class is thread-safe: all shared mutable state is guarded by an `NSLock`, so a
/// late-arriving pairing callback cannot clobber a payload committed by `cancel(message:)`.
///
/// - SeeAlso: `CollectorInitializer`, `MobilePairingClient`
public final class MobilePairingCollector: AnyFieldCollector, Submittable, Closeable, DaVinciAware, @unchecked Sendable {
    /// The collector type string as sent by the server (`"MOBILE_PAIRING"`).
    public private(set) var type: String

    /// The field key sent by the DaVinci server, also used as this collector's `id`.
    /// Defaults to an empty string if the server omits the field.
    public private(set) var key: String

    /// The pairing key supplied by the DaVinci server and passed to `pair` in `collect()`.
    /// Defaults to an empty string if the server omits the field.
    public private(set) var pairingKey: String

    /// Unique identifier for this collector. The DaVinci core uses this value as the
    /// field name under `formData` in the resume POST.
    public var id: String { key }

    /// The DaVinci instance, providing access to configuration and logging. Injected by
    /// the `CollectorFactory` when this collector conforms to `DaVinciAware`.
    public var davinci: DaVinci?

    /// The logger for recording mobile pairing events.
    private var logger: Logger {
        davinci?.config.logger ?? LogManager.logger
    }

    /// The pairing client backing `collect()`.
    private let client: any MobilePairingClient

    /// Guards all mutable state below, so commits from a completed pairing task can
    /// never clobber a cancellation payload committed by `cancel(message:)`.
    private let lock = NSLock()

    /// The pairing outcome to post back to DaVinci, or `nil` if neither `collect()` nor
    /// `cancel(message:)` has completed yet.
    private var outcome: [String: Any]?

    /// The in-flight pairing task, shared by concurrent `collect()` calls.
    private var pairingTask: Task<Void, Error>?

    /// `true` once `cancel(message:)` has been called. Prevents `collect()` from starting
    /// a new pairing and from overwriting the user-cancelled payload.
    private var cancelled = false

    /// `true` once `close()` has been called. Prevents further commits and collect calls.
    private var closed = false

    /// Convenience initializer used by the `CollectorFactory`.
    ///
    /// Creates a collector backed by the default `PingOneMFAPairingClient`.
    ///
    /// - Parameter json: The JSON object for this collector entry from the DaVinci node response.
    public required convenience init(with json: [String: Any]) {
        self.init(with: json, client: PingOneMFAPairingClient())
    }

    /// Initializes this collector from the server-provided JSON object.
    ///
    /// Reads the `key` field (used as the collector's `id`) and the `pairingKey` field
    /// (passed to `pair` during `collect()`).
    ///
    /// - Parameters:
    ///   - json: The JSON object for this collector entry from the DaVinci node response.
    ///   - client: The pairing client to use, injectable for testing.
    init(with json: [String: Any], client: any MobilePairingClient) {
        type = json[Constants.type] as? String ?? ""
        key = json[Constants.key] as? String ?? ""
        pairingKey = json[MobilePairingConstants.pairingKey] as? String ?? ""
        self.client = client
    }

    /// Initializes the field collector with the given value.
    ///
    /// This collector is not re-initializable — the DaVinci server supplies `key` and
    /// `pairingKey` at construction time, so the value is ignored.
    ///
    /// - Parameter value: Ignored.
    public func initialize(with value: Any) {}

    /// Pairs the device with a PingOne MFA account using the `pairingKey` received from
    /// the DaVinci server, then stores the outcome for submission via `payload()`.
    ///
    /// On success, stores `["status": "CLAIMED"]` and returns `.success`.
    /// On failure, stores `["error": ["code": "…", "message": "…"]]` and returns
    /// `.failure` with the underlying error.
    ///
    /// Concurrent calls share a single pairing task: the first call starts the pairing
    /// and later callers await the same result. Once `cancel(message:)` or `close()` has
    /// been called, this method returns `.failure(CancellationError())` without pairing.
    ///
    /// If `cancel(message:)` is called while this method is awaiting a pairing result,
    /// the native outcome is discarded so the user-cancelled payload is preserved. The
    /// `Result` value from the native SDK is still returned to the caller so it can be
    /// logged or forwarded to telemetry.
    ///
    /// - Returns: `.success` if pairing succeeded, or `.failure` with the underlying error.
    public func collect() async -> Result<Void, Error> {
        let task: Task<Void, Error>? = lock.withLock {
            guard !cancelled, !closed else { return nil }
            if let pairingTask {
                return pairingTask
            }

            let task = Task { try await client.pair(pairingKey: pairingKey) }
            pairingTask = task
            return task
        }

        guard let task else { return .failure(CancellationError()) }

        logger.d("MOBILE_PAIRING collector: pairing started")
        do {
            try await task.value
            commit([MobilePairingConstants.status: MobilePairingConstants.claimed])
            return .success(())
        } catch {
            logger.e("MOBILE_PAIRING collector: pairing failed", error: error)
            commit(errorPayload(for: error))
            return .failure(error)
        }
    }

    /// Records a user-initiated cancellation and stores the corresponding error envelope
    /// so it can be posted back to DaVinci via `payload()`.
    ///
    /// Stores `["error": ["code": "USER_CANCELLED", "message": message]]`.
    ///
    /// Note: this does **not** cancel any in-flight `collect()` call — the native PingOne
    /// MFA SDK has no abort API. If `collect()` is currently awaiting a pairing result,
    /// its outcome will be discarded when it resumes so the user-cancelled payload is
    /// preserved.
    ///
    /// - Parameter message: A human-readable description of the cancellation reason.
    ///   Defaults to `"User canceled the pairing flow"`.
    public func cancel(message: String? = nil) {
        lock.withLock {
            cancelled = true
            outcome = errorPayload(code: MobilePairingConstants.userCancelled, message: message ?? MobilePairingConstants.cancellationMessage)
        }
        logger.d("MOBILE_PAIRING collector: pairing cancelled\(message.map { ": \($0)" } ?? "")")
    }

    /// Returns the pairing outcome to be posted back to DaVinci under
    /// `formData[id]`, or `nil` if neither `collect()` nor `cancel(message:)` has
    /// completed yet.
    ///
    /// - Success: `["status": "CLAIMED"]`
    /// - Failure/cancel: `["error": ["code": "…", "message": "…"]]`
    public func payload() -> [String: Any]? {
        lock.withLock { outcome }
    }

    /// Returns `payload()` as an untyped value, per `AnyFieldCollector`.
    public func anyPayload() -> Any? {
        payload()
    }

    /// Returns `"action"` as the DaVinci event type.
    ///
    /// The core inspects this only when `payload()` is non-nil. When set, it becomes
    /// `parameters.eventType` on the resume POST — matching the contract used by
    /// self-submitting SDK Integrator connectors.
    public func eventType() -> String {
        Constants.action
    }

    /// Returns a single `.required` validation error while there is no pairing outcome
    /// yet, and no errors once `collect()` or `cancel(message:)` has committed one.
    public func validate() -> [ValidationError] {
        payload() == nil ? [.required] : []
    }

    /// Tears down this collector: cancels the in-flight pairing task (if any) and clears
    /// the outcome. Called by the DaVinci engine when the node is torn down.
    ///
    /// After this call, `collect()` returns `.failure(CancellationError())`, `payload()`
    /// returns `nil`, and no further commits are accepted.
    public func close() {
        lock.withLock {
            closed = true
            pairingTask?.cancel()
            pairingTask = nil
            outcome = nil
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /// Stores the pairing outcome unless `cancel(message:)` or `close()` has already
    /// committed a payload, in which case that payload takes precedence.
    private func commit(_ outcome: [String: Any]) {
        lock.withLock {
            guard !cancelled, !closed else { return }
            self.outcome = outcome
        }
    }

    /// Maps a pairing failure to a `["code", "message"]` pair for the resume envelope.
    ///
    /// A `PingOneMFAError` yields its first internal error's numeric code as a string
    /// (e.g. `"10005"`) and its raw message (without the `Code=` prefix that
    /// `PingOneMFAError.message` carries); any other error yields `"INTERNAL_ERROR"`
    /// and its localized description. The server-side connector treats any presence of
    /// `error` as the error branch and independently re-verifies pairing status via
    /// `readPairingKey`, so the code is telemetry.
    private func errorPayload(for error: Error) -> [String: Any] {
        if let mfaError = error as? PingOneMFAError {
            let firstError = mfaError.internalErrorsList?.first
            let code = firstError.map { String($0.code) } ?? MobilePairingConstants.internalError
            let message = firstNonEmpty(firstError?.message, mfaError.message, MobilePairingConstants.pairingFailed)
            return errorPayload(code: code, message: message)
        }

        return errorPayload(
            code: MobilePairingConstants.internalError,
            message: firstNonEmpty(error.localizedDescription, MobilePairingConstants.pairingFailed)
        )
    }

    /// Builds an error payload of the form `["error": ["code": code, "message": message]]`.
    private func errorPayload(code: String, message: String) -> [String: Any] {
        [Constants.error: [Constants.code: code, Constants.message: message]]
    }

    /// Returns the first non-empty, non-nil string in `values`, falling back to
    /// `MobilePairingConstants.pairingFailed`.
    private func firstNonEmpty(_ values: String?...) -> String {
        values.compactMap { $0 }.first { !$0.isEmpty } ?? MobilePairingConstants.pairingFailed
    }
}
