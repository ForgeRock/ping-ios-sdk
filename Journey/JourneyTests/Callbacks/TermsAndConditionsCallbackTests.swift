//
//  TermsAndConditionsCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingJourneyPlugin
@testable import PingJourney

class TermsAndConditionsCallbackTests: XCTestCase {

    private var callback: TermsAndConditionsCallback!
    
    override func setUp() {
        super.setUp()
        callback = TermsAndConditionsCallback()

        let jsonString = """
        {
          "type": "TermsAndConditionsCallback",
          "output": [
            {
              "name": "version",
              "value": "1.0"
            },
            {
              "name": "terms",
              "value": "This is a demo for Terms & Conditions"
            },
            {
              "name": "createDate",
              "value": "2019-07-11T22:23:55.737Z"
            }
          ],
          "input": [
            {
              "name": "IDToken1",
              "value": false
            }
          ]
        }
        """

        // Parse JSON string into dictionary
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

             // Initialize callback with parsed data
             callback = TermsAndConditionsCallback()
             _ = callback.initialize(with: jsonObject)
        } else {
            XCTFail("Failed to parse JSON string")
        }
    }

    func testInitializesCorrectly() {
        XCTAssertEqual(callback.version, "1.0")
        XCTAssertEqual(callback.terms, "This is a demo for Terms & Conditions")
        XCTAssertEqual(callback.createDate, "2019-07-11T22:23:55.737Z")
        XCTAssertFalse(callback.accepted) // Note: Swift uses 'accepted' vs Android's 'accept'
    }

    func testPayloadReturnsCorrectly() {
        callback.accepted = true

        let payload = callback.payload()

        XCTAssertNotNil(payload)

        // Verify the payload structure matches the expected input format
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertTrue(value)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testPayloadWithDefaultValue() {
        // Don't modify accepted - should be false by default

        let payload = callback.payload()

        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertFalse(value)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testAcceptedPropertyCanBeModified() {
        // Test that the accepted property can be changed
        XCTAssertFalse(callback.accepted) // Initially false

        callback.accepted = true
        XCTAssertTrue(callback.accepted)

        callback.accepted = false
        XCTAssertFalse(callback.accepted)
    }

    func testInitValueWithIndividualProperties() {
        let newCallback = TermsAndConditionsCallback()

        // Test initializing individual properties
        newCallback.initValue(name: JourneyConstants.version, value: "2.1")
        newCallback.initValue(name: JourneyConstants.terms, value: "Updated Terms and Conditions for 2025")
        newCallback.initValue(name: JourneyConstants.createDate, value: "2025-01-15T10:30:00.000Z")

        XCTAssertEqual(newCallback.version, "2.1")
        XCTAssertEqual(newCallback.terms, "Updated Terms and Conditions for 2025")
        XCTAssertEqual(newCallback.createDate, "2025-01-15T10:30:00.000Z")
    }

    func testInitValueWithInvalidTypes() {
        let newCallback = TermsAndConditionsCallback()

        // Test with invalid types - should not crash and should use default values
        newCallback.initValue(name: JourneyConstants.version, value: 123) // Invalid type
        newCallback.initValue(name: JourneyConstants.terms, value: 456) // Invalid type
        newCallback.initValue(name: JourneyConstants.createDate, value: 789) // Invalid type

        // Should maintain default values
        XCTAssertEqual(newCallback.version, "")
        XCTAssertEqual(newCallback.terms, "")
        XCTAssertEqual(newCallback.createDate, "")
    }

    func testInitValueWithUnknownProperties() {
        let newCallback = TermsAndConditionsCallback()

        // Test with unknown property names - should not crash
        newCallback.initValue(name: "unknownProperty1", value: "some value")
        newCallback.initValue(name: "unknownProperty2", value: true)

        // Should maintain default values for known properties
        XCTAssertEqual(newCallback.version, "")
        XCTAssertEqual(newCallback.terms, "")
        XCTAssertEqual(newCallback.createDate, "")
        XCTAssertFalse(newCallback.accepted)
    }

    func testVersionFormats() {
        let newCallback = TermsAndConditionsCallback()
        let versionTestCases = [
            "",
            "1.0",
            "2.1.3",
            "v1.0",
            "1.0.0-beta",
            "2024.12.01",
            "latest",
            "draft"
        ]

        for version in versionTestCases {
            newCallback.initValue(name: JourneyConstants.version, value: version)
            XCTAssertEqual(newCallback.version, version, "Failed for version: '\(version)'")
        }
    }

    func testCreateDateFormats() {
        let newCallback = TermsAndConditionsCallback()
        let dateTestCases = [
            "",
            "2019-07-11T22:23:55.737Z",
            "2025-01-15T10:30:00.000Z",
            "2024-12-31T23:59:59.999Z",
            "2020-01-01T00:00:00.000Z",
            "2023-06-15T14:45:30.123Z"
        ]

        for createDate in dateTestCases {
            newCallback.initValue(name: JourneyConstants.createDate, value: createDate)
            XCTAssertEqual(newCallback.createDate, createDate, "Failed for createDate: '\(createDate)'")
        }
    }

    func testTermsContentVariations() {
        let newCallback = TermsAndConditionsCallback()
        let termsTestCases = [
            "",
            "Short terms",
            "This is a demo for Terms & Conditions",
            "By using this service, you agree to our terms and conditions. Please read carefully before proceeding.",
            """
            Terms and Conditions
            
            1. Acceptance of Terms
            By accessing and using this service, you accept and agree to be bound by the terms and provision of this agreement.
            
            2. Privacy Policy
            Your privacy is important to us. Please review our Privacy Policy, which also governs your use of the Service.
            
            3. Changes to Terms
            We reserve the right to modify these terms at any time.
            """,
            "Terms with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?",
            "Términos y Condiciones en Español",
            "Conditions générales en français",
            "利用規約 (Japanese)",
            "Terms with emojis 📋✅❌"
        ]

        for terms in termsTestCases {
            newCallback.initValue(name: JourneyConstants.terms, value: terms)
            XCTAssertEqual(newCallback.terms, terms, "Failed for terms content test")
        }
    }

    func testPayloadWithBothAcceptedValues() {
        let testCases = [true, false]

        for acceptedValue in testCases {
            callback.accepted = acceptedValue
            let payload = callback.payload()

            if let inputArray = payload["input"] as? [[String: Any]],
               let firstInput = inputArray.first,
               let value = firstInput["value"] as? Bool {
                XCTAssertEqual(value, acceptedValue, "Failed for accepted value: \(acceptedValue)")
            } else {
                XCTFail("Payload structure is not as expected for accepted value: \(acceptedValue)")
            }
        }
    }

    func testCompleteInitializationScenario() {
        // Initialize all properties in a realistic terms acceptance scenario
        callback.initValue(name: JourneyConstants.version, value: "3.2")
        callback.initValue(name: JourneyConstants.createDate, value: "2025-01-01T00:00:00.000Z")
        callback.initValue(name: JourneyConstants.terms, value: """
        Privacy Policy and Terms of Service
        
        Last updated: January 1, 2025
        
        1. Data Collection: We collect information you provide directly to us.
        2. Data Usage: We use your information to provide and improve our services.
        3. Data Sharing: We do not sell your personal information to third parties.
        4. Your Rights: You have the right to access, update, or delete your information.
        
        By clicking "Accept", you agree to these terms.
        """)

        // Verify all properties are set correctly
        XCTAssertEqual(callback.version, "3.2")
        XCTAssertEqual(callback.createDate, "2025-01-01T00:00:00.000Z")
        XCTAssertTrue(callback.terms.contains("Privacy Policy and Terms of Service"))
        XCTAssertFalse(callback.accepted) // Default value

        // User accepts terms
        callback.accepted = true

        // Test payload with user acceptance
        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertTrue(value)
        } else {
            XCTFail("Payload structure is not as expected")
        }
    }

    func testDefaultValues() {
        let newCallback = TermsAndConditionsCallback()

        // Test that default values are correct before any initialization
        XCTAssertEqual(newCallback.version, "")
        XCTAssertEqual(newCallback.terms, "")
        XCTAssertEqual(newCallback.createDate, "")
        XCTAssertFalse(newCallback.accepted)
    }

    func testEmptyStringValues() {
        let newCallback = TermsAndConditionsCallback()

        // Test with empty string values
        newCallback.initValue(name: JourneyConstants.version, value: "")
        newCallback.initValue(name: JourneyConstants.terms, value: "")
        newCallback.initValue(name: JourneyConstants.createDate, value: "")

        XCTAssertEqual(newCallback.version, "")
        XCTAssertEqual(newCallback.terms, "")
        XCTAssertEqual(newCallback.createDate, "")
    }

    func testLongTermsContent() {
        let newCallback = TermsAndConditionsCallback()
        let longTerms = String(repeating: "This is a very long terms and conditions document that contains extensive legal text about user rights, service limitations, privacy policies, data collection practices, and various other legal provisions that users must accept before using the service. ", count: 10)

        newCallback.initValue(name: JourneyConstants.terms, value: longTerms)

        XCTAssertEqual(newCallback.terms, longTerms)
        XCTAssertTrue(newCallback.terms.count > 1000, "Should handle very long terms content")
    }

    func testTermsAcceptanceFlow() {
        let newCallback = TermsAndConditionsCallback()

        // Simulate a complete terms acceptance flow
        newCallback.initValue(name: JourneyConstants.version, value: "2.0")
        newCallback.initValue(name: JourneyConstants.createDate, value: "2024-12-15T09:00:00.000Z")
        newCallback.initValue(name: JourneyConstants.terms, value: "By using our service, you agree to comply with and be bound by these terms and conditions.")

        // User reviews and initially declines
        newCallback.accepted = false

        let declinedPayload = newCallback.payload()
        if let inputArray = declinedPayload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertFalse(value)
        }

        // User reconsiders and accepts
        newCallback.accepted = true

        let acceptedPayload = newCallback.payload()
        if let inputArray = acceptedPayload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertTrue(value)
        }
    }

    func testDifferentVersionFormats() {
        let newCallback = TermsAndConditionsCallback()

        // Test realistic version numbering schemes
        let versionSchemes = [
            "1.0",
            "2.1.4",
            "v3.0.0",
            "2024.1",
            "2025-Q1",
            "beta-1.2",
            "release-candidate-2.0",
            "latest"
        ]

        for version in versionSchemes {
            newCallback.initValue(name: JourneyConstants.version, value: version)
            XCTAssertEqual(newCallback.version, version, "Failed for version format: \(version)")
        }
    }

    func testInternationalTermsContent() {
        let newCallback = TermsAndConditionsCallback()

        // Test terms in different languages
        let internationalTerms = [
            "Términos y Condiciones: Al utilizar este servicio, usted acepta estar sujeto a estos términos.", // Spanish
            "Conditions d'utilisation: En utilisant ce service, vous acceptez d'être lié par ces conditions.", // French
            "Nutzungsbedingungen: Durch die Nutzung dieses Dienstes stimmen Sie diesen Bedingungen zu.", // German
            "利用規約：このサービスを利用することにより、これらの利用規約に同意したものとみなされます。", // Japanese
            "شروط الاستخدام: باستخدام هذه الخدمة، فإنك توافق على الالتزام بهذه الشروط." // Arabic
        ]

        for internationalTerm in internationalTerms {
            newCallback.initValue(name: JourneyConstants.terms, value: internationalTerm)
            XCTAssertEqual(newCallback.terms, internationalTerm, "Failed for international terms")
        }
    }

    func testISODateFormats() {
        let newCallback = TermsAndConditionsCallback()

        // Test various ISO date formats
        let dateFormats = [
            "2019-07-11T22:23:55.737Z",
            "2025-01-15T10:30:00.000Z",
            "2024-12-31T23:59:59.999Z",
            "2020-01-01T00:00:00.000Z",
            "2023-06-15T14:45:30.123+00:00",
            "2024-03-20T08:15:45-05:00"
        ]

        for dateFormat in dateFormats {
            newCallback.initValue(name: JourneyConstants.createDate, value: dateFormat)
            XCTAssertEqual(newCallback.createDate, dateFormat, "Failed for date format: \(dateFormat)")
        }
    }

    func testTermsWithSpecialCharacters() {
        let newCallback = TermsAndConditionsCallback()
        let specialTerms = """
        Terms & Conditions with Special Characters:
        
        • Bullet points are allowed
        ★ Special symbols work
        "Quoted text is preserved"
        'Single quotes too'
        <HTML tags> should be preserved as text
        {"JSON": "structures"} are treated as text
        URLs like https://example.com are preserved
        Email addresses like legal@company.com work
        Phone numbers +1-555-123-4567 are fine
        Mathematical expressions: a² + b² = c²
        Copyright symbols: © ® ™
        """

        newCallback.initValue(name: JourneyConstants.terms, value: specialTerms)

        XCTAssertEqual(newCallback.terms, specialTerms)
        XCTAssertTrue(newCallback.terms.contains("Special Characters"))
        XCTAssertTrue(newCallback.terms.contains("https://example.com"))
    }

    func testRealWorldTermsScenario() {
        // Test with realistic production terms and conditions
        callback.initValue(name: JourneyConstants.version, value: "4.1.2")
        callback.initValue(name: JourneyConstants.createDate, value: "2025-08-01T12:00:00.000Z")
        callback.initValue(name: JourneyConstants.terms, value: """
        TERMS OF SERVICE
        
        Effective Date: August 1, 2025
        
        1. ACCEPTANCE OF TERMS
        By creating an account or using our services, you agree to be bound by these Terms of Service.
        
        2. PRIVACY
        Your privacy is important to us. Our Privacy Policy explains how we collect and use your information.
        
        3. USER CONDUCT
        You agree to use our service responsibly and in accordance with applicable laws.
        
        4. MODIFICATIONS
        We may modify these terms at any time. Continued use constitutes acceptance of modified terms.
        
        For questions, contact: legal@ourcompany.com
        """)

        XCTAssertEqual(callback.version, "4.1.2")
        XCTAssertEqual(callback.createDate, "2025-08-01T12:00:00.000Z")
        XCTAssertTrue(callback.terms.contains("TERMS OF SERVICE"))
        XCTAssertTrue(callback.terms.contains("legal@ourcompany.com"))

        // User accepts the comprehensive terms
        callback.accepted = true

        let payload = callback.payload()
        if let inputArray = payload["input"] as? [[String: Any]],
           let firstInput = inputArray.first,
           let value = firstInput["value"] as? Bool {
            XCTAssertTrue(value)
        } else {
            XCTFail("Payload structure is not as expected for real-world terms")
        }
    }
}
