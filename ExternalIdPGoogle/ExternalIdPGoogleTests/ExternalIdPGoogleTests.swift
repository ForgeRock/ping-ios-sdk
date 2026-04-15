// 
//  ExternalIdPGoogleTests.swift
//  ExternalIdPGoogleTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingExternalIdPGoogle
@testable import PingExternalIdP
@testable import PingNetwork
@testable import PingDavinciPlugin

final class ExternalIdPGoogleTests: XCTestCase {

    override func setUpWithError() throws {
        IdpCollector.registerCollector()
    }
    
    // MARK: - IdpCollector Tests
        
    @MainActor func testidpCollectorParsingGoogle() throws {
            let jsonObject: [String: Any] = [
                "idpId" : "539aedb9bb8617786b7343eb83439e51",
                "idpType" : "GOOGLE",
                "type" : "SOCIAL_LOGIN_BUTTON",
                "label" : "Sign in with Google",
                "idpEnabled" : true,
                "links" : [
                  "authenticate" : [
                    "href" : "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/539aedb9bb8617786b7343eb83439e51/capabilities/loginFirstFactor?interactionId=009ddda1-0c65-493a-bf77-2d270a495280&interactionToken=1deb3916f674f28004e642ff53f91e4474b1561b1281e62a9a15133f118795ddfbaf3889eea8e7cbbe689b1c7f419b1306af9b0b4432a809b3a983f2dee7406857502a2592df3d2adbd88103fa1d078bfe5480f66c84b71c2d8fce065284a5708e8194689f92f4bbdc66bd683c6bfa0c35c2b43711dfbdd8ba94b083919ea1bf&skRefreshToken=true"
                  ]
                ]
            ]
            
            let idpCollector = IdpCollector(with: jsonObject)
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
            XCTAssertTrue(idpCollector.idpType == "GOOGLE")
            XCTAssertTrue(idpCollector.link?.absoluteString == "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/539aedb9bb8617786b7343eb83439e51/capabilities/loginFirstFactor?interactionId=009ddda1-0c65-493a-bf77-2d270a495280&interactionToken=1deb3916f674f28004e642ff53f91e4474b1561b1281e62a9a15133f118795ddfbaf3889eea8e7cbbe689b1c7f419b1306af9b0b4432a809b3a983f2dee7406857502a2592df3d2adbd88103fa1d078bfe5480f66c84b71c2d8fce065284a5708e8194689f92f4bbdc66bd683c6bfa0c35c2b43711dfbdd8ba94b083919ea1bf&skRefreshToken=true")
            XCTAssertNotNil(handler)
            XCTAssertNotNil(handler as? GoogleRequestHandler)
        }
    
    // MARK: - GoogleHandler Tests
    
    @MainActor func testGoogleHandlerTokenType() {
        let handler = GoogleHandler()
        XCTAssertEqual(handler.tokenType, IdpConstants.id_token)
    }
    
    @MainActor func testGoogleHandlerInitialization() {
        let handler = GoogleHandler()
        XCTAssertNotNil(handler)
        XCTAssertFalse(handler.isNativeAvailable)
    }
    
    // MARK: - GoogleRequestHandler Tests
    
    @MainActor func testGoogleRequestHandlerInitialization() {
        let httpClient = HttpClient.createClient()
        let handler = GoogleRequestHandler(httpClient: httpClient as! URLSessionHttpClient)
        XCTAssertNotNil(handler)
        XCTAssertFalse(handler.isNativeAvailable)
    }
    
    // MARK: - GoogleHandlerUtils Tests
    
    @MainActor func testGoogleHandlerUtilsAuthorizeThrowsWithNilClientId() async {
        let idpClient = IdpClient(clientId: nil, scopes: ["email"])
        
        do {
            _ = try await GoogleHandlerUtils.authorize(idpClient: idpClient)
            XCTFail("Expected error to be thrown with nil client ID")
        } catch {
            // Expected - validation fails with nil client ID
            XCTAssertNotNil(error)
        }
    }

}
