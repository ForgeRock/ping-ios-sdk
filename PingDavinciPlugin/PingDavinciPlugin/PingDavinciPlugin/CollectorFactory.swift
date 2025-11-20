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

/// The CollectorFactory singleton is responsible for creating and managing Collector instances.
/// It maintains a dictionary of collector creation functions, keyed by type.
/// It also provides functions to register new types of collectors and to create collectors from a JSON array.
public actor CollectorFactory {
    /// A dictionary to hold the collector creation functions.
    var collectors: [String: any Collector.Type] = [:]
    var collectorCreationClosures: [String: ([String: Any]) -> (any Collector)?] = [:]
    
    /// The shared instance of the CollectorFactory.
    public static let shared = CollectorFactory()
    
    init() { }
    
    /// Registers a new type of Collector.
    /// - Parameters:
    ///   - type: The type of the Collector.
    ///   - block: A function that creates a new instance of the Collector.
    @available(*, deprecated, message: "Use register(type:closure:) instead")
    public func register(type: String, collector: any Collector.Type) {
        collectors[type] = collector
    }
    
    /// Registers a new type of Collector.
    /// - Parameters:
    ///   - type: The type of the Collector.
    ///   - closure: A closure that creates a new instance of the Collector.
    public func register(type: String, closure: @escaping ([String: Any]) -> (any Collector)?) {
        collectorCreationClosures[type] = closure
    }
    
    /// Creates a list of Collector instances from an array of dictionaries.
    /// Each dictionary should have a "type" field that matches a registered Collector type.
    /// - Parameter array: The array of dictionaries to create the Collectors from.
    /// - Returns: A list of Collector instances.
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
    
    /// Injects the ContinueNode instances into the collectors.
    /// - Parameter continueNode: The ContinueNode instance to be injected.
    public func inject(continueNode: ContinueNode) {
        continueNode.collectors.forEach { collector in
            if var collector = collector as? ContinueNodeAware {
                collector.continueNode = continueNode
            }
        }
    }
    
    /// Resets the CollectorFactory by clearing all registered collectors.
    public func reset() {
        collectors.removeAll()
    }
}
