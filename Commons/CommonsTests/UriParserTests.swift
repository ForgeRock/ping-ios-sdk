//
//  UriParserTests.swift
//  PingCommonsTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingCommons

final class UriParserTests: XCTestCase {

    private var parser: UriParser? = UriParser()

    override func setUp() {
        super.setUp()
        parser = UriParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - UriScheme Tests

    func testUriScheme_RawValues() {
        XCTAssertEqual(UriScheme.otpauth.rawValue, "otpauth://")
        XCTAssertEqual(UriScheme.pushauth.rawValue, "pushauth://")
        XCTAssertEqual(UriScheme.mfauth.rawValue, "mfauth://")
    }

    func testUriScheme_SchemeProperty() {
        XCTAssertEqual(UriScheme.otpauth.scheme, "otpauth")
        XCTAssertEqual(UriScheme.pushauth.scheme, "pushauth")
        XCTAssertEqual(UriScheme.mfauth.scheme, "mfauth")
    }

    func testUriScheme_FromUrlString() {
        XCTAssertEqual(UriScheme.from(urlString: "otpauth://example"), .otpauth)
        XCTAssertEqual(UriScheme.from(urlString: "pushauth://example"), .pushauth)
        XCTAssertEqual(UriScheme.from(urlString: "mfauth://example"), .mfauth)
        XCTAssertEqual(UriScheme.from(urlString: "OTPAUTH://EXAMPLE"), .otpauth) // Case insensitive
        XCTAssertNil(UriScheme.from(urlString: "https://example.com"))
        XCTAssertNil(UriScheme.from(urlString: "invalid"))
    }

    func testUriScheme_FromUrl() {
        XCTAssertEqual(UriScheme.from(url: URL(string: "otpauth://example")!), .otpauth)
        XCTAssertEqual(UriScheme.from(url: URL(string: "pushauth://example")!), .pushauth)
        XCTAssertEqual(UriScheme.from(url: URL(string: "mfauth://example")!), .mfauth)
        XCTAssertNil(UriScheme.from(url: URL(string: "https://example.com")!))
    }

    func testUriScheme_MatchesUrlString() {
        XCTAssertTrue(UriScheme.otpauth.matches(urlString: "otpauth://example"))
        XCTAssertTrue(UriScheme.otpauth.matches(urlString: "OTPAUTH://EXAMPLE"))
        XCTAssertFalse(UriScheme.otpauth.matches(urlString: "pushauth://example"))
    }

    func testUriScheme_MatchesUrl() {
        XCTAssertTrue(UriScheme.otpauth.matches(url: URL(string: "otpauth://example")!))
        XCTAssertFalse(UriScheme.otpauth.matches(url: URL(string: "pushauth://example")!))
    }

    // MARK: - Label Parsing Tests

    func testParseLabelComponents_IssuerAndAccount() throws {
        let result = try parser?.parseLabelComponents("GitHub:john.doe", issuerParam: nil)
        XCTAssertEqual(result?.issuer, "GitHub")
        XCTAssertEqual(result?.accountName, "john.doe")
    }

    func testParseLabelComponents_IssuerAndAccountWithParam() throws {
        let result = try parser?.parseLabelComponents("GitHub:john.doe", issuerParam: "GitHub")
        XCTAssertEqual(result?.issuer, "GitHub")
        XCTAssertEqual(result?.accountName, "john.doe")
    }

    func testParseLabelComponents_IssuerMismatch() {
        XCTAssertThrowsError(try parser?.parseLabelComponents("GitHub:john.doe", issuerParam: "Google")) { error in
            if case UriParseError.issuerMismatch(let param, let label) = error {
                XCTAssertEqual(param, "Google")
                XCTAssertEqual(label, "GitHub")
            } else {
                XCTFail("Expected issuerMismatch error")
            }
        }
    }

    func testParseLabelComponents_IssuerMismatch_CaseInsensitive() throws {
        // Case insensitive matching should not throw
        let result = try parser?.parseLabelComponents("github:john.doe", issuerParam: "GitHub")
        XCTAssertEqual(result?.issuer, "github")
        XCTAssertEqual(result?.accountName, "john.doe")
    }

    func testParseLabelComponents_OnlyAccount() throws {
        let result = try parser?.parseLabelComponents("john.doe", issuerParam: "GitHub")
        XCTAssertEqual(result?.issuer, "GitHub")
        XCTAssertEqual(result?.accountName, "john.doe")
    }

    func testParseLabelComponents_OnlyAccountNoParam() throws {
        let result = try parser?.parseLabelComponents("john.doe", issuerParam: nil)
        XCTAssertEqual(result?.issuer, "")
        XCTAssertEqual(result?.accountName, "john.doe")
    }

    func testParseLabelComponents_EmptyLabel() throws {
        let result = try parser?.parseLabelComponents("", issuerParam: "GitHub")
        XCTAssertEqual(result?.issuer, "GitHub")
        XCTAssertEqual(result?.accountName, "")
    }

    func testParseLabelComponents_EmptyLabelNoParam() throws {
        let result = try parser?.parseLabelComponents("", issuerParam: nil)
        XCTAssertEqual(result?.issuer, "")
        XCTAssertEqual(result?.accountName, "")
    }

    func testParseLabelComponents_EmptyIssuerInLabel() throws {
        let result = try parser?.parseLabelComponents(":john.doe", issuerParam: "GitHub")
        XCTAssertEqual(result?.issuer, "GitHub")
        XCTAssertEqual(result?.accountName, "john.doe")
    }

    
    // MARK: - Helper Method Tests
    
    func testFormatBackgroundColor() {
        XCTAssertEqual(parser?.formatBackgroundColor("#FF0000"), "FF0000")
        XCTAssertEqual(parser?.formatBackgroundColor("FF0000"), "FF0000")
        XCTAssertNil(parser?.formatBackgroundColor(nil))
        XCTAssertEqual(parser?.formatBackgroundColor(""), "")
        XCTAssertEqual(parser?.formatBackgroundColor("#"), "")
    }
    
    
    // MARK: - Error Description Tests
    
    func testUriParseError_Descriptions() {
        let issuerMismatch = UriParseError.issuerMismatch(parameterIssuer: "Google", labelIssuer: "GitHub")
        XCTAssertTrue(issuerMismatch.errorDescription!.contains("Google"))
        XCTAssertTrue(issuerMismatch.errorDescription!.contains("GitHub"))
        
        let malformedURI = UriParseError.malformedURI("invalid://uri")
        XCTAssertTrue(malformedURI.errorDescription!.contains("invalid://uri"))
        
        let unsupportedScheme = UriParseError.unsupportedScheme("unknown")
        XCTAssertTrue(unsupportedScheme.errorDescription!.contains("unknown"))
    }
    
    
    // MARK: - Constants Tests
    
    func testUriParser_Constants() {
        XCTAssertEqual(UriParser.mfauthScheme, "mfauth")
        XCTAssertEqual(UriParser.issuerParam, "issuer")
        XCTAssertEqual(UriParser.userIdParam, "d")
        XCTAssertEqual(UriParser.userIdParamOath, "uid")
        XCTAssertEqual(UriParser.imageUrlParam, "image")
        XCTAssertEqual(UriParser.backgroundColorParam, "b")
        XCTAssertEqual(UriParser.policiesParam, "policies")
    }
    
    
    // MARK: - Edge Cases
    
    func testParseLabelComponents_MultipleColons() throws {
        let result = try parser?.parseLabelComponents("GitHub:user:name", issuerParam: nil)
        XCTAssertEqual(result?.issuer, "")
        XCTAssertEqual(result?.accountName, "")
    }
    
}
