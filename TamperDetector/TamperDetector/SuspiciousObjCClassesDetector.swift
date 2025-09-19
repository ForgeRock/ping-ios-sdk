//
//  SuspiciousObjCClassesDetector.swift
//  JailbreakDetector
//
//  Copyright (c) 2023 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// SuspiciousObjCClassesDetector is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class SuspiciousObjCClassesDetector: TamperDetectorProtocol {
    
    public init() { }

    /// Analyzes whether suspicious Obj C classes are found
    ///
    /// - Returns: returns 1.0 if suspicious Obj C classes are found, otherwise returns 0.0
    public func analyze() -> Double {
        
        if let shadowRulesetClass = objc_getClass("ShadowRuleset") as? NSObject.Type {
            let selector = Selector(("internalDictionary"))
            if class_getInstanceMethod(shadowRulesetClass, selector) != nil {
                return 1.0
            }
        }
        
        return 0.0
    }
}