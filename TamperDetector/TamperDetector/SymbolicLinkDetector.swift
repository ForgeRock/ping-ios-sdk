//
//  SymbolicLinkDetector.swift
//  PingTamperDetector
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// SymbolicLinkDetector is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class SymbolicLinkDetector: TamperDetectorProtocol {
    
    public init() { }

    /// Analyzes whether certain directories are symbolic links or not
    ///
    /// - NOTE: As part of Jailbreak process, it is commonly known that Jailbreak process will overwrite the partition, and changes some directories as symbolic link as original file/directory should remain as it was
    ///
    /// - Returns: returns 1.0 when certain directories are found as symbolic links; otherwise returns 0.0
    public func analyze() -> Double {
        let urls: [String] = [
            "/var/lib/undecimus/apt", 
            "/Applications",
            "/Library/Ringtones",
            "/Library/Wallpaper",
            "/usr/arm-apple-darwin9",
            "/usr/include",
            "/usr/libexec",
            "/usr/share"
        ]
        
        for urlString in urls {
            let url = URL(fileURLWithPath: urlString)
            if let ok = try? url.checkResourceIsReachable(), ok {
                let vals = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
                if let vals = vals, let islink = vals.isSymbolicLink, islink {
                    logger.w("SymbolicLinkDetector: path '\(urlString)' is a symbolic link, which is a common indicator of jailbreaking.", error: nil)
                    return 1.0
                }
            }
        }
        logger.d("SymbolicLinkDetector: no suspicious symbolic links found.")
        return 0.0
    }
}
