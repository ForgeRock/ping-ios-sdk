//
//  DeviceSigningVerifierCallbackE2ETests.swift
//  Binding
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingBinding
@testable import PingJourneyPlugin
@testable import PingOidc

class DeviceSigningVerifierCallbackE2ETests: BindingE2EBaseTest, @unchecked Sendable {
    
    static let APPLICATION_PIN: String = "1111"
    
    var logger = LogManager.logger
    var testTree = "device-verifier"
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Tests
    
    func testDeviceSigningVerifierDefaults() async throws {
        // Advance to the DeviceSigningVerifier node with "default" configuration
        let node = try await startTest(testConfiguration: "default")
        
        // We expect DeviceSigningVerifierCallback with default settings here. Assert its properties...
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        XCTAssertNotNil(deviceSigningVerifierCallback.userId)
        XCTAssertNotNil(deviceSigningVerifierCallback.challenge)
        XCTAssertEqual(deviceSigningVerifierCallback.title, "Authentication required")
        XCTAssertEqual(deviceSigningVerifierCallback.subtitle, "Cryptography device binding")
        XCTAssertEqual(deviceSigningVerifierCallback.description, "Please complete with biometric to proceed")
        XCTAssertEqual(deviceSigningVerifierCallback.timeout, 60)
        
        // Set "Abort" client error
        _ = deviceSigningVerifierCallback.input("Abort", forKey: "IDToken1clientError")
        
        // Submit - should advance to a Message node with "Abort" text
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting DeviceSigningVerifier with Abort")
            return
        }
        
        // Ensure that a TextOutputCallback was received with message "Abort"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Abort")
        
        // Finish the journey - should succeed
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceSigningVerifierCustom() async throws {
        // Advance to the DeviceSigningVerifier node with "custom" configuration
        let node = try await startTest(testConfiguration: "custom")
        
        // We expect DeviceSigningVerifierCallback with custom settings here. Assert its properties...
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        XCTAssertNotNil(deviceSigningVerifierCallback.userId)
        XCTAssertEqual(deviceSigningVerifierCallback.challenge, "my-hardcoded-challenge")
        XCTAssertEqual(deviceSigningVerifierCallback.title, "Custom Title")
        XCTAssertEqual(deviceSigningVerifierCallback.subtitle, "Custom Subtitle")
        XCTAssertEqual(deviceSigningVerifierCallback.description, "Custom Description")
        XCTAssertEqual(deviceSigningVerifierCallback.timeout, 0)
        
        // Set "Custom" client error - should trigger the "Custom" outcome
        _ = deviceSigningVerifierCallback.input("Custom", forKey: "IDToken1clientError")
        
        // Submit - should advance to a Message node with "Custom" text
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting DeviceSigningVerifier with Custom error")
            return
        }
        
        // Ensure that a TextOutputCallback was received with message "Custom"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Custom")
        
        // Finish the journey - should succeed
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceSigningVerifierWithUsernameCollector() async throws {
        // First, bind the device with authentication type "None"
        try await bindDevice(nodeConfiguration: "bind")
        
        // Advance to the DeviceSigningVerifier node
        let node = try await startTest(testConfiguration: "default")
        
        // We expect DeviceSigningVerifierCallback at this point
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Sign the challenge
        let signResult = await deviceSigningVerifierCallback.sign()
        
        switch signResult {
        case .success:
            break // Expected
        case .failure(let error):
            XCTFail("Device signing failed with error: \(error)")
            return
        }
        
        // Submit - DeviceSigningVerifier should trigger the "Success" outcome
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after signing verification")
            return
        }
        
        // Ensure that a TextOutputCallback is received with message "Success"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with 'Success' message")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Success")
        
