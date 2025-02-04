//
//  GoogleHandler.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

class GoogleHandler: IdpHandler {
    
    //  MARK: - Properties
    
    /// Credentials type for Google credentials
    var tokenType: String = "id_token"
    
    func authorize(idpClient: IdpClient) async throws -> Request {
        throw IdpExceptions.unsupportedIdpException(message: "Facebook is not implemented yet")
    }
    
    
}
