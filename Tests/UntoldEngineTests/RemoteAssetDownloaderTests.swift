//
//  RemoteAssetDownloaderTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

final class RemoteAssetDownloaderTests: XCTestCase {
    func testLocalURLRejectsHTTPURLs() async throws {
        let downloader = RemoteAssetDownloader()

        do {
            _ = try await downloader.localURL(for: URL(string: "http://example.com/scene.json")!)
            XCTFail("Expected insecure HTTP URL to be rejected")
        } catch let error as RemoteAssetDownloader.DownloadError {
            XCTAssertEqual(error.errorDescription, "Refusing to download over 'http': only https:// is permitted")
        }
    }

    func testLocalURLRejectsMissingScheme() async throws {
        let downloader = RemoteAssetDownloader()

        do {
            _ = try await downloader.localURL(for: URL(fileURLWithPath: "/tmp/local-file"))
            XCTFail("Expected non-HTTPS URL to be rejected")
        } catch let error as RemoteAssetDownloader.DownloadError {
            XCTAssertEqual(error.errorDescription, "Refusing to download over 'file': only https:// is permitted")
        }
    }
}
