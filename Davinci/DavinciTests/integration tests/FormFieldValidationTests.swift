//
//  FormFieldValidationTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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

class FormFieldValidationTests: DaVinciBaseTests, @unchecked Sendable {
    private var daVinci: DaVinci!

    override func setUp() async throws {
        self.configFileName = "DaVinci-e2e-config"
        try await super.setUp()

        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.acrValues = self.config.formFieldsAcrValues
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
    }

    private func goToValidationForm() async throws -> ContinueNode {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            throw XCTSkip("Could not navigate to validation form: start() did not return ContinueNode")
        }
        (startNode.collectors[1] as? FlowCollector)?.value = "click"
        guard let formNode = await startNode.next() as? ContinueNode else {
            throw XCTSkip("Could not navigate to validation form: next() did not return ContinueNode")
        }
        return formNode
    }

    // TestRailCase(26028, 26030, 26031)
    func testTextFieldValidation() async throws {
        let node = try await goToValidationForm()

        // Username field
        XCTAssertTrue(node.collectors[1] is TextCollector)
        guard let username = node.collectors[1] as? TextCollector else {
            XCTFail("Expected TextCollector at collectors[1]")
            return
        }

        XCTAssertEqual("Username", username.label)
        XCTAssertEqual("user.username", username.key)
        XCTAssertEqual("default username", username.value)
        XCTAssertEqual(true, username.required)
        XCTAssertEqual("^[a-zA-Z0-9]+$", username.validation?.regex?.pattern)
        XCTAssertEqual("Must be alphanumeric", username.validation?.errorMessage)

        // Change the value of the username field to empty
        username.value = ""

        // Validate should return list with 2 validation errors since the value is empty
        // and does not match the configured regex
        var usernameValidationResult = username.validate()
        XCTAssertEqual(2, usernameValidationResult.count)
        XCTAssertEqual("This field cannot be empty.", usernameValidationResult[0].errorMessage)
        XCTAssertEqual("Must be alphanumeric", usernameValidationResult[1].errorMessage)

        username.value = "user123"
        usernameValidationResult = username.validate() // Should return empty list this time
        XCTAssertTrue(usernameValidationResult.isEmpty)

        // Email field
        XCTAssertTrue(node.collectors[2] is TextCollector)
        guard let email = node.collectors[2] as? TextCollector else {
            XCTFail("Expected TextCollector at collectors[2]")
            return
        }

        XCTAssertEqual("Email Address", email.label)
        XCTAssertEqual("user.email", email.key)
        XCTAssertEqual("default email", email.value)
        XCTAssertEqual(true, email.required)
        XCTAssertEqual("^[^@]+@[^@]+\\.[^@]+$", email.validation?.regex?.pattern)
        XCTAssertEqual("Not a valid email", email.validation?.errorMessage)

        // Change the value of the email field to empty
        email.value = ""

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

    // TestRailCase(26034, 26031)
    func testPasswordValidation() async throws {
        let node = try await goToValidationForm()

        XCTAssertTrue(node.collectors[3] is PasswordCollector)
        guard let password = node.collectors[3] as? PasswordCollector else {
            XCTFail("Expected PasswordCollector at collectors[3]")
            return
        }
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
        XCTAssertEqual("default password", password.value)
        XCTAssertEqual(true, password.required)

        // Clear the password field
        password.value = ""

        // Validate should return list of all the failing password policy items
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

    // Verify that a password exceeding maxRepeatedCharacters triggers .maxRepeat validation.
    func testPasswordMaxRepeatValidation() async throws {
        let node = try await goToValidationForm()

        guard let password = node.collectors[3] as? PasswordCollector else {
            XCTFail("Expected PasswordCollector at collectors[3]")
            return
        }
        guard let policy = password.passwordPolicy() else {
            XCTFail("Password policy not found")
            return
        }

        let maxRepeated = policy.maxRepeatedCharacters
        guard maxRepeated < Int.max else {
            XCTFail("Test requires a policy with a maxRepeatedCharacters limit")
            return
        }

        // Build a value where one character repeats maxRepeated+1 times, plus padding to
        // satisfy all other constraints (length, unique chars, minCharacters).
        let excess = String(repeating: "a", count: maxRepeated + 1)
        password.value = excess + "B1!cde"

        let errors = password.validate()
        XCTAssertTrue(errors.contains(.maxRepeat(max: maxRepeated)),
            "Expected .maxRepeat(\(maxRepeated)) in \(errors)")

        // At most maxRepeated repetitions — MaxRepeat error should be absent
        password.value = String(repeating: "a", count: maxRepeated) + "B1!cde"
        let errorsAfterFix = password.validate()
        XCTAssertFalse(errorsAfterFix.contains(.maxRepeat(max: maxRepeated)),
            "MaxRepeat error should be absent when repetitions <= \(maxRepeated)")
    }

    // Verify that a password exceeding the policy's max length triggers .invalidLength.
    func testPasswordMaxLengthValidation() async throws {
        let node = try await goToValidationForm()

        guard let password = node.collectors[3] as? PasswordCollector else {
            XCTFail("Expected PasswordCollector at collectors[3]")
            return
        }
        guard let policy = password.passwordPolicy() else {
            XCTFail("Password policy not found")
            return
        }

        let maxLen = policy.length.max
        // Build a value that exceeds max length while satisfying all other constraints
        password.value = "Aa1!" + String(repeating: "x", count: maxLen)

        let errors = password.validate()
        XCTAssertTrue(errors.contains(.invalidLength(min: policy.length.min, max: maxLen)),
            "Expected .invalidLength for value longer than max=\(maxLen)")
    }

    // close() must wipe the value when clearPassword is true (the default).
    func testPasswordClearAfterClose() async throws {
        let node = try await goToValidationForm()

        guard let password = node.collectors[3] as? PasswordCollector else {
            XCTFail("Expected PasswordCollector at collectors[3]")
            return
        }
        password.value = "Password123!"

        XCTAssertTrue(password.clearPassword)
        password.close()
        XCTAssertEqual("", password.value, "Password should be cleared after close() when clearPassword=true")
    }

    // Verify additional PasswordPolicy metadata fields are populated.
    func testPasswordPolicyAdditionalMetadata() async throws {
        let node = try await goToValidationForm()

        guard let password = node.collectors[3] as? PasswordCollector else {
            XCTFail("Expected PasswordCollector at collectors[3]")
            return
        }
        guard let policy = password.passwordPolicy() else {
            XCTFail("Password policy not found")
            return
        }

        XCTAssertTrue(policy.maxRepeatedCharacters < Int.max,
            "maxRepeatedCharacters should be set by the 'Standard' policy")
        XCTAssertEqual(4, policy.minCharacters.count,
            "Standard policy should require exactly 4 character classes")
        XCTAssertFalse(policy.createdAt.isEmpty, "createdAt should be set")
        XCTAssertFalse(policy.updatedAt.isEmpty, "updatedAt should be set")
        XCTAssertGreaterThanOrEqual(policy.populationCount, 0)
    }

    // Verify the SDK surfaces the field-level passwordPolicy embedded inside the
    // PASSWORD_VERIFY field JSON (SDKS-4694), not from a top-level fallback.
    func testPasswordPolicySourceIsFieldLevel() async throws {
        let node = try await goToValidationForm()

        guard let password = node.collectors[3] as? PasswordCollector else {
            XCTFail("Expected PasswordCollector at collectors[3]")
            return
        }

        // Verify the policy is embedded directly inside the PASSWORD_VERIFY field in the raw JSON
        let form = node.input["form"] as? [String: Any]
        let components = form?["components"] as? [String: Any]
        let fields = components?["fields"] as? [[String: Any]]
        let passwordField = fields?.first { $0["type"] as? String == "PASSWORD_VERIFY" }
        XCTAssertNotNil(passwordField, "PASSWORD_VERIFY field not found in form components")
        XCTAssertNotNil(passwordField?["passwordPolicy"], "passwordPolicy must be embedded inside the PASSWORD_VERIFY field")

        // The SDK must surface the field-level policy via passwordPolicy()
        guard let policy = password.passwordPolicy() else {
            XCTFail("Password policy not found")
            return
        }
        XCTAssertEqual("Standard", policy.name)
        XCTAssertEqual(8, policy.length.min)
        XCTAssertEqual(255, policy.length.max)
    }

    // TestRailCase(27507)
    func testErrorNode() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }

        // Go to the "Error Node" form
        (startNode.collectors[3] as? FlowCollector)?.value = "click"

        let result = await startNode.next()
        guard let errorNode = result as? ErrorNode else {
            XCTFail("Expected ErrorNode, got \(type(of: result))")
            return
        }

        XCTAssertEqual("400", String(describing: errorNode.input["code"]!))
        XCTAssertEqual("Error message from error node", errorNode.message)

        // SDKS-3891 Access Previous Continue Node from ErrorNode
        XCTAssertNotNil(errorNode.continueNode)
        XCTAssertEqual(errorNode.continueNode?.name, "Select Test Form")
        XCTAssertEqual(errorNode.continueNode?.description, "Select form for testing")
    }
}
