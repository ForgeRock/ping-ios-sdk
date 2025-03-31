//
//  ModuleRegistry.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Represents a ModuleRegistry protocol. A ModuleRegistry represents a registry of modules in the application.
public protocol ModuleRegistryProtocol<Config>: Sendable where Config: Sendable {
    associatedtype Config: Sendable
    /// The UUID of the module
    var id: UUID { get }
    /// The priority of the module in the registry.
    var priority: Int { get }
    /// The configuration for the module.
    var config: Config { get }
    /// The function that sets up the module.
    var setup: @Sendable (Setup<Config>) -> (Void) { get }
    
    /// Registers the module to the workflow.
    func register(workflow: Workflow)
}


/// Class for a ModuleRegistry. A ModuleRegistry represents a registry of modules in the application.
///  - property id: The UUID of the module
///  - property priority: The priority of the module in the registry.
///  - property config: The configuration for the module.
///  - property setup: The function that sets up the module.
public final class ModuleRegistry<Config>: ModuleRegistryProtocol where Config: Sendable {
    public let id: UUID
    public let priority: Int
    public let config: Config
    public let setup: @Sendable (Setup<Config>) -> Void
    
    public init(setup: @escaping @Sendable (Setup<Config>) -> (Void),
                priority: Int,
                id: UUID,
                config: Config) {
        self.id = id
        self.priority = priority
        self.config = config
        self.setup = setup
    }
    
    /// Registers the module to the workflow.
    /// - parameter workflow: The workflow to which the module is registered.
    public func register(workflow: Workflow) {
        let setupInstance = Setup<Config>(workflow: workflow, config: config)
        setup(setupInstance)
    }
}


extension ModuleRegistry: Comparable {
    /// Compares two ModuleRegistry instances.
    /// - Parameters:
    ///   - lhs: The left-hand side ModuleRegistry instance.
    ///   - rhs: The right-hand side ModuleRegistry instance.
    /// - Returns: A boolean value indicating whether the left-hand side ModuleRegistry instance is less than the right-hand side ModuleRegistry instance.
    public static func < (lhs: ModuleRegistry, rhs: ModuleRegistry) -> Bool {
        return lhs.priority < rhs.priority
    }
    
    /// Compares two ModuleRegistry instances for equality.
    /// - Parameters:
    ///   - lhs: The left-hand side ModuleRegistry instance
    ///   - rhs: The right-hand side ModuleRegistry instance
    /// - Returns: A boolean value indicating whether the left-hand side ModuleRegistry instance is equal to the right-hand side ModuleRegistry instance.
    public static func == (lhs: ModuleRegistry, rhs: ModuleRegistry) -> Bool {
        return lhs.priority == rhs.priority
    }
}
