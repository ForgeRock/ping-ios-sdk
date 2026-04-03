//
//  MigrationProgress.swift
//  PingCommons
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Represents the progress state of a migration operation.
///
/// `MigrationProgress` is an enum that tracks the various states of a migration process.
/// It is emitted as an `AsyncStream` from a migration's `start()` method, allowing
/// consumers to monitor migration progress, handle errors, and provide user feedback.
///
/// ## Progress Flow Sequence
///
/// A typical migration follows this progress sequence:
/// 1. **started** — Migration begins.
/// 2. **inProgress** — For each step being executed.
/// 3. **stepCompleted** — After each step completes successfully.
/// 4. **success** — When all steps complete, OR
/// 5. **error** — If any step fails with an exception.
///
/// ## Usage Example
///
/// ```swift
/// for await progress in migrationStream {
///     switch progress {
///     case .started:
///         showProgressIndicator()
///
///     case .inProgress(let step, let current, let total):
///         updateProgressBar(current: current, total: total)
///         updateStatus("Step \(current)/\(total): \(step)")
///
///     case .stepCompleted(let step):
///         logger.i("Completed step: \(step)")
///
///     case .success(let message):
///         hideProgressIndicator()
///         showSuccessMessage(message)
///
///     case .error(let step, let error):
///         hideProgressIndicator()
///         showErrorDialog("Migration failed at step: \(step)", error: error)
///     }
/// }
/// ```
///
/// ## Error Handling
///
/// When a migration step throws an exception, the migration process stops
/// and emits an ``error(step:underlyingError:)`` event. The error contains both the
/// exception and the step where the failure occurred, enabling precise error handling
/// and debugging.
///
/// - SeeAlso: ``MigrationStep``
public enum MigrationProgress: Sendable {

    /// Migration has started.
    ///
    /// This is the first progress event emitted when a migration begins execution.
    /// It indicates that the migration framework has initialized and is about to
    /// start executing the configured steps.
    ///
    /// Use this event to initialize progress tracking UI, show loading indicators,
    /// or prepare logging systems for the migration process.
    case started

    /// A migration step is about to execute.
    ///
    /// This progress event is emitted when a migration step is about to be executed.
    /// It provides information about the current step, including its position
    /// in the sequence.
    ///
    /// This event is emitted **before** the step executes, allowing
    /// UI updates to show what operation is about to begin.
    ///
    /// - Parameters:
    ///   - step: The ``MigrationStep`` about to be executed, containing its description.
    ///   - current: The 1-based index of the step currently being executed (1, 2, 3, …).
    ///   - total: The total number of steps in this migration sequence.
    case inProgress(step: MigrationStep, current: Int, total: Int)

    /// A migration step has completed successfully.
    ///
    /// This progress event is emitted **after** a migration step finishes
    /// its work without throwing an exception.
    ///
    /// Use this event for logging step completions, updating detailed progress tracking,
    /// or performing cleanup actions after each step.
    ///
    /// - Parameter step: The ``MigrationStep`` that has completed successfully.
    case stepCompleted(step: MigrationStep)

    /// Migration completed successfully.
    ///
    /// This is the final progress event emitted when a migration completes without errors.
    /// It indicates that all migration steps have been executed successfully.
    ///
    /// Use this event to hide progress UI, show success messages, perform
    /// post-migration cleanup, or trigger dependent operations.
    ///
    /// - Parameter message: A human-readable summary providing additional context about
    ///   the completion (e.g., `"Migrated 3 OATH + 1 Push credentials"`).
    case success(message: String)

    /// Migration failed with an error.
    ///
    /// This progress event is emitted when a migration step throws an exception
    /// during execution. The migration process stops immediately when an error
    /// occurs, and no further steps are executed.
    ///
    /// The error state provides both the exception that caused the failure and
    /// the specific step where the error occurred, enabling precise error handling
    /// and debugging.
    ///
    /// - Parameters:
    ///   - step: The ``MigrationStep`` where the error occurred, providing context for debugging.
    ///   - underlyingError: The `Error` that caused the migration to fail.
    case error(step: MigrationStep, underlyingError: Error)
}
