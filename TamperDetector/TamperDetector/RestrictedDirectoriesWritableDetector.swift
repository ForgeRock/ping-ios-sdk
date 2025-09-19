//
//  RestrictedDirectoriesWritableDetector.swift
//  JailbreakDetector
//
//  Copyright (c) 2019 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// RestrictedDirectoriesWritableDetector is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class RestrictedDirectoriesWritableDetector: TamperDetectorProtocol {
    
    public init() { }

    /// Analyzes whether the app can write to restricted directories
    ///
    /// - Returns: returns 1.0 if the app has write access to restricted directories; otherwise returns 0.0
    public func analyze() -> Double {
        
        let fileManager = FileManager.default
        
        let restrictedPaths = [
            "/",
            "/root/",
            "/private/",
            "/jb/"
        ]
        for restrictedPath in restrictedPaths {
            
            var isFileWritable = false
            let path = restrictedPath + UUID().uuidString
            
            // Try to generate a file with Random UUID as name
            // Make sure to handle writing / deleting operation separately to correctly measure the result
            do {
                try "[TamperDetector] RestrictedDirectoriesWritableDetection Test".write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
                isFileWritable = true
            } catch {
                isFileWritable = false
            }
            
            // Make sure if the file was written, delete the file
            if isFileWritable {
                do {
                    try fileManager.removeItem(atPath: path)
                } catch {
                    // Warn that file is created, but was able to delete
                }
            }
            
            if isFileWritable {
                return 1.0
            }
        }
        
        return 0.0
    }
}
