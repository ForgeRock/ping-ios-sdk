//
//  PingOneProtectInitializeCallback.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney

/// A callback class for initializing the PingOne Protect SDK.
/// This class extends AbstractProtectCallback and provides functionality to configure
/// the Protect SDK with various parameters such as environment ID, behavioral data collection,
/// console logging, and device attributes to ignore.
public class PingOneProtectInitializeCallback: AbstractProtectCallback, @unchecked Sendable {
    /// The environment ID for the Protect SDK
    private(set) public var envId: String = ""
    /// Indicates whether behavioral data collection is enabled
    private(set) public var isBehavioralDataCollection: Bool = false
    /// Indicates whether console logging is enabled
    private(set) public var isConsoleLogEnabled: Bool = false
    /// Indicates whether lazy metadata loading is enabled
    private(set) public var lazyMetadata: Bool = false
    /// The custom host for the Protect SDK
    private(set) public var customHost: String = ""
    /// A list of device attributes to ignore
    private(set) public var deviceAttributesToIgnore: [String] = []
    
    /// Initializes a new instance of `PingOneProtectInitializeCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
        
        switch name {
        case JourneyConstants.envId:
            if let stringValue = value as? String {
                self.envId = stringValue
            }
        case JourneyConstants.behavioralDataCollection:
            if let boolValue = value as? Bool {
                self.isBehavioralDataCollection = boolValue
            }
        case JourneyConstants.consoleLogEnabled:
            if let boolValue = value as? Bool {
                self.isConsoleLogEnabled = boolValue
            }
        case JourneyConstants.lazyMetadata:
            if let boolValue = value as? Bool {
                self.lazyMetadata = boolValue
            }
        case JourneyConstants.customHost:
            if let stringValue = value as? String {
                self.customHost = stringValue
            }
        case JourneyConstants.deviceAttributesToIgnore:
            if let arrayValue = value as? [String] {
                self.deviceAttributesToIgnore = arrayValue
            }
        default:
            break
        }
    }
    
    /// Start the PingOne Protect SDK
    /// - Returns: A Result containing either success or failure
    public func start() async -> Result<Void, Error> {
        do {
            // Configure Protect SDK
            await Protect.config {
                $0.envId = envId.nilIfEmpty()
                $0.deviceAttributesToIgnore = deviceAttributesToIgnore
                $0.customHost = customHost
                $0.isConsoleLogEnabled = isConsoleLogEnabled
                $0.isLazyMetadata = lazyMetadata
                $0.isBehavioralDataCollection = isBehavioralDataCollection
            }
            
            try await Protect.initialize()
            
            if isBehavioralDataCollection {
                try await Protect.resumeBehavioralData()
            } else {
                try await Protect.pauseBehavioralData()
            }
            return .success(())
        } catch {
            let errorMessage = error.localizedDescription.isEmpty ? JourneyConstants.clientError : error.localizedDescription
            self.error(errorMessage)
            return .failure(error)
        }
    }
}

private extension String {
    /// Returns nil if string is empty, otherwise returns the string
    func nilIfEmpty() -> String? {
        return self.isEmpty ? nil : self
    }
}

extension JourneyConstants {
    public static let envId = "envId"
    public static let behavioralDataCollection = "behavioralDataCollection"
    public static let consoleLogEnabled = "consoleLogEnabled"
    public static let lazyMetadata = "lazyMetadata"
    public static let customHost = "customHost"
    public static let deviceAttributesToIgnore = "deviceAttributesToIgnore"
    public static let pauseBehavioralData = "pauseBehavioralData"
}
