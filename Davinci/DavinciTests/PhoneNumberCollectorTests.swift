//
//  PhoneNumberCollectorTests.swift
//  Davinci
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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
    
    func testDefaultWithPhoneNumber() {
        let input = "1234567"
        let collector = PhoneNumberCollector(with: [:])
        collector.initialize(with: input)
        
        XCTAssertEqual(collector.phoneNumber, "1234567")
    }
    
    func testInitializeWithDictionaryAndSetsPhoneNumberAndCountryCode() {
        // Arrange
        let input: [String: Any] = [
            "phoneNumber": "CA-1-+17783186380-7783186380",
            "countryCode": "CA"
        ]
        let collector = PhoneNumberCollector(with: [:])
        
        // Act
        collector.initialize(with: input)
        
        // Assert
        XCTAssertEqual(collector.phoneNumber, "CA-1-+17783186380-7783186380")
        XCTAssertEqual(collector.countryCode, "CA")
    }
    
    func testInitWithoutRequiredDefaultsToFalse() {
        let collector = PhoneNumberCollector(with: [:])
        XCTAssertEqual(collector.required, false)
    }
    
    func testInitWithNullDefaultCountryCodeUsesEmptyString() {
        let collector = PhoneNumberCollector(with: [:])
        XCTAssertEqual(collector.defaultCountryCode, "")
    }
    
    func testPayloadReturnsProperlyFormattedPhoneNumber() {
        let collector = PhoneNumberCollector(with: [:])
        collector.countryCode = "US"
        collector.phoneNumber = "5555555555"
        
        let result = collector.payload()
        
        XCTAssertEqual(result?["countryCode"] as? String, "US")
        XCTAssertEqual(result?["phoneNumber"] as? String, "5555555555")
    }
    
    func testInitializeWithPhoneNumberAndExtension() {
        let input: [String: Any] = [
            "phoneNumber": "CA-1-+17783186380-7783186380",
            "countryCode": "CA",
            "extension": "1234"
        ]
        let collector = PhoneNumberCollector(with: [:])
        
        collector.initialize(with: input)
        
        XCTAssertEqual(collector.phoneNumber, "CA-1-+17783186380-7783186380")
        XCTAssertEqual(collector.countryCode, "CA")
        XCTAssertEqual(collector.extension, "1234")
    }
    
    func testInitWithShowExtensionAndExtensionLabel() {
        let input: [String: Any] = [
            "type": "PHONE_NUMBER",
            "key": "phone-field",
            "label": "Phone",
            "showExtension": true,
            "extensionLabel": "Ext."
        ]
        
        let collector = PhoneNumberCollector(with: input)
        XCTAssertEqual(collector.showExtension, true)
        XCTAssertEqual(collector.extensionLabel, "Ext.")
    }
    
    func testPayloadIncludesExtension() {
        let collector = PhoneNumberCollector(with: [:])
        collector.countryCode = "US"
        collector.phoneNumber = "5555555555"
        collector.extension = "1234"
        
        let result = collector.payload()
        
        XCTAssertEqual(result?["countryCode"] as? String, "US")
        XCTAssertEqual(result?["phoneNumber"] as? String, "5555555555")
        XCTAssertEqual(result?["extension"] as? String, "1234")
    }
    
    func testPayloadReturnsNilWhenFieldsEmpty() {
        let collector = PhoneNumberCollector(with: [:])
        XCTAssertNil(collector.payload())
    }
    
    func testPayloadReturnsNilWhenOnlyCountryCode() {
        let collector = PhoneNumberCollector(with: [:])
        collector.countryCode = "US"
        XCTAssertNil(collector.payload())
    }
}
