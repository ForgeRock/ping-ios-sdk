//
//  PingOneProtectEvaluationCallback.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney

/// A callback class for evaluating Protect data collection.
/// This class extends AbstractProtectCallback and provides functionality to collect
/// data from the Protect SDK, with an option to pause behavioral data collection.
public class PingOneProtectEvaluationCallback: AbstractProtectCallback, @unchecked Sendable {
    /// Indicates whether to pause behavioral data collection
    private(set) public var pauseBehavioralData: Bool = false
    
    /// Initializes a new instance of `PingOneProtectEvaluationCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        super.initValue(name: name, value: value)
        
        switch name {
        case JourneyConstants.pauseBehavioralData:
            if let boolValue = value as? Bool {
                self.pauseBehavioralData = boolValue
            }
        default:
            break
        }
    }
    
    /// Collects data from the Protect SDK and returns it as a Result
    /// - Returns: Result containing the collected data or an error if an exception occurs
    public func collect() async -> Result<String, Error> {
        do {
            // Call Protect SDK to get data
            let signal = try await Protect.data()
            
            if pauseBehavioralData {
                try await Protect.pauseBehavioralData()
            }
            
            self.signal(signal, error: "")
            return .success(signal)
        } catch {
            let errorMessage = error.localizedDescription.isEmpty ? JourneyConstants.clientError : error.localizedDescription
            self.signal("", error: errorMessage)
            return .failure(error)
        }
    }
}
