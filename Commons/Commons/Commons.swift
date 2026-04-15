// 
//  Commons.swift
//  Commons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

extension Int8 {
    /// Converts an array of `Int8` to a  string.
    ///
    /// - Parameter arr: The array of `Int8` to convert.
    /// - Parameter separator: String separator
    /// - Returns: A string representation of the array.
    public static func convertInt8ArrToStr(_ arr: [Int8], separator: String) -> String {
        return arr.map { String($0) }.joined(separator: separator)
    }
}
