// 
//  NoEncryptorTests.swift
//  Storage
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingStorage

final class NoEncryptorTests: XCTestCase {
    
    var noEncryptor: NoEncryptor!
    
    override func setUp() {
        super.setUp()
        noEncryptor = NoEncryptor()
    }
    
    override func tearDown() {
        noEncryptor = nil
        super.tearDown()
    }
    
    func testEncryptReturnsOriginalData() async throws {
        let originalData = "Test data to encrypt".data(using: .utf8)!
        let encryptedData = try await noEncryptor.encrypt(data: originalData)
        XCTAssertEqual(encryptedData, originalData)
    }
    
    func testDecryptReturnsOriginalData() async throws {
        let originalData = "Test data to decrypt".data(using: .utf8)!
        let decryptedData = try await noEncryptor.decrypt(data: originalData)
        XCTAssertEqual(decryptedData, originalData)
    }
    
    func testEncryptAndDecryptRoundTrip() async throws {
        let originalData = "Round trip test data".data(using: .utf8)!
        let encryptedData = try await noEncryptor.encrypt(data: originalData)
        let decryptedData = try await noEncryptor.decrypt(data: encryptedData)
        XCTAssertEqual(decryptedData, originalData)
    }
}
