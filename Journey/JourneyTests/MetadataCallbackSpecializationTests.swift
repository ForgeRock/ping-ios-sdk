//
//  MetadataCallbackSpecializationTests.swift
//  JourneyTests
//
//  Converted from Swift Testing to XCTest
//

import XCTest
@testable import PingJourney
@testable import PingJourneyPlugin

// Test doubles for specialized callbacks
private final class TestPingOneProtectInitializeCallback: AbstractCallback, @unchecked Sendable {
    public override func initValue(name: String, value: Any) {}
}
private final class TestPingOneProtectEvaluationCallback: AbstractCallback, @unchecked Sendable {
    public override func initValue(name: String, value: Any) {}
}
private final class TestFidoRegistrationCallback: AbstractCallback, @unchecked Sendable {
    public override func initValue(name: String, value: Any) {}
}
private final class TestFidoAuthenticationCallback: AbstractCallback, @unchecked Sendable {
    public override func initValue(name: String, value: Any) {}
}
// A simple MetadataCallback registration key double
private final class TestMetadataCallback: MetadataCallback, @unchecked Sendable { }

final class MetadataCallbackSpecializationTests: XCTestCase {

    override func setUp() async throws {
        await CallbackRegistry.shared.reset()
    }

    func testProtectInitialize() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "PingOneProtectInitializeCallback", callback: TestPingOneProtectInitializeCallback.self)

        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_type": "PingOneProtect",
                "_action": "protect_initialize"
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is TestPingOneProtectInitializeCallback)
    }

    func testProtectEvaluation() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "PingOneProtectEvaluationCallback", callback: TestPingOneProtectEvaluationCallback.self)

        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_type": "PingOneProtect",
                "_action": "protect_risk_evaluation"
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is TestPingOneProtectEvaluationCallback)
    }

    func testFidoRegistrationByAction() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "FidoRegistrationCallback", callback: TestFidoRegistrationCallback.self)

        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_action": "webauthn_registration"
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is TestFidoRegistrationCallback)
    }

    func testFidoRegistrationByTypeAndParams() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "FidoRegistrationCallback", callback: TestFidoRegistrationCallback.self)

        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_type": "WebAuthn",
                "pubKeyCredParams": []
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is TestFidoRegistrationCallback)
    }

    func testFidoAuthenticationByAction() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "FidoAuthenticationCallback", callback: TestFidoAuthenticationCallback.self)

        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_action": "webauthn_authentication"
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is TestFidoAuthenticationCallback)
    }

    func testFidoAuthenticationByTypeAndAllowCredentials() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "FidoAuthenticationCallback", callback: TestFidoAuthenticationCallback.self)

        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_type": "WebAuthn",
                "allowCredentials": []
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is TestFidoAuthenticationCallback)
    }

    func testMetadataFilteredOutWhenNoSpecialization() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)

        // No recognizable metadata keys -> should not produce a non-metadata callback
        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "random": "value"
            ]
        )
        let result = await CallbackRegistry.shared.callback(from: [item])
        // Because the callback remains metadata (MetadataCallbackProtocol), it should be filtered out.
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Helpers

private func makeMetadataItem(typeKey: String, data: [String: Any]) -> [String: Any] {
    // The registry expects JourneyConstants.type, input/output arrays, and output with name/value entries.
    // We only need to populate output[data] for these tests.
    return [
        JourneyConstants.type: typeKey,
        JourneyConstants.output: [
            [
                JourneyConstants.name: JourneyConstants.data,
                JourneyConstants.value: data
            ]
        ],
        JourneyConstants.input: [] // not used by these tests
    ]
}
