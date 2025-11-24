//
//  DeviceTests.swift
//  DeviceClientTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDeviceClient

/// Tests for Device models
final class DeviceTests: XCTestCase {
    
    // MARK: - OathDevice Tests
    
    func testOathDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "My Authenticator",
            "uuid": "uuid-456",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(OathDevice.self, from: data)
        
        XCTAssertEqual(device.id, "oath-123")
        XCTAssertEqual(device.deviceName, "My Authenticator")
        XCTAssertEqual(device.uuid, "uuid-456")
        XCTAssertEqual(device.createdDate, 1704067200000.0)
        XCTAssertEqual(device.lastAccessDate, 1704153600000.0)
        XCTAssertEqual(device.urlSuffix, "devices/2fa/oath")
    }
    
    func testOathDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "Test Device",
            "uuid": "uuid-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(OathDevice.self, from: data)
        
        let encodedData = try JSONEncoder().encode(device)
        let decodedDevice = try JSONDecoder().decode(OathDevice.self, from: encodedData)
        
        XCTAssertEqual(device.id, decodedDevice.id)
        XCTAssertEqual(device.deviceName, decodedDevice.deviceName)
        XCTAssertEqual(device.uuid, decodedDevice.uuid)
    }
    
    func testOathDeviceConformsToDevice() {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "Test",
            "uuid": "uuid",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        let device = try! JSONDecoder().decode(OathDevice.self, from: data)
        
        // Test Device protocol conformance
        let deviceProtocol: Device = device
        XCTAssertEqual(deviceProtocol.id, "oath-123")
        XCTAssertEqual(deviceProtocol.deviceName, "Test")
        XCTAssertEqual(deviceProtocol.urlSuffix, "devices/2fa/oath")
    }
    
    // MARK: - PushDevice Tests
    
    func testPushDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "push-789",
            "deviceName": "iPhone 15 Pro",
            "uuid": "uuid-push-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(PushDevice.self, from: data)
        
        XCTAssertEqual(device.id, "push-789")
        XCTAssertEqual(device.deviceName, "iPhone 15 Pro")
        XCTAssertEqual(device.uuid, "uuid-push-123")
        XCTAssertEqual(device.urlSuffix, "devices/2fa/push")
    }
    
    func testPushDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "push-123",
            "deviceName": "Test Push",
            "uuid": "uuid-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(PushDevice.self, from: data)
        
        let encodedData = try JSONEncoder().encode(device)
        let decodedDevice = try JSONDecoder().decode(PushDevice.self, from: encodedData)
        
        XCTAssertEqual(device.id, decodedDevice.id)
        XCTAssertEqual(device.deviceName, decodedDevice.deviceName)
    }
    
    // MARK: - BoundDevice Tests
    
    func testBoundDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "bound-456",
            "deviceId": "device-id-789",
            "deviceName": "My Phone",
            "uuid": "uuid-bound-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(BoundDevice.self, from: data)
        
        XCTAssertEqual(device.id, "bound-456")
        XCTAssertEqual(device.deviceId, "device-id-789")
        XCTAssertEqual(device.deviceName, "My Phone")
        XCTAssertEqual(device.uuid, "uuid-bound-123")
        XCTAssertEqual(device.urlSuffix, "devices/2fa/binding")
    }
    
    func testBoundDeviceMutability() throws {
        let json: [String: Any] = [
            "_id": "bound-123",
            "deviceId": "device-id-123",
            "deviceName": "Original Name",
            "uuid": "uuid-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(BoundDevice.self, from: data)
        
        XCTAssertEqual(device.deviceName, "Original Name")
        
        device.deviceName = "Updated Name"
        XCTAssertEqual(device.deviceName, "Updated Name")
    }
    
    func testBoundDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "bound-123",
            "deviceId": "device-id-123",
            "deviceName": "Test Bound",
            "uuid": "uuid-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(BoundDevice.self, from: data)
        
        let encodedData = try JSONEncoder().encode(device)
        let decodedDevice = try JSONDecoder().decode(BoundDevice.self, from: encodedData)
        
        XCTAssertEqual(device.deviceId, decodedDevice.deviceId)
    }
    
    // MARK: - ProfileDevice Tests
    
    func testProfileDeviceDecodingWithLocation() throws {
        let json: [String: Any] = [
            "_id": "profile-123",
            "alias": "My Device Profile",
            "identifier": "identifier-abc",
            "lastSelectedDate": 1704067200000.0,
            "metadata": [
                "platform": "iOS",
                "version": "17.2",
                "model": "iPhone 15"
            ],
            "location": [
                "latitude": 37.7749,
                "longitude": -122.4194
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertEqual(device.id, "profile-123")
        XCTAssertEqual(device.deviceName, "My Device Profile")
        XCTAssertEqual(device.identifier, "identifier-abc")
        XCTAssertEqual(device.lastSelectedDate, 1704067200000.0)
        XCTAssertEqual(device.urlSuffix, "devices/profile")
        
        // Test metadata
        XCTAssertEqual(device.metadata["platform"] as? String, "iOS")
        XCTAssertEqual(device.metadata["version"] as? String, "17.2")
        
        // Test location
        XCTAssertNotNil(device.location)
        XCTAssertEqual(device.location?.latitude, 37.7749)
        XCTAssertEqual(device.location?.longitude, -122.4194)
    }
    
    func testProfileDeviceDecodingWithoutLocation() throws {
        let json: [String: Any] = [
            "_id": "profile-456",
            "alias": "No Location Device",
            "identifier": "identifier-xyz",
            "lastSelectedDate": 1704067200000.0,
            "metadata": ["key": "value"]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertNil(device.location)
    }
    
    func testProfileDeviceMetadataTypes() throws {
        let json: [String: Any] = [
            "_id": "profile-789",
            "alias": "Complex Metadata",
            "identifier": "identifier-complex",
            "lastSelectedDate": 1704067200000.0,
            "metadata": [
                "string": "value",
                "number": 42,
                "double": 3.14,
                "bool": true,
                "array": [1, 2, 3],
                "nested": ["key": "value"]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertEqual(device.metadata["string"] as? String, "value")
        XCTAssertEqual(device.metadata["number"] as? Int, 42)
        XCTAssertEqual(device.metadata["double"] as? Double, 3.14)
        XCTAssertEqual(device.metadata["bool"] as? Bool, true)
        XCTAssertNotNil(device.metadata["array"])
        XCTAssertNotNil(device.metadata["nested"])
    }
    
    func testProfileDeviceMutability() throws {
        let json: [String: Any] = [
            "_id": "profile-123",
            "alias": "Original",
            "identifier": "id",
            "lastSelectedDate": 1704067200000.0,
            "metadata": [:]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        device.deviceName = "Updated"
        XCTAssertEqual(device.deviceName, "Updated")
    }
    
    func testProfileDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "profile-123",
            "alias": "Test Profile",
            "identifier": "test-id",
            "lastSelectedDate": 1704067200000.0,
            "metadata": ["key": "value"],
            "location": [
                "latitude": 40.7128,
                "longitude": -74.0060
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        let encodedData = try JSONEncoder().encode(device)
        let decodedDevice = try JSONDecoder().decode(ProfileDevice.self, from: encodedData)
        
        XCTAssertEqual(device.id, decodedDevice.id)
        XCTAssertEqual(device.identifier, decodedDevice.identifier)
        XCTAssertEqual(device.location?.latitude, decodedDevice.location?.latitude)
    }
    
    // MARK: - WebAuthnDevice Tests
    
    func testWebAuthnDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "webauthn-123",
            "credentialId": "credential-abc-123",
            "deviceName": "YubiKey 5C",
            "uuid": "uuid-webauthn-456",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(WebAuthnDevice.self, from: data)
        
        XCTAssertEqual(device.id, "webauthn-123")
        XCTAssertEqual(device.credentialId, "credential-abc-123")
        XCTAssertEqual(device.deviceName, "YubiKey 5C")
        XCTAssertEqual(device.uuid, "uuid-webauthn-456")
        XCTAssertEqual(device.urlSuffix, "devices/2fa/webauthn")
    }
    
    func testWebAuthnDeviceMutability() throws {
        let json: [String: Any] = [
            "_id": "webauthn-123",
            "credentialId": "cred-123",
            "deviceName": "Original",
            "uuid": "uuid-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(WebAuthnDevice.self, from: data)
        
        device.deviceName = "Updated Security Key"
        XCTAssertEqual(device.deviceName, "Updated Security Key")
    }
    
    func testWebAuthnDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "webauthn-123",
            "credentialId": "cred-123",
            "deviceName": "Test WebAuthn",
            "uuid": "uuid-123",
            "createdDate": 1704067200000.0,
            "lastAccessDate": 1704153600000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(WebAuthnDevice.self, from: data)
        
        let encodedData = try JSONEncoder().encode(device)
        let decodedDevice = try JSONDecoder().decode(WebAuthnDevice.self, from: encodedData)
        
        XCTAssertEqual(device.credentialId, decodedDevice.credentialId)
        XCTAssertEqual(device.deviceName, decodedDevice.deviceName)
    }
    
    // MARK: - Location Tests
    
    func testLocationDecoding() throws {
        let json: [String: Any] = [
            "latitude": 51.5074,
            "longitude": -0.1278
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let location = try JSONDecoder().decode(Location.self, from: data)
        
        XCTAssertEqual(location.latitude, 51.5074)
        XCTAssertEqual(location.longitude, -0.1278)
    }
    
    func testLocationEncoding() throws {
        let location = Location(latitude: 35.6762, longitude: 139.6503)
        
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(Location.self, from: data)
        
        XCTAssertEqual(location.latitude, decoded.latitude)
        XCTAssertEqual(location.longitude, decoded.longitude)
    }
    
    func testLocationSendable() {
        // Test that Location conforms to Sendable
        let location = Location(latitude: 1.0, longitude: 2.0)
        
        Task {
            _ = location
        }
    }
    
    // MARK: - Device Protocol Tests
    
    func testAllDevicesConformToDevice() {
        // Test that all device types conform to Device protocol
        let oathJson: [String: Any] = [
            "_id": "oath", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let oath = try! JSONDecoder().decode(OathDevice.self, from: JSONSerialization.data(withJSONObject: oathJson))
        let _: Device = oath
        
        let pushJson: [String: Any] = [
            "_id": "push", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let push = try! JSONDecoder().decode(PushDevice.self, from: JSONSerialization.data(withJSONObject: pushJson))
        let _: Device = push
        
        let boundJson: [String: Any] = [
            "_id": "bound", "deviceId": "id", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let bound = try! JSONDecoder().decode(BoundDevice.self, from: JSONSerialization.data(withJSONObject: boundJson))
        let _: Device = bound
        
        let profileJson: [String: Any] = [
            "_id": "profile", "alias": "Test", "identifier": "id",
            "lastSelectedDate": 0.0, "metadata": [:]
        ]
        let profile = try! JSONDecoder().decode(ProfileDevice.self, from: JSONSerialization.data(withJSONObject: profileJson))
        let _: Device = profile
        
        let webauthnJson: [String: Any] = [
            "_id": "webauthn", "credentialId": "cred", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let webauthn = try! JSONDecoder().decode(WebAuthnDevice.self, from: JSONSerialization.data(withJSONObject: webauthnJson))
        let _: Device = webauthn
    }
    
    func testDeviceURLSuffixes() {
        let devices: [(any Device, String)] = [
            (createOathDevice(), "devices/2fa/oath"),
            (createPushDevice(), "devices/2fa/push"),
            (createBoundDevice(), "devices/2fa/binding"),
            (createProfileDevice(), "devices/profile"),
            (createWebAuthnDevice(), "devices/2fa/webauthn")
        ]
        
        for (device, expectedSuffix) in devices {
            XCTAssertEqual(device.urlSuffix, expectedSuffix)
        }
    }
    
    // MARK: - Edge Cases
    
    func testDeviceDecodingWithMissingFields() throws {
        let json: [String: Any] = [
            "_id": "test"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        
        XCTAssertThrowsError(try JSONDecoder().decode(OathDevice.self, from: data))
    }
    
    func testDeviceDecodingWithWrongTypes() throws {
        let json: [String: Any] = [
            "_id": 123, // Should be String
            "deviceName": "Test",
            "uuid": "uuid",
            "createdDate": "not a number", // Should be TimeInterval
            "lastAccessDate": 0.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        
        XCTAssertThrowsError(try JSONDecoder().decode(OathDevice.self, from: data))
    }
    
    func testProfileDeviceEmptyMetadata() throws {
        let json: [String: Any] = [
            "_id": "profile-empty",
            "alias": "Empty Metadata",
            "identifier": "id",
            "lastSelectedDate": 1704067200000.0,
            "metadata": [:]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertTrue(device.metadata.isEmpty)
    }
    
    /// MARK: - Helper Methods
    
    private func createOathDevice() -> OathDevice {
        let json: [String: Any] = [
            "_id": "oath", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(OathDevice.self, from: data)
    }
    
    private func createPushDevice() -> PushDevice {
        let json: [String: Any] = [
            "_id": "push", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(PushDevice.self, from: data)
    }
    
    private func createBoundDevice() -> BoundDevice {
        let json: [String: Any] = [
            "_id": "bound", "deviceId": "id", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(BoundDevice.self, from: data)
    }
    
    private func createProfileDevice() -> ProfileDevice {
        let json: [String: Any] = [
            "_id": "profile", "alias": "Test", "identifier": "id",
            "lastSelectedDate": 0.0, "metadata": [:]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(ProfileDevice.self, from: data)
    }
    
    private func createWebAuthnDevice() -> WebAuthnDevice {
        let json: [String: Any] = [
            "_id": "webauthn", "credentialId": "cred", "deviceName": "Test", "uuid": "uuid",
            "createdDate": 0.0, "lastAccessDate": 0.0
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(WebAuthnDevice.self, from: data)
    }
}
