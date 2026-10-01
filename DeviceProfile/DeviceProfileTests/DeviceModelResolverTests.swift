//
//  DeviceModelResolverTests.swift
//  DeviceProfile
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDeviceProfile

class DeviceModelResolverTests: XCTestCase {

    // MARK: - Known Identifier Tests

    func testKnownIdentifierResolvesToCommercialName() {
        let testCases: [(identifier: String, expectedName: String)] = [
            ("iPhone13,2", "iPhone 12"),
            ("iPhone15,2", "iPhone 14 Pro"),
            ("iPhone18,1", "iPhone 17 Pro"),
            ("iPhone19,2", "iPhone 18 Pro"),
            ("iPhone19,3", "iPhone 18 Pro Max"),
            ("iPhone19,7", "iPhone 18 Pro Max"),
            ("iPad14,3", "iPad Pro 11-inch (4th generation)"),
            ("iPad16,8", "iPad Air 11-inch (M4)"),
            ("iPod9,1", "iPod touch (7th generation)")
        ]

        for testCase in testCases {
            let resolved = DeviceModelResolver.commercialName(for: testCase.identifier)
            XCTAssertEqual(resolved, testCase.expectedName,
                           "\(testCase.identifier) should resolve to \(testCase.expectedName), got \(String(describing: resolved))")
        }
    }

    // MARK: - Unknown Identifier Tests

    func testUnknownIdentifierReturnsNil() {
        // A plausible future identifier that is not in the catalog
        XCTAssertNil(DeviceModelResolver.commercialName(for: "iPhone99,9"),
                     "An identifier absent from the catalog should resolve to nil")
        // A syntactically valid but never-released identifier
        XCTAssertNil(DeviceModelResolver.commercialName(for: "iPad99,9"),
                     "An unreleased iPad identifier should resolve to nil")
        // A Mac identifier is not an iOS device and is not in the catalog
        XCTAssertNil(DeviceModelResolver.commercialName(for: "MacBookPro18,1"),
                     "Mac identifiers should resolve to nil")
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(DeviceModelResolver.commercialName(for: ""),
                     "An empty identifier should resolve to nil")
    }

    func testSimulatorIdentifiersReturnNil() {
        // uname().machine in the iOS Simulator returns the host architecture,
        // not a device model identifier; these must resolve to nil, not crash.
        let simulatorIdentifiers = ["arm64", "x86_64", "i386"]

        for identifier in simulatorIdentifiers {
            XCTAssertNil(DeviceModelResolver.commercialName(for: identifier),
                         "Simulator machine string '\(identifier)' should resolve to nil")
        }
    }

    // MARK: - Lookup Semantics Tests

    func testCaseSensitiveLookup() {
        // Confirms no implicit normalization: altered case does not match.
        let alteredCase: [(identifier: String, knownCounterpart: String)] = [
            ("iphone15,2", "iPhone15,2"),
            ("IPHONE15,2", "iPhone15,2"),
            ("ipad14,3", "iPad14,3")
        ]

        for testCase in alteredCase {
            XCTAssertTrue(DeviceModelCatalog.identifierToCommercialName.keys.contains(testCase.knownCounterpart),
                          "Catalog should contain the correctly-cased identifier \(testCase.knownCounterpart)")
            XCTAssertNil(DeviceModelResolver.commercialName(for: testCase.identifier),
                         "Altered-case identifier '\(testCase.identifier)' should not match; lookup is case-sensitive")
        }
    }

    // MARK: - Catalog Integrity Tests

    // The catalog is generated data (generate-device-model-catalog.sh). These guard against a
    // bad regeneration or a hand edit silently changing what customers' servers receive.

    private var catalog: [String: String] { DeviceModelCatalog.identifierToCommercialName }

    func testCatalogKeysAreWellFormedHardwareIdentifiers() {
        for identifier in catalog.keys {
            XCTAssertNotNil(identifier.range(of: #"^(iPhone|iPad|iPod)[0-9]+,[0-9]+$"#, options: .regularExpression),
                            "'\(identifier)' is not a <family><major>,<minor> hardware identifier")
        }
    }

    func testCatalogNamesAreNonEmptyAndTrimmed() {
        for (identifier, name) in catalog {
            XCTAssertFalse(name.isEmpty, "\(identifier) has an empty commercial name")
            XCTAssertEqual(name, name.trimmingCharacters(in: .whitespacesAndNewlines),
                           "\(identifier) has leading or trailing whitespace in its commercial name")
        }
    }

    func testCatalogNamesMatchTheirDeviceFamily() {
        let expectedNamePrefix = ["iPhone": "iPhone", "iPad": "iPad", "iPod": "iPod touch"]

        for (identifier, name) in catalog {
            let family = String(identifier.prefix(while: \.isLetter))
            guard let prefix = expectedNamePrefix[family] else {
                XCTFail("'\(identifier)' belongs to an unexpected device family '\(family)'")
                continue
            }
            XCTAssertTrue(name.hasPrefix(prefix),
                          "\(identifier) maps to '\(name)', which does not look like a \(prefix)")
        }
    }

    func testCatalogHasNotShrunk() {
        // A floor rather than an exact count: a regeneration from a failed or partial fetch
        // would silently drop devices, which customers would see as modelName disappearing
        // for whole device families. Raise it whenever the catalog legitimately grows.
        XCTAssertGreaterThanOrEqual(catalog.count, 179,
                                    "The catalog shrank; check the last regeneration of DeviceModelCatalog.swift")
    }
}
