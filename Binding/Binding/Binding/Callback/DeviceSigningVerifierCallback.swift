
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

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
    
    private enum CodingKeys: String, CodingKey {
        case jws, clientError
    }
    
    private enum CodingKeys: String, CodingKey {
        case jws, clientError
    }
    
    private enum CodingKeys: String, CodingKey {
        case jws, clientError
    }
    
    override public func initValue(name: String, value: Any) {
        switch name {
        case Constants.userId:
            userId = value as? String
        case Constants.challenge:
            challenge = value as? String ?? ""
        case Constants.title:
            title = value as? String ?? ""
        case Constants.subtitle:
            subtitle = value as? String ?? ""
        case Constants.description:
            description = value as? String ?? ""
        case Constants.timeout:
            timeout = value as? Int ?? 30
        default:
            break
        }
    }
    
    /// Sets the JWS value in the callback.
    /// - Parameter jws: The JWS to be set.
    public func setJws(_ jws: String) {
        self.input(jws, key: CodingKeys.jws.rawValue)
    }
    
    /// Sets the client error value in the callback.
    /// - Parameter clientError: The client error to be set.
    public func setClientError(_ clientError: String) {
        self.input(clientError, key: CodingKeys.clientError.rawValue)
    }
}
