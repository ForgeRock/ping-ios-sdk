//
//  PingDavinciPluginTests.swift
//  PingDavinciPluginTests
//
//  Created by george bafaloukas on 20/11/2025.
//

import XCTest
@testable import PingDavinciPlugin
import PingDavinci

// MARK: - SingleValueCollector Tests

final class SingleValueCollectorTests: XCTestCase {

    // MARK: - Helpers

    private func makeJSON(
        type: String = PingDavinciPlugin.Constants.TEXT,
        key: String = "username",
        label: String = "Username",
        required: Bool = false,
        value: Any? = nil
    ) -> [String: Any] {
        var json: [String: Any] = [
            PingDavinciPlugin.Constants.type: type,
            PingDavinciPlugin.Constants.key: key,
            PingDavinciPlugin.Constants.label: label,
            PingDavinciPlugin.Constants.required: required
        ]
        if let value = value {
            json[PingDavinciPlugin.Constants.value] = value
        }
        return json
    }

    // MARK: - init(with:)

    func testInitWithJson_readsStringValue() {
        let json = makeJSON(required: false, value: "default-username")

        let sut = SingleValueCollector(with: json)

        XCTAssertEqual(sut.value, "default-username")
        // inherited fields
        XCTAssertEqual(sut.id, "username")
    }

    func testInitWithJson_missingValue_defaultsToEmptyString() {
        let json = makeJSON(required: false, value: nil)

        let sut = SingleValueCollector(with: json)

        XCTAssertEqual(sut.value, "")
    }

    func testInitWithJson_wrongTypeForValue_ignoresAndDefaultsToEmpty() {
        let json = makeJSON(required: false, value: 12345)

        let sut = SingleValueCollector(with: json)

        XCTAssertEqual(sut.value, "")
    }

    // MARK: - initialize(with:)

    func testInitializeWith_correctType_updatesValue() {
        let json = makeJSON(value: nil)
        let sut = SingleValueCollector(with: json)

        sut.initialize(with: "new-username")

        XCTAssertEqual(sut.value, "new-username")
    }

    func testInitializeWith_wrongType_doesNotChangeValue() {
        let json = makeJSON(value: "initial")
        let sut = SingleValueCollector(with: json)

        sut.initialize(with: 999)

        XCTAssertEqual(sut.value, "initial")
    }

    // MARK: - payload and anyPayload

    func testPayload_whenValueEmpty_returnsNil() {
        let sut = SingleValueCollector(with: makeJSON(value: ""))

        XCTAssertNil(sut.payload())
        XCTAssertNil(sut.anyPayload() as? String)
    }

    func testPayload_whenValueNonEmpty_returnsValue() {
        let sut = SingleValueCollector(with: makeJSON(value: "abc"))

        XCTAssertEqual(sut.payload(), "abc")
        XCTAssertEqual(sut.anyPayload() as? String, "abc")
    }

    // MARK: - validate (required)

    func testValidate_whenRequiredAndPayloadNil_returnsRequiredError() {
        let sut = SingleValueCollector(with: makeJSON(required: true, value: ""))

        let errors = sut.validate()

        XCTAssertEqual(errors, [.required])
        XCTAssertEqual(errors.first?.errorMessage, ValidationError.required.errorMessage)
    }

