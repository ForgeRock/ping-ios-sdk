//
//  DaVinciIntegrationTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

class FormFieldValidationTest: XCTestCase {
    private var daVinci: DaVinci!
    
    override func setUp() async throws {
        try await super.setUp()
        
        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "60de77d5-dd2c-41ef-8c40-f8bb2381a359"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
            }
        }
    }
    
    // TestRailCase(26028, 26030)
    func testTextFieldValidation() async throws {
        // Go to the "Form Fields Validation" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[1] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Username filed...
        XCTAssertTrue(node.collectors[1] is TextCollector)
        let username = node.collectors[1] as! TextCollector
        
        XCTAssertEqual("Username", username.label)
        XCTAssertEqual("user.username", username.key)
        XCTAssertEqual(true, username.required)
        XCTAssertEqual("^[a-zA-Z0-9]+$", username.validation?.regex?.pattern)
        XCTAssertEqual("Must be alphanumeric", username.validation?.errorMessage)
        
        // Validate should return list with 2 validation errors since the value is empty
        // and does not match the configured regex
        var usernameValidationResult = username.validate()
        XCTAssertEqual(2, usernameValidationResult.count)
        XCTAssertEqual("This field cannot be empty.", usernameValidationResult[0].errorMessage)
        XCTAssertEqual("Must be alphanumeric", usernameValidationResult[1].errorMessage)
        
        username.value = "user123"
        usernameValidationResult = username.validate() // Should return empty list this time
        XCTAssertTrue(usernameValidationResult.isEmpty)
        
        // Email field...
        XCTAssertTrue(node.collectors[2] is TextCollector)
        let email = node.collectors[2] as! TextCollector
        
        XCTAssertEqual("Email Address", email.label)
        XCTAssertEqual("user.email", email.key)
        XCTAssertEqual(true, email.required)
        XCTAssertEqual("^[^@]+@[^@]+\\.[^@]+$", email.validation?.regex?.pattern)
        XCTAssertEqual("Not a valid email", email.validation?.errorMessage)
        
        // Validate should return list with 2 validation errors since the value is empty
        // and does not match the configured regex
        var emailValidationResult = email.validate()
        XCTAssertEqual(2, emailValidationResult.count)
        XCTAssertEqual("This field cannot be empty.", emailValidationResult[0].errorMessage)
        XCTAssertEqual("Not a valid email", emailValidationResult[1].errorMessage)
        
        email.value = "not an email"
        emailValidationResult = email.validate() // Should return 1 validation error this time
        XCTAssertEqual(1, emailValidationResult.count)
        XCTAssertEqual("Not a valid email", emailValidationResult[0].errorMessage)
        
        email.value = "valid@email.com"
        emailValidationResult = email.validate() // Should return empty list this time
        XCTAssertTrue(emailValidationResult.isEmpty)
    }
    
    // TestRailCase(26034)
    func testPasswordValidation() async throws {
        // Go to the "Form Fields Validation" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[1] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Password filed...
        XCTAssertTrue(node.collectors[3] is PasswordCollector)
        let password = node.collectors[3] as! PasswordCollector
        guard let passwordPolicy = password.passwordPolicy() else {
            XCTFail("Password policy not found")
            return
        }
        
        // Assert the password policy
        XCTAssertEqual(true, passwordPolicy.default)
        XCTAssertEqual("Standard", passwordPolicy.name)
        XCTAssertEqual("A standard policy that incorporates industry best practices", passwordPolicy.description)
        XCTAssertEqual(8, passwordPolicy.length.min)
        XCTAssertEqual(255, passwordPolicy.length.max)
        XCTAssertEqual(5, passwordPolicy.minUniqueCharacters)
        XCTAssertTrue(passwordPolicy.minCharacters.keys.contains("0123456789"))
        XCTAssertTrue(passwordPolicy.minCharacters.keys.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        XCTAssertTrue(passwordPolicy.minCharacters.keys.contains("abcdefghijklmnopqrstuvwxyz"))
        XCTAssertTrue(passwordPolicy.minCharacters.keys.contains("~!@#$%^&*()-_=+[]{}|;:,.<>/?"))
        
        // Assert the properties of the Password field
        XCTAssertEqual("PASSWORD_VERIFY", password.type)
        XCTAssertEqual("Password", password.label)
        XCTAssertEqual("user.password", password.key)
        XCTAssertEqual(true, password.required)
        
        // Validate should return list of all the faling password policy items
        var passwordValidationResult = password.validate()
        
        XCTAssertEqual(7, passwordValidationResult.count)
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("This field cannot be empty."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input length must be between 8 and 255 characters."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must contain at least 5 unique characters."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must include at least 1 character(s) from this set: \'ABCDEFGHIJKLMNOPQRSTUVWXYZ\'."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must include at least 1 character(s) from this set: \'abcdefghijklmnopqrstuvwxyz\'."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must include at least 1 character(s) from this set: \'~!@#$%^&*()-_=+[]{}|;:,.<>/?\'."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must include at least 1 character(s) from this set: \'0123456789\'."))

        // Set password that meets some of the policy requirements
        password.value = "password123"
        passwordValidationResult = password.validate()
        
        XCTAssertEqual(2, passwordValidationResult.count)
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must include at least 1 character(s) from this set: \'ABCDEFGHIJKLMNOPQRSTUVWXYZ\'."))
        XCTAssert(passwordValidationResult.map { $0.errorMessage }.contains("The input must include at least 1 character(s) from this set: \'~!@#$%^&*()-_=+[]{}|;:,.<>/?\'."))
        
        // Set password that meets all of the policy requirements
        password.value = "Password123!"
        passwordValidationResult = password.validate()
        
        XCTAssertTrue(passwordValidationResult.isEmpty)
    }
}
