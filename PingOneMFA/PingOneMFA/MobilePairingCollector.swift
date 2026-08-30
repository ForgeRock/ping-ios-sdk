//
//  MobilePairingCollector.swift
//  PingOneMFA
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import Foundation
import PingDavinciPlugin
import PingOrchestrate

enum MobilePairingConstants {
    static let type = "MOBILE_PAIRING"
    static let pairingKey = "pairingKey"
    static let status = "status"
    static let claimed = "CLAIMED"
    static let internalError = "INTERNAL_ERROR"
    static let userCancelled = "USER_CANCELLED"
    static let pairingFailed = "Pairing failed"
    static let cancellationMessage = "User canceled the pairing flow"
}

public final class MobilePairingCollector: AnyFieldCollector, Submittable, Closeable, @unchecked Sendable {
    public private(set) var type: String
    public private(set) var key: String
    public private(set) var pairingKey: String
    public var id: String { key }

    private let client: any MobilePairingClient
    private let lock = NSLock()
    private var outcome: [String: Any]?
    private var pairingTask: Task<Void, Error>?
    private var cancelled = false
    private var closed = false

    public required convenience init(with json: [String: Any]) {
        self.init(with: json, client: PingOneMFAPairingClient())
    }

    init(with json: [String: Any], client: any MobilePairingClient) {
        type = json[Constants.type] as? String ?? ""
        key = json[Constants.key] as? String ?? ""
        pairingKey = json[MobilePairingConstants.pairingKey] as? String ?? ""
        self.client = client
    }

    public func initialize(with value: Any) {}

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

        do {
            try await task.value
            commit([MobilePairingConstants.status: MobilePairingConstants.claimed])
            return .success(())
        } catch {
            commit(errorPayload(for: error))
            return .failure(error)
        }
    }

    public func cancel(message: String = "User canceled the pairing flow") {
        lock.withLock {
            cancelled = true
            outcome = errorPayload(code: MobilePairingConstants.userCancelled, message: message)
        }
    }

    public func payload() -> [String: Any]? {
        lock.withLock { outcome }
    }

    public func anyPayload() -> Any? {
        payload()
    }

    public func eventType() -> String {
        Constants.action
    }

    public func validate() -> [ValidationError] {
        payload() == nil ? [.required] : []
    }

    public func close() {
        lock.withLock {
            closed = true
            pairingTask?.cancel()
            pairingTask = nil
            outcome = nil
        }
    }

    private func commit(_ outcome: [String: Any]) {
        lock.withLock {
            guard !cancelled, !closed else { return }
            self.outcome = outcome
        }
    }

    private func errorPayload(for error: Error) -> [String: Any] {
        if let mfaError = error as? PingOneMFAError {
            let firstError = mfaError.internalErrorsList?.first
            let code = firstError.map { String($0.code) } ?? MobilePairingConstants.internalError
            let message = firstNonEmpty(mfaError.message, firstError?.message, MobilePairingConstants.pairingFailed)
            return errorPayload(code: code, message: message)
        }

        return errorPayload(
            code: MobilePairingConstants.internalError,
            message: firstNonEmpty(error.localizedDescription, MobilePairingConstants.pairingFailed)
        )
    }

    private func errorPayload(code: String, message: String) -> [String: Any] {
        [Constants.error: [Constants.code: code, Constants.message: message]]
    }

    private func firstNonEmpty(_ values: String?...) -> String {
        values.compactMap { $0 }.first { !$0.isEmpty } ?? MobilePairingConstants.pairingFailed
    }
}
