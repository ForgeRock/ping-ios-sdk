/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import XCTest
@testable import PingFido

class FidoRegistrationCollectorTests: XCTestCase {

    var collector: FidoRegistrationCollector!
    
    override func setUp() {
        super.setUp()
        let json: [String: Any] = [
            "type": "FidoRegistrationCollector",
            "name": "fidoReg",
            "label": "Register with FIDO",
            "publicKeyCredentialCreationOptions": [
                "challenge": "someChallenge"
            ]
        ]
        collector = FidoRegistrationCollector(with: json)
    }

    func testCloseShouldClearAttestationValue() {
        collector.attestationValue = ["test": "value"]
        
        XCTAssertNotNil(collector.payload())
        
        collector.close()
        
        XCTAssertNil(collector.payload())
    }
    
    func testCloseShouldAllowReuse() {
        let attestation1 = ["test": "value1"]
        let attestation2 = ["test": "value2"]
        
        collector.attestationValue = attestation1
        var payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["attestationValue"] as? [String: String], attestation1)
        
        collector.close()
        XCTAssertNil(collector.payload())
        
        collector.attestationValue = attestation2
        payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["attestationValue"] as? [String: String], attestation2)
    }
}
