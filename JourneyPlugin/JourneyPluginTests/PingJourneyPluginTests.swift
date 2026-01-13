//
//  PingJourneyPluginTests.swift
//  PingJourneyPluginTests
//
//  Created by george bafaloukas on 20/11/2025.
//

import XCTest
@testable import PingJourneyPlugin
import PingOrchestrate
import PingJourney

final class PingJourneyPluginTests: XCTestCase {

    // MARK: - Journey typealias tests

    func testJourneyIsTypealiasOfWorkflow() {
        // This line only compiles if Journey is a typealias of Workflow
        let _: Workflow.Type = Journey.self
        XCTAssertTrue(true)
    }

    func testJourneyConfigConformsToWorkflowConfig() {
        // Helper requiring WorkflowConfig conformance
        func acceptsWorkflowConfig(_ config: WorkflowConfig) -> Bool { true }

        let config = JourneyConfig()
        XCTAssertTrue(acceptsWorkflowConfig(config))
    }

    // MARK: - JourneyConfig default values

    func testJourneyConfigDefaults() {
        let config = JourneyConfig()

        // serverUrl is optional and should default to nil
        XCTAssertNil(config.serverUrl)

        // realm and cookie should default to JourneyConstants values
        XCTAssertEqual(config.realm, JourneyConstants.realm)
        XCTAssertEqual(config.cookie, JourneyConstants.cookie)
    }

    // MARK: - JourneyConfig mutation

    func testJourneyConfigPropertyMutation() {
        let config = JourneyConfig()

        // Mutate serverUrl
        config.serverUrl = "https://example.am.com/am"
        XCTAssertEqual(config.serverUrl, "https://example.am.com/am")

        // Mutate realm
        config.realm = "custom"
        XCTAssertEqual(config.realm, "custom")

        // Mutate cookie
        config.cookie = "iPlanetDirectoryPro"
        XCTAssertEqual(config.cookie, "iPlanetDirectoryPro")
    }

    // MARK: - Integration sanity check

    func testJourneyConfigCanInitializeWorkflow() {
        let config = JourneyConfig()
        config.serverUrl = "https://server.example.com/am"
        config.realm = "alpha"
        config.cookie = "sessionCookie"

        let workflow = Workflow(config: config)
        // Ensure the Workflow holds the same config instance
        XCTAssertTrue(workflow.config === config)
        // And that registration ran without adding modules by default
        XCTAssertTrue(workflow.config.modules.isEmpty)
    }
}
