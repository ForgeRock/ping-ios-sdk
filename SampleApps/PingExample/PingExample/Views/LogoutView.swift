// 
//  LogoutView.swift
//  PingExample
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct LogoutView: View {
    
    @Binding var path: [String]
    
    @StateObject private var viewmodel = LogoutViewModel()
    
    var body: some View {
        
        Text("Logout")
            .font(.title)
            .navigationBarTitle("Logout", displayMode: .inline)
        
        NextButton(title: "Procced to logout") {
            Task {
                await viewmodel.logout()
                path.removeLast()
            }
        }
        
    }
}
