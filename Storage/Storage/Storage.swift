//
//  Storage.swift
//  PingStorage
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Protocol to persist and retrieve `Codable` instance.
public protocol Storage<T>: Sendable {
    associatedtype T: Codable, Sendable
    
    /// Saves the given item.
    /// - Parameter item: The item to be saved.
    func save(item: T) async throws
    
    /// Retrieves the stored item.
    /// - Returns: The stored item, or null if no item is stored.
    func get() async throws -> T?
    
    /// Deletes the stored item.
    func delete() async throws
}
