// 
//  PasswordPolicyTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import XCTest
@testable import PingDavinci

final class PasswordPolicyTests: XCTestCase {
   
   func testConvertsJsonStringToPasswordPolicy() throws {
       let jsonString = """
           {
               "name": "Test Policy",
               "description": "A test password policy",
               "excludesProfileData": true,
               "notSimilarToCurrent": true,
               "excludesCommonlyUsed": true,
               "maxAgeDays": 90,
               "minAgeDays": 1,
               "maxRepeatedCharacters": 2,
               "minUniqueCharacters": 3,
               "history": {
                   "count": 5,
                   "retentionDays": 365
               },
               "lockout": {
                   "failureCount": 3,
                   "durationSeconds": 600
               },
               "length": {
                   "min": 8,
                   "max": 20
               },
               "minCharacters": {
                   "digits": 1,
                   "special": 1
               },
               "populationCount": 1000,
               "createdAt": "2024-01-01T00:00:00Z",
               "updatedAt": "2024-01-02T00:00:00Z",
               "default": true
           }
       """
       
       let jsonData = jsonString.data(using: .utf8)!
       let policy = try JSONDecoder().decode(PasswordPolicy.self, from: jsonData)
       
       XCTAssertEqual(policy.name, "Test Policy")
       XCTAssertEqual(policy.description, "A test password policy")
       XCTAssertEqual(policy.excludesProfileData, true)
       XCTAssertEqual(policy.notSimilarToCurrent, true)
       XCTAssertEqual(policy.excludesCommonlyUsed, true)
       XCTAssertEqual(policy.maxAgeDays, 90)
       XCTAssertEqual(policy.minAgeDays, 1)
       XCTAssertEqual(policy.maxRepeatedCharacters, 2)
       XCTAssertEqual(policy.minUniqueCharacters, 3)
       XCTAssertEqual(policy.history?.count, 5)
       XCTAssertEqual(policy.history?.retentionDays, 365)
       XCTAssertEqual(policy.lockout?.failureCount, 3)
       XCTAssertEqual(policy.lockout?.durationSeconds, 600)
       XCTAssertEqual(policy.length.min, 8)
       XCTAssertEqual(policy.length.max, 20)
       XCTAssertEqual(policy.minCharacters["digits"], 1)
       XCTAssertEqual(policy.minCharacters["special"], 1)
       XCTAssertEqual(policy.populationCount, 1000)
       XCTAssertEqual(policy.createdAt, "2024-01-01T00:00:00Z")
       XCTAssertEqual(policy.updatedAt, "2024-01-02T00:00:00Z")
       XCTAssertEqual(policy.default, true)
   }
   
   func testConvertsEmptyJsonStringToPasswordPolicyWithDefaultValues() throws {
       let jsonString = "{}"
       let jsonData = jsonString.data(using: .utf8)!
       let policy = try JSONDecoder().decode(PasswordPolicy.self, from: jsonData)
       
       XCTAssertEqual(policy.name, "")
       XCTAssertEqual(policy.description, "")
       XCTAssertEqual(policy.excludesProfileData, false)
       XCTAssertEqual(policy.notSimilarToCurrent, false)
       XCTAssertEqual(policy.excludesCommonlyUsed, false)
       XCTAssertEqual(policy.maxAgeDays, 0)
       XCTAssertEqual(policy.minAgeDays, 0)
       XCTAssertEqual(policy.maxRepeatedCharacters, Int.max)
       XCTAssertEqual(policy.minUniqueCharacters, 0)
       XCTAssertNil(policy.history)
       XCTAssertNil(policy.lockout)
       XCTAssertEqual(policy.length.min, 0)
       XCTAssertEqual(policy.length.max, Int.max)
       XCTAssertEqual(policy.minCharacters, [:])
       XCTAssertEqual(policy.populationCount, 0)
       XCTAssertEqual(policy.createdAt, "")
       XCTAssertEqual(policy.updatedAt, "")
       XCTAssertEqual(policy.default, false)
   }
}