        // Finish the journey
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceSigningVerifierUsernameless() async throws {
        // First, bind the device with authentication type "None"
        try await bindDevice(nodeConfiguration: "bind")
        
        // Advance to the DeviceSigningVerifier node with "usernameless" flow
        let node = try await startTest(testConfiguration: "usernameless")
        
        // We expect DeviceSigningVerifierCallback at this point
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Sign the challenge
        let signResult = await deviceSigningVerifierCallback.sign()
        
        switch signResult {
        case .success:
            break // Expected
        case .failure(let error):
            XCTFail("Device signing failed with error: \(error)")
            return
        }
        
        // Submit - DeviceSigningVerifier should trigger the "Success" outcome
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after signing verification")
            return
        }
        
        // Ensure that a TextOutputCallback is received with message "Success"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with 'Success' message")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Success")
        
        // Finish the journey
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceSigningVerifierTimeout() async throws {
        // First, bind the device with authentication type "None"
        try await bindDevice(nodeConfiguration: "bind")
        
        // Advance to the DeviceSigningVerifier node with "custom" configuration
        // Note: the "custom" DeviceSigningVerifier node is configured with timeout=0
        let node = try await startTest(testConfiguration: "custom")
        
        // We expect DeviceSigningVerifierCallback at this point
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Sign the challenge - should fail with timeout
        let signResult = await deviceSigningVerifierCallback.sign()
        
        switch signResult {
        case .success:
            XCTFail("Expected signing to fail with timeout, but got success")
            return
        case .failure(let error):
            // Verify timeout error
            if let bindingStatus = error as? DeviceBindingStatus {
                XCTAssertEqual(bindingStatus.clientError, "Timeout")
            }
        }
        
        // Submit - DeviceSigningVerifier should trigger the "Timeout" outcome
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after timeout")
            return
        }
        
        // Ensure that a TextOutputCallback is received with message "Timeout"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with 'Timeout' message")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Timeout")
        
        // Finish the journey
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceSigningVerifierPin() async throws {
        // This test fails on simulator
        try XCTSkipIf(isSimulator, "Cannot run this test on simulator")
        try XCTSkipIf(!Self.biometricTestsSupported, "This test requires PIN setup on the device")
        
        // Bind the device with authentication type "APPLICATION_PIN"
        try await bindDevice(nodeConfiguration: "bind-pin")
        
        // Advance to the DeviceSigningVerifier node
        let node = try await startTest(testConfiguration: "default")
        
        // We expect DeviceSigningVerifierCallback at this point
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Sign with custom PIN authenticator
        let pinCollector = CustomPinCollector(pin: Self.APPLICATION_PIN)
        let appPinConfig = AppPinConfig(pinCollector: pinCollector)
        let appPinAuthenticator = AppPinAuthenticator(config: appPinConfig)
        
        let signResult = await deviceSigningVerifierCallback.sign(authenticator: appPinAuthenticator)
        
        switch signResult {
        case .success:
            break // Expected
        case .failure(let error):
            XCTFail("Device signing with PIN failed with error: \(error)")
            return
        }
        
        // Submit - DeviceSigningVerifier should trigger the "Success" outcome
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after signing verification")
            return
        }
        
        // Ensure that a TextOutputCallback is received with message "Success"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with 'Success' message")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Success")
        
