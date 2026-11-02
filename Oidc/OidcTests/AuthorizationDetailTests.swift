//
//  AuthorizationDetailTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOidc

final class AuthorizationDetailTests: XCTestCase {

    func testEncodingDecodingRoundTrip() throws {
        let detail = AuthorizationDetail(
            type: "payment_initiation",
            locations: ["https://example.com/payments"],
            actions: ["initiate"],
            additionalFields: [
                "instructedAmount": .object(["currency": .string("EUR"), "amount": .string("123.50")]),
                "creditorName": .string("Merchant A")
            ]
        )

        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(AuthorizationDetail.self, from: data)

        XCTAssertEqual(decoded, detail)
    }

    func testCatchAllFieldFidelity() throws {
        let json = """
        {
          "type": "account_information",
          "actions": ["list_accounts", "read_balances"],
          "datatypes": ["balances"],
          "isReadOnly": true,
          "maxAmount": 42.5,
          "note": "some text",
          "extra": null,
          "nested": {"a": "b"},
          "list": [1, 2, 3]
        }
        """
        let decoded = try JSONDecoder().decode(AuthorizationDetail.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.type, "account_information")
        XCTAssertEqual(decoded.actions, ["list_accounts", "read_balances"])
        XCTAssertEqual(decoded.datatypes, ["balances"])
        XCTAssertEqual(decoded.additionalFields["isReadOnly"], .bool(true))
        XCTAssertEqual(decoded.additionalFields["maxAmount"], .double(42.5))
        XCTAssertEqual(decoded.additionalFields["note"], .string("some text"))
        XCTAssertEqual(decoded.additionalFields["extra"], .null)
        XCTAssertEqual(decoded.additionalFields["nested"], .object(["a": .string("b")]))
        XCTAssertEqual(decoded.additionalFields["list"], .array([.double(1), .double(2), .double(3)]))

        // Re-encode and decode again: catch-all fields survive a full round trip.
        let reencoded = try JSONEncoder().encode(decoded)
        let roundTripped = try JSONDecoder().decode(AuthorizationDetail.self, from: reencoded)
        XCTAssertEqual(roundTripped, decoded)
    }

    func testWireValueIsDeterministicallyOrdered() throws {
        let details = [
            AuthorizationDetail(type: "payment_initiation", additionalFields: ["b": .string("2"), "a": .string("1")]),
            AuthorizationDetail(type: "account_information")
        ]

        let first = try AuthorizationDetail.wireValue(details)
        let second = try AuthorizationDetail.wireValue(details)

        XCTAssertEqual(first, second, "wireValue must be deterministic (.sortedKeys) for stable test assertions and PAR-body comparisons")
        XCTAssertTrue(first.contains("payment_initiation"))
        XCTAssertTrue(first.contains("account_information"))

        // And it decodes back losslessly.
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(first.utf8))
        XCTAssertEqual(decoded, details)
    }

    func testAnyBridgeInitializer() {
        XCTAssertEqual(AuthorizationDetailValue(any: "hello"), .string("hello"))
        XCTAssertEqual(AuthorizationDetailValue(any: true), .bool(true))
        XCTAssertEqual(AuthorizationDetailValue(any: false), .bool(false))
        XCTAssertEqual(AuthorizationDetailValue(any: 42.0), .double(42.0))
        // JSON numbers 0 and 1 arrive from JSONSerialization as NSNumber and bridge to Bool
        // successfully — they must classify as numbers, not booleans.
        XCTAssertEqual(AuthorizationDetailValue(any: 0), .double(0.0))
        XCTAssertEqual(AuthorizationDetailValue(any: 1), .double(1.0))
        XCTAssertEqual(AuthorizationDetailValue(any: NSNull()), .null)
        XCTAssertEqual(AuthorizationDetailValue(any: ["k": "v"]), .object(["k": .string("v")]))
        XCTAssertEqual(AuthorizationDetailValue(any: ["a", "b"]), .array([.string("a"), .string("b")]))
    }

    /// The exact regression the 0/1 test above guards: a JSONSerialization-produced array
    /// containing integer 1 must round-trip as a number, not `true`.
    func testAnyBridgeThroughJSONSerializationClassifiesNumbersAsNumbers() throws {
        let json = try JSONSerialization.jsonObject(with: Data("[{\"type\":\"x\",\"quantity\":1,\"flag\":true,\"zero\":0}]".utf8))
        let array = try XCTUnwrap(json as? [Any])
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: try JSONSerialization.data(withJSONObject: array))
        XCTAssertEqual(decoded[0].additionalFields["quantity"], .double(1.0))
        XCTAssertEqual(decoded[0].additionalFields["flag"], .bool(true))
        XCTAssertEqual(decoded[0].additionalFields["zero"], .double(0.0))
    }

    /// JSON numbers 0/1 decoded directly through JSONDecoder must classify as numbers
    /// (`.double`), not booleans — guards the Double-before-Bool ordering in
    /// `AuthorizationDetailValue.init(from:)` (the Codable mirror of the `init(any:)`
    /// JSONSerialization trap).
    func testCodableDecodeClassifiesJSONNumbersAsNumbers() throws {
        let json = """
        {"type": "x", "maxInstallments": 1, "zero": 0, "decimal": 2.5, "flag": true}
        """
        let decoded = try JSONDecoder().decode(AuthorizationDetail.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.additionalFields["maxInstallments"], .double(1.0))
        XCTAssertEqual(decoded.additionalFields["zero"], .double(0.0))
        XCTAssertEqual(decoded.additionalFields["decimal"], .double(2.5))
        XCTAssertEqual(decoded.additionalFields["flag"], .bool(true))
    }

    /// An additionalFields entry whose key shadows a modeled property (`type`) must not
    /// be emitted on encode — the typed property wins and the wire object carries the
    /// member exactly once (duplicate members are rejected by strict parsers).
    func testEncodeSkipsAdditionalFieldsShadowingModeledKeys() throws {
        let detail = AuthorizationDetail(
            type: "payment_initiation",
            additionalFields: ["type": .string("shadowed"), "note": .string("kept")]
        )

        let wire = try AuthorizationDetail.wireValue([detail])

        // `type` appears exactly once and carries the modeled value.
        let occurrences = wire.components(separatedBy: "payment_initiation").count - 1
        XCTAssertEqual(occurrences, 1, "Shadowed key must not duplicate the type member on the wire, got: \(wire)")
        XCTAssertTrue(wire.contains("note"))
        // The filtered object still round-trips.
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(wire.utf8))
        XCTAssertEqual(decoded[0].type, "payment_initiation")
        XCTAssertEqual(decoded[0].additionalFields["note"], .string("kept"))
        XCTAssertNil(decoded[0].additionalFields["type"], "Shadowed key must be dropped, not decoded into additionalFields")
    }
}
