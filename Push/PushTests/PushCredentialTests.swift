//
//  PushCredentialTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushCredentialTests: XCTestCase {
    
    // MARK: - Creation Tests
    
    func testInitializationWithMinimalParameters() {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123"
        )
        
        XCTAssertFalse(credential.id.isEmpty)
        XCTAssertNil(credential.userId)
        XCTAssertEqual(credential.resourceId, credential.id) // Defaults to id
        XCTAssertEqual(credential.issuer, "MyCompany")
        XCTAssertEqual(credential.displayIssuer, "MyCompany") // Defaults to issuer
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.displayAccountName, "user@example.com") // Defaults to accountName
        XCTAssertEqual(credential.serverEndpoint, "https://am.example.com/push")
        XCTAssertNotNil(credential.createdAt)
        XCTAssertNil(credential.imageURL)
        XCTAssertNil(credential.backgroundColor)
        XCTAssertNil(credential.policies)
        XCTAssertNil(credential.lockingPolicy)
        XCTAssertFalse(credential.isLocked)
        XCTAssertEqual(credential.platform, .pingAM)
        XCTAssertNil(credential.additionalData)
    }
    
    func testInitializationWithAllParameters() {
        let id = "credential-123"
        let userId = "user-456"
        let resourceId = "device-789"
        let createdAt = Date(timeIntervalSince1970: 1609459200)
        let additionalData: [String: Any] = ["key": "value", "number": 42]
        
        let credential = PushCredential(
            id: id,
            userId: userId,
            resourceId: resourceId,
            issuer: "MyCompany",
            displayIssuer: "My Company Inc.",
            accountName: "user@example.com",
            displayAccountName: "John Doe",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123",
            createdAt: createdAt,
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF5733",
            policies: "{\"policy\":\"value\"}",
            lockingPolicy: "JailbreakPolicy",
            isLocked: true,
            platform: .pingAM,
            additionalData: additionalData
        )
        
        XCTAssertEqual(credential.id, id)
        XCTAssertEqual(credential.userId, userId)
        XCTAssertEqual(credential.resourceId, resourceId)
        XCTAssertEqual(credential.issuer, "MyCompany")
        XCTAssertEqual(credential.displayIssuer, "My Company Inc.")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.displayAccountName, "John Doe")
        XCTAssertEqual(credential.serverEndpoint, "https://am.example.com/push")
        XCTAssertEqual(credential.createdAt, createdAt)
        XCTAssertEqual(credential.imageURL, "https://example.com/logo.png")
        XCTAssertEqual(credential.backgroundColor, "#FF5733")
        XCTAssertEqual(credential.policies, "{\"policy\":\"value\"}")
        XCTAssertEqual(credential.lockingPolicy, "JailbreakPolicy")
        XCTAssertTrue(credential.isLocked)
        XCTAssertEqual(credential.platform, .pingAM)
        XCTAssertNotNil(credential.additionalData)
    }
    
    // MARK: - Computed Properties Tests
    
    func testRegistrationEndpoint() {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123"
        )
        
        XCTAssertEqual(credential.registrationEndpoint, "https://am.example.com/push?_action=register")
    }
    
    func testAuthenticationEndpoint() {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123"
        )
        
        XCTAssertEqual(credential.authenticationEndpoint, "https://am.example.com/push?_action=authenticate")
    }
    
    func testUpdateEndpoint() {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123"
        )
        
        XCTAssertEqual(credential.updateEndpoint, "https://am.example.com/push?_action=refresh")
    }
    
    // MARK: - Policy Methods Tests
    
    func testLockCredential() {
        var credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123"
        )
        
        XCTAssertFalse(credential.isLocked)
        XCTAssertNil(credential.lockingPolicy)
        
        credential.lockCredential(policyName: "JailbreakPolicy")
        
        XCTAssertTrue(credential.isLocked)
        XCTAssertEqual(credential.lockingPolicy, "JailbreakPolicy")
    }
    
    func testUnlockCredential() {
        var credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123",
            lockingPolicy: "JailbreakPolicy",
            isLocked: true
        )
        
        XCTAssertTrue(credential.isLocked)
        XCTAssertEqual(credential.lockingPolicy, "JailbreakPolicy")
        
        credential.unlockCredential()
        
        XCTAssertFalse(credential.isLocked)
        XCTAssertNil(credential.lockingPolicy)
    }
    
    // MARK: - Encoding Tests
    
    func testEncoding() throws {
        let credential = PushCredential(
            id: "credential-123",
            userId: "user-456",
            resourceId: "device-789",
            issuer: "MyCompany",
            displayIssuer: "My Company Inc.",
            accountName: "user@example.com",
            displayAccountName: "John Doe",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123",
            createdAt: Date(timeIntervalSince1970: 1609459200),
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF5733",
            policies: "{\"policy\":\"value\"}",
            lockingPolicy: nil,
            isLocked: false,
            platform: .pingAM
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(credential)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["id"] as? String, "credential-123")
        XCTAssertEqual(json?["userId"] as? String, "user-456")
        XCTAssertEqual(json?["issuer"] as? String, "MyCompany")
        XCTAssertEqual(json?["accountName"] as? String, "user@example.com")
        XCTAssertEqual(json?["serverEndpoint"] as? String, "https://am.example.com/push")
        XCTAssertEqual(json?["isLocked"] as? Bool, false)
    }
    
    // MARK: - Decoding Tests
    
    func testDecoding() throws {
        let json = """
        {
            "id": "credential-123",
            "userId": "user-456",
            "resourceId": "device-789",
            "issuer": "MyCompany",
            "displayIssuer": "My Company Inc.",
            "accountName": "user@example.com",
            "displayAccountName": "John Doe",
            "serverEndpoint": "https://am.example.com/push",
            "sharedSecret": "secretKey123",
            "createdAt": 1609459200,
            "imageURL": "https://example.com/logo.png",
            "backgroundColor": "#FF5733",
            "policies": "{\\"policy\\":\\"value\\"}",
            "lockingPolicy": null,
            "isLocked": false,
            "platform": "pingam"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let credential = try decoder.decode(PushCredential.self, from: data)
        
        XCTAssertEqual(credential.id, "credential-123")
        XCTAssertEqual(credential.userId, "user-456")
        XCTAssertEqual(credential.resourceId, "device-789")
        XCTAssertEqual(credential.issuer, "MyCompany")
        XCTAssertEqual(credential.displayIssuer, "My Company Inc.")
        XCTAssertEqual(credential.accountName, "user@example.com")
        XCTAssertEqual(credential.displayAccountName, "John Doe")
        XCTAssertEqual(credential.serverEndpoint, "https://am.example.com/push")
        XCTAssertEqual(credential.imageURL, "https://example.com/logo.png")
        XCTAssertEqual(credential.backgroundColor, "#FF5733")
        XCTAssertEqual(credential.policies, "{\"policy\":\"value\"}")
        XCTAssertNil(credential.lockingPolicy)
        XCTAssertFalse(credential.isLocked)
        XCTAssertEqual(credential.platform, .pingAM)
    }
    
    func testRoundTripEncoding() throws {
        let original = PushCredential(
            id: "credential-123",
            userId: "user-456",
            resourceId: "device-789",
            issuer: "MyCompany",
            displayIssuer: "My Company Inc.",
            accountName: "user@example.com",
            displayAccountName: "John Doe",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123",
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF5733",
            policies: "{\"policy\":\"value\"}",
            lockingPolicy: "JailbreakPolicy",
            isLocked: true,
            platform: .pingAM
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PushCredential.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.resourceId, original.resourceId)
        XCTAssertEqual(decoded.issuer, original.issuer)
        XCTAssertEqual(decoded.displayIssuer, original.displayIssuer)
        XCTAssertEqual(decoded.accountName, original.accountName)
        XCTAssertEqual(decoded.displayAccountName, original.displayAccountName)
        XCTAssertEqual(decoded.serverEndpoint, original.serverEndpoint)
        XCTAssertEqual(decoded.isLocked, original.isLocked)
        XCTAssertEqual(decoded.lockingPolicy, original.lockingPolicy)
        XCTAssertEqual(decoded.platform, original.platform)
    }
    
    // MARK: - CustomStringConvertible Tests
    
    func testDescription() {
        let credential = PushCredential(
            id: "credential-123",
            issuer: "MyCompany",
            displayIssuer: "My Company Inc.",
            accountName: "user@example.com",
            displayAccountName: "John Doe",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123",
            isLocked: false
        )
        
        let description = credential.description
        XCTAssertTrue(description.contains("credential-123"))
        XCTAssertTrue(description.contains("My Company Inc."))
        XCTAssertTrue(description.contains("John Doe"))
        XCTAssertTrue(description.contains("pingam"))
        XCTAssertTrue(description.contains("false"))
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "secretKey123"
        )
        
        await Task {
            XCTAssertEqual(credential.issuer, "MyCompany")
        }.value
    }
    
    // MARK: - URI Factory Tests
    
    func testFromUriWithMinimalParameters() async throws {
        // pushauth:// URI with only required parameters
        // Using the same format as the PushUriParserTests
        let uri = "pushauth://push/MyCompany:user?a=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249YXV0aGVudGljYXRl&r=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249cmVnaXN0ZXI&s=c2hhcmVkU2VjcmV0VmFsdWU"
        
        let credential = try await PushCredential.fromUri(uri)
        
        XCTAssertEqual(credential.issuer, "MyCompany")
        XCTAssertEqual(credential.accountName, "user")
        XCTAssertEqual(credential.serverEndpoint, "http://example.com/endpoint")
        XCTAssertEqual(credential.platform, .pingAM)
        XCTAssertNil(credential.userId)
        XCTAssertNil(credential.imageURL)
        XCTAssertNil(credential.backgroundColor)
    }
    
    func testFromUriWithAllParameters() async throws {
        // Create a fully-featured pushauth URI with all optional parameters
        let uri = """
        pushauth://push/ForgeRock:john.doe@example.com?\
        r=aHR0cHM6Ly9hbS5leGFtcGxlLmNvbS9wdXNoP19hY3Rpb249cmVnaXN0ZXI%3D&\
        a=aHR0cHM6Ly9hbS5leGFtcGxlLmNvbS9wdXNoP19hY3Rpb249YXV0aGVudGljYXRl&\
        s=c2VjcmV0S2V5MTIz&\
        d=dXNlci00NTY%3D&\
        pid=ZGV2aWNlLTc4OQ%3D%3D&\
        image=aHR0cHM6Ly9leGFtcGxlLmNvbS9sb2dvLnBuZw%3D%3D&\
        b=FF5733&\
        policies=eyJwb2xpY3kiOiJ2YWx1ZSJ9&\
        issuer=ForgeRock
        """
        
        let credential = try await PushCredential.fromUri(uri)
        
        XCTAssertEqual(credential.issuer, "ForgeRock")
        XCTAssertEqual(credential.accountName, "john.doe@example.com")
        XCTAssertTrue(credential.serverEndpoint.contains("https://am.example.com/push"))
        XCTAssertEqual(credential.userId, "user-456")
        XCTAssertEqual(credential.resourceId, "device-789")
        XCTAssertEqual(credential.imageURL, "https://example.com/logo.png")
        XCTAssertEqual(credential.backgroundColor, "#FF5733")
        XCTAssertEqual(credential.policies, "{\"policy\":\"value\"}")
        XCTAssertEqual(credential.platform, .pingAM)
    }
    
    func testFromUriWithMfauthScheme() async throws {
        // Test mfauth:// scheme
        let uri = "mfauth://push/MyCompany:user?a=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249YXV0aGVudGljYXRl&r=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249cmVnaXN0ZXI&s=c2hhcmVkU2VjcmV0VmFsdWU"
        
        let credential = try await PushCredential.fromUri(uri)
        
        XCTAssertEqual(credential.issuer, "MyCompany")
        XCTAssertEqual(credential.accountName, "user")
        XCTAssertEqual(credential.platform, .pingAM)
    }
    
    func testFromUriWithSpecialCharacters() async throws {
        // Test issuer and account with special characters
        let uri = "pushauth://push/My%20Company%20Inc.:john%2Bdoe%40example.com?a=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249YXV0aGVudGljYXRl&r=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249cmVnaXN0ZXI&s=c2hhcmVkU2VjcmV0VmFsdWU"
        
        let credential = try await PushCredential.fromUri(uri)
        
        XCTAssertEqual(credential.issuer, "My Company Inc.")
        XCTAssertEqual(credential.accountName, "john+doe@example.com")
    }
    
    func testFromUriThrowsOnInvalidScheme() async {
        let uri = "invalid://push/MyCompany:user@example.com?r=endpoint&a=endpoint&s=secret"
        
        do {
            _ = try await PushCredential.fromUri(uri)
            XCTFail("Expected error for invalid scheme")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Invalid URI scheme"))
            } else {
                XCTFail("Expected invalidUri error")
            }
        } catch {
            XCTFail("Expected PushError")
        }
    }
    
    func testFromUriThrowsOnMissingRequiredParameter() async {
        // Missing shared secret parameter
        let uri = "pushauth://push/MyCompany:user?r=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50&a=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50"
        
        do {
            _ = try await PushCredential.fromUri(uri)
            XCTFail("Expected error for missing required parameter")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected invalidUri error")
            }
        } catch {
            XCTFail("Expected PushError")
        }
    }
    
    func testFromUriThrowsOnMalformedUri() async {
        let uri = "not a valid uri at all"
        
        do {
            _ = try await PushCredential.fromUri(uri)
            XCTFail("Expected error for malformed URI")
        } catch let error as PushError {
            if case .invalidUri = error {
                // Expected
            } else {
                XCTFail("Expected invalidUri error")
            }
        } catch {
            XCTFail("Expected PushError")
        }
    }
    
    func testToUriWithMinimalParameters() async throws {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz"
        )
        
        let uri = try await credential.toUri()
        
        XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
        XCTAssertTrue(uri.contains("MyCompany"))
        // Account name should be URL-encoded (@ becomes %40)
        XCTAssertTrue(uri.contains("user%40example.com"))
        XCTAssertTrue(uri.contains("r="))
        XCTAssertTrue(uri.contains("a="))
        XCTAssertTrue(uri.contains("s="))
        XCTAssertTrue(uri.contains("issuer=MyCompany"))
    }
    
    func testToUriWithAllParameters() async throws {
        let credential = PushCredential(
            id: "credential-123",
            userId: "user-456",
            resourceId: "device-789",
            issuer: "ForgeRock",
            displayIssuer: "ForgeRock Inc.",
            accountName: "john.doe@example.com",
            displayAccountName: "John Doe",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz",
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF5733",
            policies: "{\"policy\":\"value\"}",
            platform: .pingAM
        )
        
        let uri = try await credential.toUri()
        
        XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
        XCTAssertTrue(uri.contains("ForgeRock"))
        // Account name should be URL-encoded
        XCTAssertTrue(uri.contains("john.doe%40example.com"))
        XCTAssertTrue(uri.contains("r="))
        XCTAssertTrue(uri.contains("a="))
        XCTAssertTrue(uri.contains("s="))
        XCTAssertTrue(uri.contains("d="))  // userId parameter
        XCTAssertTrue(uri.contains("pid="))  // resourceId parameter
        XCTAssertTrue(uri.contains("image="))
        XCTAssertTrue(uri.contains("b="))  // backgroundColor parameter
        XCTAssertTrue(uri.contains("policies="))
        XCTAssertTrue(uri.contains("issuer=ForgeRock"))
    }
    
    func testToUriWithSpecialCharacters() async throws {
        let credential = PushCredential(
            issuer: "My Company Inc.",
            accountName: "john+doe@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz"
        )
        
        let uri = try await credential.toUri()
        
        // Special characters should be URL-encoded in the URI
        XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
        XCTAssertTrue(uri.contains(":"))  // Colon between issuer and account
    }
    
    func testToUriEscapesBackgroundColor() async throws {
        let credential = PushCredential(
            issuer: "MyCompany",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz",
            backgroundColor: "#FF5733"
        )
        
        let uri = try await credential.toUri()
        
        // Background color should be in the URI without the # prefix
        XCTAssertTrue(uri.contains("b=FF5733") || uri.contains("b=%23FF5733"))
    }
    
    func testRoundTripUriConversion() async throws {
        // Create original credential
        let original = PushCredential(
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz",
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF5733"
        )
        
        // Convert to URI
        let uri = try await original.toUri()
        
        // Parse back from URI
        let parsed = try await PushCredential.fromUri(uri)
        
        // Verify critical fields match
        XCTAssertEqual(parsed.issuer, original.issuer)
        XCTAssertEqual(parsed.accountName, original.accountName)
        XCTAssertTrue(parsed.serverEndpoint.contains("am.example.com/push"))
        XCTAssertEqual(parsed.imageURL, original.imageURL)
        XCTAssertEqual(parsed.backgroundColor, original.backgroundColor)
        XCTAssertEqual(parsed.platform, original.platform)
    }
    
    func testRoundTripUriConversionWithAllParameters() async throws {
        // Create credential with all optional parameters
        let original = PushCredential(
            userId: "user-456",
            resourceId: "device-789",
            issuer: "ForgeRock",
            accountName: "john.doe@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz",
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF5733",
            policies: "{\"policy\":\"value\"}"
        )
        
        // Convert to URI and back
        let uri = try await original.toUri()
        let parsed = try await PushCredential.fromUri(uri)
        
        // Verify all fields are preserved
        XCTAssertEqual(parsed.issuer, original.issuer)
        XCTAssertEqual(parsed.accountName, original.accountName)
        XCTAssertEqual(parsed.userId, original.userId)
        XCTAssertEqual(parsed.resourceId, original.resourceId)
        XCTAssertEqual(parsed.imageURL, original.imageURL)
        XCTAssertEqual(parsed.backgroundColor, original.backgroundColor)
        XCTAssertEqual(parsed.policies, original.policies)
    }
    
    func testFromUriPreservesDisplayValues() async throws {
        // When parsing from URI, displayIssuer and displayAccountName should default to issuer/accountName
        let uri = "pushauth://push/MyCompany:user?a=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249YXV0aGVudGljYXRl&r=aHR0cDovL2V4YW1wbGUuY29tL2VuZHBvaW50P19hY3Rpb249cmVnaXN0ZXI&s=c2hhcmVkU2VjcmV0VmFsdWU"
        
        let credential = try await PushCredential.fromUri(uri)
        
        XCTAssertEqual(credential.displayIssuer, credential.issuer)
        XCTAssertEqual(credential.displayAccountName, credential.accountName)
    }
    
    func testToUriUsesIssuerNotDisplayIssuer() async throws {
        // toUri should use the original issuer, not the user-edited displayIssuer
        let credential = PushCredential(
            issuer: "OriginalIssuer",
            displayIssuer: "User Edited Issuer",
            accountName: "user@example.com",
            serverEndpoint: "https://am.example.com/push",
            sharedSecret: "c2VjcmV0S2V5MTIz"
        )
        
        let uri = try await credential.toUri()
        
        // Should use original issuer in the URI
        XCTAssertTrue(uri.contains("OriginalIssuer"))
        XCTAssertFalse(uri.contains("User%20Edited%20Issuer"))
    }
}
