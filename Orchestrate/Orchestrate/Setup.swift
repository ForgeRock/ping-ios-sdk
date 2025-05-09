//
//  Setup.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger

/// Struct for a Setup. A Setup represents the setup of a module in the application.
/// - property workflow: The workflow of the application.
/// - property context: The shared context of the application.
/// - property logger:  The logger used in the application.
/// - property httpClient: The HTTP client used in the application.
/// - property config: The configuration for the module.
public struct Setup<ModuleConfig: Sendable>: Sendable {
    public let workflow: Workflow
    public let context: SharedContext
    public let logger: Logger
    public let httpClient: HttpClient
    public let config: ModuleConfig
    
    /// Initializes a new Setup instance.
    /// - Parameters:
    ///   - workflow: The workflow of the application.
    ///   - config: The configuration for the module.
    public init(workflow: Workflow, config: ModuleConfig) {
        self.workflow = workflow
        self.context = workflow.sharedContext
        self.logger = workflow.config.logger
        self.httpClient = workflow.config.httpClient
        self.config = config
    }
    
    /// Adds an initialization block to the workflow.
    /// - Parameter block: The block to be added.
    public func initialize(block: @escaping @Sendable () async throws -> Void) {
        workflow.initHandlers.append(block)
    }
    
    /// Adds a start block to the workflow.
    /// - Parameter block: The block to be added.
    public func start(_ block: @escaping @Sendable (FlowContext, Request) async throws -> Request) {
        workflow.startHandlers.append(block)
    }
    
    /// Adds a next block to the workflow.
    /// - Parameter block: The block to be added.
    public func next(block: @escaping @Sendable (FlowContext, ContinueNode, Request) async throws -> Request) {
        workflow.nextHandlers.append(block)
    }
    
    /// Adds a response block to the workflow.
    /// - Parameter block: The block to be added.
    public func response(block: @escaping @Sendable (FlowContext, Response) async throws -> Void) {
        workflow.responseHandlers.append(block)
    }
    
    /// Adds a node block to the workflow.
    /// - Parameter block: The block to be added.
    public func node(block: @escaping @Sendable (FlowContext, Node) async throws -> Node) {
        workflow.nodeHandlers.append(block)
    }
    
    /// Adds a success block to the workflow.
    /// - Parameter block: The block to be added.
    public func success(block: @escaping @Sendable (FlowContext, SuccessNode) async throws -> SuccessNode) {
        workflow.successHandlers.append(block)
    }
    
    /// Sets the transform block of the workflow.
    /// - Parameter block: The block to be set.
    public func transform(block: @escaping @Sendable (FlowContext, Response) async throws -> Node) {
        workflow.transformHandler = block
    }
    
    /// Adds a sign off block to the workflow.
    /// - Parameter block: The block to be added.
    public func signOff(block: @escaping @Sendable (Request) async -> Request) {
        workflow.signOffHandlers.append(block)
    }
}