    func testValidate_whenRequiredAndHasValue_returnsNoErrors() {
        let sut = SingleValueCollector(with: makeJSON(required: true, value: "value"))

        let errors = sut.validate()

        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_whenNotRequiredAndEmpty_returnsNoErrors() {
        let sut = SingleValueCollector(with: makeJSON(required: false, value: ""))

        let errors = sut.validate()

        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - id passthrough from FieldCollector (key)

    func testIdMatchesKeyFromJson() {
        let sut = SingleValueCollector(with: makeJSON(key: "email", value: "a@b.c"))
        XCTAssertEqual(sut.id, "email")
    }
}

// MARK: - Option.parseOptions Tests

final class OptionParsingTests: XCTestCase {

    func testParseOptions_returnsEmptyWhenMissingOptionsKey() {
        let input: [String: Any] = [:]

        let options = Option.parseOptions(from: input)

        XCTAssertTrue(options.isEmpty)
    }

    func testParseOptions_parsesValidOptions() {
        let input: [String: Any] = [
            PingDavinciPlugin.Constants.options: [
                [PingDavinciPlugin.Constants.label: "One", PingDavinciPlugin.Constants.value: "1"],
                [PingDavinciPlugin.Constants.label: "Two", PingDavinciPlugin.Constants.value: "2"]
            ]
        ]

        let options = Option.parseOptions(from: input)

        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].label, "One")
        XCTAssertEqual(options[0].value, "1")
        XCTAssertEqual(options[1].label, "Two")
        XCTAssertEqual(options[1].value, "2")
    }

    func testParseOptions_handlesMissingFieldsByDefaultingToEmptyStrings() {
        let input: [String: Any] = [
            PingDavinciPlugin.Constants.options: [
                [PingDavinciPlugin.Constants.label: "OnlyLabel"], // missing value
                [PingDavinciPlugin.Constants.value: "only-value"] // missing label
            ]
        ]

        let options = Option.parseOptions(from: input)

        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].label, "OnlyLabel")
        XCTAssertEqual(options[0].value, "")
        XCTAssertEqual(options[1].label, "")
        XCTAssertEqual(options[1].value, "only-value")
    }

    func testParseOptions_ignoresNonDictionaryEntriesByReturningEmpty() {
        let input: [String: Any] = [
            PingDavinciPlugin.Constants.options: [
                [PingDavinciPlugin.Constants.label: "Valid", PingDavinciPlugin.Constants.value: "v"],
                "not-a-dictionary",
                123
            ]
        ]

        // Implementation force-casts ([[String: Any]]); invalid entries cause cast to fail -> []
        let options = Option.parseOptions(from: input)
        XCTAssertEqual(options.count, 0)
    }
}

// MARK: - ValidationError Tests

final class ValidationErrorTests: XCTestCase {

    func testErrorMessages() {
        XCTAssertEqual(ValidationError.required.errorMessage, "This field cannot be empty.")
        XCTAssertEqual(ValidationError.regexError(message: "m").errorMessage, "m")
        XCTAssertEqual(ValidationError.invalidLength(min: 1, max: 5).errorMessage, "The input length must be between 1 and 5 characters.")
        XCTAssertEqual(ValidationError.uniqueCharacter(min: 3).errorMessage, "The input must contain at least 3 unique characters.")
        XCTAssertEqual(ValidationError.maxRepeat(max: 2).errorMessage, "The input contains too many repeated characters. Maximum allowed repeats: 2.")
        XCTAssertEqual(ValidationError.minCharacters(character: "ABC", min: 1).errorMessage, "The input must include at least 1 character(s) from this set: 'ABC'.")
    }
}

// MARK: - FieldCollector anyPayload delegation

private final class TestStringCollector: FieldCollector<String>, @unchecked Sendable {
    var stored: String? = nil

    required init(with json: [String : Any]) {
        super.init(with: json)
    }

    override func payload() -> String? {
        return stored
    }
}

final class FieldCollectorAnyPayloadTests: XCTestCase {
    func testAnyPayloadDelegatesToPayload() {
        let sut = TestStringCollector(with: [
            PingDavinciPlugin.Constants.type: "TEXT",
            PingDavinciPlugin.Constants.key: "k",
            PingDavinciPlugin.Constants.label: "l",
            PingDavinciPlugin.Constants.required: false
        ])

        XCTAssertNil(sut.anyPayload())
        sut.stored = "val"
        XCTAssertEqual(sut.anyPayload() as? String, "val")
    }
}
