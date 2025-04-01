// 
//  ErrorNode.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate

/// Extension to provide additional functionality to `ErrorNode`.
extension ErrorNode {
    
    /// Extracts and returns an array of `Detail` objects from the `input` dictionary.
    ///
    /// - Returns: An array of `Detail` objects if parsing is successful, otherwise an empty array.
    public var details: [Detail] {
        guard let detailsArray = input[Constants.details] as? [[String: Any]] else {
            return []
        }
        return detailsArray.compactMap { try? Detail(dictionary: $0) }
    }
}

/// Represents a detailed error response.
public struct Detail: Codable, Sendable {
    /// The raw response associated with the error.
    public let rawResponse: RawResponse
    
    /// The HTTP status code of the error response.
    public let statusCode: Int
    
    /// Initializes a `Detail` object from a dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing the error details.
    /// - Throws: `SerializationError.invalidFormat` if required fields are missing or invalid.
    public init(dictionary: [String: Any]) throws {
        guard let statusCode = dictionary[Constants.statusCode] as? Int,
              let rawResponseDict = dictionary[Constants.rawResponse] as? [String: Any] else {
            throw SerializationError.invalidFormat
        }
        
        self.statusCode = statusCode
        self.rawResponse = try RawResponse(dictionary: rawResponseDict)
    }
}

/// Represents the raw response of an error.
public struct RawResponse: Codable, Sendable {
    /// The unique identifier of the error.
    public let id: String?
    
    /// The error code.
    public let code: String?
    
    /// A message describing the error.
    public let message: String?
    
    /// Additional error details.
    public let details: [ErrorDetail]?
    
    /// Initializes a `RawResponse` object from a dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing the raw response data.
    /// - Throws: `SerializationError.invalidFormat` if required fields are missing or invalid.
    public init(dictionary: [String: Any]) throws {
        self.id = dictionary[Constants.id] as? String
        self.code = dictionary[Constants.code] as? String
        self.message = dictionary[Constants.message] as? String
        
        if let detailsArray = dictionary[Constants.details] as? [[String: Any]] {
            self.details = try detailsArray.map { try ErrorDetail(dictionary: $0) }
        } else {
            self.details = nil
        }
    }
}

/// Represents a specific error detail.
public struct ErrorDetail: Codable, Sendable {
    /// The error code.
    public let code: String?
    
    /// The target field or resource affected by the error.
    public let target: String?
    
    /// A message describing the error.
    public let message: String?
    
    /// Additional inner error details, if available.
    public let innerError: InnerError?
    
    /// Initializes an `ErrorDetail` object from a dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing the error detail data.
    /// - Throws: `SerializationError.invalidFormat` if required fields are missing or invalid.
    public init(dictionary: [String: Any]) throws {
        self.code = dictionary[Constants.code] as? String
        self.target = dictionary[Constants.target] as? String
        self.message = dictionary[Constants.message] as? String
        
        if let innerErrorDict = dictionary[Constants.innerError] as? [String: Any] {
            self.innerError = try InnerError(dictionary: innerErrorDict)
        } else {
            self.innerError = nil
        }
    }
}

/// Represents additional inner error details.
public struct InnerError: Codable, Sendable {
    /// A dictionary mapping unsatisfied requirements to their respective messages.
    public let errors: [String: String]
    
    /// Initializes an `InnerError` object from a dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing inner error details.
    /// - Throws: `SerializationError.invalidFormat` if required fields are missing or invalid.
    public init(dictionary: [String: Any]) throws {
        guard let unsatisfiedRequirements = dictionary[Constants.unsatisfiedRequirements] as? [String] else {
            throw SerializationError.invalidFormat
        }
        
        var errorsMap: [String: String] = [:]
        for requirement in unsatisfiedRequirements {
            errorsMap[requirement] = (dictionary[requirement] as? String) ?? "No message available"
        }
        
        self.errors = errorsMap
    }
}

/// Represents errors that occur during serialization.
public enum SerializationError: Error {
    /// Indicates that the provided data has an invalid format.
    case invalidFormat
}
