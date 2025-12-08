//
//  Int+StatusCode.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

extension Int {
    /// Returns true when the status code is in the 2xx range.
    public func isSuccess() -> Bool {
        (200...299).contains(self)
    }

    /// Returns true when the status code is in the 3xx range.
    public func isRedirect() -> Bool {
        (300...399).contains(self)
    }

    /// Returns true when the status code is in the 4xx range.
    public func isClientError() -> Bool {
        (400...499).contains(self)
    }

    /// Returns true when the status code is in the 5xx range.
    public func isServerError() -> Bool {
        (500...599).contains(self)
    }
}
