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
    
    /// Action to register a new FIDO credential.
    public static let ACTION_REGISTER = "REGISTER"
    /// Action to authenticate with an existing FIDO credential.
    public static let ACTION_AUTHENTICATE = "AUTHENTICATE"

    // MARK: - Event Types
    
    /// Event type for submitting a FIDO response.
    public static let EVENT_TYPE_SUBMIT = "submit"

    // MARK: - JSON Fields
    
    /// The key for the main data payload in a callback.
    public static let FIELD_DATA = "data"
    /// The key for the action to be performed (e.g., "REGISTER" or "AUTHENTICATE").
    public static let FIELD_ACTION = "action"
    /// The key for the response data from a FIDO operation.
    public static let FIELD_RESPONSE = "response"
    /// The key for the raw ID of a credential, typically Base64 encoded.
    public static let FIELD_RAW_ID = "rawId"
    /// The key for the client data JSON.
    public static let FIELD_CLIENT_DATA_JSON = "clientDataJSON"
    /// The key for the attestation object.
    public static let FIELD_ATTESTATION_OBJECT = "attestationObject"
    /// The key for the authenticator data.
    public static let FIELD_AUTHENTICATOR_DATA = "authenticatorData"
    /// The key for the signature.
    public static let FIELD_SIGNATURE = "signature"
    /// The key for the user handle.
    public static let FIELD_USER_HANDLE = "userHandle"
    /// The key for the challenge.
    public static let FIELD_CHALLENGE = "challenge"
    /// The key for the timeout value.
    public static let FIELD_TIMEOUT = "timeout"
    /// The key for the user verification preference.
    public static let FIELD_USER_VERIFICATION = "userVerification"
    /// The key for the relying party ID.
    public static let FIELD_RP_ID = "rpId"
    /// The key for the list of allowed credentials.
    public static let FIELD_ALLOW_CREDENTIALS = "allowCredentials"
    /// The key for the attestation preference.
    public static let FIELD_ATTESTATION = "attestation"
    /// The key for the relying party information.
    public static let FIELD_RP = "rp"
    /// The key for the user information.
    public static let FIELD_USER = "user"
    /// The key for the public key credential type.
    public static let FIELD_PUB_KEY = "public-key"
    /// The key for the public key credential parameters.
    public static let FIELD_PUB_KEY_CRED_PARAMS = "pubKeyCredParams"
    /// The key for the list of credentials to exclude.
    public static let FIELD_EXCLUDE_CREDENTIALS = "excludeCredentials"
    /// The key for the authenticator selection criteria.
    public static let FIELD_AUTHENTICATOR_SELECTION = "authenticatorSelection"
    /// The key for the credential type.
    public static let FIELD_TYPE = "type"
    /// The key for the credential ID.
    public static let FIELD_ID = "id"
    /// The key for the algorithm.
    public static let FIELD_ALG = "alg"
    /// The key for the name.
    public static let FIELD_NAME = "name"
    /// The key for the display name.
    public static let FIELD_DISPLAY_NAME = "displayName"
    /// The key for the authenticator attachment type.
    public static let FIELD_AUTHENTICATOR_ATTACHMENT = "authenticatorAttachment"
    /// The key for the resident key requirement.
    public static let FIELD_REQUIRE_RESIDENT_KEY = "requireResidentKey"
    /// The key for the resident key preference.
    public static let FIELD_RESIDENT_KEY = "residentKey"
    /// The key indicating support for a JSON response.
    public static let FIELD_SUPPORTS_JSON_RESPONSE = "supportsJsonResponse"
    /// The key for the assertion value in a DaVinci response.
    public static let FIELD_ASSERTION_VALUE = "assertionValue"
    /// The key for the attestation value in a DaVinci response.
    public static let FIELD_ATTESTATION_VALUE = "attestationValue"

    // MARK: - Private/Internal Fields
    
    /// Internal key for the relying party ID.
    public static let FIELD_RELYING_PARTY_ID_INTERNAL = "_relyingPartyId"
    /// Internal key for the list of allowed credentials.
    public static let FIELD_ALLOW_CREDENTIALS_INTERNAL = "_allowCredentials"
    /// Internal key for the public key credential parameters.
    public static let FIELD_PUB_KEY_CRED_PARAMS_INTERNAL = "_pubKeyCredParams"
    /// Internal key for the list of credentials to exclude.
    public static let FIELD_EXCLUDE_CREDENTIALS_INTERNAL = "_excludeCredentials"
    /// Internal key for the authenticator selection criteria.
    public static let FIELD_AUTHENTICATOR_SELECTION_INTERNAL = "_authenticatorSelection"

    // MARK: - Standard Field Names
    
    /// The standard key for the relying party name.
    public static let FIELD_RELYING_PARTY_NAME = "relyingPartyName"
    /// The standard key for the user ID.
    public static let FIELD_USER_ID = "userId"
    /// The standard key for the user name.
    public static let FIELD_USER_NAME = "userName"
    /// The standard key for the attestation preference.
    public static let FIELD_ATTESTATION_PREFERENCE = "attestationPreference"
    /// The key for the public key credential creation options.
    public static let FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS = "publicKeyCredentialCreationOptions"
    /// The key for the public key credential request options.
    public static let FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS = "publicKeyCredentialRequestOptions"

    // MARK: - Default Values
    
    /// The default timeout for FIDO operations (60 seconds).
    public static let DEFAULT_TIMEOUT: Double = 60000.0
    /// The default attestation preference ("none").
    public static let DEFAULT_ATTESTATION = "none"
    /// The default user verification preference ("required").
    public static let DEFAULT_USER_VERIFICATION = "required"
    /// The default resident key requirement ("required").
    public static let DEFAULT_RESIDENT_KEY_REQUIRED = "required"
    /// The value for a discouraged resident key.
    public static let RESIDENT_KEY_DISCOURAGED = "discouraged"
    /// The default relying party ID for testing.
    public static let DEFAULT_RELYING_PARTY_ID = "credential-manager-test.example.com"

    // MARK: - Separators
    
    /// The separator used for concatenating data in legacy FIDO responses.
    public static let DATA_SEPARATOR = "::"
    /// The separator used for integer arrays.
    public static let INT_SEPARATOR = ","

    // MARK: - Callback IDs
    
    /// The ID for the WebAuthn outcome callback.
    public static let WEB_AUTHN_OUTCOME = "webAuthnOutcome"

    // MARK: - Error Types
    
    /// An unsupported error type.
    public static let ERROR_UNSUPPORTED = "unsupported"
    /// The error code for a cancelled operation.
    public static let ERROR_NOT_ALLOWED = "NotAllowedError"
    /// The error code for an unknown error.
    public static let ERROR_UNKNOWN = "UnknownError"
    /// The message for a cancelled operation.
    public static let ERROR_NOT_ALLOWED_MESSAGE = "The operation was canceled."
    /// The error code for an invalid state.
    public static let ERROR_INVALID_STATE = "InvalidStateError"
    /// The error code for an unsupported operation.
    public static let ERROR_NOT_SUPPORTED = "NotSupportedError"
    /// The prefix for error messages.
    public static let ERROR_PREFIX = "ERROR::"

    // MARK: - Authenticator Types
    
    /// The platform authenticator type.
    public static let AUTHENTICATOR_PLATFORM = "platform"

    // MARK: - FIDO JSON Response Keys
    
    /// The key for legacy data in a JSON response.
    public static let FIELD_LEGACY_DATA = "legacyData"

    // MARK: - Callback Types
    
    /// The type for the FIDO registration callback.
    public static let FIDO_REGISTRATION_CALLBACK = "FidoRegistrationCallback"
    /// The type for the FIDO authentication callback.
    public static let FIDO_AUTHENTICATION_CALLBACK = "FidoAuthenticationCallback"
}
