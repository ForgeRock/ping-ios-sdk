// 
//  TextCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import Combine

/// Class representing a TEXT type.
/// This class inherits from the ValidatedCollector class and implements the Collector protocol.
/// It is used to collect text data.
public class TextCollector: ValidatedCollector, ObservableObject, @unchecked Sendable {}
