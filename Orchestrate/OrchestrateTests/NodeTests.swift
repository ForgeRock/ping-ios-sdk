//
//  NodeTests.swift
//  OrchestrateTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingOrchestrate

final class NodeTests: XCTestCase {
    
    func testConnectorNextShouldReturnContinueNodeInWorkflow() async {
        let mockWorkflow = WorkflowMock(config: WorkflowConfig())
        let mockContext = FlowContextMock(flowContext: SharedContext())
        let mockNode = NodeMock()
        
        mockWorkflow.nextReturnValue = mockNode
        
        let connector = TestContinueNode(context: mockContext, workflow: mockWorkflow, input: [:], actions: [])
        
        let continueNode = await connector.next()
        XCTAssertTrue(continueNode as? NodeMock === mockNode)
    }
    
    func testConnectorCloseShouldCloseAllCloseableActions() {
        let closeableAction = TestAction()
        let connector = TestContinueNode(context: FlowContextMock(flowContext: SharedContext()), workflow: WorkflowMock(config: WorkflowConfig()), input: [:], actions: [closeableAction])
        
        connector.close()
        
        XCTAssertTrue(closeableAction.isClosed)
    }
}

// Supporting Test Classes
class WorkflowMock: Workflow, @unchecked Sendable {
    var nextReturnValue: Node?
    override func next(_ context: FlowContext, _ current: ContinueNode) async -> Node {
        return nextReturnValue ?? NodeMock()
    }
}

class FlowContextMock: FlowContext {}

final class NodeMock: Node {}

class TestContinueNode: ContinueNode, @unchecked Sendable {
    override func asRequest() -> Request {
        return RequestMock(urlString: "https://openam.example.com")
    }
}

class TestAction: Action, Closeable, @unchecked Sendable {
    var isClosed = false
    func close() {
        isClosed = true
    }
}

class RequestMock: Request, @unchecked Sendable {}
