//
//  CollectorFactory.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
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
    
    /// The shared instance of the CollectorFactory.
    public static let shared = CollectorFactory()
    
    init() { }
    
    /// Registers the default DaVinci Collectors.
    public func registerDefaultCollectors() {
        register(type: Constants.TEXT, collector: TextCollector.self)//
        register(type: Constants.PASSWORD, collector: PasswordCollector.self)
        register(type: Constants.PASSWORD_VERIFY, collector: PasswordCollector.self)
        register(type: Constants.SUBMIT_BUTTON, collector: SubmitCollector.self)//
        register(type: Constants.ACTION, collector: FlowCollector.self)
        register(type: Constants.LABEL, collector: LabelCollector.self)//
        register(type: Constants.SINGLE_SELECT, collector: SingleSelectCollector.self)
        register(type: Constants.MULTI_SELECT, collector: MultiSelectCollector.self)
        
        // TODO: Remove `FLOW_BUTTON` and `FLOW_LINK` once the server is updated
        register(type: Constants.FLOW_BUTTON, collector: FlowCollector.self)
        register(type: Constants.FLOW_LINK, collector: FlowCollector.self)
        register(type: Constants.DROPDOWN, collector: SingleSelectCollector.self)
        register(type: Constants.RADIO, collector: SingleSelectCollector.self)
        register(type: Constants.COMBOBOX, collector: MultiSelectCollector.self)
        register(type: Constants.CHECKBOX, collector: MultiSelectCollector.self)
        if let c: NSObject.Type = NSClassFromString("PingExternalIdP.IdpCollector") as? NSObject.Type {
            c.perform(Selector(("registerCollector")))
        }
        register(type: Constants.DEVICE_REGISTRATION, collector: DeviceRegistrationCollector.self)
        register(type: Constants.DEVICE_AUTHENTICATION, collector: DeviceAuthenticationCollector.self)
        register(type: Constants.PHONE_NUMBER, collector: PhoneNumberCollector.self)
        if let c: NSObject.Type = NSClassFromString("PingProtect.ProtectCollector") as? NSObject.Type {
            c.perform(Selector(("registerCollector")))
        }
    }
    
    /// Registers a new type of Collector.
    /// - Parameters:
    ///   - type: The type of the Collector.
    ///   - block: A function that creates a new instance of the Collector.
    public func register(type: String, collector: any Collector.Type) {
        collectors[type] = collector
    }
    
    /// Creates a list of Collector instances from an array of dictionaries.
    /// Each dictionary should have a "type" field that matches a registered Collector type.
    /// - Parameter array: The array of dictionaries to create the Collectors from.
    /// - Returns: A list of Collector instances.
    public func collector(from array: [[String: Any]]) -> Collectors {
        var list: [any Collector] = []
        for item in array {
            if let type = item[Constants.inputType] as? String ?? item[Constants.type] as? String, let collectorType = collectors[type] {
                list.append(collectorType.init(with: item))
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
