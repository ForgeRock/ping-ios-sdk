//
//  PingAMPushResponderTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingOrchestrate
@testable import PingPush

private final class URLProtocolMock: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = URLProtocolMock.requestHandler else {
            fatalError("URLProtocolMock.requestHandler not set")
        }

        let bodyData = Self.extractBodyData(from: request)
        URLProtocolMock.lastRequestBody = bodyData

        do {
            let (response, data) = try handler(request)
            URLProtocolMock.lastRequest = request
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        requestHandler = nil
        lastRequest = nil
        lastRequestBody = nil
    }

    private static func extractBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }

        guard let stream = request.httpBodyStream else { return nil }
        return read(stream: stream)
    }

    private static func read(stream: InputStream) -> Data? {
        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                return nil
            }
            if bytesRead == 0 { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }
}

final class PingAMPushResponderTests: XCTestCase {

    private enum TestValues {
        static let base64Secret = "b3uYLkQ7dRPjBaIzV0t/aijoXRgMq+NP5AwVAvRfa/E="
        static let base64Challenge = "9giiBAdUHjqpo0XE4YdZ7pRlv0hrQYwDz8Z1wwLLbkg="
        static let expectedChallengeResponse = "Df02AwA3Ra+sTGkL5+QvkEtN3eLdZiFmL5nxAV1m0k8="
        static let messageId = "test-message-id"
        static let action = "test-action"
        static let deviceId = "test-apns-token"
        static let deviceName = "Test Device"
        static let cookie = "amlbcookie=value"
        static let serverEndpoint = "https://push.example.com/am/json/push"
        static let notificationId = "notification-id"
    }

    private var httpClient: HttpClient!
    private var responder: PingAMPushResponder!

    override func setUp() {
        super.setUp()
        URLProtocolMock.reset()
        httpClient = HttpClient()
        responder = PingAMPushResponder(httpClient: httpClient, logger: nil)
    }

    override func tearDown() {
        URLProtocolMock.reset()
        responder = nil
        httpClient = nil
        super.tearDown()
    }

    func testGenerateJwtProducesValidStructure() throws {
        let claims: [String: Any] = [
            "messageId": TestValues.messageId,
            "action": TestValues.action
        ]

        let jwt = try responder.generateJwt(base64Secret: TestValues.base64Secret, claims: claims)
        let components = jwt.split(separator: ".")
        XCTAssertEqual(components.count, 3, "JWT must contain three sections")

        let headerData = try XCTUnwrap(Self.decodeBase64URL(String(components[0])))
        let headerJson = try JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        XCTAssertEqual(headerJson?["alg"] as? String, "HS256")
        XCTAssertEqual(headerJson?["typ"] as? String, "JWT")

        let payloadData = try XCTUnwrap(Self.decodeBase64URL(String(components[1])))
        let payloadJson = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        XCTAssertEqual(payloadJson?["messageId"] as? String, TestValues.messageId)
        XCTAssertEqual(payloadJson?["action"] as? String, TestValues.action)

        XCTAssertFalse(components[2].isEmpty, "Signature component must not be empty")
    }

    func testGenerateJwtHandlesVariousDataTypes() throws {
        let claims: [String: Any] = [
            "stringValue": "test",
            "intValue": 123,
            "doubleValue": 123.45,
            "booleanValue": true,
            "nestedValue": ["key": "value"]
        ]

        let jwt = try responder.generateJwt(base64Secret: TestValues.base64Secret, claims: claims)
        let payloadData = try XCTUnwrap(Self.decodeBase64URL(jwt.components(separatedBy: ".")[1]))
        let payloadJson = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]

        XCTAssertEqual(payloadJson?["stringValue"] as? String, "test")
        XCTAssertEqual(payloadJson?["intValue"] as? Int, 123)
        XCTAssertEqual(payloadJson?["doubleValue"] as? Double, 123.45)
        XCTAssertEqual(payloadJson?["booleanValue"] as? Bool, true)