        // Finish the journey
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceSigningVerifierWrongPin() async throws {
        // This test fails on simulator
        try XCTSkipIf(isSimulator, "Cannot run this test on simulator")
        try XCTSkipIf(!Self.biometricTestsSupported, "This test requires PIN setup on the device")
        
        // Bind the device with authentication type "APPLICATION_PIN"
        try await bindDevice(nodeConfiguration: "bind-pin")
        
        // Advance to the DeviceSigningVerifier node
        let node = try await startTest(testConfiguration: "default")
        
        // We expect DeviceSigningVerifierCallback at this point
        guard let deviceSigningVerifierCallback = node.callbacks.first as? DeviceSigningVerifierCallback else {
            XCTFail("Expected DeviceSigningVerifierCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Sign with wrong PIN authenticator
        let pinCollector = CustomPinCollector(pin: "WRONG-PIN")
        let appPinConfig = AppPinConfig(pinCollector: pinCollector)
        let appPinAuthenticator = AppPinAuthenticator(config: appPinConfig)
        
        let signResult = await deviceSigningVerifierCallback.sign(authenticator: appPinAuthenticator)
        
        switch signResult {
        case .success:
            XCTFail("Expected signing to fail with wrong PIN, but got success")
            return
        case .failure(let error):
            // Verify the error is authorization-related
            if let bindingStatus = error as? DeviceBindingStatus {
                XCTAssertEqual(bindingStatus.clientError, "Abort")
            }
        }
        
        // Submit - DeviceSigningVerifier should trigger the "Abort" outcome
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after wrong PIN attempt")
            return
        }
        
        // Ensure that a TextOutputCallback is received with message "Abort"
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with 'Abort' message")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Abort")
        
        // Finish the journey
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after finishing the journey")
            return
        }
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    // MARK: - Helper Methods
    
    /// Bind a device before running signing verification tests.
    /// Possible values for nodeConfiguration are "bind" or "bind-pin"
    private func bindDevice(nodeConfiguration: String) async throws {
        // Start the journey
        let node = await defaultJourney.start(testTree)
        
        // First node: ChoiceCallback - select "collectusername"
        guard let choiceNode1 = node as? ContinueNode else {
            XCTFail("Expected ContinueNode (Choice collector) but got \(type(of: node))")
            throw XCTSkip("Failed to get choice collector node")
        }
        
        guard let choiceCallback1 = choiceNode1.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            throw XCTSkip("Missing ChoiceCallback")
        }
        
        if let idx = choiceCallback1.choices.firstIndex(of: "collectusername") {
            choiceCallback1.selectedIndex = idx
        } else {
            XCTFail("'collectusername' choice not found")
            throw XCTSkip("Invalid choice")
        }
        
