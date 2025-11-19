//
//  PushDeviceTokenManagerTests.swift
//  PushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushDeviceTokenManagerTests: XCTestCase {

    private var storage: TestInMemoryPushStorage!
    private var manager: PushDeviceTokenManager!

    override func setUp() async throws {
        try await super.setUp()
        storage = TestInMemoryPushStorage()
        manager = PushDeviceTokenManager(storage: storage, logger: nil)
    }

    override func tearDown() async throws {
        storage = nil
        manager = nil
        try await super.tearDown()
    }

    func testStoreDeviceTokenPersistsToken() async throws {
        try await manager.storeDeviceToken("  token-123  ")

        let stored = try await storage.getCurrentPushDeviceToken()
        XCTAssertEqual(stored?.token, "token-123")
        XCTAssertNotNil(stored?.id)
    }

    func testGetDeviceTokenIdReturnsStoredToken() async throws {
        try await manager.storeDeviceToken("token-456")

        let retrieved = try await manager.getDeviceTokenId()
        XCTAssertEqual(retrieved, "token-456")
    }

    func testGetDeviceTokenIdReturnsNilWhenNoToken() async throws {
        let retrieved = try await manager.getDeviceTokenId()
        XCTAssertNil(retrieved)
    }

    func testHasTokenChangedReturnsTrueWhenNoStoredToken() async throws {
        let hasChanged = try await manager.hasTokenChanged("token-789")
        XCTAssertTrue(hasChanged)
    }

    func testHasTokenChangedDetectsDifference() async throws {
        try await manager.storeDeviceToken("token-abc")

        let hasChanged = try await manager.hasTokenChanged("token-def")
        XCTAssertTrue(hasChanged)
    }

    func testHasTokenChangedDetectsSameToken() async throws {
        try await manager.storeDeviceToken("token-same")

        let hasChanged = try await manager.hasTokenChanged("token-same")
        XCTAssertFalse(hasChanged)
    }

    func testStoreDeviceTokenRejectsEmptyToken() async {
        do {
            try await manager.storeDeviceToken("   ")
            XCTFail("Expected error not thrown")
        } catch let error as PushError {
            guard case .invalidParameterValue(let message) = error else {
                return XCTFail("Unexpected PushError case: \(error)")
            }
            XCTAssertTrue(message.contains("Device token cannot be empty"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testHasTokenChangedRejectsEmptyToken() async {
        do {
            _ = try await manager.hasTokenChanged(" ")
            XCTFail("Expected error not thrown")
        } catch let error as PushError {
            guard case .invalidParameterValue(let message) = error else {
                return XCTFail("Unexpected PushError case: \(error)")
            }
            XCTAssertTrue(message.contains("Device token cannot be empty"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
