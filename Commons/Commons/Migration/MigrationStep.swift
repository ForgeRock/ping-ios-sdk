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
/// The ``id`` property provides a stable, non-localizable identifier for programmatic
/// checks (e.g., UI state comparisons), while ``description`` is a human-readable,
/// display-only field that can be freely translated.
///
/// ## Defining Custom Steps
///
/// Migration modules extend `MigrationStep` with their own step constants:
///
/// ```swift
/// extension MigrationStep {
///     static let importLegacyData   = MigrationStep(id: "importLegacyData", description: "Import legacy data")
///     static let migrateCredentials = MigrationStep(id: "migrateCredentials", description: "Migrate credentials")
///     static let cleanup            = MigrationStep(id: "cleanup", description: "Cleanup legacy data")
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
public struct MigrationStep: Sendable, Identifiable, Equatable, Hashable, CustomStringConvertible {

    /// A stable, non-localizable identifier for the step.
    ///
    /// Use this for programmatic checks (e.g., `if step.id == "importLegacyData"`)
    public let id: String

    /// A human-readable description of the step.
    ///
    /// Used in progress reporting, log messages, and UI display. Should be a short,
    /// descriptive phrase such as `"Import legacy data"` or `"Migrate credentials"`.
    public let description: String

    /// Creates a new migration step with the given identifier and description.
    ///
    /// - Parameters:
    ///   - id: A stable, non-localizable identifier for programmatic use.
    ///   - description: A human-readable description of the step.
    public init(id: String, description: String) {
        self.id = id
        self.description = description
    }

    // MARK: - Equatable & Hashable

    public static func == (lhs: MigrationStep, rhs: MigrationStep) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