        // Second node: NameCallback - provide username
        guard let usernameNode = await choiceNode1.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Username collector)")
            throw XCTSkip("Failed to get username collector node")
        }
        
        guard let nameCallback = usernameNode.callbacks.first as? NameCallback else {
            XCTFail("Expected NameCallback")
            throw XCTSkip("Missing NameCallback")
        }
        nameCallback.name = username
        
        // Third node: ChoiceCallback - select "bind" or "bind-pin"
        guard let choiceNode2 = await usernameNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Choice collector)")
            throw XCTSkip("Failed to get choice collector node")
        }
        
        guard let choiceCallback2 = choiceNode2.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            throw XCTSkip("Missing ChoiceCallback")
        }
        
        if let idx = choiceCallback2.choices.firstIndex(of: nodeConfiguration) {
            choiceCallback2.selectedIndex = idx
        } else {
            XCTFail("'\(nodeConfiguration)' choice not found")
            throw XCTSkip("Invalid choice")
        }
        
        // Fourth node: DeviceBindingCallback - execute bind
        guard let bindingNode = await choiceNode2.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (DeviceBinding)")
            throw XCTSkip("Failed to get device binding node")
        }
        
        guard let deviceBindingCallback = bindingNode.callbacks.first as? DeviceBindingCallback else {
            XCTFail("Expected DeviceBindingCallback")
            throw XCTSkip("Missing DeviceBindingCallback")
        }
        
        // Configure and execute the binding
        if nodeConfiguration == "bind-pin" {
            let pinCollector = CustomPinCollector(pin: Self.APPLICATION_PIN)
            let appPinConfig = AppPinConfig(pinCollector: pinCollector)
            let appPinAuthenticator = AppPinAuthenticator(config: appPinConfig)
            let bindResult = await deviceBindingCallback.bind { config in
                config.deviceAuthenticator = appPinAuthenticator
            }
            switch bindResult {
            case .success:
                break // Expected
            case .failure(let error):
                XCTFail("Device binding with PIN failed: \(error)")
                throw XCTSkip("Binding failed")
            }
        } else {
            let bindResult = await deviceBindingCallback.bind()
            switch bindResult {
            case .success:
                break // Expected
            case .failure(let error):
                XCTFail("Device binding failed: \(error)")
                throw XCTSkip("Binding failed")
            }
        }
        
        // Submit and expect SuccessNode (user is logged in)
        guard let result = await bindingNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after device binding")
            throw XCTSkip("Binding did not succeed")
        }
        
        XCTAssertNotNil(result.session)
        
        // Logout after binding
        await defaultJourney.journeyUser()?.logout()
    }
    
    /// Helper function for processing common steps in test cases.
    /// Valid values for "testConfiguration" are "usernameless", "default" or "custom"
    func startTest(testConfiguration: String) async throws -> ContinueNode {
        // Start the journey
        let node = await defaultJourney.start(testTree)
        
        // First node: ChoiceCallback - select "collectusername" or "usernameless"
        guard let choiceNode1 = node as? ContinueNode else {
            XCTFail("Expected ContinueNode (Choice collector) but got \(type(of: node))")
            throw XCTSkip("Failed to get choice collector node")
        }
        
        guard let choiceCallback1 = choiceNode1.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            throw XCTSkip("Missing ChoiceCallback")
        }
        
        if testConfiguration == "usernameless" {
            if let idx = choiceCallback1.choices.firstIndex(of: "usernameless") {
                choiceCallback1.selectedIndex = idx
            } else {
                XCTFail("'usernameless' choice not found")
                throw XCTSkip("Invalid choice")
            }
            
            // For usernameless flow, return the next node directly (DSV node)
            guard let resultNode = await choiceNode1.next() as? ContinueNode else {
                XCTFail("Expected ContinueNode (DeviceSigningVerifier) after usernameless selection")
                throw XCTSkip("Failed to get DSV node")
            }
            return resultNode
        }
        
        // For other flows, select "collectusername"
        if let idx = choiceCallback1.choices.firstIndex(of: "collectusername") {
            choiceCallback1.selectedIndex = idx
        } else {
            XCTFail("'collectusername' choice not found")
            throw XCTSkip("Invalid choice")
        }
        
        // Second node: NameCallback - provide username
        guard let usernameNode = await choiceNode1.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Username collector)")
            throw XCTSkip("Failed to get username collector node")
        }
        
        guard let nameCallback = usernameNode.callbacks.first as? NameCallback else {
            XCTFail("Expected NameCallback")
            throw XCTSkip("Missing NameCallback")
        }
        nameCallback.name = username
        
        // Third node: ChoiceCallback - select "default" or "custom"
        guard let choiceNode2 = await usernameNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Choice collector)")
            throw XCTSkip("Failed to get choice collector node")
        }
        
        guard let choiceCallback2 = choiceNode2.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            throw XCTSkip("Missing ChoiceCallback")
        }
        
        if let idx = choiceCallback2.choices.firstIndex(of: testConfiguration) {
            choiceCallback2.selectedIndex = idx
        } else {
            XCTFail("'\(testConfiguration)' choice not found")
            throw XCTSkip("Invalid choice")
        }
        
        // Fourth node: DeviceSigningVerifier callback
        guard let resultNode = await choiceNode2.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (DeviceSigningVerifier) after selecting '\(testConfiguration)'")
            throw XCTSkip("Failed to get DSV node")
        }
        
        return resultNode
    }
    
    /// Custom PinCollector for testing
    class CustomPinCollector: PinCollector {
        private var pin: String = ""
        
        required public init(pin: String) {
            self.pin = pin
        }
        
        func collectPin(prompt: Prompt, completion: @escaping @Sendable (String?) -> Void) {
            completion(self.pin)
        }
    }
}
