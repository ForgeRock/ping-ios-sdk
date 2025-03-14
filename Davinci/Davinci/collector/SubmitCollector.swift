// 
//  SubmitCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Class representing a SUBMIT_BUTTON Type.
/// This class inherits from the SingleValueCollector class and implements the Collector protocol.
/// It is used to collect data when a form is submitted.
public class SubmitCollector: SingleValueCollector, @unchecked Sendable {}
