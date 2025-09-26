//
//  SuspiciousFilesAccessibleDetector.swift
//  PingTamperDetector
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// SuspiciousFilesAccessibleDetector is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class SuspiciousFilesAccessibleDetector: TamperDetectorProtocol {
    
    public init() { }

    /// Analyzes whether suspicious files are accessible
    ///
    /// - Returns: returns 1.0 if suspicious files are accessible; otherwise returns 0.0
    public func analyze() -> Double {
        
        var paths = [
            "/.installed_unc0ver",
            "/.bootstrapped_electra",
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/etc/apt",
            "/var/log/apt",
            "/var/jb/"
        ]
        
        // These files can give false positive in the emulator
        if !isSimulator() {
            paths += [
                "/bin/bash",
                "/usr/sbin/sshd",
                "/usr/bin/ssh"
            ]
        }
        
        for path in paths {
            if self.canOpen(path: path) {
                return 1.0
            }
        }
        
        return 0.0
    }
}
