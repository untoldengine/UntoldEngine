//
//  TextureLoaderBracketParserTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// Unit tests for `TextureLoader.parseUSDZBracketPath`.
///
/// This static function is the only piece of Option-B URL-based texture loading that
/// contains non-trivial logic (string parsing + URL construction). All other code paths
/// delegate to MTKTextureLoader, which can only be exercised on-device.
final class TextureLoaderBracketParserTests: XCTestCase {
    // MARK: - Valid inputs

    func testTypicalUSDZEmbeddedPath_returnsURLAndInnerPath() {
        let str = "file:///var/containers/scene.usdz[0/texture_base_color.png]"
        let result = TextureLoader.parseUSDZBracketPath(from: str)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.usdzURL, URL(string: "file:///var/containers/scene.usdz"))
        XCTAssertEqual(result?.innerPath, "0/texture_base_color.png")
    }

    func testInnerPathWithSubdirectory_preservesSlashes() {
        let str = "file:///path/to/my%20scene.usdz[textures/diffuse/albedo.png]"
        let result = TextureLoader.parseUSDZBracketPath(from: str)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.innerPath, "textures/diffuse/albedo.png")
    }

    func testBackslashesInInnerPath_areNormalized() {
        let str = "file:///models/city.usdz[0\\building_wall.jpg]"
        let result = TextureLoader.parseUSDZBracketPath(from: str)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.innerPath, "0/building_wall.jpg")
    }

    func testLeadingAndTrailingWhitespaceInInnerPath_isTrimmed() {
        let str = "file:///models/props.usdz[  0/prop_diffuse.png  ]"
        let result = TextureLoader.parseUSDZBracketPath(from: str)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.innerPath, "0/prop_diffuse.png")
    }

    func testLastBracketPairIsUsed_whenMultipleBracketsPresent() {
        // lastIndex(of:) is used intentionally — the USDZ path itself never contains brackets.
        let str = "file:///path/to/[weird]name.usdz[0/texture.png]"
        let result = TextureLoader.parseUSDZBracketPath(from: str)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.innerPath, "0/texture.png")
    }

    // MARK: - Invalid / edge-case inputs

    func testEmptyString_returnsNil() {
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: ""))
    }

    func testStringWithNoBrackets_returnsNil() {
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "file:///path/to/scene.usdz"))
    }

    func testEmptyInnerPath_returnsNil() {
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "file:///scene.usdz[]"))
    }

    func testWhitespaceOnlyInnerPath_returnsNil() {
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "file:///scene.usdz[   ]"))
    }

    func testNonFileURL_returnsNil() {
        // Only file:// URLs should be treated as USDZ package paths.
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "https://example.com/scene.usdz[0/tex.png]"))
    }

    func testOpenBracketAfterCloseBracket_returnsNil() {
        // Malformed: "]" comes before "[" when searching from the end.
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "file:///scene.usdz]0/tex.png["))
    }

    func testMissingCloseBracket_returnsNil() {
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "file:///scene.usdz[0/tex.png"))
    }

    func testMissingOpenBracket_returnsNil() {
        XCTAssertNil(TextureLoader.parseUSDZBracketPath(from: "file:///scene.usdz 0/tex.png]"))
    }

    // MARK: - Package URL construction

    func testPackageURLIsCorrectlyAssembled() {
        let str = "file:///Users/harold/models/city.usdz[0/building_albedo.png]"
        guard let parsed = TextureLoader.parseUSDZBracketPath(from: str) else {
            XCTFail("Expected successful parse")
            return
        }
        let packageURL = parsed.usdzURL.appendingPathComponent(parsed.innerPath)
        XCTAssertEqual(packageURL.absoluteString, "file:///Users/harold/models/city.usdz/0/building_albedo.png")
    }
}
