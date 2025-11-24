//
//  DeviceErrorTests.swift
//  DeviceClientTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDeviceClient

/// Tests for DeviceError
final class DeviceErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testNetworkErrorDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
        ])
        let error = DeviceError.networkError(error: underlyingError)
        
        XCTAssertEqual(
            error.errorDescription,
            "Network error: The Internet connection appears to be offline."
        )
    }
    
    func testRequestFailedErrorDescription() {
        let error = DeviceError.requestFailed(statusCode: 404, message: "Not Found")
        
        XCTAssertEqual(
            error.errorDescription,
            "Request failed with status 404: Not Found"
        )
    }
    
    func testInvalidUrlErrorDescription() {
        let error = DeviceError.invalidUrl(url: "invalid://url")
        
        XCTAssertEqual(
            error.errorDescription,
            "Invalid URL: invalid://url"
        )
    }
    
    func testDecodingFailedErrorDescription() {
        let underlyingError = NSError(domain: "DecodingError", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Key not found"
        ])
        let error = DeviceError.decodingFailed(error: underlyingError)
        
        XCTAssertEqual(
            error.errorDescription,
            "Failed to decode response: Key not found"
        )
    }
    
    func testEncodingFailedErrorDescription() {
        let error = DeviceError.encodingFailed(message: "Invalid data format")
        
        XCTAssertEqual(
            error.errorDescription,
            "Failed to encode request: Invalid data format"
        )
    }
    
    func testInvalidResponseErrorDescription() {
        let error = DeviceError.invalidResponse(message: "Missing required field")
        
        XCTAssertEqual(
            error.errorDescription,
            "Invalid response: Missing required field"
        )
    }
    
    func testInvalidTokenErrorDescription() {
        let error = DeviceError.invalidToken(message: "Token expired")
        
        XCTAssertEqual(
            error.errorDescription,
            "Invalid token: Token expired"
        )
    }
    
    func testMissingConfigurationErrorDescription() {
        let error = DeviceError.missingConfiguration(message: "Server URL required")
        
        XCTAssertEqual(
            error.errorDescription,
            "Missing configuration: Server URL required"
        )
    }
    
    // MARK: - Failure Reason Tests
    
    func testNetworkErrorFailureReason() {
        let error = DeviceError.networkError(error: NSError(domain: "", code: 0))
        
        XCTAssertEqual(
            error.failureReason,
            "The network request could not be completed."
        )
    }
    
    func testRequestFailedFailureReason() {
        let error = DeviceError.requestFailed(statusCode: 500, message: "Internal Server Error")
        
        XCTAssertEqual(
            error.failureReason,
            "The server returned an error response."
        )
    }
    
    func testInvalidUrlFailureReason() {
        let error = DeviceError.invalidUrl(url: "bad-url")
        
        XCTAssertEqual(
            error.failureReason,
            "The URL is malformed or invalid."
        )
    }
    
    func testDecodingFailedFailureReason() {
        let error = DeviceError.decodingFailed(error: NSError(domain: "", code: 0))
        
        XCTAssertEqual(
            error.failureReason,
            "The response data could not be decoded."
        )
    }
    
    func testEncodingFailedFailureReason() {
        let error = DeviceError.encodingFailed(message: "Test")
        
        XCTAssertEqual(
            error.failureReason,
            "The request data could not be encoded."
        )
    }
    
    func testInvalidResponseFailureReason() {
        let error = DeviceError.invalidResponse(message: "Test")
        
        XCTAssertEqual(
            error.failureReason,
            "The server response format is invalid."
        )
    }
    
    func testInvalidTokenFailureReason() {
        let error = DeviceError.invalidToken(message: "Test")
        
        XCTAssertEqual(
            error.failureReason,
            "The authentication token is missing or invalid."
        )
    }
    
    func testMissingConfigurationFailureReason() {
        let error = DeviceError.missingConfiguration(message: "Test")
        
        XCTAssertEqual(
            error.failureReason,
            "Required configuration is missing."
        )
    }
    
    // MARK: - Recovery Suggestion Tests
    
    func testNetworkErrorRecoverySuggestion() {
        let error = DeviceError.networkError(error: NSError(domain: "", code: 0))
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please check your network connection and try again."
        )
    }
    
    func testRequestFailed401RecoverySuggestion() {
        let error = DeviceError.requestFailed(statusCode: 401, message: "Unauthorized")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please authenticate again."
        )
    }
    
    func testRequestFailed404RecoverySuggestion() {
        let error = DeviceError.requestFailed(statusCode: 404, message: "Not Found")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "The requested resource was not found."
        )
    }
    
    func testRequestFailed500RecoverySuggestion() {
        let error = DeviceError.requestFailed(statusCode: 500, message: "Internal Server Error")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "The server encountered an error. Please try again later."
        )
    }
    
    func testRequestFailed503RecoverySuggestion() {
        let error = DeviceError.requestFailed(statusCode: 503, message: "Service Unavailable")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "The server encountered an error. Please try again later."
        )
    }
    
    func testRequestFailedOtherRecoverySuggestion() {
        let error = DeviceError.requestFailed(statusCode: 400, message: "Bad Request")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please try again or contact support."
        )
    }
    
    func testInvalidUrlRecoverySuggestion() {
        let error = DeviceError.invalidUrl(url: "test")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please verify the server configuration."
        )
    }
    
    func testDecodingFailedRecoverySuggestion() {
        let error = DeviceError.decodingFailed(error: NSError(domain: "", code: 0))
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "The response format may have changed. Please update the SDK."
        )
    }
    
    func testEncodingFailedRecoverySuggestion() {
        let error = DeviceError.encodingFailed(message: "Test")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please verify the device data is valid."
        )
    }
    
    func testInvalidResponseRecoverySuggestion() {
        let error = DeviceError.invalidResponse(message: "Test")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "The server response format may have changed. Please update the SDK."
        )
    }
    
    func testInvalidTokenRecoverySuggestion() {
        let error = DeviceError.invalidToken(message: "Test")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please authenticate again to obtain a valid token."
        )
    }
    
    func testMissingConfigurationRecoverySuggestion() {
        let error = DeviceError.missingConfiguration(message: "Test")
        
        XCTAssertEqual(
            error.recoverySuggestion,
            "Please provide the required configuration."
        )
    }
    
    // MARK: - LocalizedError Conformance Tests
    
    func testLocalizedErrorConformance() {
        let error: LocalizedError = DeviceError.networkError(error: NSError(domain: "", code: 0))
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testErrorAsNSError() {
        let error = DeviceError.requestFailed(statusCode: 404, message: "Not Found")
        let nsError = error as NSError
        
        XCTAssertNotNil(nsError.localizedDescription)
        XCTAssertNotNil(nsError.localizedFailureReason)
        XCTAssertNotNil(nsError.localizedRecoverySuggestion)
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() {
        // Test that DeviceError can be used in async contexts
        Task {
            let error = DeviceError.networkError(error: NSError(domain: "", code: 0))
            _ = error
        }
    }
    
    func testSendableInAsyncThrow() async throws {
        func asyncFunction() async throws {
            throw DeviceError.invalidToken(message: "Test")
        }
        
        do {
            try await asyncFunction()
            XCTFail("Should have thrown")
        } catch let error as DeviceError {
            if case .invalidToken = error {
                // Success
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - Error Equality Tests
    
    func testErrorCaseComparison() {
        // Test that we can pattern match on error cases
        let error = DeviceError.requestFailed(statusCode: 401, message: "Unauthorized")
        
        switch error {
        case .requestFailed(let statusCode, _):
            XCTAssertEqual(statusCode, 401)
        default:
            XCTFail("Wrong error case")
        }
    }
    
    func testNetworkErrorCaseMatch() {
        let underlyingError = NSError(domain: "Test", code: 123)
        let error = DeviceError.networkError(error: underlyingError)
        
        if case .networkError = error {
            // Success
        } else {
            XCTFail("Should match networkError case")
        }
    }
    
    func testMultipleErrorCases() {
        let errors: [DeviceError] = [
            .networkError(error: NSError(domain: "", code: 0)),
            .requestFailed(statusCode: 404, message: "Not Found"),
            .invalidUrl(url: "test"),
            .decodingFailed(error: NSError(domain: "", code: 0)),
            .encodingFailed(message: "Test"),
            .invalidResponse(message: "Test"),
            .invalidToken(message: "Test"),
            .missingConfiguration(message: "Test")
        ]
        
        XCTAssertEqual(errors.count, 8)
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.failureReason)
            XCTAssertNotNil(error.recoverySuggestion)
        }
    }
    
    // MARK: - Real-World Scenarios
    
    func testUnauthorizedErrorScenario() {
        let error = DeviceError.requestFailed(statusCode: 401, message: "Invalid token")
        
        XCTAssertTrue(error.errorDescription?.contains("401") ?? false)
        XCTAssertEqual(error.recoverySuggestion, "Please authenticate again.")
    }
    
    func testNetworkOfflineScenario() {
        let underlyingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        let error = DeviceError.networkError(error: underlyingError)
        
        XCTAssertTrue(error.errorDescription?.contains("offline") ?? false)
        XCTAssertTrue(error.recoverySuggestion?.contains("network connection") ?? false)
    }
    
    func testServerErrorScenario() {
        let error = DeviceError.requestFailed(statusCode: 500, message: "Internal Server Error")
        
        XCTAssertTrue(error.errorDescription?.contains("500") ?? false)
        XCTAssertTrue(error.recoverySuggestion?.contains("try again later") ?? false)
    }
    
    func testInvalidConfigurationScenario() {
        let error = DeviceError.missingConfiguration(message: "Server URL is required")
        
        XCTAssertTrue(error.errorDescription?.contains("Server URL") ?? false)
        XCTAssertTrue(error.recoverySuggestion?.contains("configuration") ?? false)
    }
    
    func testDecodingErrorScenario() {
        struct TestError: Error {}
        let error = DeviceError.decodingFailed(error: TestError())
        
        XCTAssertTrue(error.errorDescription?.contains("decode") ?? false)
        XCTAssertTrue(error.recoverySuggestion?.contains("update the SDK") ?? false)
    }
    
    // MARK: - Error Throwing Tests
    
    func testThrowingNetworkError() throws {
        func throwError() throws {
            throw DeviceError.networkError(error: NSError(domain: "", code: 0))
        }
        
        XCTAssertThrowsError(try throwError()) { error in
            XCTAssertTrue(error is DeviceError)
            if let deviceError = error as? DeviceError {
                if case .networkError = deviceError {
                    // Success
                } else {
                    XCTFail("Wrong error case")
                }
            }
        }
    }
    
    func testAsyncThrowingError() async {
        func asyncThrow() async throws {
            throw DeviceError.invalidToken(message: "Expired")
        }
        
        do {
            try await asyncThrow()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is DeviceError)
        }
    }
    
    // MARK: - Error Message Content Tests
    
    func testErrorMessagesAreUserFriendly() {
        let errors: [DeviceError] = [
            .networkError(error: NSError(domain: "", code: 0)),
            .requestFailed(statusCode: 404, message: "Not Found"),
            .invalidUrl(url: "test"),
            .decodingFailed(error: NSError(domain: "", code: 0)),
            .encodingFailed(message: "Test"),
            .invalidResponse(message: "Test"),
            .invalidToken(message: "Test"),
            .missingConfiguration(message: "Test")
        ]
        
        for error in errors {
            // Error descriptions should not be empty
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
            
            // Recovery suggestions should be actionable
            XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true)
            
            // Failure reasons should explain the problem
            XCTAssertFalse(error.failureReason?.isEmpty ?? true)
        }
    }
    
    func testErrorMessagesContainNoTechnicalJargon() {
        let error = DeviceError.requestFailed(statusCode: 404, message: "Not Found")
        
        // User-facing messages should be clear
        let description = error.errorDescription ?? ""
        let suggestion = error.recoverySuggestion ?? ""
        
        XCTAssertFalse(description.isEmpty)
        XCTAssertFalse(suggestion.isEmpty)
        
        // Should mention the status code for debugging
        XCTAssertTrue(description.contains("404"))
    }
}
