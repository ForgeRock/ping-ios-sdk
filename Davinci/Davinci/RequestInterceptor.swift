// 
//  RequestInterceptor.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate

public protocol RequestInterceptor {
    func intercept(context: FlowContext, request: Request) -> Request
}
