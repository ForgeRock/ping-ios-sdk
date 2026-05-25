//
//  DaVinci+Device.swift
//  PingDavinci
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Options used to supply caller inputs before the DaVinci flow begins.
///
/// Currently used for the RFC 8628 Device Authorization Grant (approving-device side).
/// When `verificationUriComplete` is set, `OidcModule.setup.start` extracts the `user_code`
/// query parameter from the URL and includes it in the outgoing authorization request so the
/// authorization server can approve the requesting device.
public struct DaVinciOptions: Sendable {
    /// The `verificationUriComplete` URL from an RFC 8628 device authorization response.
    ///
    /// When set, the DaVinci `OidcModule` will extract the `user_code` query parameter from
    /// this URL and include it in the device-flow verification request, approving the
    /// requesting device.
    public var verificationUriComplete: URL? = nil
}

public extension DaVinci {

    /// Starts the DaVinci flow after applying caller-supplied device-flow inputs.
    ///
    /// Use this overload when the current device is acting as the approving device in an
    /// RFC 8628 Device Authorization Grant flow:
    ///
    /// ```swift
    /// let node = await daVinci.start { options in
    ///     options.verificationUriComplete = URL(string: verificationUriCompleteString)
    /// }
    /// ```
    ///
    /// The supplied URL is stored in `sharedContext` under
    /// `SharedContext.Keys.daVinciVerificationUriCompleteKey` and consumed during the
    /// `start` phase of `OidcModule`. Passing `nil` clears any previously stored value,
    /// so a subsequent plain `start()` does not include a `user_code` parameter.
    ///
    /// - Parameter configure: Closure that populates a `DaVinciOptions` with caller inputs.
    /// - Returns: The first `Node` produced by the DaVinci flow.
    func start(_ configure: @Sendable (inout DaVinciOptions) -> Void) async -> Node {
        var options = DaVinciOptions()
        configure(&options)
        
        if let uri = options.verificationUriComplete {
            sharedContext.set(key: SharedContext.Keys.daVinciVerificationUriCompleteKey, value: uri.absoluteString)
        } else {
            _ = sharedContext.removeValue(forKey: SharedContext.Keys.daVinciVerificationUriCompleteKey)
        }
        
        return await start()
    }
}
