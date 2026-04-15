//
//  JwtUtilsTests.swift
//  PingCommonsTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import Foundation
@testable import PingCommons

final class CompactJwtTests: XCTestCase {

    // Test secrets - at least 256 bits (32 bytes) for HS256
    private static let testSecret = "c2VjcmV0S2V5Rm9yVGVzdGluZ1RoaXNOZWVkc1RvQmVBdExlYXN0MjU2Yml0cw==" // At least 256 bits
    private static let testChallenge = "dGVzdENoYWxsZW5nZQ==" // Base64 for "testChallenge"

    // MARK: - JWT Generation Tests

    func testGenerateJwt_CreatesValidJWTStructure() throws {
        // Set up claims for JWT
        let claims: [String: Any] = [
            "sub": "testUser",
            "iss": "testIssuer",
            "exp": Int(Date().timeIntervalSince1970) + 3600,
            "intValue": 123,
            "doubleValue": 123.45,
            "boolValue": true
        ]

        let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: claims)

        // Verify JWT structure
        let jwtParts = jwt.split(separator: ".")
        XCTAssertEqual(jwtParts.count, 3, "JWT should have three parts")

        // Verify header
        let headerString = String(jwtParts[0])
        let headerData = decodeBase64URL(headerString)
        XCTAssertNotNil(headerData, "Header should be decodable")

        let header = try JSONSerialization.jsonObject(with: headerData!) as? [String: String]
        XCTAssertNotNil(header)
        XCTAssertEqual(header?["alg"], "HS256")
        XCTAssertEqual(header?["typ"], "JWT")

        // Verify payload
        let payloadString = String(jwtParts[1])
        let payloadData = decodeBase64URL(payloadString)
        XCTAssertNotNil(payloadData, "Payload should be decodable")

