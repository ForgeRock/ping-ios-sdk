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
import PingDavinciPlugin

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
            await CollectorFactory.shared.register(type: Constants.TEXT, closure: { json in
                return TextCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.PASSWORD, closure: { json in
                return PasswordCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.PASSWORD_VERIFY, closure: { json in
                return PasswordCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.SUBMIT_BUTTON, closure: { json in
                return SubmitCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.ACTION, closure: { json in
                return FlowCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.LABEL, closure: { json in
                return LabelCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.SINGLE_SELECT, closure: { json in
                return SingleSelectCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.MULTI_SELECT, closure: { json in
                return MultiSelectCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.FLOW_BUTTON, closure: { json in
                return FlowCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.FLOW_LINK, closure: { json in
                return FlowCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.DROPDOWN, closure: { json in
                return SingleSelectCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.RADIO, closure: { json in
                return SingleSelectCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.COMBOBOX, closure: { json in
                return MultiSelectCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.CHECKBOX, closure: { json in
                return MultiSelectCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.DEVICE_REGISTRATION, closure: { json in
                return DeviceRegistrationCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.DEVICE_AUTHENTICATION, closure: { json in
                return DeviceAuthenticationCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.PHONE_NUMBER, closure: { json in
                return PhoneNumberCollector(with: json)
            })
            if let c: NSObject.Type = NSClassFromString("PingProtect.ProtectCollector") as? NSObject.Type {
                c.perform(Selector(("registerCollector")))
            }
            if let c: NSObject.Type = NSClassFromString("PingOneProtect.ProtectCollector") as? NSObject.Type {
                c.perform(Selector(("registerCollector")))
            }
            if let c: NSObject.Type = NSClassFromString("PingFido.CollectorInitializer") as? NSObject.Type {
                c.perform(Selector(("registerCollectors")))
            }
            if let c: NSObject.Type = NSClassFromString("PingExternalIdP.IdpCollector") as? NSObject.Type {
                c.perform(Selector(("registerCollector")))
            }
        }
        
        // Apply custom configuration
        block(config)
        
        return DaVinci(config: config)
    }
}
