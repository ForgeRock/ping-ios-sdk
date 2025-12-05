//
//  HttpResponseInterceptor.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Response interceptor closure type.
///
/// Interceptors are executed in registration order after the response is received.
public typealias HttpResponseInterceptor = @Sendable (HttpResponse) -> Void
