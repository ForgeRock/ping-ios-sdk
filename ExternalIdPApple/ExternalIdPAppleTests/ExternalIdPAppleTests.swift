//
//  ExternalIdPAppleTests.swift
//  ExternalIdPAppleTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingExternalIdPApple
@testable import PingExternalIdP
@testable import PingOrchestrate
@testable import PingDavinciPlugin

final class ExternalIdPAppleTests: XCTestCase {
    
    override func setUpWithError() throws {
        IdpCollector.registerCollector()
    }
    
    @MainActor func testidpCollectorParsingApple() throws {
        let jsonObject: [String: Any] = [
            "idpId" : "e1112ad5f29f4fef394c68fa90baa0fe",
            "idpType" : "APPLE",
            "type" : "SOCIAL_LOGIN_BUTTON",
            "label" : "Sign in with Apple",
            "idpEnabled" : true,
            "links" : [
                "authenticate" : [
                    "href" : "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/e1112ad5f29f4fef394c68fa90baa0fe/capabilities/loginFirstFactor?interactionId=009ddda1-0c65-493a-bf77-2d270a495280&interactionToken=1deb3916f674f28004e642ff53f91e4474b1561b1281e62a9a15133f118795ddfbaf3889eea8e7cbbe689b1c7f419b1306af9b0b4432a809b3a983f2dee7406857502a2592df3d2adbd88103fa1d078bfe5480f66c84b71c2d8fce065284a5708e8194689f92f4bbdc66bd683c6bfa0c35c2b43711dfbdd8ba94b083919ea1bf&skRefreshToken=true"
                ]
            ]
        ]
        
        let idpCollector = IdpCollector(with: jsonObject)
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.init(session: .shared))
        XCTAssertTrue(idpCollector.idpType == "APPLE")
        XCTAssertTrue(idpCollector.link?.absoluteString == "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/e1112ad5f29f4fef394c68fa90baa0fe/capabilities/loginFirstFactor?interactionId=009ddda1-0c65-493a-bf77-2d270a495280&interactionToken=1deb3916f674f28004e642ff53f91e4474b1561b1281e62a9a15133f118795ddfbaf3889eea8e7cbbe689b1c7f419b1306af9b0b4432a809b3a983f2dee7406857502a2592df3d2adbd88103fa1d078bfe5480f66c84b71c2d8fce065284a5708e8194689f92f4bbdc66bd683c6bfa0c35c2b43711dfbdd8ba94b083919ea1bf&skRefreshToken=true")
        XCTAssertNotNil(handler)
        XCTAssertNotNil(handler as? AppleRequestHandler)
    }
    
}
