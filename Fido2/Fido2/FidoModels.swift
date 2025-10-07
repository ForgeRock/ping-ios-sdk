
//
//  FidoModels.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents the options for creating a new public key credential.
public struct PublicKeyCredentialCreationOptions: Codable {
    /// The relying party entity.
    public let rp: PublicKeyCredentialRpEntity
    /// The user entity.
    public let user: PublicKeyCredentialUserEntity
    /// A challenge to prevent replay attacks.
    public let challenge: String
    /// The parameters for the public key credential.
    public let pubKeyCredParams: [PublicKeyCredentialParameters]
    /// The timeout for the operation.
    public let timeout: Int?
    /// A list of credentials to exclude.
    public let excludeCredentials: [PublicKeyCredentialDescriptor]?
    /// The authenticator selection criteria.
    public let authenticatorSelection: AuthenticatorSelectionCriteria?
    /// The attestation conveyance preference.
    public let attestation: AttestationConveyancePreference?
}

/// Represents the options for a public key credential request.
public struct PublicKeyCredentialRequestOptions: Codable {
    /// A challenge to prevent replay attacks.
    public let challenge: String
    /// The timeout for the operation.
    public let timeout: Int?
    /// The relying party ID.
    public let rpId: String?
    /// A list of allowed credentials.
    public let allowCredentials: [PublicKeyCredentialDescriptor]?
    /// The user verification requirement.
    public let userVerification: UserVerificationRequirement?
}

/// Represents a public key credential relying party entity.
public struct PublicKeyCredentialRpEntity: Codable {
    /// The ID of the relying party.
    public let id: String?
    /// The name of the relying party.
    public let name: String
}

/// Represents a public key credential user entity.
public struct PublicKeyCredentialUserEntity: Codable {
    /// The ID of the user.
    public let id: String
    /// The name of the user.
    public let name: String
    /// The display name of the user.
    public let displayName: String
}

/// Represents the parameters for a public key credential.
public struct PublicKeyCredentialParameters: Codable {
    /// The type of the public key credential.
    public let type: PublicKeyCredentialType
    /// The algorithm for the public key credential.
    public let alg: COSEAlgorithmIdentifier
}

/// Represents a public key credential descriptor.
public struct PublicKeyCredentialDescriptor: Codable {
    /// The type of the public key credential.
    public let type: PublicKeyCredentialType
    /// The ID of the public key credential.
    public let id: String
    /// The transports for the public key credential.
    public let transports: [AuthenticatorTransport]?
}

/// Represents the authenticator selection criteria.
public struct AuthenticatorSelectionCriteria: Codable {
    /// The authenticator attachment.
    public let authenticatorAttachment: AuthenticatorAttachment?
    /// Whether a resident key is required.
    public let requireResidentKey: Bool?
    /// The user verification requirement.
    public let userVerification: UserVerificationRequirement?
}

/// Represents the type of a public key credential.
public enum PublicKeyCredentialType: String, Codable {
    case publicKey = "public-key"
}

/// Represents the COSE algorithm identifier.
public enum COSEAlgorithmIdentifier: Int, Codable {
    case es256 = -7
    case es384 = -35
    case es512 = -36
    case rs256 = -257
    case rs384 = -258
    case rs512 = -259
}

/// Represents the authenticator transport.
public enum AuthenticatorTransport: String, Codable {
    case usb, nfc, ble, internal_transport = "internal"
}

/// Represents the authenticator attachment.
public enum AuthenticatorAttachment: String, Codable {
    case platform, crossPlatform = "cross-platform"
}

/// Represents the user verification requirement.
public enum UserVerificationRequirement: String, Codable {
    case required, preferred, discouraged
}

/// Represents the attestation conveyance preference.
public enum AttestationConveyancePreference: String, Codable {
    case none, indirect, direct
}

/// Represents a public key credential.
public struct PublicKeyCredential<T: Codable>: Codable {
    /// The ID of the public key credential.
    public let id: String
    /// The raw ID of the public key credential.
    public let rawId: String
    /// The type of the public key credential.
    public let type: PublicKeyCredentialType
    /// The response from the authenticator.
    public let response: T
}

/// Represents the response from an authenticator for an attestation.
public struct AuthenticatorAttestationResponse: Codable {
    /// The client data JSON.
    public let clientDataJSON: String
    /// The attestation object.
    public let attestationObject: String
}

/// Represents the response from an authenticator for an assertion.
public struct AuthenticatorAssertionResponse: Codable {
    /// The client data JSON.
    public let clientDataJSON: String
    /// The authenticator data.
    public let authenticatorData: String
    /// The signature.
    public let signature: String
    /// The user handle.
    public let userHandle: String?
}
