//
//  MetadataCallbackInjectionTests.swift
//  JourneyTests
//
//  Converted from Swift Testing to XCTest
//

import XCTest
@testable import PingJourneyPlugin
@testable import PingJourney
@testable import PingOrchestrate

// MARK: - Test doubles

// Specialized callbacks that record injections
private final class TestInjectableProtectInitCallback: AbstractCallback, JourneyAware, ContinueNodeAware, @unchecked Sendable {
    var journey: Journey?
    var continueNode: ContinueNode?
}

private final class TestInjectableFidoAuthCallback: AbstractCallback, JourneyAware, ContinueNodeAware, @unchecked Sendable {
    var journey: Journey?
    var continueNode: ContinueNode?
}

// Metadata registration key double
private final class TestMetadataCallback: MetadataCallback, @unchecked Sendable { }

// Minimal fake Journey. In your codebase, Journey is a typealias to Workflow,
// so we’ll use a concrete Workflow subclass instead where needed.

// Minimal fake Workflow to build a ContinueNode
private final class FakeWorkflow: Workflow, @unchecked Sendable {
    // Provide a minimal config to satisfy Workflow's initializer
    init() {
        super.init(config: WorkflowConfig())
    }

    override func next(_ context: FlowContext, _ node: ContinueNode) async -> Node {
        EmptyNode()
    }
}

// Minimal FlowContext helper
private extension FlowContext {
    static func fake() -> FlowContext {
        FlowContext(flowContext: SharedContext())
    }
}

// A tiny ContinueNode subclass we can instantiate
private final class FakeContinueNode: ContinueNode, @unchecked Sendable {
    init() {
        super.init(context: .fake(), workflow: FakeWorkflow(), input: [:], actions: [])
    }

    override func asRequest() -> Request { Request() }
}

// MARK: - Tests

final class MetadataCallbackInjectionTests: XCTestCase {

    override func setUp() async throws {
        await CallbackRegistry.shared.reset()
    }

    func testInjectForProtectInitialize() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "PingOneProtectInitializeCallback", callback: TestInjectableProtectInitCallback.self)

        // Build metadata that triggers Protect Initialize specialization
        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_type": "PingOneProtect",
                "_action": "protect_initialize"
            ]
        )

        // Create callbacks and then inject
        let callbacks = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(callbacks.count, 1)
        let cb = callbacks[0]
        XCTAssertTrue(cb is TestInjectableProtectInitCallback)

        // Use a real Workflow instance (Journey is a typealias to Workflow)
        let journey = Workflow(config: WorkflowConfig())
        let node = FakeContinueNode()

        await CallbackRegistry.shared.inject(continueNode: node, journey: journey)

        let injected = cb as! TestInjectableProtectInitCallback
        // Verify identity injection
        XCTAssertTrue(injected.journey === journey)
        XCTAssertTrue(injected.continueNode === node)
    }

    func testInjectForFidoAuthentication() async throws {
        await CallbackRegistry.shared.register(type: "MetadataCallback", callback: TestMetadataCallback.self)
        await CallbackRegistry.shared.register(type: "FidoAuthenticationCallback", callback: TestInjectableFidoAuthCallback.self)

        // Build metadata that triggers FIDO Authentication specialization
        let item = makeMetadataItem(
            typeKey: "MetadataCallback",
            data: [
                "_type": "WebAuthn",
                "allowCredentials": []
            ]
        )

        // Create callbacks and then inject
        let callbacks = await CallbackRegistry.shared.callback(from: [item])
        XCTAssertEqual(callbacks.count, 1)
        let cb = callbacks[0]
        XCTAssertTrue(cb is TestInjectableFidoAuthCallback)

        // Use a real Workflow instance (Journey is a typealias to Workflow)
        let journey = Workflow(config: WorkflowConfig())
        let node = FakeContinueNode()

        await CallbackRegistry.shared.inject(continueNode: node, journey: journey)

        let injected = cb as! TestInjectableFidoAuthCallback
        // Verify identity injection
        XCTAssertTrue(injected.journey === journey)
        XCTAssertTrue(injected.continueNode === node)
    }
}

// MARK: - Helpers

private func makeMetadataItem(typeKey: String, data: [String: Any]) -> [String: Any] {
    return [
        JourneyConstants.type: typeKey,
        JourneyConstants.output: [
            [
                JourneyConstants.name: JourneyConstants.data,
                JourneyConstants.value: data
            ]
        ],
        JourneyConstants.input: []
    ]
}
