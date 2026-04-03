//
//  RuntimeAssetSource.swift
//  UntoldEngine
//
//  Source descriptors and lightweight metadata for selecting the correct
//  runtime asset loader implementation.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct RuntimeAssetSource: Sendable, Equatable {
    public var url: URL
    public var kind: RuntimeAssetSourceKind

    public init(url: URL, kind: RuntimeAssetSourceKind) {
        self.url = url
        self.kind = kind
    }

    public static func infer(from url: URL) -> RuntimeAssetSource {
        let ext = url.pathExtension.lowercased()
        let kind: RuntimeAssetSourceKind = switch ext {
        case "untold":
            .untold
        case "usd", "usda", "usdc", "usdz":
            .usd
        default:
            .procedural
        }
        return RuntimeAssetSource(url: url, kind: kind)
    }
}
