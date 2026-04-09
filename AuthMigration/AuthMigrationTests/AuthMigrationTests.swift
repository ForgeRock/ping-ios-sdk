//
//  AuthMigrationTests.swift
//  AuthMigrationTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingCommons
@testable import PingOath
@testable import PingPush
@testable import PingAuthMigration

final class AuthMigrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Reset migration state so each test runs fresh
        await AuthMigration.resetMigrationState()
        // Clean up any legacy Keychain data from previous tests
        TestKeychainHelper.cleanupLegacyKeychain()
    }

    override func tearDown() async throws {
        TestKeychainHelper.cleanupLegacyKeychain()
        await AuthMigration.resetMigrationState()
        try await super.tearDown()
    }

    // MARK: - testStart_noLegacyData_emitsError

    func testStart_noLegacyData_emitsError() async throws {
        var events: [MigrationProgress] = []
        let stream = AuthMigration.start()
        for await progress in stream {
            events.append(progress)
        }

        XCTAssertEqual(events.count, 3)
        if case .started = events[0] { /* ok */ } else { XCTFail("Expected .started at [0]") }
        if case .inProgress(let step, let current, let total) = events[1] {
            XCTAssertEqual(step.description, MigrationStep.importLegacyData.description)
            XCTAssertEqual(current, 1)
            XCTAssertEqual(total, 3)
        } else {
            XCTFail("Expected .inProgress(.importLegacyData) at [1]")
        }
        if case .error(let step, let error) = events[2] {
            XCTAssertEqual(step.description, MigrationStep.importLegacyData.description)
            let migErr = error as? AuthMigrationError
            if case .noLegacyDataFound = migErr { /* ok */ } else {
                XCTFail("Expected .noLegacyDataFound error")
            }
        } else {
            XCTFail("Expected .error at [2]")
        }
    }

    // MARK: - testStart_migratesOathCredentials

    func testStart_migratesOathCredentials() async throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyAccount(
            issuer: "Acme", accountName: "alice@example.com",
            displayIssuer: "Acme Corp", displayAccountName: "Alice",
            imageUrl: "https://example.com/logo.png", backgroundColor: "#FF0000",
            timeAdded: 1_234_567,
            policies: #"{"biometric":true}"#, lockingPolicy: "biometricOnly", lock: true
        )
        try TestKeychainHelper.writeLegacyTOTPMechanism(
            mechanismUUID: uuid, issuer: "Acme", accountName: "alice@example.com",
            secret: "JBSWY3DPEHPK3PXP", algorithm: "sha256", digits: 8, period: 60
        )

        let oathStorage = MockOathStorage()
        let pushStorage = MockPushStorage()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.pushStorage = pushStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream {}

        let credentials = await oathStorage.getAllCredentials()
        XCTAssertEqual(credentials.count, 1)
        let cred = credentials[0]

        // Credential identity
        XCTAssertEqual(cred.id, uuid)
        XCTAssertEqual(cred.issuer, "Acme")
        XCTAssertEqual(cred.accountName, "alice@example.com")

        // OATH fields
        XCTAssertEqual(cred.oathType, .totp)
        XCTAssertEqual(cred.oathAlgorithm, .sha256)
        XCTAssertEqual(cred.digits, 8)
        XCTAssertEqual(cred.period, 60)
        XCTAssertEqual(cred.counter, 0)
        XCTAssertEqual(cred.secretKey, "JBSWY3DPEHPK3PXP")

        // Display names
        XCTAssertEqual(cred.displayIssuer, "Acme Corp")
        XCTAssertEqual(cred.displayAccountName, "Alice")

        // Visual fields
        XCTAssertEqual(cred.imageURL, "https://example.com/logo.png")
        XCTAssertEqual(cred.backgroundColor, "#FF0000")

        // Policies & locking
        XCTAssertEqual(cred.policies, #"{"biometric":true}"#)
        XCTAssertEqual(cred.lockingPolicy, "biometricOnly")
        XCTAssertTrue(cred.isLocked)

        // Timestamp
        XCTAssertEqual(cred.createdAt.timeIntervalSince1970, 1_234_567, accuracy: 0.001)

        // Push storage must remain empty
        let pushCreds = await pushStorage.getAllCredentials()
        XCTAssertEqual(pushCreds.count, 0)
    }

    // MARK: - testStart_migratesPushCredentials

    func testStart_migratesPushCredentials() async throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyAccount(
            issuer: "PingCo", accountName: "bob@example.com",
            displayIssuer: "Ping Company", displayAccountName: "Bob",
            backgroundColor: "#0000FF",
            policies: #"{"biometric":true}"#, lockingPolicy: "biometricOnly", lock: true
        )
        try TestKeychainHelper.writeLegacyPushMechanism(
            mechanismUUID: uuid, issuer: "PingCo", accountName: "bob@example.com",
            secret: "PUSHSECRET123",
            authEndpoint: "https://am.example.com/json/push/sns/message?_action=authenticate"
        )

        let oathStorage = MockOathStorage()
        let pushStorage = MockPushStorage()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.pushStorage = pushStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream {}

        let credentials = await pushStorage.getAllCredentials()
        XCTAssertEqual(credentials.count, 1)
        let cred = credentials[0]

        // Credential identity
        XCTAssertEqual(cred.id, uuid)
        XCTAssertEqual(cred.issuer, "PingCo")
        XCTAssertEqual(cred.accountName, "bob@example.com")

        // Display names
        XCTAssertEqual(cred.displayIssuer, "Ping Company")
        XCTAssertEqual(cred.displayAccountName, "Bob")

        // Push-specific fields
        XCTAssertEqual(cred.serverEndpoint, "https://am.example.com/json/push/sns/message")
        XCTAssertFalse(cred.sharedSecret.isEmpty)
        XCTAssertEqual(cred.platform, .pingAM)

        // Visual fields
        XCTAssertNil(cred.imageURL) // no image was set in the account
        XCTAssertEqual(cred.backgroundColor, "#0000FF")

        // Policies & locking
        XCTAssertEqual(cred.policies, #"{"biometric":true}"#)
        XCTAssertEqual(cred.lockingPolicy, "biometricOnly")
        XCTAssertTrue(cred.isLocked)

        // Timestamp
        XCTAssertTrue(cred.createdAt.timeIntervalSince1970 > 0)

        // OATH storage must remain empty
        let oathCreds = await oathStorage.getAllCredentials()
        XCTAssertEqual(oathCreds.count, 0)
    }

    // MARK: - testStart_migratesMixedCredentials

    func testStart_migratesMixedCredentials() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "OATH Corp", accountName: "user1@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "OATH Corp", accountName: "user1@example.com")
        try TestKeychainHelper.writeLegacyAccount(issuer: "Push Corp", accountName: "user2@example.com")
        try TestKeychainHelper.writeLegacyPushMechanism(issuer: "Push Corp", accountName: "user2@example.com")

        let oathStorage = MockOathStorage()
        let pushStorage = MockPushStorage()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.pushStorage = pushStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream {}

        let oathCreds = await oathStorage.getAllCredentials()
        let pushCreds = await pushStorage.getAllCredentials()
        XCTAssertEqual(oathCreds.count, 1)
        XCTAssertEqual(pushCreds.count, 1)
    }

    // MARK: - testStart_emitsCorrectProgressSequence

    func testStart_emitsCorrectProgressSequence() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "user@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "user@example.com")

        let oathStorage = MockOathStorage()
        var events: [MigrationProgress] = []
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = true
        }
        for await progress in stream {
            events.append(progress)
        }

        // Expected: started, inProgress(import), stepCompleted(import),
        //           inProgress(migrate), stepCompleted(migrate),
        //           inProgress(cleanup), stepCompleted(cleanup), success
        XCTAssertEqual(events.count, 8)
        if case .started = events[0] { /* ok */ } else { XCTFail("events[0] should be .started") }
        if case .inProgress(let step, _, _) = events[1] {
            XCTAssertEqual(step.description, MigrationStep.importLegacyData.description)
        } else { XCTFail("events[1] should be .inProgress(.importLegacyData)") }
        if case .stepCompleted(let step) = events[2] {
            XCTAssertEqual(step.description, MigrationStep.importLegacyData.description)
        } else { XCTFail("events[2] should be .stepCompleted(.importLegacyData)") }
        if case .inProgress(let step, _, _) = events[3] {
            XCTAssertEqual(step.description, MigrationStep.migrateCredentials.description)
        } else { XCTFail("events[3] should be .inProgress(.migrateCredentials)") }
        if case .stepCompleted(let step) = events[4] {
            XCTAssertEqual(step.description, MigrationStep.migrateCredentials.description)
        } else { XCTFail("events[4] should be .stepCompleted(.migrateCredentials)") }
        if case .inProgress(let step, _, _) = events[5] {
            XCTAssertEqual(step.description, MigrationStep.cleanup.description)
        } else { XCTFail("events[5] should be .inProgress(.cleanup)") }
        if case .stepCompleted(let step) = events[6] {
            XCTAssertEqual(step.description, MigrationStep.cleanup.description)
        } else { XCTFail("events[6] should be .stepCompleted(.cleanup)") }
        if case .success(let message) = events[7] {
            XCTAssertTrue(message.contains("OATH") || message.contains("Push"))
        } else { XCTFail("events[7] should be .success") }
    }

    // MARK: - testStart_idempotent_skipsDuplicates

    func testStart_idempotent_skipsDuplicates() async throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "dup@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(
            mechanismUUID: uuid, issuer: "Acme", accountName: "dup@example.com"
        )

        let oathStorage = MockOathStorage()

        // First migration
        let stream1 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream1 {}

        let after1 = await oathStorage.getAllCredentials()
        XCTAssertEqual(after1.count, 1)

        // Reset state so we can run again
        await AuthMigration.resetMigrationState()

        // Second migration — same data still in Keychain, same credential in storage
        let stream2 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream2 {}

        // Should still be only 1 credential (duplicate skipped)
        let after2 = await oathStorage.getAllCredentials()
        XCTAssertEqual(after2.count, 1)
    }

    // MARK: - testStart_cleanupEnabled_deletesLegacyData

    func testStart_cleanupEnabled_deletesLegacyData() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "cleanup@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "cleanup@example.com")

        // Verify data exists before migration
        let existsBefore = await AuthMigration.isMigrationNeeded()
        XCTAssertTrue(existsBefore)

        let oathStorage = MockOathStorage()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = true
        }
        for await _ in stream {}

        // Verify legacy data is gone
        let existsAfter = await AuthMigration.isMigrationNeeded()
        XCTAssertFalse(existsAfter)
    }

    // MARK: - testStart_cleanupDisabled_preservesLegacyData

    func testStart_cleanupDisabled_preservesLegacyData() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "keep@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "keep@example.com")

        let oathStorage = MockOathStorage()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream {}

        // Legacy data should still exist
        let existsAfter = await AuthMigration.isMigrationNeeded()
        XCTAssertTrue(existsAfter)
    }

    // MARK: - testStart_onlyRunsOnce

    func testStart_onlyRunsOnce() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "once@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "once@example.com")

        let oathStorage = MockOathStorage()

        // First run
        let stream1 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream1 {}

        let after1 = await oathStorage.getAllCredentials()
        XCTAssertEqual(after1.count, 1)

        // Second run without resetting state — should be a no-op
        let stream2 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        // Collect stream2 — it may emit nothing (if state manager skips it immediately)
        for await _ in stream2 {}

        // Credential count should still be 1 (not 2)
        let after2 = await oathStorage.getAllCredentials()
        XCTAssertEqual(after2.count, 1)
    }

    // MARK: - testMigrateIfNeeded_returnsTrue_whenDataExists

    func testMigrateIfNeeded_returnsTrue_whenDataExists() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "migrate@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "migrate@example.com")

        let oathStorage = MockOathStorage()
        let didMigrate = await AuthMigration.migrateIfNeeded { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = true
        }

        XCTAssertTrue(didMigrate)
    }

    // MARK: - testMigrateIfNeeded_returnsFalse_whenNoData

    func testMigrateIfNeeded_returnsFalse_whenNoData() async {
        let didMigrate = await AuthMigration.migrateIfNeeded()
        XCTAssertFalse(didMigrate)
    }

    // MARK: - testIsMigrationNeeded_returnsTrue

    func testIsMigrationNeeded_returnsTrue() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "check@example.com")
        let needed = await AuthMigration.isMigrationNeeded()
        XCTAssertTrue(needed)
    }

    // MARK: - testIsMigrationNeeded_returnsFalse

    func testIsMigrationNeeded_returnsFalse() async {
        let needed = await AuthMigration.isMigrationNeeded()
        XCTAssertFalse(needed)
    }

    // MARK: - testResetMigrationState_allowsRerun

    func testResetMigrationState_allowsRerun() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "reset@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "reset@example.com")

        let oathStorage = MockOathStorage()

        // First run
        let stream1 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream1 {}

        let count1 = await oathStorage.getAllCredentials().count
        XCTAssertEqual(count1, 1)

        // Reset + clear storage + run again
        await AuthMigration.resetMigrationState()
        try await oathStorage.clearOathCredentials()

        let stream2 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream2 {}

        let count2 = await oathStorage.getAllCredentials().count
        XCTAssertEqual(count2, 1)
    }

    // MARK: - testStart_withCustomStorage

    func testStart_withCustomStorage() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Custom", accountName: "storage@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Custom", accountName: "storage@example.com")
        try TestKeychainHelper.writeLegacyAccount(issuer: "Custom", accountName: "push@example.com")
        try TestKeychainHelper.writeLegacyPushMechanism(issuer: "Custom", accountName: "push@example.com")

        let customOath = MockOathStorage()
        let customPush = MockPushStorage()

        let stream = AuthMigration.start { config in
            config.oathStorage = customOath
            config.pushStorage = customPush
            config.cleanupLegacyData = false
        }
        for await _ in stream {}

        let oathCreds = await customOath.getAllCredentials()
        let pushCreds = await customPush.getAllCredentials()
        XCTAssertEqual(oathCreds.count, 1)
        XCTAssertEqual(pushCreds.count, 1)
        XCTAssertEqual(oathCreds[0].issuer, "Custom")
        XCTAssertEqual(pushCreds[0].issuer, "Custom")
    }

    // MARK: - testStart_HOTPMigration

    func testStart_HOTPMigration() async throws {
        let uuid = UUID().uuidString
        try TestKeychainHelper.writeLegacyAccount(
            issuer: "HOTP Inc", accountName: "hotp@example.com",
            displayIssuer: "HOTP Display", displayAccountName: "HOTP User",
            imageUrl: "https://example.com/hotp.png", backgroundColor: "#00FF00",
            timeAdded: 2_000_000,
            policies: #"{"deviceTampering":{"score":0.8}}"#, lockingPolicy: "deviceTampering", lock: true
        )
        try TestKeychainHelper.writeLegacyHOTPMechanism(
            mechanismUUID: uuid, issuer: "HOTP Inc", accountName: "hotp@example.com",
            secret: "HOTPSECRET", counter: 5
        )

        let oathStorage = MockOathStorage()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await _ in stream {}

        let credentials = await oathStorage.getAllCredentials()
        XCTAssertEqual(credentials.count, 1)
        let cred = credentials[0]

        // Credential identity
        XCTAssertEqual(cred.id, uuid)
        XCTAssertEqual(cred.issuer, "HOTP Inc")
        XCTAssertEqual(cred.accountName, "hotp@example.com")

        // OATH fields
        XCTAssertEqual(cred.oathType, .hotp)
        XCTAssertEqual(cred.counter, 5)
        XCTAssertEqual(cred.oathAlgorithm, .sha1) // default when not specified
        XCTAssertEqual(cred.digits, 6) // default
        XCTAssertEqual(cred.period, 0) // HOTP has no period
        XCTAssertEqual(cred.secretKey, "HOTPSECRET")

        // Display names
        XCTAssertEqual(cred.displayIssuer, "HOTP Display")
        XCTAssertEqual(cred.displayAccountName, "HOTP User")

        // Visual fields
        XCTAssertEqual(cred.imageURL, "https://example.com/hotp.png")
        XCTAssertEqual(cred.backgroundColor, "#00FF00")

        // Policies & locking
        XCTAssertEqual(cred.policies, #"{"deviceTampering":{"score":0.8}}"#)
        XCTAssertEqual(cred.lockingPolicy, "deviceTampering")
        XCTAssertTrue(cred.isLocked)

        // Timestamp
        XCTAssertEqual(cred.createdAt.timeIntervalSince1970, 2_000_000, accuracy: 0.001)
    }

    // MARK: - testStart_performanceWith20Mechanisms

    func testStart_performanceWith20Mechanisms() async throws {
        let total = 20

        // Create 20 legacy mechanisms — alternating TOTP / HOTP with unique accounts
        for i in 0..<total {
            let accountName = "perf-\(i)@example.com"
            try TestKeychainHelper.writeLegacyAccount(issuer: "PerfIssuer", accountName: accountName)
            if i % 2 == 0 {
                try TestKeychainHelper.writeLegacyTOTPMechanism(
                    issuer: "PerfIssuer", accountName: accountName,
                    secret: "JBSWY3DPEHPK3PXP", algorithm: "sha1", digits: 6, period: 30
                )
            } else {
                try TestKeychainHelper.writeLegacyHOTPMechanism(
                    issuer: "PerfIssuer", accountName: accountName,
                    secret: "JBSWY3DPEHPK3PXP", counter: i
                )
            }
        }

        let oathStorage = MockOathStorage()

        // Measure migration wall-clock time
        let startTime = CFAbsoluteTimeGetCurrent()
        let stream = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = true
        }
        for await _ in stream {}
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Must complete within 10 seconds
        XCTAssertLessThan(elapsed, 10.0, "Migration of \(total) mechanisms took \(elapsed)s — expected < 10s")

        // Verify all credentials migrated with correct type distribution
        let credentials = await oathStorage.getAllCredentials()
        XCTAssertEqual(credentials.count, total)

        let totpCount = credentials.filter { $0.oathType == .totp }.count
        let hotpCount = credentials.filter { $0.oathType == .hotp }.count
        XCTAssertEqual(totpCount, total / 2)
        XCTAssertEqual(hotpCount, total / 2)

        // Legacy data must be cleaned up
        let existsAfter = await AuthMigration.isMigrationNeeded()
        XCTAssertFalse(existsAfter)
    }

    // MARK: - testStart_retryAllowedAfterFailure

    func testStart_retryAllowedAfterFailure() async throws {
        // Write an account with no mechanisms — pipeline will fail at "no mechanisms found"
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "retry@example.com")

        let oathStorage = MockOathStorage()

        // First run — should fail (accounts exist but no mechanisms)
        var firstEvents: [MigrationProgress] = []
        let stream1 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await progress in stream1 {
            firstEvents.append(progress)
        }

        // Verify it failed
        let firstRunFailed = firstEvents.contains { progress in
            if case .error = progress { return true }
            return false
        }
        XCTAssertTrue(firstRunFailed, "First run should fail with no mechanisms")

        // Now add a mechanism so the second run can succeed
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "retry@example.com")

        // Second run — should be allowed (hasRun is false after failure) and succeed
        var secondEvents: [MigrationProgress] = []
        let stream2 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = false
        }
        for await progress in stream2 {
            secondEvents.append(progress)
        }

        let secondRunSucceeded = secondEvents.contains { progress in
            if case .success = progress { return true }
            return false
        }
        XCTAssertTrue(secondRunSucceeded, "Retry after failure should be allowed and succeed")

        // Verify the credential was actually migrated
        let credentials = await oathStorage.getAllCredentials()
        XCTAssertEqual(credentials.count, 1)
    }

    // MARK: - testStart_secondRunIsNoOp_afterCleanup

    func testStart_secondRunIsNoOp_afterCleanup() async throws {
        try TestKeychainHelper.writeLegacyAccount(issuer: "Acme", accountName: "noop@example.com")
        try TestKeychainHelper.writeLegacyTOTPMechanism(issuer: "Acme", accountName: "noop@example.com")

        let oathStorage = MockOathStorage()

        // First run — real migration with cleanup
        var firstEvents: [MigrationProgress] = []
        let stream1 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = true
        }
        for await progress in stream1 {
            firstEvents.append(progress)
        }
        if case .success = firstEvents.last { /* ok */ } else {
            XCTFail("First migration should succeed")
        }

        let countAfterFirst = await oathStorage.getAllCredentials().count
        XCTAssertEqual(countAfterFirst, 1)

        // Reset state so the guard doesn't skip the second run entirely
        await AuthMigration.resetMigrationState()

        // Second run — legacy data was cleaned up, should abort at step 1
        var secondEvents: [MigrationProgress] = []
        let stream2 = AuthMigration.start { config in
            config.oathStorage = oathStorage
            config.cleanupLegacyData = true
        }
        for await progress in stream2 {
            secondEvents.append(progress)
        }

        // Second run should emit an error (no legacy data found) — not insert duplicates
        let hasError = secondEvents.contains { progress in
            if case .error = progress { return true }
            return false
        }
        XCTAssertTrue(hasError, "Second run should detect no legacy data")

        // Credential count must be unchanged — no duplicates
        let countAfterSecond = await oathStorage.getAllCredentials().count
        XCTAssertEqual(countAfterSecond, countAfterFirst, "No duplicates should be inserted on second run")
    }
}
