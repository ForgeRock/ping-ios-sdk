//
//  RecognizeTests.swift
//  RecognizeTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import KeylessSDK
@testable import PingRecognize
import PingJourneyPlugin

// MARK: - RecognizeErrorTests

final class RecognizeErrorTests: XCTestCase {

    func testInitStoresMessageCodeNameAndSdkCode() {
        let error = RecognizeError(
            "something went wrong", code: 3003, name: "CORE_USER_NOT_ENROLLED", sdkCode: 20000
        )
        XCTAssertEqual(error.message, "something went wrong")
        XCTAssertEqual(error.code, 3003)
        XCTAssertEqual(error.name, "CORE_USER_NOT_ENROLLED")
        XCTAssertEqual(error.sdkCode, 20000)
    }

    func testNameAndSdkCodeDefaultToNil() {
        let error = RecognizeError("created without a shared name", code: 5)
        XCTAssertEqual(error.code, 5)
        XCTAssertNil(error.name)
        XCTAssertNil(error.sdkCode)
    }

    func testClientSideErrorIsSdkErrorWithoutSdkCode() {
        // Errors raised on-device, before any Keyless SDK call, are reported as SDK_ERROR.
        let error = AbstractRecognizeCallback.clientSideError("on-device failure")
        XCTAssertEqual(error.message, "on-device failure")
        XCTAssertEqual(error.code, 1000)
        XCTAssertEqual(error.name, "SDK_ERROR")
        XCTAssertNil(error.sdkCode)
    }

    func testErrorDescriptionMatchesMessage() {
        let error = RecognizeError("network timeout", code: 1007)
        XCTAssertEqual(error.errorDescription, "network timeout")
    }

    func testEmptyMessageIsAllowed() {
        let error = RecognizeError("", code: 0)
        XCTAssertEqual(error.message, "")
        XCTAssertEqual(error.errorDescription, "")
    }

    func testConformsToLocalizedError() {
        let error: LocalizedError = RecognizeError("test", code: 0)
        XCTAssertEqual(error.errorDescription, "test")
    }

    func testDebuggingInfoDefaultsToEmpty() {
        let error = RecognizeError("no diagnostics", code: 0)
        XCTAssertTrue(error.debuggingInfo.isEmpty)
    }

    func testDebuggingInfoStoresProvidedValues() {
        let error = RecognizeError(
            "sdk failure", code: 1,
            debuggingInfo: ["flowId": "flow-123", "sessionId": "session-456"]
        )
        XCTAssertEqual(error.debuggingInfo["flowId"], "flow-123")
        XCTAssertEqual(error.debuggingInfo["sessionId"], "session-456")
    }
}

// MARK: - SharedErrorCodeTests

final class SharedErrorCodeTests: XCTestCase {

    // MARK: Transcription guard

    /// The shared iOS mapping (version 6.0.0), written out independently of the production
    /// table: (native Keyless code, shared code, shared name). A typo in either place fails
    /// the test below. This guards against accidental edits only: it does not read the
    /// shared model, so when that gains an entry (e.g. native 20024 userProfileError) the
    /// table and this list have to be updated by hand.
    private static let expectedMapping: [(native: Int, shared: Int, name: String)] = [
        (10000, 1000, "SDK_ERROR"),
        (10001, 1009, "SDK_ARTIFACT_RETRIEVE_FAILED"),
        (10003, 1003, "SDK_LOGGING_CONFIGURATION_FAILED"),
        (10004, 2000, "CAMERA_ERROR"),
        (10005, 1004, "SDK_STORAGE_FAILED"),
        (10006, 1016, "SDK_INVALID_CUSTOMER_PROPERTIES"),
        (10100, 4000, "BIOM_ERROR"),
        (10200, 3000, "CORE_ERROR"),
        (20000, 3003, "CORE_USER_NOT_ENROLLED"),
        (20001, 3002, "CORE_USER_ALREADY_ENROLLED"),
        (20002, 1001, "SDK_NOT_CONFIGURED"),
        (20010, 1002, "SDK_INVALID_CONFIGURATION"),
        (20013, 3001, "CORE_NOT_ENOUGH_API_KEY_SEATS"),
        (20021, 4003, "BIOM_LIVENESS_ENVIRONMENT_AWARE_NOT_SUPPORTED"),
        (20022, 4004, "BIOM_DEVICE_ENVIRONMENT_AWARE_NOT_SUPPORTED"),
        (20023, 1010, "SDK_INVALID_CLIENT_STATE"),
        (20150, 1008, "SDK_DYNAMIC_LINKING_PAYLOAD_MALFORMED"),
        (20300, 3006, "CORE_SECRET_NOT_FOUND"),
        (30000, 4002, "BIOM_GENUINE_PRESENCE_NOT_ESTABLISHED"),
        (30001, 1006, "SDK_TIMEOUT"),
        (30003, 1005, "SDK_USER_CANCELLED"),
        (30004, 3004, "CORE_FACE_NOT_MATCHING"),
        (30005, 1007, "SDK_NO_NETWORK_CONNECTION"),
        (30007, 3007, "CORE_USER_LOCKED_OUT"),
        (30008, 4001, "BIOM_REJECTED"),
        (30009, 2002, "CAMERA_PERMISSION_DENIED"),
        (30010, 1012, "SDK_OUTDATED_APP"),
        (40000, 6000, "SECURITY_ERROR"),
        (40002, 6001, "SECURITY_DEVICE_NOT_GENUINE"),
    ]

    func testNativeToSharedTableMatchesExpectedMapping() {
        XCTAssertEqual(SharedErrorCode.nativeToShared.count, Self.expectedMapping.count)
        XCTAssertEqual(Self.expectedMapping.count, 29)
        for expected in Self.expectedMapping {
            let resolved = SharedErrorCode.resolve(nativeCode: expected.native)
            XCTAssertEqual(resolved.rawValue, expected.shared, "shared code for native \(expected.native)")
            XCTAssertEqual(resolved.name, expected.name, "shared name for native \(expected.native)")
            XCTAssertNotNil(SharedErrorCode.nativeToShared[expected.native], "native \(expected.native) must be an explicit entry, not the fallback")
        }
    }

    // MARK: The integrator-reported scenario

    /// The reported scenario: a not-enrolled user authenticating surfaced the raw Keyless
    /// message. After the mapping, native 20000 (userNotEnrolled) resolves to the shared
    /// CORE_USER_NOT_ENROLLED (3003) — the same name the shared model defines.
    func testResolveNotEnrolledToSharedCoreUserNotEnrolled() {
        let resolved = SharedErrorCode.resolve(nativeCode: 20000)
        XCTAssertEqual(resolved, .coreUserNotEnrolled)
        XCTAssertEqual(resolved.rawValue, 3003)
        XCTAssertEqual(resolved.name, "CORE_USER_NOT_ENROLLED")
    }

