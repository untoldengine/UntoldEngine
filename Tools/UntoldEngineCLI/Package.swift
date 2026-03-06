//
//  Package.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UntoldEngineCLI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // CLI executable for project creation
        .executable(
            name: "untoldengine-create",
            targets: ["UntoldEngineCLI"]
        ),
    ],
    dependencies: [
        // Command-line argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),

        // Local dependency on UntoldEngine (two directories up from Tools/UntoldEngineCLI)
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "UntoldEngineCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
