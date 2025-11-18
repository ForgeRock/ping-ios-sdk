//
//  DefaultUserKeySelector.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(UIKit)
import UIKit

/// The default implementation of `UserKeySelector` that uses a system alert to prompt the user.
public class DefaultUserKeySelector: UserKeySelector, @unchecked Sendable {
    
    public init() {}
    
    /// Prompts the user to select a key from the available options using a system alert.
    /// - Parameters:
    ///   - userKeys: An array of available user keys to choose from.
    ///   - prompt: The prompt information to display to the user.
    /// - Returns: The selected UserKey, or nil if the user cancels.
    public func selectKey(userKeys: [UserKey], prompt: Prompt) async -> UserKey? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topViewController = self.getTopViewController() else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let alert = UIAlertController(
                    title: prompt.title.isEmpty ? "Select Device Key" : prompt.title,
                    message: prompt.description.isEmpty ? "Multiple device keys are available. Please select one to continue." : prompt.description,
                    preferredStyle: .actionSheet
                )
                
                for userKey in userKeys {
                    let action = UIAlertAction(title: self.formatKeyOption(userKey), style: .default) { _ in
                        continuation.resume(returning: userKey)
                    }
                    alert.addAction(action)
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: nil)
                }
                alert.addAction(cancelAction)
                
                topViewController.present(alert, animated: true)
            }
        }
    }
    
    /// Formats a user key option for display.
    /// - Parameter userKey: The user key to format.
    /// - Returns: A formatted string representing the key.
    private func formatKeyOption(_ userKey: UserKey) -> String {
        if !userKey.username.isEmpty {
            return userKey.username
        } else if !userKey.userId.isEmpty {
            return "User: \(userKey.userId)"
        } else {
            return "Key: \(userKey.id)"
        }
    }
    
    /// Gets the top-most view controller in the view hierarchy.
    /// - Returns: The top view controller, or nil if none is found.
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
#endif
