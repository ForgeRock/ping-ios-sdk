// 
//  LocaleExtensionsTests.swift
//  Commons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingCommons

class LocaleExtensionsTests: XCTestCase {
    
    func testEmptyLocaleListReturnsEmptyString() {
        let emptyLocaleList: [Locale] = []
        XCTAssertEqual("", emptyLocaleList.toAcceptLanguage())
    }
    
    func testSingleLocaleWithoutScriptReturnsLanguageTag() {
        let localeList = [Locale(identifier: "en-US")]
        XCTAssertEqual("en-US, en;q=0.9", localeList.toAcceptLanguage())
    }
    
    func testSingleLocaleWithDifferentLanguageTagAddsBothVersions() {
        let localeList = [Locale(identifier: "zh-Hant-TW")]
        XCTAssertEqual("zh-Hant-TW, zh;q=0.9", localeList.toAcceptLanguage())
    }
    
    func testMultipleLocalesAreOrderedWithDecreasingQValues() {
        let localeList = [
            Locale(identifier: "en-US"),
            Locale(identifier: "es-ES"),
            Locale(identifier: "fr-FR")
        ]
        XCTAssertEqual(
            "en-US, en;q=0.9, es-ES;q=0.8, es;q=0.7, fr-FR;q=0.6, fr;q=0.5",
            localeList.toAcceptLanguage()
        )
    }
    
    func testComplexLocaleListWithScriptsHandledCorrectly() {
        let localeList = [
            Locale(identifier: "zh-Hant-TW"),
            Locale(identifier: "en-US"),
            Locale(identifier: "zh-Hans-CN")
        ]
        XCTAssertEqual(
            "zh-Hant-TW, zh;q=0.9, en-US;q=0.8, en;q=0.7, zh-Hans-CN;q=0.6, zh;q=0.5",
            localeList.toAcceptLanguage()
        )
    }
    
    func testQValuesDecreaseCorrectlyForLongLists() {
        let localeList = [
            Locale(identifier: "en-US"),
            Locale(identifier: "fr-FR"),
            Locale(identifier: "de-DE"),
            Locale(identifier: "it-IT"),
            Locale(identifier: "es-ES")
        ]
        XCTAssertEqual(
            "en-US, en;q=0.9, fr-FR;q=0.8, fr;q=0.7, de-DE;q=0.6, de;q=0.5, " +
            "it-IT;q=0.4, it;q=0.3, es-ES;q=0.2, es;q=0.1",
            localeList.toAcceptLanguage()
        )
    }
}
