//
//  DeviceBindingCallbackE2ETests.swift
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

class DeviceBindingCallbackE2ETests: BindingE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "device-bind"
    
    // MARK: - Tests
    
    func testDeviceBindingDefaults() async throws {
        // Advance to the DeviceBinding node with "default" configuration
        let node = try await startTest(nodeConfiguration: "default")
        
        // We expect DeviceBindingCallback with default settings here. Assert its properties...
        guard let deviceBindingCallback = node.callbacks.first as? DeviceBindingCallback else {
            XCTFail("Expected DeviceBindingCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        XCTAssertNotNil(deviceBindingCallback.userId)
        XCTAssertNotNil(deviceBindingCallback.challenge)
        XCTAssertEqual(deviceBindingCallback.deviceBindingAuthenticationType, DeviceBindingAuthenticationType.biometricAllowFallback)
        XCTAssertEqual(deviceBindingCallback.title, "Authentication required")
        XCTAssertEqual(deviceBindingCallback.subtitle, "Cryptography device binding")
        XCTAssertEqual(deviceBindingCallback.description, "Please complete with biometric to proceed")
        XCTAssertEqual(deviceBindingCallback.timeout, 60)
        
        // Set "Abort" client error via the callback's input
        _ = deviceBindingCallback.input("Abort", forKey: "IDToken1clientError")
        
        // Submit and expect SuccessNode (journey configured to succeed on abort)
        guard let result = await node.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting DeviceBinding callback with Abort")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceBindingCustom() async throws {
        // Advance to the DeviceBinding node with "custom" configuration
        let node = try await startTest(nodeConfiguration: "custom")
        
        // We expect DeviceBindingCallback with custom settings here. Assert its properties...
        guard let deviceBindingCallback = node.callbacks.first as? DeviceBindingCallback else {
            XCTFail("Expected DeviceBindingCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        XCTAssertNotNil(deviceBindingCallback.userId)
        XCTAssertNotNil(deviceBindingCallback.challenge)
        XCTAssertEqual(deviceBindingCallback.deviceBindingAuthenticationType, DeviceBindingAuthenticationType.none)
        XCTAssertEqual(deviceBindingCallback.title, "Custom title")
        XCTAssertEqual(deviceBindingCallback.subtitle, "Custom subtitle")
        XCTAssertEqual(deviceBindingCallback.description, "Custom description")
        XCTAssertEqual(deviceBindingCallback.timeout, 5)
        
        // Set "Custom" client error - this should trigger the "Custom" outcome of the node
        _ = deviceBindingCallback.input("Custom", forKey: "IDToken1clientError")
        
        // Submit and expect ContinueNode (should receive a Message node with TextOutput + Confirmation)
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting DeviceBinding callback with Custom error")
            return
        }
        
        // Verify TextOutputCallback message
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Custom outcome triggered")
        
        // Handle ConfirmationCallback
        guard let confirmationCallback = nextNode.callbacks.last as? ConfirmationCallback else {
            XCTFail("Expected ConfirmationCallback")
            return
        }
        confirmationCallback.selectedIndex = 0
        
        // Submit and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after confirming")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceBindingBind() async throws {
        // Advance to the DeviceBinding node with "custom" configuration (auth type: NONE)
        let node = try await startTest(nodeConfiguration: "custom")
        
        // We expect DeviceBindingCallback here
        guard let deviceBindingCallback = node.callbacks.first as? DeviceBindingCallback else {
            XCTFail("Expected DeviceBindingCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Execute the bind operation
        let bindResult = await deviceBindingCallback.bind()
        
        switch bindResult {
        case .success:
            break // Expected
        case .failure(let error):
            XCTFail("Device binding failed with error: \(error)")
            return
        }
        
        // Submit and expect SuccessNode
        guard let result = await node.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after successful device binding")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceBindingExceed() async throws {
        // Advance to the DeviceBinding node with "exceed-limit" configuration
        // The journey should automatically trigger the "Exceed Device Limit" outcome
        let node = try await startTest(nodeConfiguration: "exceed-limit")
        
        // We expect a Message node with TextOutputCallback and ConfirmationCallback
        guard let textOutputCallback = node.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with 'Device Limit Exceeded' message")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Device Limit Exceeded")
        
        // Handle ConfirmationCallback
        guard let confirmationCallback = node.callbacks.last as? ConfirmationCallback else {
            XCTFail("Expected ConfirmationCallback")
            return
        }
        confirmationCallback.selectedIndex = 0
        
        // Submit and expect SuccessNode
        guard let result = await node.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after confirming device limit exceeded")
            return
        }
        
        logger.i("Session: \(result.session.value)")
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceBindingWrongAppId() async throws {
        // Advance to the DeviceBinding node with "wrong-app-id" configuration
        let node = try await startTest(nodeConfiguration: "wrong-app-id")
        
        // We expect DeviceBindingCallback here
        guard let deviceBindingCallback = node.callbacks.first as? DeviceBindingCallback else {
            XCTFail("Expected DeviceBindingCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Execute the bind operation - should succeed locally (key is created) but server should reject
        let bindResult = await deviceBindingCallback.bind()
        
        switch bindResult {
        case .success:
            break // Key is created locally, but server will reject
        case .failure(let error):
            XCTFail("Device binding failed with error: \(error)")
            return
        }
        
        // Submit - the server should reject the binding due to wrong app ID
        let nextNode = await node.next()
        
        // Expect either FailureNode or ErrorNode (server-side rejection)
        XCTAssertFalse(nextNode is SuccessNode, "Expected failure but got SuccessNode")
    }
    
    // MARK: - Helper Methods
    
    /// Common steps for all test cases:
    /// 1. Start journey and provide username via NameCallback
    /// 2. Select nodeConfiguration via ChoiceCallback
    /// 3. Return the resulting ContinueNode (typically the DeviceBinding node)
    private func startTest(nodeConfiguration: String) async throws -> ContinueNode {
        // Start the journey
        let node = await defaultJourney.start(testTree)
        
        // First node: Username collector
        guard let usernameNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode (Username collector) but got \(type(of: node))")
            throw XCTSkip("Failed to get username collector node")
        }
        
        guard let nameCallback = usernameNode.callbacks.first as? NameCallback else {
            XCTFail("Expected NameCallback for username collection")
            throw XCTSkip("Missing NameCallback")
        }
        nameCallback.name = username
        
        // Second node: Choice collector
        guard let choiceNode = await usernameNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Choice collector) after username")
            throw XCTSkip("Failed to get choice collector node")
        }
        
        guard let choiceCallback = choiceNode.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback for node configuration selection")
            throw XCTSkip("Missing ChoiceCallback")
        }
        
        // Select the requested node configuration
        if let choiceIndex = choiceCallback.choices.firstIndex(of: nodeConfiguration) {
            choiceCallback.selectedIndex = choiceIndex
        } else {
            XCTFail("Choice '\(nodeConfiguration)' not found in available choices: \(choiceCallback.choices)")
            throw XCTSkip("Invalid choice configuration")
        }
        
        // Third node: DeviceBinding callback (or message node for exceed-limit)
        guard let resultNode = await choiceNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after selecting '\(nodeConfiguration)'")
            throw XCTSkip("Failed to get result node")
        }
        
        return resultNode
    }
}
