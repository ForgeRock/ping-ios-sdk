//
//  PingDesignSystemImport.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingDesignSystem

/// Re-exports the shared design system for every PingExample source file, so
/// call sites keep compiling without a per-file `import PingDesignSystem`.
/// Per-file imports are unnecessary while this shim exists; if it's ever
/// dropped, add an explicit `import PingDesignSystem` to each call site first.
@_exported import PingDesignSystem
