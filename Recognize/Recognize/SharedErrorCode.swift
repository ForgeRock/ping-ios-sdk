//
//  SharedErrorCode.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

// The shared Recognize error model (version 6.0.0) and the iOS native → shared mapping,
// as agreed across the web, Android, and iOS Recognize SDKs. Keep the tables below in sync
// with the shared model whenever it changes.

/// The shared cross-platform Recognize error model, used identically by the web, Android,
/// and iOS Recognize SDKs.
///
/// Each case's raw value is the shared numeric code, and `name` is the shared error name
/// string. The Keyless SDK raises errors with its own native codes, so
/// `resolve(nativeCode:)` translates a native code into the shared model.
///
/// Only the shared codes the Keyless iOS SDK can actually produce are declared here. The
/// shared model also defines web-only codes (`SDK_WEB_ASSEMBLY_*`, `CAMERA_NOT_FOUND`,
/// `CAMERA_NOT_SUPPORTED`, `CORE_NOT_ENOUGH_CIRCUITS`, `CORE_CUSTOMER_NOT_FOUND`, and the
/// `SERVER_*` family) that no iOS native code maps to.
///
/// Unlike the module's Journey files, no `#if canImport(KeylessSDK)` guard is needed: this
/// type references no Keyless symbols, mirroring `RecognizeError` in `Recognize.swift`.
enum SharedErrorCode: Int, Sendable {

    // MARK: SDK (1000–1016)

    case sdkError = 1000
    case sdkNotConfigured = 1001
    case sdkInvalidConfiguration = 1002
    case sdkLoggingConfigurationFailed = 1003
    case sdkStorageFailed = 1004
    case sdkUserCancelled = 1005
    case sdkTimeout = 1006
    case sdkNoNetworkConnection = 1007
    case sdkDynamicLinkingPayloadMalformed = 1008
    case sdkArtifactRetrieveFailed = 1009
    case sdkInvalidClientState = 1010
    case sdkOutdatedApp = 1012
    case sdkInvalidCustomerProperties = 1016

    // MARK: Camera (2000–2003)

    case cameraError = 2000
    case cameraPermissionDenied = 2002

    // MARK: Core (3000–3008)

    case coreError = 3000
    case coreNotEnoughApiKeySeats = 3001
    case coreUserAlreadyEnrolled = 3002
    case coreUserNotEnrolled = 3003
    case coreFaceNotMatching = 3004
    case coreSecretNotFound = 3006
    case coreUserLockedOut = 3007

    // MARK: Biom (4000–4004)

    case biomError = 4000
    case biomRejected = 4001
    case biomGenuinePresenceNotEstablished = 4002
    case biomLivenessEnvironmentAwareNotSupported = 4003
    case biomDeviceEnvironmentAwareNotSupported = 4004

    // MARK: Security (6000–6001)

    case securityError = 6000
    case securityDeviceNotGenuine = 6001

