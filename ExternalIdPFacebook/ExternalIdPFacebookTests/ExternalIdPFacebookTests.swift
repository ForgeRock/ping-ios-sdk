//
//  ExternalIdPFacebookTests.swift
//  ExternalIdPFacebookTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingExternalIdPFacebook
@testable import PingExternalIdP
@testable import PingOrchestrate
@testable import PingDavinciPlugin

final class ExternalIdPFacebookTests: XCTestCase {
    
    override func setUpWithError() throws {
        Task {
            IdpCollector.registerCollector()
        }
    }
    
    @MainActor func testidpCollectorParsingFacebook() throws {
        let jsonObject: [String: Any] = [
            "idpId" : "1a1198fa0290d505d7cc49bb8e9fcb68",
            "idpType" : "FACEBOOK",
            "type" : "SOCIAL_LOGIN_BUTTON",
            "label" : "Sign in with Facebook",
            "idpEnabled" : true,
            "links" : [
                "authenticate" : [
                    "href" : "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/1a1198fa0290d505d7cc49bb8e9fcb68/capabilities/loginFirstFactor?interactionId=00caf721-c3f9-4880-8fe1-43e68b8c8691&interactionToken=c99b1e4854aefd5429d032b5446d4d5152826b1728eb047f89c727b58e2d237e944357c347eed50c43125d4a8a05afce5150d728e148b7d9f6dcff0403f6aa3dbc50598c0c48a3527bb72313136101c7a07c39e34ab54d34d7bbc891488cb0b1bbe6f841aeb5d59071366a46fa84f3d18fa08779dd2517e809fa9f1513793005&skRefreshToken=true"
                ]
            ]
        ]
        
        let idpCollector = IdpCollector(with: jsonObject)
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.init(session: .shared))
        XCTAssertTrue(idpCollector.idpType == "FACEBOOK")
        XCTAssertTrue(idpCollector.link?.absoluteString == "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/1a1198fa0290d505d7cc49bb8e9fcb68/capabilities/loginFirstFactor?interactionId=00caf721-c3f9-4880-8fe1-43e68b8c8691&interactionToken=c99b1e4854aefd5429d032b5446d4d5152826b1728eb047f89c727b58e2d237e944357c347eed50c43125d4a8a05afce5150d728e148b7d9f6dcff0403f6aa3dbc50598c0c48a3527bb72313136101c7a07c39e34ab54d34d7bbc891488cb0b1bbe6f841aeb5d59071366a46fa84f3d18fa08779dd2517e809fa9f1513793005&skRefreshToken=true")
        XCTAssertNotNil(handler)
        XCTAssertNotNil(handler as? FacebookRequestHandler)
    }
    
}
