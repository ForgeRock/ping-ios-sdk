// 
//  PhoneNumberCollectorTests.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingDavinci

class PhoneNumberCollectorTests: XCTestCase {
    func testInitializesOptionsWithProvidedValue() {
        let input: [String: Any] = [
            "type":"PHONE_NUMBER",
            "key":"phone-field",
            "label":"Phone",
            "required":true,
            "validatePhoneNumber":true
        ]
        
        let collector = PhoneNumberCollector(with: input)
        XCTAssertNotNil(collector)
        XCTAssertEqual(collector.required, true)
        XCTAssertEqual(collector.validatePhoneNumber, true)
        XCTAssertEqual(collector.defaultCountryCode, "")
    }
    
    func testInitializesOptionsNotValidated() {
        let input: [String: Any] = [
            "type": "PHONE_NUMBER",
            "key": "phone-field",
            "label": "Phone",
            "required": true,
            "validatePhoneNumber": false
        ]
        
        let collector = PhoneNumberCollector(with: input)
        XCTAssertNotNil(collector)
        XCTAssertEqual(collector.validatePhoneNumber, false)
        XCTAssertEqual(collector.defaultCountryCode, "")
    }
    
    func testInitializesOptionsNotValidatedDefaultCountryCodeGB() {
        let input: [String: Any] = [
            "type": "PHONE_NUMBER",
            "key": "phone-field",
            "label": "Phone",
            "required": true,
            "validatePhoneNumber": false,
            "defaultCountryCode": "GB"
        ]
        
        let collector = PhoneNumberCollector(with: input)
        XCTAssertNotNil(collector)
        XCTAssertEqual(collector.validatePhoneNumber, false)
        XCTAssertEqual(collector.defaultCountryCode, "GB")
    }
    
    func testdefaultWithPhoneNumber() {
        let input = "1234567"
        let collector = PhoneNumberCollector(with: [:])
        collector.initialize(with: input)
        
        XCTAssertEqual(collector.phoneNumber, "1234567")
    }
}
