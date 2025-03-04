//
//  Module.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

///  A Module represents a unit of functionality in the application.
///  - property config: A function that returns the configuration for the module.
///  - property setup: A function that sets up the module.
public class Module<ModuleConfig>: Equatable, @unchecked Sendable where ModuleConfig: Sendable {
    public private(set) var setup: @Sendable (Setup<ModuleConfig>) -> (Void)
    public private(set) var config: @Sendable () -> (ModuleConfig)
    /// The unique identifier of the module.
    public var id: UUID = UUID()
    
    ///  Constructs a module with config.
    /// - Parameters:
    ///   - config: A function that returns the configuration for the module.
    ///   - setup: A function that sets up the module.
    public init(config: @escaping @Sendable () -> (ModuleConfig), setup: @escaping @Sendable (Setup<ModuleConfig>) -> (Void)) {
        self.setup = setup
        self.config = config
    }
    
    /// Constructs a module with config.
    /// - Parameters:
    ///   - config: A function that returns the configuration for the module.
    ///   - setup: A function that sets up the module.
    /// - Returns: A Module with the provided config.
    public static func of(_ config: @escaping @Sendable () -> (ModuleConfig) = {},
                          setup: @escaping @Sendable (Setup<ModuleConfig>) -> (Void)
    ) -> Module<ModuleConfig> {
        return Module<ModuleConfig>(config: config, setup: setup)
    }
  
    /// Compares two modules.
    /// - Parameters:
    ///   - lhs: The left-hand module.
    ///   - rhs: The right-hand module.
    /// - Returns: A boolean value indicating whether the two modules are equal.
    public static func == (lhs: Module<ModuleConfig>, rhs: Module<ModuleConfig>) -> Bool {
        return lhs.id == rhs.id
    }
}
