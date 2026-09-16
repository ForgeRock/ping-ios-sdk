// 
//  StorageView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import SwiftUI

struct StorageView: View {
    let menuItem: MenuItem
    var storageViewModel = StorageViewModel()
    var body: some View {
        Text("This View is for testing Storage functionality.\nPlease check the Console Logs")
            .pingScreenTitle()
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pingScreenBackground()
            .navigationTitle(menuItem.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear() {
                Task {
                    await storageViewModel.setupMemoryStorage()
                    await storageViewModel.setupKeychainStorage()
                }
            }
    }
}
