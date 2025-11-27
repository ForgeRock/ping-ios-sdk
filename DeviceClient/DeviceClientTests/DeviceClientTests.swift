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

/// Unit tests for DeviceClient
final class DeviceClientTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockHttpClient: MockHttpClient!
    var config: DeviceClientConfig!
    var deviceClient: DeviceClient!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockHttpClient = MockHttpClient()
        config = DeviceClientConfig(
            serverUrl: "https://test.example.com",
            realm: "alpha",
            cookieName: "TestCookie",
            ssoToken: "test-token-12345",
            httpClient: mockHttpClient
        )
        deviceClient = DeviceClient(config: config)
    }
    
    override func tearDown() {
        deviceClient = nil
        config = nil
        mockHttpClient = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testDeviceClientConfigInitialization() {
        XCTAssertEqual(config.serverUrl, "https://test.example.com")
        XCTAssertEqual(config.realm, "alpha")
        XCTAssertEqual(config.cookieName, "TestCookie")
        XCTAssertEqual(config.ssoToken, "test-token-12345")
        XCTAssertNotNil(config.httpClient)
    }
    
    func testDeviceClientConfigDefaultValues() {
        let configWithDefaults = DeviceClientConfig(
            serverUrl: "https://test.example.com",
            ssoToken: "test-token"
        )
        
        XCTAssertEqual(configWithDefaults.realm, "root")
        XCTAssertEqual(configWithDefaults.cookieName, "iPlanetDirectoryPro")
    }
    
    func testDeviceClientInitialization() {
        XCTAssertNotNil(deviceClient)
        XCTAssertNotNil(deviceClient.oath)
        XCTAssertNotNil(deviceClient.push)
        XCTAssertNotNil(deviceClient.bound)
        XCTAssertNotNil(deviceClient.profile)
        XCTAssertNotNil(deviceClient.webAuthn)
    }
    
    // MARK: - Session Fetching Tests
    
    func testSessionFetchingSuccess() async {
        // Setup session response
        let sessionJSON: [String: Any] = [
            "username": "demo",
            "universalId": "id=demo,ou=user,dc=openam,dc=forgerock,dc=org",
            "realm": "/alpha",
            "latestAccessTime": "2024-01-01T00:00:00Z",
            "maxIdleExpirationTime": "2024-01-01T01:00:00Z",
            "maxSessionExpirationTime": "2024-01-01T08:00:00Z"
        ]
        let sessionData = try! JSONSerialization.data(withJSONObject: sessionJSON)
        
        mockHttpClient.responses = [
            MockHttpResponse(statusCode: 200, data: sessionData), // Session fetch
            MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()) // Device fetch
        ]
        
        // Execute
        let result = await deviceClient.oath.get()
        
        // Verify session was fetched
        XCTAssertGreaterThanOrEqual(mockHttpClient.requests.count, 2)
        let sessionRequest = mockHttpClient.requests[0]
        XCTAssertTrue(sessionRequest.urlString.contains("/sessions"))
        XCTAssertTrue(sessionRequest.urlString.contains("_action=getSessionInfo"))
        
        // Verify success
        if case .success(let devices) = result {
            XCTAssertGreaterThan(devices.count, 0)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testSessionFetchingCaching() async {
        // Setup session response
        let sessionJSON: [String: Any] = [
            "username": "demo",
            "universalId": "id=demo,ou=user,dc=openam,dc=forgerock,dc=org",
            "realm": "/alpha",
            "latestAccessTime": "2024-01-01T00:00:00Z",
            "maxIdleExpirationTime": "2024-01-01T01:00:00Z",
            "maxSessionExpirationTime": "2024-01-01T08:00:00Z"
        ]
        let sessionData = try! JSONSerialization.data(withJSONObject: sessionJSON)
        
        mockHttpClient.responses = [
            MockHttpResponse(statusCode: 200, data: sessionData), // Session fetch (first call)
            MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()), // Device fetch (first call)
            MockHttpResponse(statusCode: 200, data: createPushDevicesJSON()) // Device fetch (second call, no session fetch)
        ]
        
        // First call - should fetch session
        _ = await deviceClient.oath.get()
        
        // Second call - should NOT fetch session (cached)
        _ = await deviceClient.push.get()
        
        // Verify session was only fetched once
        XCTAssertEqual(mockHttpClient.requests.count, 3)
        let sessionRequests = mockHttpClient.requests.filter { $0.urlString.contains("/sessions") }
        XCTAssertEqual(sessionRequests.count, 1, "Session should only be fetched once due to caching")
    }
    
    func testSessionFetchingFailure() async {
        // Setup session failure
        mockHttpClient.responses = [
            MockHttpResponse(statusCode: 401, data: Data()) // Session fetch fails
        ]
        
        // Execute
        let result = await deviceClient.oath.get()
        
        // Verify failure
        if case .failure(let error) = result {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 401)
            } else {
                XCTFail("Expected requestFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    // MARK: - Fetch Operations Tests
    
    func testFetchOathDevicesSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()))
        
        let result = await deviceClient.oath.get()
        
        if case .success(let devices) = result {
            XCTAssertEqual(devices.count, 2)
            XCTAssertEqual(devices[0].deviceName, "My Authenticator")
            XCTAssertEqual(devices[0].uuid, "oath-uuid-1")
            XCTAssertEqual(devices[1].deviceName, "Work Phone")
            XCTAssertEqual(devices[1].uuid, "oath-uuid-2")
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testFetchPushDevicesSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createPushDevicesJSON()))
        
        let result = await deviceClient.push.get()
        
        if case .success(let devices) = result {
            XCTAssertEqual(devices.count, 1)
            XCTAssertEqual(devices[0].deviceName, "My iPhone")
            XCTAssertEqual(devices[0].uuid, "push-uuid-1")
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testFetchBoundDevicesSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createBoundDevicesJSON()))
        
        let result = await deviceClient.bound.get()
        
        if case .success(let devices) = result {
            XCTAssertEqual(devices.count, 1)
            XCTAssertEqual(devices[0].deviceName, "Bound Device")
            XCTAssertEqual(devices[0].deviceId, "device-id-123")
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testFetchProfileDevicesSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createProfileDevicesJSON()))
        
        let result = await deviceClient.profile.get()
        
        if case .success(let devices) = result {
            XCTAssertEqual(devices.count, 1)
            XCTAssertEqual(devices[0].deviceName, "My Device")
            XCTAssertEqual(devices[0].identifier, "device-identifier-1")
            XCTAssertEqual(devices[0].metadata["platform"] as? String, "iOS")
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testFetchWebAuthnDevicesSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createWebAuthnDevicesJSON()))
        
        let result = await deviceClient.webAuthn.get()
        
        if case .success(let devices) = result {
            XCTAssertEqual(devices.count, 1)
            XCTAssertEqual(devices[0].deviceName, "YubiKey")
            XCTAssertEqual(devices[0].credentialId, "credential-id-abc")
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testFetchDevicesEmptyResult() async {
        setupSessionMock()
        
        let emptyJSON: [String: Any] = ["result": []]
        let emptyData = try! JSONSerialization.data(withJSONObject: emptyJSON)
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: emptyData))
        
        let result = await deviceClient.oath.get()
        
        if case .success(let devices) = result {
            XCTAssertEqual(devices.count, 0)
        } else {
            XCTFail("Expected success result with empty array")
        }
    }
    
    // MARK: - Update Operations Tests
    
    func testUpdateBoundDeviceSuccess() async {
        setupSessionMock()
        
        // First fetch to get device
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createBoundDevicesJSON()))
        let fetchResult = await deviceClient.bound.get()
        
        guard case .success(var devices) = fetchResult, var device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        // Update device
        device.deviceName = "Updated Device Name"
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        
        let updateResult = await deviceClient.bound.update(device)
        
        if case .success(let success) = updateResult {
            XCTAssertTrue(success)
            
            // Verify request was made
            let updateRequest = mockHttpClient.requests.last
            XCTAssertTrue(updateRequest?.urlString.contains(device.id) ?? false)
            XCTAssertEqual(updateRequest?.method, .put)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testUpdateProfileDeviceSuccess() async {
        setupSessionMock()
        
        // First fetch to get device
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createProfileDevicesJSON()))
        let fetchResult = await deviceClient.profile.get()
        
        guard case .success(var devices) = fetchResult, var device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        // Update device
        device.deviceName = "Updated Profile"
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        
        let updateResult = await deviceClient.profile.update(device)
        
        if case .success(let success) = updateResult {
            XCTAssertTrue(success)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testUpdateWebAuthnDeviceSuccess() async {
        setupSessionMock()
        
        // First fetch to get device
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createWebAuthnDevicesJSON()))
        let fetchResult = await deviceClient.webAuthn.get()
        
        guard case .success(var devices) = fetchResult, var device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        // Update device
        device.deviceName = "Updated YubiKey"
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        
        let updateResult = await deviceClient.webAuthn.update(device)
        
        if case .success(let success) = updateResult {
            XCTAssertTrue(success)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    // MARK: - Delete Operations Tests
    
    func testDeleteOathDeviceSuccess() async {
        setupSessionMock()
        
        // First fetch to get device
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()))
        let fetchResult = await deviceClient.oath.get()
        
        guard case .success(let devices) = fetchResult, let device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        // Delete device
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        
        let deleteResult = await deviceClient.oath.delete(device)
        
        if case .success(let success) = deleteResult {
            XCTAssertTrue(success)
            
            // Verify request was made
            let deleteRequest = mockHttpClient.requests.last
            XCTAssertTrue(deleteRequest?.urlString.contains(device.id) ?? false)
            XCTAssertEqual(deleteRequest?.method, .delete)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testDeletePushDeviceSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createPushDevicesJSON()))
        let fetchResult = await deviceClient.push.get()
        
        guard case .success(let devices) = fetchResult, let device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        let deleteResult = await deviceClient.push.delete(device)
        
        if case .success(let success) = deleteResult {
            XCTAssertTrue(success)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testDeleteBoundDeviceSuccess() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createBoundDevicesJSON()))
        let fetchResult = await deviceClient.bound.get()
        
        guard case .success(let devices) = fetchResult, let device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        let deleteResult = await deviceClient.bound.delete(device)
        
        if case .success(let success) = deleteResult {
            XCTAssertTrue(success)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testDeleteWith204StatusCode() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()))
        let fetchResult = await deviceClient.oath.get()
        
        guard case .success(let devices) = fetchResult, let device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        // Some servers return 204 No Content on successful delete
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 204, data: Data()))
        let deleteResult = await deviceClient.oath.delete(device)
        
        if case .success(let success) = deleteResult {
            XCTAssertTrue(success)
        } else {
            XCTFail("Expected success result for 204 status code")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchDevicesNetworkError() async {
        setupSessionMock()
        mockHttpClient.shouldThrowError = true
        mockHttpClient.errorToThrow = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        
        let result = await deviceClient.oath.get()
        
        if case .failure(let error) = result {
            if case .networkError = error {
                // Success - got expected error type
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testFetchDevices401Error() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 401, data: Data()))
        
        let result = await deviceClient.oath.get()
        
        if case .failure(let error) = result {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 401)
            } else {
                XCTFail("Expected requestFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testFetchDevices404Error() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 404, data: Data()))
        
        let result = await deviceClient.oath.get()
        
        if case .failure(let error) = result {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Expected requestFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testFetchDevices500Error() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 500, data: Data()))
        
        let result = await deviceClient.oath.get()
        
        if case .failure(let error) = result {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected requestFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testFetchDevicesInvalidResponse() async {
        setupSessionMock()
        
        let invalidJSON = "{ invalid json }"
        let invalidData = invalidJSON.data(using: .utf8)!
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: invalidData))
        
        let result = await deviceClient.oath.get()
        
        if case .failure(let error) = result {
            if case .decodingFailed = error {
                // Success - got expected error type
            } else {
                XCTFail("Expected decodingFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testFetchDevicesMissingResultKey() async {
        setupSessionMock()
        
        let invalidJSON: [String: Any] = ["data": []] // Missing "result" key
        let invalidData = try! JSONSerialization.data(withJSONObject: invalidJSON)
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: invalidData))
        
        let result = await deviceClient.oath.get()
        
        if case .failure(let error) = result {
            if case .decodingFailed = error {
                // Success - got expected error type
            } else {
                XCTFail("Expected decodingFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testUpdateDeviceFailure() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createBoundDevicesJSON()))
        let fetchResult = await deviceClient.bound.get()
        
        guard case .success(var devices) = fetchResult, var device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        device.deviceName = "Updated Name"
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 500, data: Data()))
        
        let updateResult = await deviceClient.bound.update(device)
        
        if case .failure(let error) = updateResult {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected requestFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    func testDeleteDeviceFailure() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()))
        let fetchResult = await deviceClient.oath.get()
        
        guard case .success(let devices) = fetchResult, let device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 403, data: Data()))
        let deleteResult = await deviceClient.oath.delete(device)
        
        if case .failure(let error) = deleteResult {
            if case .requestFailed(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 403)
            } else {
                XCTFail("Expected requestFailed error")
            }
        } else {
            XCTFail("Expected failure result")
        }
    }
    
    // MARK: - Request Building Tests
    
    func testRequestContainsAuthHeaders() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()))
        
        _ = await deviceClient.oath.get()
        
        let deviceRequest = mockHttpClient.requests.last
        XCTAssertEqual(deviceRequest?.headers?["TestCookie"], "test-token-12345")
        XCTAssertEqual(deviceRequest?.headers?["Accept-API-Version"], "resource=1.0")
    }
    
    func testRequestURLConstruction() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createOathDevicesJSON()))
        
        _ = await deviceClient.oath.get()
        
        let deviceRequest = mockHttpClient.requests.last
        XCTAssertTrue(deviceRequest?.urlString.contains("https://test.example.com") ?? false)
        XCTAssertTrue(deviceRequest?.urlString.contains("/json/realms/alpha/users/demo/devices/2fa/oath") ?? false)
        XCTAssertTrue(deviceRequest?.urlString.contains("_queryFilter=true") ?? false)
    }
    
    func testUpdateRequestBodyEncoding() async {
        setupSessionMock()
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: createBoundDevicesJSON()))
        let fetchResult = await deviceClient.bound.get()
        
        guard case .success(var devices) = fetchResult, var device = devices.first else {
            XCTFail("Failed to fetch device")
            return
        }
        
        device.deviceName = "New Name"
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: Data()))
        
        _ = await deviceClient.bound.update(device)
        
        let updateRequest = mockHttpClient.requests.last
        XCTAssertNotNil(updateRequest?.body)
        
        if let body = updateRequest?.body {
            do {
                let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
                XCTAssertEqual(json?["deviceName"] as? String, "New Name")
            } catch {
                XCTFail("Failed to decode request body JSON: \(error)")
            }
        } else {
            XCTFail("Request body should be present")
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupSessionMock() {
        let sessionJSON: [String: Any] = [
            "username": "demo",
            "universalId": "id=demo,ou=user,dc=openam,dc=forgerock,dc=org",
            "realm": "/alpha",
            "latestAccessTime": "2024-01-01T00:00:00Z",
            "maxIdleExpirationTime": "2024-01-01T01:00:00Z",
            "maxSessionExpirationTime": "2024-01-01T08:00:00Z"
        ]
        let sessionData = try! JSONSerialization.data(withJSONObject: sessionJSON)
        mockHttpClient.responses.append(MockHttpResponse(statusCode: 200, data: sessionData))
    }
    
    private func createOathDevicesJSON() -> Data {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "oath-1",
                    "deviceName": "My Authenticator",
                    "uuid": "oath-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ],
                [
                    "_id": "oath-2",
                    "deviceName": "Work Phone",
                    "uuid": "oath-uuid-2",
                    "createdDate": 1640000002000.0,
                    "lastAccessDate": 1640000003000.0
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func createPushDevicesJSON() -> Data {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "push-1",
                    "deviceName": "My iPhone",
                    "uuid": "push-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func createBoundDevicesJSON() -> Data {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "bound-1",
                    "deviceName": "Bound Device",
                    "deviceId": "device-id-123",
                    "uuid": "bound-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func createProfileDevicesJSON() -> Data {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "profile-1",
                    "alias": "My Device",
                    "identifier": "device-identifier-1",
                    "metadata": [
                        "platform": "iOS",
                        "version": "17.0"
                    ],
                    "lastSelectedDate": 1640000000000.0
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func createWebAuthnDevicesJSON() -> Data {
        let json: [String: Any] = [
            "result": [
                [
                    "_id": "webauthn-1",
                    "deviceName": "YubiKey",
                    "credentialId": "credential-id-abc",
                    "uuid": "webauthn-uuid-1",
                    "createdDate": 1640000000000.0,
                    "lastAccessDate": 1640000001000.0
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
}

// MARK: - Mock Objects

/// Mock HTTP client for testing
class MockHttpClient: HttpClient, @unchecked Sendable {
    var responses: [MockHttpResponse] = []
    var requests: [MockRequest] = []
    var shouldThrowError = false
    var errorToThrow: Error?
    private var responseIndex = 0
    
    override func sendRequest(request: Request) async throws -> (Data, URLResponse) {
        // Capture request
        let methodEnum = request.urlRequest.httpMethod.flatMap(Request.HTTPMethod.init(rawValue:))
        requests.append(MockRequest(
            urlString: request.urlRequest.url?.absoluteString ?? "",
            method: methodEnum,
            headers: request.urlRequest.allHTTPHeaderFields,
            body: request.urlRequest.httpBody
        ))
        
        // Throw error if configured
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "MockError", code: -1)
        }
        
        // Return mock response
        guard responseIndex < responses.count else {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No more mock responses"])
        }
        
        let response = responses[responseIndex]
        responseIndex += 1
        
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://test.example.com")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (response.data, urlResponse)
    }
}

/// Mock HTTP response
struct MockHttpResponse {
    let statusCode: Int
    let data: Data
}

/// Mock request capture
struct MockRequest {
    let urlString: String
    let method: Request.HTTPMethod?
    let headers: [String: String]?
    let body: Data?
}
