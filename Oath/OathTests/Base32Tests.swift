//
//  Base32Tests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath

final class Base32Tests: XCTestCase {

    // MARK: - Encoding Tests

    func testBase32Encoding() {
        // Test vectors from RFC 4648
        let testCases: [(input: String, expected: String)] = [
            ("", ""),
            ("f", "MY======"),
            ("fo", "MZXQ===="),
            ("foo", "MZXW6==="),
            ("foob", "MZXW6YQ="),
            ("fooba", "MZXW6YTB"),
            ("foobar", "MZXW6YTBOI======")
        ]

        for testCase in testCases {
            let data = Data(testCase.input.utf8)
            let encoded = Base32.encode(data)
            XCTAssertEqual(encoded, testCase.expected, "Encoding failed for '\(testCase.input)'")
        }
    }

    func testBase32EncodingDataExtension() {
        let testData = Data("Hello, World!".utf8)
        let encoded = testData.base32EncodedString()
        XCTAssertFalse(encoded.isEmpty, "Encoded string should not be empty")
        XCTAssertTrue(encoded.allSatisfy { "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=".contains($0) },
                     "Encoded string should only contain valid Base32 characters")
    }

    // MARK: - Decoding Tests

    func testBase32Decoding() {
        // Test vectors from RFC 4648
        let testCases: [(input: String, expected: String)] = [
            ("", ""),
            ("MY======", "f"),
            ("MZXQ====", "fo"),
            ("MZXW6===", "foo"),
            ("MZXW6YQ=", "foob"),
            ("MZXW6YTB", "fooba"),
            ("MZXW6YTBOI======", "foobar")
        ]

        for testCase in testCases {
            guard let decoded = Base32.decode(testCase.input) else {
                XCTFail("Decoding failed for '\(testCase.input)'")
                continue
            }
            let decodedString = String(data: decoded, encoding: .utf8)
            XCTAssertEqual(decodedString, testCase.expected, "Decoding failed for '\(testCase.input)'")
        }
    }

    func testBase32DecodingDataExtension() {
        let testCases = [
            "MZXW6YTBOI======", // "foobar"
            "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", // Common OATH secret
            "JBSWY3DPEHPK3PXP" // Another common test secret
        ]

        for testCase in testCases {
            let decoded = Data(base32Encoded: testCase)
            XCTAssertNotNil(decoded, "Decoding should succeed for '\(testCase)'")
            XCTAssertTrue(decoded!.count > 0, "Decoded data should not be empty")
        }
    }

    // MARK: - Round Trip Tests

    func testBase32RoundTrip() {
        let testStrings = [
            "Hello, World!",
            "The quick brown fox jumps over the lazy dog",
            "12345678901234567890", // Common OATH test secret
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "!@#$%^&*()_+-={}[]|\\:;\"'<>?,./"
        ]

        for testString in testStrings {
            let originalData = Data(testString.utf8)
            let encoded = Base32.encode(originalData)

            guard let decoded = Base32.decode(encoded) else {
                XCTFail("Round trip failed for '\(testString)' - decoding failed")
                continue
            }

            XCTAssertEqual(originalData, decoded, "Round trip failed for '\(testString)'")
        }
    }

    func testBase32RoundTripDataExtension() {
        let testData = [
            Data("Hello".utf8),
            Data([0x01, 0x02, 0x03, 0x04, 0x05]),
            Data(repeating: 0xFF, count: 20),
            Data(Array(0...255))
        ]

        for data in testData {
            let encoded = data.base32EncodedString()
            let decoded = Data(base32Encoded: encoded)

            XCTAssertNotNil(decoded, "Round trip failed - decoding returned nil")
            XCTAssertEqual(data, decoded, "Round trip failed for data")
        }
    }

    // MARK: - Case Insensitivity Tests

    func testBase32CaseInsensitivity() {
        let testCases = [
            "MZXW6YTBOI======",
            "mzxw6ytboi======",
            "MzXw6YtBoI======"
        ]

        for testCase in testCases {
            let decoded = Base32.decode(testCase)
            XCTAssertNotNil(decoded, "Decoding should work regardless of case for '\(testCase)'")

            let decodedString = decoded.flatMap { String(data: $0, encoding: .utf8) }
            XCTAssertEqual(decodedString, "foobar", "Case insensitive decoding failed")
        }
    }

    // MARK: - Whitespace Handling Tests

