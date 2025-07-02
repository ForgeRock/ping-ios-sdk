//
//  ProtectLifecycleModule.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinci
import PingOrchestrate

/// Module for managing the lifecycle of the Protect SDK.
/// This module initializes the Protect SDK and manages the pause/resume behavior
/// of behavioral data collection based on the authentication lifecycle.
public class ProtectLifecycleModule {
    public init() { }
    
    /// The module configuration.
    public static let config: Module<ProtectLifecycleConfig> = Module.of({ ProtectLifecycleConfig() }) { setup in
        
        let setupConfig: ProtectLifecycleConfig = setup.config
        
        // Initializes the module.
        setup.initialize { @Sendable in
            await Protect.config { config in
                config.envId = setupConfig.envId
                config.deviceAttributesToIgnore = setupConfig.deviceAttributesToIgnore
                config.customHost = setupConfig.customHost
                config.isConsoleLogEnabled = setupConfig.isConsoleLogEnabled
                config.isLazyMetadata = setupConfig.isLazyMetadata
                config.isBehavioralDataCollection = setupConfig.isBehavioralDataCollection
            }
            try await Protect.initialize()
        }
        
        setup.start { @Sendable context, request in
            if setupConfig.resumeBehavioralDataOnStart {
                try await Protect.resumeBehavioralData()
            }
            return request
        }
        
        setup.success { @Sendable context, successNode in
            if setupConfig.pauseBehavioralDataOnSuccess {
                try await Protect.pauseBehavioralData()
            }
            return successNode
        }
    }
}

/// Configuration for the Protect Lifecycle Module.
/// This module allows you to pause and resume behavioral data collection
/// based on the lifecycle of the authentication process.
public class ProtectLifecycleConfig: ProtectConfig, @unchecked Sendable {
    /// Whether to pause behavioral data collection on successful authentication.
    /// Default is false, meaning behavioral data will continue to be collected.
    public var pauseBehavioralDataOnSuccess: Bool = false
    
    /// Whether to resume behavioral data collection when the module starts.
    /// Default is false, meaning behavioral data will not be resumed automatically.
    public var resumeBehavioralDataOnStart: Bool = false
    
    public override init() {}
}
