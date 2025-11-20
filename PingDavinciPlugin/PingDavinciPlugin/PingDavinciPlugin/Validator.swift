// 
//  Validator.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// A protocol for validating objects.
/// This protocol defines a method to validate an object and return an array of validation errors.
/// The `validate` method should be implemented by conforming types to perform the validation logic.
public protocol Validator {
    func validate() -> [ValidationError]
}
