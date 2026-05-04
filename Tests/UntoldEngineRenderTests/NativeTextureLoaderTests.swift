//
//  NativeTextureLoaderTests.swift
//  UntoldEngine
//
//  Tests for NativeTextureLoader: shared cache deduplication, single-flight
//  concurrency, mip-tier separation, purge, error recovery, and key normalization.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@preconcurrency import Metal
@testable import UntoldEngine
import XCTest

// MARK: - Test class

@MainActor
final class NativeTextureLoaderTests: BaseRenderSetup {
    private var loader: NativeTextureLoader!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        loader = NativeTextureLoader(device: renderInfo.device)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NativeTextureLoaderTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        NativeTextureLoader.purgeSharedCache()
    }

    override func tearDown() async throws {
        NativeTextureLoader.purgeSharedCache()
        try? FileManager.default.removeItem(at: tempDir)
        loader = nil
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Cache deduplication

    func testCacheReturnsSameInstanceForSameURL() throws {
        let url = try writeMinimalUtex(named: "dedup_test")
        let t1 = loader.loadTexture(from: url)
        let t2 = loader.loadTexture(from: url)
        let tex1 = try XCTUnwrap(t1, "First load should succeed")
        let tex2 = try XCTUnwrap(t2, "Second load should succeed")
        XCTAssertIdentical(tex1, tex2, "Same URL must return the same MTLTexture instance from cache")
    }

    func testCacheSeparatesTiersForSameURL() throws {
        let url = try writeMinimalUtex(named: "tier_test", mipSizes: [128, 64, 32])
        let full = loader.loadTexture(from: url, targetMaxDimension: nil)
        let small = loader.loadTexture(from: url, targetMaxDimension: 64)
        let texFull = try XCTUnwrap(full)
        let texSmall = try XCTUnwrap(small)
        XCTAssertNotIdentical(texFull, texSmall, "Different mip tiers must produce separate MTLTexture instances")
        XCTAssertGreaterThan(texFull.width, texSmall.width, "Full-res texture must be wider than the capped tier")
    }

    // MARK: - Single-flight concurrency

    func testConcurrentRequestsForSameKeyReturnSameInstance() async throws {
        let url = try writeMinimalUtex(named: "concurrent_test")
        let device = try XCTUnwrap(renderInfo.device)

        // Spin up 8 concurrent tasks that all request the same URL.
        // withTaskGroup collects results without any shared mutable state.
        let textures: [MTLTexture] = try await withThrowingTaskGroup(of: MTLTexture.self) { group in
            for _ in 0 ..< 8 {
                group.addTask {
                    let loader = try XCTUnwrap(NativeTextureLoader(device: device))
                    return try XCTUnwrap(loader.loadTexture(from: url), "Concurrent load must not return nil")
                }
            }
            var collected: [MTLTexture] = []
            for try await tex in group {
                collected.append(tex)
            }
            return collected
        }

        XCTAssertEqual(textures.count, 8, "All 8 concurrent loads must succeed")
        let first = try XCTUnwrap(textures.first)
        for (i, tex) in textures.enumerated() {
            XCTAssertIdentical(tex, first, "Load \(i) must return the same cached MTLTexture instance")
        }
    }

    // MARK: - Purge

    func testPurgeAllowsFreshLoad() throws {
        let url = try writeMinimalUtex(named: "purge_test")
        let before = try XCTUnwrap(loader.loadTexture(from: url))
        NativeTextureLoader.purgeSharedCache()
        let after = try XCTUnwrap(loader.loadTexture(from: url))
        XCTAssertNotIdentical(before, after, "After purge, the loader must allocate a new MTLTexture")
    }

    func testPurgeDoesNotHangWithNoCache() {
        // Should complete immediately without deadlock even on an empty cache.
        NativeTextureLoader.purgeSharedCache()
        NativeTextureLoader.purgeSharedCache()
    }

    // MARK: - Missing / bad file

    func testMissingFileReturnsNil() {
        let missing = tempDir.appendingPathComponent("does_not_exist.utex")
        let result = loader.loadTexture(from: missing)
        XCTAssertNil(result, "Loading a non-existent file must return nil, not crash")
    }

    func testCorruptFileReturnsNil() throws {
        let url = tempDir.appendingPathComponent("corrupt.utex")
        try Data([0xDE, 0xAD, 0xBE, 0xEF]).write(to: url)
        let result = loader.loadTexture(from: url)
        XCTAssertNil(result, "Loading a corrupt file must return nil, not crash")
    }

    func testFailedLoadReleasesInFlightSoSubsequentLoadSucceeds() throws {
        // Write a corrupt file at a URL, attempt to load it (clears in-flight on error),
        // then overwrite with a valid file and verify the second load succeeds.
        let url = tempDir.appendingPathComponent("recovery.utex")
        try Data([0x00]).write(to: url)
        _ = loader.loadTexture(from: url) // expected nil — also clears in-flight entry

        let valid = try makeMinimalUtexData(mipSizes: [4])
        try valid.write(to: url)
        NativeTextureLoader.purgeSharedCache() // clear the nil result (if any) from cache

        let result = loader.loadTexture(from: url)
        XCTAssertNotNil(result, "After a failed load clears in-flight, a subsequent valid load must succeed")
    }

    // MARK: - Key normalization

    func testStandardizedPathDeduplicatesEquivalentURLs() throws {
        let url = try writeMinimalUtex(named: "normalize_test")
        // Construct an equivalent URL with a redundant path component.
        var components = url.pathComponents
        components.insert(".", at: components.count - 1)
        let dotURL = try XCTUnwrap(NSURL.fileURL(withPathComponents: components))

        let t1 = loader.loadTexture(from: url)
        let t2 = loader.loadTexture(from: dotURL)
        let tex1 = try XCTUnwrap(t1)
        let tex2 = try XCTUnwrap(t2)
        XCTAssertIdentical(tex1, tex2, "Equivalent paths (with redundant components) must hit the same cache entry")
    }

    // MARK: - Texture properties

    func testLoadedTextureHasExpectedDimensions() throws {
        let url = try writeMinimalUtex(named: "dims_test", mipSizes: [64])
        let tex = try XCTUnwrap(loader.loadTexture(from: url))
        XCTAssertEqual(tex.width, 64)
        XCTAssertEqual(tex.height, 64)
    }

    func testTargetMaxDimensionSelectsCorrectMip() throws {
        // Build a 3-mip chain: 128, 64, 32. Requesting cap=64 must pick the 64-wide mip.
        let url = try writeMinimalUtex(named: "mip_select_test", mipSizes: [128, 64, 32])
        let tex = try XCTUnwrap(loader.loadTexture(from: url, targetMaxDimension: 64))
        XCTAssertLessThanOrEqual(tex.width, 64, "Requested cap=64 must not return a texture wider than 64px")
    }

    // MARK: - Fixture helpers

    /// Writes a minimal valid single-mip `.utex` file to the temp directory and returns its URL.
    private func writeMinimalUtex(named name: String, mipSizes: [Int] = [4]) throws -> URL {
        let data = try makeMinimalUtexData(mipSizes: mipSizes)
        let url = tempDir.appendingPathComponent("\(name).utex")
        try data.write(to: url)
        return url
    }

    /// Builds a minimal valid `.utex` container in memory.
    ///
    /// Each entry in `mipSizes` produces one mip level of that width (square).
    /// Payload bytes are zeroed ASTC blocks — valid as-is since ASTC is decoded
    /// on-GPU; the CPU only sees opaque 16-byte blocks.
    private func makeMinimalUtexData(mipSizes: [Int]) throws -> Data {
        // ASTC 4×4 sRGB — raw value 186 (MTLPixelFormat.astc_4x4_sRGB)
        let pixelFormat: UInt32 = 186
        let blockW: UInt8 = 4
        let blockH: UInt8 = 4

        // Build the mip table and compute payload sizes.
        struct MipInfo { let widthPx: UInt32; let heightPx: UInt32; let byteSize: UInt32 }
        let mipInfos: [MipInfo] = mipSizes.map { side in
            let blocks = max(1, (side + Int(blockW) - 1) / Int(blockW))
            let bytes = UInt32(blocks * blocks * 16)
            return MipInfo(widthPx: UInt32(side), heightPx: UInt32(side), byteSize: bytes)
        }

        let mipCount = UInt32(mipInfos.count)
        let payloadOffset = NativeTexFormat.payloadOffset(mipCount: Int(mipCount))
        let totalPayload = mipInfos.reduce(0) { $0 + $1.byteSize }

        let header = NativeTexHeader(
            flags: 0,
            width: mipInfos[0].widthPx,
            height: mipInfos[0].heightPx,
            mipCount: mipCount,
            pixelFormat: pixelFormat,
            blockWidth: blockW,
            blockHeight: blockH,
            payloadOffset: payloadOffset,
            totalPayloadSize: totalPayload
        )

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)

        var byteOffset: UInt32 = 0
        for mip in mipInfos {
            NativeTexMipEntry(
                byteOffset: byteOffset,
                byteSize: mip.byteSize,
                widthPx: mip.widthPx,
                heightPx: mip.heightPx
            ).encode(to: writer)
            byteOffset += mip.byteSize
        }

        // Zero-filled ASTC blocks (valid: GPU decodes them as opaque black).
        writer.writeData(Data(count: Int(totalPayload)))
        return writer.data
    }
}
