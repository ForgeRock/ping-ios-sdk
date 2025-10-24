/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// A struct representing the prompt to be displayed to the user.
public struct Prompt {
    /// The title of the prompt.
    public let title: String
    /// The subtitle of the prompt.
    public let subtitle: String
    /// The description of the prompt.
    public let description: String
    
    /// Initializes a new `Prompt`.
    /// - Parameters:
    ///   - title: The title of the prompt.
    ///   - subtitle: The subtitle of the prompt.
    ///   - description: The description of the prompt.
    public init(title: String, subtitle: String, description: String) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
    }
}
