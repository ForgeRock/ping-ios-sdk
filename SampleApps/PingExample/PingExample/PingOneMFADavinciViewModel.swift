//
//  PingOneMFADavinciViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import Foundation
import PingDavinciPlugin
import PingExternalIdP
import PingOneMFA
import PingOrchestrate

@MainActor
final class PingOneMFADavinciViewModel: ObservableObject {
    @Published var state = DavinciState()
    @Published var isLoading = false
    @Published var pairingComplete = false
    @Published var errorMessage: String?

    init() {
        Task { await start() }
    }

    func start() async {
        errorMessage = nil
        pairingComplete = false
        isLoading = true
        defer { isLoading = false }

        do {
            try await ConfigurationManager.shared.initializePingOneMFAClient()
        } catch is CancellationError {
            return
        } catch {
            state = DavinciState()
            errorMessage = error.localizedDescription
            return
        }

        guard let davinci = ConfigurationManager.shared.pingOneMFADavinci else {
            state = DavinciState()
            errorMessage = "PingOne MFA DaVinci not configured"
            return
        }

        await CollectorInitializer.registerCollectorsAsync()
        guard !Task.isCancelled else { return }
        state = DavinciState(node: await davinci.start())
    }

    /// Submits a MobilePairing result and completes the pairing transaction.
    /// The returned node is intentionally ignored to match Android behavior.
    func next(current: ContinueNode) async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await submit { await current.next() }
            pairingComplete = true
        } catch is CancellationError {
            // Task cancellation is navigation/lifecycle control, not a pairing failure.
        } catch {
            state = DavinciState()
            errorMessage = error.localizedDescription
        }
    }

    /// Progresses ordinary collectors that appear before the MobilePairing collector.
    func progress(current: ContinueNode) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let next = try await submit { await current.next() }
            state = DavinciState(node: next)
        } catch is CancellationError {
            // Task cancellation is navigation/lifecycle control, not a flow failure.
        } catch {
            state = DavinciState()
            errorMessage = error.localizedDescription
        }
    }

    func shouldValidate(current: ContinueNode) -> Bool {
        var shouldValidate = false
        for collector in current.collectors {
            if let socialCollector = collector as? IdpCollector,
               socialCollector.resumeRequest != nil {
                return false
            }
            if let collector = collector as? any Validator,
               !collector.validate().isEmpty {
                shouldValidate = true
            }
        }
        return shouldValidate
    }

    func refresh() {
        state = DavinciState(node: state.node)
    }

    private func submit(_ operation: () async throws -> Node) async throws -> Node {
        let next = try await operation()
        try Task.checkCancellation()
        return next
    }
}
