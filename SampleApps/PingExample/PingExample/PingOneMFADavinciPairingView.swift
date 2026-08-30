//
//  PingOneMFADavinciPairingView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import SwiftUI
import PingDavinci
import PingOneMFA
import PingOrchestrate

struct PingOneMFADavinciPairingView: View {
    @Binding var path: [MenuItem]
    @StateObject private var davinciViewModel = DavinciViewModel()
    @StateObject private var validationViewModel = ValidationViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    switch davinciViewModel.state.node {
                    case let continueNode as ContinueNode:
                        pairingStep(continueNode)
                    case let failureNode as FailureNode:
                        let apiError = failureNode.cause as? ApiError
                        switch apiError {
                        case .error(_, _, let message):
                            ErrorView(title: "DaVinci Pairing Error", message: message)
                        default:
                            ErrorView(title: "DaVinci Pairing Error", message: "unknown error")
                        }
                    case let errorNode as ErrorNode:
                        ErrorNodeView(node: errorNode)
                        if let nextNode = errorNode.continueNode {
                            pairingStep(nextNode)
                        }
                    default:
                        EmptyView()
                    }
                }
            }

            if davinciViewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2)
                    .tint(.themeButtonBackground)
            }
        }
        .navigationTitle("DaVinci Pairing")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Renders a flow step. MobilePairing submits finish the flow: the returned node is
    /// ignored (matching Android) and the screen returns to the main menu. Ordinary
    /// collectors progress the flow normally.
    @ViewBuilder
    private func pairingStep(_ node: ContinueNode) -> some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
            ContinueNodeView(
                continueNode: node,
                onNodeUpdated: { davinciViewModel.refresh() },
                onStart: { Task { await davinciViewModel.startDavinci() } },
                onNext: { isSubmit in
                    Task { await handleNext(node: node, isSubmit: isSubmit) }
                }
            )
            .environmentObject(validationViewModel)
        }
    }

    private func handleNext(node: ContinueNode, isSubmit: Bool) async {
        validationViewModel.shouldValidate = isSubmit
            && davinciViewModel.shouldValidate(node: node)
        guard !validationViewModel.shouldValidate else { return }

        // On a pairing node, onNext(false) is the MobilePairing collector finishing
        // (success Continue, failure Continue, or Cancel): the fallback Next button is
        // suppressed when a MobilePairing collector is present, so no other collector
        // submits with isSubmit == false on this node.
        let finishesPairing = !isSubmit
            && node.collectors.contains(where: { $0 is MobilePairingCollector })

        await davinciViewModel.next(node: node)
        if finishesPairing, path.last == .pingOneMFADavinciPairing {
            path.removeLast()
        }
    }
}
