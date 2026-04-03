//
//  MigrationStep.swift
//  PingCommons
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Describes a single step in a migration pipeline.
///
/// `MigrationStep` is a lightweight value type that provides identification and
/// display metadata for a migration step. Each migration module defines its own
/// steps as `static` properties via extensions.
///
/// ## Defining Custom Steps
///
/// Migration modules extend `MigrationStep` with their own step constants:
///
/// ```swift
/// extension MigrationStep {
///     static let importLegacyData   = MigrationStep(description: "Import legacy data")
///     static let migrateCredentials = MigrationStep(description: "Migrate credentials")
///     static let cleanup            = MigrationStep(description: "Cleanup legacy data")
/// }
/// ```
///
/// ## Usage
///
/// Steps are passed as associated values in ``MigrationProgress`` events:
///
/// ```swift
/// case .inProgress(let step, let current, let total):
///     print("Step \(current)/\(total): \(step.description)")
/// ```
///
/// - SeeAlso: ``MigrationProgress``
public struct MigrationStep: Sendable, CustomStringConvertible {

    /// A human-readable description of the step.
    ///
    /// Used in progress reporting and log messages. Should be a short, descriptive phrase
    /// such as `"Import legacy data"` or `"Migrate credentials"`.
    public let description: String

    /// Creates a new migration step with the given description.
    ///
    /// - Parameter description: A human-readable description of the step.
    public init(description: String) {
        self.description = description
    }
}
