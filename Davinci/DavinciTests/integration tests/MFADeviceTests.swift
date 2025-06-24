//
//  MFADeviceTests.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate
@testable import PingDavinci
@testable import PingLogger

class MFADeviceTests: XCTestCase {
    
    private var daVinci: DaVinci!
        
    private let MFA_TEXT = 1
    private let MFA_VOICE = 2
    
    private var usernamePrefix: String!
    private var userFname: String!
    private var userLname: String!
    private var username: String!
    private var password: String!
    private var email1: String!
    private var email2: String!
    private var phoneNumber1: String!
    private var phoneNumber2: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configure DaVinci
        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "021b83ce-a9b1-4ad4-8c1d-79e576eeab76"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.acrValues = "1557008a3c8b6105d5f4e8e053ac7a29"
            }
        }
        
        // Initialize test data
        usernamePrefix = "MFA"
        password = "Demo1234#1"
        username = "\(usernamePrefix!)\(Int(Date().timeIntervalSince1970 * 1000))@example.com"
        userFname = "GAGA"
        userLname = "User"
        email1 = "\(usernamePrefix!)\(Int(Date().timeIntervalSince1970 * 1000))@example.com"
        email2 = "\(usernamePrefix!)\(Int(Date().timeIntervalSince1970 * 1000))@example.net"
        phoneNumber1 = "888123456"
        phoneNumber2 = "888123457"
        
        // Start with a clean session
        await daVinci.daVinciuser()?.logout()
        try await registerUser(username: username, password: password)
    }
    
    override func tearDown() async throws {
        try await deleteUser(username: username, password: password)
        try await super.tearDown()
    }
    
    // MARK: - Test Cases
    func testDeviceRegistrationForm() async throws {
        // Login with the test user
        var node = try await loginUser(username: username, password: password)
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Select the "Device Registration" test form
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // There is only one collector in this node ("device-registration" collector)
        XCTAssertTrue(node.collectors.count == 1)
        XCTAssertTrue(node.collectors[0] is DeviceRegistrationCollector)
        
        let deviceRegistrationCollector = node.collectors[0] as! DeviceRegistrationCollector
        
        XCTAssertEqual("DEVICE_REGISTRATION", deviceRegistrationCollector.type)
        XCTAssertEqual("device-registration", deviceRegistrationCollector.key)
        XCTAssertEqual("MFA Device Selection - Registration", deviceRegistrationCollector.label)
        XCTAssertTrue(deviceRegistrationCollector.required)
        
        // Assert the available options
        XCTAssertTrue(deviceRegistrationCollector.devices.count == 3)
        XCTAssertEqual("EMAIL", deviceRegistrationCollector.devices[0].type)
        XCTAssertEqual("Email", deviceRegistrationCollector.devices[0].title)
        XCTAssertEqual("Receive an authentication passcode in your email.", deviceRegistrationCollector.devices[0].description)
        XCTAssertNotNil(deviceRegistrationCollector.devices[0].iconSrc)
        
        XCTAssertEqual("SMS", deviceRegistrationCollector.devices[1].type)
        XCTAssertEqual("Text Message", deviceRegistrationCollector.devices[1].title)
        XCTAssertEqual("Receive an authentication passcode in a text message.", deviceRegistrationCollector.devices[1].description)
        XCTAssertNotNil(deviceRegistrationCollector.devices[1].iconSrc)
        
        XCTAssertEqual("VOICE", deviceRegistrationCollector.devices[2].type)
        XCTAssertEqual("Voice", deviceRegistrationCollector.devices[2].title)
        XCTAssertEqual("Receive a phone call with an authentication passcode.", deviceRegistrationCollector.devices[2].description)
        XCTAssertNotNil(deviceRegistrationCollector.devices[2].iconSrc)
    }
        
    func testDeviceAuthenticationFormError() async throws {
        // Login with the test user (no MFA devices registered yet)
        let node = try await loginUser(username: username, password: password)
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Select the "Device Authentication" test form
        (node.collectors[1] as? FlowCollector)?.value = "click"
        
        let errorNode = await node.next()
        XCTAssertTrue(errorNode is ErrorNode)
        
        let error = errorNode as! ErrorNode
        if let responseStatus = error.input["httpResponseCode"] {
            XCTAssertEqual("400", "\(responseStatus)")
        } else {
            XCTFail("httpResponseCode was nil")
        }
        XCTAssertEqual("There was a problem getting the MFA devices for the specified user. Check your PingOne Forms connector configuration.", error.message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
        
    func testDeviceAuthenticationForm() async throws {
        // Register an email MFA device
        try await registerEmailMFA(email: email1)
        var node = try await loginUser(username: username, password: password)
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Select the "Device Authentication" test form
        (node.collectors[1] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        XCTAssertEqual("SDK Automation - Device Authentication", node.name)
        XCTAssertEqual("Test form for DEVICE_AUTHENTICATION collector", node.description)
        
        // There is only one collector in this node ("device-authentication" collector)
        XCTAssertTrue(node.collectors.count == 1)
        XCTAssertTrue(node.collectors[0] is DeviceAuthenticationCollector)
        
        var deviceAuthenticationCollector = node.collectors[0] as! DeviceAuthenticationCollector
        
        XCTAssertEqual("DEVICE_AUTHENTICATION", deviceAuthenticationCollector.type)
        XCTAssertEqual("device-authentication", deviceAuthenticationCollector.key)
        XCTAssertEqual("MFA Device Selection - Authentication", deviceAuthenticationCollector.label)
        XCTAssertTrue(deviceAuthenticationCollector.required)
        
        // Assert the available devices (should be only one EMAIL device)
        XCTAssertTrue(deviceAuthenticationCollector.devices.count == 1)
        XCTAssertEqual("EMAIL", deviceAuthenticationCollector.devices[0].type)
        XCTAssertEqual("Email", deviceAuthenticationCollector.devices[0].title)
        
        let description = deviceAuthenticationCollector.devices[0].description
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let range = description?.range(of: emailRegex, options: .regularExpression)

        XCTAssertNotNil(range, "Description should contain a valid email address")
        
        XCTAssertNotNil(deviceAuthenticationCollector.devices[0].iconSrc)
        
        // Register another email MFA device and TEXT and VOICE MFA devices
        try await registerEmailMFA(email: email2)
        try await registerPhoneMFA(phone: phoneNumber1, mfaType: MFA_TEXT)
        try await registerPhoneMFA(phone: phoneNumber2, mfaType: MFA_VOICE)
        
        // Login with the test user (should have 4 MFA devices registered)
        // Note that registered devices may take a few seconds to appear in the form, so wait for a second and retry a few times...
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        var foundAllDevices = false

        for attempt in 1...5 {
            print("Login attempt \(attempt)...")
            node = try await loginUser(username: username, password: password)
            (node.collectors[1] as? FlowCollector)?.value = "click"
            node = await node.next() as! ContinueNode
            
            guard let collector = node.collectors.first as? DeviceAuthenticationCollector else {
                XCTFail("Expected DeviceAuthenticationCollector")
                return
            }

            print("deviceAuthenticationCollector.devices.count = \(collector.devices.count)")

            if collector.devices.count == 4 {
                foundAllDevices = true
                break
            }

            try await Task.sleep(nanoseconds: 1_500_000_000)
        }

        XCTAssertTrue(foundAllDevices, "Expected 4 devices, but never received them after retries")
        
        // Repeat the steps from above and make sure that all registered MFA devices appear in the form
        node = try await loginUser(username: username, password: password)
        
        // Select the "Device Authentication" test form
        (node.collectors[1] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        XCTAssertEqual("SDK Automation - Device Authentication", node.name)
        deviceAuthenticationCollector = node.collectors[0] as! DeviceAuthenticationCollector
        
        // Assert the available devices
        print("deviceAuthenticationCollector.devices.count = \(deviceAuthenticationCollector.devices.count)")
        XCTAssertTrue(deviceAuthenticationCollector.devices.count == 4)
        XCTAssertEqual("EMAIL", deviceAuthenticationCollector.devices[0].type)
        XCTAssertEqual("EMAIL", deviceAuthenticationCollector.devices[1].type)
        XCTAssertEqual("SMS", deviceAuthenticationCollector.devices[2].type)
        XCTAssertEqual("VOICE", deviceAuthenticationCollector.devices[3].type)
    }
        
    func testDeviceRegistrationEmail() async throws {
        try await registerEmailMFA(email: email1)
    }
    
    func testDeviceRegistrationSMS() async throws {
        try await registerPhoneMFA(phone: phoneNumber1, mfaType: MFA_TEXT)
    }
    
    func testDeviceRegistrationVOICE() async throws {
        try await registerPhoneMFA(phone: phoneNumber2, mfaType: MFA_VOICE)
    }
        
    // MARK: - Helper Functions
    private func registerUser(username: String, password: String) async throws {
        var node = await daVinci.start() as! ContinueNode
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Click on the registration link
        (node.collectors[2] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that we are at the user registration form
        XCTAssertEqual("Registration Form", node.name)
        
        // Fill in the registration form
        (node.collectors[0] as? TextCollector)?.value = username
        (node.collectors[1] as? PasswordCollector)?.value = password
        (node.collectors[2] as? TextCollector)?.value = userFname
        (node.collectors[3] as? TextCollector)?.value = userLname
        (node.collectors[4] as? SubmitCollector)?.value = "Save"
        
        node = await node.next() as! ContinueNode
        
        XCTAssertTrue(node.collectors[0] is SubmitCollector)
        XCTAssertEqual("Registration Complete", node.name)
        XCTAssertEqual("User Account Successfully Created", node.description)
        XCTAssertEqual("Continue", (node.collectors[0] as! SubmitCollector).label)
        
        // Click "Continue" to finish the registration process
        (node.collectors[0] as? SubmitCollector)?.value = "Continue"
        let successNode = await node.next() as! SuccessNode
        
        // Make sure the user is not null
        let user = successNode.user
        let token = await user!.token()
        switch token {
        case .success(let tokenValue):
            XCTAssertNotNil(tokenValue.accessToken)
        case .failure(let error):
            XCTFail("Token retrieval failed: \(error)")
        }
        
        // Logout the user
        guard let u = await daVinci.daVinciuser() else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User is null"])
        }
        await u.logout()
    }
    
    private func loginUser(username: String, password: String) async throws -> ContinueNode {
        var node = await daVinci.start() as! ContinueNode
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Click on the "User Login" button
        (node.collectors[3] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that we are at the user registration form
        XCTAssertEqual("SDK Automation - Sign On", node.name)
        
        // Fill in the login form with valid credentials and submit...
        (node.collectors[1] as? TextCollector)?.value = username
        (node.collectors[2] as? PasswordCollector)?.value = password
        (node.collectors[3] as? SubmitCollector)?.value = "Sign On"
        
        node = await node.next() as! ContinueNode
        
        // Upon successful login we should be at the initial screen... ("Select Test Form")
        XCTAssertEqual("Select Test Form", node.name)
        return node
    }
    
    private func deleteUser(username: String, password: String) async throws {
        // Login the user
        var node = try await loginUser(username: username, password: password)
        
        // Click on the "User Delete" button
        (node.collectors[4] as? FlowCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that the user is successfully deleted
        XCTAssertEqual("Success", node.name)
        XCTAssertEqual("User has been successfully deleted", node.description)
    }
    
    private func registerEmailMFA(email: String) async throws {
        // Login with the test user
        var node = try await loginUser(username: username, password: password)
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Select the "Device Registration" test form
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // There is only one collector in this node ("device-registration" collector)
        XCTAssertTrue(node.collectors.count == 1)
        XCTAssertTrue(node.collectors[0] is DeviceRegistrationCollector)
        
        // Select the "Email" option
        let deviceRegistrationCollector = node.collectors[0] as! DeviceRegistrationCollector
        deviceRegistrationCollector.value = deviceRegistrationCollector.devices[0]
        node = await node.next() as! ContinueNode
        
        // Make sure that we are at the EMAIL device registration form
        XCTAssertEqual("SDK Automation - Enter Email", node.name)
        XCTAssertEqual("Enter email for registration", node.description)
        
        // Assert the collectors
        XCTAssertTrue(node.collectors.count == 3)
        XCTAssertTrue(node.collectors[0] is LabelCollector)
        XCTAssertTrue(node.collectors[1] is TextCollector)
        XCTAssertTrue(node.collectors[2] is SubmitCollector)
        
        XCTAssertEqual("Enter Email", (node.collectors[0] as! LabelCollector).content)
        XCTAssertEqual("Email Address", (node.collectors[1] as! TextCollector).label)
        
        // Enter an email address in the form
        (node.collectors[1] as? TextCollector)?.value = email
        (node.collectors[2] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that we are at the "successful registration" screen
        XCTAssertEqual("EMAIL MFA Registered", node.name)
        XCTAssertEqual("Email MFA Device Successfully Created", node.description)
    }
    
    private func registerPhoneMFA(phone: String, mfaType: Int) async throws {
        // Login with the test user
        var node = try await loginUser(username: username, password: password)
        
        // Make sure that we are at the initial test form
        XCTAssertEqual("Select Test Form", node.name)
        
        // Select the "Device Registration" test form
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // There is only one collector in this node ("device-registration" collector)
        XCTAssertTrue(node.collectors.count == 1)
        XCTAssertTrue(node.collectors[0] is DeviceRegistrationCollector)
        
        // Select the "Text Message" option
        let deviceRegistrationCollector = node.collectors[0] as! DeviceRegistrationCollector
        deviceRegistrationCollector.value = deviceRegistrationCollector.devices[mfaType]
        node = await node.next() as! ContinueNode
        
        // Make sure that we are at the Phone Number registration form
        XCTAssertEqual("SDK Automation - Enter Phone Number", node.name)
        XCTAssertEqual("Enter phone number", node.description)
        
        // Assert the collectors
        XCTAssertTrue(node.collectors.count == 4)
        XCTAssertTrue(node.collectors[0] is LabelCollector)
        XCTAssertTrue(node.collectors[1] is SingleSelectCollector)
        XCTAssertTrue(node.collectors[2] is TextCollector)
        XCTAssertTrue(node.collectors[3] is SubmitCollector)
        
        // We have a label collector with the text "Enter Phone Number"
        XCTAssertEqual("Enter Phone Number", (node.collectors[0] as! LabelCollector).content)
        
        // Followed by a Dropdown collector with country codes
        let dropdown = node.collectors[1] as! SingleSelectCollector
        XCTAssertEqual("DROPDOWN", dropdown.type)
        XCTAssertEqual("countryCode", dropdown.key)
        XCTAssertEqual("Country Code", dropdown.label)
        XCTAssertEqual(true, dropdown.required)
        XCTAssertEqual(4, dropdown.options.count)
        XCTAssertEqual("India (91)", dropdown.options[0].label)
        XCTAssertEqual("United States (1)", dropdown.options[1].label)
        XCTAssertEqual("United Kingdom (44)", dropdown.options[2].label)
        XCTAssertEqual("Bulgaria (359)", dropdown.options[3].label)
        XCTAssertEqual("91", dropdown.options[0].value)
        XCTAssertEqual("1", dropdown.options[1].value)
        XCTAssertEqual("44", dropdown.options[2].value)
        XCTAssertEqual("359", dropdown.options[3].value)
        
        // Then a text collector for the phone number
        let phoneNumberCollector = node.collectors[2] as! TextCollector
        XCTAssertEqual("Enter Phone Number", phoneNumberCollector.label)
        
        // Select a country code and enter a valid phone number:...
        dropdown.value = "359"  // Select Bulgaria...
        phoneNumberCollector.value = phone
        
        // Submit the form
        (node.collectors[3] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that we are at the "successful registration" screen
        XCTAssertEqual("SMS/Voice MFA Registered", node.name)
        XCTAssertEqual("SMS/Voice MFA Device Successfully Created", node.description)
        
        // Click "Continue" to finish the registration process
        (node.collectors[0] as? SubmitCollector)?.value = "Continue"
        node = await node.next() as! ContinueNode
        
        // Upon successful phone registration we should be at the initial screen... ("Select Test Form")
        XCTAssertEqual("Select Test Form", node.name)
    }
}
