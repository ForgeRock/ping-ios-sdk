// 
//  DeviceAuthenticatorCollectorTests.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci

class DeviceAuthenticationCollectorTests: XCTestCase {
    
    func testInitializesOptionsWithProvidedValue() {
        let input: [String: Any] = [
            "type": "DEVICE_AUTHENTICATION",
            "key": "device-authentication",
            "label": "MFA Device Selection - Authentication",
            "required": true,
            "options": [
                [
                    "type": "EMAIL",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.10.0/images/icon-outline-mail.svg",
                    "title": "Email",
                    "id": "e00e00a2-e0c9-409a-9944-f6c282d6da60",
                    "default": true,
                    "description": "d******l@gmail.com"
                ],
                [
                    "type": "EMAIL",
                    "iconSrc": "https://assets.pingone.com/ux/end-user/2.10.0/images/icon-outline-mail.svg",
                    "title": "Email",
                    "id": "e00e00a2-e0c9-409a-9945-f6c282d6da61",
                    "default": true,
                    "description": "b******l@gmail.com"
                ]
            ]
        ]
        
        let collector = DeviceAuthenticationCollector(with: input)
        XCTAssertEqual(collector.devices.count, 2)
        
        XCTAssertEqual(
            collector.devices.map { $0.title },
            ["Email", "Email"]
        )
        XCTAssertEqual(
            collector.devices.map { $0.id },
            ["e00e00a2-e0c9-409a-9944-f6c282d6da60", "e00e00a2-e0c9-409a-9945-f6c282d6da61"]
        )
        XCTAssertEqual(
            collector.devices.map { $0.description },
            ["d******l@gmail.com", "b******l@gmail.com"]
        )
    }
}
