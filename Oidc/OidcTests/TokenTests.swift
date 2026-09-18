//
//  TokenTests.swift
//  OidcTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc

final class TokenTests: XCTestCase {
    
    func testInitialization() {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: 3600,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        XCTAssertEqual(token.accessToken, "testAccessToken")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.scope, "testScope")
        XCTAssertEqual(token.expiresIn, 3600)
        XCTAssertEqual(token.refreshToken, "testRefreshToken")
        XCTAssertEqual(token.idToken, "testIdToken")
        XCTAssertFalse(token.isExpired)
    }
    
    // TestRailCase(22116, 22117)
    func testEncodingDecoding() throws {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: 3600,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(token)
        let decodedToken = try decoder.decode(Token.self, from: data)
        
        XCTAssertEqual(decodedToken.accessToken, "testAccessToken")
        XCTAssertEqual(decodedToken.tokenType, "Bearer")
        XCTAssertEqual(decodedToken.scope, "testScope")
        XCTAssertEqual(decodedToken.expiresIn, 3600)
        XCTAssertEqual(decodedToken.refreshToken, "testRefreshToken")
        XCTAssertEqual(decodedToken.idToken, "testIdToken")
        XCTAssertEqual(decodedToken.expiresAt, token.expiresAt)
    }
    
    // TestRailCase(22112)
    func testIsExpired() {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: -1,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        XCTAssertTrue(token.isExpired)
    }
    
    // TestRailCase(22114, 22115)
    func testIsExpiredWithThreshold() {
        let token = Token(
            accessToken: "testAccessToken",
            tokenType: "Bearer",
            scope: "testScope",
            expiresIn: 3600,
            refreshToken: "testRefreshToken",
            idToken: "testIdToken"
        )
        
        XCTAssertTrue(token.isExpired(threshold: 3601))
        XCTAssertFalse(token.isExpired(threshold: 3599))
    }

    /// RFC 9396 §7: the token response MUST include the granted `authorization_details`.
    /// Proves the field survives decode AND a JSONEncoder→JSONDecoder round trip — the exact
    /// mechanism `KeychainStorage`'s `Keychain<T>.save/get` wrap around persistence, so this is
    /// the correct way to prove the keychain round-trip claim without touching real Keychain.
    func testAuthorizationDetailsSurvivesEncodingDecoding() throws {
        let body = Data("""
        {
          "access_token": "rar-access-token",
          "token_type": "Bearer",
          "expires_in": 3600,
          "refresh_token": "rar-refresh-token",
          "scope": "openid",
          "authorization_details": [{"type": "payment_initiation", "instructedAmount": {"currency": "EUR", "amount": "123.50"}}]
        }
        """.utf8)

        let token = try JSONDecoder().decode(Token.self, from: body)

        XCTAssertEqual(token.accessToken, "rar-access-token")
        let details = try XCTUnwrap(token.authorizationDetails)
        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(details[0].type, "payment_initiation")
        if case .object(let amount)? = details[0].additionalFields["instructedAmount"] {
            XCTAssertEqual(amount["currency"], .string("EUR"))
            XCTAssertEqual(amount["amount"], .string("123.50"))
        } else {
            XCTFail("instructedAmount object did not decode")
        }

        // Round trip through JSONEncoder/JSONDecoder — the same encode/decode pair
        // `Keychain<T>.save`/`get` wrap around actual persistence.
        let reencoded = try JSONEncoder().encode(token)
        let roundTripped = try JSONDecoder().decode(Token.self, from: reencoded)
        XCTAssertEqual(roundTripped.authorizationDetails, token.authorizationDetails,
                       "authorization_details must survive an encode/decode round trip")
    }
}
