//
//  DeviceClientTests.swift
//  DeviceClientTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDeviceClient
@testable import PingOrchestrate

/// Tests for DeviceClient
final class DeviceClientTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockHttpClient: MockHttpClient!
    var deviceClient: DeviceClient!
    var config: DeviceClientConfig!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockHttpClient = MockHttpClient()
        
        config = DeviceClientConfig(
            serverUrl: "https://test.example.com",
            realm: "test-realm",
            cookieName: "TestCookie",
            userId: "test-user",
            ssoToken: "test-token-12345",
            httpClient: mockHttpClient
        )
        
        deviceClient = DeviceClient(config: config)
    }
    
    override func tearDown() {
        mockHttpClient = nil
        deviceClient = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDeviceClientConfigInitialization() {
        // Test all properties are set correctly
        XCTAssertEqual(config.serverUrl, "https://test.example.com")
        XCTAssertEqual(config.realm, "test-realm")
        XCTAssertEqual(config.cookieName, "TestCookie")
        XCTAssertEqual(config.userId, "test-user")
        XCTAssertEqual(config.ssoToken, "test-token-12345")
        XCTAssertTrue(config.httpClient is MockHttpClient)
    }
    
    func testDeviceClientConfigDefaultHttpClient() {
        let configWithDefault = DeviceClientConfig(
            serverUrl: "https://test.example.com",
            realm: "test-realm",
            cookieName: "TestCookie",
            userId: "test-user",
            ssoToken: "test-token"
        )
        
        XCTAssertNotNil(configWithDefault.httpClient)
    }
    
    func testDeviceClientInitialization() {
        XCTAssertNotNil(deviceClient)
    }
    
    // MARK: - Fetch Devices Tests
    
    func testFetchOathDevicesSuccess() async throws {
        // Setup mock response
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "oath-1",
                    "deviceName": "My Authenticator",
                    "uuid": "uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ],
                [
                    "_id": "oath-2",
                    "deviceName": "Work Authenticator",
                    "uuid": "uuid-2",
                    "createdDate": 1640000002000.0,
                    "lastAccessDate": 1640000003000.0
                ]
            ]
        ]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        // Execute
        let devices = try await deviceClient.oath.get()
        
        // Verify
        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].id, "oath-1")
        XCTAssertEqual(devices[0].deviceName, "My Authenticator")
        XCTAssertEqual(devices[1].id, "oath-2")
        XCTAssertEqual(devices[1].deviceName, "Work Authenticator")
        
        // Verify request was made correctly
        XCTAssertTrue(mockHttpClient.lastRequest?.urlString.contains("devices/2fa/oath") ?? false)
        XCTAssertTrue(mockHttpClient.lastRequest?.urlString.contains("_queryFilter=true") ?? false)
    }
    
    func testFetchPushDevicesSuccess() async throws {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "push-1",
                    "deviceName": "iPhone 15",
                    "uuid": "push-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ]
            ]
        ]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        let devices = try await deviceClient.push.get()
        
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].id, "push-1")
        XCTAssertEqual(devices[0].deviceName, "iPhone 15")
    }
    
    func testFetchBoundDevicesSuccess() async throws {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "bound-1",
                    "deviceId": "device-id-1",
                    "deviceName": "My Phone",
                    "uuid": "bound-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ]
            ]
        ]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        let devices = try await deviceClient.bound.get()
        
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].id, "bound-1")
        XCTAssertEqual(devices[0].deviceId, "device-id-1")
    }
    
    func testFetchProfileDevicesSuccess() async throws {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "profile-1",
                    "alias": "My Device",
                    "identifier": "identifier-1",
                    "lastSelectedDate": 1640000000000.0,
                    "metadata": [
                        "platform": "iOS",
                        "version": "17.0"
                    ],
                    "location": [
                        "latitude": 37.7749,
                        "longitude": -122.4194
                    ]
                ]
            ]
        ]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        let devices = try await deviceClient.profile.get()
        
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].id, "profile-1")
        XCTAssertEqual(devices[0].deviceName, "My Device")
        XCTAssertEqual(devices[0].identifier, "identifier-1")
        XCTAssertNotNil(devices[0].location)
        XCTAssertEqual(devices[0].location?.latitude, 37.7749)
    }
    
    func testFetchWebAuthnDevicesSuccess() async throws {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "webauthn-1",
                    "credentialId": "cred-id-1",
                    "deviceName": "YubiKey",
                    "uuid": "webauthn-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ]
            ]
        ]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        let devices = try await deviceClient.webAuthn.get()
        
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].id, "webauthn-1")
        XCTAssertEqual(devices[0].credentialId, "cred-id-1")
    }
    
    func testFetchDevicesEmptyResult() async throws {
        let json: [String: Any] = ["result": []]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        let devices: [OathDevice] = try await deviceClient.oath.get()
        
        XCTAssertEqual(devices.count, 0)
    }
    
    // MARK: - Update Device Tests
    
    func testUpdateBoundDeviceSuccess() async throws {
        var device = createMockBoundDevice()
        device.deviceName = "Updated Name"
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 200, data: Data())
        
        try await deviceClient.bound.update(device)
        
        // Verify request
        XCTAssertEqual(mockHttpClient.lastRequest?.method, .put)
        XCTAssertTrue(mockHttpClient.lastRequest?.urlString.contains("devices/2fa/binding") ?? false)
        XCTAssertTrue(mockHttpClient.lastRequest?.urlString.contains(device.id) ?? false)
    }
    
    func testUpdateProfileDeviceSuccess() async throws {
        var device = createMockProfileDevice()
        device.deviceName = "Updated Profile"
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 200, data: Data())
        
        try await deviceClient.profile.update(device)
        
        XCTAssertEqual(mockHttpClient.lastRequest?.method, .put)
    }
    
    func testUpdateWebAuthnDeviceSuccess() async throws {
        var device = createMockWebAuthnDevice()
        device.deviceName = "Updated WebAuthn"
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 200, data: Data())
        
        try await deviceClient.webAuthn.update(device)
        
        XCTAssertEqual(mockHttpClient.lastRequest?.method, .put)
    }
    
    // MARK: - Delete Device Tests
    
    func testDeleteOathDeviceSuccess() async throws {
        let device = createMockOathDevice()
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 200, data: Data())
        
        try await deviceClient.oath.delete(device)
        
        XCTAssertEqual(mockHttpClient.lastRequest?.method, .delete)
        XCTAssertTrue(mockHttpClient.lastRequest?.urlString.contains(device.id) ?? false)
    }
    
    func testDeleteDeviceSuccess204() async throws {
        let device = createMockPushDevice()
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 204, data: Data())
        
        try await deviceClient.push.delete(device)
        
        // Should not throw - 204 is also acceptable
    }
    
    func testDeleteBoundDeviceSuccess() async throws {
        let device = createMockBoundDevice()
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 200, data: Data())
        
        try await deviceClient.bound.delete(device)
        
        XCTAssertEqual(mockHttpClient.lastRequest?.method, .delete)
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchDevicesInvalidResponse() async throws {
        // Missing 'result' key
        let json: [String: Any] = ["data": []]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        do {
            _ = try await deviceClient.oath.get()
            XCTFail("Should have thrown error")
        } catch let error as DeviceError {
            if case .invalidResponse(let message) = error {
                XCTAssertTrue(message.contains("result"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testFetchDevicesStatusCode401() async throws {
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 401, data: Data())
        
        do {
            _ = try await deviceClient.oath.get()
            XCTFail("Should have thrown error")
        } catch let error as DeviceError {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 401)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testUpdateDeviceStatusCode500() async throws {
        let device = createMockBoundDevice()
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 500, data: Data())
        
        do {
            try await deviceClient.bound.update(device)
            XCTFail("Should have thrown error")
        } catch let error as DeviceError {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testDeleteDeviceStatusCode404() async throws {
        let device = createMockOathDevice()
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 404, data: Data())
        
        do {
            try await deviceClient.oath.delete(device)
            XCTFail("Should have thrown error")
        } catch let error as DeviceError {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testNetworkError() async throws {
        mockHttpClient.shouldThrowError = true
        mockHttpClient.errorToThrow = NSError(domain: "TestError", code: -1, userInfo: nil)
        
        do {
            _ = try await deviceClient.oath.get()
            XCTFail("Should have thrown error")
        } catch let error as DeviceError {
            if case .networkError = error {
                // Success
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testDecodingError() async throws {
        // Invalid JSON for OathDevice
        let json: [String: Any] = [
            "result": [
                ["invalidKey": "invalidValue"]
            ]
        ]
        
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        do {
            _ = try await deviceClient.oath.get()
            XCTFail("Should have thrown error")
        } catch let error as DeviceError {
            if case .decodingFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Request Building Tests
    
    func testRequestContainsAuthHeaders() async throws {
        let json: [String: Any] = ["result": []]
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        _ = try await deviceClient.oath.get()
        
        // Verify headers
        XCTAssertNotNil(mockHttpClient.lastRequest?.headers)
        XCTAssertEqual(mockHttpClient.lastRequest?.headers?["TestCookie"], "test-token-12345")
        XCTAssertEqual(mockHttpClient.lastRequest?.headers?["Accept-API-Version"], "resource=1.0")
    }
    
    func testRequestURLConstruction() async throws {
        let json: [String: Any] = ["result": []]
        mockHttpClient.mockResponse = MockHttpResponse(
            statusCode: 200,
            data: try! JSONSerialization.data(withJSONObject: json)
        )
        
        _ = try await deviceClient.oath.get()
        
        let expectedUrl = "https://test.example.com/json/realms/test-realm/users/test-user/devices/2fa/oath?_queryFilter=true"
        XCTAssertEqual(mockHttpClient.lastRequest?.urlString, expectedUrl)
    }
    
    func testUpdateRequestContainsBody() async throws {
        var device = createMockBoundDevice()
        device.deviceName = "Updated"
        
        mockHttpClient.mockResponse = MockHttpResponse(statusCode: 200, data: Data())
        
        try await deviceClient.bound.update(device)
        
        XCTAssertNotNil(mockHttpClient.lastRequest?.body)
        
        // Verify body contains updated name
        if let body = mockHttpClient.lastRequest?.body as? [String: Any] {
            XCTAssertEqual(body["deviceName"] as? String, "Updated")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockOathDevice() -> OathDevice {
        let json: [String: Any] = [
            "_id": "oath-test-1",
            "deviceName": "Test Oath",
            "uuid": "uuid-oath-1",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(OathDevice.self, from: data)
    }
    
    private func createMockPushDevice() -> PushDevice {
        let json: [String: Any] = [
            "_id": "push-test-1",
            "deviceName": "Test Push",
            "uuid": "uuid-push-1",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(PushDevice.self, from: data)
    }
    
    private func createMockBoundDevice() -> BoundDevice {
        let json: [String: Any] = [
            "_id": "bound-test-1",
            "deviceId": "device-id-test",
            "deviceName": "Test Bound",
            "uuid": "uuid-bound-1",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(BoundDevice.self, from: data)
    }
    
    private func createMockProfileDevice() -> ProfileDevice {
        let json: [String: Any] = [
            "_id": "profile-test-1",
            "alias": "Test Profile",
            "identifier": "identifier-test",
            "lastSelectedDate": 1640000000000.0,
            "metadata": ["key": "value"]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(ProfileDevice.self, from: data)
    }
    
    private func createMockWebAuthnDevice() -> WebAuthnDevice {
        let json: [String: Any] = [
            "_id": "webauthn-test-1",
            "credentialId": "cred-test",
            "deviceName": "Test WebAuthn",
            "uuid": "uuid-webauthn-1",
            "createdDate": 1640000000000.0,
            "lastAccessDate": 1640000001000.0
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(WebAuthnDevice.self, from: data)
    }
}

// MARK: - Mock Classes

class MockHttpClient: HttpClient, @unchecked Sendable {
    var mockResponse: MockHttpResponse?
    var lastRequest: MockRequest?
    var shouldThrowError = false
    var errorToThrow: Error?
    
    override func sendRequest(request: Request) async throws -> (Data, URLResponse) {
        // Capture request for verification
        lastRequest = MockRequest(
            urlString: request.urlRequest.url?.absoluteString ?? "",
            method: MockRequest.HTTPMethod(rawValue: request.urlRequest.httpMethod ?? "") ?? .get,
            headers: request.urlRequest.allHTTPHeaderFields,
            body: request.body
        )
        
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: -1)
        }
        
        guard let response = mockResponse else {
            throw NSError(domain: "MockHttpClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock response set"])
        }
        
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (response.data, urlResponse)
    }
}

struct MockHttpResponse {
    let statusCode: Int
    let data: Data
}

struct MockRequest {
    let urlString: String
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Any?
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

extension Request {
    var body: Any? {
        // Extract body for testing
        guard let bodyData = urlRequest.httpBody else { return nil }
        return try? JSONSerialization.jsonObject(with: bodyData)
    }
    
    var headers: [String: String]? {
        return urlRequest.allHTTPHeaderFields
    }
    
    var method: MockRequest.HTTPMethod {
        return MockRequest.HTTPMethod(rawValue: urlRequest.httpMethod ?? "") ?? .get
    }
}
