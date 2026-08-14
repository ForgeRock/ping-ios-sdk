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
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                if let config = jsonResult as? [String: Any] {
                    self.configJSON = config
                    self.username = config["username"] as? String ?? ""
                    self.userFname = config["userFname"] as? String ?? ""
                    self.userLname = config["userLname"] as? String ?? ""
                    self.password = config["password"] as? String ?? ""
                    self.newPassword = config["newPassword"] as? String ?? ""
                    self.verificationCode = config["verificationCode"] as? String ?? ""

                    if let configPlistFileName = config["configPlistFileName"] as? String {
                        self.configPlistFileName = configPlistFileName
                    }

                    self.clientId = config["clientId"] as? String ?? ""
                    self.discoveryEndpoint = config["discoveryEndpoint"] as? String ?? ""
                    let scopes = config["scopes"] as? String ?? ""
                    self.scopes = scopes
                      .components(separatedBy: .whitespaces)
                      .filter { !$0.isEmpty }
                    self.redirectUri = config["redirectUri"] as? String ?? ""
                    self.acrValues = config["acrValues"] as? String ?? ""

                    // Device Authorization Grant fields are optional — tests that don't
                    // exercise device flow simply read empty strings from the config.
                    self.deviceClientId = config["deviceClientId"] as? String ?? ""
                    self.deviceUsername = config["deviceUsername"] as? String ?? ""
                    self.devicePassword = config["devicePassword"] as? String ?? ""

                    // Feature-specific ACR values — optional
                    self.mfaDeviceAcrValues = config["mfaDeviceAcrValues"] as? String ?? ""
                    self.formFieldsAcrValues = config["formFieldsAcrValues"] as? String ?? ""
                    self.pollingAcrValues = config["pollingAcrValues"] as? String ?? ""
                    self.metadataAcrValues = config["metadataAcrValues"] as? String ?? ""
                    self.imageAcrValues = config["imageAcrValues"] as? String ?? ""
                }
                else {
                    throw ConfigError.invalidConfiguration("\(configFileName) is invalid or missing some value")
                }
            } catch {
                throw error
            }
        }
        else {
            throw ConfigError.emptyConfiguration
        }
    }
}
