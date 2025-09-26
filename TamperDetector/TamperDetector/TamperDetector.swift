//
//  TamperDetector.swift
//  PingTamperDetector
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// A protocol that defines a tamper detector. Each detector is responsible for a specific check to determine if the device is suspicious of being jailbroken.
@MainActor
public protocol TamperDetectorProtocol {
    /// Analyzes the device for a specific tampering indicator.
    /// - Returns: A score between 0.0 and 1.0, where 1.0 indicates a high probability of tampering.
    func analyze() -> Double
}

extension TamperDetectorProtocol {
    /// Checks if a file at a given path can be opened.
    /// - Parameter path: The path of the file to check.
    /// - Returns: `true` if the file can be opened, `false` otherwise.
    func canOpen(path: String) -> Bool {
        let file = fopen(path, "r")
        guard file != nil else {
            return false
        }
        fclose(file)
        return true
    }

    /// Checks if the code is running on a simulator.
    /// - Returns: `true` if the code is running on a simulator, `false` otherwise.
    func isSimulator() -> Bool {
        return checkCompile() || checkRuntime()
    }

    /// Checks if the code is being compiled for a simulator.
    /// - Returns: `true` if the code is being compiled for a simulator, `false` otherwise.
    func checkRuntime() -> Bool {
        return ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] != nil
    }

    /// Checks at runtime if the code is running on a simulator.
    /// - Returns: `true` if the code is running on a simulator, `false` otherwise.
    func checkCompile() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

/// The main class for detecting tampering on a device. It uses a set of detectors to analyze the device for signs of jailbreaking.
@MainActor
public class TamperDetector {
    
    let logger = LogManager.logger
    
    /// The default set of detectors used for tampering analysis.
    @MainActor
    public static var defaultDetectors: [TamperDetectorProtocol] {
        return [
            SuspiciousFilesExistenceDetector(),
            SuspiciousFilesAccessibleDetector(),
            URLSchemeDetector(),
            RestrictedDirectoriesWritableDetector(),
            SymbolicLinkDetector(),
            DyldDetector(),
            SandboxDetector(),
            SuspiciousObjCClassesDetector(),
            SandboxRestrictedFilesAccessable()
        ]
    }

    /// The list of detectors to be used for the analysis.
    public let detectors: [TamperDetectorProtocol]

    /// Initializes the `TamperDetector` with a custom set of detectors. If no detectors are provided, the default set is used.
    /// - Parameter detectors: An array of `TamperDetectorProtocol` to be used for the analysis.
    public init(detectors: [TamperDetectorProtocol] = defaultDetectors) {
        self.detectors = detectors
    }
    
    /// Initializes the `TamperDetector` with the default detectors plus a custom set of detectors.
    /// - Parameter customDetectors: An array of custom `TamperDetectorProtocol` to be added to the default set.
    public init(customDetectors: [TamperDetectorProtocol]) {
        self.detectors = TamperDetector.defaultDetectors + customDetectors
    }

    /// Analyzes the device for tampering using the configured detectors.
    /// - Parameter forceRunOnSimulator: A boolean to force the analysis to run on a simulator. Defaults to `false`.
    /// - Returns: A score between 0.0 and 1.0, where 1.0 indicates a high probability of tampering.
    @MainActor public func analyze(forceRunOnSimulator: Bool = false) -> Double {
        #if targetEnvironment(simulator)
            if !forceRunOnSimulator {
                self.logger.i("Running in Simulator, returning 0.0 (no tampering risk).")
                return 0.0
            }
        #endif

        if self.detectors.isEmpty {
            self.logger.e("No detectors configured, returning 1.0 (maximum tampering risk).", error: nil)
            return 1.0
        }

        var maxResult = 0.0
        for detector in self.detectors {
            var detectorResult = detector.analyze()
            if detectorResult >= 1.0 {
                detectorResult = 1.0
            }
            else if detectorResult < 0 {
                detectorResult = 0
            }
            
            maxResult = max(maxResult, detectorResult)
        }
        
        return maxResult
    }
}