    // MARK: Fallback for unmapped native codes

    func testResolveUnmappedNativeCodeFallsBackToSdkError() {
        // 20024 (userProfileError) exists in the Keyless SDK but is not in the shared mapping.
        for unmapped in [20024, 99999, 0, -5] {
            let resolved = SharedErrorCode.resolve(nativeCode: unmapped)
            XCTAssertEqual(resolved, .sdkError)
            XCTAssertEqual(resolved.rawValue, 1000)
            XCTAssertEqual(resolved.name, "SDK_ERROR")
        }
    }

    // MARK: Conversion helper (the createRecognizeError counterpart)

    func testRecognizeErrorFromNativeMapsKnownCode() {
        let error = AbstractRecognizeCallback.recognizeError(
            fromNativeMessage: "You must be enrolled to perform this action",
            nativeCode: 20000,
            debuggingInfo: ["flowId": "flow-1"]
        )
        XCTAssertEqual(error.message, "You must be enrolled to perform this action")
        XCTAssertEqual(error.code, 3003)
        XCTAssertEqual(error.name, "CORE_USER_NOT_ENROLLED")
        XCTAssertEqual(error.sdkCode, 20000)
        XCTAssertEqual(error.errorDescription, "You must be enrolled to perform this action")
        XCTAssertEqual(error.debuggingInfo["flowId"], "flow-1")
        // The native code is mirrored into debuggingInfo for log-based debugging.
        XCTAssertEqual(error.debuggingInfo["sdkCode"], "20000")
    }

    func testRecognizeErrorFromNativeFallbackPreservesNativeCode() {
        let error = AbstractRecognizeCallback.recognizeError(
            fromNativeMessage: "profile error", nativeCode: 20024, debuggingInfo: [:]
        )
        XCTAssertEqual(error.code, 1000)
        XCTAssertEqual(error.name, "SDK_ERROR")
        XCTAssertEqual(error.sdkCode, 20024)
        XCTAssertEqual(error.debuggingInfo["sdkCode"], "20024")
    }

    func testRecognizeErrorFromNativeDoesNotMutatePassedDebuggingInfo() {
        var info = ["flowId": "flow-1"]
        _ = AbstractRecognizeCallback.recognizeError(
            fromNativeMessage: "msg", nativeCode: 20000, debuggingInfo: info
        )
        XCTAssertNil(info["sdkCode"])
        XCTAssertEqual(info["flowId"], "flow-1")
    }

    // MARK: End-to-end wire value

    private func inputValue(for key: String, in callback: AbstractRecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    /// `report()` submits the shared error name in `clientError` (the Journey filters on it)
    /// and the shared code in `clientErrorCode`, not the human message or the native Keyless
    /// code. The mapping itself is covered by the helper tests above.
    func testReportSubmitsSharedNameAndCode() async {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        let json: [String: Any] = [
            "input": inputKeys.map { ["name": $0, "value": ""] },
            "output": [["name": JourneyConstants.operationType, "value": "ENROLL"]],
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = RealPathEnrollCallback()
        _ = await cb.initialize(with: json)
        cb.keylessEnrollResult = .failure(RecognizeError(
            "You must be enrolled to perform this action",
            code: 3003, name: "CORE_USER_NOT_ENROLLED", sdkCode: 20000
        ))
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "CORE_USER_NOT_ENROLLED")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "3003")
    }
}

// MARK: - RecognizeMobileSDKOptionsTests + RecognizeCallbackConstantsTests

final class RecognizeMobileSDKOptionsTests: XCTestCase {

    // MARK: Boolean computed properties

    func testBoolTrueReturnsTrueForExactString() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.livenessEnvironmentAware: "true",
            JourneyConstants.showSuccessFeedback: "true",
            JourneyConstants.showFailureFeedback: "true",
            JourneyConstants.showInstructionsScreen: "true",
        ])
        XCTAssertEqual(opts.livenessEnvironmentAware, true)
        XCTAssertEqual(opts.showSuccessFeedback, true)
        XCTAssertEqual(opts.showFailureFeedback, true)
        XCTAssertEqual(opts.showInstructionsScreen, true)
    }

    func testBoolFalseWhenKeyAbsent() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertNil(opts.livenessEnvironmentAware)
        XCTAssertNil(opts.showSuccessFeedback)
        XCTAssertNil(opts.showFailureFeedback)
        XCTAssertNil(opts.showInstructionsScreen)
    }

    func testBoolFalseForNonTrueString() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.livenessEnvironmentAware: "false",
            JourneyConstants.showSuccessFeedback: "false"
        ])
        XCTAssertEqual(opts.livenessEnvironmentAware, false)
        XCTAssertEqual(opts.showSuccessFeedback, false)
    }

    func testBoolFalseWhenExplicitlySetToFalse() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.showSuccessFeedback: "false",
            JourneyConstants.showFailureFeedback: "false",
            JourneyConstants.showInstructionsScreen: "false"
        ])
        XCTAssertEqual(opts.showSuccessFeedback, false)
        XCTAssertEqual(opts.showFailureFeedback, false)
        XCTAssertEqual(opts.showInstructionsScreen, false)
    }

    // MARK: Integer coercion

    func testCameraDelaySecondsValidInt() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.cameraDelaySeconds: "3"])
        XCTAssertEqual(opts.cameraDelaySeconds, 3)
    }

    func testCameraDelaySecondsAbsentReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertNil(opts.cameraDelaySeconds)
    }

    func testCameraDelaySecondsNonNumericReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.cameraDelaySeconds: "abc"])
        XCTAssertNil(opts.cameraDelaySeconds)
    }

    func testNumberOfEnrollmentCircuitsValidInt() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.numberOfEnrollmentCircuits: "7"])
        XCTAssertEqual(opts.numberOfEnrollmentCircuits, 7)
    }

    func testNumberOfEnrollmentCircuitsAbsentReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertNil(opts.numberOfEnrollmentCircuits)
    }

    func testNumberOfEnrollmentCircuitsNonNumericReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.numberOfEnrollmentCircuits: "nope"])
        XCTAssertNil(opts.numberOfEnrollmentCircuits)
    }

    // MARK: String properties

    func testStringPropertiesPresentReturnsValue() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.livenessConfiguration: "LEVEL_2",
            JourneyConstants.operationInfoId: "op-id-123",
            JourneyConstants.operationInfoPayload: "payload-abc",
            JourneyConstants.operationInfoExternalUserId: "user-xyz",
            JourneyConstants.presentation: "OVERLAY",
            JourneyConstants.presentationStyle: "CAMERA_PREVIEW"
        ])
        XCTAssertEqual(opts.livenessConfiguration, "LEVEL_2")
        XCTAssertEqual(opts.operationInfoId, "op-id-123")
        XCTAssertEqual(opts.operationInfoPayload, "payload-abc")
        XCTAssertEqual(opts.operationInfoExternalUserId, "user-xyz")
        XCTAssertEqual(opts.presentation, "OVERLAY")
        XCTAssertEqual(opts.presentationStyle, "CAMERA_PREVIEW")
    }

    func testStringPropertiesAbsentReturnEmptyString() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertEqual(opts.livenessConfiguration, "")
        XCTAssertEqual(opts.operationInfoId, "")
        XCTAssertEqual(opts.operationInfoPayload, "")
        XCTAssertEqual(opts.operationInfoExternalUserId, "")
        XCTAssertEqual(opts.presentation, "")
        XCTAssertEqual(opts.presentationStyle, "")
    }
}

