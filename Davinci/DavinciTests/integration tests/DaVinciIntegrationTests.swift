//
//  DaVinciIntegrationTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
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

class DaVinciIntegrationTests: XCTestCase {
    private var daVinci: DaVinci!
    private var username: String!
    private var userFname: String!
    private var userLname: String!
    private var password: String!
    private var newPassword: String!
    private var verificationCode: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        username = "e2euser@example.com"
        userFname = "E2E"
        userLname = "iOS"
        password = "Demo1234#1"
        newPassword = "New1234#1"
        verificationCode = "1234"
        
        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "021b83ce-a9b1-4ad4-8c1d-79e576eeab76"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
            }
        }
        
        // Start with a clean session
        await daVinci.user()?.logout()
    }
    
    // TestRailCase(21274)
    func testLoginSuccess() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Login form validation...
        XCTAssertEqual(continueNode.collectors.count, 5)
        XCTAssertTrue(continueNode.collectors[0] is TextCollector)
        XCTAssertTrue(continueNode.collectors[1] is PasswordCollector)
        XCTAssertTrue(continueNode.collectors[2] is SubmitCollector)
        XCTAssertTrue(continueNode.collectors[3] is FlowCollector)
        XCTAssertTrue(continueNode.collectors[4] is FlowCollector)

        XCTAssertEqual("E2E Login Form", continueNode.name)
        XCTAssertEqual("Enter your username and password", continueNode.description)
        
        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On" // This will submit the form...
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Verify the Successful login form
        XCTAssertTrue(continueNode.collectors.count == 3)
        XCTAssertTrue(continueNode.collectors[0] is SubmitCollector)
        XCTAssertTrue(continueNode.collectors[1] is FlowCollector)
        XCTAssertTrue(continueNode.collectors[2] is FlowCollector)

        XCTAssertEqual("Successful login", continueNode.name)
        XCTAssertEqual("Successfully logged in to DaVinci", continueNode.description)
        XCTAssertEqual("Continue", (continueNode.collectors[0] as! SubmitCollector).label)
        XCTAssertEqual("Reset password...", (continueNode.collectors[1] as! FlowCollector).label)
        XCTAssertEqual("Delete user...", (continueNode.collectors[2] as! FlowCollector).label)
        
        // Click continue
        (continueNode.collectors[0] as! SubmitCollector).value = "Continue"

        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode)
        let successNode = node as! SuccessNode
        
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
    }
    
    // TestRailCase(21275)
    func testLoginFailure() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        let continueNode = node as! ContinueNode
        
        // Make sure that we are at the Login form...
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = "invalid"
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
        node = await continueNode.next()
        XCTAssertTrue(node is ErrorNode)
        let errorNode = node as! ErrorNode
        
        // Verify the error message upon attempt to login with invalid credentials
        XCTAssertEqual("Invalid username and/or password", errorNode.message)
        
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
    }
    
    // TestRailCase(21276)
    func testActiveSession() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Ensure that we are at the Login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Login with valid credentials...
        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // Verify the user was successfully logged in
        XCTAssertEqual("Successful login", continueNode.name)

        // Click continue
        (continueNode.collectors[0] as! SubmitCollector).value = "Continue"

        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode)
        var successNode = node as! SuccessNode
        
        var user = successNode.user
        var userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        // Launch the login form again (active session exists...)
        // Should go directly to success...
        let node1 = await daVinci.start()
        XCTAssertTrue(node1 is SuccessNode)
        successNode = node1 as! SuccessNode
        
        user = successNode.user
        userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
    }
    
    // TestRailCase(21253)
    func testUserRegistrationSuccess() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click the registration link
        (continueNode.collectors[3] as? FlowCollector)?.value = "register"
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Validate the registration form
        XCTAssertTrue(continueNode.collectors.count == 6)
        XCTAssertEqual("Registration Form", continueNode.name)
        XCTAssertEqual("Collect Name, Email, Password", continueNode.description)
        
        XCTAssertTrue(continueNode.collectors[0] is TextCollector)      // Email
        XCTAssertTrue(continueNode.collectors[1] is PasswordCollector)  // Password
        XCTAssertTrue(continueNode.collectors[2] is TextCollector)      // Given Name
        XCTAssertTrue(continueNode.collectors[3] is TextCollector)      // Family Name
        XCTAssertTrue(continueNode.collectors[4] is SubmitCollector)    // Continue
        XCTAssertTrue(continueNode.collectors[5] is FlowCollector)      // Already have an account (link)
        
        XCTAssertEqual("Email", (continueNode.collectors[0] as! TextCollector).label)
        XCTAssertEqual("Password", (continueNode.collectors[1] as! PasswordCollector).label)
        XCTAssertEqual("Given Name", (continueNode.collectors[2] as! TextCollector).label)
        XCTAssertEqual("Family Name", (continueNode.collectors[3] as! TextCollector).label)
        XCTAssertEqual("Continue", (continueNode.collectors[4] as! SubmitCollector).label)
        XCTAssertEqual("Already have an account? Sign On", (continueNode.collectors[5] as! FlowCollector).label)
        
        // Fill in the registration form
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmssSSSS"
        
        let newUser = "e2e" + formatter.string(from: date) + "@example.com"
        
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? TextCollector)?.value = userFname
        (continueNode.collectors[3] as? TextCollector)?.value = userLname
        (continueNode.collectors[4] as? SubmitCollector)?.value = "Save"
        
        // Click continue
        (continueNode.collectors[4] as! SubmitCollector).value = "Save"

        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // User should be navigated to the verification code screen
        XCTAssertTrue(continueNode.collectors.count == 3 )
        XCTAssertTrue(continueNode.collectors[0] is TextCollector)
        XCTAssertTrue(continueNode.collectors[1] is SubmitCollector)
        XCTAssertTrue(continueNode.collectors[2] is FlowCollector)

        XCTAssertEqual("Enter verification code", continueNode.name)
        XCTAssertEqual("Hint: The verification code is 1234", continueNode.description)
        XCTAssertEqual("Verification Code", (continueNode.collectors[0] as! TextCollector).label)
        XCTAssertEqual("Verify", (continueNode.collectors[1] as! SubmitCollector).label)
        XCTAssertEqual("Resend Verification Code", (continueNode.collectors[2] as! FlowCollector).label)
        
        // Fill in the verification code and submit
        (continueNode.collectors[0] as? TextCollector)?.value = verificationCode
        (continueNode.collectors[1] as? SubmitCollector)?.value = "Verify"
        node = await continueNode.next()
        continueNode = node as! ContinueNode

        // User should be navigated to the "Successful user creation" screen...
        XCTAssertTrue(continueNode.collectors.count == 1 )
        XCTAssertTrue(continueNode.collectors[0] is SubmitCollector)
        
        XCTAssertEqual("Registration Complete", continueNode.name)
        XCTAssertEqual("Notify User Account Is Successfully Created", continueNode.description)
        XCTAssertEqual("Continue", (continueNode.collectors[0] as! SubmitCollector).label)

        // Click "Continue" to finish the registration process
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode)
        let successNode = node as! SuccessNode
        
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
        
        // Delete the user from PingOne
        try await deleteUser(userName: newUser, pass: password)
    }

    // TestRailCase(21269)
    func testUserRegistrationFailureUserAlreadyExists() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click the registration link
        (continueNode.collectors[3] as? FlowCollector)?.value = "register"
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
        
        // Fill  the registration form with username that already exists
        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? TextCollector)?.value = userFname
        (continueNode.collectors[3] as? TextCollector)?.value = userLname
        (continueNode.collectors[4] as? SubmitCollector)?.value = "Save"
        
        // Click continue
        (continueNode.collectors[4] as! SubmitCollector).value = "Save"

        node = await continueNode.next()
        let errorNode = node as! ErrorNode
        
        // Make sure we get the expected error
        XCTAssertEqual("uniquenessViolation", String(describing: errorNode.input["code"]!))
        XCTAssertEqual("400", String(describing: errorNode.input["httpResponseCode"]!))
        XCTAssertEqual("An account with that email address already exists.", errorNode.message)
        
        // Make sure that we are still at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
    }
    
    // TestRailCase(21270)
    func testUserRegistrationFailureInvalidEmail() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click the registration link
        (continueNode.collectors[3] as? FlowCollector)?.value = "register"
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
        
        // Enter invalid (empty) email in the registration form
        (continueNode.collectors[0] as? TextCollector)?.value = ""
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? TextCollector)?.value = userFname
        (continueNode.collectors[3] as? TextCollector)?.value = userLname
        (continueNode.collectors[4] as? SubmitCollector)?.value = "Save"
        
        // Click continue
        (continueNode.collectors[4] as! SubmitCollector).value = "Save"

        node = await continueNode.next()
        let errorNode = node as! ErrorNode
        
        // Make sure we get the expected error
        XCTAssertEqual("invalidInput", String(describing: errorNode.input["code"]!))
        XCTAssertEqual("400", String(describing: errorNode.input["httpResponseCode"]!))
        XCTAssertEqual("Enter a valid email address", errorNode.message)
        
        // Make sure that we are still at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
    }
    
    // TestRailCase(21272)
    func testUserRegistrationFailureInvalidPassword() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click the registration link
        (continueNode.collectors[3] as? FlowCollector)?.value = "register"
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
        
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmssSSSS"
        
        let newUser = "e2e" + formatter.string(from: date) + "@example.com"
        
        // Enter invalid password in the registration form
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        // Note: The password rules for the E2E Tests population require at least one number
        (continueNode.collectors[1] as? PasswordCollector)?.value = "invalid"
        (continueNode.collectors[2] as? TextCollector)?.value = userFname
        (continueNode.collectors[3] as? TextCollector)?.value = userLname
        (continueNode.collectors[4] as? SubmitCollector)?.value = "Save"
        
        // Click continue
        (continueNode.collectors[4] as! SubmitCollector).value = "Save"

        node = await continueNode.next()
        let errorNode = node as! ErrorNode
        
        // Make sure we get the expected error
        XCTAssertEqual("invalidValue", String(describing: errorNode.input["code"]!))
        XCTAssertEqual("400", String(describing: errorNode.input["httpResponseCode"]!))
        XCTAssertEqual("password: User password did not satisfy password policy requirements", errorNode.message)
        
        // Make sure that we are still at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
    }
    
    // TestRailCase(21273)
    func testUserRegistrationFailureInvalidVerificationCode() async throws {
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click the registration link
        (continueNode.collectors[3] as? FlowCollector)?.value = "register"
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)
        
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmssSSSS"
        
        let newUser = "e2e" + formatter.string(from: date) + "@example.com"
        
        // Fill the registration form
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? TextCollector)?.value = userFname
        (continueNode.collectors[3] as? TextCollector)?.value = userLname
        (continueNode.collectors[4] as? SubmitCollector)?.value = "Save"
        
        // Click continue
        (continueNode.collectors[4] as! SubmitCollector).value = "Save"

        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the "Verification Code" screen
        XCTAssertEqual("Enter verification code", continueNode.name)
        
        // Fill in the verification code and submit
        (continueNode.collectors[0] as? TextCollector)?.value = "invalid"
        (continueNode.collectors[1] as? SubmitCollector)?.value = "Verify"
        node = await continueNode.next()
        let errorNode = node as! ErrorNode
        
        // Make sure we get the expected error
        XCTAssertEqual("400", String(describing: errorNode.input["code"]!))
        XCTAssertEqual("Invalid verification code", errorNode.message)
        
        // Make sure that we are still at verification code page
        XCTAssertEqual("Enter verification code", continueNode.name)
        
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
        try await deleteUser(userName: newUser, pass: password)
    }
    
    // TestRailCase(21277)
    func testPasswordRecovery() async throws {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmssSSSS"
        let newUser = "e2e" + formatter.string(from: date) + "@example.com"
        
        // Register a test user
        try await registerUser(userName: newUser, password: password)
        
        // Launch DaVinci...
        var node = await daVinci.start()
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click on the "Having trouble..." link
        (continueNode.collectors[4] as? FlowCollector)?.value = "click"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // At the "User Identifier Form" screen...
        XCTAssertTrue(continueNode.collectors.count == 3)
        XCTAssertEqual("User Identifier Form", continueNode.name)
        XCTAssertEqual("Prompt For Email To Send Instructions To Reset Password", continueNode.description)
        
        XCTAssertTrue(continueNode.collectors[0] is TextCollector)      // Username
        XCTAssertTrue(continueNode.collectors[1] is SubmitCollector)    // Continue
        XCTAssertTrue(continueNode.collectors[2] is FlowCollector)      // Back (link)
        
        XCTAssertEqual("Username", (continueNode.collectors[0] as! TextCollector).label)
        XCTAssertEqual("Continue", (continueNode.collectors[1] as! SubmitCollector).label)
        XCTAssertEqual("Back", (continueNode.collectors[2] as! FlowCollector).label)
        
        // Fill in the username and submit
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? SubmitCollector)?.value = "Submit"
        
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // At the "Password Recovery Form" screen...
        XCTAssertTrue(continueNode.collectors.count == 6)
        XCTAssertEqual("Password Recovery Form", continueNode.name)
        XCTAssertEqual("Enter The Recovery Code and Set New Password (Hint: Recovery code is 1234)", continueNode.description)
        
        XCTAssertTrue(continueNode.collectors[0] is TextCollector)      // Recovery Code
        XCTAssertTrue(continueNode.collectors[1] is PasswordCollector)  // New Password
        XCTAssertTrue(continueNode.collectors[2] is PasswordCollector)  // Verify New Password
        XCTAssertTrue(continueNode.collectors[3] is SubmitCollector)    // Continue button
        XCTAssertTrue(continueNode.collectors[4] is FlowCollector)      // Resend recovery code
        XCTAssertTrue(continueNode.collectors[5] is FlowCollector)      // Cancel link
        
        XCTAssertEqual("Recovery Code", (continueNode.collectors[0] as! TextCollector).label)
        XCTAssertEqual("New Password", (continueNode.collectors[1] as! PasswordCollector).label)
        XCTAssertEqual("Verify New Password", (continueNode.collectors[2] as! PasswordCollector).label)
        XCTAssertEqual("Continue", (continueNode.collectors[3] as! SubmitCollector).label)
        XCTAssertEqual("Resend recovery code", (continueNode.collectors[4] as! FlowCollector).label)
        XCTAssertEqual("Cancel", (continueNode.collectors[5] as! FlowCollector).label)
        
        // Fill in the recovery code and new password and submit
        (continueNode.collectors[0] as? TextCollector)?.value = verificationCode
        (continueNode.collectors[1] as? PasswordCollector)?.value = newPassword
        (continueNode.collectors[2] as? PasswordCollector)?.value = newPassword
        (continueNode.collectors[3] as? SubmitCollector)?.value = "Submit"
        
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // At the "Successful password reset" screen...
        XCTAssertTrue(continueNode.collectors.count == 1)
        XCTAssertEqual("Password Reset Success", continueNode.name)
        XCTAssertEqual("Success Message With Animated Checkmark", continueNode.description)
        XCTAssertEqual("Continue", (continueNode.collectors[0] as! SubmitCollector).label)
        
        // Click "Continue" to finish the password reset process
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"
        
        node = await continueNode.next()
        let successNode = node as! SuccessNode
        
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
        
        // Delete the user from PingOne
        try await deleteUser(userName: newUser, pass: newPassword)
    }
    
    // TestRailCase(21278)
    func testPasswordReset() async throws {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmssSSSS"
        let newUser = "e2e" + formatter.string(from: date) + "@example.com"
        
        // Register a test user
        try await registerUser(userName: newUser, password: password)
        
        // Launch DaVinci...
        var node = await daVinci.start()
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Login
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // At the "Successful Login" page
        XCTAssertEqual("Successful login", continueNode.name)
        
        // Click the "Reset password" link
        (continueNode.collectors[1] as? FlowCollector)?.value = "click"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // At the "Change Password Form" screen...
        XCTAssertTrue(continueNode.collectors.count == 5)
        XCTAssertEqual("Change Password Form", continueNode.name)
        XCTAssertEqual("Prompt for existing and new password", continueNode.description)
        
        XCTAssertTrue(continueNode.collectors[0] is PasswordCollector)  // Current Password
        XCTAssertTrue(continueNode.collectors[1] is PasswordCollector)  // New Password
        XCTAssertTrue(continueNode.collectors[2] is PasswordCollector)  // Verify New Password
        XCTAssertTrue(continueNode.collectors[3] is SubmitCollector)    // Continue button
        XCTAssertTrue(continueNode.collectors[4] is FlowCollector)      // Cancel (link)
        
        XCTAssertEqual("Current Password", (continueNode.collectors[0] as! PasswordCollector).label)
        XCTAssertEqual("New Password", (continueNode.collectors[1] as! PasswordCollector).label)
        XCTAssertEqual("Verify New Password", (continueNode.collectors[2] as! PasswordCollector).label)
        XCTAssertEqual("Continue", (continueNode.collectors[3] as! SubmitCollector).label)
        XCTAssertEqual("Cancel", (continueNode.collectors[4] as! FlowCollector).label)
        
        // Fill in the reset password form and submit
        (continueNode.collectors[0] as? PasswordCollector)?.value = password
        (continueNode.collectors[1] as? PasswordCollector)?.value = newPassword
        (continueNode.collectors[2] as? PasswordCollector)?.value = newPassword
        (continueNode.collectors[3] as? SubmitCollector)?.value = "Submit"
        
        node = await continueNode.next()
        continueNode = node as! ContinueNode

        // At the "Password Reset Success" screen...
        XCTAssertTrue(continueNode.collectors.count == 1)
        XCTAssertEqual("Password Reset Success", continueNode.name)
        XCTAssertEqual("Success Message With Animated Checkmark", continueNode.description)
        XCTAssertTrue(continueNode.collectors[0] is SubmitCollector)    // Continue button

        // Click "Continue" to finish the password reset process
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"
        
        node = await continueNode.next()
        let successNode = node as! SuccessNode
        
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
        
        // Delete the user from PingOne
        try await deleteUser(userName: newUser, pass: newPassword)
    }
    
    // TestRailCase(24629)
    func testAccountLocked() async throws {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmssSSSS"
        let newUser = "e2e" + formatter.string(from: date) + "@example.com"
        
        // Register a test user
        try await registerUser(userName: newUser, password: password)
        
        // Launch DaVinci...
        var node = await daVinci.start()
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Fill in the login form with invalid credentials and submit...
        // The following rules apply for the E2E test population:
        // Account Lockout Rules:
        // The user's account will be locked out after 2 distinct failed password attempts;
        // repeated attempts of the same password are not counted.
        // Automatically unlock accounts that were locked by failed password attempts after 1 second
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? PasswordCollector)?.value = "wrong1"
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
        node = await continueNode.next()
        let errorNode = node as! ErrorNode
        
        // Make sure we get the expected error
        XCTAssertEqual("Invalid username and/or password", errorNode.message)
        
        // Make sure that we are still at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Enter invalid credentials again (this should lock the account)
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? PasswordCollector)?.value = "wrong2"
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the "Account Locked" screen...
        XCTAssertTrue(continueNode.collectors.count == 1)
        XCTAssertEqual("Account Locked Message", continueNode.name)
        XCTAssertEqual("Notify when account will unlock", continueNode.description)
        XCTAssertTrue(continueNode.collectors[0] is FlowCollector)  // Back to sign on (link)
        XCTAssertEqual("Back to sign on", (continueNode.collectors[0] as! FlowCollector).label)

        // Click "back" to return to the login page
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Back"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // Ensure that we are now at the login page and user is not logged in
        XCTAssertEqual("E2E Login Form", continueNode.name)
        var daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
        
        // Wait for a second so that the account gets unlocked
        try await Task.sleep(nanoseconds: 1 * 1_500_000_000)
        
        // Enter the valid username and password of the account that was locked
        (continueNode.collectors[0] as? TextCollector)?.value = newUser
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On" // This will submit the form...
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Verify that the login was successful
        XCTAssertEqual("Successful login", continueNode.name)

        // Click continue
        (continueNode.collectors[0] as! SubmitCollector).value = "Continue"
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode)
        let successNode = node as! SuccessNode
        
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
        
        // Delete the test user
        try await deleteUser(userName: newUser, pass: password)
        
    }

    /// Helper function to register a user
    private func registerUser(userName: String, password: String) async throws {
        var node = await daVinci.start()
        var continueNode = node as! ContinueNode
        
        // Make sure that we are at the login form
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        // Click the registration link
        (continueNode.collectors[3] as? FlowCollector)?.value = "register"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // Make sure that we are at the registration form
        XCTAssertEqual("Registration Form", continueNode.name)

        // Fill in the registration form
        (continueNode.collectors[0] as? TextCollector)?.value = userName
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? TextCollector)?.value = userFname
        (continueNode.collectors[3] as? TextCollector)?.value = userLname
        (continueNode.collectors[4] as? SubmitCollector)?.value = "Save"
        
        // Click continue
        (continueNode.collectors[4] as! SubmitCollector).value = "Save"

        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // User should be navigated to the verification code screen
        XCTAssertEqual("Enter verification code", continueNode.name)
        
        // Fill in the verification code and submit
        (continueNode.collectors[0] as? TextCollector)?.value = verificationCode
        (continueNode.collectors[1] as? SubmitCollector)?.value = "Verify"
        node = await continueNode.next()
        continueNode = node as! ContinueNode

        // User should be navigated to the "Successful user creation" screen...
        XCTAssertEqual("Registration Complete", continueNode.name)

        // Click "Continue" to finish the registration process
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode)
        
        // logout the user
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
    }
    
    /// Helper function to delete a user
    private func deleteUser(userName: String, pass: String) async throws {
        var node = await daVinci.start()
        var continueNode = node as! ContinueNode
        
        // // Make sure that we are at the Login form...
        XCTAssertEqual("E2E Login Form", continueNode.name)
        
        (continueNode.collectors[0] as? TextCollector)?.value = userName
        (continueNode.collectors[1] as? PasswordCollector)?.value = pass
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
        node = await continueNode.next()
        XCTAssertTrue(node is ContinueNode)
        continueNode = node as! ContinueNode
        
        // Verify the Successful login form
        XCTAssertEqual("Successful login", continueNode.name)
        XCTAssertEqual("Successfully logged in to DaVinci", continueNode.description)
        XCTAssertEqual("Continue", (continueNode.collectors[0] as! SubmitCollector).label)
        XCTAssertEqual("Reset password...", (continueNode.collectors[1] as! FlowCollector).label)
        XCTAssertEqual("Delete user...", (continueNode.collectors[2] as! FlowCollector).label)
        
        // Click the "Delete user" link
        (continueNode.collectors[2] as? FlowCollector)?.value = "Delete User"
        node = await continueNode.next()
        continueNode = node as! ContinueNode
        
        // Validate success user deletion screen
        XCTAssertEqual("Success", continueNode.name)
        XCTAssertEqual("User has been successfully deleted", continueNode.description)
    }
}
