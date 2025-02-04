//
//  BrowserHandler.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation
import PingBrowser
import PingOrchestrate

class BrowserHandler: IdpHandler {
    var tokenType: String = ""
    
    func authorize(idpClient: IdpClient) async throws -> Request {
        guard let continueURLString = idpClient.continueUrl, let continueUrl = URL(string: continueURLString) else {
            throw IdpExceptions.illegalArgumentException(message: "continueUrl not found")
            
        }
        
        do {
            let result = try await BrowserLauncher.currentBrowser?.launch(url: continueUrl, callbackURLScheme: "")
        } catch {
            throw IdpExceptions.illegalStateException(message: "BrowserLauncher failed")
        }
        
        throw IdpExceptions.unsupportedIdpException(message: "BrowserHandler is not implemented yet")
    }
    
    
}
