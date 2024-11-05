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

public struct SendableAny: @unchecked Sendable {
  public let value: Any
  
  public init(_ value: Any) {
    self.value = value
  }
}


public struct UncheckedSendableHandler: @unchecked Sendable {
  private let handler: () async throws -> Void
  
  init(_ handler: @escaping () async throws -> Void) {
    self.handler = handler
  }
  
  func execute() async throws {
    try await handler()
  }
}
  
