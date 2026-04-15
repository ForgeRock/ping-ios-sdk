//
//  JourneyContinueNodeTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 - 2026 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourneyPlugin
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingNetwork

final class JourneyContinueNodeTests: XCTestCase {
    
    // MARK: - Mock Classes
    
    class MockCallback: Callback, @unchecked Sendable {

        typealias T = String
        var id: String = ""
        private var json: [String: Any] = [:]

        required init() {}

        func initialize(with json: [String : Any]) -> any Callback {
            self.json = json
            self.id = json["_id"] as? String ?? ""
            return self
        }
        
        func payload() -> [String: Any] {
            return ["value": "test"]
        }
    }
    
    // MARK: - ContinueNode Extension Tests
    
    func testCallbacksExtraction() {
        let mockCallback1 = MockCallback().initialize(with: ["_id": "1"])
        let mockCallback2 = MockCallback().initialize(with: ["_id": "2"])
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
        let mockCallback = MockCallback().initialize(with: ["_id": "1"])

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
        let mockCallback = MockCallback().initialize(with: ["_id": "1"])

        let node = JourneyContinueNode(context: context,
                                     workflow: journey,
                                     input: input,
                                     actions: [mockCallback])
        
        guard let request = node.asRequest() as? URLSessionHttpRequest else {
            XCTFail("request should be URLSessionHttpRequest")
            return
        }
        
        XCTAssertEqual(request.url, "https://test.com/json/realms/test-realm/authenticate")
        XCTAssertEqual(request.getHeader(name: JourneyConstants.contentType), JourneyConstants.applicationJson)
        
        if let httpBody = request.buildURLRequest()?.httpBody,
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
        let mockCallback = MockCallback().initialize(with: ["_id": "1"])

        let node = JourneyContinueNode(context: context,
                                     workflow: workflow,
                                     input: input,
                                     actions: [mockCallback])
        
        guard let request = node.asRequest() as? URLSessionHttpRequest else {
            XCTFail("request should be URLSessionHttpRequest")
            return
        }
        
        XCTAssertEqual(URL(string: request.url ?? "")?.path, "/json/realms/root/authenticate")
        
        if let httpBody = request.buildURLRequest()?.httpBody,
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
        
        guard let request = node.asRequest() as? URLSessionHttpRequest else {
            XCTFail("request should be URLSessionHttpRequest")
            return
        }
        
        if let httpBody = request.buildURLRequest()?.httpBody,
           let bodyJson = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            XCTAssertEqual((bodyJson[JourneyConstants.callbacks] as? [[String: Any]])?.count, 0)
        } else {
            XCTFail("Failed to parse request body")
        }
    }
    
    // MARK: - ContinueNode Property Tests
    
    func testDescriptionProperty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input = [JourneyConstants.description: "This is a test description"]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageDescription, "This is a test description")
    }
    
    func testDescriptionPropertyEmpty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [:]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageDescription, "")
    }
    
    func testHeaderProperty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input = [JourneyConstants.header: "Welcome Back"]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageHeader, "Welcome Back")
    }
    
    func testHeaderPropertyEmpty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [:]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageHeader, "")
    }
    
    func testStageProperty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input = [JourneyConstants.stage: "Registration"]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.stage, "Registration")
    }
    
    func testStagePropertyEmpty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [:]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.stage, "")
    }
    
    // MARK: - Submit Button Text Tests
    
    func testSubmitButtonTextFromStageJSON() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{\"en\":\"Submit\",\"fr\":\"Soumettre\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // The result depends on the device's locale, but should not be empty
        XCTAssertFalse(node.submitButtonText.isEmpty)
        XCTAssertTrue(node.submitButtonText == "Submit" || node.submitButtonText == "Soumettre")
    }
    
    func testSubmitButtonTextFromStageJSONWithLocale() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{\"en-gb\":\"Submit Now\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should extract the value regardless of exact locale match
        XCTAssertEqual(node.submitButtonText, "Submit Now")
    }
    
    func testSubmitButtonTextEmpty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [:]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.submitButtonText, "")
    }
    
    func testSubmitButtonTextWithNonJSONStage() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [
            JourneyConstants.stage: "SimpleStageString"
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should return empty string when stage is not JSON
        XCTAssertEqual(node.submitButtonText, "")
    }
    
    // MARK: - Page Footer Tests
    
    func testPageFooterFromStageJSON() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"pageFooter\":{\"en\":\"English Footer\",\"fr\":\"Pied de page français\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // The result depends on the device's locale, but should not be empty
        XCTAssertFalse(node.pageFooter.isEmpty)
        XCTAssertTrue(node.pageFooter == "English Footer" || node.pageFooter == "Pied de page français")
    }
    
    func testPageFooterFromStageJSONWithLocale() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"pageFooter\":{\"en-gb\":\"UK Footer Text\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageFooter, "UK Footer Text")
    }
    
    func testPageFooterEmpty() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [:]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageFooter, "")
    }
    
    func testPageFooterWithNonJSONStage() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [
            JourneyConstants.stage: "SimpleStageString"
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should return empty string when stage is not JSON
        XCTAssertEqual(node.pageFooter, "")
    }
    
    // MARK: - Combined Stage JSON Tests
    
    func testCombinedStageJSONProperties() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{\"en\":\"Continue\"},\"pageFooter\":{\"en\":\"Help available 24/7\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.submitButtonText, "Continue")
        XCTAssertEqual(node.pageFooter, "Help available 24/7")
    }
    
    func testStageJSONWithMultipleLocales() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = """
        {
            "submitButtonText": {
                "en": "Submit",
                "en-gb": "Submit Now",
                "en-us": "Submit Form",
                "fr": "Soumettre",
                "es": "Enviar"
            },
            "pageFooter": {
                "en": "Footer",
                "fr": "Pied de page",
                "es": "Pie de página"
            }
        }
        """
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should successfully extract values
        XCTAssertFalse(node.submitButtonText.isEmpty)
        XCTAssertFalse(node.pageFooter.isEmpty)
    }
    
    func testStageJSONWithUnderscoreLocale() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{\"en_GB\":\"Submit\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should handle underscore format
        XCTAssertEqual(node.submitButtonText, "Submit")
    }
    
    func testInvalidStageJSON() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [
            JourneyConstants.stage: "{invalid json"
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should return empty strings when JSON is invalid
        XCTAssertEqual(node.submitButtonText, "")
        XCTAssertEqual(node.pageFooter, "")
        // Stage should still return the original string
        XCTAssertEqual(node.stage, "{invalid json")
    }
    
    func testStageAsSimpleString() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let input: [String: Any] = [
            JourneyConstants.stage: "Registration"
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Stage should remain as simple string
        XCTAssertEqual(node.stage, "Registration")
        // Should return empty strings when stage is not JSON
        XCTAssertEqual(node.submitButtonText, "")
        XCTAssertEqual(node.pageFooter, "")
    }
    
    func testStageJSONWithOnlyOneValue() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{\"xyz\":\"Single Value\"}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should return the single available value even if locale doesn't match
        XCTAssertEqual(node.submitButtonText, "Single Value")
    }
    
    func testStageJSONWithEmptyLocalizedDict() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{}}"
        let input: [String: Any] = [
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        // Should return empty string when localized dict is empty
        XCTAssertEqual(node.submitButtonText, "")
    }
    
    func testAllPropertiesTogether() {
        let sharedContext = SharedContext()
        let context = FlowContext(flowContext: sharedContext)
        let config = WorkflowConfig()
        let workflow = Workflow(config: config)
        let stageJSON = "{\"submitButtonText\":{\"en\":\"Submit\"},\"pageFooter\":{\"en\":\"Footer\"}}"
        let input: [String: Any] = [
            JourneyConstants.description: "Form Description",
            JourneyConstants.header: "Welcome",
            JourneyConstants.stage: stageJSON
        ]
        
        let node = ContinueNode(context: context, workflow: workflow, input: input, actions: [])
        
        XCTAssertEqual(node.pageDescription, "Form Description")
        XCTAssertEqual(node.pageHeader, "Welcome")
        XCTAssertEqual(node.stage, stageJSON)
        XCTAssertEqual(node.submitButtonText, "Submit")
        XCTAssertEqual(node.pageFooter, "Footer")
    }
}
