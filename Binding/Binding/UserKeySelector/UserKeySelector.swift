//
//  UserKeySelector.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// A protocol for collecting user key selection when multiple keys are available.
/// Conforming types can provide custom UI for selecting from multiple bound device keys.
public protocol UserKeySelector: Sendable {
    /// Prompts the user to select a key from the available options.
    /// - Parameters:
    ///   - userKeys: An array of available user keys to choose from.
    ///   - prompt: The prompt information to display to the user.
    /// - Returns: The selected UserKey, or nil if the user cancels.
    func selectKey(userKeys: [UserKey], prompt: Prompt) async -> UserKey?
}
