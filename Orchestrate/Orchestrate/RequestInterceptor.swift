// 
//  RequestInterceptor.swift
//  PingOrchestrate
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A protocol for request interceptor. To be implemented by classes that need to override the request.
public protocol RequestInterceptor {
    /// Intercepts the request before it is sent. Implement this method to override the request.
    func intercept(context: FlowContext, request: Request) -> Request
}
