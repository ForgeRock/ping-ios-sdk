//
//  DeviceRegistrationCollectorTests.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingDavinci

class DeviceRegistrationCollectorTests: XCTestCase {
    
    func testInitializesOptionsWithProvidedValue() {
        let input: [String: Any] = [
            "type": "DEVICE_REGISTRATION",
            "key": "device-registration",
            "label": "MFA Device Selection - Registration",
            "required": true,
            "options": [
                [
                    "type": "EMAIL",
                    "title": "Email",
                    "description": "Receive an authentication passcode in your email.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.10.0/images/icon-outline-mail.svg"
                ],
                [
                    "type": "SMS",
                    "title": "Text Message",
                    "description": "Receive an authentication passcode in a text message.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.18.2/images/icon-outline-text-message.svg"
                ],
                [
                    "type": "VOICE",
                    "title": "Voice",
                    "description": "Receive an authentication passcode in a text message.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.18.2/images/icon-outline-text-message.svg"
                ]
            ]
        ]
        
        let collector = DeviceRegistrationCollector(with: input)
        XCTAssertEqual(collector.devices.count, 3)
        
        XCTAssertEqual(
            collector.devices.map { $0.title },
            ["Email", "Text Message", "Voice"]
        )
        XCTAssertEqual(
            collector.devices.map { $0.type },
            ["EMAIL", "SMS", "VOICE"]
        )
    }
    
    func testCloseShouldClearValue() {
        let input: [String: Any] = [
            "type": "DEVICE_REGISTRATION",
            "key": "device-registration",
            "label": "MFA Device Selection - Registration",
            "required": true,
            "options": [
                [
                    "type": "EMAIL",
                    "title": "Email",
                    "description": "Receive an authentication passcode in your email.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.10.0/images/icon-outline-mail.svg"
                ],
                [
                    "type": "SMS",
                    "title": "Text Message",
                    "description": "Receive an authentication passcode in a text message.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.18.2/images/icon-outline-text-message.svg"
                ],
                [
                    "type": "VOICE",
                    "title": "Voice",
                    "description": "Receive an authentication passcode in a text message.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.18.2/images/icon-outline-text-message.svg"
                ]
            ]
        ]
        let collector = DeviceRegistrationCollector(with: input)
        collector.value = collector.devices.first
        
        XCTAssertNotNil(collector.value)
        
        collector.close()
        
        XCTAssertNil(collector.value)
        XCTAssertNil(collector.payload())
    }
    
    func testCloseShouldAllowReuse() {
        let input: [String: Any] = [
            "type": "DEVICE_REGISTRATION",
            "key": "device-registration",
            "label": "MFA Device Selection - Registration",
            "required": true,
            "options": [
                [
                    "type": "EMAIL",
                    "title": "Email",
                    "description": "Receive an authentication passcode in your email.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.10.0/images/icon-outline-mail.svg"
                ],
                [
                    "type": "SMS",
                    "title": "Text Message",
                    "description": "Receive an authentication passcode in a text message.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.18.2/images/icon-outline-text-message.svg"
                ],
                [
                    "type": "VOICE",
                    "title": "Voice",
                    "description": "Receive an authentication passcode in a text message.",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.18.2/images/icon-outline-text-message.svg"
                ]
            ]
        ]
        let collector = DeviceRegistrationCollector(with: input)
        
        collector.value = collector.devices.first
        var payload = collector.payload()
        XCTAssertEqual(payload, "EMAIL")
        
        collector.close()
        XCTAssertNil(collector.value)
        
        collector.value = collector.devices.last
        payload = collector.payload()
        XCTAssertEqual(payload, "VOICE")
    }
}
