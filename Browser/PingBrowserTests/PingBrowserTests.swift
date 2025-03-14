//
//  PingBrowserTests.swift
//  PingBrowserTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBrowser
@testable import External_idp
@testable import PingOrchestrate


/// Tests for the BrowserHandler class.
@MainActor
final class PingBrowserTests: XCTestCase {
    
    // Hold a reference to the original browser so that we can restore it in tearDown.
    var originalBrowser: BrowserLauncherProtocol!
    var mockBrowser: MockBrowserLauncher!
    var connector: TestContinueNode!
    let continueURL = "https://example.com/continue"
    
    override func setUp() async throws {
        Task {
            try await super.setUp()
        }
        // Save the original BrowserLauncher and replace it with our mock.
        // (Assumes that BrowserLauncher.currentBrowser is mutable and of type BrowserLauncherProtocol.)
        originalBrowser = BrowserLauncher.currentBrowser
        mockBrowser = MockBrowserLauncher()
        BrowserLauncher.currentBrowser = mockBrowser
        
        // Create a mock ContinueNode with the expected _links structure.
        let mockWorkflow = WorkflowMock(config: WorkflowConfig())
        let mockContext = FlowContextMock(flowContext: SharedContext())
        let mockNode = NodeMock()
        
        mockWorkflow.nextReturnValue = mockNode
        
        
        connector = TestContinueNode(context: mockContext, workflow: mockWorkflow, input: [
            Request.Constants._links: [
                Request.Constants._continue: [
                    Request.Constants.href: continueURL
                ]
            ]
        ], actions: [])
    }
    
    override func tearDown() async throws {
        // Restore the original BrowserLauncher.
        BrowserLauncher.currentBrowser = originalBrowser
        originalBrowser = nil
        mockBrowser = nil
        connector =  nil
        Task {
            try await super.tearDown()
        }
    }
    
    func testCurrentBrowser() throws {
        let browser = BrowserLauncher.currentBrowser
        XCTAssertNotNil(browser)
        XCTAssertFalse(browser.isInProgress)
    }
    
    /// Tests that a successful authorization produces a Request with the correct URL, header, and body.
    func testAuthorizeSuccess() async throws {
        // Arrange
        let continueToken = "abc123"
        // Simulate the browser launcher returning a URL that includes the continueToken in the query.
        let browserReturnURL = URL(string: "myapp://callback?continueToken=\(continueToken)")!
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            return browserReturnURL
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act
        let request = try await handler.authorize(url: url)
        
        // Assert
        XCTAssertEqual(request.urlRequest.url!.absoluteString, continueURL)
        XCTAssertEqual(request.urlRequest.allHTTPHeaderFields?[Request.Constants.authorization], "Bearer \(continueToken)")
        XCTAssertEqual(request.urlRequest.httpMethod, "POST")
    }
    
    
    /// Tests that calling authorize with a nil URL throws an illegalArgumentException.
    func testAuthorizeNilURL() async {
        // Arrange
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        // Act & Assert
        do {
            let url: URL? = nil
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception when URL is nil.")
        } catch let error as IdpExceptions {
            XCTAssertEqual(error.errorMessage, "illegalArgumentException Idp Exception: continueUrl not found")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Tests that if the BrowserLauncher fails (throws an error), authorize throws an illegalStateException.
    func testAuthorizeBrowserLauncherFailure() async {
        // Arrange
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            throw BrowserError.externalUserAgentFailure
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act & Assert
        do {
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception due to BrowserLauncher failure.")
        } catch let error as IdpExceptions {
            XCTFail("Unexpected error type: \(error)")
        } catch  let error as BrowserError {
            XCTAssertEqual(error, BrowserError.externalUserAgentFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Tests that if the browser returns a URL without query items, authorize throws an illegalStateException.
    func testAuthorizeMissingQueryItems() async {
        // Arrange: the browser returns a URL with no query items.
        let browserReturnURL = URL(string: "myapp://callback")!
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            return browserReturnURL
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act & Assert
        do {
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception due to missing query items in the response URL.")
        } catch let error as IdpExceptions {
            XCTAssertEqual(error.errorMessage, "illegalStateException Idp Exception: Could not read response URL")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Tests that if the continueToken parameter is missing from the browser response URL, authorize throws an illegalStateException.
    func testAuthorizeMissingContinueToken() async {
        // Arrange: the browser returns a URL with a query parameter that is not continueToken.
        let browserReturnURL = URL(string: "myapp://callback?otherParam=value")!
        mockBrowser.launchHandler = { url, browserType, callbackURLScheme in
            return browserReturnURL
        }
        
        let handler = BrowserHandler(continueNode: connector, callbackURLScheme: "myapp")
        let url = URL(string: "https://auth.example.com")!
        
        // Act & Assert
        do {
            _ = try await handler.authorize(url: url)
            XCTFail("Expected an exception due to missing continueToken in the URL query items.")
        } catch let error as IdpExceptions {
            XCTAssertEqual(error.errorMessage, "illegalStateException Idp Exception: Could not read continueToken")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

/// Supporting Test Classes
class WorkflowMock: Workflow, @unchecked Sendable {
    var nextReturnValue: Node?
    override func next(_ context: FlowContext, _ current: ContinueNode) async -> Node {
        return NodeMock()
    }
}

class FlowContextMock: FlowContext {}

final class NodeMock: Node {}

class TestContinueNode: ContinueNode, @unchecked Sendable {
    override func asRequest() -> Request {
        return RequestMock(urlString: "https://openam.example.com")
    }
}

class RequestMock: Request, @unchecked Sendable {}

/// A mock BrowserLauncher that you can control in tests.
class MockBrowserLauncher: BrowserLauncherProtocol {
    func reset() async {
        self.isInProgress = false
    }
    
    var isInProgress: Bool = false
    
    /// A closure that will be called when `launch` is invoked.
    var launchHandler: ((URL, BrowserType, String) async throws -> URL)?
    
    func launch(url: URL, browserType: BrowserType, callbackURLScheme: String) async throws -> URL {
        if let handler = launchHandler {
            return try await handler(url, browserType, callbackURLScheme)
        }
        throw NSError(domain: "MockBrowserLauncher", code: 0, userInfo: nil)
    }
}
