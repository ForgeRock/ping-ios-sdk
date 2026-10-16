//
//  RarJson.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc

/// Decodes a user-entered `authorization_details` JSON array string (RFC 9396 §2) into
/// the typed values the SDK accepts.
enum RarJson {
    struct DecodeError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func decode(_ text: String) -> Result<[AuthorizationDetail], DecodeError> {
        guard let data = text.data(using: .utf8) else {
            return .failure(DecodeError(message: "Not valid UTF-8 text."))
        }
        do {
            let details = try JSONDecoder().decode([AuthorizationDetail].self, from: data)
            guard !details.isEmpty else {
                return .failure(DecodeError(message: "At least one authorization_details object is required."))
            }
            return .success(details)
        } catch {
            return .failure(DecodeError(message: String(describing: error)))
        }
    }
}

/// Ready-made `authorization_details` payloads for the sample app.
enum RarPreset: String, CaseIterable, Identifiable {
    case paymentInitiation = "payment_initiation"
    case accountInformation = "account_information"
    case empty = "Custom"

    var id: String { rawValue }

    var json: String {
        switch self {
        case .paymentInitiation:
            return """
            [
              {
                "type": "payment_initiation",
                "locations": ["https://example.com/payments"],
                "instructedAmount": {"currency": "EUR", "amount": "123.50"},
                "creditorName": "Merchant A",
                "creditorAccount": {"iban": "DE02100100109307118603"},
                "remittanceInformationUnstructured": "Ref Number Merchant"
              }
            ]
            """
        case .accountInformation:
            return """
            [
              {
                "type": "account_information",
                "actions": ["list_accounts", "read_balances"],
                "locations": ["https://example.com/accounts"],
                "datatypes": ["balances"]
              }
            ]
            """
        case .empty:
            return """
            [
              {
                "type": ""
              }
            ]
            """
        }
    }
}
