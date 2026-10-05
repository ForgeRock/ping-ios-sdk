//
//  CustomUserKeySelector.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import UIKit
import PingBinding

/// A custom user key selector that presents a SwiftUI view for key selection.
class CustomUserKeySelector: UserKeySelector {
    
    func selectKey(userKeys: [UserKey], prompt: Prompt) async -> UserKey? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topViewController = self.getTopViewController() else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let selectorView = UserKeySelectorView(
                    userKeys: userKeys,
                    prompt: prompt
                ) { selectedKey in
                    topViewController.dismiss(animated: true) {
                        continuation.resume(returning: selectedKey)
                    }
                }
                
                let hostingController = UIHostingController(rootView: selectorView)
                hostingController.modalPresentationStyle = .formSheet
                topViewController.present(hostingController, animated: true)
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
}

/// A SwiftUI view for selecting a user key from multiple options.
struct UserKeySelectorView: View {
    let userKeys: [UserKey]
    let prompt: Prompt
    let completion: (UserKey?) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: PingTheme.Spacing.large) {
                if !prompt.description.isEmpty {
                    Text(prompt.description)
                        .pingBodySecondary()
                        .multilineTextAlignment(.center)
                }
                
                List(userKeys, id: \.id) { userKey in
                    Button(action: {
                        completion(userKey)
                    }) {
                        VStack(alignment: .leading, spacing: PingTheme.Spacing.xSmall) {
                            if !userKey.username.isEmpty {
                                Text(userKey.username)
                                    .pingSectionHeader()
                            }
                            if !userKey.userId.isEmpty {
                                Text("User ID: \(userKey.userId)")
                                    .pingCaptionText()
                            }
                            Text("Auth: \(userKey.authType.rawValue)")
                                .pingCaptionText()
                        }
                        .padding(.vertical, PingTheme.Spacing.xSmall)
                    }
                }
            }
            .navigationTitle(prompt.title.isEmpty ? "Select Device Key" : prompt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        completion(nil)
                    }
                }
            }
        }
    }
}
