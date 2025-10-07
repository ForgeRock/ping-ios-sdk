//
//  Constants.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// Represents various constants used in Journey requests and flows.
public enum JourneyConstants {

    public static let realm = "root"
    public static let cookie = "iPlanetDirectoryPro"

    public static let startRequest = "com.pingidentity.journey.START_REQUEST"
    public static let forceAuth = "com.pingidentity.journey.FORCE_AUTH"
    public static let noSession = "com.pingidentity.journey.NO_SESSION"
    public static let authIndexType = "authIndexType"
    public static let authIndexValue = "authIndexValue"
    public static let service = "service"
    public static let suspendedId = "suspendedId"

    public static let forceAuthParam = "ForceAuth"
    public static let noSessionParam = "noSession"

    public static let sessionConfig = "com.pingidentity.journey.SESSION_CONFIG"
    public static let resource31 = "resource=3.1, protocol=1.0"

    public static let acceptApiVersion = "Accept-API-Version"
    public static let resource21Protocol10 = "resource=2.1, protocol=1.0"

    public static let authId = "authId"
    public static let callbacks = "callbacks"
    public static let contentType = "Content-Type"
    public static let applicationJson = "application/json"
    public static let tokenId = "tokenId"
    public static let successUrl = "successUrl"
    public static let realmName = "realm"

    public static let location = "location"
    public static let type = "type"

    /// Constant key used to store and retrieve the OIDC client from the shared context
    public static let oidcClient = "com.pingidentity.journey.OIDC_CLIENT"

    /// Callback Types
    public static let booleanAttributeInputCallback = "BooleanAttributeInputCallback"
    public static let choiceCallback = "ChoiceCallback"
    public static let confirmationCallback = "ConfirmationCallback"
    public static let consentMappingCallback = "ConsentMappingCallback"
    public static let hiddenValueCallback = "HiddenValueCallback"
    public static let kbaCreateCallback = "KbaCreateCallback"
    public static let metadataCallback = "MetadataCallback"
    public static let nameCallback = "NameCallback"
    public static let numberAttributeInputCallback = "NumberAttributeInputCallback"
    public static let passwordCallback = "PasswordCallback"
    public static let pollingWaitCallback = "PollingWaitCallback"
    public static let stringAttributeInputCallback = "StringAttributeInputCallback"
    public static let suspendedTextOutputCallback = "SuspendedTextOutputCallback"
    public static let termsAndConditionsCallback = "TermsAndConditionsCallback"
    public static let textInputCallback = "TextInputCallback"
    public static let textOutputCallback = "TextOutputCallback"
    public static let validatedPasswordCallback = "ValidatedCreatePasswordCallback"
    public static let validatedUsernameCallback = "ValidatedCreateUsernameCallback"
    public static let fido2RegistrationCallback = "Fido2RegistrationCallback"
    public static let fido2AuthenticationCallback = "Fido2AuthenticationCallback"

    // Response keys
    public static let message = "message"

    // OIDC Requests
    public static let client_id = "client_id"
    public static let scope = "scope"
    public static let state = "state"
    public static let grant_type = "grant_type"
    public static let refresh_token = "refresh_token"
    public static let token = "token"
    public static let authorization_code = "authorization_code"
    public static let redirect_uri = "redirect_uri"
    public static let code_verifier = "code_verifier"
    public static let code = "code"
    public static let id_token_hint = "id_token_hint"
    public static let response_type = "response_type"
    public static let code_challenge = "code_challenge"
    public static let code_challenge_method = "code_challenge_method"
    public static let nonce = "nonce"
    public static let login_hint = "login_hint"
    public static let prompt = "prompt"

    public static let output = "output"
    public static let name = "name"
    public static let value = "value"
    public static let input = "input"
    public static let id = "id"
    public static let policies = "policies"
    public static let validateOnly = "validateOnly"
    public static let failedPolicies = "failedPolicies"
    public static let params = "params"
    public static let policyRequirement = "policyRequirement"
    public static let required = "required"
    public static let choices = "choices"
    public static let defaultChoice = "defaultChoice"
    public static let options = "options"
    public static let defaultOption = "defaultOption"
    public static let messageType = "messageType"
    public static let optionType = "optionType"
    public static let displayName = "displayName"
    public static let icon = "icon"
    public static let accessLevel = "accessLevel"
    public static let isRequired = "isRequired"
    public static let fields = "fields"
    public static let predefinedQuestions = "predefinedQuestions"
    public static let data = "data"
    public static let waitTime = "waitTime"
    public static let version = "version"
    public static let createDate = "createDate"
    public static let terms = "terms"
    public static let defaultText = "defaultText"
    public static let echoOn = "echoOn"
    public static let allowUserDefinedQuestions = "allowUserDefinedQuestions"

    /// Constants for IdpCallbacks
    public static let provider = "provider"
    public static let clientId = "clientId"
    public static let redirectUri = "redirectUri"
    public static let scopes = "scopes"
    public static let acrValues = "acrValues"
    public static let request = "request"
    public static let requestUri = "requestUri"
    public static let IDPLogin = "IDPLogin"
    public static let token_type = "token_type"
    public static let APPLE = "apple"
    public static let SIWA = "siwa"
    public static let GOOGLE = "google"
    public static let FACEBOOK = "facebook"
    public static let providers = "providers"
    public static let acceptsJSON = "acceptsJSON"
}
