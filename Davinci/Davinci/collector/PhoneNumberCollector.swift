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
open class PhoneNumberCollector: FieldCollector<[String: Any]>, Submittable, @unchecked Sendable {
    
    /// default country code
    public private(set) var defaultCountryCode: String
    /// country code
    public  var countryCode: String?
    /// phone number
    public  var phoneNumber: String?

    public required init(with json: [String : Any]) {
        self.defaultCountryCode = json[Constants.defaultCountryCode] as? String ?? ""
        super.init(with: json)
    }
    
    /// Returns the selected device type.
    override open func payload() -> [String: Any]? {
        if countryCode == nil || phoneNumber == nil {
            return nil
        }
        var payload: [String: Any] = [:]
        payload[Constants.phoneNumber] = phoneNumber
        payload[Constants.countryCode] = countryCode
        return payload
    }
}
