//
//  AssetRef.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// A reference to a project asset, stored as a path relative to the project's asset folder
/// (`assetBasePath`), e.g. `Animations/run.untold`.
public struct AssetRef: Equatable, Sendable {
    /// The asset browser folder a reference is picked from. Raw values match the folder names.
    public enum Category: String, CaseIterable, Sendable {
        case models = "Models"
        case streamModels = "StreamModels"
        case animations = "Animations"
        case scripts = "Scripts"
        case scenes = "Scenes"
        case gaussians = "Gaussians"
        case materials = "Materials"
        case hdr = "HDR"
        case lut = "LUT"
    }

    public var path: String
    /// Declaration metadata: which folder the editor offers. Not saved with the scene.
    public let category: Category?

    public init(_ path: String = "", category: Category? = nil) {
        self.path = path
        self.category = category
    }

    public var isEmpty: Bool {
        path.isEmpty
    }

    /// The asset's location on disk, when the project's asset folder is known.
    public func resolveURL() -> URL? {
        guard path.isEmpty == false, let basePath = assetBasePath else { return nil }
        return basePath.appendingPathComponent(path)
    }
}

extension AssetRef: UntoldAttributeValueType {
    public var attributeKind: UntoldAttributeKind {
        .asset(category: category?.rawValue)
    }

    public var attributeValue: UntoldAttributeValue {
        .object(["asset": path])
    }

    public func applying(_ value: UntoldAttributeValue) -> AssetRef? {
        guard case let .object(fields) = value, let path = fields["asset"] else { return nil }
        return AssetRef(path, category: category)
    }
}