    /// The shared error name, spelled exactly as in the shared model.
    var name: String {
        switch self {
        case .sdkError: return "SDK_ERROR"
        case .sdkNotConfigured: return "SDK_NOT_CONFIGURED"
        case .sdkInvalidConfiguration: return "SDK_INVALID_CONFIGURATION"
        case .sdkLoggingConfigurationFailed: return "SDK_LOGGING_CONFIGURATION_FAILED"
        case .sdkStorageFailed: return "SDK_STORAGE_FAILED"
        case .sdkUserCancelled: return "SDK_USER_CANCELLED"
        case .sdkTimeout: return "SDK_TIMEOUT"
        case .sdkNoNetworkConnection: return "SDK_NO_NETWORK_CONNECTION"
        case .sdkDynamicLinkingPayloadMalformed: return "SDK_DYNAMIC_LINKING_PAYLOAD_MALFORMED"
        case .sdkArtifactRetrieveFailed: return "SDK_ARTIFACT_RETRIEVE_FAILED"
        case .sdkInvalidClientState: return "SDK_INVALID_CLIENT_STATE"
        case .sdkOutdatedApp: return "SDK_OUTDATED_APP"
        case .sdkInvalidCustomerProperties: return "SDK_INVALID_CUSTOMER_PROPERTIES"
        case .cameraError: return "CAMERA_ERROR"
        case .cameraPermissionDenied: return "CAMERA_PERMISSION_DENIED"
        case .coreError: return "CORE_ERROR"
        case .coreNotEnoughApiKeySeats: return "CORE_NOT_ENOUGH_API_KEY_SEATS"
        case .coreUserAlreadyEnrolled: return "CORE_USER_ALREADY_ENROLLED"
        case .coreUserNotEnrolled: return "CORE_USER_NOT_ENROLLED"
        case .coreFaceNotMatching: return "CORE_FACE_NOT_MATCHING"
        case .coreSecretNotFound: return "CORE_SECRET_NOT_FOUND"
        case .coreUserLockedOut: return "CORE_USER_LOCKED_OUT"
        case .biomError: return "BIOM_ERROR"
        case .biomRejected: return "BIOM_REJECTED"
        case .biomGenuinePresenceNotEstablished: return "BIOM_GENUINE_PRESENCE_NOT_ESTABLISHED"
        case .biomLivenessEnvironmentAwareNotSupported: return "BIOM_LIVENESS_ENVIRONMENT_AWARE_NOT_SUPPORTED"
        case .biomDeviceEnvironmentAwareNotSupported: return "BIOM_DEVICE_ENVIRONMENT_AWARE_NOT_SUPPORTED"
        case .securityError: return "SECURITY_ERROR"
        case .securityDeviceNotGenuine: return "SECURITY_DEVICE_NOT_GENUINE"
        }
    }

    /// Faithful transcription of the shared iOS mapping (29 entries, version 6.0.0):
    /// native Keyless iOS code → shared error.
    /// Internal (not private) so the transcription-guard test can assert its size.
    static let nativeToShared: [Int: SharedErrorCode] = [
        10000: .sdkError,
        10001: .sdkArtifactRetrieveFailed,
        10003: .sdkLoggingConfigurationFailed,
        10004: .cameraError,
        10005: .sdkStorageFailed,
        10006: .sdkInvalidCustomerProperties,
        10100: .biomError,
        10200: .coreError,
        20000: .coreUserNotEnrolled,
        20001: .coreUserAlreadyEnrolled,
        20002: .sdkNotConfigured,
        20010: .sdkInvalidConfiguration,
        20013: .coreNotEnoughApiKeySeats,
        20021: .biomLivenessEnvironmentAwareNotSupported,
        20022: .biomDeviceEnvironmentAwareNotSupported,
        20023: .sdkInvalidClientState,
        20150: .sdkDynamicLinkingPayloadMalformed,
        20300: .coreSecretNotFound,
        30000: .biomGenuinePresenceNotEstablished,
        30001: .sdkTimeout,
        30003: .sdkUserCancelled,
        30004: .coreFaceNotMatching,
        30005: .sdkNoNetworkConnection,
        30007: .coreUserLockedOut,
        30008: .biomRejected,
        30009: .cameraPermissionDenied,
        30010: .sdkOutdatedApp,
        40000: .securityError,
        40002: .securityDeviceNotGenuine,
    ]

    /// Resolves a native Keyless iOS code to the shared error model.
    ///
    /// Unmapped native codes fall back to `sdkError` — matching the web SDK's fallback
    /// vocabulary (`get-recognize-error-code-key` returns `SDK_ERROR` for unknown codes).
    /// This also covers native codes absent from the shared mapping (e.g. Keyless
    /// `20024` userProfileError, which the shared model does not define yet).
    static func resolve(nativeCode: Int) -> SharedErrorCode {
        nativeToShared[nativeCode] ?? .sdkError
    }
}