        let nested = payloadJson?["nestedValue"] as? [String: Any]
        XCTAssertEqual(nested?["key"] as? String, "value")
    }

    func testGenerateChallengeResponseMatchesExpectedValue() throws {
        let response = try responder.generateChallengeResponse(
            base64Secret: TestValues.base64Secret,
            base64Challenge: TestValues.base64Challenge
        )

        XCTAssertEqual(response, TestValues.expectedChallengeResponse)
    }

    func testGenerateChallengeResponseWithEmptySecretThrows() {
        XCTAssertThrowsError(
            try responder.generateChallengeResponse(
                base64Secret: "",
                base64Challenge: TestValues.base64Challenge
            )
        ) { error in
            guard case PushError.invalidParameterValue = error else {
                return XCTFail("Expected invalidParameterValue error")
            }
        }
    }

    func testGenerateChallengeResponseWithInvalidSecretThrows() {
        XCTAssertThrowsError(
            try responder.generateChallengeResponse(
                base64Secret: "not-base64",
                base64Challenge: TestValues.base64Challenge
            )
        ) { error in
            guard case PushError.invalidParameterValue = error else {
                return XCTFail("Expected invalidParameterValue error")
            }
        }
    }

    func testMakeRegistrationClaimsIncludesExpectedKeys() {
        let claims = responder.makeRegistrationClaims(
            deviceId: TestValues.deviceId,
            deviceName: TestValues.deviceName,
            mechanismUID: "mechanism-id",
            challengeResponse: TestValues.expectedChallengeResponse
        )

        XCTAssertEqual(claims[PingAMPushResponder.Keys.deviceId] as? String, TestValues.deviceId)
        XCTAssertEqual(claims[PingAMPushResponder.Keys.deviceName] as? String, TestValues.deviceName)
        XCTAssertEqual(claims[PingAMPushResponder.Keys.mechanismUID] as? String, "mechanism-id")
        XCTAssertEqual(
            claims[PingAMPushResponder.Keys.response] as? String,
            TestValues.expectedChallengeResponse
        )
        XCTAssertEqual(
            claims[PingAMPushResponder.Keys.communicationType] as? String,
            "apns"
        )
        XCTAssertEqual(
            claims[PingAMPushResponder.Keys.deviceType] as? String,
            "ios"
        )
    }

    func testMakeAuthenticationClaimsHandlesDenyAndNumbersChallenge() {
        let claims = responder.makeAuthenticationClaims(
            challengeResponse: TestValues.expectedChallengeResponse,
            deny: true,
            numbersChallengeResponse: "42"
        )

        XCTAssertEqual(
            claims[PingAMPushResponder.Keys.response] as? String,
            TestValues.expectedChallengeResponse
        )
        XCTAssertEqual(
            claims[PingAMPushResponder.Keys.challengeResponse] as? String,
            "42"
        )
        XCTAssertEqual(claims[PingAMPushResponder.Keys.deny] as? Bool, true)
    }

    func testEncodeRequestBodyProducesValidJSON() throws {
        let body: [String: Any] = [
            "messageId": TestValues.messageId,
            "metadata": [
                "deviceId": TestValues.deviceId,
                "timestamp": 1700000000
            ],
            "approved": true
        ]

        let jsonData = try responder.encodeRequestBody(body)
        let deserialized = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        XCTAssertEqual(deserialized?["messageId"] as? String, TestValues.messageId)
        XCTAssertEqual(deserialized?["approved"] as? Bool, true)

        let metadata = deserialized?["metadata"] as? [String: Any]
        XCTAssertEqual(metadata?["deviceId"] as? String, TestValues.deviceId)
        XCTAssertEqual(metadata?["timestamp"] as? Int, 1_700_000_000)
    }

    func testRegisterSucceedsWithValidParameters() async throws {
        let expectation = expectation(description: "Request handled")
        URLProtocolMock.requestHandler = { request in
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()

        let params: [String: Any] = [
            PingAMPushResponder.Keys.messageId: TestValues.messageId,
            PingAMPushResponder.Keys.deviceId: TestValues.deviceId,
            PingAMPushResponder.Keys.deviceName: TestValues.deviceName,
            PingAMPushResponder.Keys.challenge: TestValues.base64Challenge,
            PingAMPushResponder.Keys.amlbCookie: TestValues.cookie
        ]

        let result = try await mockResponder.register(credential: credential, params: params)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(result)

        let lastRequest = try XCTUnwrap(URLProtocolMock.lastRequest)
        XCTAssertEqual(lastRequest.url?.absoluteString, credential.registrationEndpoint)
        XCTAssertEqual(lastRequest.value(forHTTPHeaderField: "Accept-API-Version"), "resource=1.0, protocol=1.0")
        XCTAssertEqual(lastRequest.value(forHTTPHeaderField: "Cookie"), TestValues.cookie)

        let bodyData = try XCTUnwrap(URLProtocolMock.lastRequestBody)
        let jwt = try extractJwt(from: bodyData)
        let payload = try Self.decodeJwtPayload(jwt)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceId] as? String, TestValues.deviceId)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceName] as? String, TestValues.deviceName)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.communicationType] as? String, "apns")
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceType] as? String, "ios")
        XCTAssertEqual(payload[PingAMPushResponder.Keys.response] as? String, TestValues.expectedChallengeResponse)

        let requestJson = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(requestJson?[PingAMPushResponder.Keys.messageId] as? String, TestValues.messageId)
        XCTAssertNotNil(requestJson?[PingAMPushResponder.Keys.jwt])
    }

    func testRegisterUsesDefaultDeviceNameWhenMissing() async throws {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()

        let params: [String: Any] = [
            PingAMPushResponder.Keys.messageId: TestValues.messageId,
            PingAMPushResponder.Keys.deviceId: TestValues.deviceId,
            PingAMPushResponder.Keys.challenge: TestValues.base64Challenge
        ]

        let result = try await mockResponder.register(credential: credential, params: params)
        XCTAssertTrue(result)

        let bodyData = try XCTUnwrap(URLProtocolMock.lastRequestBody)
        let jwt = try extractJwt(from: bodyData)
        let payload = try Self.decodeJwtPayload(jwt)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceName] as? String, "iOS Device")
    }

    func testRegisterMissingParameterThrows() async {
        let credential = makeCredential()
        do {
            _ = try await responder.register(credential: credential, params: [:])
            XCTFail("Expected error for missing parameters")
        } catch PushError.missingRequiredParameter(let key) {
            XCTAssertEqual(key, PingAMPushResponder.Keys.messageId)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRegisterInvalidChallengeThrows() async {
        URLProtocolMock.requestHandler = { _ in
            XCTFail("Request should not be executed when challenge is invalid")
            let response = HTTPURLResponse(
                url: URL(string: TestValues.serverEndpoint)!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()
        let params: [String: Any] = [
            PingAMPushResponder.Keys.messageId: TestValues.messageId,
            PingAMPushResponder.Keys.deviceId: TestValues.deviceId,
            PingAMPushResponder.Keys.challenge: "invalid-challenge"
        ]

        do {
            _ = try await mockResponder.register(credential: credential, params: params)
            XCTFail("Expected invalidParameterValue error")
        } catch PushError.invalidParameterValue {
            XCTAssertNil(URLProtocolMock.lastRequest)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRegisterNonSuccessStatusThrows() async {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data("{\"error\":\"server\"}".utf8)
            return (response, data)
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()
        let params: [String: Any] = [
            PingAMPushResponder.Keys.messageId: TestValues.messageId,
            PingAMPushResponder.Keys.deviceId: TestValues.deviceId,
            PingAMPushResponder.Keys.challenge: TestValues.base64Challenge
        ]

        do {
            _ = try await mockResponder.register(credential: credential, params: params)
            XCTFail("Expected network failure error")
        } catch PushError.networkFailure(let message, _) {
            XCTAssertTrue(message.contains("500"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendAuthenticationApprovalSuccess() async throws {
        let expectation = expectation(description: "Authentication request handled")
        URLProtocolMock.requestHandler = { request in
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()
        let notification = makeNotification()

        let result = try await mockResponder.sendAuthenticationResponse(
            credential: credential,
            notification: notification,
            approve: true
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(result)

        let lastRequest = try XCTUnwrap(URLProtocolMock.lastRequest)
        XCTAssertEqual(lastRequest.url?.absoluteString, credential.authenticationEndpoint)
        XCTAssertEqual(lastRequest.value(forHTTPHeaderField: "Accept-API-Version"), "resource=1.0, protocol=1.0")
        XCTAssertEqual(lastRequest.value(forHTTPHeaderField: "Cookie"), TestValues.cookie)

        let bodyData = try XCTUnwrap(URLProtocolMock.lastRequestBody)
        let jwt = try extractJwt(from: bodyData)
        let payload = try Self.decodeJwtPayload(jwt)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.response] as? String, TestValues.expectedChallengeResponse)
        XCTAssertNil(payload[PingAMPushResponder.Keys.deny])
        XCTAssertNil(payload[PingAMPushResponder.Keys.challengeResponse])

        let requestJson = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(requestJson?[PingAMPushResponder.Keys.messageId] as? String, notification.messageId)
        XCTAssertNotNil(requestJson?[PingAMPushResponder.Keys.jwt])
    }

    func testSendAuthenticationDenialIncludesDenyAndNumbersChallenge() async throws {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()
        var notification = makeNotification(loadBalancer: nil)
        notification.numbersChallenge = "1,2,3"

        let result = try await mockResponder.sendAuthenticationResponse(
            credential: credential,
            notification: notification,
            approve: false,
            numbersChallengeResponse: "42"
        )

        XCTAssertTrue(result)

        let lastRequest = try XCTUnwrap(URLProtocolMock.lastRequest)
        XCTAssertNil(lastRequest.value(forHTTPHeaderField: "Cookie"))

        let bodyData = try XCTUnwrap(URLProtocolMock.lastRequestBody)
        let jwt = try extractJwt(from: bodyData)
        let payload = try Self.decodeJwtPayload(jwt)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.response] as? String, TestValues.expectedChallengeResponse)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.challengeResponse] as? String, "42")
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deny] as? Bool, true)
    }

    func testSendAuthenticationMissingChallengeThrows() async {
        let credential = makeCredential()
        let notification = makeNotification(challenge: nil)

        do {
            _ = try await responder.sendAuthenticationResponse(
                credential: credential,
                notification: notification,
                approve: true
            )
            XCTFail("Expected invalidParameterValue for missing challenge")
        } catch PushError.invalidParameterValue(let message) {
            XCTAssertTrue(message.localizedCaseInsensitiveContains("challenge"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendAuthenticationNonSuccessStatusThrows() async {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data("{\"error\":\"failure\"}".utf8)
            return (response, data)
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()
        let notification = makeNotification()

        do {
            _ = try await mockResponder.sendAuthenticationResponse(
                credential: credential,
                notification: notification,
                approve: true
            )
            XCTFail("Expected network failure error")
        } catch PushError.networkFailure(let message, _) {
            XCTAssertTrue(message.contains("500"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUpdateDeviceTokenSuccess() async throws {
        let expectation = expectation(description: "Update request handled")
        URLProtocolMock.requestHandler = { request in
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()

        let result = try await mockResponder.updateDeviceToken(
            credential: credential,
            deviceToken: "  \(TestValues.deviceId)  ",
            deviceName: TestValues.deviceName
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(result)

        let lastRequest = try XCTUnwrap(URLProtocolMock.lastRequest)
        XCTAssertEqual(lastRequest.url?.absoluteString, credential.updateEndpoint)
        XCTAssertEqual(lastRequest.value(forHTTPHeaderField: "Accept-API-Version"), "resource=1.0, protocol=1.0")
        XCTAssertNil(lastRequest.value(forHTTPHeaderField: "Cookie"))

        let bodyData = try XCTUnwrap(URLProtocolMock.lastRequestBody)
        let requestJson = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(requestJson?[PingAMPushResponder.Keys.mechanismUID] as? String, credential.id)
        XCTAssertEqual(requestJson?[PingAMPushResponder.Keys.userId] as? String, credential.userId)

        let jwt = try extractJwt(from: bodyData)
        let payload = try Self.decodeJwtPayload(jwt)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceId] as? String, TestValues.deviceId)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceName] as? String, TestValues.deviceName)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.communicationType] as? String, "apns")
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceType] as? String, "ios")
    }

    func testUpdateDeviceTokenUsesDefaultDeviceName() async throws {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()

        let result = try await mockResponder.updateDeviceToken(
            credential: credential,
            deviceToken: TestValues.deviceId,
            deviceName: nil
        )

        XCTAssertTrue(result)

        let bodyData = try XCTUnwrap(URLProtocolMock.lastRequestBody)
        let jwt = try extractJwt(from: bodyData)
        let payload = try Self.decodeJwtPayload(jwt)
        XCTAssertEqual(payload[PingAMPushResponder.Keys.deviceName] as? String, "iOS Device")
    }

    func testUpdateDeviceTokenMissingTokenThrows() async {
        let credential = makeCredential()
        do {
            _ = try await responder.updateDeviceToken(
                credential: credential,
                deviceToken: "   ",
                deviceName: nil
            )
            XCTFail("Expected invalidParameterValue for empty token")
        } catch PushError.invalidParameterValue(let message) {
            XCTAssertTrue(message.localizedCaseInsensitiveContains("token"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUpdateDeviceTokenNonSuccessStatusThrows() async {
        URLProtocolMock.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data("{\"error\":\"failure\"}".utf8)
            return (response, data)
        }

        let mockResponder = PingAMPushResponder(httpClient: makeMockHttpClient(), logger: nil)
        let credential = makeCredential()

        do {
            _ = try await mockResponder.updateDeviceToken(
                credential: credential,
                deviceToken: TestValues.deviceId,
                deviceName: TestValues.deviceName
            )
            XCTFail("Expected network failure error")
        } catch PushError.networkFailure(let message, _) {
            XCTAssertTrue(message.contains("500"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }


    // MARK: - Helpers

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }

        return Data(base64Encoded: base64, options: [.ignoreUnknownCharacters])
    }

    private static func decodeJwtPayload(_ jwt: String) throws -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            throw XCTSkip("Invalid JWT structure")
        }
        let payloadData = try XCTUnwrap(decodeBase64URL(String(parts[1])))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
    }

    private func makeCredential() -> PushCredential {
        PushCredential(
            id: "credential-id",
            userId: "user-123",
            resourceId: "credential-id",
            issuer: "Ping Identity",
            displayIssuer: "Ping Identity",
            accountName: "user@example.com",
            displayAccountName: "User Example",
            serverEndpoint: TestValues.serverEndpoint,
            sharedSecret: TestValues.base64Secret,
            createdAt: Date(),
            platform: .pingAM
        )
    }

    private func makeMockHttpClient() -> HttpClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        return HttpClient(session: session)
    }

    private func extractJwt(from bodyData: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        return try XCTUnwrap(json?[PingAMPushResponder.Keys.jwt] as? String)
    }

    private func makeNotification(
        challenge: String? = TestValues.base64Challenge,
        loadBalancer: String? = TestValues.cookie
    ) -> PushNotification {
        PushNotification(
            id: TestValues.notificationId,
            credentialId: "credential-id",
            ttl: 60,
            messageId: TestValues.messageId,
            messageText: "Approve login?",
            customPayload: nil,
            challenge: challenge,
            numbersChallenge: nil,
            loadBalancer: loadBalancer,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date(),
            sentAt: nil,
            respondedAt: nil,
            additionalData: nil,
            approved: false,
            pending: true
        )
    }
}
