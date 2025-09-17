
//
//  JailbreakDetector.swift
//  JailbreakDetector
//
//  Copyright (c) 2019 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// JailbreakDetector protocol represents definition of JailbreakDetector which is used as individual analyzer to detect whether the device is Jailbroken or not. Each detector should analyze its logic to determine whether the device is suspicious to be Jailbroken or not, and returns the result score with maximum of 1.0
@objc
public protocol JailbreakDetectorProtocol {
    
    /// Analyzes and returns the score of result
    ///
    /// - NOTE: analyze result **MUST** returns result in Double within range of 0.0 to 1.0; if the result value is less than 0.0 or greater than 1.0, the result will be forced to floor() or ceil()
    ///
    /// - Returns: returns result of analysis within range of 0.0 to 1.0
    @objc
    func analyze() -> Double
}

// MARK: -
extension JailbreakDetectorProtocol {
    
    /// Validates whether given path can be opened through file system
    ///
    /// - Parameter path: designated path for a file or directory to check
    /// - Returns: returns true if given path can be opened; otherwise returns false
    public func canOpen(path: String) -> Bool {
        let file = fopen(path, "r")
        guard file != nil else {
            return false
            
        }
        fclose(file)
        return true
    }
    
    public func isSimulator() -> Bool {
        return checkCompile() || checkRuntime()
    }
    
    func checkRuntime() -> Bool {
        return ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] != nil
    }

    func checkCompile() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}


/// JailbreakDetector is responsible to analyze and provide possibilities in score whether the device is suspicious for Jailbreak or not
@objc
public class JailbreakDetector: NSObject {
    
    /// An array of JailbreakDetector to be analyzed
    @objc
    public var detectors: [JailbreakDetectorProtocol]
    
    /// Private initialization method which initializes default array of JailbreakDetector
    @objc
    public override init() {
        detectors = [SuspiciousFilesExistenceDetector(),
                     SuspiciousFilesAccessibleDetector(),
                     URLSchemeDetector(),
                     RestrictedDirectoriesWritableDetector(),
                     SymbolicLinkDetector(),
                     DyldDetector(),
                     SandboxDetector(),
                     SuspiciousObjCClassesDetector(),
                     SandboxRestrictedFilesAccessable()]
    }
    
    
    /// Initializes JailbreakDetector with custom detectors
    /// - Parameter detectors: An array of custom detectors
    @objc
    public init(detectors: [JailbreakDetectorProtocol]) {
        self.detectors = detectors
    }
    
    
    /// Analyzes and returns the result of given JailbreakDetector
    ///
    /// - NOTE: Any detector returns the result value less than 0.0 or greater than 1.0 will be rounded to a range of 0.0 to 1.0.
    ///
    /// - Returns: returns result of analysis of all given detectors
    @objc
    public func analyze() -> Double {
        #if targetEnvironment(simulator)
            return 0.0
        #else
        if self.detectors.count > 0 {
            let _ = self.detectors.count
            var maxResult = 0.0
            var result = 0.0
            for detector in self.detectors {
                var detectorResult = detector.analyze()
                if detectorResult > 1.0 {
                    detectorResult = 1.0
                }
                else if detectorResult < 0 {
                    detectorResult = 0
                }
                
                maxResult = max(maxResult, detectorResult)
                result += detectorResult
            }
            
            return maxResult
        }
        else {
            return -1.0
        }
        #endif
    }
}
