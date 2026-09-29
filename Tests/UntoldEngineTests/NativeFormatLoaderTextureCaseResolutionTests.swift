//
//  NativeFormatLoaderTextureCaseResolutionTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

@testable import UntoldEngine
import XCTest

/// A `.untold` file's texture URI is baked at export time and can drift in casing from
/// the folder actually checked into the project (e.g. "Textures" baked vs. "textures" on
/// disk). That mismatch is invisible on this Mac's default case-insensitive volume, so
/// these tests exercise `caseInsensitiveResolvedURL` directly rather than relying on
/// `FileManager.fileExists` to fail the way it would on a case-sensitive bundle layout.
final class NativeFormatLoaderTextureCaseResolutionTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("NativeFormatLoaderTextureCaseResolutionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        try super.tearDownWithError()
    }

    func testCaseInsensitiveResolvedURLMatchesDifferentlyCasedFolder() throws {
        let texturesDirectory = tempRoot.appendingPathComponent("textures", isDirectory: true)
        try FileManager.default.createDirectory(at: texturesDirectory, withIntermediateDirectories: true)
        let currentResource = texturesDirectory.appendingPathComponent("soccer-stadium.vox-0.png")
        try Data().write(to: currentResource)

        let loader = NativeFormatLoader()
        let resolved = loader.caseInsensitiveResolvedURL(
            relativePath: "Textures/soccer-stadium.vox-0.png",
            baseURL: tempRoot
        )

        XCTAssertEqual(resolved?.standardizedFileURL, currentResource.standardizedFileURL)
    }

    func testCaseInsensitiveResolvedURLReturnsNilWhenNoMatchExists() {
        let loader = NativeFormatLoader()
        let resolved = loader.caseInsensitiveResolvedURL(
            relativePath: "Textures/does-not-exist.png",
            baseURL: tempRoot
        )

        XCTAssertNil(resolved)
    }

    func testResolvedURLResolvesDifferentlyCasedFolderEndToEnd() throws {
        // On this machine's default case-insensitive volume, the plain fileExists check
        // earlier in resolvedURL already matches "Textures" against a real "textures"
        // folder, so this doesn't by itself prove the case-insensitive fallback branch
        // ran -- that's covered deterministically (independent of host filesystem case
        // sensitivity) by the caseInsensitiveResolvedURL tests above. This just guards
        // the end-to-end public entry point returns the right URL either way.
        let texturesDirectory = tempRoot.appendingPathComponent("textures", isDirectory: true)
        try FileManager.default.createDirectory(at: texturesDirectory, withIntermediateDirectories: true)
        let currentResource = texturesDirectory.appendingPathComponent("soccer-player-1.png")
        try Data().write(to: currentResource)

        let loader = NativeFormatLoader()
        let resolved = loader.resolvedURL(from: "Textures/soccer-player-1.png", baseURL: tempRoot)

        // Not a standardizedFileURL equality check: on this case-insensitive host,
        // resolvedURL's first plain fileExists probe already matches "Textures" against
        // "textures" and returns that URL as-given (unchanged, pre-existing behavior),
        // rather than the case-corrected one caseInsensitiveResolvedURL would produce.
        // What matters here is that some URL pointing at a real, loadable file comes back.
        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
    }
}
