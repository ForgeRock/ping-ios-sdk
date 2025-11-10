//
//  MockProtect.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation
@testable import PingProtect
@testable import PingJourney

class MockProtect {
    nonisolated(unsafe) static var shouldThrowError = false
    nonisolated(unsafe) static var errorMessage = "Operation failed"
    nonisolated(unsafe) static var dataReturnValue = "deviceSignals"
    nonisolated(unsafe) static var initializeCalled = false
    nonisolated(unsafe) static var resumeBehavioralDataCalled = false
    nonisolated(unsafe) static var pauseBehavioralDataCalled = false
    nonisolated(unsafe) static var configCalled = false
    nonisolated(unsafe) static var lastConfig: ProtectConfig?

    static func reset() {
        shouldThrowError = false
        errorMessage = "Operation failed"
        dataReturnValue = "deviceSignals"
        initializeCalled = false
        resumeBehavioralDataCalled = false
        pauseBehavioralDataCalled = false
        configCalled = false
        lastConfig = nil
    }

    static func data() async throws -> String {
        if shouldThrowError {
            throw TestError.collectDataFailed(errorMessage)
        }
        return dataReturnValue
    }

    static func resumeBehavioralData() async throws {
        resumeBehavioralDataCalled = true
    }

    static func pauseBehavioralData() async throws {
        pauseBehavioralDataCalled = true
    }

    @ProtectActor
    static func config(_ closure: (ProtectConfig) -> Void) async {
        configCalled = true
        let config = ProtectConfig()
        closure(config)
        lastConfig = config
    }

    static func initialize() async throws {
        initializeCalled = true
        if shouldThrowError {
            throw TestError.initFailed(errorMessage)
        }
    }
}


enum TestError: LocalizedError {
    case initFailed(String)
    case collectDataFailed(String)

    var errorDescription: String? {
        switch self {
        case .collectDataFailed(let message):
            return message
        case .initFailed(let message):
            return message
        }
    }
}

