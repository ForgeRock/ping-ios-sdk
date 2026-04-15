//
//  PushErrorTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testNotInitializedError() {
        let error = PushError.notInitialized
        XCTAssertEqual(error.localizedDescription, "Push client has not been initialized")
    }
    
    func testInitializationFailedError() {
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let error = PushError.initializationFailed("Setup failed", underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Initialization failed"))
        XCTAssertTrue(error.localizedDescription.contains("Setup failed"))
    }
    
    func testInvalidUriError() {
        let error = PushError.invalidUri("Malformed scheme")
        XCTAssertTrue(error.localizedDescription.contains("Invalid Push URI"))
        XCTAssertTrue(error.localizedDescription.contains("Malformed scheme"))
    }
    
    func testMissingRequiredParameterError() {
        let error = PushError.missingRequiredParameter("sharedSecret")
        XCTAssertTrue(error.localizedDescription.contains("Missing required parameter"))
        XCTAssertTrue(error.localizedDescription.contains("sharedSecret"))
    }
    
    func testInvalidParameterValueError() {
        let error = PushError.invalidParameterValue("TTL must be positive")
        XCTAssertTrue(error.localizedDescription.contains("Invalid parameter value"))
        XCTAssertTrue(error.localizedDescription.contains("TTL must be positive"))
    }
    
    func testUriFormattingError() {
        let error = PushError.uriFormatting("Failed to encode URI")
        XCTAssertTrue(error.localizedDescription.contains("URI formatting failed"))
        XCTAssertTrue(error.localizedDescription.contains("Failed to encode URI"))
    }
    
    func testInvalidPushTypeError() {
        let error = PushError.invalidPushType("unknown")
        XCTAssertTrue(error.localizedDescription.contains("Invalid push type"))
        XCTAssertTrue(error.localizedDescription.contains("unknown"))
    }
    
    func testInvalidPlatformError() {
        let error = PushError.invalidPlatform("custom")
        XCTAssertTrue(error.localizedDescription.contains("Invalid platform"))
        XCTAssertTrue(error.localizedDescription.contains("custom"))
    }
    
    func testStorageFailureError() {
        let underlyingError = NSError(domain: "KeychainDomain", code: -34018, userInfo: nil)
        let error = PushError.storageFailure("Keychain access denied", underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Storage failure"))
        XCTAssertTrue(error.localizedDescription.contains("Keychain access denied"))
    }
    
    func testDeviceTokenNotSetError() {
        let error = PushError.deviceTokenNotSet
        XCTAssertEqual(error.localizedDescription, "Device token has not been set")
    }
    
    func testNoHandlerForPlatformError() {
        let error = PushError.noHandlerForPlatform("custom_platform")
        XCTAssertTrue(error.localizedDescription.contains("No handler available for platform"))
        XCTAssertTrue(error.localizedDescription.contains("custom_platform"))
    }
    
    func testMessageParsingFailedError() {
        let error = PushError.messageParsingFailed("Invalid JWT format")
        XCTAssertTrue(error.localizedDescription.contains("Message parsing failed"))
        XCTAssertTrue(error.localizedDescription.contains("Invalid JWT format"))
    }
    
    func testCredentialNotFoundError() {
        let error = PushError.credentialNotFound("cred-123")
        XCTAssertTrue(error.localizedDescription.contains("Credential not found"))
        XCTAssertTrue(error.localizedDescription.contains("cred-123"))
    }
    
    func testCredentialLockedError() {
        let error = PushError.credentialLocked("cred-456")
        XCTAssertTrue(error.localizedDescription.contains("Credential is locked"))
        XCTAssertTrue(error.localizedDescription.contains("cred-456"))
    }
    
    func testNotificationNotFoundError() {
        let error = PushError.notificationNotFound("notif-789")
        XCTAssertTrue(error.localizedDescription.contains("Notification not found"))
        XCTAssertTrue(error.localizedDescription.contains("notif-789"))
    }
    
    func testPolicyViolationError() {
        let error = PushError.policyViolation("Jailbreak detected")
        XCTAssertTrue(error.localizedDescription.contains("Policy violation"))
        XCTAssertTrue(error.localizedDescription.contains("Jailbreak detected"))
    }
    
    func testRegistrationFailedError() {
        let error = PushError.registrationFailed("Server rejected request")
        XCTAssertTrue(error.localizedDescription.contains("Registration failed"))
        XCTAssertTrue(error.localizedDescription.contains("Server rejected request"))
    }
    
    func testNetworkFailureError() {
        let underlyingError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let error = PushError.networkFailure("Request timed out", underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Network failure"))
        XCTAssertTrue(error.localizedDescription.contains("Request timed out"))
    }
    
    // MARK: - Error Without Underlying Error Tests
    
    func testStorageFailureWithoutUnderlyingError() {
        let error = PushError.storageFailure("Failed to write", nil)
        XCTAssertEqual(error.localizedDescription, "Storage failure: Failed to write")
    }
    
    func testNetworkFailureWithoutUnderlyingError() {
        let error = PushError.networkFailure("Connection refused", nil)
        XCTAssertEqual(error.localizedDescription, "Network failure: Connection refused")
    }
    
    func testInitializationFailedWithoutUnderlyingError() {
        let error = PushError.initializationFailed("Invalid configuration", nil)
        XCTAssertEqual(error.localizedDescription, "Initialization failed: Invalid configuration")
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        let error = PushError.credentialNotFound("test-id")
        
        await Task {
            XCTAssertTrue(error.localizedDescription.contains("test-id"))
        }.value
    }
}

// MARK: - PushStorageError Tests

final class PushStorageErrorTests: XCTestCase {
    
    func testStorageFailureError() {
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let error = PushStorageError.storageFailure("Write failed", underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Storage failure"))
        XCTAssertTrue(error.localizedDescription.contains("Write failed"))
    }
    
    func testStorageFailureWithoutUnderlyingError() {
        let error = PushStorageError.storageFailure("Read failed", nil)
        XCTAssertEqual(error.localizedDescription, "Storage failure: Read failed")
    }
    
    func testDuplicateCredentialError() {
        let error = PushStorageError.duplicateCredential("cred-123")
        XCTAssertTrue(error.localizedDescription.contains("Duplicate credential"))
        XCTAssertTrue(error.localizedDescription.contains("cred-123"))
    }
    
    func testDuplicateNotificationError() {
        let error = PushStorageError.duplicateNotification("notif-456")
        XCTAssertTrue(error.localizedDescription.contains("Duplicate notification"))
        XCTAssertTrue(error.localizedDescription.contains("notif-456"))
    }
    
    func testSendable() async {
        let error = PushStorageError.duplicateCredential("test-id")
        
        await Task {
            XCTAssertTrue(error.localizedDescription.contains("test-id"))
        }.value
    }
}
