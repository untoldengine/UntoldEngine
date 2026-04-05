
//
//  AssetDiskCacheTests.swift
//  UntoldEngineTests
//
//  Unit tests for AssetDiskCache.
//  No GPU, no renderer — pure disk I/O logic.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

final class AssetDiskCacheTests: XCTestCase {
    /// Each test gets a fresh temporary directory so tests are fully isolated.
    private var cacheDir: URL!

    override func setUp() async throws {
        cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssetDiskCacheTest-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDir)
    }

    // MARK: - Helpers

    private func makeCache(maxBytes: Int = 10 * 1024 * 1024) -> AssetDiskCache {
        AssetDiskCache(directory: cacheDir, maxBytes: maxBytes)
    }

    private func remoteURL(_ path: String) -> URL {
        URL(string: "https://cdn.example.com/\(path)")!
    }

    // MARK: - store / localURL

    func testStoreAndRetrieve() async throws {
        let cache = makeCache()
        let url = remoteURL("tiles/city_01.untold")
        let payload = Data("hello world".utf8)

        let localURL = try await cache.store(data: payload, for: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
        XCTAssertEqual(localURL.pathExtension, "untold")

        let retrieved = await cache.localURL(for: url)
        XCTAssertEqual(retrieved, localURL)
    }

    func testCacheMissReturnsNil() async {
        let cache = makeCache()
        let url = remoteURL("tiles/missing.untold")

        let result = await cache.localURL(for: url)
        XCTAssertNil(result)
    }

    func testTwoDifferentURLsGetDifferentFiles() async throws {
        let cache = makeCache()
        let urlA = remoteURL("tiles/a.untold")
        let urlB = remoteURL("tiles/b.untold")

        let localA = try await cache.store(data: Data("aaa".utf8), for: urlA)
        let localB = try await cache.store(data: Data("bbb".utf8), for: urlB)

        XCTAssertNotEqual(localA, localB)
        let cachedA = await cache.localURL(for: urlA)
        let cachedB = await cache.localURL(for: urlB)
        XCTAssertNotNil(cachedA)
        XCTAssertNotNil(cachedB)
    }

    func testOverwriteSameURL() async throws {
        let cache = makeCache()
        let url = remoteURL("tiles/city_01.untold")

        _ = try await cache.store(data: Data("v1".utf8), for: url)
        let localURL = try await cache.store(data: Data("v2".utf8), for: url)

        // Only one file should exist (not two).
        let contents = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "untold" }
        XCTAssertEqual(contents.count, 1)

        // Content should be the latest write.
        let data = try Data(contentsOf: localURL)
        XCTAssertEqual(String(data: data, encoding: .utf8), "v2")
    }

    // MARK: - ETag sidecar

    func testEtagRoundTrip() async throws {
        let cache = makeCache()
        let url = remoteURL("scenes/manifest.json")
        let etag = "\"abc123\""

        _ = try await cache.store(data: Data("{}".utf8), for: url, etag: etag)

        let retrieved = await cache.etag(for: url)
        XCTAssertEqual(retrieved, etag)
    }

    func testNoEtagSidecarWhenEtagIsNil() async throws {
        let cache = makeCache()
        let url = remoteURL("tiles/city_01.untold")

        _ = try await cache.store(data: Data("data".utf8), for: url, etag: nil)

        let metaFiles = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "meta" }
        XCTAssertTrue(metaFiles.isEmpty, "No .meta sidecar should be written when etag is nil")
    }

    // MARK: - storeAtRelativePath / fileExists

    func testStoreAtRelativePath() async throws {
        let cache = makeCache()
        let relativePath = "Textures/SimpleDungeonTexture.png"
        let payload = Data("fake-png".utf8)

        try await cache.storeAtRelativePath(relativePath, data: payload)

        let expectedURL = cacheDir.appendingPathComponent(relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path))

        let stored = try Data(contentsOf: expectedURL)
        XCTAssertEqual(stored, payload)
    }

    func testFileExistsAtRelativePath_falseBeforeStore() async {
        let cache = makeCache()
        let exists = await cache.fileExists(atRelativePath: "Textures/Missing.png")
        XCTAssertFalse(exists)
    }

    func testFileExistsAtRelativePath_trueAfterStore() async throws {
        let cache = makeCache()
        let relativePath = "Textures/Present.png"

        try await cache.storeAtRelativePath(relativePath, data: Data("img".utf8))

        let exists = await cache.fileExists(atRelativePath: relativePath)
        XCTAssertTrue(exists)
    }

    func testStoreAtRelativePathCreatesSubdirectories() async throws {
        let cache = makeCache()
        let deepPath = "Assets/Textures/Sub/Deep.png"

        try await cache.storeAtRelativePath(deepPath, data: Data("x".utf8))

        let dir = cacheDir.appendingPathComponent("Assets/Textures/Sub", isDirectory: true)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    // MARK: - LRU eviction

    func testLRUEvictsOldestEntries() async throws {
        // Budget: 250 bytes. Each payload: 100 bytes.
        // After storing C (3rd entry), currentBytes = 300 > 250.
        // evictIfNeeded targets 75% = 187 bytes.
        // Evict A (oldest, 100 bytes) → 200 bytes, still > 187.
        // Evict B (100 bytes) → 100 bytes ≤ 187. Stop.
        // Only C should remain.
        let cache = makeCache(maxBytes: 250)

        let urlA = remoteURL("evict/a.bin")
        let urlB = remoteURL("evict/b.bin")
        let urlC = remoteURL("evict/c.bin")
        let payload = Data(repeating: 0xAB, count: 100)

        _ = try await cache.store(data: payload, for: urlA)
        try await Task.sleep(nanoseconds: 1_000_000) // ensure distinct lastAccess timestamps
        _ = try await cache.store(data: payload, for: urlB)
        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try await cache.store(data: payload, for: urlC)

        let evictA = await cache.localURL(for: urlA)
        let evictB = await cache.localURL(for: urlB)
        let evictC = await cache.localURL(for: urlC)
        XCTAssertNil(evictA, "Oldest entry A should have been evicted")
        XCTAssertNil(evictB, "Second-oldest entry B should have been evicted")
        XCTAssertNotNil(evictC, "Newest entry C should survive eviction")
    }

    func testLRUAccessUpdatesOrder() async throws {
        // Store A then B (A is older). Access A to promote it to most-recently-used.
        // Store C to trigger eviction (300 bytes > maxBytes 280).
        // target = 75% of 280 = 210. Evict oldest (B, 100 bytes) → 200 ≤ 210, stop.
        // B should be evicted; A and C should survive.
        let cache = makeCache(maxBytes: 280)

        let urlA = remoteURL("order/a.bin")
        let urlB = remoteURL("order/b.bin")
        let urlC = remoteURL("order/c.bin")
        let payload = Data(repeating: 0xBC, count: 100)

        _ = try await cache.store(data: payload, for: urlA)
        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try await cache.store(data: payload, for: urlB)
        try await Task.sleep(nanoseconds: 1_000_000)

        // Touch A — promotes it to most-recently-used.
        _ = await cache.localURL(for: urlA)

        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try await cache.store(data: payload, for: urlC)

        let orderA = await cache.localURL(for: urlA)
        let orderB = await cache.localURL(for: urlB)
        let orderC = await cache.localURL(for: urlC)
        XCTAssertNotNil(orderA, "A was accessed recently — should survive eviction")
        XCTAssertNil(orderB, "B was least recently used — should be evicted")
        XCTAssertNotNil(orderC, "C is newest — should survive eviction")
    }

    // MARK: - Index persistence

    func testIndexSurvivesReinit() async throws {
        let url = remoteURL("persist/tile.untold")
        let payload = Data("persistent".utf8)

        // Write via first instance.
        let cache1 = makeCache()
        _ = try await cache1.store(data: payload, for: url)

        // Second instance at the same directory should find the file.
        let cache2 = AssetDiskCache(directory: cacheDir, maxBytes: 10 * 1024 * 1024)
        let retrieved = await cache2.localURL(for: url)
        XCTAssertNotNil(retrieved, "Cached file written by cache1 should be found by cache2 after reinit")
    }

    func testMissingFileRemovedFromIndexOnRead() async throws {
        let cache = makeCache()
        let url = remoteURL("stale/gone.untold")

        let localURL = try await cache.store(data: Data("x".utf8), for: url)

        // Delete the file behind the cache's back.
        try FileManager.default.removeItem(at: localURL)

        // localURL should return nil and evict the stale entry.
        let result = await cache.localURL(for: url)
        XCTAssertNil(result, "Stale index entry with missing file should return nil")
    }
}
