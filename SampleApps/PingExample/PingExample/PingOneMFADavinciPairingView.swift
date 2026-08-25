//
//  PingOneMFADavinciPairingView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import SwiftUI
import PingDavinci
import PingOrchestrate

struct PingOneMFADavinciPairingView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PingOneMFADavinciViewModel()
    @StateObject private var validationViewModel = ValidationViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorView(title: "DaVinci Pairing Error", message: errorMessage)
                    } else {
                        switch viewModel.state.node {
                        case let continueNode as ContinueNode:
                            Image("Logo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                            ContinueNodeView(
                                continueNode: continueNode,
                                onNodeUpdated: viewModel.refresh,
                                onStart: { Task { await viewModel.start() } },
                                onNext: { isSubmit in
                                    Task {
                                        validationViewModel.shouldValidate = isSubmit
                                            && viewModel.shouldValidate(current: continueNode)
                                        if !validationViewModel.shouldValidate {
                                            await viewModel.progress(current: continueNode)
                                        }
                                    }
                                },
                                onMobilePairingNext: {
                                    await viewModel.next(current: continueNode)
                                }
                            )
                            .environmentObject(validationViewModel)
                        case let failureNode as FailureNode:
                            ErrorView(
                                title: "DaVinci Pairing Error",
                                message: failureNode.cause.localizedDescription
                            )
                        case let errorNode as ErrorNode:
                            ErrorNodeView(node: errorNode)
                        default:
                            EmptyView()
                        }
                    }
                }
            }

            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2)
                    .tint(.themeButtonBackground)
            }
        }
        .navigationTitle("DaVinci Pairing")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.pairingComplete) { complete in
            if complete, path.last == .pingOneMFADavinciPairing {
                path.removeLast()
            }
        }
    }
}
