//
//  Protect.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.

import PingOrchestrate
import PingOneSignals

/// Actor to manage Protect SDK state with thread safety
@globalActor
public actor ProtectActor {
    public static let shared = ProtectActor()
}

/// The `Protect` class provides methods to initialize the SDK and retrieve device signal data
@ProtectActor
public class Protect {
    internal private(set) static var protectConfig: ProtectConfig?
    internal private(set) static var isInitialized: Bool = false

    /// Configures the Protect SDK with the provided configuration.
    /// This method should be called before calling `initialize()`.
    ///
    /// - Parameter block: A closure that configures the `ProtectConfig`.
    public static func config(_ block: (ProtectConfig) -> Void) {
        let protectConfig = ProtectConfig()
        block(protectConfig)
        self.protectConfig = protectConfig
    }

    /// Initializes the Protect SDK with the provided configuration.
    /// This method should be called before using any other methods in the Protect SDK.
    ///
    /// - Throws: `ProtectError` if initialization fails.
    public static func initialize() async throws {
        if isInitialized {
            return
        }

        guard let config = protectConfig else {
            throw ProtectError("Protect SDK not configured. Call config() first.")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let initParams = POInitParams()
            initParams.envId = config.envId
            initParams.deviceAttributesToIgnore = config.deviceAttributesToIgnore
            initParams.customHost = config.customHost
            initParams.consoleLogEnabled = config.isConsoleLogEnabled
            initParams.lazyMetadata = config.isLazyMetadata
            initParams.behavioralDataCollection = config.isBehavioralDataCollection

            let pingOneSignals = PingOneSignals.initSDK(initParams: initParams)

            pingOneSignals.setInitCallback { error in
                Task { @ProtectActor in
                    if let error = error as? NSError {
                        self.isInitialized = false
                        continuation.resume(throwing: ProtectError("PingOneSignals initialization failed: \(error.localizedDescription)"))
                    } else {
                        self.isInitialized = true
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Retrieves the signal data from the Protect SDK.
    /// This method should be called after `initialize()` to get the data.
    ///
    /// - Returns: A string containing the behavioral data.
    /// - Throws: `ProtectError` if data retrieval fails.
    public static func data() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let sharedInstance = PingOneSignals.sharedInstance() else {
                continuation.resume(throwing: ProtectError("PingOneSignals shared instance is not available"))
                return
            }

            sharedInstance.getData({ data, error in
                if let data = data {
                    continuation.resume(returning: data)
                } else if let error = error as? NSError {
                    continuation.resume(throwing: ProtectError("Data retrieval failed: \(error.localizedDescription)"))
                } else {
                    continuation.resume(throwing: ProtectError("Data retrieval failed with unknown error"))
                }
            })
        }
    }

    /// Pause behavioral data collection
    /// - Throws: `ProtectError` if SDK is not initialized
    public static func pauseBehavioralData() throws {
        guard let sharedInstance = PingOneSignals.sharedInstance() else {
            throw ProtectError("PingOneSignals shared instance is not available")
        }

        sharedInstance.pauseBehavioralData()
    }

    /// Resume behavioral data collection
    /// - Throws: `ProtectError` if SDK is not initialized
    public static func resumeBehavioralData() throws {
        guard let sharedInstance = PingOneSignals.sharedInstance() else {
            throw ProtectError("PingOneSignals shared instance is not available")
        }

        sharedInstance.resumeBehavioralData()
    }

    /// Resets the SDK to uninitialized state (useful for testing)
    internal static func reset() {
        isInitialized = false
        protectConfig = nil
    }
}

/// Class to provide Protect SDK configuration attributes.
public class ProtectConfig {
    /// The environment ID for the Protect SDK.
    public var envId: String?

    /// A list of device attributes to ignore when collecting data.
    public var deviceAttributesToIgnore: [String] = []

    /// Custom host for the Protect SDK.
    public var customHost: String?

    /// Whether to enable console logging for the Protect SDK.
    public var isConsoleLogEnabled: Bool = false

    /// Whether to use lazy metadata loading for the Protect SDK.
    public var isLazyMetadata: Bool = false

    /// Whether to enable behavioral data collection.
    public var isBehavioralDataCollection: Bool = true

    /// Initializes a new instance of the ProtectConfig.
    public init() {}
}
