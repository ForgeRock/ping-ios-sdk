//
//  AccessToken.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct AccessTokenView: View {
    
    @StateObject var accessToken = TokenViewModel()
    
    var body: some View {
        VStack {
            ScrollView {
                Text($accessToken.accessToken.wrappedValue)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal)
                  .navigationTitle("AccessToken")
            }
        }
    }
}

struct UserInfoView: View {
    
    @StateObject var userInfoViewModel = UserInfoViewModel()
    
    var body: some View {
        ScrollView {
            Text($userInfoViewModel.userInfo.wrappedValue)
              .foregroundStyle(.secondary)
              .padding(.horizontal)
              .navigationTitle("User Info")
        }
    }
}
