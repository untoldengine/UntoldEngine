//
//  XRFoveationTests.swift
//  UntoldEngine
//
//  Drawing through a rasterization rate map (visionOS foveation, XRFoveation.swift): the map's
//  parameter data the shaders decode, which pass descriptors carry the map and which do not,
//  and the occlusion cull sampling a pyramid drawn through a map where the map put the rect,
//  not where the rect's screen UV falls in the texture.
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
final class XRFoveationTests: BaseRenderSetup {
    private let screen = 256

    override func initializeAssets() {}

    override func tearDown() async throws {
        renderInfo.xrFoveation = nil
        applyXRFoveationToSceneRenderPassDescriptors()
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// A map over a 256-pixel-square screen whose right half is drawn at a quarter of the rate
    /// of its left half, so the physical texture is narrower than the screen and a screen
    /// position in the right half lands at a different texel than its UV says.
    private func makeRateMap() throws -> MTLRasterizationRateMap {
        let device = try XCTUnwrap(renderInfo.device)
        guard device.supportsRasterizationRateMap(layerCount: 1) else {
            throw XCTSkip("this GPU has no rasterization rate maps")
        }
        let descriptor = MTLRasterizationRateMapDescriptor(screenSize: MTLSize(width: screen, height: screen, depth: 1))
        let layer = MTLRasterizationRateLayerDescriptor(sampleCount: MTLSize(width: 2, height: 1, depth: 1))
        layer.horizontal[0] = 1.0
        layer.horizontal[1] = 0.25
        layer.vertical[0] = 1.0
        descriptor.setLayer(layer, at: 0)
        descriptor.label = "XRFoveationTests"
        return try XCTUnwrap(device.makeRasterizationRateMap(descriptor: descriptor))
    }

    private func makeRateMapData(_ rateMap: MTLRasterizationRateMap) throws -> XRRasterizationRateMapData {
        let device = try XCTUnwrap(renderInfo.device)
        let buffer = try XCTUnwrap(device.makeBuffer(length: rateMap.parameterDataSizeAndAlign.size, options: .storageModeShared))
        return try XCTUnwrap(XRRasterizationRateMapData(rateMap: rateMap, buffer: buffer))
    }

    // MARK: - Tests

    func testRateMapDataCarriesTheSizesAndParameters() throws {
        let rateMap = try makeRateMap()
        let data = try makeRateMapData(rateMap)

        let physical = rateMap.physicalSize(layer: 0)
        XCTAssertEqual(data.screenSize, simd_float2(Float(screen), Float(screen)))
        XCTAssertEqual(data.physicalSize, simd_float2(Float(physical.width), Float(physical.height)))
        XCTAssertLessThan(physical.width, screen, "a quarter-rate half narrows the physical texture")
        XCTAssertEqual(data.sizes, simd_float4(Float(screen), Float(screen), Float(physical.width), Float(physical.height)))
        XCTAssertEqual(rateMapSizes(nil), .zero, "the word the shaders read as 'no map'")

        let bytes = UnsafeRawBufferPointer(start: data.buffer.contents(), count: rateMap.parameterDataSizeAndAlign.size)
        XCTAssertTrue(bytes.contains { $0 != 0 }, "the map's parameters were copied")

        let short = try XCTUnwrap(renderInfo.device.makeBuffer(length: 4, options: .storageModeShared))
        XCTAssertNil(XRRasterizationRateMapData(rateMap: rateMap, buffer: short), "a buffer too short for the parameters is refused")
    }

    func testScenePassesCarryTheRateMapAndScreenPassesDoNot() throws {
        let rateMap = try makeRateMap()
        let data = try makeRateMapData(rateMap)
        let viewport = MTLViewport(originX: 0, originY: 0, width: Double(screen), height: Double(screen), znear: 0, zfar: 1)

        renderInfo.xrFoveation = XRFoveationFrame(rateMap: rateMap, viewport: viewport, rateMapData: data)
        applyXRFoveationToSceneRenderPassDescriptors()

        XCTAssertTrue(renderInfo.offscreenRenderPassDescriptor.rasterizationRateMap === rateMap, "the G-buffer + light pass draws through the map")
        XCTAssertTrue(renderInfo.deferredRenderPassDescriptor.rasterizationRateMap === rateMap, "transparency, wireframe and debug draw through the map")
        XCTAssertTrue(renderInfo.environmentRenderPassDescriptor.rasterizationRateMap === rateMap, "the background draws through the map")
        XCTAssertTrue(renderInfo.gaussianRenderPassDescriptor.rasterizationRateMap === rateMap, "the splats draw through the map")
        XCTAssertNil(renderInfo.sceneCompositeRenderPassDescriptor.rasterizationRateMap, "the composite copies physical pixels one to one")
        XCTAssertNil(renderInfo.ssaoRenderPassDescriptor.rasterizationRateMap, "SSAO reads the physical depth one to one")
        XCTAssertNil(renderInfo.postProcessRenderPassDescriptor?.rasterizationRateMap, "post-processing copies physical pixels one to one")

        renderInfo.xrFoveation = nil
        applyXRFoveationToSceneRenderPassDescriptors()
        XCTAssertNil(renderInfo.offscreenRenderPassDescriptor.rasterizationRateMap, "a uniform frame detaches the map")
        XCTAssertNil(renderInfo.deferredRenderPassDescriptor.rasterizationRateMap)
        XCTAssertNil(renderInfo.environmentRenderPassDescriptor.rasterizationRateMap)
        XCTAssertNil(renderInfo.gaussianRenderPassDescriptor.rasterizationRateMap)
    }

    /// A box in the right half of the screen, in front of a pyramid that holds an occluder only
    /// where the map put that half. Read where the box's screen UV falls in the texture, the
    /// pyramid shows background and the box is kept; moved through the map, the rect lies on
    /// the occluder and the box is dropped.
    func testOcclusionCullSamplesThePyramidWhereTheRateMapPutTheRect() throws {
        let rateMap = try makeRateMap()
        let data = try makeRateMapData(rateMap)
        let device = try XCTUnwrap(renderInfo.device)
        let physical = rateMap.physicalSize(layer: 0)

        // The box: NDC x in 0.5…0.9 — screen pixels 192…243 of 256 — a sliver of y, at depth 0.5.
        let box = VisibleEntity(center: simd_float4(0.7, 0, 0.5, 1), halfExtent: simd_float4(0.2, 0.05, 0, 0), index: 1, version: 1)
        // Where the rect's left edge lands in the texture by Metal's own mapping, against where
        // its screen UV (0.75) would be read without the map.
        let mappedMinX = rateMap.physicalCoordinates(screenCoordinates: MTLCoordinate2D(x: 192, y: 128), layer: 0).x
        let unmappedMinX = 0.75 * Float(physical.width)
        XCTAssertGreaterThan(mappedMinX, unmappedMinX + 2, "the quarter-rate half moves the rect to the right in the texture")

        // One mip: an occluder (0.9, near in reverse-Z) from just before the mapped rect to the
        // right edge, background (0) everywhere else.
        let occluderStart = max(0, Int(mappedMinX.rounded(.down)) - 1)
        let pyramidDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: physical.width, height: physical.height, mipmapped: false)
        pyramidDescriptor.usage = [.shaderRead]
        pyramidDescriptor.storageMode = .managed
        let pyramid = try XCTUnwrap(device.makeTexture(descriptor: pyramidDescriptor))
        var row = [Float](repeating: 0, count: physical.width)
        for x in occluderStart ..< physical.width {
            row[x] = 0.9
        }
        var texels = [Float]()
        texels.reserveCapacity(physical.width * physical.height)
        for _ in 0 ..< physical.height {
            texels.append(contentsOf: row)
        }
        texels.withUnsafeBytes { bytes in
            pyramid.replace(
                region: MTLRegionMake2D(0, 0, physical.width, physical.height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: physical.width * MemoryLayout<Float>.stride
            )
        }

        // The frame state the cull reads, restored afterwards.
        let savedViewPort = renderInfo.viewPort
        let savedValid = renderInfo.hzbIsValid
        let savedFrame = renderInfo.hzbFrame
        let savedMipCount = renderInfo.hzbMipCount
        let savedReverseZ = renderInfo.reverseZEnabled
        let savedPyramid = textureResources.hzbDepthPyramid
        defer {
            renderInfo.viewPort = savedViewPort
            renderInfo.hzbIsValid = savedValid
            renderInfo.hzbFrame = savedFrame
            renderInfo.hzbMipCount = savedMipCount
            renderInfo.reverseZEnabled = savedReverseZ
            textureResources.hzbDepthPyramid = savedPyramid
        }
        renderInfo.viewPort = simd_float2(Float(physical.width), Float(physical.height))
        renderInfo.hzbIsValid = true
        renderInfo.hzbMipCount = 1
        renderInfo.reverseZEnabled = true
        textureResources.hzbDepthPyramid = pyramid

        func survivors(rateMapData: XRRasterizationRateMapData?) throws -> Int {
            renderInfo.hzbFrame = HZBPyramidFrame(viewProjection: matrix_identity_float4x4, cameraPosition: .zero, rateMapData: rateMapData)
            var candidate = box
            var candidateCount: UInt32 = 1
            let inputVisibility = try XCTUnwrap(device.makeBuffer(bytes: &candidate, length: MemoryLayout<VisibleEntity>.stride, options: .storageModeShared))
            let inputCount = try XCTUnwrap(device.makeBuffer(bytes: &candidateCount, length: MemoryLayout<UInt32>.stride, options: .storageModeShared))
            let outputVisibility = try XCTUnwrap(device.makeBuffer(length: MemoryLayout<VisibleEntity>.stride, options: .storageModeShared))
            let outputCount = try XCTUnwrap(device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared))

            let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
            let ran = executeHZBOcclusionCulling(
                commandBuffer,
                cameraPosition: .zero,
                dispatchCount: 1,
                inputVisibilityBuffer: inputVisibility,
                inputVisibleCountBuffer: inputCount,
                outputVisibilityBuffer: outputVisibility,
                outputVisibleCountBuffer: outputCount
            )
            XCTAssertTrue(ran, "the pyramid is valid and the camera has not moved")
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return Int(outputCount.contents().load(as: UInt32.self))
        }

        XCTAssertEqual(try survivors(rateMapData: nil), 1, "read at its screen UV, the rect sees background and the box is kept")
        XCTAssertEqual(try survivors(rateMapData: data), 0, "moved through the map, the rect lies on the occluder and the box is dropped")
    }
}
