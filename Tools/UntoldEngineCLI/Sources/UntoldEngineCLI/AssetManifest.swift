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
        guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json") else {
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
