//
//  OathAlgorithmHelperTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CommonCrypto
import CryptoKit
import PingMfaCommons

@testable import PingOath

final class OathAlgorithmHelperTests: XCTestCase {

    // MARK: - Test Properties

    /// RFC 4226 test secret (Base32 encoded)
    private let rfc4226Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

    /// RFC 6238 test secrets (Base32 encoded, different lengths for different algorithms)
    /// SHA1: 20 bytes (160 bits) - "12345678901234567890"
    private let rfc6238SecretSha1 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    /// SHA256: 32 bytes (256 bits) - "12345678901234567890123456789012"
    private let rfc6238SecretSha256 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA"
    /// SHA512: 64 bytes (512 bits) - extended base secret
    private let rfc6238SecretSha512 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA"

    // MARK: - RFC 4226 HOTP Test Vectors

    func testHotpRfc4226TestVectorsSha1() async throws {
        // RFC 4226 test vectors for HOTP
        let expectedCodes = [
            "755224", "287082", "359152", "969429", "338314",
            "254676", "287922", "162583", "399871", "520489"
        ]

        for (counter, expectedCode) in expectedCodes.enumerated() {
            let credential = OathCredential(
                issuer: "Test",
                accountName: "user@example.com",
                oathType: .hotp,
                oathAlgorithm: .sha1,
                digits: 6,
                counter: counter,
                secretKey: rfc4226Secret
            )

            let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)
            XCTAssertEqual(codeInfo.code, expectedCode, "HOTP code mismatch for counter \(counter)")
            XCTAssertEqual(codeInfo.counter, counter + 1, "Counter mismatch")
            XCTAssertEqual(codeInfo.timeRemaining, -1, "Time remaining should be -1 for HOTP")
        }
    }

    func testHotpRfc4226TestVectorsSha256() async throws {
        // RFC 4226 test vectors for HOTP
        let expectedCodes = [
            "212759", "582291", "208342", "982745", 
            "219752", "230137", "672139", "958477"
        ]

        for (counter, expectedCode) in expectedCodes.enumerated() {
            let credential = OathCredential(
                issuer: "Test",
                accountName: "user@example.com",
                oathType: .hotp,
                oathAlgorithm: .sha256,
                digits: 6,
                counter: counter,
                secretKey: "kjr6wxe5zsiml3v47dneo6rdiuompawngagaxwdm3ykhzjjvve4ksjpi"
            )

            let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)
            XCTAssertEqual(codeInfo.code, expectedCode, "HOTP code mismatch for counter \(counter)")
            XCTAssertEqual(codeInfo.counter, counter + 1, "Counter mismatch")
            XCTAssertEqual(codeInfo.timeRemaining, -1, "Time remaining should be -1 for HOTP")
        }
    }

    func testHotpMultipleTokensAtOnce() async throws {
        let credential1 = OathCredential(
            issuer: "Forgerock",
            accountName: "demo1",
            oathType: .hotp,
            oathAlgorithm: .sha256,
            digits: 6,
            counter: 0,
            secretKey: "IJQWIZ3FOIQUEYLE"
        )

        let credential2 = OathCredential(
            issuer: "Forgerock",
            accountName: "demo2",
            oathType: .hotp,
            oathAlgorithm: .sha256,
            digits: 6,
            counter: 0,
            secretKey: "IJQWIZ3FOI======"
        )

        let codeInfo1 = try await OathAlgorithmHelper.generateCode(for: credential1)
        XCTAssertEqual(codeInfo1.code, "185731", "OTP code mismatch")
        
        let codeInfo2 = try await OathAlgorithmHelper.generateCode(for: credential2)
        XCTAssertEqual(codeInfo2.code, "919304", "OTP code mismatch")
    }
    
    // MARK: - RFC 6238 TOTP Test Vectors

    func testTotpRfc6238TestVectorsSha1() async throws {
        // RFC 6238 test vectors for TOTP with SHA1
        let testCases: [(timestamp: Int64, expectedCode: String)] = [
            (59, "94287082"),
            (1111111109, "07081804"),
            (1111111111, "14050471"),
            (1234567890, "89005924"),
            (2000000000, "69279037"),
            (20000000000, "65353130")
        ]

        for testCase in testCases {
            let codeInfo = try generateTotpCodeForTimestamp(
                timestamp: testCase.timestamp,
                algorithm: .sha1,
                digits: 8,
                period: 30,
                secret: rfc6238SecretSha1
            )

            XCTAssertEqual(codeInfo.code, testCase.expectedCode,
                          "TOTP SHA1 code mismatch for timestamp \(testCase.timestamp)")
        }
    }

    func testTotpRfc6238TestVectorsSha256() async throws {
        // RFC 6238 test vectors for TOTP with SHA256
        let testCases: [(timestamp: Int64, expectedCode: String)] = [
            (59, "46119246"),
            (1111111109, "68084774"),
            (1111111111, "67062674"),
            (1234567890, "91819424"),
            (2000000000, "90698825"),
            (20000000000, "77737706")
        ]

        for testCase in testCases {
            let codeInfo = try generateTotpCodeForTimestamp(
                timestamp: testCase.timestamp,
                algorithm: .sha256,
                digits: 8,
                period: 30,
                secret: rfc6238SecretSha256
            )

            XCTAssertEqual(codeInfo.code, testCase.expectedCode,
                          "TOTP SHA256 code mismatch for timestamp \(testCase.timestamp)")
        }
    }

    func testTotpRfc6238TestVectorsSha512() async throws {
        // RFC 6238 test vectors for TOTP with SHA512
        let testCases: [(timestamp: Int64, expectedCode: String)] = [
            (59, "90693936"),
            (1111111109, "25091201"),
            (1111111111, "99943326"),
            (1234567890, "93441116"),
            (2000000000, "38618901"),
            (20000000000, "47863826")
        ]

        for testCase in testCases {
            let codeInfo = try generateTotpCodeForTimestamp(
                timestamp: testCase.timestamp,
                algorithm: .sha512,
                digits: 8,
                period: 30,
                secret: rfc6238SecretSha512
            )

            XCTAssertEqual(codeInfo.code, testCase.expectedCode,
                          "TOTP SHA512 code mismatch for timestamp \(testCase.timestamp)")
        }
    }

    // MARK: - Edge Cases and Error Handling

    func testInvalidSecret() async throws {
        let credential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "INVALID_BASE32!"
        )

        do {
            _ = try await OathAlgorithmHelper.generateCode(for: credential)
            XCTFail("Should have thrown an error for invalid secret")
        } catch let error as OathError {
            if case .invalidSecret = error {
                // Expected error
            } else {
                XCTFail("Expected invalidSecret error, got \(error)")
            }
        }
    }

    func testEmptySecret() async throws {
        let credential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: ""
        )

        do {
            _ = try await OathAlgorithmHelper.generateCode(for: credential)
            XCTFail("Should have thrown an error for empty secret")
        } catch let error as OathError {
            if case .invalidSecret = error {
                // Expected error
            } else {
                XCTFail("Expected invalidSecret error, got \(error)")
            }
        }
    }

    func testCredentialValidation() throws {
        // Test valid credential
        let validCredential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            digits: 6,
            period: 30,
            secretKey: rfc4226Secret
        )

        XCTAssertNoThrow(try OathAlgorithmHelper.validateCredential(validCredential))

        // Test invalid digits
        let invalidDigitsCredential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            digits: 10, // Invalid
            period: 30,
            secretKey: rfc4226Secret
        )

        XCTAssertThrowsError(try OathAlgorithmHelper.validateCredential(invalidDigitsCredential))

        // Test invalid period
        let invalidPeriodCredential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            digits: 6,
            period: 500, // Invalid
            secretKey: rfc4226Secret
        )

        XCTAssertThrowsError(try OathAlgorithmHelper.validateCredential(invalidPeriodCredential))
    }

    // MARK: - Code Info Validation

    func testTotpCodeInfo() async throws {
        let credential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            digits: 6,
            period: 30,
            secretKey: rfc4226Secret
        )

        let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)

        XCTAssertEqual(codeInfo.code.count, 6, "Code should have 6 digits")
        XCTAssertTrue(codeInfo.timeRemaining > 0, "Time remaining should be positive")
        XCTAssertTrue(codeInfo.timeRemaining <= 30, "Time remaining should not exceed period")
        XCTAssertEqual(codeInfo.totalPeriod, 30, "Total period should match credential")
        XCTAssertEqual(codeInfo.counter, -1, "Counter should be -1 for TOTP")
        XCTAssertTrue(codeInfo.progress >= 0.0 && codeInfo.progress <= 1.0, "Progress should be between 0 and 1")
    }

    func testHotpCodeInfo() async throws {
        let credential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .hotp,
            digits: 6,
            counter: 5,
            secretKey: rfc4226Secret
        )

        let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)

        XCTAssertEqual(codeInfo.code.count, 6, "Code should have 6 digits")
        XCTAssertEqual(codeInfo.counter, 6, "Counter should be incremented")
        XCTAssertEqual(codeInfo.timeRemaining, -1, "Time remaining should be -1 for HOTP")
        XCTAssertEqual(codeInfo.totalPeriod, 0, "Total period should be 0 for HOTP")
        XCTAssertEqual(codeInfo.progress, 0.0, "Progress should be 0 for HOTP")
    }

    // MARK: - Different Algorithms and Digits

    func testDifferentDigits() async throws {
        for digits in 4...8 {
            let credential = OathCredential(
                issuer: "Test",
                accountName: "user@example.com",
                oathType: .totp,
                digits: digits,
                secretKey: rfc4226Secret
            )

            let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)
            XCTAssertEqual(codeInfo.code.count, digits, "Code should have \(digits) digits")

            // Verify all characters are digits
            XCTAssertTrue(codeInfo.code.allSatisfy { $0.isNumber }, "Code should only contain digits")
        }
    }

    func testDifferentAlgorithms() async throws {
        for algorithm in OathAlgorithm.allCases {
            let credential = OathCredential(
                issuer: "Test",
                accountName: "user@example.com",
                oathType: .totp,
                oathAlgorithm: algorithm,
                secretKey: rfc4226Secret
            )

            let codeInfo = try await OathAlgorithmHelper.generateCode(for: credential)
            XCTAssertEqual(codeInfo.code.count, 6, "Code should have 6 digits for \(algorithm)")
            XCTAssertTrue(codeInfo.code.allSatisfy { $0.isNumber }, "Code should only contain digits for \(algorithm)")
        }
    }

    // MARK: - Time Helper Tests

    func testTimeHelpers() {
        let period = 30

        let currentStep = OathAlgorithmHelper.getCurrentTimeStep(period: period)
        XCTAssertTrue(currentStep > 0, "Current time step should be positive")

        let timeRemaining = OathAlgorithmHelper.getTimeRemaining(period: period)
        XCTAssertTrue(timeRemaining > 0 && timeRemaining <= period, "Time remaining should be valid")

        let progress = OathAlgorithmHelper.getTotpProgress(period: period)
        XCTAssertTrue(progress >= 0.0 && progress <= 1.0, "Progress should be between 0 and 1")

        // Verify relationship between time remaining and progress
        let expectedProgress = 1.0 - (Double(timeRemaining) / Double(period))
        XCTAssertEqual(progress, expectedProgress, accuracy: 0.001, "Progress calculation should be accurate")
    }

    // MARK: - Performance Tests

    func testCodeGenerationPerformance() async throws {
        let credential = OathCredential(
            issuer: "Test",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: rfc4226Secret
        )

        measure {
            let exp = expectation(description: "perf")
            Task {
                do {
                    _ = try await OathAlgorithmHelper.generateCode(for: credential)
                } catch {
                    XCTFail("Code generation failed: \(error)")
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 1.0)
        }
    }

    // MARK: - Helper Methods

    /// Generate a TOTP code for a specific timestamp (for testing RFC vectors)
    private func generateTotpCodeForTimestamp(
        timestamp: Int64,
        algorithm: OathAlgorithm,
        digits: Int,
        period: Int,
        secret: String
    ) throws -> OathCodeInfo {
        // Calculate the time step
        let timeStep = timestamp / Int64(period)

        // Mock the current time by calculating what the code would be at that timestamp
        // Use the same logic as production code
        let secretData = Data(base32Encoded: secret)!

        // Convert counter to 8-byte big-endian data (matching production code)
        let counterUInt64 = UInt64(timeStep)
        let counterData = counterUInt64.bigEndian.data

        // Use internal helper to generate HMAC
        let hmacData = try OathAlgorithmHelper.hmac(algorithm: algorithm, key: secretData, data: counterData)

        // Dynamic truncation (RFC 4226) - matching production code approach
        var truncated = hmacData.withUnsafeBytes { pointer -> UInt32 in
            let offset = pointer[hmacData.count - 1] & 0x0f
            let truncatedHmac = pointer.baseAddress! + Int(offset)
            return truncatedHmac.bindMemory(to: UInt32.self, capacity: 1).pointee
        }

        // Convert from big-endian and apply mask
        truncated = UInt32(bigEndian: truncated)
        let discard = truncated & 0x7fffffff

        // Generate the final code with appropriate number of digits (matching production code)
        let modulus = UInt32(pow(10, Float(digits)))
        let tmpCode = String(discard % modulus)

        // Add leading zeros if necessary (matching production code)
        let codeString: String
        if (digits - tmpCode.count) > 0 {
            codeString = String(repeating: "0", count: (digits - tmpCode.count)) + tmpCode
        } else {
            codeString = tmpCode
        }

        // Calculate time remaining (for the test, just use remaining time in period)
        let timeInPeriod = timestamp % Int64(period)
        let timeRemaining = Int(Int64(period) - timeInPeriod)

        return OathCodeInfo.forTotp(
            code: codeString,
            timeRemaining: timeRemaining,
            totalPeriod: period
        )
    }

}

// MARK: - UInt64 Extension for Testing

/// Extension to match production code data conversion behavior
extension UInt64 {
    /// Data converted from UInt64 (matching production code format)
    var data: Data {
        var int = self
        let intData = Data(bytes: &int, count: MemoryLayout.size(ofValue: self))
        return intData
    }
}
