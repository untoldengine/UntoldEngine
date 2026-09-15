//
//  AssetManifest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

private final class AssetManifestBundleLocator {}

struct AssetPack: Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let downloadURL: String
    let size: String
}

struct AssetManifest: Codable {
    let version: String
    let assets: [AssetPack]

    /// Load from the bundled manifest.json shipped with the CLI binary.
    /// Swap this out for fetch(from:) once asset packs are hosted remotely.
    static func load() throws -> AssetManifest {
        // Bundle.main first covers a flattened, signed distribution of the CLI binary; the
        // nested-bundle fallback covers `swift run`/`swift test`/a plain built binary. Goes
        // through Bundle.safeModuleResourceBundle rather than this target's own generated
        // Bundle.module -- that accessor calls Swift.fatalError() on a miss, which is fatal to
        // the whole CLI invocation for what should be a recoverable missing-resource error.
        guard
            let url = Bundle.main.url(forResource: "manifest", withExtension: "json")
            ?? Bundle.mainResourceURLByPath(forResource: "manifest", withExtension: "json")
            ?? Bundle.safeModuleResourceBundle(
                named: "UntoldEngineCLI_UntoldEngineCLI.bundle", anchor: AssetManifestBundleLocator.self
            )?.url(forResource: "manifest", withExtension: "json")
        else {
            throw AssetError.manifestNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AssetManifest.self, from: data)
    }

    static func fetch(from manifestURL: URL) async throws -> AssetManifest {
        let (data, response) = try await URLSession.shared.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AssetError.downloadFailed("Failed to fetch manifest")
        }
        return try JSONDecoder().decode(AssetManifest.self, from: data)
    }
}
