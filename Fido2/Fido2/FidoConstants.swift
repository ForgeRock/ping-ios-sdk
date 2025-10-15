//
//  FidoConstants.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Constants used throughout the FIDO module.
public struct FidoConstants {
    // MARK: - Actions
    
    /// Action to register a new FIDO2 credential.
    public static let ACTION_REGISTER = "REGISTER"
    /// Action to authenticate with an existing FIDO2 credential.
    public static let ACTION_AUTHENTICATE = "AUTHENTICATE"

    // MARK: - Event Types
    
    /// Event type for submitting a FIDO2 response.
    public static let EVENT_TYPE_SUBMIT = "submit"

    // MARK: - JSON Fields
    
    public static let FIELD_DATA = "data"
    public static let FIELD_ACTION = "action"
    public static let FIELD_RESPONSE = "response"
    public static let FIELD_RAW_ID = "rawId"
    public static let FIELD_CLIENT_DATA_JSON = "clientDataJSON"
    public static let FIELD_ATTESTATION_OBJECT = "attestationObject"
    public static let FIELD_AUTHENTICATOR_DATA = "authenticatorData"
    public static let FIELD_SIGNATURE = "signature"
    public static let FIELD_USER_HANDLE = "userHandle"
    public static let FIELD_CHALLENGE = "challenge"
    public static let FIELD_TIMEOUT = "timeout"
    public static let FIELD_USER_VERIFICATION = "userVerification"
    public static let FIELD_RP_ID = "rpId"
    public static let FIELD_ALLOW_CREDENTIALS = "allowCredentials"
    public static let FIELD_ATTESTATION = "attestation"
    public static let FIELD_RP = "rp"
    public static let FIELD_USER = "user"
    public static let FIELD_PUB_KEY = "public-key"
    public static let FIELD_PUB_KEY_CRED_PARAMS = "pubKeyCredParams"
    public static let FIELD_EXCLUDE_CREDENTIALS = "excludeCredentials"
    public static let FIELD_AUTHENTICATOR_SELECTION = "authenticatorSelection"
    public static let FIELD_TYPE = "type"
    public static let FIELD_ID = "id"
    public static let FIELD_ALG = "alg"
    public static let FIELD_NAME = "name"
    public static let FIELD_DISPLAY_NAME = "displayName"
    public static let FIELD_AUTHENTICATOR_ATTACHMENT = "authenticatorAttachment"
    public static let FIELD_REQUIRE_RESIDENT_KEY = "requireResidentKey"
    public static let FIELD_RESIDENT_KEY = "residentKey"
    public static let FIELD_SUPPORTS_JSON_RESPONSE = "supportsJsonResponse"
    public static let FIELD_ASSERTION_VALUE = "assertionValue"
    public static let FIELD_ATTESTATION_VALUE = "attestationValue"

    // MARK: - Private/Internal Fields
    
    public static let FIELD_RELYING_PARTY_ID_INTERNAL = "_relyingPartyId"
    public static let FIELD_ALLOW_CREDENTIALS_INTERNAL = "_allowCredentials"
    public static let FIELD_PUB_KEY_CRED_PARAMS_INTERNAL = "_pubKeyCredParams"
    public static let FIELD_EXCLUDE_CREDENTIALS_INTERNAL = "_excludeCredentials"
    public static let FIELD_AUTHENTICATOR_SELECTION_INTERNAL = "_authenticatorSelection"

    // MARK: - Standard Field Names
    
    public static let FIELD_RELYING_PARTY_NAME = "relyingPartyName"
    public static let FIELD_USER_ID = "userId"
    public static let FIELD_USER_NAME = "userName"
    public static let FIELD_ATTESTATION_PREFERENCE = "attestationPreference"
    public static let FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS = "publicKeyCredentialCreationOptions"
    public static let FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS = "publicKeyCredentialRequestOptions"

    // MARK: - Default Values
    
    public static let DEFAULT_TIMEOUT: Double = 60000.0
    public static let DEFAULT_ATTESTATION = "none"
    public static let DEFAULT_USER_VERIFICATION = "required"
    public static let DEFAULT_RESIDENT_KEY_REQUIRED = "required"
    public static let RESIDENT_KEY_DISCOURAGED = "discouraged"
    public static let DEFAULT_RELYING_PARTY_ID = "credential-manager-test.example.com"

    // MARK: - Separators
    
    public static let DATA_SEPARATOR = "::"
    public static let INT_SEPARATOR = ","

    // MARK: - Callback IDs
    
    public static let WEB_AUTHN_OUTCOME = "webAuthnOutcome"

    // MARK: - Error Types
    
    public static let ERROR_UNSUPPORTED = "unsupported"
    public static let ERROR_NOT_ALLOWED = "NotAllowedError"
    public static let ERROR_UNKNOWN = "UnknownError"
    public static let ERROR_NOT_ALLOWED_MESSAGE = "The operation was canceled."
    public static let ERROR_INVALID_STATE = "InvalidStateError"
    public static let ERROR_NOT_SUPPORTED = "NotSupportedError"
    public static let ERROR_PREFIX = "ERROR::"

    // MARK: - Authenticator Types
    
    public static let AUTHENTICATOR_PLATFORM = "platform"

    // FIDO2 JSON Response Keys
    public static let FIELD_LEGACY_DATA = "legacyData"

    // Callback Types
    public static let FIDO2_REGISTRATION_CALLBACK = "Fido2RegistrationCallback"
    public static let FIDO2_AUTHENTICATION_CALLBACK = "Fido2AuthenticationCallback"
}
