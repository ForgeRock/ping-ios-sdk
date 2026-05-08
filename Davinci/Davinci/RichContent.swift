//
//  RichContent.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// A replacement entry within rich content.
/// - `value`: The display text for the replacement.
/// - `href`: The URL for link-type replacements.
/// - `type`: The type of replacement (e.g., "link").
/// - `target`: The link target (e.g., "_self", "_blank").
public struct RichContentReplacement: Sendable {
    public let value: String
    public let href: String?
    public let type: String
    public let target: String?
}

/// Rich content for a form field, enabling template-based text with embedded links.
/// - `content`: A template string with `{{placeholder}}` tokens.
/// - `replacements`: A dictionary mapping placeholder keys to their replacement details.
public struct RichContent: Sendable {
    public let content: String
    public let replacements: [String: RichContentReplacement]
}
