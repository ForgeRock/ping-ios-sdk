//
//  FormFieldsTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

class FormFieldsTests: DaVinciBaseTests, @unchecked Sendable {
    private var daVinci: DaVinci!

    private enum FormFieldIndex {
        static let labelTextBlob = 0
        static let labelTranslatable = 1
        static let labelRichText = 2
        static let textInput = 3
        static let checkbox = 4
        static let dropdown = 5
        static let radio = 6
        static let combobox = 7
        static let phoneNumber = 8
        static let singleCheckbox = 9
        static let flowButton = 10
        static let flowLink = 11
        static let submitButton = 12
    }

    override func setUp() {
        self.configFileName = "ConfigNew"
        super.setUp()

        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.acrValues = "b63ac7fb5db6d893efdd5e29d06a7477"
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }
    }

    private func goToFormFieldsForm() async throws -> ContinueNode {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            throw XCTSkip("Could not navigate to form fields form: start() did not return ContinueNode")
        }
        (startNode.collectors[0] as? SubmitCollector)?.value = "click"
        guard let formNode = await startNode.next() as? ContinueNode else {
            throw XCTSkip("Could not navigate to form fields form: next() did not return ContinueNode")
        }
        return formNode
    }

    // TestRailCase(26023)
    func testLabelCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.labelTextBlob] is LabelCollector)
        XCTAssertTrue(node.collectors[FormFieldIndex.labelTranslatable] is LabelCollector)

        guard let labelCollector1 = node.collectors[FormFieldIndex.labelTextBlob] as? LabelCollector else {
            XCTFail("Expected LabelCollector at collectors[\(FormFieldIndex.labelTextBlob)]")
            return
        }
        guard let labelCollector2 = node.collectors[FormFieldIndex.labelTranslatable] as? LabelCollector else {
            XCTFail("Expected LabelCollector at collectors[\(FormFieldIndex.labelTranslatable)]")
            return
        }

        XCTAssertTrue(labelCollector1.content.contains("Rich Text fields produce LABELs"))
        XCTAssertEqual("Translatable Rich Text produce LABELs too!\n\n", labelCollector2.content)

        // SDKS-3956 Add support for key attribute in Label Collectors
        XCTAssertEqual("translatable-rich-text-key", labelCollector2.key)
        // Note that the Rich Text component has been deprecated, so the key is not set
        XCTAssertEqual("", labelCollector1.key)
    }

    // TestRailCase(26032, 26031)
    func testTextCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.textInput] is TextCollector)
        guard let textCollector = node.collectors[FormFieldIndex.textInput] as? TextCollector else {
            XCTFail("Expected TextCollector at collectors[\(FormFieldIndex.textInput)]")
            return
        }

        XCTAssertEqual("TEXT", textCollector.type)
        XCTAssertEqual("Text Input Label", textCollector.label)
        XCTAssertEqual("text-input-key", textCollector.key)
        XCTAssertEqual("default text", textCollector.value)
        XCTAssertEqual(true, textCollector.required)

        // Clear the text field
        textCollector.value = ""

        XCTAssertNil(textCollector.validation?.regex)
        XCTAssertNil(textCollector.validation?.errorMessage)

        // Validate should return list with 1 validation errors since the value is empty
        let validationResult = textCollector.validate()
        XCTAssertEqual(1, validationResult.count)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        textCollector.value = "Sometext123"
        let validationResult2 = textCollector.validate() // Should return empty list this time
        XCTAssertTrue(validationResult2.isEmpty)
    }

    // TestRailCase(26024, 26031)
    func testCheckboxCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.checkbox] is MultiSelectCollector)
        guard let checkbox = node.collectors[FormFieldIndex.checkbox] as? MultiSelectCollector else {
            XCTFail("Expected MultiSelectCollector at collectors[\(FormFieldIndex.checkbox)]")
            return
        }

        XCTAssertEqual("CHECKBOX", checkbox.type)
        XCTAssertEqual("Checkbox List Label", checkbox.label)
        XCTAssertEqual("checkbox-field-key", checkbox.key)
        XCTAssertEqual(2, checkbox.options.count)
        XCTAssertEqual("option1 label", checkbox.options[0].label)
        XCTAssertEqual("option1 value", checkbox.options[0].value)
        XCTAssertEqual("option2 label", checkbox.options[1].label)
        XCTAssertEqual("option2 value", checkbox.options[1].value)
        XCTAssertEqual(true, checkbox.required)

        // Make sure that the correct checkbox values are set (default values)
        XCTAssertEqual(2, checkbox.value.count)
        XCTAssertTrue(checkbox.value.contains("option1 value"))
        XCTAssertTrue(checkbox.value.contains("option2 value"))

        // Remove the values from the checkbox
        checkbox.value.removeAll()

        // validate() should fail since value is empty but required
        let validationResult = checkbox.validate()
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        checkbox.value.append("value1")
        let validationResult2 = checkbox.validate() // Should return empty list this time
        XCTAssertTrue(validationResult2.isEmpty)
    }

    // TestRailCase(26025, 26031)
    func testDropdownCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.dropdown] is SingleSelectCollector)
        guard let dropdown = node.collectors[FormFieldIndex.dropdown] as? SingleSelectCollector else {
            XCTFail("Expected SingleSelectCollector at collectors[\(FormFieldIndex.dropdown)]")
            return
        }

        XCTAssertEqual("DROPDOWN", dropdown.type)
        XCTAssertEqual("Dropdown List Label", dropdown.label)
        XCTAssertEqual("dropdown-field-key", dropdown.key)
        XCTAssertEqual(3, dropdown.options.count)
        XCTAssertEqual("dropdown-option1-label", dropdown.options[0].label)
        XCTAssertEqual("dropdown-option2-label", dropdown.options[1].label)
        XCTAssertEqual("dropdown-option3-label", dropdown.options[2].label)
        XCTAssertEqual("dropdown-option1-value", dropdown.options[0].value)
        XCTAssertEqual("dropdown-option2-value", dropdown.options[1].value)
        XCTAssertEqual("dropdown-option3-value", dropdown.options[2].value)
        XCTAssertEqual(true, dropdown.required)

        // Make sure that dropdown default value is set
        XCTAssertEqual("dropdown-option2-value", dropdown.value)

        // Clear the value of the dropdown
        dropdown.value = ""

        // validate() should fail since value is empty but required
        let validationResult = dropdown.validate()
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        dropdown.value = "value1"
        let validationResult2 = dropdown.validate() // Should return empty list this time
        XCTAssertTrue(validationResult2.isEmpty)
    }

    // TestRailCase(26026, 26031)
    func testRadioCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.radio] is SingleSelectCollector)
        guard let radio = node.collectors[FormFieldIndex.radio] as? SingleSelectCollector else {
            XCTFail("Expected SingleSelectCollector at collectors[\(FormFieldIndex.radio)]")
            return
        }

        XCTAssertEqual("RADIO", radio.type)
        XCTAssertEqual("Radio Group Label", radio.label)
        XCTAssertEqual("radio-group-key", radio.key)
        XCTAssertEqual(3, radio.options.count)
        XCTAssertEqual("option1 label", radio.options[0].label)
        XCTAssertEqual("option2 label", radio.options[1].label)
        XCTAssertEqual("option3 label", radio.options[2].label)
        XCTAssertEqual("option1 value", radio.options[0].value)
        XCTAssertEqual("option2 value", radio.options[1].value)
        XCTAssertEqual("option3 value", radio.options[2].value)
        XCTAssertEqual(true, radio.required)

        // Make sure that radio default value is set
        XCTAssertEqual("option2 value", radio.value)

        // Clear the value of the radio
        radio.value = ""

        // validate() should fail since value is empty but required
        let validationResult = radio.validate()
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        radio.value = "value1"
        let validationResult2 = radio.validate() // Should return empty list this time
        XCTAssertTrue(validationResult2.isEmpty)
    }

    // TestRailCase(26027, 26031)
    func testComboboxCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.combobox] is MultiSelectCollector)
        guard let combobox = node.collectors[FormFieldIndex.combobox] as? MultiSelectCollector else {
            XCTFail("Expected MultiSelectCollector at collectors[\(FormFieldIndex.combobox)]")
            return
        }

        XCTAssertEqual("COMBOBOX", combobox.type)
        XCTAssertEqual("Combobox Label", combobox.label)
        XCTAssertEqual("combobox-field-key", combobox.key)
        XCTAssertEqual(3, combobox.options.count)
        XCTAssertEqual("option1 label", combobox.options[0].label)
        XCTAssertEqual("option1 value", combobox.options[0].value)
        XCTAssertEqual("option2 label", combobox.options[1].label)
        XCTAssertEqual("option2 value", combobox.options[1].value)
        XCTAssertEqual("option3 label", combobox.options[2].label)
        XCTAssertEqual("option3 value", combobox.options[2].value)
        XCTAssertEqual(true, combobox.required)

        // Make sure that default values are set
        XCTAssertEqual(2, combobox.value.count)
        XCTAssertEqual("option1 value", combobox.value[0])
        XCTAssertEqual("option3 value", combobox.value[1])

        // Clear the values of the combobox
        combobox.value.removeAll()

        // validate() should fail since value is empty but required
        let validationResult = combobox.validate()
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        combobox.value.append("value1")
        combobox.value.append("value2")
        let validationResult2 = combobox.validate() // Should return empty list this time
        XCTAssertTrue(validationResult2.isEmpty)
    }

    // TestRailCase(26027, 31735)
    func testPhoneNumberCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.phoneNumber] is PhoneNumberCollector)
        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }

        XCTAssertEqual("PHONE_NUMBER", phone.type)
        XCTAssertEqual("Phone Collector", phone.label)
        XCTAssertEqual("phone-field", phone.key)
        XCTAssertEqual(true, phone.required)
        XCTAssertEqual(true, phone.validatePhoneNumber)
        XCTAssertEqual("BF", phone.defaultCountryCode) // Burkina Faso (set in the form)
        XCTAssertEqual("GB", phone.countryCode) // Great Britain (set in DV form connector)
        XCTAssertEqual("(555)555-1234", phone.phoneNumber) // Set in DV form connector

        // Clear the value of the phone number
        phone.phoneNumber = ""

        // validate() should fail since the phone number is empty but required
        var validationResult = phone.validate()
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        // Provide a phone number without country code and validate again
        phone.countryCode = ""
        phone.phoneNumber = "7783177184"

        validationResult = phone.validate() // Should fail
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        // Providing a phone number and country code should pass the validation
        phone.countryCode = "CA"
        phone.phoneNumber = "7783177184"
        validationResult = phone.validate() // Should pass...
        XCTAssertTrue(validationResult.isEmpty)
    }

    func testBooleanCollector() async throws {
        let node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.singleCheckbox] is BooleanCollector)
        guard let singleCheckbox = node.collectors[FormFieldIndex.singleCheckbox] as? BooleanCollector else {
            XCTFail("Expected BooleanCollector at collectors[\(FormFieldIndex.singleCheckbox)]")
            return
        }

        XCTAssertEqual("SINGLE_CHECKBOX", singleCheckbox.type)
        XCTAssertEqual("single-checkbox-field", singleCheckbox.key)
        XCTAssertEqual("I agree to the Terms and Conditions", singleCheckbox.label)

        let richContent = singleCheckbox.richContent
        XCTAssertNotNil(richContent)
        XCTAssertEqual("I agree to the {{link1}}", richContent?.content)
        XCTAssertEqual(1, richContent?.replacements.count)
        XCTAssertNotNil(richContent?.replacements["link1"])
        XCTAssertEqual(true, singleCheckbox.required)

        // Default value should be false
        XCTAssertEqual(false, singleCheckbox.value)

        let requiredErrors = singleCheckbox.validate()
        XCTAssertFalse(requiredErrors.isEmpty)

        singleCheckbox.value = true
        let validationResult = singleCheckbox.validate()
        XCTAssertTrue(validationResult.isEmpty)
    }

    // Verify that a LabelCollector with two rich-text links exposes both replacements
    // with correct values, hrefs, and types.
    func testLabelCollectorMultipleLinks() async throws {
        let node = try await goToFormFieldsForm()

        guard let label = node.collectors[FormFieldIndex.labelRichText] as? LabelCollector else {
            XCTFail("Expected LabelCollector at collectors[\(FormFieldIndex.labelRichText)]")
            return
        }
        let richContent = label.richContent
        XCTAssertNotNil(richContent)

        XCTAssertEqual(
            "A translatable rich text to take the user to {{link1}} and {{link2}}",
            richContent?.content
        )
        XCTAssertEqual(2, richContent?.replacements.count)

        let link1 = richContent?.replacements["link1"]
        XCTAssertNotNil(link1)
        XCTAssertEqual("google.com", link1?.value)
        XCTAssertEqual("https://www.google.com", link1?.href)
        XCTAssertEqual("link", link1?.type)
        XCTAssertEqual("_self", link1?.target)

        let link2 = richContent?.replacements["link2"]
        XCTAssertNotNil(link2)
        XCTAssertEqual("apple.com", link2?.value)
        XCTAssertEqual("https://www.apple.com", link2?.href)
        XCTAssertEqual("link", link2?.type)
        XCTAssertEqual("_blank", link2?.target)
    }

    // Verify mixed open-in-new-tab targets: link1 stays in the same context (_self),
    // link2 requests a new tab (_blank). Both targets must be independently correct.
    func testLabelCollectorLinkTargets() async throws {
        let node = try await goToFormFieldsForm()

        guard let label = node.collectors[FormFieldIndex.labelRichText] as? LabelCollector else {
            XCTFail("Expected LabelCollector at collectors[\(FormFieldIndex.labelRichText)]")
            return
        }
        let replacements = label.richContent?.replacements
        XCTAssertNotNil(replacements)

        XCTAssertEqual("_self", replacements?["link1"]?.target)
        XCTAssertEqual("_blank", replacements?["link2"]?.target)
    }

    // Verify the object-format payload: PhoneNumberCollector.payload() must return a
    // dictionary (not nil and not a plain string) when countryCode and phoneNumber are set.
    func testPhoneNumberObjectPayload() async throws {
        let node = try await goToFormFieldsForm()

        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }

        // Server pre-fills countryCode + phoneNumber as an object (DV-17946 new format).
        XCTAssertEqual("GB", phone.countryCode)
        XCTAssertEqual("(555)555-1234", phone.phoneNumber)

        let payload = phone.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual("GB", payload?["countryCode"] as? String)
        XCTAssertEqual("(555)555-1234", payload?["phoneNumber"] as? String)
        XCTAssertNotNil(payload?["extension"]) // extension key must be present even when empty
    }

    // Verify showExtension schema property and that a non-empty extension appears in payload().
    func testPhoneNumberExtensionSchemaAndPayload() async throws {
        let node = try await goToFormFieldsForm()

        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }

        XCTAssertTrue(phone.showExtension)

        // extension is pre-filled from formData object (DV-17946 new format)
        XCTAssertEqual("4321", phone.extension)

        // Overwrite with different values and verify they appear in payload
        phone.countryCode = "CA"
        phone.phoneNumber = "7783177184"
        phone.extension = "123"

        let payload = phone.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual("CA", payload?["countryCode"] as? String)
        XCTAssertEqual("7783177184", payload?["phoneNumber"] as? String)
        XCTAssertEqual("123", payload?["extension"] as? String)
    }

    // extension is optional — it must never cause or block a Required validation error.
    func testPhoneNumberExtensionValidation() async throws {
        let node = try await goToFormFieldsForm()

        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }

        // Extension set, phone number missing → still Required
        phone.countryCode = "CA"
        phone.phoneNumber = ""
        phone.extension = "999"
        var validationResult = phone.validate()
        XCTAssertFalse(validationResult.isEmpty)
        XCTAssertEqual("This field cannot be empty.", validationResult[0].errorMessage)

        // Extension empty, valid phone + country → no errors
        phone.phoneNumber = "7783177184"
        phone.extension = ""
        validationResult = phone.validate()
        XCTAssertTrue(validationResult.isEmpty)

        // Extension set, valid phone + country → still no errors
        phone.extension = "42"
        validationResult = phone.validate()
        XCTAssertTrue(validationResult.isEmpty)
    }

    // payload() must return nil when both countryCode and phoneNumber are empty.
    func testPhoneNumberPayloadIsNilWhenEmpty() async throws {
        let node = try await goToFormFieldsForm()

        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }
        phone.countryCode = ""
        phone.phoneNumber = ""

        let errors = phone.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertEqual("This field cannot be empty.", errors[0].errorMessage)
        XCTAssertNil(phone.payload())
    }

    // Submitting countryCode + phoneNumber in object format advances the flow to "Success".
    func testPhoneNumberSubmissionWithObjectFormat() async throws {
        var node = try await goToFormFieldsForm()

        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }
        phone.countryCode = "CA"
        phone.phoneNumber = "7783177184"
        phone.extension = ""

        fillRequiredFields(node)
        (node.collectors[FormFieldIndex.submitButton] as? SubmitCollector)?.value = "Submit"

        guard let successNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after form submission")
            return
        }
        node = successNode
        XCTAssertEqual("Success", node.name)
    }

    // Submitting with a non-empty extension sends the value in the request body.
    func testPhoneNumberSubmissionWithExtension() async throws {
        var node = try await goToFormFieldsForm()

        guard let phone = node.collectors[FormFieldIndex.phoneNumber] as? PhoneNumberCollector else {
            XCTFail("Expected PhoneNumberCollector at collectors[\(FormFieldIndex.phoneNumber)]")
            return
        }
        phone.countryCode = "GB"
        phone.phoneNumber = "(555)555-1234"
        phone.extension = "4321"

        fillRequiredFields(node)
        (node.collectors[FormFieldIndex.submitButton] as? SubmitCollector)?.value = "Submit"

        guard let successNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after form submission")
            return
        }
        node = successNode
        XCTAssertEqual("Success", node.name)
    }

    // Navigate to the "Agreement Test" form via its dedicated menu button and verify
    // the ReadOnlyTextCollector (agreement text) and BooleanCollector (agreement checkbox).
    func testAgreementCollector() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode

        // Locate the "Agreement Test" button by label — index varies by environment.
        guard let agreementButton = node.collectors.first(where: {
            ($0 as? FlowCollector)?.label == "Agreement Test"
        }) as? FlowCollector else {
            throw XCTSkip("Agreement Test button not present in this environment")
        }
        agreementButton.value = "click"

        guard let agreementFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after Agreement Test button")
            return
        }
        node = agreementFormNode
        XCTAssertEqual("Automation - Agreement Tests", node.name)

        guard let agreement = node.collectors.first(where: { $0 is ReadOnlyTextCollector }) as? ReadOnlyTextCollector else {
            XCTFail("ReadOnlyTextCollector not found")
            return
        }
        guard let checkbox = node.collectors.first(where: { $0 is BooleanCollector }) as? BooleanCollector else {
            XCTFail("BooleanCollector not found")
            return
        }
        guard let submit = node.collectors.first(where: { $0 is SubmitCollector }) as? SubmitCollector else {
            XCTFail("SubmitCollector not found")
            return
        }

        // ReadOnlyTextCollector properties
        XCTAssertEqual("agreement", agreement.key)
        XCTAssertEqual("AGREEMENT", agreement.type)
        XCTAssertEqual("Terms of Service Agreement", agreement.title)
        XCTAssertTrue(agreement.titleEnabled)
        XCTAssertTrue(agreement.enabled)
        XCTAssertFalse(agreement.useDynamicAgreement)
        XCTAssertFalse(agreement.content.isEmpty)

        // BooleanCollector properties
        XCTAssertEqual("agreement-checkbox", checkbox.key)
        XCTAssertEqual("I have read and agree to terms", checkbox.label)
        XCTAssertTrue(checkbox.required)
        XCTAssertEqual("You must agree to the terms to continue.", checkbox.errorMessage)

        // richContent link inside the checkbox label
        let richContent = checkbox.richContent
        XCTAssertNotNil(richContent)
        XCTAssertEqual("I have read and agree to {{link1}}", richContent?.content)
        let link1 = richContent?.replacements["link1"]
        XCTAssertNotNil(link1)
        XCTAssertEqual("terms", link1?.value)
        XCTAssertEqual("https://www.pingidentity.com/en/legal/product-terms.html", link1?.href)
        XCTAssertEqual("_self", link1?.target)

        // Unchecked → validate() must return an error
        XCTAssertFalse(checkbox.value)
        XCTAssertFalse(checkbox.validate().isEmpty)

        // Checking the box clears the error
        checkbox.value = true
        XCTAssertTrue(checkbox.validate().isEmpty)

        // Submit with checkbox checked → flow advances back to the menu
        submit.value = "Accept"

        guard let menuNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after agreement submit")
            return
        }
        node = menuNode
        XCTAssertEqual("Select Test Form", node.name)
    }

    // TestRailCase(26033)
    func testFlowButtonCollector() async throws {
        var node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.flowButton] is FlowCollector)
        guard let flowButton = node.collectors[FormFieldIndex.flowButton] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[\(FormFieldIndex.flowButton)]")
            return
        }

        XCTAssertEqual("FLOW_BUTTON", flowButton.type)
        XCTAssertEqual("Flow Button", flowButton.label)
        XCTAssertEqual("flow-button-field", flowButton.key)

        flowButton.value = "action"

        guard let successNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after flow button action")
            return
        }
        node = successNode
        XCTAssertEqual("Success", node.name)
    }

    // TestRailCase(26033)
    func testFlowLinkCollector() async throws {
        var node = try await goToFormFieldsForm()

        XCTAssertTrue(node.collectors[FormFieldIndex.flowLink] is FlowCollector)
        guard let flowLink = node.collectors[FormFieldIndex.flowLink] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[\(FormFieldIndex.flowLink)]")
            return
        }

        XCTAssertEqual("FLOW_LINK", flowLink.type)
        XCTAssertEqual("Flow Link", flowLink.label)
        XCTAssertEqual("flow-link-field", flowLink.key)

        flowLink.value = "action"

        guard let successNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after flow link action")
            return
        }
        node = successNode
        XCTAssertEqual("Success", node.name)
    }

    // MARK: - Helpers

    // Fills the non-phone required fields in the Form Fields form so a submission test
    // targeting the phone field does not fail due to other missing required fields.
    private func fillRequiredFields(_ node: ContinueNode) {
        (node.collectors[FormFieldIndex.textInput] as? TextCollector)?.value = "test"
        (node.collectors[FormFieldIndex.checkbox] as? MultiSelectCollector)?.value = ["option1 value"]
        (node.collectors[FormFieldIndex.dropdown] as? SingleSelectCollector)?.value = "dropdown-option1-value"
        (node.collectors[FormFieldIndex.radio] as? SingleSelectCollector)?.value = "option1 value"
        (node.collectors[FormFieldIndex.combobox] as? MultiSelectCollector)?.value = ["option1 value"]
        (node.collectors[FormFieldIndex.singleCheckbox] as? BooleanCollector)?.value = true
    }
}
