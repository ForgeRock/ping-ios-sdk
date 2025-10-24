
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import PingJourney

/// A Journey callback for handling device signing verification.
import Foundation
import PingJourney

/// A Journey callback for handling device signing verification.
public class DeviceSigningVerifierCallback: AbstractCallback {
    
    /// The user ID for the signing.
    public var userId: String?
    /// The challenge to be signed.
    public var challenge: String = ""
    /// The title to be displayed in the UI.
    public var title: String = ""
    /// The subtitle to be displayed in the UI.
    public var subtitle: String = ""
    /// The description to be displayed in the UI.
    public var description: String = ""
    /// The timeout for the operation.
    public var timeout: Int = 30
    
    public required init(json: [String : Any]) throws {
        try super.init(json: json)
        userId = getOutputValue(key: Constants.userId)
        challenge = getOutputValue(key: Constants.challenge) ?? ""
        title = getOutputValue(key: Constants.title) ?? ""
        subtitle = getOutputValue(key: Constants.subtitle) ?? ""
        description = getOutputValue(key: Constants.description) ?? ""
        timeout = getOutputValue(key: Constants.timeout) ?? 30
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    /// Sets the JWS value in the callback.
    /// - Parameter jws: The JWS to be set.
    public func setJws(_ jws: String) {
        self.setInputValue(jws, for: Constants.jws)
    }
    
    /// Sets the client error value in the callback.
    /// - Parameter clientError: The client error to be set.
    public func setClientError(_ clientError: String) {
        self.setInputValue(clientError, for: Constants.clientError)
    }
}
