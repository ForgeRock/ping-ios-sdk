//
//  DaVinciBaseTests.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest

class DaVinciBaseTests: XCTestCase, @unchecked Sendable {
    var config: Config = Config()
    var configFileName: String = ""
    
    override func setUp() {
        super.setUp()
        if self.configFileName.count > 0 {
            do {
                self.config = try Config(self.configFileName)
            } catch ConfigError.notConfigured {
                // Required auth fields are null placeholders; individual tests will skip via their guards
            } catch {
                XCTFail("Failed to load test configuration file: \(error)")
            }
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        if self.configFileName.count > 0 {
            do {
                self.config = try Config(self.configFileName)
            } catch ConfigError.notConfigured {
                throw XCTSkip("Integration test skipped: real DaVinci configuration not available")
            }
        }
    }
}
