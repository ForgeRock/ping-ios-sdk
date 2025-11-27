//
//  Node.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


/// Protocol for actions
public protocol Action: Sendable {}


/// Protocol for closeable resources
public protocol Closeable: Sendable {
    func close()
}


/// Protocol for Node. Represents a node in the workflow.
public protocol Node: Sendable {}


/// Represents an EmptyNode node in the workflow.
public struct EmptyNode: Node {
    /// Initializes a new instance of `EmptyNode`.
    public init() {}
}


/// Represents an Failure node in the workflow.
/// - property cause: The cause of the error.
public struct FailureNode: Node {
    /// The cause of the error.
    public let cause: Error
    
    /// Initializes a new instance of `FailureNode`.
    /// - Parameter cause: The cause of the error.
    public init(cause: any Error) {
        self.cause = cause
    }
}


/// Represents a ErrorNode node in the workflow.
/// - property status: The status of the error.
/// - property input: The input for the error.
/// - property message: The message for the error.
public struct ErrorNode: Node {
    nonisolated(unsafe) public let input: [String: Any]
    public let message: String
    public let status: Int?
    public let context: FlowContext
    
    /// Initializes a new instance of `ErrorNode`.
    /// - Parameters:
    ///   - status: The status of the error.
    ///   - input: The input for the error.
    ///   - message: The message for the error.
    public init(status: Int? = nil,
                input: [String : Any] = [:],
                message: String = "",
                context: FlowContext) {
        self.input = input
        self.message = message
        self.status = status
        self.context = context
    }
}


/// Represents a success node in the workflow.
/// - property input: The input for the success.
/// - property session: The session for the success.
public struct SuccessNode: Node {
    nonisolated(unsafe) public let input: [String: Any]
    public let session: Session
    
    /// Initializes a new instance of `SuccessNode`.
    /// - Parameters:
    ///   - input: The input for the success.
    ///   - session: The session for the success.
    public init(input: [String : Any] = [:], session: Session) {
        self.session = session
        self.input = input
    }
}

/// Abstract class for a ContinueNode node in the workflow.
/// - property context: The context for the node.
/// - property workflow: The workflow for the node.
/// - property input: The input for the node.
/// - property actions: The actions for the node.
open class ContinueNode: Node, Closeable, @unchecked Sendable {
    public let context: FlowContext
    public let workflow: Workflow
    public let input: [String: Any]
    public let actions: [any Action]
    
    /// Initializes a new instance of `ContinueNode`.
    /// - Parameters:
    ///   - context: The context for the node.
    ///   - workflow: The workflow for the node.
    ///   - input: The input for the node.
    ///   - actions: The actions for the node.
    public init(context: FlowContext, workflow: Workflow, input: [String: Any], actions: [any Action]) {
        self.context = context
        self.workflow = workflow
        self.input = input
        self.actions = actions
    }
    
    /// Converts the ContinueNode to a Request.
    /// - Returns: The Request representation of the ContinueNode.
    open func asRequest() -> Request {
        fatalError("Must be overridden in subclass")
    }
    
    /// Moves to the next node in the workflow.
    /// - Returns: The next Node.
    public func next() async -> Node {
        return await workflow.next(context, self)
    }
    
    /// Closes all closeable actions.
    public func close() {
        actions.compactMap { $0 as? Closeable }.forEach { $0.close() }
    }
}


/// Protocol for a Session. A Session represents a user's session in the application.
public protocol Session: Sendable {
    /// Returns the value of the session as a String.
    var value: String { get }
}


/// Singleton for an EmptySession. An EmptySession represents a session with no value.
public struct EmptySession: Session {
    /// The value of the empty session as a String.
    public var value: String = ""
    
    /// Initializes a new instance of `EmptySession`.
    public init() {}
}
