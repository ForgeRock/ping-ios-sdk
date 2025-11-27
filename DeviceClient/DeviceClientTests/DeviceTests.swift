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

/// Unit tests for Device models
final class DeviceTests: XCTestCase {
    
    // MARK: - OathDevice Tests
    
    func testOathDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "My Authenticator",
            "uuid": "uuid-abc-123",
            "createdDate": 1640000000000.0, // milliseconds
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(OathDevice.self, from: data)
        
        XCTAssertEqual(device.id, "oath-123")
        XCTAssertEqual(device.deviceName, "My Authenticator")
        XCTAssertEqual(device.uuid, "uuid-abc-123")
        XCTAssertEqual(device.createdDate, 1640000000.0) // seconds
        XCTAssertEqual(device.lastAccessDate, 1640000001.0) // seconds
        XCTAssertEqual(device.urlSuffix, "devices/2fa/oath")
    }
    
    func testOathDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "My Authenticator",
            "uuid": "uuid-abc-123",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(OathDevice.self, from: data)
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(OathDevice.self, from: encoded)
        
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.deviceName, device.deviceName)
        XCTAssertEqual(decoded.uuid, device.uuid)
        XCTAssertEqual(decoded.createdDate, device.createdDate)
        XCTAssertEqual(decoded.lastAccessDate, device.lastAccessDate)
    }
    
    func testOathDeviceProtocolConformance() throws {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "Test",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(OathDevice.self, from: data)
        
        // Test Device protocol conformance
        let deviceProtocol: Device = device
        XCTAssertEqual(deviceProtocol.id, "oath-123")
        XCTAssertEqual(deviceProtocol.deviceName, "Test")
        XCTAssertEqual(deviceProtocol.urlSuffix, "devices/2fa/oath")
    }
    
    func testOathDeviceImmutability() throws {
        let json: [String: Any] = [
            "_id": "oath-123",
            "deviceName": "Original",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(OathDevice.self, from: data)
        
        // deviceName is mutable
        device.deviceName = "Modified"
        XCTAssertEqual(device.deviceName, "Modified")
        
        // Other properties are immutable (let)
        // device.id = "new-id" // Would not compile
    }
    
    // MARK: - PushDevice Tests
    
    func testPushDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "push-456",
            "deviceName": "My iPhone",
            "uuid": "push-uuid-456",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(PushDevice.self, from: data)
        
        XCTAssertEqual(device.id, "push-456")
        XCTAssertEqual(device.deviceName, "My iPhone")
        XCTAssertEqual(device.uuid, "push-uuid-456")
        XCTAssertEqual(device.createdDate, 1640000000.0)
        XCTAssertEqual(device.lastAccessDate, 1640000001.0)
        XCTAssertEqual(device.urlSuffix, "devices/2fa/push")
    }
    
    func testPushDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "push-456",
            "deviceName": "My iPhone",
            "uuid": "push-uuid-456",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(PushDevice.self, from: data)
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(PushDevice.self, from: encoded)
        
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.deviceName, device.deviceName)
        XCTAssertEqual(decoded.uuid, device.uuid)
    }
    
    // MARK: - BoundDevice Tests
    
    func testBoundDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "bound-789",
            "deviceName": "Work Phone",
            "deviceId": "device-id-xyz",
            "uuid": "bound-uuid-789",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(BoundDevice.self, from: data)
        
        XCTAssertEqual(device.id, "bound-789")
        XCTAssertEqual(device.deviceName, "Work Phone")
        XCTAssertEqual(device.deviceId, "device-id-xyz")
        XCTAssertEqual(device.uuid, "bound-uuid-789")
        XCTAssertEqual(device.createdDate, 1640000000.0)
        XCTAssertEqual(device.lastAccessDate, 1640000001.0)
        XCTAssertEqual(device.urlSuffix, "devices/2fa/binding")
    }
    
    func testBoundDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "bound-789",
            "deviceName": "Work Phone",
            "deviceId": "device-id-xyz",
            "uuid": "bound-uuid-789",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(BoundDevice.self, from: data)
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(BoundDevice.self, from: encoded)
        
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.deviceName, device.deviceName)
        XCTAssertEqual(decoded.deviceId, device.deviceId)
    }
    
    func testBoundDeviceMutability() throws {
        let json: [String: Any] = [
            "_id": "bound-789",
            "deviceName": "Original Name",
            "deviceId": "device-id-xyz",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(BoundDevice.self, from: data)
        
        // deviceName can be modified
        device.deviceName = "New Name"
        XCTAssertEqual(device.deviceName, "New Name")
    }
    
    // MARK: - ProfileDevice Tests
    
    func testProfileDeviceDecodingWithLocation() throws {
        let json: [String: Any] = [
            "_id": "profile-abc",
            "alias": "My Device",
            "identifier": "identifier-123",
            "metadata": [
                "platform": "iOS",
                "version": "17.0",
                "model": "iPhone15,2"
            ],
            "location": [
                "latitude": 37.7749,
                "longitude": -122.4194
            ],
            "lastSelectedDate": 1640000000000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertEqual(device.id, "profile-abc")
        XCTAssertEqual(device.deviceName, "My Device")
        XCTAssertEqual(device.identifier, "identifier-123")
        XCTAssertEqual(device.metadata["platform"] as? String, "iOS")
        XCTAssertEqual(device.metadata["version"] as? String, "17.0")
        XCTAssertNotNil(device.location)
        XCTAssertEqual(device.location?.latitude, 37.7749)
        XCTAssertEqual(device.location?.longitude, -122.4194)
        XCTAssertEqual(device.lastSelectedDate, 1640000000.0)
        XCTAssertEqual(device.urlSuffix, "devices/profile")
    }
    
    func testProfileDeviceDecodingWithoutLocation() throws {
        let json: [String: Any] = [
            "_id": "profile-def",
            "alias": "Desktop",
            "identifier": "identifier-456",
            "metadata": ["os": "macOS"],
            "lastSelectedDate": 1640000000000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertEqual(device.id, "profile-def")
        XCTAssertEqual(device.deviceName, "Desktop")
        XCTAssertNil(device.location)
    }
    
    func testProfileDeviceMutability() throws {
        let json: [String: Any] = [
            "_id": "profile-abc",
            "alias": "Original",
            "identifier": "id",
            "metadata": [:],
            "lastSelectedDate": 1000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        // deviceName (alias) can be modified
        device.deviceName = "Modified"
        XCTAssertEqual(device.deviceName, "Modified")
    }
    
    func testProfileDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "profile-abc",
            "alias": "My Device",
            "identifier": "id-123",
            "metadata": ["platform": "iOS"],
            "lastSelectedDate": 1640000000000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(ProfileDevice.self, from: encoded)
        
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.deviceName, device.deviceName)
        XCTAssertEqual(decoded.identifier, device.identifier)
    }
    
    func testProfileDeviceEncodingWithLocation() throws {
        let json: [String: Any] = [
            "_id": "profile-abc",
            "alias": "My Device",
            "identifier": "id-123",
            "metadata": ["platform": "iOS"],
            "location": [
                "latitude": 37.7749,
                "longitude": -122.4194
            ],
            "lastSelectedDate": 1640000000000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(ProfileDevice.self, from: encoded)
        
        XCTAssertNotNil(decoded.location)
        XCTAssertEqual(decoded.location?.latitude, device.location?.latitude)
        XCTAssertEqual(decoded.location?.longitude, device.location?.longitude)
    }
    
    // MARK: - WebAuthnDevice Tests
    
    func testWebAuthnDeviceDecoding() throws {
        let json: [String: Any] = [
            "_id": "webauthn-xyz",
            "deviceName": "YubiKey",
            "credentialId": "credential-abc-123",
            "uuid": "webauthn-uuid-xyz",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(WebAuthnDevice.self, from: data)
        
        XCTAssertEqual(device.id, "webauthn-xyz")
        XCTAssertEqual(device.deviceName, "YubiKey")
        XCTAssertEqual(device.credentialId, "credential-abc-123")
        XCTAssertEqual(device.uuid, "webauthn-uuid-xyz")
        XCTAssertEqual(device.createdDate, 1640000000.0)
        XCTAssertEqual(device.lastAccessDate, 1640000001.0)
        XCTAssertEqual(device.urlSuffix, "devices/2fa/webauthn")
    }
    
    func testWebAuthnDeviceMutability() throws {
        let json: [String: Any] = [
            "_id": "webauthn-xyz",
            "deviceName": "Original",
            "credentialId": "cred-id",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        var device = try JSONDecoder().decode(WebAuthnDevice.self, from: data)
        
        // deviceName can be modified
        device.deviceName = "Updated YubiKey"
        XCTAssertEqual(device.deviceName, "Updated YubiKey")
    }
    
    func testWebAuthnDeviceEncoding() throws {
        let json: [String: Any] = [
            "_id": "webauthn-xyz",
            "deviceName": "YubiKey",
            "credentialId": "credential-abc-123",
            "uuid": "webauthn-uuid-xyz",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(WebAuthnDevice.self, from: data)
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(WebAuthnDevice.self, from: encoded)
        
        XCTAssertEqual(decoded.id, device.id)
        XCTAssertEqual(decoded.deviceName, device.deviceName)
        XCTAssertEqual(decoded.credentialId, device.credentialId)
    }
    
    // MARK: - Location Tests
    
    func testLocationDecoding() throws {
        let json: [String: Any] = [
            "latitude": 37.7749,
            "longitude": -122.4194
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let location = try JSONDecoder().decode(Location.self, from: data)
        
        XCTAssertEqual(location.latitude, 37.7749)
        XCTAssertEqual(location.longitude, -122.4194)
    }
    
    func testLocationEncoding() throws {
        let json: [String: Any] = [
            "latitude": 37.7749,
            "longitude": -122.4194
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let location = try JSONDecoder().decode(Location.self, from: data)
        
        let encoded = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(Location.self, from: encoded)
        
        XCTAssertEqual(decoded.latitude, location.latitude)
        XCTAssertEqual(decoded.longitude, location.longitude)
    }
    
    func testLocationSendableConformance() {
        let location = Location(latitude: 37.7749, longitude: -122.4194)
        
        // Test that Location conforms to Sendable by using it in an async context
        Task {
            let _ = location.latitude
            let _ = location.longitude
        }
    }
    
    // MARK: - Protocol Tests
    
    func testAllDevicesConformToDeviceProtocol() throws {
        // Create one of each device type
        let oathJSON: [String: Any] = [
            "_id": "oath-1",
            "deviceName": "Oath",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        let oath = try JSONDecoder().decode(OathDevice.self, from: JSONSerialization.data(withJSONObject: oathJSON))
        
        let pushJSON: [String: Any] = [
            "_id": "push-1",
            "deviceName": "Push",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        let push = try JSONDecoder().decode(PushDevice.self, from: JSONSerialization.data(withJSONObject: pushJSON))
        
        let boundJSON: [String: Any] = [
            "_id": "bound-1",
            "deviceName": "Bound",
            "deviceId": "id",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        let bound = try JSONDecoder().decode(BoundDevice.self, from: JSONSerialization.data(withJSONObject: boundJSON))
        
        let profileJSON: [String: Any] = [
            "_id": "profile-1",
            "alias": "Profile",
            "identifier": "id",
            "metadata": [:],
            "lastSelectedDate": 1000.0
        ]
        let profile = try JSONDecoder().decode(ProfileDevice.self, from: JSONSerialization.data(withJSONObject: profileJSON))
        
        let webauthnJSON: [String: Any] = [
            "_id": "webauthn-1",
            "deviceName": "WebAuthn",
            "credentialId": "cred",
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        let webauthn = try JSONDecoder().decode(WebAuthnDevice.self, from: JSONSerialization.data(withJSONObject: webauthnJSON))
        
        // Test protocol conformance
        let devices: [Device] = [oath, push, bound, profile, webauthn]
        
        XCTAssertEqual(devices[0].urlSuffix, "devices/2fa/oath")
        XCTAssertEqual(devices[1].urlSuffix, "devices/2fa/push")
        XCTAssertEqual(devices[2].urlSuffix, "devices/2fa/binding")
        XCTAssertEqual(devices[3].urlSuffix, "devices/profile")
        XCTAssertEqual(devices[4].urlSuffix, "devices/2fa/webauthn")
    }
    
    func testDeviceURLSuffixes() throws {
        let oathJSON: [String: Any] = ["_id": "1", "deviceName": "Oath", "uuid": "u", "createdDate": 1000.0, "lastAccessDate": 2000.0]
        let oath = try JSONDecoder().decode(OathDevice.self, from: JSONSerialization.data(withJSONObject: oathJSON))
        XCTAssertEqual(oath.urlSuffix, "devices/2fa/oath")
        
        let pushJSON: [String: Any] = ["_id": "1", "deviceName": "Push", "uuid": "u", "createdDate": 1000.0, "lastAccessDate": 2000.0]
        let push = try JSONDecoder().decode(PushDevice.self, from: JSONSerialization.data(withJSONObject: pushJSON))
        XCTAssertEqual(push.urlSuffix, "devices/2fa/push")
        
        let boundJSON: [String: Any] = ["_id": "1", "deviceName": "Bound", "deviceId": "d", "uuid": "u", "createdDate": 1000.0, "lastAccessDate": 2000.0]
        let bound = try JSONDecoder().decode(BoundDevice.self, from: JSONSerialization.data(withJSONObject: boundJSON))
        XCTAssertEqual(bound.urlSuffix, "devices/2fa/binding")
        
        let profileJSON: [String: Any] = ["_id": "1", "alias": "Profile", "identifier": "i", "metadata": [:], "lastSelectedDate": 1000.0]
        let profile = try JSONDecoder().decode(ProfileDevice.self, from: JSONSerialization.data(withJSONObject: profileJSON))
        XCTAssertEqual(profile.urlSuffix, "devices/profile")
        
        let webauthnJSON: [String: Any] = ["_id": "1", "deviceName": "WebAuthn", "credentialId": "c", "uuid": "u", "createdDate": 1000.0, "lastAccessDate": 2000.0]
        let webauthn = try JSONDecoder().decode(WebAuthnDevice.self, from: JSONSerialization.data(withJSONObject: webauthnJSON))
        XCTAssertEqual(webauthn.urlSuffix, "devices/2fa/webauthn")
    }
    
    // MARK: - Edge Cases
    
    func testDeviceDecodingWithMissingOptionalFields() throws {
        // ProfileDevice with missing location should decode successfully
        let json: [String: Any] = [
            "_id": "profile-1",
            "alias": "Device",
            "identifier": "id",
            "metadata": [:],
            "lastSelectedDate": 1000.0
            // location is missing but optional
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertNil(device.location)
    }
    
    func testDeviceDecodingWithWrongTypesShouldFail() {
        let json: [String: Any] = [
            "_id": "oath-1",
            "deviceName": 12345, // Wrong type: should be String
            "uuid": "uuid",
            "createdDate": 1000.0,
            "lastAccessDate": 2000.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        
        XCTAssertThrowsError(try JSONDecoder().decode(OathDevice.self, from: data))
    }
    
    func testProfileDeviceWithEmptyMetadata() throws {
        let json: [String: Any] = [
            "_id": "profile-1",
            "alias": "Device",
            "identifier": "id",
            "metadata": [:], // Empty metadata
            "lastSelectedDate": 1000.0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let device = try JSONDecoder().decode(ProfileDevice.self, from: data)
        
        XCTAssertTrue(device.metadata.isEmpty)
    }
    
    // MARK: - Sendable Tests
    
    func testDevicesAreSendable() {
        // Test that all devices can be used in async contexts
        Task {
            let oathJSON: [String: Any] = ["_id": "1", "deviceName": "Oath", "uuid": "u", "createdDate": 1000.0, "lastAccessDate": 2000.0]
            let oath = try! JSONDecoder().decode(OathDevice.self, from: JSONSerialization.data(withJSONObject: oathJSON))
            
            let _ = oath.deviceName // Access in async context
        }
    }
}
