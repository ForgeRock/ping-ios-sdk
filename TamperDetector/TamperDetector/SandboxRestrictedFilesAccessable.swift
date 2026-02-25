// 
//  SandboxRestrictedFilesAccessable.swift
//  PingTamperDetector
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger

/// SandboxRestrictedFilesAccessable is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class SandboxRestrictedFilesAccessable: TamperDetectorProtocol {
        
    public init() { }

    /// Analyzes whether the app has access the restricted directories
    ///
    /// - Returns: returns 1.0 if the app has access to restricted directories; otherwise returns 0.0
    public func analyze() -> Double {
        
        let restrictedPaths = ["/var/root/", "/var/mobile/Library/Preferences"]
        for path in restrictedPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                logger.w("SandboxRestrictedFilesAccessable: app can read sandbox-restricted path '\(path)'.", error: nil)
                return 1.0
            }
        }
        
        logger.d("SandboxRestrictedFilesAccessable: no sandbox-restricted paths are readable.")
        return 0.0
    }
}
