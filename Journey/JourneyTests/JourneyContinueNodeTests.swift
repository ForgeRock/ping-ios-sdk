//
//  JourneyContinueNodeTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOrchestrate

final class JourneyContinueNodeTests: XCTestCase {
    
    // MARK: - Mock Classes
    
    struct MockCallback: Callback, @unchecked Sendable {
        typealias T = String
        let id: String
        private var json: [String: Any]
        
        init(with json: [String: Any]) {
            self.json = json
            self.id = json["_id"] as? String ?? ""
        }
        
        func payload() -> [String: Any] {
            return ["value": "test"]
        }
    }
    
    // MARK: - ContinueNode Extension Tests
    
    func testCallbacksExtraction() {
        let mockCallback1 = MockCallback(with: ["_id": "1"])
        let mockCallback2 = MockCallback(with: ["_id": "2"])
        let mockActions: [Action] = [mockCallback1, mockCallback2]
        
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let continueNode = ContinueNode(context: context, workflow: workflow, input: [:], actions: mockActions)
        
        XCTAssertEqual(continueNode.callbacks.count, 2)
        XCTAssertTrue(continueNode.callbacks[0] is MockCallback)
        XCTAssertTrue(continueNode.callbacks[1] is MockCallback)
    }
    
    // MARK: - JourneyContinueNode Tests
    
    func testJourneyContinueNodeInitialization() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input = ["authId": "test-auth-id"]
        let mockCallback = MockCallback(with: ["_id": "1"])
        
        let node = JourneyContinueNode(context: context,
                                     workflow: workflow,
                                     input: input,
                                     actions: [mockCallback])
        
        XCTAssertNotNil(node)
    }
    
    func testJourneyContinueNodeRequest() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        
        let input = ["authId": "test-auth-id"]
        let mockCallback = MockCallback(with: ["_id": "1"])
        
        let node = JourneyContinueNode(context: context,
                                     workflow: journey,
                                     input: input,
                                     actions: [mockCallback])
        
        let request = node.asRequest()
        
        XCTAssertEqual(request.urlRequest.url?.absoluteString, "https://test.com/json/realms/test-realm/authenticate")
        XCTAssertEqual(request.urlRequest.value(forHTTPHeaderField: JourneyConstants.contentType), JourneyConstants.applicationJson)
        
        if let httpBody = request.urlRequest.httpBody,
           let bodyJson = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            XCTAssertEqual(bodyJson["authId"] as? String, "test-auth-id")
            XCTAssertNotNil(bodyJson[JourneyConstants.callbacks])
        } else {
            XCTFail("Failed to parse request body")
        }
    }
    
    func testJourneyContinueNodeDefaultValues() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [:]
        let mockCallback = MockCallback(with: ["_id": "1"])
        
        let node = JourneyContinueNode(context: context,
                                     workflow: workflow,
                                     input: input,
                                     actions: [mockCallback])
        
        let request = node.asRequest()
        
        XCTAssertEqual(request.urlRequest.url?.path, "/json/realms/root/authenticate")
        
        if let httpBody = request.urlRequest.httpBody,
           let bodyJson = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            XCTAssertEqual(bodyJson["authId"] as? String, "")
        } else {
            XCTFail("Failed to parse request body")
        }
    }
    
    func testEmptyCallbacksPayload() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input = ["authId": "test-auth-id"]
        
        let node = JourneyContinueNode(context: context,
                                     workflow: workflow,
                                     input: input,
                                     actions: [])
        
        let request = node.asRequest()
        
        if let httpBody = request.urlRequest.httpBody,
           let bodyJson = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            XCTAssertEqual((bodyJson[JourneyConstants.callbacks] as? [[String: Any]])?.count, 0)
        } else {
            XCTFail("Failed to parse request body")
        }
    }
}
