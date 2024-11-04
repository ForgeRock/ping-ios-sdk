//
//  SharedContext.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// An actor that manages a shared context using a dictionary.
public final class SharedContext {
  private var map: [String: Any]
  
  /// Initializes the SharedContext with an empty dictionary or a pre-existing one.
  ///
  /// - Parameter map: A dictionary to initialize the context with. Defaults to an empty dictionary.
  public init(_ map: [String: Any] = [:]) {
    self.map = map
  }
  
  /// Sets a value for the given key in the shared context.
  ///
  /// - Parameters:
  ///   - key: The key for which to set the value.
  ///   - value: The value to set for the given key.
  public func set(key: String, value: Any)  {
    self.map[key] = value
  }
  
  /// Retrieves the value for the given key from the shared context.
  ///
  /// - Parameter key: The key for which to get the value.
  /// - Returns: The value associated with the key, or `nil` if the key does not exist.
  public func get(key: String) -> Any?  {
    return self.map[key]
    
  }
  
  /// Removes the value for the given key from the shared context.
  ///
  /// - Parameter key: The key for which to remove the value.
  /// - Returns: The removed value, or `nil` if the key does not exist.
  public func removeValue(forKey key: String) -> Any? {
    self.map.removeValue(forKey: key)
  }
  
  /// A Boolean value indicating whether the shared context is empty.
  public var isEmpty: Bool {
    return self.map.isEmpty
  }
  
  /// A namespace for key names to be added in an extension.
  public enum Keys {
    
  }
}
