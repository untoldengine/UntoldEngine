//
//  TemporalAntiAliasingTests.swift
//  UntoldEngine
//
//  The temporal resolve (TemporalAntiAliasing.swift, TAAShader.metal): the jitter sequence,
//  the jitter going into and out of the projection, and the resolve of a still scene settling
//  to a stable image that stays close to the un-anti-aliased frame.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class TemporalAntiAliasingTests: BaseRenderSetup {
    private var camera: EntityID = 0
    private var savedMode: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        antiAliasingMode = savedMode
        TemporalAntiAliasing.shared.applyJitter()
        TemporalAntiAliasing.shared.invalidateHistory()
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        let box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
        let slab = createEntity()
        setEntityMeshDirect(entityId: slab, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Slab")
        scaleTo(entityId: slab, scale: simd_float3(4, 0.05, 0.05))
        translateTo(entityId: slab, position: simd_float3(0, 1.6, -1))
    }

    // MARK: - Helpers

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    /// The anti-aliasing output as floats, RGBA per pixel.
    private func readAntiAliasingOutput() throws -> [Float] {
        let texture = try XCTUnwrap(textureResources.antiAliasingTexture)
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    private func meanAbsoluteDifference(_ a: [Float], _ b: [Float]) -> Float {
        var total: Float = 0
        for i in 0 ..< min(a.count, b.count) {
            total += abs(a[i] - b[i])
        }
        return total / Float(max(1, min(a.count, b.count)))
    }

    // MARK: - Tests

    func testJitterSequenceIsSubPixelAndCentred() {
        XCTAssertEqual(taaJitterSequence.count, 8)
        var mean = simd_float2.zero
        for offset in taaJitterSequence {
            XCTAssertLessThanOrEqual(abs(offset.x), 0.5)
            XCTAssertLessThanOrEqual(abs(offset.y), 0.5)
            mean += offset
        }
        mean /= Float(taaJitterSequence.count)
        XCTAssertLessThan(abs(mean.x), 0.1, "the offsets average near the pixel centre")
        XCTAssertLessThan(abs(mean.y), 0.1)
        XCTAssertEqual(Set(taaJitterSequence.map { "\($0.x),\($0.y)" }).count, 8, "eight distinct offsets")
    }

    func testJitterGoesIntoAndOutOfTheProjection() {
        antiAliasingMode = .fxaa
        TemporalAntiAliasing.shared.applyJitter()
        let base = renderInfo.perspectiveSpace

        antiAliasingMode = .taa
        TemporalAntiAliasing.shared.applyJitter()
        let jittered = renderInfo.perspectiveSpace
        let pixels = TemporalAntiAliasing.shared.currentJitterPixels
        XCTAssertNotEqual(pixels, .zero)
        XCTAssertEqual(jittered.columns.2.x - base.columns.2.x, 2 * pixels.x / renderInfo.viewPort.x, accuracy: 1e-6)
        XCTAssertEqual(jittered.columns.2.y - base.columns.2.y, 2 * pixels.y / renderInfo.viewPort.y, accuracy: 1e-6)
        XCTAssertEqual(jittered.columns.0, base.columns.0)
        XCTAssertEqual(jittered.columns.1, base.columns.1)
        XCTAssertEqual(jittered.columns.3, base.columns.3)
        XCTAssertEqual(TemporalAntiAliasing.shared.unjitteredProjection, base, "the unjittered projection is the base one")

        TemporalAntiAliasing.shared.applyJitter()
        XCTAssertNotEqual(renderInfo.perspectiveSpace.columns.2.x, jittered.columns.2.x, "the next frame takes the next offset, not a sum")

        antiAliasingMode = .fxaa
        TemporalAntiAliasing.shared.applyJitter()
        XCTAssertEqual(renderInfo.perspectiveSpace, base, "leaving the temporal mode leaves the projection as it was")
    }

    /// A rate map over the window whose dense column sits at `denseColumn` of four; the
    /// three other columns are drawn at a quarter of the rate. Every column layout has the
    /// same physical size, as the compositor's gaze-following maps do.
    private func makeRateMap(denseColumn: Int) throws -> MTLRasterizationRateMap {
        let device = try XCTUnwrap(renderInfo.device)
        guard device.supportsRasterizationRateMap(layerCount: 1) else {
            throw XCTSkip("this GPU has no rasterization rate maps")
        }
        let descriptor = MTLRasterizationRateMapDescriptor(screenSize: MTLSize(width: windowWidth, height: windowHeight, depth: 1))
        let layer = MTLRasterizationRateLayerDescriptor(sampleCount: MTLSize(width: 4, height: 1, depth: 1))
        for column in 0 ..< 4 {
            layer.horizontal[column] = column == denseColumn ? 1.0 : 0.25
        }
        layer.vertical[0] = 1.0
        descriptor.setLayer(layer, at: 0)
        return try XCTUnwrap(device.makeRasterizationRateMap(descriptor: descriptor))
    }

    private func makeFoveationFrame(_ rateMap: MTLRasterizationRateMap) throws -> XRFoveationFrame {
        let device = try XCTUnwrap(renderInfo.device)
        let buffer = try XCTUnwrap(device.makeBuffer(length: rateMap.parameterDataSizeAndAlign.size, options: .storageModeShared))
        let data = try XCTUnwrap(XRRasterizationRateMapData(rateMap: rateMap, buffer: buffer))
        let viewport = MTLViewport(originX: 0, originY: 0, width: Double(windowWidth), height: Double(windowHeight), znear: 0, zfar: 1)
        return XRFoveationFrame(rateMap: rateMap, viewport: viewport, rateMapData: data)
    }

    /// Reads a physical-size texture of the look format as floats.
    private func readFloats(_ texture: MTLTexture) -> [Float] {
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    /// The headset's situation: a still scene drawn through a rate map whose dense zone moves
    /// every frame, as a gaze-following map does. The history of each frame is laid out in the
    /// previous map's physical space; reprojected through both maps it must land where this
    /// frame's map puts the same point, or the resolve shows the scene with a displaced copy.
    func testResolveStaysStableWhileTheRateMapsDenseZoneMoves() throws {
        let maps = try [makeRateMap(denseColumn: 0), makeRateMap(denseColumn: 3)]
        let physical = maps[0].physicalSize(layer: 0)
        guard physical.width == maps[1].physicalSize(layer: 0).width, physical.height == maps[1].physicalSize(layer: 0).height else {
            throw XCTSkip("the two layouts got different physical sizes on this GPU")
        }
        XCTAssertLessThan(physical.width, windowWidth, "three quarter-rate columns narrow the texture")
        let frames = try maps.map { try makeFoveationFrame($0) }

        // Draw into textures of the physical size, through the maps, like a foveated eye.
        let savedViewPort = renderInfo.viewPort
        defer {
            renderInfo.xrFoveation = nil
            renderInfo.viewPort = savedViewPort
            renderer.initSizeableResources()
            TemporalAntiAliasing.shared.invalidateHistory()
        }
        renderInfo.viewPort = simd_float2(Float(physical.width), Float(physical.height))
        renderer.initSizeableResources()

        // The single-sample frame in the first map's layout.
        antiAliasingMode = .none
        renderInfo.xrFoveation = frames[0]
        for _ in 0 ..< 2 {
            drawFrame()
        }
        let single = try readFloats(XCTUnwrap(textureResources.lookTexture))
        XCTAssertGreaterThan(single.max() ?? 0, 0.01, "the scene draws something through the map")

        // The same frame in the second layout differs a lot from the first: the test can tell
        // the layouts apart, so a history mapped through the wrong one would be caught.
        renderInfo.xrFoveation = frames[1]
        drawFrame()
        let singleOther = try readFloats(XCTUnwrap(textureResources.lookTexture))
        let layoutDifference = meanAbsoluteDifference(single, singleOther)
        XCTAssertGreaterThan(layoutDifference, 0.002, "the two layouts place the scene differently in the texture")

        // Temporal, with the dense zone jumping every frame, ending on the first layout.
        antiAliasingMode = .taa
        TemporalAntiAliasing.shared.invalidateHistory()
        for frame in 0 ..< 12 {
            renderInfo.xrFoveation = frames[(frame + 1) % 2]
            drawFrame()
        }
        let resolved = try readFloats(XCTUnwrap(textureResources.antiAliasingTexture))

        // The floor: the resolve of the first layout held still differs from the single-sample
        // frame by the jitter's averaging and the history filter alone.
        TemporalAntiAliasing.shared.invalidateHistory()
        renderInfo.xrFoveation = frames[0]
        for _ in 0 ..< 12 {
            drawFrame()
        }
        let still = try readFloats(XCTUnwrap(textureResources.antiAliasingTexture))
        let floor = meanAbsoluteDifference(still, single)

        XCTAssertFalse(resolved.contains { $0.isNaN || $0.isInfinite })
        let resolveDifference = meanAbsoluteDifference(resolved, single)
        print("TAA moving-map test: resolve differs from the single-sample frame by \(resolveDifference), held still by \(floor), the other layout by \(layoutDifference)")
        XCTAssertLessThan(resolveDifference, floor + 0.1 * layoutDifference, "the history reprojected through the moving maps lands where this frame's map puts the scene: resolve differs by \(resolveDifference), held still by \(floor), the other layout by \(layoutDifference)")
    }

    /// A camera that moves a little every frame, as a head does: the history is reprojected
    /// through the depth buffer and the two view-projections, and the resolve at the final
    /// pose must match the single-sample frame at that pose rather than drag the earlier poses
    /// along as a shadow.
    func testResolveFollowsAMovingCameraWithoutAShadow() throws {
        func pose(_ frame: Int) -> simd_float3 {
            simd_float3(0.03 * Float(frame), 1 + 0.01 * Float(frame), 4 - 0.02 * Float(frame))
        }
        let frameCount = 12

        antiAliasingMode = .none
        cameraLookAt(entityId: camera, eye: pose(0), target: .zero, up: simd_float3(0, 1, 0))
        drawFrame()
        drawFrame()
        let first = try readFloats(XCTUnwrap(textureResources.lookTexture))
        cameraLookAt(entityId: camera, eye: pose(frameCount - 1), target: .zero, up: simd_float3(0, 1, 0))
        drawFrame()
        drawFrame()
        let last = try readFloats(XCTUnwrap(textureResources.lookTexture))
        let motion = meanAbsoluteDifference(first, last)
        XCTAssertGreaterThan(motion, 0.002, "the camera's path moves the scene in the frame")

        for mode in [AntiAliasingMode.taa, .msaaTaa] {
            antiAliasingMode = mode
            TemporalAntiAliasing.shared.invalidateHistory()
            for frame in 0 ..< frameCount {
                cameraLookAt(entityId: camera, eye: pose(frame), target: .zero, up: simd_float3(0, 1, 0))
                drawFrame()
            }
            let moved = try readAntiAliasingOutput()
            TemporalAntiAliasing.shared.invalidateHistory()
            for _ in 0 ..< frameCount {
                drawFrame()
            }
            let held = try readAntiAliasingOutput()
            print("TAA moving-camera \(mode): resolve differs from the final pose's frame by \(meanAbsoluteDifference(moved, last)), held still by \(meanAbsoluteDifference(held, last)), the first pose by \(motion)")
        }

        antiAliasingMode = .taa
        TemporalAntiAliasing.shared.invalidateHistory()
        for frame in 0 ..< frameCount {
            cameraLookAt(entityId: camera, eye: pose(frame), target: .zero, up: simd_float3(0, 1, 0))
            drawFrame()
        }
        let resolved = try readAntiAliasingOutput()
        let shadow = meanAbsoluteDifference(resolved, last)

        // The floor: the resolve held still at the final pose.
        TemporalAntiAliasing.shared.invalidateHistory()
        for _ in 0 ..< frameCount {
            drawFrame()
        }
        let stillResolved = try readAntiAliasingOutput()
        let floor = meanAbsoluteDifference(stillResolved, last)
        print("TAA moving-camera test: resolve differs from the final pose's frame by \(shadow), held still by \(floor), the first pose by \(motion)")
        if let dump = ProcessInfo.processInfo.environment["UNTOLD_TAA_DUMP"] {
            let texture = try XCTUnwrap(textureResources.antiAliasingTexture)
            for (name, pixels) in [("single", last), ("moving", resolved), ("still", stillResolved)] {
                let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
                try data.write(to: URL(fileURLWithPath: dump).appendingPathComponent("\(name)_\(texture.width)x\(texture.height).f32"))
            }
        }
        XCTAssertLessThan(shadow, floor + 0.1 * motion, "the resolve follows the camera: it differs from the final pose's frame by \(shadow), held still by \(floor), the first pose differs by \(motion)")
    }

    func testResolveSettlesOnAStillSceneCloseToTheSingleSampleFrame() throws {
        antiAliasingMode = .none
        for _ in 0 ..< 2 {
            drawFrame()
        }
        // The look output is what the output pass shows without a post-look pass.
        let lookTexture = try XCTUnwrap(textureResources.lookTexture)
        var reference = [UInt16](repeating: 0, count: lookTexture.width * lookTexture.height * 4)
        reference.withUnsafeMutableBytes { bytes in
            lookTexture.getBytes(bytes.baseAddress!, bytesPerRow: lookTexture.width * 8, from: MTLRegionMake2D(0, 0, lookTexture.width, lookTexture.height), mipmapLevel: 0)
        }
        let single = reference.map { Float(Float16(bitPattern: $0)) }
        XCTAssertGreaterThan(single.max() ?? 0, 0.01, "the scene draws something")

        antiAliasingMode = .taa
        TemporalAntiAliasing.shared.invalidateHistory()
        for _ in 0 ..< 10 {
            drawFrame()
        }
        let settled = try readAntiAliasingOutput()
        drawFrame()
        let next = try readAntiAliasingOutput()

        XCTAssertFalse(settled.contains { $0.isNaN || $0.isInfinite }, "no NaN or infinity in the resolve")
        print("TAA still test: frame to frame \(meanAbsoluteDifference(settled, next)), resolve vs single-sample \(meanAbsoluteDifference(settled, single))")
        XCTAssertLessThan(meanAbsoluteDifference(settled, next), 0.004, "a still scene no longer changes between frames")
        XCTAssertLessThan(meanAbsoluteDifference(settled, single), 0.02, "the resolve stays close to the single-sample frame: no drift, no smear")
        XCTAssertGreaterThan(meanAbsoluteDifference(settled, single), 0, "and is not the single-sample frame")
    }
}
