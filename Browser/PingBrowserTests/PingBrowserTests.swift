//
//  PingBrowserTests.swift
//  PingBrowserTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBrowser
@testable import PingExternalIdP
@testable import PingOrchestrate
@testable import PingNetwork

// MARK: - BrowserType Tests

@MainActor
final class BrowserTypeTests: XCTestCase {
    
    func testBrowserTypeRawValues() {
        XCTAssertEqual(BrowserType.authSession.rawValue, 0)
        XCTAssertEqual(BrowserType.nativeBrowserApp.rawValue, 1)
        XCTAssertEqual(BrowserType.sfViewController.rawValue, 2)
        XCTAssertEqual(BrowserType.ephemeralAuthSession.rawValue, 3)
    }
    
    func testBrowserTypeInitFromRawValue() {
        XCTAssertEqual(BrowserType(rawValue: 0), .authSession)
        XCTAssertEqual(BrowserType(rawValue: 1), .nativeBrowserApp)
        XCTAssertEqual(BrowserType(rawValue: 2), .sfViewController)
        XCTAssertEqual(BrowserType(rawValue: 3), .ephemeralAuthSession)
        XCTAssertNil(BrowserType(rawValue: 99))
    }
}

// MARK: - BrowserError Tests

@MainActor
final class BrowserErrorTests: XCTestCase {
    
    func testBrowserErrorEquality() {
        XCTAssertEqual(BrowserError.externalUserAgentFailure, BrowserError.externalUserAgentFailure)
        XCTAssertEqual(BrowserError.externalUserAgentAuthenticationInProgress, BrowserError.externalUserAgentAuthenticationInProgress)
        XCTAssertEqual(BrowserError.externalUserAgentCancelled, BrowserError.externalUserAgentCancelled)
    }
    
    func testBrowserErrorIsError() {
        let error: Error = BrowserError.externalUserAgentFailure
        XCTAssertNotNil(error)
    }
}

// MARK: - BrowserMode Tests

@MainActor
final class BrowserModeTests: XCTestCase {
    
    func testBrowserModeValues() {
        let loginMode: BrowserMode = .login
        let logoutMode: BrowserMode = .logout
        let customMode: BrowserMode = .custom
        
        XCTAssertNotNil(loginMode)
        XCTAssertNotNil(logoutMode)
        XCTAssertNotNil(customMode)
    }
}

// MARK: - OpenURLMonitor Tests

@MainActor
final class OpenURLMonitorTests: XCTestCase {
    
    func testOpenURLMonitorSharedInstance() {
        let monitor1 = OpenURLMonitor.shared
        let monitor2 = OpenURLMonitor.shared
        XCTAssertTrue(monitor1 === monitor2)
    }
    
    func testOpenURLMonitorHandleURLReturnsTrue() {
        let url = URL(string: "myapp://callback?code=123")!
        let result = OpenURLMonitor.shared.handleOpenURL(url)
        XCTAssertTrue(result)
    }
}

// MARK: - BrowserLauncher Tests

@MainActor
final class BrowserLauncherTests: XCTestCase {
    
    func testBrowserLauncherCurrentBrowserExists() {
        let browser = BrowserLauncher.currentBrowser
        XCTAssertNotNil(browser)
    }
    
    func testBrowserLauncherIsNotInProgressInitially() {
        let browser = BrowserLauncher()
        XCTAssertFalse(browser.isInProgress)
    }
    
    func testBrowserLauncherResetWhenIdle() {
        let browser = BrowserLauncher()
        // Should not crash when reset is called in idle state
        browser.reset()
        XCTAssertFalse(browser.isInProgress)
    }
    
    func testBrowserLauncherHandleAppActivationWhenIdle() {
        let browser = BrowserLauncher()
        // Should not crash when called in idle state
        browser.handleAppActivation()
        XCTAssertFalse(browser.isInProgress)
    }
}

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
            NetworkConstants._links: [
                NetworkConstants.continue: [
                    NetworkConstants.href: continueURL
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
        XCTAssertEqual(request.url, continueURL)
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerAuthorization), "Bearer \(continueToken)")
        XCTAssertEqual(request.getMethod(), HttpMethod.post)
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

class FlowContextMock: FlowContext, @unchecked Sendable {}

final class NodeMock: Node {}

class TestContinueNode: ContinueNode, @unchecked Sendable {
    override func asRequest() -> Request {
        let request = RequestMock()
        request.url = "https://openam.example.com"
        return request
    }
}

class RequestMock: URLSessionHttpRequest, @unchecked Sendable {}

/// A mock BrowserLauncher that you can control in tests.
class MockBrowserLauncher: BrowserLauncherProtocol {
    func handleAppActivation() {
        // No-op for mock
    }
    
    func reset() {
        self.isInProgress = false
    }
    
    var isInProgress: Bool = false
    
    /// A closure that will be called when `launch` is invoked.
    var launchHandler: ((URL, BrowserType, String) async throws -> URL)?
    
    func launch(url: URL, customParams: [String : String]?, browserType: PingBrowser.BrowserType, browserMode: PingBrowser.BrowserMode, callbackURLScheme: String) async throws -> URL {
        if let handler = launchHandler {
            return try await handler(url, browserType, callbackURLScheme)
        }
        throw NSError(domain: "MockBrowserLauncher", code: 0, userInfo: nil)
    }
}
