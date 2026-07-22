//
//  MetadataCollector.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingDavinciPlugin

/// A collector that handles a DaVinci SDK Integrator connector's pause step
/// of type `METADATA`.
///
/// The connector pauses the flow and hands an opaque JSON payload to the SDK
/// client. The app is expected to invoke on-device work (a third-party SDK,
/// risk engine, payment SDK, etc.), then call `setResult(_:)` or
/// `setError(code:message:)` before continuing the flow.
///
/// ### Example server payload
/// ```json
/// {
///   "type": "METADATA",
///   "key": "sdkMetadata",
///   "payload": { "sdk": "PROTECT", "action": "INITIALIZE" }
/// }
/// ```
///
/// ### Usage
/// 1. Read `metadata` to determine which SDK operation to invoke.
/// 2. Call `setResult(_:)` with the SDK's result, or `setError(...)` to
///    signal the connector's client-error branch.
/// 3. Continue the flow as usual — the SDK serialises the result and POSTs
///    the resume envelope to DaVinci.
public class MetadataCollector: AnyFieldCollector, Submittable, Validator, Closeable, @unchecked Sendable {

    public var id: String { key }

    /// The form field key. Per spec always `"sdkMetadata"`.
    public private(set) var key: String = ""

    /// The collector type. Always `"METADATA"`.
    public private(set) var type: String = ""

    /// The opaque metadata payload delivered by the DaVinci connector.
    ///
    /// Consumers interpret the shape themselves; the SDK does not validate or
    /// introspect the content. Maps to the `payload` field of the `METADATA`
    /// component.
    public private(set) var metadata: [String: Any] = [:]

    /// App-supplied result to POST back to DaVinci.
    ///
    /// `nil` until the app calls `setResult(_:)` or `setError(...)`, after
    /// which the collector is considered ready to submit.
    private var result: [String: Any]?

    /// Creates a collector from a raw JSON component received from DaVinci.
    ///
    /// - Parameter json: The parsed JSON object for this `METADATA` component.
    public required init(with json: [String: Any]) {
        key = json[Constants.key] as? String ?? ""
        type = json[Constants.type] as? String ?? ""
        metadata = json[Constants.payload] as? [String: Any] ?? [:]
    }

    /// Sets the result that the SDK will include as `formData["sdkMetadata"]`
    /// when the flow resumes.
    ///
    /// Call this with whatever data the on-device SDK returned. Replaces any
    /// previously set result.
    ///
    /// - Parameter result: A dictionary representing the SDK's outcome.
    public func setResult(_ result: [String: Any]) {
        self.result = result
    }

    /// Signals the connector's client-error branch by setting a structured
    /// error result.
    ///
    /// The SDK will POST a result of the form:
    /// ```json
    /// { "error": { "code": "...", "message": "..." } }
    /// ```
    /// The server-side connector reads this and routes the flow to the
    /// false/error branch.
    ///
    /// - Parameters:
    ///   - code: A short error code string (e.g. `"USER_CANCELLED"`).
    ///   - message: A human-readable description of the error.
    public func setError(code: String, message: String) {
        self.result = [Constants.error: [
            Constants.code: code,
            Constants.message: message
        ]]
    }

    /// Intentionally a no-op.
    ///
    /// `MetadataCollector` result must always originate from an on-device SDK
    /// call via `setResult(_:)` or `setError(...)`. Accepting server-echoed
    /// `formData` values here would bypass the required on-device invocation
    /// (e.g. risk evaluation, payment SDK) by silently pre-satisfying
    /// `validate()` with stale data.
    public func initialize(with value: Any) {}

    /// Returns the result dictionary to include in the `formData` POST body,
    /// or `nil` if no result has been set yet.
    public func payload() -> [String: Any]? {
        return result
    }

    /// Returns the result as `Any?`, suitable for use in heterogeneous
    /// `formData` dictionaries. Equivalent to `payload()` for this collector.
    public func anyPayload() -> Any? {
        return result
    }

    /// The `eventType` value DaVinci expects on resume. Always `"action"`.
    public func eventType() -> String {
        return Constants.action
    }

    /// Returns a `.required` validation error when no result has been set,
    /// or an empty array once `setResult(_:)` or `setError(...)` has been called.
    ///
    /// - Note: The SDK does not call this automatically. It is the integrating
    ///   app's responsibility to invoke `validate()` before continuing the flow
    ///   and handle the `.required` error if no result has been set.
    public func validate() -> [ValidationError] {
        return result == nil ? [.required] : []
    }

    /// Clears the result, returning the collector to its initial unset state.
    public func close() {
        result = nil
    }
}
