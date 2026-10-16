//
//  Config.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

@testable import PingDavinci

public enum ConfigError: Error {
    case emptyConfiguration
    case invalidConfiguration(String)
    /// A required configuration field is JSON `null` — intentional placeholder for local development.
    case notConfigured
}

class Config: NSObject {
    var username: String
    var userFname: String
    var userLname: String
    var password: String
    var newPassword: String
    var verificationCode: String

    var clientId: String
    var discoveryEndpoint: String
    var scopes: [String]
    var redirectUri: String
    var acrValues: String
    var configPlistFileName: String?

    // Device Authorization Grant (RFC 8628) — requesting-device OIDC client
    var deviceClientId: String = ""

    // Device Authorization Grant — shared test credentials
    var deviceUsername: String = ""
    var devicePassword: String = ""

    // Feature-specific ACR values — optional; tests fall back to the main acrValues if empty
    var mfaDeviceAcrValues: String = ""
    var formFieldsAcrValues: String = ""
    var pollingAcrValues: String = ""
    var metadataAcrValues: String = ""
    var imageAcrValues: String = ""

    var configJSON: [String: Any]?

    override init() {
        username = ""
        userFname = ""
        userLname = ""
        password = ""
        newPassword = ""
        verificationCode = ""

        clientId = ""
        discoveryEndpoint = ""
        scopes = []
        redirectUri = ""
        acrValues = ""
    }


    init(_ configFileName: String) throws {

        username = ""
        userFname = ""
        userLname = ""
        password = ""
        newPassword = ""
        verificationCode = ""

        clientId = ""
        discoveryEndpoint = ""
        scopes = []
        redirectUri = ""
        acrValues = ""

        if let path = Bundle(for: DaVinciTests.self).path(forResource: configFileName, ofType: "json") {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            guard let config = jsonResult as? [String: Any] else {
                throw ConfigError.invalidConfiguration("\(configFileName) is not a valid JSON object")
            }
            self.configJSON = config

            // Required fields: throw if absent or wrong type; null is allowed and
            // treated as "not configured" — DaVinciBaseTests will skip via XCTSkip.
            self.username          = try Self.requiredString("username",          from: config)
            self.userFname         = try Self.requiredString("userFname",         from: config)
            self.userLname         = try Self.requiredString("userLname",         from: config)
            self.password          = try Self.requiredString("password",          from: config)
            self.newPassword       = try Self.requiredString("newPassword",       from: config)
            self.verificationCode  = try Self.requiredString("verificationCode",  from: config)

            if let configPlistFileName = config["configPlistFileName"] as? String {
                self.configPlistFileName = configPlistFileName
            }

            self.clientId           = try Self.requiredString("clientId",           from: config)
            self.discoveryEndpoint  = try Self.requiredString("discoveryEndpoint",  from: config)
            let scopesRaw           = try Self.requiredString("scopes",             from: config)
            self.scopes = scopesRaw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            self.redirectUri        = try Self.requiredString("redirectUri",        from: config)
            self.acrValues          = try Self.requiredString("acrValues",          from: config)

            // Device Authorization Grant fields — optional
            self.deviceClientId = config["deviceClientId"] as? String ?? ""
            self.deviceUsername = config["deviceUsername"] as? String ?? ""
            self.devicePassword = config["devicePassword"] as? String ?? ""

            // Feature-specific ACR values — fall back to main acrValues when missing or empty
            self.mfaDeviceAcrValues = (config["mfaDeviceAcrValues"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? self.acrValues
            self.formFieldsAcrValues = (config["formFieldsAcrValues"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? self.acrValues
            self.pollingAcrValues = (config["pollingAcrValues"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? self.acrValues
            self.metadataAcrValues = (config["metadataAcrValues"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? self.acrValues
            self.imageAcrValues = (config["imageAcrValues"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? self.acrValues
        }
        else {
            throw ConfigError.emptyConfiguration
        }
    }

    // Throws .notConfigured for JSON null (placeholder mode); throws .invalidConfiguration
    // for a missing key or wrong type.
    private static func requiredString(_ key: String, from config: [String: Any]) throws -> String {
        guard let value = config[key] else {
            throw ConfigError.invalidConfiguration("Required field '\(key)' is missing from test configuration")
        }
        if value is NSNull { throw ConfigError.notConfigured }
        guard let string = value as? String else {
            throw ConfigError.invalidConfiguration("Field '\(key)' must be a string")
        }
        return string
    }
}
