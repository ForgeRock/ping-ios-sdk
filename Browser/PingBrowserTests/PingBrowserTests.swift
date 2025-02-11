//
//  PingBrowserTests.swift
//  PingBrowserTests
//
//  Created by george bafaloukas on 10/02/2025.
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
