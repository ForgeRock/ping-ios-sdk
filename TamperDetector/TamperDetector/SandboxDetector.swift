//
//  SandboxDetector.swift
//  TamperDetector
//
//  Copyright (c) 2019 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// SandboxDetector is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class SandboxDetector: TamperDetectorProtocol {
    
    public init() { }

    /// Analyzes whether the device has an access to special system method on non-jailbroken devices
    ///
    /// - Returns: returns 1.0 when the device can successfully use fork() and return pid; otherwise returns 0.0
    public func analyze() -> Double {
        
        if isSimulator() {
            return 0.0
        }
        
        let pointerToFork = UnsafeMutableRawPointer(bitPattern: -2)
        let forkPtr = dlsym(pointerToFork, "fork")
        typealias ForkType = @convention(c) () -> pid_t
        let fork = unsafeBitCast(forkPtr, to: ForkType.self)
        let forkResult = fork()
        
        if forkResult >= 0 {
            if forkResult > 0 {
                kill(forkResult, SIGTERM)
            }
            return 1.0
        }
        
        return 0.0
    }
}
