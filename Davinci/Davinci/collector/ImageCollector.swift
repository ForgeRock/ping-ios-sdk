//
//  ImageCollector.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinciPlugin

/// A display-only collector that surfaces an image in DaVinci authentication flows.
///
/// The server sends the image as a URL in the `imageUrl` field. An optional
/// `hyperlinkUrl` field may be present to provide a tappable link associated
/// with the image.
///
/// This collector does not participate in form submission — `payload()` always returns `nil`.
public class ImageCollector: Collector, @unchecked Sendable {

    // MARK: - Collector

    public var id: String { key }

    // MARK: - Properties

    /// The key identifying this collector within the form.
    public private(set) var key: String = ""

    /// The URL string of the image to display. Empty string if not provided by the server.
    public private(set) var imageUrl: String = ""

    /// A description or alt text for the image. Empty string if not provided by the server.
    public private(set) var description: String = ""

    /// An optional hyperlink URL to display below the image. `nil` if not provided by the server.
    public private(set) var hyperlinkUrl: String?

    // MARK: - Init

    public required init(with json: [String: Any]) {
        key = json[Constants.key] as? String ?? ""
        imageUrl = json[Constants.imageUrl] as? String ?? ""
        description = json[Constants.description] as? String ?? ""
        hyperlinkUrl = json[Constants.hyperlinkUrl] as? String
    }

    // MARK: - Collector protocol

    /// No-op: this collector is display-only and does not accept user input.
    public func initialize(with value: Any) {}

    /// Returns `nil` — image collectors are display-only and do not submit a value.
    public func payload() -> Never? {
        return nil
    }
}