    func testBase32WhitespaceHandling() {
        let testCases = [
            " MZXW6YTBOI====== ",
            "\tMZXW6YTBOI======\t",
            "\nMZXW6YTBOI======\n",
            "  MZXW6YTBOI======  "
        ]

        for testCase in testCases {
            let decoded = Base32.decode(testCase)
            XCTAssertNotNil(decoded, "Decoding should handle whitespace for '\(testCase)'")

            let decodedString = decoded.flatMap { String(data: $0, encoding: .utf8) }
            XCTAssertEqual(decodedString, "foobar", "Whitespace handling failed")
        }
    }

    // MARK: - Padding Tests

    func testBase32PaddingVariations() {
        // Test with and without padding
        let testCases: [(withPadding: String, withoutPadding: String)] = [
            ("MY======", "MY"),
            ("MZXQ====", "MZXQ"),
            ("MZXW6===", "MZXW6"),
            ("MZXW6YQ=", "MZXW6YQ"),
            ("MZXW6YTB", "MZXW6YTB") // No padding needed
        ]

        for testCase in testCases {
            let decodedWithPadding = Base32.decode(testCase.withPadding)
            let decodedWithoutPadding = Base32.decode(testCase.withoutPadding)

            XCTAssertNotNil(decodedWithPadding, "Decoding with padding should work")
            XCTAssertNotNil(decodedWithoutPadding, "Decoding without padding should work")
            XCTAssertEqual(decodedWithPadding, decodedWithoutPadding, "Results should be identical")
        }
    }

    // MARK: - Error Handling Tests

    func testBase32InvalidCharacters() {
        let invalidInputs = [
            "INVALID0", // Contains '0'
            "INVALID1", // Contains '1'
            "INVALID8", // Contains '8'
            "INVALID9", // Contains '9'
            "MZXW6YTB!", // Contains '!'
            "MZXW6YTB@", // Contains '@'
        ]

        for invalidInput in invalidInputs {
            let decoded = Base32.decode(invalidInput)
            XCTAssertNil(decoded, "Decoding should fail for invalid input '\(invalidInput)'")
        }
    }

    func testBase32DataExtensionInvalidInput() {
        let invalidInputs = [
            "INVALID0",
            "MZXW6YTB!",
            "123456789"
        ]

        for invalidInput in invalidInputs {
            let decoded = Data(base32Encoded: invalidInput)
            XCTAssertNil(decoded, "Data extension should return nil for invalid input '\(invalidInput)'")
        }
    }

    // MARK: - OATH Secret Tests

    func testOathSecrets() {
        // Common OATH secrets used in testing
        let oathSecrets = [
            "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", // "12345678901234567890"
            "JBSWY3DPEHPK3PXP", // "Hello!‾™"
            "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA" // RFC 6238 test secret
        ]

        for secret in oathSecrets {
            let decoded = Data(base32Encoded: secret)
            XCTAssertNotNil(decoded, "OATH secret should decode successfully")
            XCTAssertTrue(decoded!.count > 0, "Decoded secret should not be empty")

            // Test round trip
            let reencoded = decoded!.base32EncodedString()
            let redecoded = Data(base32Encoded: reencoded)
            XCTAssertEqual(decoded, redecoded, "OATH secret round trip should work")
        }
    }

    // MARK: - Edge Cases

    func testBase32EdgeCases() {
        // Empty string
        XCTAssertEqual(Base32.decode(""), Data())
        XCTAssertEqual(Base32.encode(Data()), "")

        // Single character
        let singleChar = Data("A".utf8)
        let encoded = Base32.encode(singleChar)
        let decoded = Base32.decode(encoded)
        XCTAssertEqual(decoded, singleChar)

        // Large data
        let largeData = Data(repeating: 0xAB, count: 1000)
        let encodedLarge = Base32.encode(largeData)
        let decodedLarge = Base32.decode(encodedLarge)
        XCTAssertEqual(decodedLarge, largeData)
    }

    // MARK: - Performance Tests

    func testBase32EncodingPerformance() {
        let testData = Data(repeating: 0xAB, count: 10000)

        measure {
            _ = Base32.encode(testData)
        }
    }

    func testBase32DecodingPerformance() {
        let testData = Data(repeating: 0xAB, count: 10000)
        let encoded = Base32.encode(testData)

        measure {
            _ = Base32.decode(encoded)
        }
    }
}