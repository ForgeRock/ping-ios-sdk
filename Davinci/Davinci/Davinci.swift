//
//  DaVinci.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingOidc

public typealias DaVinci = Workflow
public typealias DaVinciConfig = WorkflowConfig

extension DaVinci {
    /// Method to create a DaVinci instance.
    /// - Parameter block: The configuration block.
    /// - Returns: The DaVinci instance.
    public static func createDaVinci(block: @Sendable (DaVinciConfig) -> Void = {_ in }) -> DaVinci {
        let config = DaVinciConfig()
        config.module(CustomHeader.config) { customHeaderConfig in
            customHeaderConfig.header(name: Request.Constants.xRequestedWith, value: Request.Constants.pingSdk)
            customHeaderConfig.header(name: Request.Constants.xRequestedPlatform, value: Request.Constants.ios)
            customHeaderConfig.header(name: Request.Constants.acceptLanguage, value: Locale.preferredLocales.toAcceptLanguage())
        }
        config.module(NodeTransformModule.config)
        config.module(ContinueNodeModule.config)
        config.module(OidcModule.config)
        config.module(CookieModule.config) { cookieConfig in
            cookieConfig.persist = [Request.Constants.stCookie, Request.Constants.stNoSsCookie]
        }
        Task {
            await CollectorFactory.shared.registerDefaultCollectors()
        }
        
        // Apply custom configuration
        block(config)
        
        return DaVinci(config: config)
    }
}
