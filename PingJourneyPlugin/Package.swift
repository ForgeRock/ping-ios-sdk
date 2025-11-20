//
// Package.swift
//
// Copyright (c) 2024 Ping Identity. All rights reserved.
//
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENSE file for details.
//

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PingJourneyPlugin",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PingJourneyPlugin",
            targets: ["PingJourneyPlugin"]),
    ],
    targets: [
        .target(
            name: "PingJourneyPlugin",
            dependencies: []),
    ]
)
