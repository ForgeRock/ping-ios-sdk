//
//  DaVinciTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

final class DaVinciTests: DaVinciBaseTests, @unchecked Sendable {
    var davinci: DaVinci?
    
    let testClientId = "test"
    let testScopes = ["openid", "email", "address"]
    let testRedirectUri = "http://localhost:8080"
    let testDiscoveryEndpoint = "http://localhost/.well-known/openid-configuration"
    
    override func setUp() {
        self.configFileName = "Config"
        super.setUp()
        
        self.davinci = DaVinci.createDaVinci { config in
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
        
        MockURLProtocol.startInterceptingRequests()
        _ = CollectorFactory()
        
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.token.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.token.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.tokenResponse)
            case MockAPIEndpoint.userinfo.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.userinfo.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.userinfoResponse)
            case MockAPIEndpoint.revocation.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.revocation.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            case MockAPIEndpoint.endSession.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.endSession.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, Data())
            case MockAPIEndpoint.customHTMLTemplate.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.customHTMLTemplate.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.customHTMLTemplateHeaders)!, MockResponse.customHTMLTemplate)
            case MockAPIEndpoint.authorization.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.authorizeResponseHeaders)!, MockResponse.authorizeResponse)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }
    
    func testDaVinci() throws {
        guard let davinci = self.davinci else {
            XCTFail("Failed to create DaVinci instance")
            return
        }
        
        XCTAssertEqual(davinci.config.modules.count, 5)
        XCTAssertEqual(davinci.initHandlers.count, 2)
        XCTAssertEqual(davinci.nextHandlers.count, 2)
        XCTAssertEqual(davinci.nodeHandlers.count, 1)
        XCTAssertEqual(davinci.responseHandlers.count, 1)
        XCTAssertEqual(davinci.signOffHandlers.count, 2)
        XCTAssertEqual(davinci.successHandlers.count, 1)
        
        let nosession = Module.of { setup in
            setup.next { ( context,connector, request) in
                request.header(name: "nosession", value: "true")
                return request
            }
        }
        
        let davinci1 = DaVinci.createDaVinci { config in
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
            
            config.module(nosession)
        }
        
        XCTAssertEqual(davinci1.config.modules.count, 6)
        XCTAssertEqual(davinci1.initHandlers.count, 2)
        XCTAssertEqual(davinci1.nextHandlers.count, 3)
        XCTAssertEqual(davinci1.nodeHandlers.count, 1)
        XCTAssertEqual(davinci1.responseHandlers.count, 1)
        XCTAssertEqual(davinci1.signOffHandlers.count, 2)
        XCTAssertEqual(davinci1.successHandlers.count, 1)
    }
    
    
    func testDaVinciDefaultModuleSequence() async throws {
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        XCTAssertEqual(5, daVinci.config.modules.count)
        let list = daVinci.config.modules
        XCTAssertTrue(list[0].config is CustomHeaderConfig)
        XCTAssertTrue(list[1].config is Void)
        XCTAssertTrue(list[2].config is Void)
        XCTAssertTrue(list[3].config is OidcClientConfig)
        XCTAssertTrue(list[4].config is CookieConfig)
        
    }
    
    func testDaVinciSimpleHappyPath() async throws {
        let tokenStorage = MemoryStorage<Token>()
        let cookieStorage = MemoryStorage<[CustomHTTPCookie]>()
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = tokenStorage
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = cookieStorage
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        let continueNode = node as! ContinueNode
        XCTAssertEqual(continueNode.collectors.count, 5)
        
        XCTAssertEqual(continueNode.id, "cq77vwelou")
        XCTAssertEqual(continueNode.name, "Username/Password Form")
        XCTAssertEqual(continueNode.description, "Test Description")
        XCTAssertEqual(continueNode.category, "CUSTOM_HTML")
        
        (continueNode.collectors[0] as? TextCollector)?.value = "My First Name"
        (continueNode.collectors[1] as? PasswordCollector)?.value = "My Password"
        (continueNode.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode)
        
        let authorizeReq = MockURLProtocol.requestHistory[1]
        XCTAssertTrue(authorizeReq.url!.query?.contains("client_id=test") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("response_mode=pi.flow") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("code_challenge_method=S256") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("code_challenge=") ?? false)
        XCTAssertTrue(authorizeReq.url!.query?.contains("redirect_uri=") ?? false)
        
        let request = MockURLProtocol.requestHistory[2]
        //let result = request.httpBody as! TextContent
        //            let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        //            XCTAssertEqual(json["eventName"] as? String, "continue")
        //            let parameters = json["parameters"] as! [String: Any]
        //            let data = parameters["data"] as! [String: Any]
        //            XCTAssertEqual(data["actionKey"] as? String, "SIGNON")
        //            let formData = data["formData"] as! [String: Any]
        //            XCTAssertEqual(formData["username"] as? String, "My First Name")
        //            XCTAssertEqual(formData["password"] as? String, "My Password")
        
        XCTAssertEqual(request.allHTTPHeaderFields!["x-requested-with"], "ping-sdk")
        XCTAssertEqual(request.allHTTPHeaderFields!["x-requested-platform"], "ios")
        XCTAssertTrue(request.allHTTPHeaderFields!["Cookie"]?.contains("interactionId") ?? false)
        //XCTAssertTrue(request.allHTTPHeaderFields!["Cookie"]?.contains("interactionToken") ?? false)
        //XCTAssertTrue(request.allHTTPHeaderFields!["Cookie"]?.contains("skProxyApiEnvironmentId") ?? false)
        
        let successNode = node as! SuccessNode
        let user = successNode.user
        let userToken = await user?.token()
        switch userToken! {
        case .success(let token):
            XCTAssertEqual(token.accessToken, "Dummy AccessToken")
            break
        case .failure(_):
            XCTFail("Should have succeeded")
        }
        //            XCTAssertEqual((user?.token() as? Result.Success)?.value.accessToken, "Dummy AccessToken")
        
        let u = await daVinci.daVinciUser()
        await u?.logout()
        let revoke = MockURLProtocol.requestHistory[4]
        XCTAssertEqual(revoke.url!.absoluteString, "https://auth.test-one-pingone.com/revoke")
        //            let revokeBody =  try JSONSerialization.jsonObject(with: revoke.httpBody!) as! [String: Any]
        //            XCTAssertEqual(revokeBody["client_id"] as? String, "test")
        //            XCTAssertEqual(revokeBody["token"] as? String, "Dummy RefreshToken")
        
        let signOff = MockURLProtocol.requestHistory[5]
        XCTAssertEqual(signOff.url!.absoluteString, "https://auth.test-one-pingone.com/signoff?id_token_hint=Dummy%20IdToken&client_id=test")
        XCTAssertTrue(signOff.allHTTPHeaderFields!["Cookie"]?.contains("ST=session_token") ?? false)
        
        let storedToken = try await tokenStorage.get()
        XCTAssertNil(storedToken)
        let storedCokie = try await cookieStorage.get()
        XCTAssertNil(storedCokie)
        let storedUser = await daVinci.daVinciUser()
        XCTAssertNil(storedUser)
    }
    
    func testDaVinciAdditionOidcParameter() async throws {
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage =  MemoryStorage()
                oidcValue.logger = LogManager.standard
                oidcValue.acrValues = "acrValues"
                oidcValue.display = "display"
                oidcValue.loginHint = "login_hint"
                oidcValue.nonce = "nonce"
                oidcValue.prompt = "prompt"
                oidcValue.uiLocales = "ui_locales"
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        let connector = node as! ContinueNode
        (connector.collectors[0] as? TextCollector)?.value = "My First Name"
        (connector.collectors[1] as? PasswordCollector)?.value = "My Password"
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is SuccessNode)
        
        let authorizeReq = MockURLProtocol.requestHistory[1]
        XCTAssertTrue(authorizeReq.url?.query?.contains("client_id=test") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("response_mode=pi.flow") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("code_challenge_method=S256") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("code_challenge=") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("redirect_uri=http://localhost:8080") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("acr_values=acrValues") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("display=display") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("login_hint=login_hint") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("nonce=nonce") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("prompt=prompt") ?? false)
        XCTAssertTrue(authorizeReq.url?.query?.contains("ui_locales=ui_locales") ?? false)
    }
    
    func testDaVinciRevokeAccessToken() async throws {
        let tokenStorage = MemoryStorage<Token>()
        let cookieStorage = MemoryStorage<[CustomHTTPCookie]>()
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = tokenStorage
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = cookieStorage
                cookieValue.persist = ["ST"]
            }
        }
        
        var node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        let connector = node as! ContinueNode
        (connector.collectors[0] as? TextCollector)?.value = "My First Name"
        (connector.collectors[1] as? PasswordCollector)?.value = "My Password"
        (connector.collectors[2] as? SubmitCollector)?.value = "click me"
        
        node = await connector.next()
        XCTAssertTrue(node is SuccessNode)
        
        let u = await daVinci.daVinciUser()
        await u?.revoke()
        let storedToken = try await tokenStorage.get()
        XCTAssertNil(storedToken)
        let storedCokie = try await cookieStorage.get()
        XCTAssertNotNil(storedCokie)
    }
    
    func testDaVinciCollectorsParsing() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfigurationResponse)
            case MockAPIEndpoint.authorization.url.path:
                let headers = MockResponse.authorizeResponseHeaders
                return (HTTPURLResponse(url: MockAPIEndpoint.authorization.url, statusCode: 200, httpVersion: nil, headerFields: headers)!, MockResponse.responseWithBasicTypes)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        
        let daVinci = DaVinci.createDaVinci { config in
            config.httpClient = HttpClient(session: .shared)
            
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = self.testClientId
                oidcValue.scopes = Set(self.testScopes)
                oidcValue.redirectUri = self.testRedirectUri
                oidcValue.discoveryEndpoint = self.testDiscoveryEndpoint
                oidcValue.storage = MemoryStorage()
                oidcValue.logger = LogManager.standard
            }
            
            config.module(CookieModule.config) { cookieValue in
                cookieValue.cookieStorage = MemoryStorage()
                cookieValue.persist = ["ST"]
            }
        }
        
        let node = await daVinci.start()
        XCTAssertTrue(node is ContinueNode)
        let continueNode = node as! ContinueNode
        XCTAssertEqual(continueNode.collectors.count, 11)
        
        guard let collector1 = (continueNode.collectors[0] as? LabelCollector) else {
            XCTFail("LabelCollector is nil")
            return
        }
        XCTAssertEqual(collector1.content, "Sign On")
        
        guard let collector2 = (continueNode.collectors[1] as? LabelCollector) else {
            XCTFail("LabelCollector is nil")
            return
        }
        XCTAssertEqual(collector2.content, "Welcome to Ping Identity")
        
        guard let collector3 = (continueNode.collectors[2] as? TextCollector) else {
            XCTFail("TextCollector is nil")
            return
        }
        XCTAssertEqual(collector3.type, "TEXT")
        XCTAssertEqual(collector3.key, "user.username")
        XCTAssertEqual(collector3.label, "Username")
        XCTAssertEqual(collector3.required, true)
        XCTAssertEqual(collector3.validation?.regex?.pattern, ".")
        XCTAssertEqual(collector3.validation?.errorMessage, "Must be valid email address")
        XCTAssertEqual(collector3.value, "default-username")
        
        guard let collector4 = (continueNode.collectors[3] as? PasswordCollector) else {
            XCTFail("PasswordCollector is nil")
            return
        }
        XCTAssertEqual(collector4.type, "PASSWORD")
        XCTAssertEqual(collector4.key, "password")
        XCTAssertEqual(collector4.label, "Password")
        XCTAssertEqual(collector4.required, true)
        XCTAssertEqual(collector4.value, "default-password")
        
        guard let collector5 = (continueNode.collectors[4] as? SubmitCollector) else {
            XCTFail("SubmitCollector is nil")
            return
        }
        XCTAssertEqual(collector5.type, "SUBMIT_BUTTON")
        XCTAssertEqual(collector5.key, "submit")
        XCTAssertEqual(collector5.label, "Sign On")
        
        guard let collector6 = (continueNode.collectors[5] as? FlowCollector) else {
            XCTFail("FlowCollector is nil")
            return
        }
        XCTAssertEqual(collector6.type, "FLOW_LINK")
        XCTAssertEqual(collector6.key, "register")
        XCTAssertEqual(collector6.label, "No account? Register now!")
        
        guard let collector7 = (continueNode.collectors[6] as? FlowCollector) else {
            XCTFail("FlowCollector is nil")
            return
        }
        XCTAssertEqual(collector7.type, "FLOW_LINK")
        XCTAssertEqual(collector7.key, "trouble")
        XCTAssertEqual(collector7.label, "Having trouble signing on?")
        
        guard let collector8 = (continueNode.collectors[7] as? SingleSelectCollector) else {
            XCTFail("SingleSelectCollector is nil")
            return
        }
        XCTAssertEqual(collector8.type, "DROPDOWN")
        XCTAssertEqual(collector8.key, "dropdown-field")
        XCTAssertEqual(collector8.label, "Dropdown")
        XCTAssertEqual(collector8.required, true)
        XCTAssertEqual(collector8.options.count, 3)
        XCTAssertEqual(collector8.value, "default-dropdown")
        
        guard let collector9 = (continueNode.collectors[8] as? MultiSelectCollector) else {
            XCTFail("MultiSelectCollector is nil")
            return
        }
        XCTAssertEqual(collector9.type, "COMBOBOX")
        XCTAssertEqual(collector9.key, "combobox-field")
        XCTAssertEqual(collector9.label, "Combobox")
        XCTAssertEqual(collector9.required, true)
        XCTAssertEqual(collector9.options.count, 2)
        XCTAssertEqual(collector9.value, ["default-combobox"])
        
        guard let collector10 = (continueNode.collectors[9] as? SingleSelectCollector) else {
            XCTFail("MultiSelectCollector is nil")
            return
        }
        XCTAssertEqual(collector10.type, "RADIO")
        XCTAssertEqual(collector10.key, "radio-field")
        XCTAssertEqual(collector10.label, "Radio")
        XCTAssertEqual(collector10.required, true)
        XCTAssertEqual(collector10.options.count, 2)
        XCTAssertEqual(collector10.value, "default-radio")
        
        guard let collector11 = (continueNode.collectors[10] as? MultiSelectCollector) else {
            XCTFail("SingleSelectCollector is nil")
            return
        }
        XCTAssertEqual(collector11.type, "CHECKBOX")
        XCTAssertEqual(collector11.key, "checkbox-field")
        XCTAssertEqual(collector11.label, "Checkbox")
        XCTAssertEqual(collector11.required, true)
        XCTAssertEqual(collector11.options.count, 2)
        XCTAssertEqual(collector11.value, ["default-checkbox"])
    }
}
