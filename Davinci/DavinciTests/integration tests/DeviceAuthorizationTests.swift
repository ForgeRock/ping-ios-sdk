//
//  DeviceAuthorizationTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

/// E2E tests for the OAuth 2.0 Device Authorization Grant (RFC 8628) flow against PingOne/DaVinci.
///
/// Configuration is loaded from `ConfigDeviceAuth.json`. The file is committed with blank values;
/// the real values are injected by CI or set locally before running these tests.
///
/// Test topology:
/// - `client` — the requesting device, drives `OidcDeviceClient.deviceAuthorization()`.
/// - `approvingDaVinci` — the approving device, drives a DaVinci login flow using
///   `verificationUriComplete` so the server links the session to the pending device code.
class DeviceAuthorizationTests: DaVinciBaseTests, @unchecked Sendable {

    private var client: OidcDeviceClient!
    private var approvingDaVinci: DaVinci!

    override func setUp() async throws {
        self.configFileName = "ConfigNew"
        try await super.setUp()

        client = OidcDeviceClient.createOidcDeviceClient { config in
            config.logger = LogManager.standard
            config.clientId = self.config.deviceClientId
            config.discoveryEndpoint = self.config.discoveryEndpoint
            config.scopes = Set(["openid", "email", "address", "phone", "profile"])
            config.storage = KeychainStorage<Token>(account: "device_flow_test")
        }

        approvingDaVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.scopes = Set(["openid", "email", "address", "phone", "profile"])
                oidcValue.redirectUri = ""
                oidcValue.storage = KeychainStorage<Token>(account: "device_flow_approver_test")
            }
        }

        // Clear any leftover token so each test starts fresh.
        await client.user()?.logout()
        await approvingDaVinci.daVinciUser()?.logout()
    }

    // =========================================================================
    // TC-01: Start device authorization flow — verify user code and polling
    // =========================================================================

    /// Starts the device flow, waits for the first `.polling` emission, then cancels.
    /// Keeps the test well under 20 s (one 5 s poll interval) instead of waiting for expiry.
    ///
    /// Verifies:
    /// - First emission is `.started` with a well-formed `DeviceAuthorizationResponse`.
    /// - `userCode` matches the XXXX-XXXX pattern.
    /// - `verificationUri` begins with the expected PingOne base URL.
    /// - `verificationUriComplete` is present and contains `user_code=`.
    /// - At least one `.polling` emission follows with `pollCount == 1` and the
    ///   server-specified `pollInterval`.
    func testStartFlowEmitsStartedThenPolling() async throws {
        let stream = try await client.deviceAuthorization()

        var started: DeviceFlowStatus? = nil
        var firstPolling: DeviceFlowStatus? = nil

        for try await status in stream {
            switch status {
            case .started:
                started = status
            case .polling:
                firstPolling = status
                // Cancel after the first poll — no need to wait for expiry.
                break
            default:
                break
            }
            if firstPolling != nil { break }
        }

        // --- .started ---
        guard case .started(let response) = started else {
            XCTFail("First emission must be .started")
            return
        }

        XCTAssertFalse(response.userCode.isEmpty, "userCode must not be empty")
        XCTAssertTrue(
            response.userCode.range(of: #"^[A-Z0-9]{4}-[A-Z0-9]{4}$"#, options: .regularExpression) != nil,
            "userCode '\(response.userCode)' must match pattern XXXX-XXXX"
        )

        XCTAssertFalse(response.verificationUri.isEmpty, "verificationUri must not be empty")
        XCTAssertTrue(
            response.verificationUri.hasPrefix("https://auth.pingone.ca/"),
            "verificationUri should start with 'https://auth.pingone.ca/', got: \(response.verificationUri)"
        )

        XCTAssertNotNil(response.verificationUriComplete, "verificationUriComplete must be present")
        XCTAssertTrue(
            response.verificationUriComplete?.contains("user_code=") == true,
            "verificationUriComplete must contain 'user_code='"
        )

        XCTAssertFalse(response.deviceCode.isEmpty, "deviceCode must not be empty")
        XCTAssertGreaterThan(response.expiresIn, 0, "expiresIn must be positive")
        XCTAssertEqual(5, response.interval, "PingOne default interval is 5 seconds")

        // --- .polling ---
        guard case .polling(let pollCount, let pollInterval, _) = firstPolling else {
            XCTFail("Expected at least one .polling emission")
            return
        }
        XCTAssertEqual(1, pollCount, "first pollCount must be 1")
        XCTAssertEqual(response.interval, pollInterval, "pollInterval must match the server-specified interval")
    }

    // =========================================================================
    // TC-02: Successful device authorization via DaVinci approval
    // =========================================================================

    /// Starts the device flow, drives a DaVinci login on the approving side using
    /// `verificationUriComplete`, taps "Approve Device", and waits for the requesting
    /// side to emit `.success`.
    ///
    /// Verifies:
    /// - Terminal emission on the requesting side is `.success`.
    /// - The access token is retrievable from the returned `User`.
    /// - `client.user()` is non-nil after the flow completes.
    func testDeviceAuthorizationApprovalViaDaVinci() async throws {
        let stream = try await client.deviceAuthorization()

        var allStatuses: [DeviceFlowStatus] = []
        var approvalTask: Task<Void, Never>?

        // Iterate the stream on this task. When .started arrives, fire the approving-side
        // flow in a background Task so polling and approval run concurrently — same pattern
        // as testChallengePollingApproval in PollingCollectorIntegrationTests.
        for try await status in stream {
            allStatuses.append(status)

            if case .started(let response) = status, approvalTask == nil {
                guard let uriComplete = response.verificationUriComplete else {
                    XCTFail("verificationUriComplete must be present for DaVinci approval")
                    return
                }
                let approvingDaVinci = self.approvingDaVinci!
                let username = config.deviceUsername
                let password = config.devicePassword

                approvalTask = Task {
                    // Step 1: start the approving DaVinci flow with the verification URI.
                    var node = await approvingDaVinci.start { options in
                        options.verificationUriComplete = URL(string: uriComplete)
                    }
                    guard let continueNode = node as? ContinueNode else {
                        XCTFail("Expected ContinueNode from approvingDaVinci.start, got \(type(of: node))")
                        return
                    }
                    node = continueNode

                    // Step 2: Sign On form — username + password.
                    (continueNode.collectors[0] as? TextCollector)?.value = username
                    (continueNode.collectors[1] as? PasswordCollector)?.value = password
                    (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
                    node = await continueNode.next()
                    guard let deviceFormNode = node as? ContinueNode else {
                        XCTFail("Expected ContinueNode after sign-on, got \(type(of: node))")
                        return
                    }

                    // Step 3: Device Code form — tap "Approve Device" (FlowCollector at index 1).
                    // Layout: index 0 = TEXT (device-code display), index 1 = FLOW_BUTTON (approve),
                    //         index 2 = FLOW_BUTTON (reject).
                    (deviceFormNode.collectors[1] as? FlowCollector)?.value = "click"
                    let approvalResult = await deviceFormNode.next()
                    // The approval returns a DaVinci ContinueNode wrapping the redirect response —
                    // not a SuccessNode. What matters is the requesting side receives .success.
                    XCTAssertTrue(approvalResult is ContinueNode,
                                  "Approval should return a ContinueNode (DaVinci redirect), got \(type(of: approvalResult))")
                }
            }

            if case .success = status { break }
            if case .accessDenied = status { break }
            if case .expired = status { break }
            if case .failure = status { break }
        }

        await approvalTask?.value

        // Requesting side must have received .success as the terminal emission.
        guard case .success(let user) = allStatuses.last else {
            XCTFail("Expected .success as terminal status, got \(String(describing: allStatuses.last))")
            return
        }

        let tokenResult = await user.token()
        switch tokenResult {
        case .success(let token):
            XCTAssertNotNil(token.accessToken, "accessToken must not be nil")
        case .failure(let error):
            XCTFail("token() should succeed after approval, got error: \(error)")
        }

        let userAfterFlow = await client.user()
        XCTAssertNotNil(userAfterFlow, "client.user() must be non-nil after successful device flow")

        // Clean up.
        await client.user()?.logout()
        await approvingDaVinci.daVinciUser()?.logout()
    }

    // =========================================================================
    // TC-03: Device authorization denied via DaVinci
    // =========================================================================

    /// Starts the device flow, drives a DaVinci login, taps "Reject Device", and confirms
    /// the requesting side receives `.accessDenied`.
    ///
    /// Verifies:
    /// - The DaVinci reject step returns an `ErrorNode` (server returns 400 with the rejection).
    /// - Terminal emission on the requesting side is `.accessDenied`.
    /// - `client.user()` is nil — no token was stored.
    func testDeviceAuthorizationRejectedViaDaVinci() async throws {
        let stream = try await client.deviceAuthorization()

        var allStatuses: [DeviceFlowStatus] = []
        var rejectionTask: Task<Void, Never>?

        for try await status in stream {
            allStatuses.append(status)

            if case .started(let response) = status, rejectionTask == nil {
                guard let uriComplete = response.verificationUriComplete else {
                    XCTFail("verificationUriComplete must be present for DaVinci rejection")
                    return
                }
                let approvingDaVinci = self.approvingDaVinci!
                let username = config.deviceUsername
                let password = config.devicePassword

                rejectionTask = Task {
                    var node = await approvingDaVinci.start { options in
                        options.verificationUriComplete = URL(string: uriComplete)
                    }
                    guard let continueNode = node as? ContinueNode else {
                        XCTFail("Expected ContinueNode from approvingDaVinci.start, got \(type(of: node))")
                        return
                    }
                    node = continueNode

                    // Sign On.
                    (continueNode.collectors[0] as? TextCollector)?.value = username
                    (continueNode.collectors[1] as? PasswordCollector)?.value = password
                    (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"
                    node = await continueNode.next()
                    guard let deviceFormNode = node as? ContinueNode else {
                        XCTFail("Expected ContinueNode after sign-on, got \(type(of: node))")
                        return
                    }

                    // Tap "Reject Device" (FlowCollector at index 2).
                    (deviceFormNode.collectors[2] as? FlowCollector)?.value = "click"
                    let rejectionResult = await deviceFormNode.next()
                    // The server returns 400 with the rejection, surfaced as an ErrorNode.
                    XCTAssertTrue(rejectionResult is ErrorNode,
                                  "Rejection should return an ErrorNode, got \(type(of: rejectionResult))")
                }
            }

            if case .success = status { break }
            if case .accessDenied = status { break }
            if case .expired = status { break }
            if case .failure = status { break }
        }

        await rejectionTask?.value

        // Requesting side must have received .accessDenied as the terminal emission.
        guard case .accessDenied = allStatuses.last else {
            XCTFail("Expected .accessDenied as terminal status, got \(String(describing: allStatuses.last))")
            return
        }

        let userAfterRejection = await client.user()
        XCTAssertNil(userAfterRejection, "client.user() must be nil after a rejected device flow")
    }

    // =========================================================================
    // TC-04: Device code expires without approval
    // =========================================================================

    /// Starts the device flow without approving and waits for the polling loop to exhaust
    /// the device-code lifetime. The terminal emission must be `.expired`.
    ///
    /// Disabled by default: this test waits for the full device-code lifetime (~30 s on this
    /// tenant) before asserting `.expired`, which makes it too slow for routine CI runs.
    /// Enable it manually when verifying expiry behaviour (e.g. after changes to the polling
    /// loop or token storage).
    func disabled_testDeviceCodeExpiresWithoutApproval() async throws {
        let stream = try await client.deviceAuthorization()
        var allStatuses: [DeviceFlowStatus] = []

        for try await status in stream {
            allStatuses.append(status)
        }

        guard case .started = allStatuses.first else {
            XCTFail("First emission must be .started")
            return
        }

        let pollingEmissions = allStatuses.compactMap { status -> DeviceFlowStatus? in
            if case .polling = status { return status }
            return nil
        }
        XCTAssertFalse(pollingEmissions.isEmpty, "Expected at least one .polling emission before expiry")

        guard case .expired = allStatuses.last else {
            XCTFail("Expected .expired as terminal status, got \(String(describing: allStatuses.last))")
            return
        }

        let userAfterExpiry = await client.user()
        XCTAssertNil(userAfterExpiry, "client.user() must be nil after device-code expiry")
    }
}
