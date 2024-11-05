//
//  ThreadSafe.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Sendable wrapper for a any value.
public struct SendableAny: @unchecked Sendable {
  /// The value to be wrapped.
  public let value: Any
  
  /// Creates a new instance of `SendableAny`.
  public init(_ value: Any) {
    self.value = value
  }
}

///Sendable wrapper for a closure.
public struct UncheckedSendableHandler: @unchecked Sendable {
  private let handler: () async throws -> Void
  
  /// Creates a new instance of `UncheckedSendableHandler`.
  init(_ handler: @escaping () async throws -> Void) {
    self.handler = handler
  }
  
  /// Executes the handler.
  func execute() async throws {
    try await handler()
  }
}
  