// MARK: - RecognizeCallbackInitValueTests

final class RecognizeCallbackInitValueTests: XCTestCase {

    // MARK: operationType

    func testInitValueOperationTypeEnroll() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "ENROLL")
        XCTAssertEqual(callback.operationType, .enroll)
    }

    func testInitValueOperationTypeAuthenticate() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "AUTHENTICATE")
        XCTAssertEqual(callback.operationType, .authenticate)
    }

    func testInitValueOperationTypeUnknownStaysNil() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "UNKNOWN")
        XCTAssertNil(callback.operationType)
    }

    func testInitValueOperationTypeMixedCaseIsRejected() {
        // Exact match only, matching the Android SDK — no case normalization.
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "authenticate")
        XCTAssertNil(callback.operationType)
    }

    // MARK: String output fields

    func testInitValueWebsocketURL() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.websocketURL, value: "wss://example.com/ws")
        XCTAssertEqual(callback.websocketURL, "wss://example.com/ws")
    }

    func testInitValueCustomerName() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.customerName, value: "Acme Corp")
        XCTAssertEqual(callback.customerName, "Acme Corp")
    }

    func testInitValueImageEncryptionPublicKey() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.imageEncryptionPublicKey, value: "MFwwDQYJ")
        XCTAssertEqual(callback.imageEncryptionPublicKey, "MFwwDQYJ")
    }

    func testInitValueImageEncryptionKeyId() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.imageEncryptionKeyId, value: "key-id-007")
        XCTAssertEqual(callback.imageEncryptionKeyId, "key-id-007")
    }

    func testInitValueHost() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.host, value: "https://recognize.ping.com")
        XCTAssertEqual(callback.host, "https://recognize.ping.com")
    }

    func testInitValueApiKey() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.apiKey, value: "api-key-abc")
        XCTAssertEqual(callback.apiKey, "api-key-abc")
    }

    func testInitValueUsername() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.username, value: "testuser")
        XCTAssertEqual(callback.username, "testuser")
    }

    func testInitValueTransactionData() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.transactionData, value: "tx-data-payload")
        XCTAssertEqual(callback.transactionData, "tx-data-payload")
    }

    func testInitValueGenerateClientStateString() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.generateClientState, value: "true")
        XCTAssertTrue(callback.generateClientState)
    }

    func testInitValueGenerateClientStateBoolTrue() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.generateClientState, value: true)
        XCTAssertTrue(callback.generateClientState)
    }

    func testInitValueGenerateClientStateBoolFalse() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.generateClientState, value: false)
        XCTAssertFalse(callback.generateClientState)
    }

    func testInitValueClientState() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.clientState, value: "client-state-blob")
        XCTAssertEqual(callback.clientState, "client-state-blob")
    }

    // MARK: mobileSDKOptions

    func testInitValueMobileSDKOptionsStringDict() {
        let callback = RecognizeCallback()
        let raw: [String: Any] = [
            JourneyConstants.livenessConfiguration: "LEVEL_1",
            JourneyConstants.livenessEnvironmentAware: "true"
        ]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: raw)
        XCTAssertEqual(callback.mobileSDKOptions.livenessConfiguration, "LEVEL_1")
        XCTAssertEqual(callback.mobileSDKOptions.livenessEnvironmentAware, true)
    }

    func testInitValueMobileSDKOptionsNonStringValuesCoerced() {
        let callback = RecognizeCallback()
        let raw: [String: Any] = [JourneyConstants.cameraDelaySeconds: 4]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: raw)
        // The value 4 is coerced to "4" via string interpolation; Int("4") == 4
        XCTAssertEqual(callback.mobileSDKOptions.cameraDelaySeconds, 4)
    }

    func testInitValueMobileSDKOptionsUnknownCustomSecretIsIgnored() {
        let callback = RecognizeCallback()
        let raw: [String: Any] = ["customSecret": "server-secret"]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: raw)
        XCTAssertEqual(callback.mobileSDKOptions.livenessConfiguration, "")
        XCTAssertNil(callback.mobileSDKOptions.cameraDelaySeconds)
    }

    func testInitValueMobileSDKOptionsEmptyDictProducesNilForOptionals() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: [String: Any]())
        XCTAssertNil(callback.mobileSDKOptions.livenessEnvironmentAware)
        XCTAssertNil(callback.mobileSDKOptions.cameraDelaySeconds)
        XCTAssertNil(callback.mobileSDKOptions.numberOfEnrollmentCircuits)
    }

    func testInitValueUnknownKeyIsIgnored() {
        let callback = RecognizeCallback()
        // Should not crash; all properties retain their defaults.
        callback.initValue(name: "unknownOutputField", value: "irrelevant")
        XCTAssertNil(callback.operationType)
        XCTAssertEqual(callback.websocketURL, "")
    }

    func testInitValueWrongTypeForStringFieldIsIgnored() {
        let callback = RecognizeCallback()
        // Passing a non-String for a string field — the guard `value as? String` should fail silently.
        callback.initValue(name: JourneyConstants.websocketURL, value: 42)
        XCTAssertEqual(callback.websocketURL, "")
    }
}

// MARK: - RecognizeCallbackInputSetterTests

final class RecognizeCallbackInputSetterTests: XCTestCase {

