//
//  AuthorizationDetail.swift
//  PingOidc
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// One RFC 9396 §2 `authorization_details` object.
public struct AuthorizationDetail: Codable, Sendable, Equatable {
    /// The type of authorization details as defined by the authorization server (RFC 9396 §2, required).
    public var type: String
    /// Locations this authorization applies to (RFC 9396 §2).
    public var locations: [String]?
    /// Actions this authorization applies to (RFC 9396 §2).
    public var actions: [String]?
    /// Data types this authorization applies to (RFC 9396 §2).
    public var datatypes: [String]?
    /// Privileges this authorization applies to (RFC 9396 §2).
    public var privileges: [String]?
    /// Catch-all for type-specific fields not modeled above (e.g. `instructedAmount` for `payment_initiation`).
    public var additionalFields: [String: AuthorizationDetailValue]

    public init(
        type: String,
        locations: [String]? = nil,
        actions: [String]? = nil,
        datatypes: [String]? = nil,
        privileges: [String]? = nil,
        additionalFields: [String: AuthorizationDetailValue] = [:]
    ) {
        self.type = type
        self.locations = locations
        self.actions = actions
        self.datatypes = datatypes
        self.privileges = privileges
        self.additionalFields = additionalFields
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case type, locations, actions, datatypes, privileges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        locations = try container.decodeIfPresent([String].self, forKey: .locations)
        actions = try container.decodeIfPresent([String].self, forKey: .actions)
        datatypes = try container.decodeIfPresent([String].self, forKey: .datatypes)
        privileges = try container.decodeIfPresent([String].self, forKey: .privileges)

        var extra: [String: AuthorizationDetailValue] = [:]
        let dynamic = try decoder.container(keyedBy: AuthorizationDetailValue.DynamicKey.self)
        for key in dynamic.allKeys where !CodingKeys.allCases.contains(where: { $0.stringValue == key.stringValue }) {
            if let value = try? dynamic.decode(AuthorizationDetailValue.self, forKey: key) {
                extra[key.stringValue] = value
            }
        }
        additionalFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(locations, forKey: .locations)
        try container.encodeIfPresent(actions, forKey: .actions)
        try container.encodeIfPresent(datatypes, forKey: .datatypes)
        try container.encodeIfPresent(privileges, forKey: .privileges)

        if !additionalFields.isEmpty {
            var dynamic = encoder.container(keyedBy: AuthorizationDetailValue.DynamicKey.self)
            for (key, value) in additionalFields {
                let codingKey = AuthorizationDetailValue.DynamicKey(stringValue: key)
                try dynamic.encode(value, forKey: codingKey)
            }
        }
    }
}

public extension AuthorizationDetail {
    /// Serializes `details` into the single JSON-array-string value the `authorization_details`
    /// wire parameter (RFC 9396 §2) expects. Uses `.sortedKeys` for deterministic output.
    ///
    /// - Note: the returned value contains raw `+` characters where the JSON does (URL-encoding
    ///   happens downstream in the request layer); form-encoded transports decode `+` as a
    ///   space, so payloads whose JSON contains a literal `+` in a string value must avoid
    ///   relying on it surviving a round trip through such a server.
    static func wireValue(_ details: [AuthorizationDetail]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(details)
        return String(decoding: data, as: UTF8.self)
    }
}

/// Minimal type-erased Codable value for `AuthorizationDetail.additionalFields`.
public enum AuthorizationDetailValue: Codable, Sendable, Equatable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case object([String: AuthorizationDetailValue])
    case array([AuthorizationDetailValue])
    case null

    /// Bridges an untyped JSON value (as produced by `JSONSerialization`) into a typed value.
    public init(any: Any) {
        switch any {
        case let s as String: self = .string(s)
        case let n as NSNumber:
            // Everything JSON numbers/booleans produce arrives as NSNumber, and
            // `NSNumber(value: 1) as? Bool` succeeds — so Bool must be detected via the
            // CFBoolean type ID only, never via an `as? Bool` cast (which would
            // misclassify JSON numbers 0 and 1 as booleans).
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                self = .bool(n.boolValue)
            } else {
                self = .double(n.doubleValue)
            }
        case let d as [String: Any]: self = .object(d.mapValues { AuthorizationDetailValue(any: $0) })
        case let a as [Any]: self = .array(a.map { AuthorizationDetailValue(any: $0) })
        case is NSNull: self = .null
        default: self = .string(String(describing: any))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([String: AuthorizationDetailValue].self) {
            self = .object(v)
        } else if let v = try? container.decode([AuthorizationDetailValue].self) {
            self = .array(v)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported authorization_details value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
