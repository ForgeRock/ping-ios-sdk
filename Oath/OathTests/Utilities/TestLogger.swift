//
//  TestLogger.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation
import PingLogger

/// A thread-safe logger implementation for testing purposes.
/// It captures log messages in memory for later inspection.
final class TestLogger: Logger, @unchecked Sendable {
    private let queue = DispatchQueue(label: "TestLogger.queue")

    private var _debugMessages: [String] = []
    private var _infoMessages: [String] = []
    private var _warningMessages: [String] = []
    private var _errorMessages: [String] = []

    var debugMessages: [String] { queue.sync { _debugMessages } }
    var infoMessages: [String] { queue.sync { _infoMessages } }
    var warningMessages: [String] { queue.sync { _warningMessages } }
    var errorMessages: [String] { queue.sync { _errorMessages } }

    func d(_ message: String) { queue.sync { _debugMessages.append(message) } }
    func i(_ message: String) { queue.sync { _infoMessages.append(message) } }
    func w(_ message: String, error: Error?) { queue.sync { _warningMessages.append(message) } }
    func e(_ message: String, error: Error?) { queue.sync { _errorMessages.append(message) } }
}