    /// Builds a RecognizeCallback whose `json` already contains an `input` array
    /// with all six Recognize input keys — mirrors what the Journey framework delivers.
    private func makeCallback() async -> RecognizeCallback {
        let inputKeys = [
            JourneyConstants.inputSignedJwt,
            JourneyConstants.inputClientState,
            JourneyConstants.inputRecognizeId,
            JourneyConstants.inputDevicePublicSigningKey,
            JourneyConstants.inputClientError,
            JourneyConstants.inputClientErrorCode
        ]
        let inputArray = inputKeys.map { ["name": $0, "value": ""] }
        let json: [String: Any] = ["input": inputArray, "output": [], "type": "PingOneRecognizeCallback"]
        let callback = RecognizeCallback()
        _ = await callback.initialize(with: json)
        return callback
    }

    private func inputValue(for key: String, in callback: RecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    func testSetSignedJwt() async {
        let callback = await makeCallback()
        callback.setSignedJwt("jwt-token-xyz")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputSignedJwt, in: callback), "jwt-token-xyz")
    }

    func testSetClientState() async {
        let callback = await makeCallback()
        callback.setClientState("state-blob")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientState, in: callback), "state-blob")
    }

    func testSetRecognizeId() async {
        let callback = await makeCallback()
        callback.setRecognizeId("recognize-id-001")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: callback), "recognize-id-001")
    }

    func testSetDevicePublicSigningKey() async {
        let callback = await makeCallback()
        callback.setDevicePublicSigningKey("public-key-pem")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: callback), "public-key-pem")
    }

    func testSetClientErrorCode() async {
        let callback = await makeCallback()
        callback.setClientErrorCode("ERR_001")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: callback), "ERR_001")
    }

    func testErrorHelper() async {
        let callback = await makeCallback()
        callback.error("something went wrong")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: callback), "something went wrong")
    }
}

// MARK: - PopulateResultInputsTests

final class PopulateResultInputsTests: XCTestCase {

    private func makeCallback() async -> RecognizeCallback {
        let inputKeys = [
            JourneyConstants.inputSignedJwt,
            JourneyConstants.inputClientState,
            JourneyConstants.inputRecognizeId,
            JourneyConstants.inputDevicePublicSigningKey,
            JourneyConstants.inputClientError,
            JourneyConstants.inputClientErrorCode
        ]
        let inputArray = inputKeys.map { ["name": $0, "value": ""] }
        let json: [String: Any] = ["input": inputArray, "output": [], "type": "PingOneRecognizeCallback"]
        let callback = RecognizeCallback()
        _ = await callback.initialize(with: json)
        return callback
    }

    private func inputValue(for key: String, in callback: RecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    func testPopulatesAllFourResultInputs() async {
        let callback = await makeCallback()
        callback.populateResultInputs(
            signedJwt: "jwt", clientState: "state", recognizeId: "rid", devicePublicSigningKey: "pem-key"
        )
        XCTAssertEqual(inputValue(for: JourneyConstants.inputSignedJwt, in: callback), "jwt")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientState, in: callback), "state")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: callback), "rid")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: callback), "pem-key")
    }

    func testNilValuesLeaveInputsUntouched() async {
        let callback = await makeCallback()
        callback.populateResultInputs(signedJwt: nil, clientState: nil, recognizeId: nil, devicePublicSigningKey: nil)
        XCTAssertEqual(inputValue(for: JourneyConstants.inputSignedJwt, in: callback), "")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientState, in: callback), "")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: callback), "")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: callback), "")
    }
}

// MARK: - RealPathEnrollCallback (Keyless-boundary seams only)

/// Subclass that overrides only the two Keyless SDK boundary seams — `performKeylessEnroll`
/// and `devicePublicSigningKey()` — leaving `performEnroll`'s own body (config building, the
/// `devicePublicSigningKey()` lookup, and the `populateResultInputs` call) untouched.
///
/// Regression test for the enrollment-signing-key fix: unlike `TestableEnrollCallback`, which
/// overrides `performEnroll` wholesale and so never runs its body, this drives the actual
/// method — if `performEnroll` ever stopped calling `devicePublicSigningKey()` or
/// `populateResultInputs(...)`, this is the test that would fail.
class RealPathEnrollCallback: PingOneRecognizeEnrollCallback {
    var configureResult: Error? = nil
    var keylessEnrollResult: Result<RecognizeSuccess, Error> = .success(
        RecognizeSuccess(signedJwt: "jwt", clientState: "state", recognizeId: "rid", selfie: nil)
    )
    var stubbedSigningKey: String? = "stub-signing-key"

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func performKeylessEnroll(configuration: BiomEnrollConfig) async throws -> RecognizeSuccess {
        switch keylessEnrollResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    override func devicePublicSigningKey() -> String? {
        stubbedSigningKey
    }
}

final class RealPathEnrollTests: XCTestCase {

    private func inputArrayWith(keys: [String]) -> [[String: Any]] {
        keys.map { ["name": $0, "value": ""] }
    }

    private func inputValue(for key: String, in callback: AbstractRecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    private func makeCallback() async -> RealPathEnrollCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": [["name": JourneyConstants.operationType, "value": "ENROLL"]],
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = RealPathEnrollCallback()
        _ = await cb.initialize(with: json)
        return cb
    }

    func testRealPerformEnrollWritesDevicePublicSigningKeyToInputField() async {
        let cb = await makeCallback()
        let result = await cb.enroll()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: cb), "stub-signing-key")
    }

    func testRealPerformEnrollAlsoWritesSignedJwtClientStateAndRecognizeId() async {
        let cb = await makeCallback()
        let result = await cb.enroll()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputSignedJwt, in: cb), "jwt")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientState, in: cb), "state")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: cb), "rid")
    }

    func testRealPerformEnrollNilSigningKeyLeavesInputFieldUntouched() async {
        let cb = await makeCallback()
        cb.stubbedSigningKey = nil
        let result = await cb.enroll()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: cb), "")
    }

    func testRealPerformEnrollReturnsResultMatchingCeremonyOutcome() async {
        let cb = await makeCallback()
        cb.keylessEnrollResult = .success(
            RecognizeSuccess(signedJwt: "custom-jwt", clientState: "custom-state", recognizeId: "custom-rid", selfie: nil)
        )
        let result = await cb.enroll()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "custom-jwt")
        XCTAssertEqual(r.recognizeId, "custom-rid")
    }

    func testRealPerformEnrollCeremonyFailurePropagatesWithoutWritingSigningKey() async {
        let cb = await makeCallback()
        cb.keylessEnrollResult = .failure(RecognizeError("ceremony failed", code: 1006, name: "SDK_TIMEOUT", sdkCode: 30001))
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: cb), "")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_TIMEOUT")
    }
}

// MARK: - RealPathAuthCallback (Keyless-boundary seams only)

