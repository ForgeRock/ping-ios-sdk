//
//  OathUriParserTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath
@testable import PingCommons

final class OathUriParserTests: XCTestCase {

    // MARK: - Basic TOTP Parsing Tests

    func testParseBasicTotpUri() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA1&digits=6&period=30"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.displayIssuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.displayAccountName, "user@example.com")
        XCTAssertEqual(credential.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(credential.oathType, .totp)
        XCTAssertEqual(credential.oathAlgorithm, .sha1)
        XCTAssertEqual(credential.digits, 6)
        XCTAssertEqual(credential.period, 30)
        XCTAssertEqual(credential.counter, 0)
    }

    func testParseBasicHotpUri() async throws {
        let uri = "otpauth://hotp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA1&digits=6&counter=1"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(credential.oathType, .hotp)
        XCTAssertEqual(credential.oathAlgorithm, .sha1)
        XCTAssertEqual(credential.digits, 6)
        XCTAssertEqual(credential.counter, 1)
    }

    func testParseMfauthScheme() async throws {
        let uri = "mfauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=RXhhbXBsZQ"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(credential.oathType, .totp)
    }

    // MARK: - Algorithm Tests

    func testParseWithSha256Algorithm() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.oathAlgorithm, .sha256)
    }

    func testParseWithSha512Algorithm() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA512"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.oathAlgorithm, .sha512)
    }

    func testParseWithDefaultAlgorithm() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.oathAlgorithm, .sha1)
    }

    // MARK: - Digits Tests

    func testParseWithCustomDigits() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&digits=8"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.digits, 8)
    }

    func testParseWithDefaultDigits() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.digits, 6)
    }

    // MARK: - Period Tests

    func testParseWithCustomPeriod() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&period=60"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.period, 60)
    }

    func testParseWithDefaultPeriod() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.period, 30)
    }

    // MARK: - Additional Parameters Tests

    func testParseWithBase64UserId() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&uid=dXNlcjEyMw"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.userId, "user123")
    }

    func testParseWithResourceId() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&oid=ZGV2aWNlLTEyMzQ1"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.resourceId, "device-12345")
    }

    func testParseWithImageUrl() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&image=https://example.com/logo.png"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.imageURL, "https://example.com/logo.png")
    }

    func testParseWithBackgroundColor() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&b=FF0000"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.backgroundColor, "FF0000")
    }

    func testParseWithBackgroundColorHash() async throws {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&b=%23FF0000"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.backgroundColor, "FF0000")
    }

    // MARK: - Label Parsing Tests

    func testParseLabelWithoutIssuer() async throws {
        let uri = "otpauth://totp/user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.accountName, "user@example.com")
    }

    func testParseLabelWithUrlEncoding() async throws {
        let uri = "otpauth://totp/Example%20Corp:user%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example%20Corp"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "Example Corp")
        XCTAssertEqual(credential.accountName, "user@example.com")
    }

    // MARK: - Base64 Encoded Parameters for MfAuth

    func testParseMfauthWithBase64EncodedResourceId() async throws {
        let uri = "mfauth://totp/Example:user?secret=JBSWY3DPEHPK3PXP&issuer=RXhhbXBsZQ" +
        "&uid=YWxpY2VAdGVzdC5jb20=&oid=ZGV2aWNlLTEyMzQ1"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "Example")
        XCTAssertEqual(credential.resourceId, "device-12345")
        XCTAssertEqual(credential.userId, "alice@test.com")
        XCTAssertEqual(credential.accountName, "user")
    }

    // MARK: - Error Handling Tests

    func testParseInvalidScheme() async {
        let uri = "https://example.com/path?secret=JBSWY3DPEHPK3PXP"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidUri error")
        } catch let error as OathError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("scheme"))
            } else {
                XCTFail("Expected invalidUri error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseMissingSecret() async {
        let uri = "otpauth://totp/Example:user@example.com?issuer=Example"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected missingRequiredParameter error")
        } catch let error as OathError {
            if case .missingRequiredParameter(let message) = error {
                XCTAssertTrue(message.contains("secret"))
            } else {
                XCTFail("Expected missingRequiredParameter error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseEmptySecret() async {
        let uri = "otpauth://totp/Example:user@example.com?secret=&issuer=Example"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected missingRequiredParameter error")
        } catch let error as OathError {
            if case .missingRequiredParameter = error {
                // Expected
            } else {
                XCTFail("Expected missingRequiredParameter error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseInvalidOathType() async {
        let uri = "otpauth://invalid/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidUri error")
        } catch let error as OathError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("type"))
            } else {
                XCTFail("Expected invalidUri error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseInvalidDigits() async {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&digits=2"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidParameterValue error")
        } catch let error as OathError {
            if case .invalidParameterValue(let message) = error {
                XCTAssertTrue(message.contains("digits"))
            } else {
                XCTFail("Expected invalidParameterValue error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseInvalidPeriod() async {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&period=0"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidParameterValue error")
        } catch let error as OathError {
            if case .invalidParameterValue(let message) = error {
                XCTAssertTrue(message.contains("period"))
            } else {
                XCTFail("Expected invalidParameterValue error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseInvalidAlgorithm() async {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=MD5"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidAlgorithm error")
        } catch let error as OathError {
            if case .invalidAlgorithm = error {
                // Expected
            } else {
                XCTFail("Expected invalidAlgorithm error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseMissingLabel() async {
        let uri = "otpauth://totp/?secret=JBSWY3DPEHPK3PXP&issuer=Example"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidUri error")
        } catch let error as OathError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("label"))
            } else {
                XCTFail("Expected invalidUri error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseMalformedUrl() async {
        let uri = "not a valid url"

        do {
            _ = try await OathUriParser.parse(uri)
            XCTFail("Expected invalidUri error")
        } catch let error as OathError {
            if case .invalidUri = error {
                // Expected
            } else {
                XCTFail("Expected invalidUri error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Format Tests

    func testFormatBasicTotpCredential() async throws {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            oathAlgorithm: .sha1,
            digits: 6,
            period: 30,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let uri = try await OathUriParser.format(credential)

        XCTAssertTrue(uri.hasPrefix("otpauth://totp/"))
        XCTAssertTrue(uri.contains("secret=JBSWY3DPEHPK3PXP"))
        XCTAssertTrue(uri.contains("issuer=Example"))
        XCTAssertFalse(uri.contains("algorithm=")) // Default SHA1 should be omitted
        XCTAssertFalse(uri.contains("digits=")) // Default 6 should be omitted
        XCTAssertFalse(uri.contains("period=")) // Default 30 should be omitted
    }

    func testFormatBasicHotpCredential() async throws {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .hotp,
            oathAlgorithm: .sha1,
            digits: 6,
            counter: 5,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let uri = try await OathUriParser.format(credential)

        XCTAssertTrue(uri.hasPrefix("otpauth://hotp/"))
        XCTAssertTrue(uri.contains("secret=JBSWY3DPEHPK3PXP"))
        XCTAssertTrue(uri.contains("counter=5"))
    }

    func testFormatWithNonDefaultParameters() async throws {
        let credential = OathCredential(
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            oathAlgorithm: .sha256,
            digits: 8,
            period: 60,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let uri = try await OathUriParser.format(credential)

        XCTAssertTrue(uri.contains("algorithm=SHA256"))
        XCTAssertTrue(uri.contains("digits=8"))
        XCTAssertTrue(uri.contains("period=60"))
    }

    func testFormatWithAdditionalParameters() async throws {
        let credential = OathCredential(
            userId: "user123",
            resourceId: "resource123",
            issuer: "Example",
            accountName: "user@example.com",
            oathType: .totp,
            imageURL: "https://example.com/logo.png",
            backgroundColor: "FF0000",
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let uri = try await OathUriParser.format(credential)

        XCTAssertTrue(uri.contains("uid="))
        XCTAssertTrue(uri.contains("oid=cmVzb3VyY2UxMjM"))
        XCTAssertTrue(uri.contains("image=https://example.com/logo.png"))
        XCTAssertTrue(uri.contains("b=FF0000"))
    }

    func testFormatWithUrlEncodedLabel() async throws {
        let credential = OathCredential(
            issuer: "Example Corp",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let uri = try await OathUriParser.format(credential)

        XCTAssertTrue(uri.contains("Example%20Corp"))
        XCTAssertTrue(uri.contains("user%40example.com"))
    }

    func testFormatWithEmptyIssuer() async throws {
        let credential = OathCredential(
            issuer: "",
            accountName: "user@example.com",
            oathType: .totp,
            secretKey: "JBSWY3DPEHPK3PXP"
        )

        let uri = try await OathUriParser.format(credential)

        // Should only contain account name in path, no colon
        XCTAssertTrue(uri.contains("/user%40example.com?"))
        XCTAssertFalse(uri.contains("issuer="))
    }

    // MARK: - Round Trip Tests

    func testRoundTripBasicTotp() async throws {
        let originalUri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256&digits=8&period=60"

        let credential = try await OathUriParser.parse(originalUri)
        let formattedUri = try await OathUriParser.format(credential)
        let reparsedCredential = try await OathUriParser.parse(formattedUri)

        XCTAssertEqual(credential.issuer, reparsedCredential.issuer)
        XCTAssertEqual(credential.accountName, reparsedCredential.accountName)
        XCTAssertEqual(credential.secret, reparsedCredential.secret)
        XCTAssertEqual(credential.oathType, reparsedCredential.oathType)
        XCTAssertEqual(credential.oathAlgorithm, reparsedCredential.oathAlgorithm)
        XCTAssertEqual(credential.digits, reparsedCredential.digits)
        XCTAssertEqual(credential.period, reparsedCredential.period)
    }

    func testRoundTripBasicHotp() async throws {
        let originalUri = "otpauth://hotp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&counter=10"

        let credential = try await OathUriParser.parse(originalUri)
        let formattedUri = try await OathUriParser.format(credential)
        let reparsedCredential = try await OathUriParser.parse(formattedUri)

        XCTAssertEqual(credential.issuer, reparsedCredential.issuer)
        XCTAssertEqual(credential.accountName, reparsedCredential.accountName)
        XCTAssertEqual(credential.secret, reparsedCredential.secret)
        XCTAssertEqual(credential.oathType, reparsedCredential.oathType)
        XCTAssertEqual(credential.counter, reparsedCredential.counter)
    }

    func testRoundTripWithAdditionalParameters() async throws {
        let originalUri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&uid=dXNlcjEyMw&oid=ZGV2aWNlLTEyMzQ1&image=https://example.com/logo.png&b=FF0000"

        let credential = try await OathUriParser.parse(originalUri)
        let formattedUri = try await OathUriParser.format(credential)
        let reparsedCredential = try await OathUriParser.parse(formattedUri)

        XCTAssertEqual(credential.userId, reparsedCredential.userId)
        XCTAssertEqual(credential.resourceId, reparsedCredential.resourceId)
        XCTAssertEqual(credential.imageURL, reparsedCredential.imageURL)
        XCTAssertEqual(credential.backgroundColor, reparsedCredential.backgroundColor)
    }

    // MARK: - RFC Test Vectors

    func testRfcTestVectorTotp() async throws {
        // Test vector from RFC 6238 appendix B
        let uri = "otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA1&digits=6&period=30"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "ACME Co")
        XCTAssertEqual(credential.accountName, "john.doe@email.com")
        XCTAssertEqual(credential.secret, "HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ")
        XCTAssertEqual(credential.oathType, .totp)
        XCTAssertEqual(credential.oathAlgorithm, .sha1)
        XCTAssertEqual(credential.digits, 6)
        XCTAssertEqual(credential.period, 30)
    }

    func testRfcTestVectorHotp() async throws {
        // Test vector from RFC 4226
        let uri = "otpauth://hotp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA1&digits=6&counter=1"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "ACME Co")
        XCTAssertEqual(credential.accountName, "john.doe@email.com")
        XCTAssertEqual(credential.secret, "HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ")
        XCTAssertEqual(credential.oathType, .hotp)
        XCTAssertEqual(credential.oathAlgorithm, .sha1)
        XCTAssertEqual(credential.digits, 6)
        XCTAssertEqual(credential.counter, 1)
    }

    // MARK: - Malformed Padding Compatibility Tests (FRAuthenticator)

    func testUriParsingWithMalformedPadding() async throws {
        // Test the primary failing URI from FRAuthenticator compatibility issue
        // This secret has malformed padding: 25 base32 chars + 6 padding = 31 total (not multiple of 8)
        let uri = "otpauth://totp/ACME:Elmer.Fudd?secret=HNEZ2W7D462P3JYDG2HV7PFBM======&image=https://upload.wikimedia.org/wikipedia/commons/6/6e/Acme-corp.png"

        let credential = try await OathUriParser.parse(uri)

        XCTAssertEqual(credential.issuer, "ACME")
        XCTAssertEqual(credential.accountName, "Elmer.Fudd")
        XCTAssertEqual(credential.secret, "HNEZ2W7D462P3JYDG2HV7PFBM======")
        XCTAssertEqual(credential.oathType, .totp)
        XCTAssertEqual(credential.imageURL, "https://upload.wikimedia.org/wikipedia/commons/6/6e/Acme-corp.png")

        // Verify secret can be decoded despite malformed padding
        let secretData = Base32.decode(credential.secret, strict: false)
        XCTAssertNotNil(secretData, "Secret with malformed padding should decode in lenient mode")
        XCTAssertGreaterThan(secretData?.count ?? 0, 0, "Decoded secret should not be empty")
    }

    func testUriParsingWithVariousMalformedPadding() async throws {
        // Test various malformed padding scenarios
        let testCases = [
            ("otpauth://totp/Test:user1?secret=JBSWY3DPEHPK3PXP==&issuer=Test", "2 char padding (18 total)"),
            ("otpauth://totp/Test:user2?secret=JBSWY3DPE=====&issuer=Test", "5 char padding (14 total)"),
            ("otpauth://totp/Test:user3?secret=JBSWY3D=======&issuer=Test", "7 char padding (14 total)"),
        ]

        for (uri, description) in testCases {
            let credential = try await OathUriParser.parse(uri)

            XCTAssertEqual(credential.issuer, "Test", "Issuer should be parsed correctly: \(description)")
            XCTAssertTrue(credential.accountName.hasPrefix("user"), "Account name should be parsed correctly: \(description)")

            // Verify secret can be decoded despite malformed padding
            let secretData = Base32.decode(credential.secret, strict: false)
            XCTAssertNotNil(secretData, "Secret should decode in lenient mode: \(description)")
        }
    }

    func testUriRoundTripWithMalformedPadding() async throws {
        // Parse URI with malformed padding
        let originalUri = "otpauth://totp/ACME:test@example.com?secret=HNEZ2W7D462P3JYDG2HV7PFBM======&issuer=ACME"

        let credential = try await OathUriParser.parse(originalUri)

        // Format back to URI
        let formattedUri = try await OathUriParser.format(credential)

        // Reparse formatted URI
        let reparsedCredential = try await OathUriParser.parse(formattedUri)

        // Verify all fields match
        XCTAssertEqual(credential.issuer, reparsedCredential.issuer)
        XCTAssertEqual(credential.accountName, reparsedCredential.accountName)
        XCTAssertEqual(credential.secret, reparsedCredential.secret)
        XCTAssertEqual(credential.oathType, reparsedCredential.oathType)

        // Verify both secrets can be decoded
        let originalSecretData = Base32.decode(credential.secret, strict: false)
        let reparsedSecretData = Base32.decode(reparsedCredential.secret, strict: false)
        XCTAssertNotNil(originalSecretData)
        XCTAssertNotNil(reparsedSecretData)
        XCTAssertEqual(originalSecretData, reparsedSecretData, "Decoded secrets should match after round trip")
    }
}
