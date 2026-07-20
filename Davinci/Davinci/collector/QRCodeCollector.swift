//
//  QRCodeCollector.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinciPlugin

/// A display-only collector that provides a QR code image in DaVinci authentication flows.
///
/// The server sends the image as a data URI in the `content` field, e.g.:
/// `"data:image/png;base64,iVBORw0KGgo..."`
///
/// The `imageData` property exposes the decoded `Data` after stripping the data URI prefix,
/// allowing the UI layer to render it as a `UIImage` or `SwiftUI.Image`.
///
/// The `fallbackText` property carries an alternative string (e.g. a manual entry code or
/// a URL) to display if the QR code cannot be rendered or scanned.
///
/// This collector does not participate in form submission — `payload()` always returns `nil`.
public class QRCodeCollector: Collector, @unchecked Sendable {

    // MARK: - Collector

    public var id: String { key }

    // MARK: - Properties

    /// The key identifying this collector within the form.
    public private(set) var key: String = ""

    /// The decoded QR code image bytes, or `nil` if the `content` field was absent or invalid.
    ///
    /// Use `UIImage(data:)` or `Image(uiImage:)` in the UI layer to render this as an image.
    public private(set) var imageData: Data?

    /// Alternative text to display when the QR code cannot be rendered or scanned.
    /// Typically a URL or manual entry code. Empty string if not provided by the server.
    public private(set) var fallbackText: String = ""

    // MARK: - Init

    public required init(with json: [String: Any]) {
        key = json[Constants.key] as? String ?? ""
        fallbackText = json[Constants.fallbackText] as? String ?? ""
        // The server sends the image as a data URI: "data:image/png;base64,<data>"
        // Strip everything up to and including "base64," before decoding, matching Android.
        if let content = json[Constants.content] as? String {
            let base64 = content.components(separatedBy: Constants.base64Separator).last ?? ""
            imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
        }
    }

    // MARK: - Collector protocol

    /// No-op: this collector is display-only and does not accept user input.
    public func initialize(with value: Any) {}

    /// Returns `nil` — QR code collectors are display-only and do not submit a value.
    public func payload() -> Never? {
        return nil
    }
}