/// Subclass that overrides only the three Keyless SDK boundary seams —
/// `performKeylessAuthenticate`, `authenticatedUserId()`, and `devicePublicSigningKey()` —
/// leaving `performAuthenticate`'s own body (config building, the two lookups, and the
/// `populateResultInputs` call) untouched.
///
/// Regression test mirroring `RealPathEnrollCallback`: unlike `TestableAuthCallback`, which
/// overrides `performAuthenticate` wholesale and so never runs its body, this drives the
/// actual method.
class RealPathAuthCallback: PingOneRecognizeAuthenticateCallback {
    var configureResult: Error? = nil
    var keylessAuthenticateResult: Result<RecognizeSuccess, Error> = .success(
        RecognizeSuccess(signedJwt: "jwt", clientState: "state", recognizeId: nil, selfie: nil)
    )
    var stubbedUserId: String? = "stub-user-id"
    var stubbedSigningKey: String? = "stub-signing-key"

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func performKeylessAuthenticate(configuration: BiomAuthConfig) async throws -> RecognizeSuccess {
        switch keylessAuthenticateResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    override func authenticatedUserId() -> String? {
        stubbedUserId
    }

    override func devicePublicSigningKey() -> String? {
        stubbedSigningKey
    }
}

final class RealPathAuthenticateTests: XCTestCase {

    private func inputArrayWith(keys: [String]) -> [[String: Any]] {
        keys.map { ["name": $0, "value": ""] }
    }

    private func inputValue(for key: String, in callback: AbstractRecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    /// `output` carries only `operationType` (no `clientState`), so `authenticate()` routes to
    /// the plain `performAuthenticate` path rather than `enrollWithClientStateIfNeeded`.
    private func makeCallback() async -> RealPathAuthCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": [["name": JourneyConstants.operationType, "value": "AUTHENTICATE"]],
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = RealPathAuthCallback()
        _ = await cb.initialize(with: json)
        return cb
    }

    func testRealPerformAuthenticateWritesDevicePublicSigningKeyToInputField() async {
        let cb = await makeCallback()
        let result = await cb.authenticate()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: cb), "stub-signing-key")
    }

    func testRealPerformAuthenticateWritesRecognizeIdFromAuthenticatedUserId() async {
        let cb = await makeCallback()
        let result = await cb.authenticate()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: cb), "stub-user-id")
    }

    func testRealPerformAuthenticateAlsoWritesSignedJwtAndClientState() async {
        let cb = await makeCallback()
        let result = await cb.authenticate()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputSignedJwt, in: cb), "jwt")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientState, in: cb), "state")
    }

    func testRealPerformAuthenticateNilSigningKeyLeavesInputFieldUntouched() async {
        let cb = await makeCallback()
        cb.stubbedSigningKey = nil
        let result = await cb.authenticate()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: cb), "")
    }

    func testRealPerformAuthenticateNilUserIdLeavesRecognizeIdUntouched() async {
        let cb = await makeCallback()
        cb.stubbedUserId = nil
        let result = await cb.authenticate()
        guard case .success = result else { return XCTFail("Expected success") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: cb), "")
    }

    func testRealPerformAuthenticateReturnsResultMatchingCeremonyOutcome() async {
        let cb = await makeCallback()
        cb.keylessAuthenticateResult = .success(
            RecognizeSuccess(signedJwt: "custom-jwt", clientState: "custom-state", recognizeId: nil, selfie: nil)
        )
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "custom-jwt")
        XCTAssertEqual(r.clientState, "custom-state")
        XCTAssertEqual(r.recognizeId, "stub-user-id")
    }

    func testRealPerformAuthenticateCeremonyFailurePropagatesWithoutWritingSigningKey() async {
        let cb = await makeCallback()
        cb.keylessAuthenticateResult = .failure(RecognizeError("ceremony failed", code: 1000, name: "SDK_ERROR", sdkCode: 50001))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: cb), "")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
    }
}

// MARK: - StringDictionaryTests

final class StringDictionaryTests: XCTestCase {

    func testStringStringDictPassthroughUnchanged() {
        let callback = RecognizeCallback()
        let input: [String: Any] = ["key1": "value1", "key2": "value2"]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: input)
        XCTAssertEqual(callback.mobileSDKOptions.operationInfoId, "")
        XCTAssertEqual(callback.mobileSDKOptions.livenessConfiguration, "")
    }

    func testStringAnyDictWithNonStringValuesCoerced() {
        let callback = RecognizeCallback()
        let input: [String: Any] = [
            JourneyConstants.cameraDelaySeconds: 3,
            JourneyConstants.numberOfEnrollmentCircuits: 7
        ]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: input)
        XCTAssertEqual(callback.mobileSDKOptions.cameraDelaySeconds, 3)
        XCTAssertEqual(callback.mobileSDKOptions.numberOfEnrollmentCircuits, 7)
    }

    func testNonDictValueProducesEmptyOptions() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: "not-a-dict")
        XCTAssertNil(callback.mobileSDKOptions.cameraDelaySeconds)
        XCTAssertNil(callback.mobileSDKOptions.numberOfEnrollmentCircuits)
        XCTAssertNil(callback.mobileSDKOptions.livenessEnvironmentAware)
    }

    func testNSCFBooleanFalseCoercedCorrectly() throws {
        // JSONSerialization produces __NSCFBoolean, which interpolates as "0"/"1".
        // Verify that false JSON booleans are coerced to "false", not "0".
        let json = """
        {"showInstructionsScreen": false, "showSuccessFeedback": false, "livenessEnvironmentAware": false}
        """.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: parsed)
        XCTAssertEqual(callback.mobileSDKOptions.showInstructionsScreen, false)
        XCTAssertEqual(callback.mobileSDKOptions.showSuccessFeedback, false)
        XCTAssertEqual(callback.mobileSDKOptions.livenessEnvironmentAware, false)
    }

    func testNSCFBooleanTrueCoercedCorrectly() throws {
        let json = """
        {"showInstructionsScreen": true, "showSuccessFeedback": true, "livenessEnvironmentAware": true}
        """.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: parsed)
        XCTAssertEqual(callback.mobileSDKOptions.showInstructionsScreen, true)
        XCTAssertEqual(callback.mobileSDKOptions.showSuccessFeedback, true)
        XCTAssertEqual(callback.mobileSDKOptions.livenessEnvironmentAware, true)
    }

    func testIntegerZeroAndOneAreNotMistakenForBooleans() throws {
        // Regression test: NSNumber(1)/NSNumber(0) from JSONSerialization must NOT be
        // coerced to "true"/"false" just because `as? Bool` succeeds for any NSNumber on
        // Apple platforms — only genuine CFBoolean-backed values should be.
        let json = """
        {"cameraDelaySeconds": 1, "numberOfEnrollmentCircuits": 0, "showSuccessFeedback": true}
        """.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: parsed)
        XCTAssertEqual(callback.mobileSDKOptions.cameraDelaySeconds, 1)
        XCTAssertEqual(callback.mobileSDKOptions.numberOfEnrollmentCircuits, 0)
        XCTAssertEqual(callback.mobileSDKOptions.showSuccessFeedback, true)
    }
}


