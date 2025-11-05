//
//  Config.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

@testable import PingJourney

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
    var serverUrl: String
    var cookieName: String
    var realm: String
    
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
        serverUrl = ""
        cookieName = ""
        realm = ""
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
        serverUrl = ""
        cookieName = ""
        realm = ""
        
        if let path = Bundle(for: JourneyTests.self).path(forResource: configFileName, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                if let config = jsonResult as? [String: Any] {
                    self.configJSON = config
                    guard let username = config["username"] as? String,
                          let userFname = config["userFname"] as? String,
                          let userLname = config["userLname"] as? String,
                          let password = config["password"] as? String,
                          let newPassword = config["newPassword"] as? String,
                          let verificationCode = config["verificationCode"] as? String
                    else {
                        throw ConfigError.invalidConfiguration("Test config data is empty or invalid")
                    }
                    
                    self.username = username
                    self.userFname = userFname
                    self.userLname = userLname
                    self.password = password
                    self.newPassword = newPassword
                    self.verificationCode = verificationCode
                    
                    if let configPlistFileName = config["configPlistFileName"] as? String {
                        self.configPlistFileName = configPlistFileName
                    }
                                                            
                    guard let clientId = config["clientId"] as? String,
                          let discoveryEndpoint = config["discoveryEndpoint"] as? String,
                          let scopes = config["scopes"] as? String,
                          let redirectUri = config["redirectUri"] as? String,
                          let acrValues = config["acrValues"] as? String,
                          let serverUrl = config["serverUrl"] as? String,
                          let realm = config["realm"] as? String,
                          let cookieName = config["cookieName"] as? String
                    else {
                        throw ConfigError.invalidConfiguration("Test DV config data is empty or invalid")
                    }
                    
                    self.clientId = clientId
                    self.discoveryEndpoint = discoveryEndpoint
                    self.scopes = scopes
                      .components(separatedBy: .whitespaces)
                      .filter { !$0.isEmpty }
                    self.redirectUri = redirectUri
                    self.acrValues = acrValues
                    self.serverUrl = serverUrl
                    self.realm = realm
                    self.cookieName = cookieName
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
