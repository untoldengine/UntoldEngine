//
//  GaussianChunkLoadTest.swift
//  UntoldEngine
//
//  The .untoldgs v3 GPU load path: chunks read by range, decoded by the
//  gaussianDecodeChunks kernel, and bound to the same buffers the renderer
//  consumes. Verified against the CPU decode of the same file.
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

        let count = gpu.splatCount
        let decoded = UnsafeBufferPointer(start: gpu.encodedSplatBuffer.contents().bindMemory(to: EncodedGaussianSplat.self, capacity: count), count: count)
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
        XCTAssertNotNil(component.encodedSplatData)
        XCTAssertEqual(component.encodedSplatData?.length, Int(expected.splatCount) * MemoryLayout<EncodedGaussianSplat>.stride)
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
        XCTAssertGreaterThan(built.estimatedGPUBytes, Int(header.splatCount) * MemoryLayout<EncodedGaussianSplat>.stride)
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
