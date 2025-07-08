//
//  ExternalIdPTests.swift
//  ExternalIdPTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci
@testable import PingExternalIdP
@testable import PingOrchestrate

@MainActor
final class ExternalIdPTests: XCTestCase {

    override func setUpWithError() throws {
        Task {
            await CollectorFactory.shared.registerDefaultCollectors()
        }
    }
    
    func testIdpCollectorRegistration() async throws {
        let idpCollector = await CollectorFactory.shared.collectors[Constants.SOCIAL_LOGIN_BUTTON]
        XCTAssertNotNil(idpCollector)
    }

    func testIdpCollectorParsing() throws {
        
        let jsonObject: [String: Any] = [
            "idpId" : "c3e6a164bde107954e93f5c09f0c8bce",
            "idpType" : "GOOGLE",
            "type" : "SOCIAL_LOGIN_BUTTON",
            "label" : "Sign in with Google",
            "links" : [
              "authenticate" : [
                "href" : "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/c3e6a164bde107954e93f5c09f0c8bce/capabilities/loginFirstFactor?interactionId=00e792f3-68a3-47a8-9887-96f2afa87ed0&interactionToken=96b769b009374865fd2d2cc12d1889596fe9bf0923cd7215c9d48f31d4580af74f781515d1944de5101ab4a91014d7afb9cb5ff376a3f6c9109a17c7940ccaeefff9c32d0b39832dbf508315f4b3b4dd1973683b23081c1754e884009de348d0457294a71fdb4386c6431fc15f409c49a3687475219ca07647f7ad1119688879&skRefreshToken=true&identityProviderId=27724658-9f93-4d3a-9817-e0e5f9778080&populationId=2390570b-c63d-483f-8eb6-a16260cfa8ea&createP1User=true&returnUrl=myapp%3A%2F%2Fexample.com"
              ]
            ]
        ]
        
        let idpCollector = IdpCollector(with: jsonObject)
        XCTAssertEqual(idpCollector.idpType, "GOOGLE")
        XCTAssertEqual(idpCollector.label, "Sign in with Google")
        XCTAssertNotNil(idpCollector.link)
        XCTAssertEqual(idpCollector.link!, URL(string: "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/c3e6a164bde107954e93f5c09f0c8bce/capabilities/loginFirstFactor?interactionId=00e792f3-68a3-47a8-9887-96f2afa87ed0&interactionToken=96b769b009374865fd2d2cc12d1889596fe9bf0923cd7215c9d48f31d4580af74f781515d1944de5101ab4a91014d7afb9cb5ff376a3f6c9109a17c7940ccaeefff9c32d0b39832dbf508315f4b3b4dd1973683b23081c1754e884009de348d0457294a71fdb4386c6431fc15f409c49a3687475219ca07647f7ad1119688879&skRefreshToken=true&identityProviderId=27724658-9f93-4d3a-9817-e0e5f9778080&populationId=2390570b-c63d-483f-8eb6-a16260cfa8ea&createP1User=true&returnUrl=myapp%3A%2F%2Fexample.com")!)
        XCTAssertNotNil(idpCollector.id)
        XCTAssertEqual(idpCollector.idpId, "c3e6a164bde107954e93f5c09f0c8bce")
        XCTAssertEqual(idpCollector.idpEnabled, true)
    }
    
    func testBrowserHandlerInitialization() async {
        let mockWorkflow = WorkflowMock(config: WorkflowConfig())
        let mockContext = FlowContextMock(flowContext: SharedContext())
        let mockNode = NodeMock()
        
        mockWorkflow.nextReturnValue = mockNode
        
        let connector = TestContinueNode(context: mockContext, workflow: mockWorkflow, input: [:], actions: [])
        
        let browserHandler = BrowserHandler(continueNode: connector, callbackURLScheme: "myApp")
        XCTAssertNotNil(browserHandler)
        XCTAssertEqual(browserHandler.callbackURLScheme, "myApp")
    }
    
    func testIdpHandlerAuthorizeThrow() async throws {
        let mockWorkflow = WorkflowMock(config: WorkflowConfig())
        let mockContext = FlowContextMock(flowContext: SharedContext())
        let mockNode = NodeMock()
        
        mockWorkflow.nextReturnValue = mockNode
        
        let connector = TestContinueNode(context: mockContext, workflow: mockWorkflow, input: [:], actions: [])
        
        let browserHandler = BrowserHandler(continueNode: connector, callbackURLScheme: "myApp")
        
        do {
            let _ = try await browserHandler.authorize(url: nil)
            XCTAssertFalse(true)
        } catch IdpExceptions.illegalArgumentException(let errorResponse) {
            XCTAssertTrue(errorResponse == "continueUrl not found")
        }
    }
}

// Supporting Test Classes
class WorkflowMock: Workflow, @unchecked Sendable {
    var nextReturnValue: Node?
  override func next(_ context: FlowContext, _ current: ContinueNode) async -> Node {
        return NodeMock()
    }
}

class FlowContextMock: FlowContext {}

class NodeMock: Node, @unchecked Sendable {}

class TestContinueNode: ContinueNode, @unchecked Sendable {
    override func asRequest() -> Request {
        return RequestMock(urlString: "https://openam.example.com")
    }
}

class RequestMock: Request, @unchecked Sendable {}
