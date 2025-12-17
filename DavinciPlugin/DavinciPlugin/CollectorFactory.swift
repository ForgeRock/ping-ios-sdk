//
//  CollectorFactory.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Type alias for a list of collectors created for a ContinueNode.
public typealias Collectors = [any Collector]

/// A factory and registry for Collector types.
///
/// CollectorFactory is responsible for:
/// - Registering collector types by a string key (typically the server-provided "type" or "inputType").
/// - Creating collectors from JSON dictionaries provided by DaVinci responses.
/// - Injecting contextual references (e.g., ContinueNode) into collectors that need them.
/// - Resetting the registry (useful in tests).
///
/// The actor ensures thread-safe registration and creation across concurrent tasks.
public actor CollectorFactory {
    /// Legacy registry mapping a type key to a Collector metatype.
    /// Deprecated in favor of `collectorCreationClosures`.
    var collectors: [String: any Collector.Type] = [:]
    
    /// Registry mapping a type key to a factory closure that produces a collector from the raw JSON.
    var collectorCreationClosures: [String: ([String: Any]) -> (any Collector)?] = [:]
    
    /// The shared singleton instance of the CollectorFactory.
    public static let shared = CollectorFactory()
    
    /// Initializes a new CollectorFactory.
    /// Prefer using the shared instance unless you specifically need isolation (e.g., in tests).
    init() { }
    
    /// Registers a Collector metatype for a given key.
    ///
    /// - Parameters:
    ///   - type: The string key identifying the collector (e.g., "TEXT", "PASSWORD").
    ///   - collector: The Collector type to instantiate when that key is encountered.
    ///
    /// - Note: This API is deprecated. Prefer `register(type:closure:)` to allow flexible construction.
    @available(*, deprecated, message: "Use register(type:closure:) instead")
    public func register(type: String, collector: any Collector.Type) {
        collectors[type] = collector
    }
    
    /// Registers a Collector factory closure for a given key.
    ///
    /// - Parameters:
    ///   - type: The string key identifying the collector (e.g., "TEXT", "PASSWORD").
    ///   - closure: A closure that takes the raw JSON dictionary for a collector and returns an instance,
    ///              or nil if the JSON cannot be parsed for this type.
    public func register(type: String, closure: @escaping ([String: Any]) -> (any Collector)?) {
        collectorCreationClosures[type] = closure
    }
    
    /// Creates a list of collectors from an array of JSON dictionaries.
    ///
    /// - Parameters:
    ///   - daVinci: The DaVinci workflow instance to inject into collectors that are `DaVinciAware`.
    ///   - array: The array of JSON dictionaries describing each collector. The factory will read
    ///            `Constants.inputType` first, falling back to `Constants.type`, to identify the collector type.
    /// - Returns: An ordered list of collectors constructed from the JSON input.
    ///
    /// The method attempts construction using:
    /// 1. A registered metatype in `collectors` (deprecated path).
    /// 2. A registered closure in `collectorCreationClosures`.
    ///
    /// If a collector conforms to `DaVinciAware`, the provided `daVinci` instance is injected.
    public func collector(daVinci: DaVinci, from array: [[String: Any]]) -> Collectors {
        var list: [any Collector] = []
        for item in array {
            if let type = item[Constants.inputType] as? String ?? item[Constants.type] as? String {
                if let collectorType = collectors[type] {
                    let collector = collectorType.init(with: item)
                    if var collector = collector as? DaVinciAware {
                        collector.davinci = daVinci
                    }
                    list.append(collector)
                } else if let closure = collectorCreationClosures[type] {
                    if let collector = closure(item) {
                        list.append(collector)
                    }
                }
            }
        }
        return list
    }
    
    /// Injects the provided ContinueNode into any collectors that conform to `ContinueNodeAware`.
    ///
    /// - Parameter continueNode: The node whose collectors will receive the node reference.
    ///
    /// This enables collectors to call `next()` or otherwise interact with their hosting node.
    public func inject(continueNode: ContinueNode) {
        continueNode.collectors.forEach { collector in
            if var collector = collector as? ContinueNodeAware {
                collector.continueNode = continueNode
            }
        }
    }
    
    /// Clears all registered collectors and factory closures.
    ///
    /// Useful for tests to ensure a clean registry between runs.
    public func reset() {
        collectors.removeAll()
        collectorCreationClosures.removeAll()
    }
}

