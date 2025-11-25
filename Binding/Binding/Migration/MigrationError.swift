//
//  MigrationError.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Errors that can occur during device binding migration.
public enum MigrationError: LocalizedError {
    /// Failed to read legacy user keys from keychain
    case failedToReadLegacyKeys(Error)
    
    /// Failed to save migrated keys to new storage
    case failedToSaveKeys(Error)
    
    /// Failed to delete legacy keychain data
    case failedToDeleteLegacyData(Error)
    
    /// No legacy data found to migrate
    case noLegacyDataFound
    
    /// Migration already completed
    case alreadyMigrated
    
    /// Invalid or corrupted legacy data
    case invalidLegacyData(String)
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .failedToReadLegacyKeys(let error):
            return "Failed to read legacy user keys: \(error.localizedDescription)"
        case .failedToSaveKeys(let error):
            return "Failed to save migrated keys: \(error.localizedDescription)"
        case .failedToDeleteLegacyData(let error):
            return "Failed to delete legacy data: \(error.localizedDescription)"
        case .noLegacyDataFound:
            return "No legacy data found to migrate"
        case .alreadyMigrated:
            return "Migration has already been completed"
        case .invalidLegacyData(let message):
            return "Invalid legacy data: \(message)"
        }
    }
}
