//
//  SelectIdpCallbackTests.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingJourney
@testable import PingExternalIdP

final class SelectIdpCallbackTests: XCTestCase {
    
    let json: [String: Any] = [
        "type": "SelectIdPCallback",
        "output": [
            [
                "name": "providers",
                "value": [
                    [
                        "provider": "GooglePostman",
                        "uiConfig": [
                            "buttonCustomStyle": "background-color: #fff; color: #757575; border-color: #ddd;",
                            "buttonImage": "images/g-logo.png",
                            "buttonClass": "",
                            "buttonCustomStyleHover": "color: #6d6d6d; background-color: #eee; border-color: #ccc;",
                            "buttonDisplayName": "Google",
                            "iconClass": "fa-google",
                            "iconFontColor": "white",
                            "iconBackground": "#4184f3"
                        ]
                    ]
                ]
            ],
            [
                "name": "value",
                "value": ""
            ]
        ],
        "input": [
            [
                "name": "IDToken1",
                "value": ""
            ]
        ]
    ]
    func testInitValueParsesProviders() {
        let jsonArray: [[String: Any]] = [
            ["provider": "google", "uiConfig": ["icon": "google.png"]],
            ["provider": "facebook"]
        ]
        let callback = SelectIdpCallback()
        callback.initValue(name: "providers", value: jsonArray)
        XCTAssertEqual(callback.providers.count, 2)
        XCTAssertEqual(callback.providers[0].provider, "google")
        XCTAssertEqual(callback.providers[0].uiConfig["icon"] as? String, "google.png")
        XCTAssertEqual(callback.providers[1].provider, "facebook")
        XCTAssertTrue(callback.providers[1].uiConfig.isEmpty)
    }
    
    func testSelectIdpCallbackPayload() {
        let callback = SelectIdpCallback()
        callback.json = json // use the dictionary created previously
        callback.value = "GooglePostman"
        
        let payload = callback.payload()
        XCTAssertEqual(payload["type"] as? String, "SelectIdPCallback")
        
        // Check output providers
        guard let outputArray = payload["output"] as? [[String: Any]] else {
            XCTFail("payload output is not array")
            return
        }
        let providersEntry = outputArray.first(where: { $0["name"] as? String == "providers" })
        XCTAssertNotNil(providersEntry)
        
        // Check input for correct value
        guard let inputArray = payload["input"] as? [[String: Any]] else {
            XCTFail("payload input is not array")
            return
        }
        guard let idTokenInput = inputArray.first(where: { $0["name"] as? String == "IDToken1" }) else {
            XCTFail("IDToken1 input not found")
            return
        }
        XCTAssertEqual(idTokenInput["value"] as? String, "GooglePostman")
    }
}
