
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// A struct representing the configuration for the user key storage.
public struct UserKeyStorageConfig {
    /// The name of the file to store the user keys in.
    public var fileName: String = "user_keys"
}