// MARK: - EnrollWithClientStateTests

final class EnrollWithClientStateTests: XCTestCase {

    func testClientStateAbsentRoutesToAuthenticateBranch() async {
        let inputKeys = [
            JourneyConstants.inputSignedJwt,
            JourneyConstants.inputClientState,
            JourneyConstants.inputRecognizeId,
            JourneyConstants.inputDevicePublicSigningKey,
            JourneyConstants.inputClientError,
            JourneyConstants.inputClientErrorCode
        ]
        let inputArray = inputKeys.map { ["name": $0, "value": ""] }
        let outputArray: [[String: Any]] = [
            ["name": JourneyConstants.operationType, "value": "AUTHENTICATE"]
        ]
        let json: [String: Any] = [
            "input": inputArray,
            "output": outputArray,
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let callback = RecognizeCallback()
        _ = await callback.initialize(with: json)

        XCTAssertEqual(callback.clientState, "")
        XCTAssertEqual(callback.operationType, .authenticate)

        let inputs = callback.json["input"] as? [[String: Any]]
        let recognizeIdValue = inputs?.first(where: { ($0["name"] as? String) == JourneyConstants.inputRecognizeId })?["value"] as? String
        XCTAssertEqual(recognizeIdValue, "")
    }
}

// MARK: - RecognizeOperationTypeTests

final class RecognizeOperationTypeTests: XCTestCase {

    func testRawValueEnroll() {
        XCTAssertEqual(RecognizeOperationType.enroll.rawValue, "ENROLL")
    }

    func testRawValueAuthenticate() {
        XCTAssertEqual(RecognizeOperationType.authenticate.rawValue, "AUTHENTICATE")
    }

    func testInitFromRawValueEnroll() {
        XCTAssertEqual(RecognizeOperationType(rawValue: "ENROLL"), .enroll)
    }

    func testInitFromRawValueAuthenticate() {
        XCTAssertEqual(RecognizeOperationType(rawValue: "AUTHENTICATE"), .authenticate)
    }

