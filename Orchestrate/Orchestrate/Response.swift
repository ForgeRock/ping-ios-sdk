//
//  Response.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingNetwork

extension Response {
    /// Returns the body of the response as a JSON object.
    /// - Returns: The body of the response as a JSON object.
    public func json() throws -> [String: Any] {
        return (try JSONSerialization.jsonObject(with: self.body ?? Data(), options: []) as? [String: Any]) ?? [:]
    }
}
