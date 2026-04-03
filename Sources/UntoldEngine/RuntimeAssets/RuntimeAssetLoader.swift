//
//  RuntimeAssetLoader.swift
//  UntoldEngine
//
//  Loader contracts for source-specific decoders that produce source-agnostic
//  runtime assets for the engine.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public protocol RuntimeAssetLoading: Sendable {
    func loadAsset(from url: URL) async throws -> RuntimeAsset
}

public protocol NamedRuntimeAssetLoading: RuntimeAssetLoading {
    func loadMeshGroup(named name: String, from url: URL) async throws -> RuntimeMeshGroup?
}

public enum RuntimeAssetLoaderError: Error, Sendable, Equatable {
    case unsupportedSource(URL)
    case missingMeshGroup(String)
    case malformedAsset(String)
}
