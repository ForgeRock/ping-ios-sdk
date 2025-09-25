//
//  TelephonyCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CoreTelephony

// MARK: - TelephonyCollector

/// Collector for cellular network and carrier information.
///
/// This collector gathers information about the device's cellular capabilities
/// including carrier name and network country information from available
/// cellular service providers.
class TelephonyCollector: DeviceCollector {
    typealias DataType = TelephonyInfo
    
    /// Unique identifier for telephony information data
    let key = "telephony"
    
    /// Collects cellular network and carrier information
    /// - Returns: TelephonyInfo containing carrier and network details
    func collect() async -> TelephonyInfo? {
        return TelephonyInfo()
    }
}

// MARK: - TelephonyInfo

/// Information about the device's cellular network and carrier services.
///
/// This structure contains details about the cellular service provider
/// and network country code, extracted from available cellular subscriptions.
struct TelephonyInfo: Codable {
    /// ISO country code of the cellular network (e.g., "US", "GB", "JP")
    /// - Note: Returns "Unknown" if no carrier information is available
    let networkCountryIso: String?
    
    /// Name of the cellular carrier (e.g., "Verizon", "AT&T", "Vodafone")
    /// - Note: Returns "Unknown" if no carrier information is available
    let carrierName: String?
    
    /// Initializes telephony information by querying cellular providers
    ///
    /// ## Implementation Details
    /// - Queries all available cellular service subscriptions
    /// - Uses custom sorting to select the most appropriate carrier
    /// - Falls back to "Unknown" values if no carrier data is available
    ///
    /// ## Multi-SIM Support
    /// - Handles devices with multiple cellular subscriptions
    /// - Selects the primary or most complete carrier information
    /// - Prioritizes carriers with complete information
    init() {
        let networkInfo = CTTelephonyNetworkInfo()
        
        var selectedCarrier: (carrierName: String?, isoCountryCode: String?)?
        
        // Check for available cellular service providers
        if let providers = networkInfo.serviceSubscriberCellularProviders,
           !providers.isEmpty {
            
            // Extract carrier information from all providers
            let carriers = providers.map {
                (carrierName: $0.value.carrierName, isoCountryCode: $0.value.isoCountryCode)
            }
            
            // Select the best carrier using custom sorting logic
            selectedCarrier = TelephonyCollector.selectPrimaryCarrier(from: carriers)
        }
        
        // Set final values with fallback to "Unknown"
        if let carrier = selectedCarrier {
            self.carrierName = carrier.carrierName ?? "Unknown"
            self.networkCountryIso = carrier.isoCountryCode ?? "Unknown"
        } else {
            self.carrierName = "Unknown"
            self.networkCountryIso = "Unknown"
        }
    }
}

// MARK: - Helper Methods

extension TelephonyCollector {
    
    /// Selects the primary carrier from multiple available carriers.
    ///
    /// This method implements a custom sorting algorithm to determine
    /// the most appropriate carrier when multiple cellular subscriptions
    /// are available (e.g., dual-SIM devices).
    ///
    /// - Parameter carriers: Array of carrier information tuples
    /// - Returns: The selected primary carrier, or nil if array is empty
    ///
    /// ## Selection Logic
    /// 1. **Complete Information Priority**: Carriers with both name and country code
    /// 2. **Carrier Name Priority**: Carriers with valid names over those without
    /// 3. **Country Code Priority**: When names are equal, sort by country code
    /// 4. **Alphabetical Fallback**: Consistent sorting for identical information
    ///
    /// ## Example Scenarios
    /// - **Single SIM**: Returns the only available carrier
    /// - **Dual SIM**: Prioritizes the carrier with complete information
    /// - **Multiple eSIMs**: Selects based on completeness and alphabetical order
    ///
    /// ## Use Cases
    /// - **Travel**: May prefer local carrier over roaming carrier
    /// - **Business**: May select primary line over secondary data-only line
    /// - **Consistency**: Ensures stable selection across app launches
    static func selectPrimaryCarrier(
        from carriers: [(carrierName: String?, isoCountryCode: String?)]
    ) -> (carrierName: String?, isoCountryCode: String?)? {
        
        let sortedCarriers = carriers.sorted { first, second in
            // Both carriers have no name
            if first.carrierName == nil && second.carrierName == nil {
                // Sort by country code presence and value
                if first.isoCountryCode == nil {
                    return false // second wins if it has country code
                } else if second.isoCountryCode == nil {
                    return true // first wins if second has no country code
                } else {
                    // Both have country codes, sort alphabetically
                    return (first.isoCountryCode ?? "") < (second.isoCountryCode ?? "")
                }
            }
            // First has no name, second wins
            else if first.carrierName == nil {
                return false
            }
            // Second has no name, first wins
            else if second.carrierName == nil {
                return true
            }
            // Both have names, sort alphabetically
            else {
                return (first.carrierName ?? "") < (second.carrierName ?? "")
            }
        }
        
        return sortedCarriers.first
    }
}
