// 
//  JourneyView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import SwiftUI
import PingOrchestrate
import PingJourney

struct JourneyView: View {
    /// The view model that manages the Davinci flow logic.
    @StateObject private var journeyViewModel = JourneyViewModel()
    /// A binding to the navigation stack path.
    @Binding var path: [String]
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    Spacer()
                    // Handle different types of nodes in the Journey.
                    switch journeyViewModel.state.node {
                    case let continueNode as ContinueNode:
                        // Display the callback view for the next node.
                        CallbackView(journeyViewModel: journeyViewModel, node: continueNode)
                    case let errorNode as ErrorNode:
                        // Handle server-side errors (e.g., invalid credentials)
                        // Display error to the user
                        ErrorNodeView(node: errorNode)
                        if let nextNode = errorNode.continueNode {
                            CallbackView(journeyViewModel: journeyViewModel, node: nextNode)
                        }
                    case let failureNode as FailureNode:
                        ErrorView(message: failureNode.cause.localizedDescription)
                    case is SuccessNode:
                        // Authentication successful, retrieve the session
                        VStack{}.onAppear {
                            path.removeLast()
                            path.append("Token")
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

/// A view for displaying the current step in the Davinci flow.
struct CallbackView: View {
    /// The Journey view model managing the flow.
    @ObservedObject var journeyViewModel: JourneyViewModel
    /// The next node to process in the flow.
    public var node: ContinueNode
    
    var body: some View {
        VStack {
            Image("Logo").resizable().scaledToFill().frame(width: 100, height: 100)
            
            JourneyNodeView(continueNode: node,
                             onNodeUpdated:  { journeyViewModel.refresh() },
                             onStart: { Task { await journeyViewModel.startJourney() }},
                             onNext: { isSubmit in Task {
                await journeyViewModel.next(node: node)
            }})
        }
        
    }
}

struct JourneyNodeView: View {
    var continueNode: ContinueNode
    let onNodeUpdated: () -> Void
    let onStart: () -> Void
    let onNext: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            ForEach(continueNode.callbacks , id: \.id) { callback in
                switch callback {
                case is NameCallback:
                    if let nameCallback = callback as? NameCallback {
                        NameCallbackView(field: nameCallback, onNodeUpdated: onNodeUpdated)
                    }
                case is PasswordCallback:
                    if let passwordCallback = callback as? PasswordCallback {
                        PasswordCallbackView(field: passwordCallback, onNodeUpdated: onNodeUpdated)
                    }
                default:
                    EmptyView()
                }
            }
            
            Button(action: { onNext(false) }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.themeButtonBackground)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 16)
        }
        .padding()
    }
}
