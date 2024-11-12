//
//  DaVinciIntegrationTests.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate
@testable import Logger
@testable import PingOidc
@testable import Storage
@testable import PingDavinci

class DaVinciIntegrationTests: XCTestCase {
    
    private var daVinci: DaVinci!
    private var username: String!
    private var password: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        username = "iosclient"
        password = "Connector123!"
        
        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "a9cf6b4c-8669-4dee-8b97-7c703752c04f"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
            }
            
        }
        
        // Start with a clean session
        await daVinci.user()?.logout()
    }
    
    func testHappyPathWithPasswordCredentials() async throws {
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var connector = node as! ContinueNode
        
        XCTAssertEqual(connector.collectors.count, 1)
        let collector = connector.collectors[0] as! TextCollector
        XCTAssertEqual("protectsdk", collector.key)
        XCTAssertEqual("Protect Payload", collector.label)
        
        node = await connector.next()
        XCTAssertEqual((node as! ContinueNode).collectors.count, 5)
        connector = node as! ContinueNode
        
        (connector.collectors[0] as? TextCollector)?.value = username
        (connector.collectors[1] as? PasswordCollector)?.value = password
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        XCTAssertTrue(connector.collectors[3] is FlowCollector)
        XCTAssertTrue(connector.collectors[4] is FlowCollector)
        
        node = await connector.next()
        XCTAssertTrue(node is ContinueNode)
        connector = node as! ContinueNode
      
      (connector.collectors[0] as? SubmitCollector)?.value = "click me"
      
       node = await connector.next()
      
       let successNode = node as! SuccessNode
        
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertNotNil(token.accessToken)
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        
        let u = await daVinci.user()
        await u?.logout() ?? { XCTFail("User is null") }()
        
        // After logout make sure the user is null
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
    }
    
    func testHappyPathWithNoAccount() async throws {
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var connector = node as! ContinueNode
        
        XCTAssertEqual(connector.collectors.count, 1)
        let collector = connector.collectors[0] as! TextCollector
        XCTAssertEqual("protectsdk", collector.key)
        XCTAssertEqual("Protect Payload", collector.label)
        
        node =  await connector.next()
        XCTAssertEqual((node as! ContinueNode).collectors.count, 5)
        connector = node as! ContinueNode
        
        (connector.collectors[0] as? TextCollector)?.value = username
        (connector.collectors[1] as? PasswordCollector)?.value = password
        XCTAssertTrue(connector.collectors[2] is SubmitCollector)
        XCTAssertTrue(connector.collectors[3] is FlowCollector)
        (connector.collectors[4] as? FlowCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is ContinueNode)
        connector = node as! ContinueNode
        
        // Registration Form
        XCTAssertEqual(6, connector.collectors.count)
        XCTAssertEqual("First Name", (connector.collectors[0] as! TextCollector).label)
        XCTAssertEqual("Last Name", (connector.collectors[1] as! TextCollector).label)
        XCTAssertEqual("Email", (connector.collectors[2] as! TextCollector).label)
        XCTAssertEqual("Password", (connector.collectors[3] as! PasswordCollector).label)
        XCTAssertEqual("Save", (connector.collectors[4] as! SubmitCollector).label)
        XCTAssertEqual("Already have an account? Sign on", (connector.collectors[5] as! FlowCollector).label)
    }
    
    func testInvalidPassword() async throws {
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        var connector = node as! ContinueNode
        
        XCTAssertEqual(connector.collectors.count, 1)
        let collector = connector.collectors[0] as! TextCollector
        XCTAssertEqual("protectsdk", collector.key)
        XCTAssertEqual("Protect Payload", collector.label)
        
        node = await connector.next()
        connector = node as! ContinueNode
        
        (connector.collectors[0] as? TextCollector)?.value = username
        (connector.collectors[1] as? PasswordCollector)?.value = "invalid"
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is ErrorNode)
        let errorNode = node as! ErrorNode
        XCTAssertNotNil(errorNode.input)
        
        XCTAssertEqual("Invalid username and/or password", errorNode.message.trimmingCharacters(in: .whitespaces))
        
        let daVinciUser = await daVinci.user()
        XCTAssertNil(daVinciUser)
    }
}
