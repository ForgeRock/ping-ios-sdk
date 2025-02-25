//
//  NativeHandlerTests.swift
//  External-idpTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci
@testable import External_idp
@testable import PingOrchestrate

final class NativeHandlerTests: XCTestCase {
    override func setUpWithError() throws {
        CollectorFactory.shared.registerDefaultCollectors()
    }
    
    func testidpCollectorParsingFacebook() throws {
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
    
    func testidpCollectorParsingGoogle() throws {
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
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.init(session: .shared))
        XCTAssertTrue(idpCollector.idpType == "GOOGLE")
        XCTAssertTrue(idpCollector.link?.absoluteString == "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/539aedb9bb8617786b7343eb83439e51/capabilities/loginFirstFactor?interactionId=009ddda1-0c65-493a-bf77-2d270a495280&interactionToken=1deb3916f674f28004e642ff53f91e4474b1561b1281e62a9a15133f118795ddfbaf3889eea8e7cbbe689b1c7f419b1306af9b0b4432a809b3a983f2dee7406857502a2592df3d2adbd88103fa1d078bfe5480f66c84b71c2d8fce065284a5708e8194689f92f4bbdc66bd683c6bfa0c35c2b43711dfbdd8ba94b083919ea1bf&skRefreshToken=true")
        XCTAssertNotNil(handler)
        XCTAssertNotNil(handler as? GoogleRequestHandler)
    }
    
    func testidpCollectorParsingApple() throws {
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

/*
 {
   "idpId" : "e1112ad5f29f4fef394c68fa90baa0fe",
   "idpType" : "APPLE",
   "type" : "SOCIAL_LOGIN_BUTTON",
   "label" : "Sign in with Apple George",
   "idpEnabled" : true,
   "links" : {
     "authenticate" : {
       "href" : "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/e1112ad5f29f4fef394c68fa90baa0fe/capabilities/loginFirstFactor?interactionId=009ddda1-0c65-493a-bf77-2d270a495280&interactionToken=1deb3916f674f28004e642ff53f91e4474b1561b1281e62a9a15133f118795ddfbaf3889eea8e7cbbe689b1c7f419b1306af9b0b4432a809b3a983f2dee7406857502a2592df3d2adbd88103fa1d078bfe5480f66c84b71c2d8fce065284a5708e8194689f92f4bbdc66bd683c6bfa0c35c2b43711dfbdd8ba94b083919ea1bf&skRefreshToken=true"
     }
   }
 }
 */
