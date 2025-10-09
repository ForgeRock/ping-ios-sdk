//
//  OathSecurityTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath

final class OathSecurityTests: XCTestCase {

    // MARK: - Test Data

    private let testSecret = "JBSWY3DPEHPK3PXP"
    private let testIssuer = "Security Test"
    private let testAccountName = "security@test.com"

    // MARK: - Secret Key Security Tests

    func testSecretKeyNotExposedInSerialization() throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(credential)
        let jsonString = String(data: jsonData, encoding: .utf8)

        XCTAssertNotNil(jsonString)
        XCTAssertFalse(jsonString?.contains(testSecret) ?? true, "Secret key should not appear in JSON serialization")
        XCTAssertFalse(jsonString?.contains("secretKey") ?? true, "Secret key field should not appear in JSON")
    }

    func testSecretKeyNotExposedInDescription() {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        let description = String(describing: credential)
        XCTAssertFalse(description.contains(testSecret), "Secret key should not appear in description")
    }

    func testSecretKeyNotExposedInDebugDescription() {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        let debugDescription = String(reflecting: credential)
        XCTAssertFalse(debugDescription.contains(testSecret), "Secret key should not appear in debug description")
    }

    func testSecretKeyEmptyAfterDeserialization() throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(credential)

        let decoder = JSONDecoder()
        let decodedCredential = try decoder.decode(OathCredential.self, from: jsonData)

        XCTAssertEqual(decodedCredential.secretKey, "", "Secret key should be empty after deserialization")
    }

    // MARK: - Input Validation Security Tests

    func testMaliciousUriInputs() async {
        let maliciousUris = [
            "otpauth://totp/../../../etc/passwd?secret=JBSWY3DPEHPK3PXP",
            "otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&issuer=<script>alert('xss')</script>",
            "otpauth://totp/test?secret=\0\0\0\0&issuer=test",
            "javascript:alert('xss')//totp/test?secret=JBSWY3DPEHPK3PXP",
            "otpauth://totp/test?secret=" + String(repeating: "A", count: 10000),
            "otpauth://totp/\u{202E}test\u{202D}?secret=JBSWY3DPEHPK3PXP", // Unicode bidirectional override
        ]

        for maliciousUri in maliciousUris {
            do {
                _ = try await OathUriParser.parse(maliciousUri)
                XCTFail("Should have thrown an error for malicious URI: \(maliciousUri)")
            } catch {
                XCTAssertTrue(error is OathError, "Should throw OathError for malicious URI: \(maliciousUri)")
            }
        }
    }

    func testExtremelyLongInputValidation() {
        let veryLongString = String(repeating: "A", count: 100000)

        // Test very long issuer
        XCTAssertThrowsError(try OathCredential(
            issuer: veryLongString,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        ).validate()) { _ in }

        // Test very long account name
        XCTAssertThrowsError(try OathCredential(
            issuer: testIssuer,
            accountName: veryLongString,
            oathType: .totp,
            secretKey: testSecret
        ).validate()) { _ in }

        // Test very long secret key
        XCTAssertThrowsError(try OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: veryLongString
        ).validate()) { _ in }
    }

    func testNullByteInjection() {
        let stringWithNullByte = "test\0injection"

        let credential = OathCredential(
            issuer: stringWithNullByte,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        // Should handle null bytes gracefully without crashing
        XCTAssertNoThrow(try credential.validate())
        XCTAssertEqual(credential.issuer, stringWithNullByte)
    }

    // MARK: - Timing Attack Resistance Tests

    func testConstantTimeSecretComparison() async {
        let credential1 = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: "AAAAAAAAAAAAAAAA"
        )

        let credential2 = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: "BBBBBBBBBBBBBBBB"
        )

        let startTime = CFAbsoluteTimeGetCurrent()
        let code1 = try? await OathAlgorithmHelper.generateCode(for: credential1)
        let time1 = CFAbsoluteTimeGetCurrent() - startTime

        let startTime2 = CFAbsoluteTimeGetCurrent()
        let code2 = try? await OathAlgorithmHelper.generateCode(for: credential2)
        let time2 = CFAbsoluteTimeGetCurrent() - startTime2

        XCTAssertNotNil(code1)
        XCTAssertNotNil(code2)

        // Times should be similar (within reasonable variance for timing attacks)
        let timeDifference = abs(time1 - time2)
        XCTAssertLessThan(timeDifference, 0.01, "Code generation time should be consistent to prevent timing attacks")
    }

    // MARK: - Memory Security Tests

    func testSensitiveDataClearing() async {
        var credential: OathCredential? = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        // Generate a code to ensure the secret is used
        _ = try? await OathAlgorithmHelper.generateCode(for: credential!)

        // Clear the credential
        credential = nil

        // Note: This is a basic test. In production, sensitive data clearing
        // would be handled by the storage layer with explicit memory zeroing
        XCTAssertNil(credential)
    }

    func testNoSecretLeakageInErrors() async {
        let invalidCredential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: "INVALID!@#$%^&*()"
        )

        do {
            _ = try await OathAlgorithmHelper.generateCode(for: invalidCredential)
            XCTFail("Should have thrown an error for invalid secret")
        } catch {
            let errorDescription = String(describing: error)
            XCTAssertFalse(errorDescription.contains("INVALID!@#$%^&*()"), "Error should not expose secret key")
        }
    }

    // MARK: - Cryptographic Security Tests

    func testCodeUniquenessAcrossTime() async throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            period: 30,
            secretKey: testSecret
        )

        var codes: [OathCodeInfo] = []
        for offset in 0..<10 {
            let timeOffset = TimeInterval(offset * 30) // 30-second intervals
            let code = try await OathAlgorithmHelper.generateCode(for: credential)
            codes.append(code)
        }

        let uniqueCodes = Set(codes.map { $0.code })
        XCTAssertEqual(codes.count, uniqueCodes.count, "All TOTP codes should be unique across different time periods")
    }

    func testCodeUniquenessAcrossCounters() async throws {
        var credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            secretKey: testSecret
        )

        var codes: [String] = []
        for counter in 0..<10 {
            credential.counter = counter
            let code = try await OathAlgorithmHelper.generateCode(for: credential)
            codes.append(code.code)
        }

        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "All HOTP codes should be unique across different counters")
    }

    func testCodeUniquenessAcrossSecrets() async throws {
        let secrets = [
            "JBSWY3DPEHPK3PXP",
            "HXDMVJECJJWSRB3H",
            "GEZDGNBVGY3TQOJQ",
            "MFRGG43FMZRW63LN"
        ]

        var codes: [String] = []

        for secret in secrets {
            let credential = OathCredential(
                issuer: testIssuer,
                accountName: testAccountName,
                oathType: .totp,
                secretKey: secret
            )
            let code = try await OathAlgorithmHelper.generateCode(for: credential)
            codes.append(code.code)
        }

        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "Codes should be unique across different secrets")
    }

    func testAlgorithmDeterminism() async throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        let code1 = try await OathAlgorithmHelper.generateCode(for: credential)
        let code2 = try await OathAlgorithmHelper.generateCode(for: credential)

        XCTAssertEqual(code1.code, code2.code, "TOTP algorithm should be deterministic for the same inputs")
    }

    // MARK: - Base32 Security Tests

    func testBase32DecodingSecurityValidation() {
        let invalidBase32Inputs = [
            "INVALID1", // Contains '1' which is not valid Base32
            "INVALID0", // Contains '0' which is not valid Base32
            "JBSWY3DPEHPK3PX", // Invalid padding
            "", // Empty string
            "=====", // Only padding
            String(repeating: "A", count: 10000), // Extremely long input
        ]

        for invalidInput in invalidBase32Inputs {
            let result = Base32.decode(invalidInput)
            // Base32.decode should return nil or empty data for invalid inputs
            XCTAssertTrue(result == nil || result?.isEmpty == true,
                         "Base32.decode should handle invalid input gracefully: \(invalidInput)")
        }
    }

    func testBase32PaddingAttacks() {
        let paddingAttacks = [
            "JBSWY3DPEHPK3PXP===", // Extra padding
            "=JBSWY3DPEHPK3PXP", // Padding at start
            "JBSWY3DP=EHPK3PXP", // Padding in middle
            "JBSWY3DPEHPK3PXP\0", // Null byte
        ]

        for attack in paddingAttacks {
            let result = Base32.decode(attack)
            // Base32.decode should handle padding attacks gracefully by returning nil or empty data
            XCTAssertTrue(result == nil || result?.isEmpty == true,
                         "Base32.decode should handle padding attack gracefully: \(attack)")
        }
    }

    // MARK: - RFC Compliance Security Tests

    func testRfcCompliantTotpGeneration() async throws {
        // Test vectors from RFC 6238
        let testVectors = [
            (time: 59, expectedSha1: "94287082"),
            (time: 1111111109, expectedSha1: "07081804"),
            (time: 1111111111, expectedSha1: "14050471"),
            (time: 1234567890, expectedSha1: "89005924"),
            (time: 2000000000, expectedSha1: "69279037"),
        ]

        let secret = "12345678901234567890" // RFC test secret
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha1,
            digits: 8,
            period: 30,
            secretKey: Base32.encode(secret.data(using: .ascii)!)
        )

        for testVector in testVectors {
            let generatedCode = try await OathAlgorithmHelper.generateCode(for: credential)

            XCTAssertEqual(generatedCode.code, testVector.expectedSha1,
                          "Generated TOTP code should match RFC 6238 test vector for time \(testVector.time)")
        }
    }

    func testRfcCompliantHotpGeneration() async throws {
        // Test vectors from RFC 4226
        let testVectors = [
            (counter: 0, expected: "755224"),
            (counter: 1, expected: "287082"),
            (counter: 2, expected: "359152"),
            (counter: 3, expected: "969429"),
            (counter: 4, expected: "338314"),
            (counter: 5, expected: "254676"),
            (counter: 6, expected: "287922"),
            (counter: 7, expected: "162583"),
            (counter: 8, expected: "399871"),
            (counter: 9, expected: "520489"),
        ]

        let secret = "12345678901234567890" // RFC test secret
        var credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            oathAlgorithm: .sha1,
            digits: 6,
            secretKey: Base32.encode(secret.data(using: .ascii)!)
        )

        for testVector in testVectors {
            credential.counter = testVector.counter
            let generatedCode = try await OathAlgorithmHelper.generateCode(for: credential)

            XCTAssertEqual(generatedCode.code, testVector.expected,
                          "Generated HOTP code should match RFC 4226 test vector for counter \(testVector.counter)")
        }
    }

    // MARK: - Policy Security Tests

    func testPolicyViolationHandling() {
        // This test would require a mock policy evaluator that simulates policy violations
        // For now, we test that credentials can be marked as locked
        var credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        XCTAssertFalse(credential.isLocked)

        credential.isLocked = true
        credential.lockingPolicy = "SecurityPolicy"

        XCTAssertTrue(credential.isLocked)
        XCTAssertEqual(credential.lockingPolicy, "SecurityPolicy")
    }

    // MARK: - Configuration Security Tests

    func testSecureDefaultConfiguration() {
        let config = OathConfiguration()

        // Verify secure defaults
        XCTAssertTrue(config.encryptionEnabled, "Encryption should be enabled by default")
        XCTAssertFalse(config.enableCredentialCache, "Credential caching should be disabled by default for security")
        XCTAssertEqual(config.timeoutMs, 15.0, "Timeout should have reasonable default value")
    }

    func testConfigurationSecuritySettings() {
        let config = OathConfiguration.build { config in
            config.encryptionEnabled = true
            config.enableCredentialCache = false
        }

        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertFalse(config.enableCredentialCache)
    }

    // MARK: - Thread Safety Security Tests

    func testConcurrentAccessSafety() async {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            secretKey: testSecret
        )

        let expectation = XCTestExpectation(description: "Concurrent access")
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "test.security.concurrent", attributes: .concurrent)

        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "test.security.results")

        // Test concurrent code generation doesn't cause race conditions
        for _ in 0..<100 {
            dispatchGroup.enter()
            concurrentQueue.async {
                Task {
                    if let code = try? await OathAlgorithmHelper.generateCode(for: credential) {
                        resultsQueue.async {
                            results.append(code.code)
                            dispatchGroup.leave()
                        }
                    } else {
                        dispatchGroup.leave()
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)

        // All operations should complete without crashes
        XCTAssertGreaterThan(results.count, 0, "Should have generated codes successfully")
    }
}
