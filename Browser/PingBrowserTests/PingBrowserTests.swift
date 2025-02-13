//
//  PingBrowserTests.swift
//  PingBrowserTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBrowser

final class PingBrowserTests: XCTestCase {

    func testCurrentBrowser() throws {
        let browser = BrowserLauncher.currentBrowser
        XCTAssertNotNil(browser)
        XCTAssertFalse(browser.isInProgress)
    }

}
