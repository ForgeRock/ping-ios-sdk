/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import XCTest
@testable import PingFido

class FidoAuthenticationCollectorTests: XCTestCase {

    var collector: FidoAuthenticationCollector!
    
    override func setUp() {
        super.setUp()
        let json: [String: Any] = [
            "type": "FidoAuthenticationCollector",
            "name": "fidoAuth",
            "label": "Authenticate with FIDO",
            "publicKeyCredentialRequestOptions": [
                "challenge": "someChallenge"
            ]
        ]
        collector = FidoAuthenticationCollector(with: json)
    }

    func testCloseShouldClearAssertionValue() {
        collector.assertionValue = ["test": "value"]
        
        XCTAssertNotNil(collector.payload())
        
        collector.close()
        
        XCTAssertNil(collector.payload())
    }
    
    func testCloseShouldAllowReuse() {
        let assertion1 = ["test": "value1"]
        let assertion2 = ["test": "value2"]
        
        collector.assertionValue = assertion1
        var payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["assertionValue"] as? [String: String], assertion1)
        
        collector.close()
        XCTAssertNil(collector.payload())
        
        collector.assertionValue = assertion2
        payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["assertionValue"] as? [String: String], assertion2)
    }
}
