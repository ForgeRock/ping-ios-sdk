//
//  OathCodeInfoTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath

final class OathCodeInfoTests: XCTestCase {

    // MARK: - Test Data

    private let testCode = "123456"
    private let testTimeRemaining = 25
    private let testTotalPeriod = 30
    private let testCounter = 42

    // MARK: - TOTP Factory Method Tests

    func testForTotpCreation() {
        let codeInfo = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        XCTAssertEqual(codeInfo.code, testCode)
        XCTAssertEqual(codeInfo.timeRemaining, testTimeRemaining)
        XCTAssertEqual(codeInfo.totalPeriod, testTotalPeriod)
        XCTAssertEqual(codeInfo.counter, -1)

        // Test progress calculation: 1.0 - (25/30) = 1.0 - 0.8333... ≈ 0.1667
        let expectedProgress = 1.0 - (Double(testTimeRemaining) / Double(testTotalPeriod))
        XCTAssertEqual(codeInfo.progress, expectedProgress, accuracy: 0.0001)
    }

    func testForTotpProgressCalculation() {
        // Test beginning of period (full time remaining)
        let beginningCode = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 30,
            totalPeriod: 30
        )
        XCTAssertEqual(beginningCode.progress, 0.0, accuracy: 0.0001)

        // Test middle of period
        let middleCode = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 15,
            totalPeriod: 30
        )
        XCTAssertEqual(middleCode.progress, 0.5, accuracy: 0.0001)

        // Test end of period (no time remaining)
        let endCode = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 0,
            totalPeriod: 30
        )
        XCTAssertEqual(endCode.progress, 1.0, accuracy: 0.0001)
    }

    func testForTotpZeroPeriod() {
        let codeInfo = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 10,
            totalPeriod: 0
        )

        XCTAssertEqual(codeInfo.code, testCode)
        XCTAssertEqual(codeInfo.timeRemaining, 10)
        XCTAssertEqual(codeInfo.totalPeriod, 0)
        XCTAssertEqual(codeInfo.counter, -1)
        XCTAssertEqual(codeInfo.progress, 0.0)
    }

    func testForTotpEdgeCases() {
        // Test with very small period
        let smallPeriod = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 1,
            totalPeriod: 1
        )
        XCTAssertEqual(smallPeriod.progress, 0.0, accuracy: 0.0001)

        // Test with large period
        let largePeriod = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 150,
            totalPeriod: 300
        )
        XCTAssertEqual(largePeriod.progress, 0.5, accuracy: 0.0001)

        // Test with time remaining greater than period (edge case)
        let overTime = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: 40,
            totalPeriod: 30
        )
        // Progress should be negative in this case
        let expectedProgress = 1.0 - (40.0 / 30.0)
        XCTAssertEqual(overTime.progress, expectedProgress, accuracy: 0.0001)
    }

    // MARK: - HOTP Factory Method Tests

    func testForHotpCreation() {
        let codeInfo = OathCodeInfo.forHotp(
            code: testCode,
            counter: testCounter
        )

        XCTAssertEqual(codeInfo.code, testCode)
        XCTAssertEqual(codeInfo.counter, testCounter)
        XCTAssertEqual(codeInfo.timeRemaining, -1)
        XCTAssertEqual(codeInfo.totalPeriod, 0)
        XCTAssertEqual(codeInfo.progress, 0.0)
    }

    func testForHotpWithZeroCounter() {
        let codeInfo = OathCodeInfo.forHotp(
            code: testCode,
            counter: 0
        )

        XCTAssertEqual(codeInfo.code, testCode)
        XCTAssertEqual(codeInfo.counter, 0)
        XCTAssertEqual(codeInfo.timeRemaining, -1)
        XCTAssertEqual(codeInfo.totalPeriod, 0)
        XCTAssertEqual(codeInfo.progress, 0.0)
    }

    func testForHotpWithLargeCounter() {
        let largeCounter = 999999
        let codeInfo = OathCodeInfo.forHotp(
            code: testCode,
            counter: largeCounter
        )

        XCTAssertEqual(codeInfo.code, testCode)
        XCTAssertEqual(codeInfo.counter, largeCounter)
        XCTAssertEqual(codeInfo.timeRemaining, -1)
        XCTAssertEqual(codeInfo.totalPeriod, 0)
        XCTAssertEqual(codeInfo.progress, 0.0)
    }

    // MARK: - JSON Serialization Tests

    func testTotpJsonSerialization() throws {
        let originalCodeInfo = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        // Serialize to JSON
        let jsonString = try originalCodeInfo.toJson()
        XCTAssertFalse(jsonString.isEmpty)

        // Deserialize from JSON
        let deserializedCodeInfo = try OathCodeInfo.fromJson(jsonString)

        // Verify all properties match
        XCTAssertEqual(deserializedCodeInfo.code, originalCodeInfo.code)
        XCTAssertEqual(deserializedCodeInfo.timeRemaining, originalCodeInfo.timeRemaining)
        XCTAssertEqual(deserializedCodeInfo.totalPeriod, originalCodeInfo.totalPeriod)
        XCTAssertEqual(deserializedCodeInfo.counter, originalCodeInfo.counter)
        XCTAssertEqual(deserializedCodeInfo.progress, originalCodeInfo.progress, accuracy: 0.0001)
    }

    func testHotpJsonSerialization() throws {
        let originalCodeInfo = OathCodeInfo.forHotp(
            code: testCode,
            counter: testCounter
        )

        // Serialize to JSON
        let jsonString = try originalCodeInfo.toJson()
        XCTAssertFalse(jsonString.isEmpty)

        // Deserialize from JSON
        let deserializedCodeInfo = try OathCodeInfo.fromJson(jsonString)

        // Verify all properties match
        XCTAssertEqual(deserializedCodeInfo.code, originalCodeInfo.code)
        XCTAssertEqual(deserializedCodeInfo.counter, originalCodeInfo.counter)
        XCTAssertEqual(deserializedCodeInfo.timeRemaining, originalCodeInfo.timeRemaining)
        XCTAssertEqual(deserializedCodeInfo.totalPeriod, originalCodeInfo.totalPeriod)
        XCTAssertEqual(deserializedCodeInfo.progress, originalCodeInfo.progress, accuracy: 0.0001)
    }

    func testJsonSerializationWithSpecialCharacters() throws {
        let specialCode = "abc!@#"
        let codeInfo = OathCodeInfo.forTotp(
            code: specialCode,
            timeRemaining: 15,
            totalPeriod: 30
        )

        let jsonString = try codeInfo.toJson()
        let deserializedCodeInfo = try OathCodeInfo.fromJson(jsonString)

        XCTAssertEqual(deserializedCodeInfo.code, specialCode)
    }

    func testJsonSerializationWithEmptyCode() throws {
        let emptyCode = ""
        let codeInfo = OathCodeInfo.forHotp(
            code: emptyCode,
            counter: 5
        )

        let jsonString = try codeInfo.toJson()
        let deserializedCodeInfo = try OathCodeInfo.fromJson(jsonString)

        XCTAssertEqual(deserializedCodeInfo.code, emptyCode)
    }

    func testFromJsonWithInvalidString() {
        let invalidJson = "invalid json string"

        XCTAssertThrowsError(try OathCodeInfo.fromJson(invalidJson)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testFromJsonWithInvalidUTF8() {
        // Create a string that will fail UTF-8 encoding
        let invalidString = String(bytes: [0xFF, 0xFE], encoding: .utf8) ?? ""

        XCTAssertThrowsError(try OathCodeInfo.fromJson(invalidString)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testFromJsonWithMissingFields() {
        let incompleteJson = "{\"code\":\"123456\"}"

        XCTAssertThrowsError(try OathCodeInfo.fromJson(incompleteJson)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Codable Tests

    func testDirectCodableImplementation() throws {
        let originalCodeInfo = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        // Test direct encoding/decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalCodeInfo)

        let decoder = JSONDecoder()
        let decodedCodeInfo = try decoder.decode(OathCodeInfo.self, from: data)

        XCTAssertEqual(decodedCodeInfo.code, originalCodeInfo.code)
        XCTAssertEqual(decodedCodeInfo.timeRemaining, originalCodeInfo.timeRemaining)
        XCTAssertEqual(decodedCodeInfo.totalPeriod, originalCodeInfo.totalPeriod)
        XCTAssertEqual(decodedCodeInfo.counter, originalCodeInfo.counter)
        XCTAssertEqual(decodedCodeInfo.progress, originalCodeInfo.progress, accuracy: 0.0001)
    }

    // MARK: - Equality and Comparison Tests

    func testCodeInfoEquality() throws {
        let codeInfo1 = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        let codeInfo2 = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        // Since OathCodeInfo is a struct, they should be equal if all properties match
        XCTAssertEqual(codeInfo1.code, codeInfo2.code)
        XCTAssertEqual(codeInfo1.timeRemaining, codeInfo2.timeRemaining)
        XCTAssertEqual(codeInfo1.totalPeriod, codeInfo2.totalPeriod)
        XCTAssertEqual(codeInfo1.counter, codeInfo2.counter)
        XCTAssertEqual(codeInfo1.progress, codeInfo2.progress, accuracy: 0.0001)
    }

    func testCodeInfoDifferences() {
        let totpCodeInfo = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        let hotpCodeInfo = OathCodeInfo.forHotp(
            code: testCode,
            counter: testCounter
        )

        // They should be different due to different factory methods
        XCTAssertEqual(totpCodeInfo.code, hotpCodeInfo.code)
        XCTAssertNotEqual(totpCodeInfo.timeRemaining, hotpCodeInfo.timeRemaining)
        XCTAssertNotEqual(totpCodeInfo.totalPeriod, hotpCodeInfo.totalPeriod)
        XCTAssertNotEqual(totpCodeInfo.counter, hotpCodeInfo.counter)
        XCTAssertNotEqual(totpCodeInfo.progress, hotpCodeInfo.progress)
    }

    // MARK: - Property Validation Tests

    func testTotpPropertiesValid() {
        let codeInfo = OathCodeInfo.forTotp(
            code: testCode,
            timeRemaining: testTimeRemaining,
            totalPeriod: testTotalPeriod
        )

        // TOTP should have valid time properties and invalid counter
        XCTAssertGreaterThanOrEqual(codeInfo.timeRemaining, 0)
        XCTAssertGreaterThan(codeInfo.totalPeriod, 0)
        XCTAssertGreaterThanOrEqual(codeInfo.progress, 0.0)
        XCTAssertLessThanOrEqual(codeInfo.progress, 1.0)
        XCTAssertEqual(codeInfo.counter, -1)
    }

    func testHotpPropertiesValid() {
        let codeInfo = OathCodeInfo.forHotp(
            code: testCode,
            counter: testCounter
        )

        // HOTP should have valid counter and invalid time properties
        XCTAssertGreaterThanOrEqual(codeInfo.counter, 0)
        XCTAssertEqual(codeInfo.timeRemaining, -1)
        XCTAssertEqual(codeInfo.totalPeriod, 0)
        XCTAssertEqual(codeInfo.progress, 0.0)
    }
}