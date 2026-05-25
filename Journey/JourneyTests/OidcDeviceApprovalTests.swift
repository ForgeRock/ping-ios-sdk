//
//  OidcDeviceApprovalTests.swift
//  JourneyTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingOrchestrate
import PingJourneyPlugin
@testable import PingJourney
@testable import PingOidc
@testable import PingNetwork
@testable import PingLogger

final class OidcDeviceApprovalTests: XCTestCase, @unchecked Sendable {

    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }

    // Builds a Journey with MockURLProtocol wired in. Device approval is built into OidcModule.
    private func makeJourney() -> Journey {
        Journey.createJourney { journeyConfig in
            journeyConfig.serverUrl = "https://openam.example.com/am"
            journeyConfig.realm = "alpha"
            journeyConfig.cookie = "iPlanetDirectoryPro"
            journeyConfig.httpClient = MockURLProtocol.makeClient()
            journeyConfig.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.clientId = "testClient"
                oidcValue.scopes = ["openid"]
                oidcValue.redirectUri = "myapp://callback"
                oidcValue.discoveryEndpoint = "https://openam.example.com/am/oauth2/alpha/.well-known/openid-configuration"
            }
        }
    }

    private func makeSSOToken(value: String = "test-sso-token") -> SSOTokenImpl {
        SSOTokenImpl(value: value, successUrl: "https://openam.example.com/console", realm: "alpha")
    }

    // Runs all successHandlers on the journey and returns the last SuccessNode emitted.
    private func driveSuccessHandlers(journey: Journey, session: Session) async throws -> SuccessNode {
        let context = FlowContext(flowContext: journey.sharedContext)
        var node = SuccessNode(session: session)
        for handler in journey.successHandlers {
            node = try await handler(context, node)
        }
        return node
    }

    // MARK: - No-op when verificationUriComplete is absent

    func testNoOpWhenVerificationUriCompleteKeyAbsent() async throws {
        let journey = makeJourney()
        // verificationUriCompleteKey is NOT set in sharedContext

        var deviceUserRequestMade = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("device/user") == true {
                deviceUserRequestMade = true
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        let result = try await driveSuccessHandlers(journey: journey, session: makeSSOToken())

        XCTAssertFalse(deviceUserRequestMade, "No device/user POST should be made when verificationUriComplete is absent")
        XCTAssertEqual(result.session.value, makeSSOToken().value)
    }

    // MARK: - No-op when session is not SSOToken

    func testNoOpWhenSessionIsNotSSOToken() async throws {
        let journey = makeJourney()
        journey.sharedContext.set(
            key: SharedContext.Keys.journeyVerificationUriCompleteKey,
            value: "https://openam.example.com/activate?user_code=ABCD-1234"
        )

        var deviceUserRequestMade = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("device/user") == true {
                deviceUserRequestMade = true
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        // MockSession is not an SSOToken — the module's guard should short-circuit
        let nonSsoSession = MockSession(value: "non-sso")
        _ = try await driveSuccessHandlers(journey: journey, session: nonSsoSession)

        XCTAssertFalse(deviceUserRequestMade, "No device/user POST should be made when session is not SSOToken")
    }

    // MARK: - AM POST with correct parameters

    func testDeviceApprovalPostWithCorrectParameters() async throws {
        let journey = makeJourney()
        let ssoToken = makeSSOToken(value: "my-sso-session-token")
        let verificationUri = "https://openam.example.com/activate?user_code=ABCD-1234"
        journey.sharedContext.set(
            key: SharedContext.Keys.journeyVerificationUriCompleteKey,
            value: verificationUri
        )

        var capturedRequest: URLRequest?
        var capturedBodyParams = [String: String]()

        MockURLProtocol.requestHandler = { request in
            // The module POSTs to the verificationUriComplete URL itself (/activate), not a /device/user path.
            if request.url?.absoluteString == verificationUri {
                capturedRequest = request
                // URLSession may move httpBody to httpBodyStream before giving the request to URLProtocol.
                let bodyData: Data?
                if let data = request.httpBody {
                    bodyData = data
                } else if let stream = request.httpBodyStream {
                    stream.open()
                    var data = Data()
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                    while stream.hasBytesAvailable {
                        let count = stream.read(buffer, maxLength: 4096)
                        if count > 0 { data.append(buffer, count: count) }
                    }
                    buffer.deallocate()
                    stream.close()
                    bodyData = data
                } else {
                    bodyData = nil
                }
                if let data = bodyData, let bodyString = String(data: data, encoding: .utf8) {
                    for pair in bodyString.components(separatedBy: "&") {
                        let kv = pair.components(separatedBy: "=")
                        if kv.count == 2 {
                            capturedBodyParams[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                        }
                    }
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        let result = try await driveSuccessHandlers(journey: journey, session: ssoToken)

        // The SuccessNode should be returned unchanged.
        XCTAssertEqual(result.session.value, ssoToken.value)

        // A POST should have been made to the verificationUriComplete URL.
        XCTAssertNotNil(capturedRequest, "Expected a POST to the verificationUriComplete URL")
        XCTAssertEqual(capturedRequest?.url?.absoluteString, verificationUri)

        // Form parameters must match RFC 8628 expectations.
        XCTAssertEqual(capturedBodyParams["user_code"], "ABCD-1234")
        XCTAssertEqual(capturedBodyParams["decision"], "allow")
        XCTAssertEqual(capturedBodyParams["csrf"], ssoToken.value)

        // SSO token should appear in the custom cookie header (name taken from JourneyConfig.cookie).
        // makeJourney() sets journeyConfig.cookie = "iPlanetDirectoryPro".
        let cookieHeaderValue = capturedRequest?.value(forHTTPHeaderField: "iPlanetDirectoryPro") ?? ""
        XCTAssertEqual(cookieHeaderValue, ssoToken.value,
                       "iPlanetDirectoryPro header should carry the SSO token value")
    }

    // MARK: - No-op when verificationUriComplete URI is malformed

    func testNoOpWhenVerificationUriCompleteIsMalformed() async throws {
        let journey = makeJourney()
        journey.sharedContext.set(
            key: SharedContext.Keys.journeyVerificationUriCompleteKey,
            value: "not a valid url %%%"
        )

        var deviceUserRequestMade = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("device/user") == true {
                deviceUserRequestMade = true
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        _ = try await driveSuccessHandlers(journey: journey, session: makeSSOToken())

        XCTAssertFalse(deviceUserRequestMade, "No POST should be made when verificationUriComplete is a malformed URL")
    }

    // MARK: - No-op when user_code is missing from URI

    func testNoOpWhenUserCodeIsMissingFromUri() async throws {
        let journey = makeJourney()
        // Valid URL but no user_code query parameter
        journey.sharedContext.set(
            key: SharedContext.Keys.journeyVerificationUriCompleteKey,
            value: "https://openam.example.com/activate"
        )

        var deviceUserRequestMade = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("device/user") == true {
                deviceUserRequestMade = true
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        _ = try await driveSuccessHandlers(journey: journey, session: makeSSOToken())

        XCTAssertFalse(deviceUserRequestMade, "No POST should be made when user_code is absent from verificationUriComplete")
    }

    // MARK: - No-op when user_code is empty

    func testNoOpWhenUserCodeIsEmpty() async throws {
        let journey = makeJourney()
        journey.sharedContext.set(
            key: SharedContext.Keys.journeyVerificationUriCompleteKey,
            value: "https://openam.example.com/activate?user_code="
        )

        var deviceUserRequestMade = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("device/user") == true {
                deviceUserRequestMade = true
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        _ = try await driveSuccessHandlers(journey: journey, session: makeSSOToken())

        XCTAssertFalse(deviceUserRequestMade, "No POST should be made when user_code value is empty")
    }

    // MARK: - Network failure does not convert SuccessNode to FailureNode

    func testNetworkFailureDoesNotFailSuccessNode() async throws {
        let journey = makeJourney()
        journey.sharedContext.set(
            key: SharedContext.Keys.journeyVerificationUriCompleteKey,
            value: "https://openam.example.com/activate?user_code=EFGH-5678"
        )

        MockURLProtocol.requestHandler = { request in
            throw URLError(.notConnectedToInternet)
        }

        let ssoToken = makeSSOToken()
        let result = try await driveSuccessHandlers(journey: journey, session: ssoToken)

        // Even when the network call throws, the module must absorb the error and return SuccessNode.
        XCTAssertEqual(result.session.value, ssoToken.value,
                       "SuccessNode session should be unchanged after a network failure in device approval")
    }
}
