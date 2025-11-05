//
//  PhoneNumberCollector.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// A collector for phone number.
open class PhoneNumberCollector: FieldCollector<[String: Any]>, @unchecked Sendable {
    
    /// default country code
    public private(set) var defaultCountryCode: String
    /// validate phone number
    public private(set) var validatePhoneNumber: Bool
    /// country code
    public var countryCode: String = ""
    /// phone number
    public var phoneNumber: String = ""
    
    /// Initializes a new instance of `PhoneNumberCollector` with the given JSON input.
    public required init(with json: [String : Any]) {
        self.defaultCountryCode = json[Constants.defaultCountryCode] as? String ?? ""
        self.validatePhoneNumber = json[Constants.validatePhoneNumber] as? Bool ?? false
        try super.init(with: json)
    }
    
    /// Initializes the collector's values. The input can be a dictionary containing
    /// both phone number and country code, or a simple string for just the phone number.
    /// - Parameter input: The value to initialize the collector with.
    public override func initialize(with input: Any) {
        // Check for the new structure (a dictionary with phone and country code)
        if let dictValue = input as? [String: Any] {
            self.phoneNumber = dictValue[Constants.phoneNumber] as? String ?? ""
            self.countryCode = dictValue[Constants.countryCode] as? String ?? ""
        }
        // Fallback to the legacy structure (a simple string)
        else if let stringValue = input as? String {
            self.phoneNumber = stringValue
        }
    }
    
    /// Returns the selected device type.
    override open func payload() -> [String: Any]? {
        if countryCode.isEmpty || phoneNumber.isEmpty{
            return nil
        }
        var payload: [String: Any] = [:]
        payload[Constants.phoneNumber] = phoneNumber
        payload[Constants.countryCode] = countryCode
        return payload
    }
}
