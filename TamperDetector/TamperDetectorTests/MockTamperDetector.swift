//
//  MockTamperDetector.swift
//  PingTamperDetectorTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
@testable import PingTamperDetector

class MockTamperDetector: TamperDetectorProtocol {
    
    var score: Double
    
    init(score: Double) {
        self.score = score
    }
    
    func analyze() -> Double {
        return score
    }
}
