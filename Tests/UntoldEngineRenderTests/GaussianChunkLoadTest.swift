//
//  GaussianChunkLoadTest.swift
//  UntoldEngine
//
//  The .untoldgs v3 GPU load path: chunks read by range into the resident packed
//  buffer the fused per-chunk pass decodes every frame, with the chunk table beside
//  it and no encoded or per-slot index buffers. The gaussianDecodeChunks kernel that
//  expands the same records for the whole-buffer path is verified against the CPU
//  decode of the same file.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class GaussianChunkLoadTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        destroyAllEntities()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    private func testPLYURL() throws -> URL {
        try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
    }

    private func bakeV3(chunkSplats log2: UInt8 = 8) throws -> URL {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianChunkLoadTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = log2
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: testPLYURL(), outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        let url = try XCTUnwrap(result.tiers.first?.url)
        temporaryFiles.append(url)
        return url
    }

    func testDecodePipelineIsAvailable() {
        XCTAssertTrue(gaussianDecodePipeline.success, "gaussianDecodeChunks must compile into the engine metallib")
        XCTAssertTrue(GaussianChunkLoader.isAvailable)
    }

    func testGPUDecodeMatchesCPUDecode() throws {
        // The fixture is small; 16 splats per chunk makes it span many chunks.
        let url = try bakeV3(chunkSplats: 4)
        let cpu = try UntoldGSFormat.read(from: url)
        let gpu = try GaussianChunkLoader.load(url: url)

        XCTAssertEqual(gpu.splatCount, cpu.splatCount)
        XCTAssertGreaterThan(gpu.index.chunks.count, 1, "the fixture should span several chunks")
        XCTAssertEqual(gpu.boundingBox.min, cpu.boundingBoxMin)
        XCTAssertEqual(gpu.boundingBox.max, cpu.boundingBoxMax)
        XCTAssertEqual(gpu.meanSquaredSplatExtent, cpu.meanSquaredSplatExtent)
        XCTAssertEqual(gpu.sphericalHarmonicsMetadata?.degree, cpu.shMetadata?.degree)

        XCTAssertEqual(gpu.packedSplatBuffer.length, gpu.splatCount * UntoldGSFormat.coreRecordSize, "the 16-byte records stay resident as read")

        let count = gpu.splatCount
        let encodedSplatBuffer = try GaussianChunkLoader.decodeEncodedSplats(gpu)
        XCTAssertEqual(encodedSplatBuffer.length, count * MemoryLayout<EncodedGaussianSplat>.stride)
        let decoded = UnsafeBufferPointer(start: encodedSplatBuffer.contents().bindMemory(to: EncodedGaussianSplat.self, capacity: count), count: count)
        var maxCovarianceError: Float = 0
        for (index, reference) in cpu.encodedSplats.enumerated() {
            let splat = decoded[index]
            XCTAssertEqual(splat.position.x, reference.position.x, accuracy: 1e-5)
            XCTAssertEqual(splat.position.y, reference.position.y, accuracy: 1e-5)
            XCTAssertEqual(splat.position.z, reference.position.z, accuracy: 1e-5)
            for (a, b) in [(splat.covA.x, reference.covA.x), (splat.covA.y, reference.covA.y), (splat.covA.z, reference.covA.z),
                           (splat.covB.x, reference.covB.x), (splat.covB.y, reference.covB.y), (splat.covB.z, reference.covB.z)]
            {
                let scale = max(abs(Float(b)), 1e-4)
                maxCovarianceError = max(maxCovarianceError, abs(Float(a) - Float(b)) / scale)
            }
            XCTAssertEqual(Float(splat.colorAndOpacity.x), Float(reference.colorAndOpacity.x), accuracy: 2e-3)
            XCTAssertEqual(Float(splat.colorAndOpacity.w), Float(reference.colorAndOpacity.w), accuracy: 2e-3)
        }
        // Half-precision covariance from two independent float pipelines: allow a few ulps of half.
        XCTAssertLessThan(maxCovarianceError, 0.02, "covariance relative error \(maxCovarianceError)")

        if let shBuffer = gpu.sphericalHarmonicsBuffer {
            let bytes = Array(UnsafeBufferPointer(start: shBuffer.contents().bindMemory(to: UInt8.self, capacity: shBuffer.length), count: shBuffer.length))
            XCTAssertEqual(bytes, cpu.shCoefficients, "SH bytes are bound as stored")
        } else {
            XCTAssertTrue(cpu.shCoefficients.isEmpty)
        }
    }

    func testSetEntityGaussianLoadsASingleUntoldgsFile() throws {
        let url = try bakeV3()
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")

        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let expected = try UntoldGSFormat.readHeaderV3(from: url)
        XCTAssertEqual(component.splatCount, UInt(expected.splatCount))
        XCTAssertTrue(component.isChunked, "a .untoldgs load takes the per-chunk path")
        XCTAssertNil(component.encodedSplatData, "no 48-byte encoded buffer is kept for a chunked entity")
        XCTAssertEqual(component.packedSplatData?.length, Int(expected.splatCount) * UntoldGSFormat.coreRecordSize)
        XCTAssertTrue(component.gaussianVisibleIndices.isEmpty, "no per-slot visible-index buffers either")
        XCTAssertTrue(component.gaussianVisibleCount.isEmpty)
        XCTAssertEqual(component.chunkTable?.visibleChunks.count, maxInFlightCommandBuffers)
        let local = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity))
        XCTAssertEqual(local.boundingBox.min, expected.boundingBoxMin)
        XCTAssertEqual(local.boundingBox.max, expected.boundingBoxMax)
        XCTAssertNotNil(MemoryBudgetManager.shared.getMemorySize(for: entity))

        // The loaded entity renders through the unchanged cull/sort/draw path.
        renderer.draw(in: renderer.metalView)
    }

    func testProgressiveTierLoadUsesTheGPUPath() throws {
        let url = try bakeV3(chunkSplats: 9)
        let built = try XCTUnwrap(buildGaussianComponentFromUntoldGS(url: url))
        let header = try UntoldGSFormat.readHeaderV3(from: url)
        XCTAssertEqual(built.component.splatCount, UInt(header.splatCount))
        XCTAssertEqual(built.meanSquaredSplatExtent, header.meanSquaredSplatExtent)
        XCTAssertEqual(built.boundingBox.min, header.boundingBoxMin)
        let table = try XCTUnwrap(built.component.chunkTable)
        XCTAssertEqual(
            built.estimatedGPUBytes,
            Int(header.splatCount) * UntoldGSFormat.coreRecordSize + (built.component.sphericalHarmonicsData?.length ?? 0) + table.gpuBytes,
            "a chunked tier costs its packed records, its harmonics and its chunk table"
        )
        XCTAssertLessThan(built.estimatedGPUBytes, Int(header.splatCount) * MemoryLayout<EncodedGaussianSplat>.stride, "far less than the 48-byte encoded records alone")
    }

    func testCorruptedFileFailsTheLoad() throws {
        let url = try bakeV3()
        var data = try Data(contentsOf: url)
        let index = try UntoldGSFormat.readIndex(from: data)
        data[Int(index.chunks[0].payloadOffset) + 3] ^= 0xFF
        try data.write(to: url)
        XCTAssertThrowsError(try GaussianChunkLoader.load(url: url))
        XCTAssertNil(buildGaussianLoadResultFromUntoldGS(url: url))
    }
}
