//
//  AccessTokenView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

/// A view that displays the access token.
struct AccessTokenView: View {
    /// A state object that manages the access token data.
    @StateObject var accessTokenViewModel: AccessTokenViewModel
    
    var body: some View {
        VStack {
            ScrollView {
                Text($accessTokenViewModel.token.wrappedValue)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .navigationTitle("Access Token")
            }
        }
    }
}
