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
    @StateObject private var davinciViewModel = DavinciViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    switch davinciViewModel.state.node {
                    case let continueNode as ContinueNode:
                        ConnectorView(davinciViewModel: davinciViewModel, node: continueNode)
                    case is SuccessNode:
                        VStack {}.onAppear {
                            path.removeLast()
                            path.append(.davinciToken)
                        }
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
                            ConnectorView(davinciViewModel: davinciViewModel, node: nextNode)
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
}