        let payload = try JSONSerialization.jsonObject(with: payloadData!) as? [String: Any]
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["sub"] as? String, "testUser")
        XCTAssertEqual(payload?["iss"] as? String, "testIssuer")
        XCTAssertEqual(payload?["intValue"] as? Int, 123)
        XCTAssertEqual(payload?["doubleValue"] as? Double, 123.45)
        XCTAssertEqual(payload?["boolValue"] as? Bool, true)

        // Verify signature exists
        XCTAssertFalse(String(jwtParts[2]).isEmpty, "Signature should not be empty")
    }

    func testGenerateJwt_EmptySecret_ThrowsError() {
        let claims: [String: Any] = ["test": "value"]

        XCTAssertThrowsError(try CompactJwt.signJwtClaims(base64Secret: "", claims: claims)) { error in
            guard case JwtError.invalidSecret = error else {
                XCTFail("Expected invalidSecret error")
                return
            }
        }
    }

    func testGenerateJwt_InvalidBase64Secret_ThrowsError() {
        let claims: [String: Any] = ["test": "value"]
        let invalidSecret = "not-valid-base64!@#$"

        XCTAssertThrowsError(try CompactJwt.signJwtClaims(base64Secret: invalidSecret, claims: claims)) { error in
            guard case JwtError.invalidSecret = error else {
                XCTFail("Expected invalidSecret error")
                return
            }
        }
    }

    func testGenerateJwt_CreatesExpectedJwtOutput() throws {
        // Use the same test data as Android tests
        let base64Secret = "2afd55692b492e60df7e9c0b4f55b0492afd55692b492e60df7e9c0b4f55b049"
        let claims: [String: Any] = [
            "deviceId": "test-device-token",
            "deviceName": "Test Android Device",
            "deviceType": "android",
            "communicationType": "gcm"
        ]

        let jwt = try CompactJwt.signJwtClaims(base64Secret: base64Secret, claims: claims)

        XCTAssertFalse(jwt.isEmpty)
        let jwtParts = jwt.split(separator: ".")
        XCTAssertEqual(jwtParts.count, 3, "JWT should have three parts")

        // Note: The exact JWT may differ due to JSON serialization order differences between platforms
        // But we can verify the structure and claims are correct
        let parsedClaims = try CompactJwt.parseJwtClaims(jwt)
        XCTAssertEqual(parsedClaims["deviceId"] as? String, "test-device-token")
        XCTAssertEqual(parsedClaims["deviceName"] as? String, "Test Android Device")
        XCTAssertEqual(parsedClaims["deviceType"] as? String, "android")
        XCTAssertEqual(parsedClaims["communicationType"] as? String, "gcm")
    }

    // MARK: - JWT Validation Tests

    func testIsValidJwt_ValidJWT_ReturnsTrue() throws {
        // Generate a valid JWT first
        let claims: [String: Any] = [
            "test": "value",
            "required1": "value1",
            "required2": "value2"
        ]
        let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: claims)

        // Test with no required fields
        XCTAssertTrue(CompactJwt.canParseJwt(jwt))

        // Test with required fields that exist
        XCTAssertTrue(CompactJwt.canParseJwt(jwt, requiredFields: ["required1", "required2"]))
    }

    func testIsValidJwt_InvalidJWT_ReturnsFalse() throws {
        // Test with invalid JWT formats
        XCTAssertFalse(CompactJwt.canParseJwt("invalid.jwt.format"))
        XCTAssertFalse(CompactJwt.canParseJwt("invalid"))
        XCTAssertFalse(CompactJwt.canParseJwt(""))
        XCTAssertFalse(CompactJwt.canParseJwt("only.two.parts"))

        // Test with a JWT missing required fields
        let claims: [String: Any] = ["test": "value"]
        let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: claims)
        XCTAssertFalse(CompactJwt.canParseJwt(jwt, requiredFields: ["missing"]))
    }

    func testIsValidJwt_MalformedPayload_ReturnsFalse() {
        // Create a JWT with valid structure but invalid base64 payload
        let malformedJwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.invalid_base64_payload.signature"
        XCTAssertFalse(CompactJwt.canParseJwt(malformedJwt))
    }

    // MARK: - JWT Parsing Tests

    func testParseJwtClaims_ExtractsCorrectValues() throws {
        // Generate a JWT with various data types
        let originalClaims: [String: Any] = [
            "stringValue": "test",
            "intValue": 123,
            "doubleValue": 123.45,
            "boolValue": true,
            "nullValue": NSNull()
        ]

        let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: originalClaims)

        // Parse the JWT
        let parsedClaims = try CompactJwt.parseJwtClaims(jwt)

        // Verify the parsed values
        XCTAssertEqual(parsedClaims["stringValue"] as? String, "test")
        XCTAssertEqual(parsedClaims["intValue"] as? Int, 123)
        XCTAssertEqual(parsedClaims["doubleValue"] as? Double, 123.45)
        XCTAssertEqual(parsedClaims["boolValue"] as? Bool, true)
        // Note: NSNull may be handled differently in JSON serialization
    }

    func testParseJwtClaims_InvalidJWTFormat_ThrowsError() {
        XCTAssertThrowsError(try CompactJwt.parseJwtClaims("invalid.jwt")) { error in
            guard case JwtError.invalidFormat = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
        }

        XCTAssertThrowsError(try CompactJwt.parseJwtClaims("only.two")) { error in
            guard case JwtError.invalidFormat = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
        }
    }

    func testParseJwtClaims_InvalidPayload_ThrowsError() {
        // Create JWT with invalid base64 payload
        let invalidPayloadJwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.invalid_base64.signature"

        XCTAssertThrowsError(try CompactJwt.parseJwtClaims(invalidPayloadJwt)) { error in
            guard case JwtError.invalidPayload = error else {
                XCTFail("Expected invalidPayload error")
                return
            }
        }
    }

    // MARK: - Edge Cases and Error Handling

    func testGenerateJwt_EmptyClaims_Succeeds() throws {
        let emptyClaims: [String: Any] = [:]
        let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: emptyClaims)

        XCTAssertFalse(jwt.isEmpty)
        let parsedClaims = try CompactJwt.parseJwtClaims(jwt)
        XCTAssertTrue(parsedClaims.isEmpty)
    }

    func testGenerateJwt_UnicodeCharacters_Succeeds() throws {
        let unicodeClaims: [String: Any] = [
            "unicode": "Hello 世界 🌍",
            "emoji": "🚀🔐",
            "accents": "café naïve résumé"
        ]

        let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: unicodeClaims)
        let parsedClaims = try CompactJwt.parseJwtClaims(jwt)

        XCTAssertEqual(parsedClaims["unicode"] as? String, "Hello 世界 🌍")
        XCTAssertEqual(parsedClaims["emoji"] as? String, "🚀🔐")
        XCTAssertEqual(parsedClaims["accents"] as? String, "café naïve résumé")
    }

    func testJwtError_ErrorDescriptions() {
        let invalidSecret = JwtError.invalidSecret("test message")
        XCTAssertTrue(invalidSecret.errorDescription!.contains("test message"))

        let invalidFormat = JwtError.invalidFormat("format error")
        XCTAssertTrue(invalidFormat.errorDescription!.contains("format error"))

        let invalidPayload = JwtError.invalidPayload("payload error")
        XCTAssertTrue(invalidPayload.errorDescription!.contains("payload error"))

        let signingFailed = JwtError.signingFailed("signing error")
        XCTAssertTrue(signingFailed.errorDescription!.contains("signing error"))
    }

    // MARK: - Base64URL Encoding Tests

    func testBase64URLEncoding_RemovesPadding() {
        let testData = Data("Hello World".utf8)
        let base64URL = testData.base64URLEncodedString()

        // Should not contain padding characters
        XCTAssertFalse(base64URL.contains("="))
        // Should use URL-safe characters
        XCTAssertFalse(base64URL.contains("+"))
        XCTAssertFalse(base64URL.contains("/"))
    }

    func testBase64URLDecoding_HandlesVariousInputs() {
        // Test decoding with various base64URL inputs
        let testCases = [
            "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9", // Standard JWT header
            "dGVzdA", // "test" without padding
            "dGVzdA==", // "test" with padding
            "dGVzdENoYWxsZW5nZQ" // "testChallenge" without padding
        ]

        for testCase in testCases {
            let decoded = decodeBase64URL(testCase)
            XCTAssertNotNil(decoded, "Should be able to decode: \(testCase)")
        }
    }

    // MARK: - Performance Tests

    func testJWT_Performance() throws {
        let claims: [String: Any] = [
            "sub": "user123",
            "iss": "test-issuer",
            "exp": Int(Date().timeIntervalSince1970) + 3600,
            "data": "some test data"
        ]

        measure {
            for _ in 0..<100 {
                do {
                    let jwt = try CompactJwt.signJwtClaims(base64Secret: Self.testSecret, claims: claims)
                    _ = try CompactJwt.parseJwtClaims(jwt)
                    _ = CompactJwt.canParseJwt(jwt)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func decodeBase64URL(_ base64URLString: String) -> Data? {
        // Convert base64URL to standard base64
        var base64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
