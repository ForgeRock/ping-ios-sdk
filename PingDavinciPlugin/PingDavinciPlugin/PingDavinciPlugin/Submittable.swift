// 
//  Submittable.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

/// A protocol representing a self submittable [Collector].
public protocol Submittable {
    /// A method returning the eventType of the submittable object.
    func eventType() -> String
}
