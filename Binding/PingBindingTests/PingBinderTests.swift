//
//  PingBinderTests.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBinding
@testable import PingJourneyPlugin
import PingStorage

class PingBinderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Task {
            let storage = KeychainStorage<[UserKey]>(account: "testKeys", encryptor: NoEncryptor())
            let config = UserKeyStorageConfig(storage: storage)
            let userKeyStorage = UserKeysStorage(config: config)
            try? await userKeyStorage.deleteAll()
        }
    }
    
    override func tearDown() {
        super.tearDown()
        Task {
            let storage = KeychainStorage<[UserKey]>(account: "testKeys", encryptor: NoEncryptor())
            let config = UserKeyStorageConfig(storage: storage)
            let userKeyStorage = UserKeysStorage(config: config)
            try? await userKeyStorage.deleteAll()
        }
    }

    func testBind() async throws {
        let jsonString = """
                {"type":"DeviceBindingCallback","output":[{"name":"userId","value":"id=8ae8fada-3663-4d37-87c3-f3286d9cb75b,ou=user,o=alpha,ou=services,ou=am-config"},{"name":"username","value":"gbafal"},{"name":"authenticationType","value":"NONE"},{"name":"challenge","value":"AZrz80IwNkYoXMcmlEBZa29mRwwsGI/PkJb6xLRAZVo="},{"name":"title","value":"Authentication required"},{"name":"subtitle","value":"Cryptography device binding"},{"name":"description","value":"Please complete with biometric to proceed"},{"name":"timeout","value":60},{"name":"attestation","value":true}],"input":[{"name":"IDToken1jws","value":""},{"name":"IDToken1deviceName","value":""},{"name":"IDToken1deviceId","value":""},{"name":"IDToken1clientError","value":""}]}
        """
        let data = jsonString.toDictionary()!
        let callback = await DeviceBindingCallback().initialize(with: data) as! DeviceBindingCallback
        
        // When
        let jws = try await Binding.bind(callback: callback, journey: nil) { config in
            let storage = KeychainStorage<[UserKey]>(account: "testKeys", encryptor: NoEncryptor())
            config.userKeyStorage = UserKeyStorageConfig(storage: storage)
        }
        
        // Then
        XCTAssertNotNil(jws)
        
        let callbackJws = (callback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == "IDToken1jws" })?["value"]
        XCTAssertNotNil(callbackJws)
        XCTAssertEqual(jws, callbackJws as? String)
    }
    
    func testSign() async throws {
        let jsonString = """
                {"type":"DeviceBindingCallback","output":[{"name":"userId","value":"id=8ae8fada-3663-4d37-87c3-f3286d9cb75b,ou=user,o=alpha,ou=services,ou=am-config"},{"name":"username","value":"gbafal"},{"name":"authenticationType","value":"NONE"},{"name":"challenge","value":"AZrz80IwNkYoXMcmlEBZa29mRwwsGI/PkJb6xLRAZVo="},{"name":"title","value":"Authentication required"},{"name":"subtitle","value":"Cryptography device binding"},{"name":"description","value":"Please complete with biometric to proceed"},{"name":"timeout","value":60},{"name":"attestation","value":true}],"input":[{"name":"IDToken1jws","value":""},{"name":"IDToken1deviceName","value":""},{"name":"IDToken1deviceId","value":""},{"name":"IDToken1clientError","value":""}]}
        """
        let data = jsonString.toDictionary()!
        let bindCallback = await DeviceBindingCallback().initialize(with: data) as! DeviceBindingCallback
        
        let signJsonString = """
                {"type":"DeviceSigningVerifierCallback","output":[{"name":"userId","value":"id=8ae8fada-3663-4d37-87c3-f3286d9cb75b,ou=user,o=alpha,ou=services,ou=am-config"},{"name":"challenge","value":"gSP9Qx1tIfj7a/ryMwl4jVWOZRkKErMFyQz8KAWtLdo="},{"name":"title","value":"Authentication required"},{"name":"subtitle","value":"Cryptography device binding"},{"name":"description","value":"Please complete with biometric to proceed"},{"name":"timeout","value":60}],"input":[{"name":"IDToken1jws","value":""},{"name":"IDToken1clientError","value":""}]}
        """
        let signData = signJsonString.toDictionary()!
        let signCallback = await DeviceSigningVerifierCallback().initialize(with: signData) as! DeviceSigningVerifierCallback
        
        // Given - Bind first
        _ = try await Binding.bind(callback: bindCallback, journey: nil) { config in
            let storage = KeychainStorage<[UserKey]>(account: "testKeys", encryptor: NoEncryptor())
            config.userKeyStorage = UserKeyStorageConfig(storage: storage)
        }
        
        // When - Sign
        let jws = try await Binding.sign(callback: signCallback, journey: nil) { config in
            let storage = KeychainStorage<[UserKey]>(account: "testKeys", encryptor: NoEncryptor())
            config.userKeyStorage = UserKeyStorageConfig(storage: storage)
        }
        
        // Then
        XCTAssertNotNil(jws)
        
        let callbackJws = (signCallback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == "IDToken1jws" })?["value"]
        XCTAssertNotNil(callbackJws)
        XCTAssertEqual(jws, callbackJws as? String)
    }
}

extension String {
    func toDictionary() -> [String: Any]? {
        if let data = self.data(using: .utf8) {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        return nil
    }
}
