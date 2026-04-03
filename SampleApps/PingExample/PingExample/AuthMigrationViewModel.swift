//
//  AuthMigrationViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingAuthMigration
import PingCommons
import PingLogger

/// Represents the current state of the migration process.
enum MigrationStatus: Equatable {
    case idle
    case checking
    case running
    case completed
    case failed
}

/// Represents a single migration step's result for UI display.
struct MigrationStepResult: Identifiable {
    let id = UUID()
    let stepDescription: String
    var status: StepStatus

    enum StepStatus {
        case inProgress
        case completed
        case failed(String)
    }
}

@MainActor
class AuthMigrationViewModel: ObservableObject {

    @Published var migrationStatus: MigrationStatus = .idle
    @Published var isMigrationNeeded: Bool? = nil
    @Published var stepResults: [MigrationStepResult] = []
    @Published var summaryMessage: String? = nil
    @Published var errorMessage: String? = nil

    /// Checks whether legacy FRAuthenticator data exists in the Keychain.
    func checkMigrationNeeded() async {
        migrationStatus = .checking
        let needed = await AuthMigration.isMigrationNeeded()
        isMigrationNeeded = needed
        migrationStatus = .idle
    }

    /// Starts the migration pipeline with progress tracking.
    func startMigration() async {
        // Reset state
        stepResults = []
        summaryMessage = nil
        errorMessage = nil
        migrationStatus = .running

        let stream = AuthMigration.start { config in
            config.logger = LogManager.logger
        }

        for await progress in stream {
            switch progress {
            case .started:
                break

            case .inProgress(let step, _, _):
                stepResults.append(
                    MigrationStepResult(
                        stepDescription: step.description,
                        status: .inProgress
                    )
                )

            case .stepCompleted(let step):
                if let index = stepResults.lastIndex(where: { $0.stepDescription == step.description }) {
                    stepResults[index].status = .completed
                }

            case .success(let message):
                summaryMessage = message
                migrationStatus = .completed
                // Refresh the check
                isMigrationNeeded = false

            case .error(let step, let error):
                if let index = stepResults.lastIndex(where: { $0.stepDescription == step.description }) {
                    stepResults[index].status = .failed(error.localizedDescription)
                }
                errorMessage = "Failed at \"\(step.description)\": \(error.localizedDescription)"
                migrationStatus = .failed

            @unknown default:
                break
            }
        }

        // If stream ended without explicit success/error (e.g., no legacy data)
        if migrationStatus == .running {
            migrationStatus = .completed
            if summaryMessage == nil {
                summaryMessage = "No legacy data to migrate."
            }
        }
    }
}
