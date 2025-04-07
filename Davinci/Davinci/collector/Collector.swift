//
//  FlowCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.


import PingOrchestrate
import Foundation

/// Protocol representing a Collector.
public protocol Collector<T>: Action, Identifiable, Sendable {
    associatedtype T
    var id: String { get }
    init(with json: [String: Any])
    func payload() -> T?
}

extension Collector {
    func payload() -> T? {
        return nil
    }
}
