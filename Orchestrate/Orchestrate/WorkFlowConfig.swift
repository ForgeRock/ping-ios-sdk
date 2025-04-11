//
//  WorkflowConfig.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger

/// Enum representing the mode of module override.
public enum OverrideMode {
    case override // Override the previous registered module
    case append // Append to the list, and cannot be overridden
    case ignore // Ignore if the module is already registered
}


/// Workflow configuration
public class WorkflowConfig: @unchecked Sendable {
    /// Use a list instead of a map to allow registering a module twice with different configurations
    public private(set) var modules: [any ModuleRegistryProtocol] = []
    /// Timeout for the HTTP client, default is 15 seconds
    public var timeout: TimeInterval = 15.0
    /// Logger for the workflow, default is NoneLogger
    public var logger: Logger = LogManager.logger {
        didSet {
            // Propagate the logger to Modules
            LogManager.logger = logger
        }
    }
    /// HTTP client for the engine
    public internal(set) var httpClient: HttpClient = HttpClient()
    
    /// Initializes a new WorkflowConfig instance.
    public init() {}
    
    /// Register a module.
    /// - Parameters:
    ///   - module: The module to be registered.
    ///   - priority: The priority of the module in the registry. Default is 10.
    ///   - mode: The mode of the module registration. Default is `override`. If the mode is `override`, the module will be overridden if it is already registered.
    ///   - config: The configuration for the module.
    public func module<T: Sendable>(_ module: Module<T>,
                                    priority: Int = 10,
                                    mode: OverrideMode = .override,
                                    _ config: @escaping @Sendable (T) -> (Void) = { _ in })  {
        
        switch mode {
        case .override:
            
            if let index = modules.firstIndex(where: { $0.id == module.id }) {
                modules[index] = ModuleRegistry(setup: module.setup, priority: modules[index].priority, id: modules[index].id, config: configValue(initalValue: module.config, nextValue: config))
            } else {
                let registry = ModuleRegistry(setup: module.setup, priority: priority, id: module.id, config: configValue(initalValue: module.config, nextValue: config))
                modules.append(registry )
            }
            
        case .append:
            let uuid = UUID()
            let moduleCopy = module
            let registry = ModuleRegistry(setup: moduleCopy.setup, priority: priority, id: uuid, config: configValue(initalValue: moduleCopy.config, nextValue: config))
            modules.append(registry)
            
        case .ignore:
            if modules.contains(where: { $0.id == module.id }) {
                return
            }
            let registry = ModuleRegistry(setup: module.setup, priority: priority, id: module.id, config: configValue(initalValue: module.config, nextValue: config))
            modules.append(registry)
        }
    }
    
    private func configValue<T>(initalValue: @escaping @Sendable () -> (T), nextValue: @escaping @Sendable (T) -> (Void)) -> T {
        let initConfig = initalValue()
        nextValue(initConfig)
        return initConfig
    }
    
    /// Registers the workflow
    /// - Parameter workflow: The workflow to be registered.
    public func register(workflow: Workflow) {
        httpClient.timeoutIntervalForRequest = timeout
        modules.sort(by: { $0.priority < $1.priority })
        modules.forEach { $0.register(workflow: workflow) }
    }
}
