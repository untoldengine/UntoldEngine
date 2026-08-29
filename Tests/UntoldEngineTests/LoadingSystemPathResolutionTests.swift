//
//  LoadingSystemPathResolutionTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

@testable import UntoldEngine
import XCTest

final class LoadingSystemPathResolutionTests: XCTestCase {
    private var previousAssetBasePath: URL?
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousAssetBasePath = assetBasePath
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoadingSystemPathResolutionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        assetBasePath = previousAssetBasePath
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testAbsoluteStalePathFallsBackToCurrentStructuredResourceSuffix() throws {
        let currentResource = tempRoot
            .appendingPathComponent("Models/redplayer", isDirectory: true)
            .appendingPathComponent("redplayer")
            .appendingPathExtension("usdz")
        try FileManager.default.createDirectory(at: currentResource.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: currentResource)
        assetBasePath = tempRoot

        let resolved = getResourceURL(
            resourceName: "/old/build/GameData/Models/redplayer/redplayer.usdz",
            ext: "usdz",
            subName: nil
        )

        XCTAssertEqual(resolved?.standardizedFileURL, currentResource.standardizedFileURL)
    }

    func testAbsoluteStalePathFallsBackToFlatResourceWithoutDuplicatingExtension() throws {
        let currentResource = tempRoot
            .appendingPathComponent("redplayer")
            .appendingPathExtension("usdz")
        try Data().write(to: currentResource)
        assetBasePath = tempRoot

        let resolved = getResourceURL(
            resourceName: "/old/build/GameData/Models/redplayer/redplayer.usdz",
            ext: "usdz",
            subName: nil
        )

        XCTAssertEqual(resolved?.standardizedFileURL, currentResource.standardizedFileURL)
    }

    func testAbsoluteStalePathFallbackUsesBundleResourceDirectory() throws {
        let bundleURL = tempRoot.appendingPathComponent("GameData.bundle", isDirectory: true)
        let resourcesURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let infoPlistURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.untoldengine.tests.gamedata</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
        </dict>
        </plist>
        """.write(to: infoPlistURL, atomically: true, encoding: .utf8)

        let currentResource = resourcesURL
            .appendingPathComponent("redplayer")
            .appendingPathExtension("usdz")
        try Data().write(to: currentResource)
        assetBasePath = bundleURL

        let resolved = getResourceURL(
            resourceName: "/old/build/GameData/Models/redplayer/redplayer.usdz",
            ext: "usdz",
            subName: nil
        )

        XCTAssertEqual(resolved?.standardizedFileURL, currentResource.standardizedFileURL)
    }

    func testBareResourceNameResolvesUnderTexturesDirectory() throws {
        // GameData/Textures is a canonical asset directory created by the project
        // scaffolding (see createGameDataDirectories()), but standalone texture
        // loads (loadTexture(textureName:)) pass subResource: nil, so this must
        // resolve through the plain structured search, not the Materials/subName one.
        let texturesDirectory = tempRoot.appendingPathComponent("Textures", isDirectory: true)
        try FileManager.default.createDirectory(at: texturesDirectory, withIntermediateDirectories: true)
        let currentResource = texturesDirectory
            .appendingPathComponent("icon")
            .appendingPathExtension("png")
        try Data().write(to: currentResource)
        assetBasePath = tempRoot

        let resolved = getResourceURL(resourceName: "icon", ext: "png", subName: nil)

        XCTAssertEqual(resolved?.standardizedFileURL, currentResource.standardizedFileURL)
    }
}
