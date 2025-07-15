//
//  OidcLoginView.swift
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

struct OidcLoginView: View {
    /// The view model that manages the Journey flow logic.
    @StateObject private var oidcLoginViewModel = OidcLoginViewModel()
    /// A binding to the navigation stack path.
    @Binding var path: [String]
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    Spacer()
                    // Handle different types of nodes in the Journey.
                    switch oidcLoginViewModel.state.node {
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