    func testInitFromRawValueUnknownReturnsNil() {
        XCTAssertNil(RecognizeOperationType(rawValue: "UNKNOWN"))
    }
}

// MARK: - Testable subclasses (injectable Keyless seam)

/// Subclass that replaces `configure()` and `performEnroll()` with configurable outcomes.
/// Used to test error-propagation without invoking the real Keyless SDK.
class TestableEnrollCallback: PingOneRecognizeEnrollCallback {
    var configureResult: Error? = nil
    var enrollResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: "state", recognizeId: "rid", selfie: nil))
    private(set) var capturedRetrieveSelfie: Bool?

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func performEnroll(clientStateOverride: String?, retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        capturedRetrieveSelfie = retrieveSelfie
        switch enrollResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

/// Subclass that replaces `configure()`, `performAuthenticate()`, and the enrollment-restore
/// dispatch (`enrollWithClientStateIfNeeded`) with configurable outcomes — used to test
/// `authenticate()`'s top-level clientState-empty-vs-non-empty routing in isolation.
class TestableAuthCallback: PingOneRecognizeAuthenticateCallback {
    var configureResult: Error? = nil
    var performAuthenticateResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: nil, recognizeId: nil, selfie: nil))
    var enrollWithClientStateIfNeededResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: "state", recognizeId: nil, selfie: nil))
    private(set) var capturedRetrieveSelfie: Bool?

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func performAuthenticate(retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        capturedRetrieveSelfie = retrieveSelfie
        switch performAuthenticateResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    override func enrollWithClientStateIfNeeded(_ clientState: String, retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        capturedRetrieveSelfie = retrieveSelfie
        switch enrollWithClientStateIfNeededResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

/// Subclass that overrides only `validateUserDeviceActive`, `performEnroll`, and
/// `performAuthenticate`, leaving the real `enrollWithClientStateIfNeeded` switch logic
/// intact so its routing can be tested.
class TestableValidationAuthCallback: PingOneRecognizeAuthenticateCallback {
    var configureResult: Error? = nil
    var validateResult: PingOneRecognizeAuthenticateCallback.ValidationResult = .notEnrolled
    var performEnrollResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: nil, recognizeId: "rid", selfie: nil))
    var performAuthenticateResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: nil, recognizeId: nil, selfie: nil))

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func validateUserDeviceActive() async -> PingOneRecognizeAuthenticateCallback.ValidationResult {
        validateResult
    }

    override func performEnroll(clientStateOverride: String?, retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        switch performEnrollResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    override func performAuthenticate(retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        switch performAuthenticateResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

// MARK: - ExecutePathTests

final class ExecutePathTests: XCTestCase {

    private func inputArrayWith(keys: [String]) -> [[String: Any]] {
        keys.map { ["name": $0, "value": ""] }
    }

    private func inputValue(for key: String, in callback: AbstractRecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    /// - Parameter operationType: The `operationType` output value to send, or `nil` to omit
    ///   the field entirely (simulating a server response that never sets it).
    private func makeEnrollCallback(operationType: String? = "ENROLL") async -> TestableEnrollCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        var output: [[String: Any]] = []
        if let operationType {
            output.append(["name": JourneyConstants.operationType, "value": operationType])
        }
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": output,
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = TestableEnrollCallback()
        _ = await cb.initialize(with: json)
        return cb
    }

    /// - Parameter operationType: The `operationType` output value to send, or `nil` to omit
    ///   the field entirely (simulating a server response that never sets it).
    private func makeAuthCallback(clientState: String = "", operationType: String? = "AUTHENTICATE") async -> TestableAuthCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        var output: [[String: Any]] = []
        if let operationType {
            output.append(["name": JourneyConstants.operationType, "value": operationType])
        }
        if !clientState.isEmpty {
            output.append(["name": JourneyConstants.clientState, "value": clientState])
        }
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": output,
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = TestableAuthCallback()
        _ = await cb.initialize(with: json)
        if !clientState.isEmpty {
            cb.initValue(name: JourneyConstants.clientState, value: clientState)
        }
        return cb
    }

    // MARK: operationType fail-closed

    func testEnrollFailsClosedWhenOperationTypeMissing() async {
        let cb = await makeEnrollCallback(operationType: nil)
        let result = await cb.enroll()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        let recognizeError = error as? RecognizeError
        // Mirrors Android's `require(operationType.isNotEmpty())` message.
        XCTAssertEqual(recognizeError?.message, "\"operationType\" is required in the PingOneRecognizeCallback output")
        XCTAssertEqual(recognizeError?.code, 1000)
        XCTAssertEqual(recognizeError?.name, "SDK_ERROR")
        XCTAssertNil(recognizeError?.sdkCode)
        // The Journey receives the shared SDK_ERROR, like any other unknown error.
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    func testEnrollFailsClosedWhenOperationTypeUnrecognized() async {
        let cb = await makeEnrollCallback()
        cb.initValue(name: JourneyConstants.operationType, value: "SOMETHING_ELSE")
        let result = await cb.enroll()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        let recognizeError = error as? RecognizeError
        // Mirrors Android's `else -> throw IllegalArgumentException("...is not supported")` message.
        XCTAssertEqual(recognizeError?.message, "\"operationType\": \"SOMETHING_ELSE\" is not supported")
        XCTAssertEqual(recognizeError?.name, "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    func testEnrollFailsClosedWhenOperationTypeMixedCase() async {
        let cb = await makeEnrollCallback()
        cb.initValue(name: JourneyConstants.operationType, value: "enroll")
        let result = await cb.enroll()
        guard case .failure(let error) = result else { return XCTFail("Expected failure — exact match only, no case normalization") }
        XCTAssertEqual((error as? RecognizeError)?.message, "\"operationType\": \"enroll\" is not supported")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
    }

    func testAuthenticateFailsClosedWhenOperationTypeMissing() async {
        let cb = await makeAuthCallback(operationType: nil)
        let result = await cb.authenticate()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        XCTAssertEqual((error as? RecognizeError)?.name, "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    // MARK: configure() failure

    func testEnrollConfigureFailurePopulatesClientError() async {
        let cb = await makeEnrollCallback()
        cb.configureResult = RecognizeError("sdk setup failed", code: 1009, name: "SDK_ARTIFACT_RETRIEVE_FAILED", sdkCode: 10001)
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ARTIFACT_RETRIEVE_FAILED")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1009")
    }

    func testAuthConfigureFailurePopulatesClientError() async {
        let cb = await makeAuthCallback()
        cb.configureResult = RecognizeError("setup error", code: 1001, name: "SDK_NOT_CONFIGURED", sdkCode: 20002)
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_NOT_CONFIGURED")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1001")
    }

    // MARK: enroll() failure

    func testEnrollFailurePopulatesClientErrorAndCode() async {
        let cb = await makeEnrollCallback()
        cb.enrollResult = .failure(RecognizeError("enroll failed", code: 1006, name: "SDK_TIMEOUT", sdkCode: 30001))
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_TIMEOUT")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1006")
    }

    func testEnrollSuccessReturnsResult() async {
        let cb = await makeEnrollCallback()
        cb.enrollResult = .success(RecognizeSuccess(signedJwt: "signed-token", clientState: nil, recognizeId: "rec-123", selfie: nil))
        let result = await cb.enroll()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "signed-token")
        XCTAssertEqual(r.recognizeId, "rec-123")
    }

    // MARK: retrieveSelfie — always an explicit, app-level decision (never from mobileSDKOptions)

    func testEnrollRetrieveSelfieDefaultsToFalse() async {
        let cb = await makeEnrollCallback()
        _ = await cb.enroll()
        XCTAssertEqual(cb.capturedRetrieveSelfie, false)
    }

    func testEnrollRetrieveSelfiePassedThroughWhenSetInConfig() async {
        let cb = await makeEnrollCallback()
        _ = await cb.enroll { $0.retrieveSelfie = true }
        XCTAssertEqual(cb.capturedRetrieveSelfie, true)
    }

    // MARK: enrollWithClientStateIfNeeded() failure — owned by the Authenticate callback,
    // matching Android (the AUTHENTICATE server operationType always maps to
    // PingOneRecognizeAuthenticateCallback; the enrollment-restore decision lives inside it).

    func testEnrollWithClientStateFailurePopulatesClientError() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        cb.enrollWithClientStateIfNeededResult = .failure(RecognizeError("restore failed", code: 1000, name: "SDK_ERROR", sdkCode: 40001))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    func testEnrollWithClientStateSuccessReturnsResult() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        cb.enrollWithClientStateIfNeededResult = .success(RecognizeSuccess(signedJwt: "jwt-restore", clientState: "new-state", recognizeId: nil, selfie: nil))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "jwt-restore")
        XCTAssertEqual(r.clientState, "new-state")
    }

    // MARK: performAuthenticate() failure

    func testAuthFailurePopulatesClientErrorAndCode() async {
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .failure(RecognizeError("auth failed", code: 1000, name: "SDK_ERROR", sdkCode: 50001))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    func testAuthSuccessReturnsResult() async {
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .success(RecognizeSuccess(signedJwt: "auth-jwt", clientState: "auth-state", recognizeId: nil, selfie: nil))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "auth-jwt")
        XCTAssertEqual(r.clientState, "auth-state")
    }

    // MARK: retrieveSelfie — always an explicit, app-level decision (never from mobileSDKOptions)

    func testAuthRetrieveSelfieDefaultsToFalse() async {
        let cb = await makeAuthCallback()
        _ = await cb.authenticate()
        XCTAssertEqual(cb.capturedRetrieveSelfie, false)
    }

    func testAuthRetrieveSelfiePassedThroughWhenSetInConfig() async {
        let cb = await makeAuthCallback()
        _ = await cb.authenticate { $0.retrieveSelfie = true }
        XCTAssertEqual(cb.capturedRetrieveSelfie, true)
    }

    func testEnrollWithClientStateRetrieveSelfiePassedThrough() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        _ = await cb.authenticate { $0.retrieveSelfie = true }
        XCTAssertEqual(cb.capturedRetrieveSelfie, true)
    }

    // MARK: clientState routing (inside PingOneRecognizeAuthenticateCallback.authenticate())

    func testEmptyClientStateRoutesToAuthenticate() async {
        let cb = await makeAuthCallback()
        // performAuthenticateResult is success; enrollWithClientStateIfNeededResult would fail if wrongly called
        cb.performAuthenticateResult = .success(RecognizeSuccess(signedJwt: "auth-jwt", clientState: nil, recognizeId: nil, selfie: nil))
        cb.enrollWithClientStateIfNeededResult = .failure(RecognizeError("should not be called", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via authenticate path") }
        XCTAssertEqual(r.signedJwt, "auth-jwt")
    }

    func testNonEmptyClientStateRoutesToEnrollWithClientStateIfNeeded() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        // enrollWithClientStateIfNeededResult is success; performAuthenticateResult would fail if wrongly called
        cb.enrollWithClientStateIfNeededResult = .success(RecognizeSuccess(signedJwt: "restore-jwt", clientState: "new-state", recognizeId: nil, selfie: nil))
        cb.performAuthenticateResult = .failure(RecognizeError("should not be called", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via enrollWithClientStateIfNeeded path") }
        XCTAssertEqual(r.signedJwt, "restore-jwt")
    }

    // MARK: non-RecognizeError propagation

    func testNonRecognizeErrorIsReportedAsSdkError() async {
        struct PlainError: LocalizedError {
            var errorDescription: String? { "plain error message" }
        }
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .failure(PlainError())
        let result = await cb.authenticate()
        // The caller still receives the original error unchanged...
        guard case .failure(let error) = result, error is PlainError else { return XCTFail("Expected the original error") }
        // ...while the Journey receives the shared SDK_ERROR, like any other unknown error.
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    func testRecognizeErrorWithoutNameIsReportedAsSdkError() async {
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .failure(RecognizeError("no shared name", code: 5))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    // MARK: validateUserDeviceActive routing inside enrollWithClientStateIfNeeded

    private func makeValidationCallback(clientState: String = "existing-state") async -> TestableValidationAuthCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": [["name": JourneyConstants.operationType, "value": "AUTHENTICATE"]],
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = TestableValidationAuthCallback()
        _ = await cb.initialize(with: json)
        cb.initValue(name: JourneyConstants.clientState, value: clientState)
        return cb
    }

    func testValidationActiveRoutesToAuthenticate() async {
        let cb = await makeValidationCallback()
        cb.validateResult = .active
        cb.performAuthenticateResult = .success(RecognizeSuccess(signedJwt: "auth-jwt", clientState: nil, recognizeId: nil, selfie: nil))
        // performEnrollResult would fail if wrongly called
        cb.performEnrollResult = .failure(RecognizeError("should not enroll", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via authenticate path") }
        XCTAssertEqual(r.signedJwt, "auth-jwt")
    }

    func testValidationNotEnrolledRoutesToEnroll() async {
        let cb = await makeValidationCallback()
        cb.validateResult = .notEnrolled
        cb.performEnrollResult = .success(RecognizeSuccess(signedJwt: "enroll-jwt", clientState: nil, recognizeId: "rid", selfie: nil))
        // performAuthenticateResult would fail if wrongly called
        cb.performAuthenticateResult = .failure(RecognizeError("should not authenticate", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via enroll path") }
        XCTAssertEqual(r.signedJwt, "enroll-jwt")
    }

    func testValidationOtherErrorPropagatesWithoutEnrolling() async {
        let cb = await makeValidationCallback()
        // Native code 60001 has no entry in the shared mapping — exercises the SDK_ERROR fallback
        // through the real conversion helper in the .otherError throw path.
        cb.validateResult = .otherError(message: "device locked", code: 60001)
        // Neither performEnroll nor performAuthenticate should be called
        cb.performEnrollResult = .failure(RecognizeError("should not enroll", code: 9999))
        cb.performAuthenticateResult = .failure(RecognizeError("should not authenticate", code: 9999))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "SDK_ERROR")
        // Mapped: unmapped native 60001 falls back to the shared SDK_ERROR (1000).
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "1000")
    }

    func testValidationOtherErrorMapsKnownNativeCode() async {
        let cb = await makeValidationCallback()
        // Native Keyless 20000 (userNotEnrolled) → shared CORE_USER_NOT_ENROLLED (3003).
        cb.validateResult = .otherError(message: "user not enrolled", code: 20000)
        cb.performEnrollResult = .failure(RecognizeError("should not enroll", code: 9999))
        cb.performAuthenticateResult = .failure(RecognizeError("should not authenticate", code: 9999))
        let result = await cb.authenticate()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        let recognizeError = error as? RecognizeError
        XCTAssertEqual(recognizeError?.code, 3003)
        XCTAssertEqual(recognizeError?.name, "CORE_USER_NOT_ENROLLED")
        XCTAssertEqual(recognizeError?.sdkCode, 20000)
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "CORE_USER_NOT_ENROLLED")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "3003")
    }
}

// MARK: - KeylessErrorConversionTests

/// Drives the real Keyless SDK call sites. `KeylessSDKError` cannot be created outside the
/// Keyless SDK, but the SDK produces one itself, so these tests pin that the real call sites
/// map native errors to the shared model instead of forwarding the native code:
/// - `Keyless.enroll` fails immediately with `sdkNotConfigured` (native 20002), because
///   Keyless is never configured in the test process;
/// - `Keyless.configure` fails immediately with `invalidConfiguration` (native 20010) for an
///   empty host, and leaves the SDK unconfigured.
///
/// `Keyless.authenticate` cannot be covered the same way: with the SDK unconfigured it crashes
/// the test host instead of returning an error. That call site is not covered by a unit test.
final class KeylessErrorConversionTests: XCTestCase {

    func testKeylessEnrollErrorIsMappedToSharedModel() async {
        let callback = PingOneRecognizeEnrollCallback()
        do {
            _ = try await callback.performKeylessEnroll(configuration: BiomEnrollConfig())
            XCTFail("Expected the unconfigured Keyless SDK to fail")
        } catch {
            let recognizeError = error as? RecognizeError
            XCTAssertNotNil(recognizeError, "the Keyless error must be converted to a RecognizeError, got \(error)")
            XCTAssertEqual(recognizeError?.sdkCode, 20002)
            XCTAssertEqual(recognizeError?.code, 1001)
            XCTAssertEqual(recognizeError?.name, "SDK_NOT_CONFIGURED")
        }
    }

    func testKeylessConfigureErrorIsMappedToSharedModel() async {
        // Empty api key and host: the real Keyless.configure rejects the configuration.
        let callback = PingOneRecognizeEnrollCallback()
        do {
            try await callback.configure()
            XCTFail("Expected configure with an empty api key and host to fail")
        } catch {
            let recognizeError = error as? RecognizeError
            XCTAssertNotNil(recognizeError, "the Keyless error must be converted to a RecognizeError, got \(error)")
            XCTAssertEqual(recognizeError?.sdkCode, 20010)
            XCTAssertEqual(recognizeError?.code, 1002)
            XCTAssertEqual(recognizeError?.name, "SDK_INVALID_CONFIGURATION")
        }
    }
}
