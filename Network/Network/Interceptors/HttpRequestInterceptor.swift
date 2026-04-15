//
//  HttpRequestInterceptor.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Request interceptor closure type.
///
/// Interceptors are executed in registration order before the request is sent.
public typealias HttpRequestInterceptor = @Sendable (HttpRequest) -> Void
