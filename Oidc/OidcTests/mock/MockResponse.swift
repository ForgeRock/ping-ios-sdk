//
//  MockResponse.swift
//  OidcTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

struct MockResponse {
    static let headers = ["Content-Type": "application/json"]
    
    static var openIdConfiguration: Data {
        """
    {
      "authorization_endpoint" : "\(MockAPIEndpoint.authorization.url.absoluteString)",
      "token_endpoint" : "\(MockAPIEndpoint.token.url.absoluteString)",
      "userinfo_endpoint" : "\(MockAPIEndpoint.userinfo.url.absoluteString)",
      "end_session_endpoint" : "\(MockAPIEndpoint.endSession.url.absoluteString)",
      "revocation_endpoint" : "\(MockAPIEndpoint.revocation.url.absoluteString)"
    }
    """.data(using: .utf8)!
    }
    
    static var token: Data {
         """
    {
      "access_token" : "Dummy AccessToken",
      "token_type" : "Dummy Token Type",
      "scope" : "openid email address",
      "refresh_token" : "Dummy RefreshToken",
      "expires_in" : 2,
      "id_token" : "Dummy IdToken"
    }
    """.data(using: .utf8)!
    }
    
    static var userinfo: Data {
         """
    {
      "sub" : "test-sub",
      "name" : "test-name",
      "email" : "test-email",
      "phone_number" : "test-phone_number",
      "address" : "test-address"
    }
    """.data(using: .utf8)!
    }
    
    static var tokenErrorResponse: Data {
         """
    {
      "error" : "Invalid Grant"
    }
    """.data(using: .utf8)!
    }
    
    static var error: Data {
         """
    {
      "error" : "Internal Server Error"
    }
    """.data(using: .utf8)!
    }

    static var deviceAuthorizationResponse: Data {
        """
    {
      "device_code" : "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
      "user_code" : "WDJB-MJHT",
      "verification_uri" : "https://auth.test-one-pingone.com/activate",
      "verification_uri_complete" : "https://auth.test-one-pingone.com/activate?user_code=WDJB-MJHT",
      "expires_in" : 1800,
      "interval" : 5
    }
    """.data(using: .utf8)!
    }

    static var deviceAuthorizationResponseNoInterval: Data {
        """
    {
      "device_code" : "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
      "user_code" : "WDJB-MJHT",
      "verification_uri" : "https://auth.test-one-pingone.com/activate",
      "verification_uri_complete" : "https://auth.test-one-pingone.com/activate?user_code=WDJB-MJHT",
      "expires_in" : 1800
    }
    """.data(using: .utf8)!
    }

    static var authorizationPending: Data {
        """
    {
      "error" : "authorization_pending"
    }
    """.data(using: .utf8)!
    }

    static var slowDown: Data {
        """
    {
      "error" : "slow_down"
    }
    """.data(using: .utf8)!
    }

    static var accessDenied: Data {
        """
    {
      "error" : "access_denied"
    }
    """.data(using: .utf8)!
    }

    static var expiredToken: Data {
        """
    {
      "error" : "expired_token"
    }
    """.data(using: .utf8)!
    }

    static var deviceAuthorizationResponseFastInterval: Data {
        """
    {
      "device_code" : "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
      "user_code" : "WDJB-MJHT",
      "verification_uri" : "https://auth.test-one-pingone.com/activate",
      "verification_uri_complete" : "https://auth.test-one-pingone.com/activate?user_code=WDJB-MJHT",
      "expires_in" : 1800,
      "interval" : 0
    }
    """.data(using: .utf8)!
    }

    /// Fixture with interval=-5 so that a single slow_down (+5) results in interval=0.
    /// Use this in slow_down tests to avoid any real Task.sleep delay after the bump.
    static var deviceAuthorizationResponseSlowDownFriendly: Data {
        """
    {
      "device_code" : "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
      "user_code" : "WDJB-MJHT",
      "verification_uri" : "https://auth.test-one-pingone.com/activate",
      "verification_uri_complete" : "https://auth.test-one-pingone.com/activate?user_code=WDJB-MJHT",
      "expires_in" : 1800,
      "interval" : -5
    }
    """.data(using: .utf8)!
    }
}
