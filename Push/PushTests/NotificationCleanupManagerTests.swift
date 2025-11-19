//
//  NotificationCleanupManagerTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class NotificationCleanupManagerTests: XCTestCase {

    private var storage: TestInMemoryPushStorage!

    override func setUp() async throws {
        try await super.setUp()
        storage = TestInMemoryPushStorage()
    }

    override func tearDown() async throws {
        storage = nil
        try await super.tearDown()
    }

    // MARK: - Part 1: Core Logic

    func testRunCleanupNoneModeReturnsZero() async throws {
        let manager = NotificationCleanupManager(
            storage: storage,
            config: .none(),
            logger: nil
        )

        try await populateNotifications([
            makeNotification(id: "n1"),
            makeNotification(id: "n2")
        ])

        let removed = try await manager.runCleanup()
        XCTAssertEqual(removed, 0)

        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 2)
    }

    func testRunCleanupCountBasedModeRemovesExcess() async throws {
        let manager = NotificationCleanupManager(
            storage: storage,
            config: .countBased(maxNotifications: 2),
            logger: nil
        )

        try await populateNotifications([
            makeNotification(id: "n1", daysAgo: 4),
            makeNotification(id: "n2", daysAgo: 3),
            makeNotification(id: "n3", daysAgo: 2),
            makeNotification(id: "n4", daysAgo: 1)
        ])

        let removed = try await manager.runCleanup()
        XCTAssertEqual(removed, 2)

        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.count, 2)
        let remainingIds = Set(remaining.map(\.id))
        XCTAssertTrue(remainingIds.isSuperset(of: ["n3", "n4"]))
    }

    func testRunCleanupAgeBasedModeRemovesOldNotifications() async throws {
        let manager = NotificationCleanupManager(
            storage: storage,
            config: .ageBased(maxAgeDays: 5),
            logger: nil
        )

        try await populateNotifications([
            makeNotification(id: "recent", daysAgo: 1),
            makeNotification(id: "old", daysAgo: 7)
        ])

        let removed = try await manager.runCleanup()
        XCTAssertEqual(removed, 1)

        let remaining = try await storage.getAllPushNotifications()
        XCTAssertEqual(remaining.map(\.id), ["recent"])
    }

    // MARK: - Part 2: Strategy Behaviour

    func testHybridCleanupAppliesCountAndAgeStrategies() async throws {
        let manager = NotificationCleanupManager(
            storage: storage,
            config: .hybrid(maxNotifications: 3, maxAgeDays: 5),
            logger: nil
        )

        try await populateNotifications([
            makeNotification(id: "oldest", daysAgo: 10),
            makeNotification(id: "older", daysAgo: 6),
            makeNotification(id: "threshold", daysAgo: 4),
            makeNotification(id: "recent", daysAgo: 1)
        ])

        let removed = try await manager.runCleanup()
        XCTAssertEqual(removed, 2, "Expected removal from both count and age strategies")

        let remaining = try await storage.getAllPushNotifications()
        let remainingIds = Set(remaining.map(\.id))
        XCTAssertEqual(remainingIds, ["threshold", "recent"])
    }

    func testCleanupRespectsCredentialFilter() async throws {
        let manager = NotificationCleanupManager(
            storage: storage,
            config: .countBased(maxNotifications: 1),
            logger: nil
        )

        try await populateNotifications([
            makeNotification(id: "cred1-old", credentialId: "cred-1", daysAgo: 3),
            makeNotification(id: "cred1-new", credentialId: "cred-1", daysAgo: 1),
            makeNotification(id: "cred2-old", credentialId: "cred-2", daysAgo: 2),
            makeNotification(id: "cred2-new", credentialId: "cred-2", daysAgo: 1)
        ])

        let removed = try await manager.runCleanup(credentialId: "cred-1")
        XCTAssertEqual(removed, 1, "Only credential-specific notifications should be pruned")

        let remainingCred1 = try await storage.getAllPushNotifications()
            .filter { $0.credentialId == "cred-1" }
        XCTAssertEqual(remainingCred1.map(\.id), ["cred1-new"])

        let remainingCred2 = try await storage.getAllPushNotifications()
            .filter { $0.credentialId == "cred-2" }
        XCTAssertEqual(Set(remainingCred2.map(\.id)), ["cred2-old", "cred2-new"])
    }

    // MARK: - Helpers

    private func populateNotifications(_ notifications: [PushNotification]) async throws {
        for notification in notifications {
            try await storage.storePushNotification(notification)
        }
    }

    private func makeNotification(
        id: String,
        credentialId: String = "credential-id",
        daysAgo: Int = 0
    ) -> PushNotification {
        PushNotification(
            id: id,
            credentialId: credentialId,
            ttl: 60,
            messageId: "message-\(id)",
            messageText: nil,
            customPayload: nil,
            challenge: nil,
            numbersChallenge: nil,
            loadBalancer: nil,
            contextInfo: nil,
            pushType: .default,
            createdAt: Date().addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60)
        )
    }
}
