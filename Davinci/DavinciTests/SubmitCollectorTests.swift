// 
//  SubmitCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

final class SubmitCollectorTests: XCTestCase {
    
    func testInitialization() {
        let submitCollector = SubmitCollector(with: [:])
        XCTAssertNotNil(submitCollector)
    }
}
