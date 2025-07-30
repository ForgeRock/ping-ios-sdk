//
//  DeviceTests.swift
//  DeviceTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingDeviceId

final class DeviceTests: XCTestCase {
    
    func testIdentifierProtocolUse() async {
        let deviceIdentifier = TestDeviceIdentifier()
        
        // When
        let identifier = try? await deviceIdentifier.id
        
        // Then
        XCTAssertNotNil(identifier)
        XCTAssertEqual(identifier?.count, 36) // UUID string length
        
        let identifier2 = try? await deviceIdentifier.id
        
        XCTAssertEqual(identifier, identifier2)
    }
    
    
    func testDefaultDeviceIdentifier() async throws {
        // Initialize the DefaultDeviceIdentifier
        let deviceIdentifier = DefaultDeviceIdentifier()
        
        do {
            // Get the identifier
            let identifier1 = try await deviceIdentifier.id
            
            // Verify the identifier is not empty
            XCTAssertFalse(identifier1.isEmpty, "Device identifier should not be empty")
            
            // Get the identifier again
            let identifier2 = try await deviceIdentifier.id
            
            // Verify both identifiers are the same (persistence check)
            XCTAssertEqual(identifier1, identifier2, "Device identifier should be consistent across multiple calls")
            
            // Verify the identifier format (SHA-256 hash in hex format is 64 characters)
            XCTAssertEqual(identifier2.count, 64, "Device identifier should be a 64-character hex string")
            
            // Test using the protocol interface
            let deviceIdProvider: DeviceIdentifier = deviceIdentifier
            let identifier3 = try await deviceIdProvider.id
            
            // Verify we get the same identifier through the protocol interface
            XCTAssertEqual(identifier1, identifier3, "Device identifier should be consistent when accessed through protocol")
        } catch {
            XCTFail("Failed to get device identifier: \(error)")
        }
    }
}

// MARK: - Test Device Identifier

final class TestDeviceIdentifier: DeviceIdentifier {
    private let identifier = UUID().uuidString
    /// Unique identifier for the device
    public var id: String {
        get async throws {
            return identifier
        }
    }
}
