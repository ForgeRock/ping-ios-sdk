//
//  PushUriParserTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushUriParserTests: XCTestCase {
    
    // MARK: - Basic Parsing Tests
    
    func testParseBasicPushUri() async throws {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertNotNil(credential)
        XCTAssertEqual(credential.issuer, "forgerock")
        XCTAssertEqual(credential.accountName, "user")
        XCTAssertEqual(credential.serverEndpoint, "http://dev.openam.example.com:8081/openam/json/dev/push/sns/message")
        XCTAssertEqual(credential.sharedSecret, "b3uYLkQ7dRPjBaIzV0t/aijoXRgMq+NP5AwVAvRfa/E=")
    }
    
    func testParseRealPushUri() async throws {
        let uri = "pushauth://push/ForgeRock:stoyan@forgerock.com?a=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&b=032b75&s=oSWY2AY0tHrGUivojn-iahvGC77YDKcA2x6ChSDzwAo&c=jaKZUQlypvRCEugWMVvUWcpNfUFW4pSiB9sVBcKZLis&l=YW1sYmNvb2tpZT0wMQ&m=REGISTER:9a8e9525-f598-4a7d-a759-1ff86f130cb31755365762960&issuer=Rm9yZ2VSb2Nr"
        
        let credential = try await PushUriParser.parse(uri)
        
        // Verify essential properties
        XCTAssertNotNil(credential)
        XCTAssertEqual(credential.issuer, "ForgeRock")
        XCTAssertEqual(credential.accountName, "stoyan@forgerock.com")
        XCTAssertEqual(credential.sharedSecret, "oSWY2AY0tHrGUivojn+iahvGC77YDKcA2x6ChSDzwAo=")
        
        // Verify server endpoint contains expected base URL
        XCTAssertTrue(credential.serverEndpoint.contains("openam-sdks.forgeblocks.com:443/am/json/alpha/push/sns/message"))
    }
    
    func testParseRealMfaUri() async throws {
        let uri = "mfauth://totp/ForgeRock:rodrigo@forgerock.com?a=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&image=https://img.favpng.com/9/25/24/computer-icons-instagram-logo-sticker-png-favpng-LZmXr3KPyVbr8LkxNML458QV3.jpg&r=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&b=032b75&period=30&s=uo2Cl3tmuZF6v_U_n6x7sedgtvtTSoNJCOxmu1rP1WI&c=j_ho1QgRBsE0zeDpGdt9s4loRxrLwpRuOcNqKNQCLOo&digits=8&secret=RY7IQKMGXDI7KTOHD45PUQ6UMM======&l=YW1sYmNvb2tpZT0wMQ&m=REGISTER:c07f99ef-8c65-420f-bd3b-6b835a4868b01755815432333&issuer=Rm9yZ2VSb2Nr"
        
        let credential = try await PushUriParser.parse(uri)
        
        // Verify essential properties
        XCTAssertNotNil(credential)
        XCTAssertEqual(credential.issuer, "ForgeRock")
        XCTAssertEqual(credential.accountName, "rodrigo@forgerock.com")
        XCTAssertEqual(credential.sharedSecret, "uo2Cl3tmuZF6v/U/n6x7sedgtvtTSoNJCOxmu1rP1WI=")
        XCTAssertEqual(credential.imageURL, "https://img.favpng.com/9/25/24/computer-icons-instagram-logo-sticker-png-favpng-LZmXr3KPyVbr8LkxNML458QV3.jpg")
        
        // Verify server endpoint contains expected base URL
        XCTAssertTrue(credential.serverEndpoint.contains("openam-sdks.forgeblocks.com:443/am/json/alpha/push/sns/message"))
    }
    
    // MARK: - Error Handling Tests
    
    func testParseInvalidSchemeUri() async {
        let uri = "invalidscheme://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        do {
            _ = try await PushUriParser.parse(uri)
            XCTFail("Expected PushError.invalidUri to be thrown")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Invalid URI scheme"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testParseMissingRequiredParameter() async {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy"
        
        do {
            _ = try await PushUriParser.parse(uri)
            XCTFail("Expected PushError.invalidUri for missing shared secret")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Base64 Encoding Tests
    
    func testParseWithBase64EncodedUserIdAndResourceId() async throws {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&d=dXNlcjM&pid=NTgxZGQzYzgtM2M2OS00OWFjLWIwMWEtMDc0NDUwYjIyNmM1"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.issuer, "forgerock")
        XCTAssertEqual(credential.accountName, "user")
        XCTAssertEqual(credential.userId, "user3") // Decoded from Base64
        XCTAssertEqual(credential.resourceId, "581dd3c8-3c69-49ac-b01a-074450b226c5") // Decoded from Base64
    }
    
    // MARK: - Color Parameter Tests
    
    func testParseUriWithBackgroundColor() async throws {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&b=519387&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.backgroundColor, "#519387")
    }
    
    func testParseUriWithBackgroundColorWithHash() async throws {
        // URL-encoded # is %23
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&b=%23519387&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.backgroundColor, "#519387")
    }
    
    // MARK: - Image URL Tests
    
    func testParseUriWithImageURL() async throws {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&b=519387&image=aHR0cDovL2Zvcmdlcm9jay5jb20vbG9nby5qcGc&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.imageURL, "http://forgerock.com/logo.jpg")
    }
    
    // MARK: - Label Parsing Tests
    
    func testParseLabelWithIssuerAndAccount() async throws {
        let uri = "pushauth://push/ForgeRock:user@example.com?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.issuer, "ForgeRock")
        XCTAssertEqual(credential.accountName, "user@example.com")
    }
    
    func testParseLabelWithAccountOnly() async throws {
        let uri = "pushauth://push/user@example.com?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&issuer=Rm9yZ2VSb2Nr"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.issuer, "ForgeRock") // From issuer param
        XCTAssertEqual(credential.accountName, "user@example.com")
    }
    
    // MARK: - Scheme Tests
    
    func testParsePushauthScheme() async throws {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertNotNil(credential)
        XCTAssertEqual(credential.platform, .pingAM)
    }
    
    func testParseMfauthScheme() async throws {
        let uri = "mfauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&issuer=Rm9yZ2VSb2Nr"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertNotNil(credential)
        XCTAssertEqual(credential.issuer, "ForgeRock")
        XCTAssertEqual(credential.platform, .pingAM)
    }
    
    // MARK: - Computed Properties Tests
    
    func testCredentialComputedEndpoints() async throws {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.registrationEndpoint, "\(credential.serverEndpoint)?_action=register")
        XCTAssertEqual(credential.authenticationEndpoint, "\(credential.serverEndpoint)?_action=authenticate")
        XCTAssertEqual(credential.updateEndpoint, "\(credential.serverEndpoint)?_action=refresh")
    }
    
    // MARK: - Policies Tests
    
    func testParseWithPolicies() async throws {
        // Base64 encoded JSON policies
        let policies = "{\"biometricOnly\":true}"
        let encodedPolicies = Data(policies.utf8).base64EncodedString()
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&policies=\(encodedPolicies)"
        
        let credential = try await PushUriParser.parse(uri)
        
        XCTAssertEqual(credential.policies, policies)
    }
    
    // MARK: - Registration Parameters Tests
    
    func testRegistrationParametersWithAllParams() async throws {
        // URI with all registration parameters (c, l, m)
        let uri = "pushauth://push/ForgeRock:stoyan@forgerock.com?a=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&b=032b75&s=oSWY2AY0tHrGUivojn-iahvGC77YDKcA2x6ChSDzwAo&c=jaKZUQlypvRCEugWMVvUWcpNfUFW4pSiB9sVBcKZLis&l=YW1sYmNvb2tpZT0wMQ&m=REGISTER:9a8e9525-f598-4a7d-a759-1ff86f130cb31755365762960&issuer=Rm9yZ2VSb2Nr"
        
        let params = try await PushUriParser.registrationParameters(uri)
        
        XCTAssertEqual(params.count, 3)
        XCTAssertNotNil(params["challenge"])
        XCTAssertNotNil(params["amlbCookie"])
        XCTAssertNotNil(params["messageId"])
        
        // Verify challenge is properly decoded (base64url to base64)
        XCTAssertEqual(params["challenge"], "jaKZUQlypvRCEugWMVvUWcpNfUFW4pSiB9sVBcKZLis=")
        
        // Verify load balancer cookie is properly decoded from base64
        XCTAssertEqual(params["amlbCookie"], "amlbcookie=01")
        
        // Verify message ID is preserved as-is
        XCTAssertEqual(params["messageId"], "REGISTER:9a8e9525-f598-4a7d-a759-1ff86f130cb31755365762960")
    }
    
    func testRegistrationParametersWithMfauthScheme() async throws {
        // MFA URI with registration parameters
        let uri = "mfauth://totp/ForgeRock:rodrigo@forgerock.com?a=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cHM6Ly9vcGVuYW0tc2Rrcy5mb3JnZWJsb2Nrcy5jb206NDQzL2FtL2pzb24vYWxwaGEvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=uo2Cl3tmuZF6v_U_n6x7sedgtvtTSoNJCOxmu1rP1WI&c=j_ho1QgRBsE0zeDpGdt9s4loRxrLwpRuOcNqKNQCLOo&l=YW1sYmNvb2tpZT0wMQ&m=REGISTER:c07f99ef-8c65-420f-bd3b-6b835a4868b01755815432333"
        
        let params = try await PushUriParser.registrationParameters(uri)
        
        XCTAssertEqual(params.count, 3)
        XCTAssertNotNil(params["challenge"])
        XCTAssertNotNil(params["amlbCookie"])
        XCTAssertNotNil(params["messageId"])
    }
    
    func testRegistrationParametersWithOnlyChallenge() async {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&c=jaKZUQlypvRCEugWMVvUWcpNfUFW4pSiB9sVBcKZLis"
        
        do {
            _ = try await PushUriParser.registrationParameters(uri)
            XCTFail("Expected PushError.invalidUri for missing load balancer")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRegistrationParametersWithOnlyLoadBalancer() async {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&l=YW1sYmNvb2tpZT0wMQ"
        
        do {
            _ = try await PushUriParser.registrationParameters(uri)
            XCTFail("Expected PushError.invalidUri for missing challenge")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRegistrationParametersWithOnlyMessageId() async {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&m=REGISTER:abc123"
        
        do {
            _ = try await PushUriParser.registrationParameters(uri)
            XCTFail("Expected PushError.invalidUri for missing challenge and load balancer")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRegistrationParametersWithNoParams() async {
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E"
        
        do {
            _ = try await PushUriParser.registrationParameters(uri)
            XCTFail("Expected PushError.invalidUri for missing all registration parameters")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRegistrationParametersWithInvalidUri() async {
        let uri = "not a valid uri!!"
        
        do {
            _ = try await PushUriParser.registrationParameters(uri)
            XCTFail("Expected PushError.invalidUri to be thrown")
        } catch let error as PushError {
            if case .invalidUri = error {
                // Any invalid URI error is acceptable for this malformed URI
                // (could be "Cannot parse URI", "Invalid URI scheme", or "Missing required parameter")
            } else {
                XCTFail("Expected PushError.invalidUri, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRegistrationParametersWithEmptyParams() async {
        // URI with empty registration parameters (should throw error for missing required params)
        let uri = "pushauth://push/forgerock:user?a=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPWF1dGhlbnRpY2F0ZQ&r=aHR0cDovL2Rldi5vcGVuYW0uZXhhbXBsZS5jb206ODA4MS9vcGVuYW0vanNvbi9kZXYvcHVzaC9zbnMvbWVzc2FnZT9fYWN0aW9uPXJlZ2lzdGVy&s=b3uYLkQ7dRPjBaIzV0t_aijoXRgMq-NP5AwVAvRfa_E&c=&l=&m="
        
        do {
            _ = try await PushUriParser.registrationParameters(uri)
            XCTFail("Expected PushError.invalidUri for empty parameters")
        } catch let error as PushError {
            if case .invalidUri(let message) = error {
                XCTAssertTrue(message.contains("Missing required parameter"))
            } else {
                XCTFail("Expected PushError.invalidUri")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Format Tests
    
    func testFormatBasic() async {
        // Create a credential with all required fields
        let credential = PushCredential(
            resourceId: "test-resource-id",
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU="
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify the scheme
            XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
            
            // Verify it contains the required parameters
            XCTAssertTrue(uri.contains("r="))  // registration endpoint
            XCTAssertTrue(uri.contains("a="))  // authentication endpoint
            XCTAssertTrue(uri.contains("s="))  // shared secret
            
            // Verify the label is URL-encoded in the path (@ should be %40)
            XCTAssertTrue(uri.contains("ForgeRock:user%40example.com"))
            
            // Verify issuer parameter is added
            XCTAssertTrue(uri.contains("issuer=ForgeRock"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatWithoutIssuer() async {
        // Create a credential without an issuer
        let credential = PushCredential(
            resourceId: "test-resource-id",
            issuer: "",
            accountName: "user@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU="
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify the label does not contain a colon (no issuer prefix)
            XCTAssertFalse(uri.contains(":user"))
            // Verify it contains the URL-encoded account name (@ should be %40)
            XCTAssertTrue(uri.contains("user%40example.com"))
            
            // Verify issuer parameter is not added
            XCTAssertFalse(uri.contains("issuer="))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatWithOptionalParameters() async {
        // Create a credential with all optional parameters
        let credential = PushCredential(
            userId: "user-id-123",
            resourceId: "test-resource-id",
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU=",
            imageURL: "http://example.com/logo.png",
            backgroundColor: "#336699",
            policies: "policy1,policy2"
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify required parameters
            XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
            XCTAssertTrue(uri.contains("r="))
            XCTAssertTrue(uri.contains("a="))
            XCTAssertTrue(uri.contains("s="))
            
            // Verify optional parameters are added with correct parameter names
            XCTAssertTrue(uri.contains("d="))     // userId (from UriParser.userIdParam)
            XCTAssertTrue(uri.contains("b="))     // backgroundColor
            XCTAssertTrue(uri.contains("image=")) // imageURL (from UriParser.imageUrlParam)
            XCTAssertTrue(uri.contains("policies="))  // policies (from UriParser.policiesParam)
            XCTAssertTrue(uri.contains("pid="))   // resourceId (pushResourceIdParam)
            
            // Verify background color has # removed
            XCTAssertFalse(uri.contains("#336699"))
            XCTAssertTrue(uri.contains("336699"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatWithBackgroundColor() async {
        // Create a credential with a background color that has a # prefix
        let credential = PushCredential(
            resourceId: "test-resource-id",
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU=",
            backgroundColor: "#FF0000"
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify background color is present without the # prefix
            XCTAssertTrue(uri.contains("b=FF0000"))
            XCTAssertFalse(uri.contains("#FF0000"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatRoundTrip() async {
        // Test that formatting and parsing are inverse operations
        // Updated URI to use correct parameter names and encoding:
        // - d (userId), pid (resourceId), policies (policies) 
        // - issuer is plain text URL-encoded, not base64
        let originalUri = "pushauth://push/ForgeRock:demo?a=aHR0cDovL29wZW5hbS5leGFtcGxlLmNvbTo4MDgxL29wZW5hbS9qc29uL3B1c2gvc25zL21lc3NhZ2U_X2FjdGlvbj1hdXRoZW50aWNhdGU&b=519387&image=aHR0cDovL3NlYXR0bGV3cml0ZXIuY29tL3dwLWNvbnRlbnQvdXBsb2Fkcy8yMDEzLzAxL3dlaWdodC13YXRjaGVycy1zbWFsbC5naWY&issuer=ForgeRock&policies=ZGVmYXVsdA&r=aHR0cDovL29wZW5hbS5leGFtcGxlLmNvbTo4MDgxL29wZW5hbS9qc29uL3B1c2gvc25zL21lc3NhZ2U_X2FjdGlvbj1yZWdpc3Rlcg&s=ryJkqNRjXYd_nX523672AX_oKdVXrKExq-VjVeRKKTc&d=ZGVtbw&pid=Y2hvaWNlPTImZGV2aWNlSWQ9ZGV2aWNlLTEyMyZ1c2VyPWpvaG4"
        
        do {
            // Parse the URI
            let credential = try await PushUriParser.parse(originalUri)
            
            // Format it back to a URI
            let formattedUri = try await PushUriParser.format(credential)
            
            // Parse the formatted URI
            let parsedCredential = try await PushUriParser.parse(formattedUri)
            
            // Verify all fields match
            XCTAssertEqual(credential.issuer, parsedCredential.issuer)
            XCTAssertEqual(credential.accountName, parsedCredential.accountName)
            XCTAssertEqual(credential.serverEndpoint, parsedCredential.serverEndpoint)
            XCTAssertEqual(credential.sharedSecret, parsedCredential.sharedSecret)
            XCTAssertEqual(credential.resourceId, parsedCredential.resourceId)
            XCTAssertEqual(credential.imageURL, parsedCredential.imageURL)
            XCTAssertEqual(credential.backgroundColor, parsedCredential.backgroundColor)
            XCTAssertEqual(credential.userId, parsedCredential.userId)
            XCTAssertEqual(credential.policies, parsedCredential.policies)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatRoundTripMinimal() async {
        // Test round trip with minimal credential (only required fields)
        let credential = PushCredential(
            resourceId: "minimal-resource",
            issuer: "TestIssuer",
            accountName: "testuser",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2VjcmV0VmFsdWUxMjM="
        )
        
        do {
            // Format to URI
            let uri = try await PushUriParser.format(credential)
            
            // Parse back
            let parsedCredential = try await PushUriParser.parse(uri)
            
            // Verify all fields match
            XCTAssertEqual(credential.issuer, parsedCredential.issuer)
            XCTAssertEqual(credential.accountName, parsedCredential.accountName)
            XCTAssertEqual(credential.serverEndpoint, parsedCredential.serverEndpoint)
            XCTAssertEqual(credential.sharedSecret, parsedCredential.sharedSecret)
            XCTAssertEqual(credential.resourceId, parsedCredential.resourceId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatWithSpecialCharacters() async {
        // Test encoding with special characters in issuer and account name
        let credential = PushCredential(
            resourceId: "test-resource",
            issuer: "Forge Rock & Co.",
            accountName: "user+test@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU="
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify the URI is properly encoded
            XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
            
            // Verify it can be parsed back
            let parsedCredential = try await PushUriParser.parse(uri)
            XCTAssertEqual(credential.issuer, parsedCredential.issuer)
            XCTAssertEqual(credential.accountName, parsedCredential.accountName)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatWithEmptyResourceId() async {
        // Test credential with empty resource ID
        let credential = PushCredential(
            resourceId: "",
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU="
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify required parameters are present
            XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
            XCTAssertTrue(uri.contains("r="))
            XCTAssertTrue(uri.contains("a="))
            XCTAssertTrue(uri.contains("s="))
            
            // Verify resourceId parameter (x) is NOT added when empty
            XCTAssertFalse(uri.contains("x="))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFormatAlwaysUsesPushauthScheme() async {
        // Verify that format() always uses pushauth:// scheme
        let credential = PushCredential(
            resourceId: "test-resource-id",
            issuer: "ForgeRock",
            accountName: "user@example.com",
            serverEndpoint: "http://example.com/endpoint",
            sharedSecret: "c2hhcmVkU2VjcmV0VmFsdWU="
        )
        
        do {
            let uri = try await PushUriParser.format(credential)
            
            // Verify scheme is always pushauth
            XCTAssertTrue(uri.hasPrefix("pushauth://push/"))
            XCTAssertFalse(uri.hasPrefix("mfauth://"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
