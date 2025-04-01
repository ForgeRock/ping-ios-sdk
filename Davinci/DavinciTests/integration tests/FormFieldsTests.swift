//
//  FormFieldsTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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

class FormFieldsTests: XCTestCase {
    private var daVinci: DaVinci!
    
    override func setUp() async throws {
        try await super.setUp()
        
        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "60de77d5-dd2c-41ef-8c40-f8bb2381a359"
                oidcValue.scopes = ["openid", "email", "address", "phone", "profile"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
                oidcValue.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
            }
        }
    }
    
    // TestRailCase(26023)
    func testLabelCollector() async throws {
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that the first 2 collectors in the form are LabelCollectors
        XCTAssertTrue(node.collectors[0] is LabelCollector)
        XCTAssertTrue(node.collectors[1] is LabelCollector)
        
        let labelCollector1 = node.collectors[0] as! LabelCollector
        let labelCollector2 = node.collectors[1] as! LabelCollector
        
        XCTAssertTrue(labelCollector1.content.contains("Rich Text fields produce LABELs"))
        XCTAssertEqual("Translatable Rich Text produce LABELs too!\n\n", labelCollector2.content)
    }
    
    // TestRailCase(26032, 26031)
    func testTextCollector() async throws {
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // 3rd collector in the form is a TextCollector
        XCTAssertTrue(node.collectors[2] is TextCollector)
        let textCollector = node.collectors[2] as! TextCollector
        
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
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // 4th collector in the form is a Checkbox group
        XCTAssertTrue(node.collectors[3] is MultiSelectCollector)
        let checkbox = node.collectors[3] as! MultiSelectCollector
        
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
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // 5th collector in the form is a Dropdown field
        XCTAssertTrue(node.collectors[4] is SingleSelectCollector)
        let dropdown = node.collectors[4] as! SingleSelectCollector
        
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
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // 6th collector in the form is a Radio Group field
        XCTAssertTrue(node.collectors[5] is SingleSelectCollector)
        let radio = node.collectors[5] as! SingleSelectCollector
        
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
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // 7th collector in the form is a Combobox
        XCTAssertTrue(node.collectors[6] is MultiSelectCollector)
        let combobox = node.collectors[6] as! MultiSelectCollector
        
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
    
    // TestRailCase(26033)
    func testFlowButtonCollector() async throws {
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that FlowButton is present
        XCTAssertTrue(node.collectors[7] is FlowCollector)
        let flowButton = node.collectors[7] as! FlowCollector
        
        XCTAssertEqual("FLOW_BUTTON", flowButton.type)
        XCTAssertEqual("Flow Button", flowButton.label)
        XCTAssertEqual("flow-button-field", flowButton.key)
        
        flowButton.value = "action"
        node = await node.next() as! ContinueNode
        
        // Make sure that we advanced to the next node
        XCTAssertEqual("Success", node.name)
    }
    
    // TestRailCase(26033)
    func testFlowLinkCollector() async throws {
        // Go to the "Form Fields" form
        var node = await daVinci.start() as! ContinueNode
        (node.collectors[0] as? SubmitCollector)?.value = "click"
        node = await node.next() as! ContinueNode
        
        // Make sure that FlowLink is present
        XCTAssertTrue(node.collectors[8] is FlowCollector)
        let flowLink = node.collectors[8] as! FlowCollector
        
        XCTAssertEqual("FLOW_LINK", flowLink.type)
        XCTAssertEqual("Flow Link", flowLink.label)
        XCTAssertEqual("flow-link-field", flowLink.key)
        
        flowLink.value = "action"
        node = await node.next() as! ContinueNode
        
        // Make sure that we advanced to the next node
        XCTAssertEqual("Success", node.name)
    }
}
