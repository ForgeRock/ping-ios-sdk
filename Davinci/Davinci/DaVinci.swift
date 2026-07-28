//
//  DaVinci.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingOidc
import PingDavinciPlugin
import PingCommons
import PingNetwork
import PingLogger

public typealias DaVinci = Workflow
public typealias DaVinciConfig = WorkflowConfig

extension DaVinci {
    /// Method to create a DaVinci instance.
    /// - Parameter block: The configuration block.
    /// - Returns: The DaVinci instance.
    public static func createDaVinci(block: @Sendable (DaVinciConfig) -> Void = {_ in }) -> DaVinci {
        let config = DaVinciConfig()
        config.module(CustomHeader.config) { customHeaderConfig in
            customHeaderConfig.header(name: NetworkConstants.headerRequestedWith, value: NetworkConstants.requestedWithValue)
            customHeaderConfig.header(name: NetworkConstants.headerRequestedPlatform, value: NetworkConstants.requestedPlatformValue)
            customHeaderConfig.header(name: NetworkConstants.headerAcceptLanguage, value: Locale.preferredLocales.toAcceptLanguage())
        }
        config.module(NodeTransformModule.config)
        config.module(ContinueNodeModule.config)
        config.module(OidcModule.config)
        config.module(CookieModule.config) { cookieConfig in
            cookieConfig.persist = [NetworkConstants.stCookie, NetworkConstants.stNoSsCookie]
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
            await CollectorFactory.shared.register(type: Constants.POLLING, closure: { json in
                return PollingCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.QR_CODE, closure: { json in
                return QRCodeCollector(with: json)
            })
            // Registers a Collector for Constants.BOOLEAN `inputType`. It can have different `type`s
            // This is similar to Constants.ACTION, Constants.SINGLE_SELECT, Constants.MULTI_SELECT etc.
            await CollectorFactory.shared.register(type: Constants.BOOLEAN, closure: { json in
                return BooleanCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.READ_ONLY_TEXT, closure: { json in
                return ReadOnlyTextCollector(with: json)
            })
            await CollectorFactory.shared.register(type: Constants.METADATA, closure: { json in
                return MetadataCollector(with: json)
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

    /// Creates a DaVinci instance from a JSON dictionary.
    ///
    /// This factory parses and validates a platform-neutral JSON configuration and
    /// delegates to `createDaVinci(block:)` with the extracted values. Unknown fields
    /// (including `serverUrl`, `realm`, and `cookie`, which are Journey-specific) are
    /// silently ignored for forward compatibility.
    ///
    /// - Parameter json: A `[String: Any]` dictionary conforming to the unified SDK
    ///   configuration schema (see design doc for field reference).
    /// - Returns: `.success(DaVinci)` on valid input, `.failure(JsonConfigError)` if a
    ///   required field is absent or a field has the wrong type.
    public static func createDaVinci(json: [String: Any]) -> Result<DaVinci, Error> {
        do {
            let p = JsonConfigParser(json)
            let timeout = try p.timeoutSeconds()
            let logger  = p.logLevel()
            let oidcDict: [String: Any] = try p.required(JsonConfigKey.oidc, field: JsonConfigKey.oidc)

            let oidcConfig = try OidcClientConfig.from(oidcJson: oidcDict, logger: logger)

            let daVinci = DaVinci.createDaVinci { daVinciConfig in
                daVinciConfig.timeout = timeout
                daVinciConfig.logger = logger
                daVinciConfig.module(OidcModule.config) { moduleOidcConfig in
                    moduleOidcConfig.update(with: oidcConfig)
                }
            }
            return .success(daVinci)
        } catch {
            return .failure(error)
        }
    }
}
