// 
//  ValidationError.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// An error type that represents validation errors.
public enum ValidationError: Error, Identifiable, Equatable {
    /// A unique identifier for the error.
    public var id: UUID { UUID() }
    
    case required
    case regexError(message: String)
    case invalidLength(min: Int, max: Int)
    case uniqueCharacter(min: Int)
    case maxRepeat(max: Int)
    case minCharacters(character: String, min: Int)
    
    /// The error message for the validation error.
    public var errorMessage: String {
        switch self {
        case .required:
            return "This field cannot be empty."
        case .regexError(let message):
            return message
        case .invalidLength(let min, let max):
            return "The input length must be between \(min) and \(max) characters."
        case .uniqueCharacter(let min):
            return "The input must contain at least \(min) unique characters."
        case .maxRepeat(let max):
            return "The input contains too many repeated characters. Maximum allowed repeats: \(max)."
        case .minCharacters(let chars, let min):
            return "The input must include at least \(min) character(s) from this set: '\(chars)'."
        }
    }
}

extension ValidationError {
    
}
