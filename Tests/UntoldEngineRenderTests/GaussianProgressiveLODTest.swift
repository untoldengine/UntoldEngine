//
//  GaussianProgressiveLODTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class GaussianProgressiveLODTest: BaseRenderSetup {
    private var savedLODUpdateFrameInterval = 1
    private var savedMinimumEntityDisplacementForLODUpdate: Float = 0.5
    private var savedMinimumCameraDisplacementForLODUpdate: Float = 0.5
    private var savedGaussianOverdrawBudget: Float = 12.0
    private var savedHysteresis: Float = 5.0

    override func setUp() async throws {
        try await super.setUp()
        savedLODUpdateFrameInterval = LODConfig.shared.lodUpdateFrameInterval
        savedMinimumEntityDisplacementForLODUpdate = LODConfig.shared.minimumEntityDisplacementForLODUpdate
        savedMinimumCameraDisplacementForLODUpdate = LODConfig.shared.minimumCameraDisplacementForLODUpdate
        savedGaussianOverdrawBudget = LODConfig.shared.gaussianOverdrawBudget
        savedHysteresis = LODConfig.shared.hysteresis
        LODConfig.shared.lodUpdateFrameInterval = 1
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0
        GeometryStreamingSystem.shared.enableFrustumGate = false
        GeometryStreamingSystem.shared.maxQueryRadius = 500
        MemoryBudgetManager.shared.clear()
        GaussianLODSystem.shared.reset()
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.updateInterval = 0.1
        GeometryStreamingSystem.shared.enableFrustumGate = true
        LODConfig.shared.lodUpdateFrameInterval = savedLODUpdateFrameInterval
        LODConfig.shared.minimumEntityDisplacementForLODUpdate = savedMinimumEntityDisplacementForLODUpdate
        LODConfig.shared.minimumCameraDisplacementForLODUpdate = savedMinimumCameraDisplacementForLODUpdate
        LODConfig.shared.gaussianOverdrawBudget = savedGaussianOverdrawBudget
        LODConfig.shared.hysteresis = savedHysteresis
        MemoryBudgetManager.shared.clear()
        GaussianLODSystem.shared.reset()
        try await super.tearDown()
    }

    private func testPLYURL() throws -> URL {
        try XCTUnwrap(
            LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil)
        )
    }

    private func makeContainingTile() -> EntityID {
        let tile = createEntity()
        scene.assign(to: tile, component: TileComponent.self)?.state = .parsed
        scene.get(component: LocalTransformComponent.self, for: tile)?.boundingBox = (
            min: simd_float3(-500, -500, -500),
            max: simd_float3(500, 500, 500)
        )
        OctreeSystem.shared.registerEntity(tile)
        return tile
    }

    private func bakeProgressiveBase(levelCount: Int) throws -> String {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianProgressiveLODTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        _ = try bakeGaussianSplatProgressiveTiers(
            plyURL: try testPLYURL(),
            outputBaseURL: output,
            levelCount: levelCount
        )
        return output.deletingPathExtension().path
    }

    func testBakeProgressiveTiersWritesNestedCounts() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianProgressiveBake-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        let bakeResult = try bakeGaussianSplatProgressiveTiers(
            plyURL: try testPLYURL(),
            outputBaseURL: output,
            levelCount: 3
        )

        let tiers = try bakeResult.tiers.map { try UntoldGSFormat.read(from: $0.url) }
        XCTAssertEqual(tiers.count, 3)
        XCTAssertGreaterThan(tiers[0].splatCount, tiers[1].splatCount)
        XCTAssertGreaterThan(tiers[1].splatCount, tiers[2].splatCount)
    }

    func testBakeProgressiveTiersPreservesSpatialCoverageInCoarseTier() throws {
        let ply = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianSpatialCoverage-\(UUID().uuidString)")
            .appendingPathExtension("ply")
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianSpatialCoverage-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")

        let lines = [
            "ply",
            "format ascii 1.0",
            "element vertex 8",
            "property float x",
            "property float y",
            "property float z",
            "property float scale_0",
            "property float scale_1",
            "property float scale_2",
            "property float f_dc_0",
            "property float f_dc_1",
            "property float f_dc_2",
            "property float opacity",
            "property float rot_0",
            "property float rot_1",
            "property float rot_2",
            "property float rot_3",
            "end_header",
            "0 0 0 0 0 0 0 0 0 5 1 0 0 0",
            "0 1 0 0 0 0 0 0 0 5 1 0 0 0",
            "0 2 0 0 0 0 0 0 0 5 1 0 0 0",
            "0 3 0 0 0 0 0 0 0 5 1 0 0 0",
            "0 4 0 0 0 0 0 0 0 5 1 0 0 0",
            "0 5 0 0 0 0 0 0 0 5 1 0 0 0",
            "10 0 0 -4 -4 -4 0 0 0 -4 1 0 0 0",
            "10 1 0 -4 -4 -4 0 0 0 -4 1 0 0 0",
        ]
        try lines.joined(separator: "\n").write(to: ply, atomically: true, encoding: .utf8)

        let bakeResult = try bakeGaussianSplatProgressiveTiers(
            plyURL: ply,
            outputBaseURL: output,
            lodFractions: [1.0, 0.25]
        )
        let coarse = try UntoldGSFormat.read(from: bakeResult.tiers[1].url)
        XCTAssertEqual(coarse.splatCount, 2)

        let xs = coarse.encodedSplats.map { $0.position.x }
        XCTAssertTrue(xs.contains { $0 < 1 }, "Coarse tier should keep coverage from the dense left cluster")
        XCTAssertTrue(xs.contains { $0 > 9 }, "Coarse tier should keep coverage from the sparse right cluster")
    }

    func testProgressiveStreamingLoadsCoarsestFirstThenRefinesOnDemand() async throws {
        _ = makeContainingTile()
        let base = try bakeProgressiveBase(levelCount: 3)

        let entity = createEntity()
        translateTo(entityId: entity, position: .zero)
        setEntityGaussianStreaming(
            entityId: entity,
            source: .progressive(
                baseFilename: base,
                levelCount: 3,
                maxDistances: [20, 50, .greatestFiniteMagnitude]
            ),
            options: GaussianStreamingOptions(
                streamingRadius: 200,
                unloadRadius: 300,
                boundingBoxHalfExtent: simd_float3(1, 1, 1)
            )
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.1)
        await scene.get(component: StreamingComponent.self, for: entity)?.loadTask?.value

        let lod = try XCTUnwrap(scene.get(component: GaussianLODComponent.self, for: entity))
        XCTAssertEqual(lod.currentLOD, 2)
        XCTAssertEqual(lod.lodLevels[2].residencyState, .resident)
        XCTAssertEqual(lod.lodLevels[1].residencyState, .unknown)
        XCTAssertEqual(lod.lodLevels[0].residencyState, .unknown)

        let coarseCount = try XCTUnwrap(lod.lodLevels[2].buffers?.splatCount)
        XCTAssertEqual(scene.get(component: GaussianComponent.self, for: entity)?.splatCount, coarseCount)

        let camera = createEntity()
        scene.assign(to: camera, component: CameraComponent.self)?.localPosition = .zero
        _ = scene.assign(to: camera, component: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = camera

        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[0].loadTask?.value
        GaussianLODSystem.shared.update(deltaTime: 0.1)

        XCTAssertEqual(lod.lodLevels[0].residencyState, .resident)
        XCTAssertEqual(lod.currentLOD, 0)
        XCTAssertEqual(scene.get(component: GaussianComponent.self, for: entity)?.splatCount, lod.lodLevels[0].buffers?.splatCount)
    }

    func testProgressiveGaussianDoesNotRequireTileStreaming() async throws {
        let base = try bakeProgressiveBase(levelCount: 3)

        let entity = createEntity()
        translateTo(entityId: entity, position: .zero)
        setEntityGaussian(
            entityId: entity,
            source: .progressive(
                baseFilename: base,
                levelCount: 3,
                maxDistances: [20, 50, .greatestFiniteMagnitude]
            )
        )

        let lod = try XCTUnwrap(scene.get(component: GaussianLODComponent.self, for: entity))
        XCTAssertNil(scene.get(component: StreamingComponent.self, for: entity))

        for _ in 0 ..< 20 where lod.currentLOD != 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(lod.currentLOD, 2)
        XCTAssertEqual(lod.lodLevels[2].residencyState, .resident)
        XCTAssertEqual(scene.get(component: GaussianComponent.self, for: entity)?.splatCount, lod.lodLevels[2].buffers?.splatCount)

        let camera = createEntity()
        scene.assign(to: camera, component: CameraComponent.self)?.localPosition = .zero
        _ = scene.assign(to: camera, component: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = camera

        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[0].loadTask?.value
        GaussianLODSystem.shared.update(deltaTime: 0.1)

        XCTAssertEqual(lod.lodLevels[0].residencyState, .resident)
        XCTAssertEqual(lod.currentLOD, 0)
        XCTAssertEqual(scene.get(component: GaussianComponent.self, for: entity)?.splatCount, lod.lodLevels[0].buffers?.splatCount)
    }

    func testBakeProgressiveTiersReturnsAssetLevelBoundingBox() throws {
        let asset = try PLYReader.readGaussianAsset(from: try testPLYURL())
        let expected = computeGaussianSplatBoundingBox(asset.splats)

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianBakeBoundingBox-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        let bakeResult = try bakeGaussianSplatProgressiveTiers(
            plyURL: try testPLYURL(),
            outputBaseURL: output,
            levelCount: 3
        )

        // The box must reflect the full source asset, not just the coarsest (most-subsetted) tier.
        XCTAssertEqual(bakeResult.boundingBoxMin, expected.min)
        XCTAssertEqual(bakeResult.boundingBoxMax, expected.max)
    }

    func testSetEntityGaussianAutoComputesBoundingBox() throws {
        // setEntityGaussian's auto-computed box goes through buildGaussianLoadResult, which
        // only has post-encode splat positions (no per-splat scale) -- it pads a centers-only
        // box by an RMS radius derived from the mean squared extent, rather than the exact
        // per-splat expansion computeGaussianSplatBoundingBox(_ splats:) does at bake time.
        let asset = try PLYReader.readGaussianAsset(from: try testPLYURL())
        let allIndices = Array(asset.splats.indices)
        let positions = asset.splats.map { simd_float3($0.center.x, $0.center.y, $0.center.z) }
        let extentSum = allIndices.reduce(Float(0)) { partial, index in
            let majorAxis = gaussianMajorAxis(asset.splats[index])
            return partial + majorAxis * majorAxis
        }
        let meanSquaredExtent = extentSum / Float(allIndices.count)
        let expected = computeGaussianSplatPositionBoundingBox(positions, padding: sqrt(meanSquaredExtent))

        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")

        let boundingBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)?.boundingBox)
        XCTAssertNotEqual(boundingBox.min, boundingBox.max, "Bounding box should not collapse to a single point")
        XCTAssertEqual(boundingBox.min, expected.min)
        XCTAssertEqual(boundingBox.max, expected.max)
    }

    func testMeanSquaredSplatExtentRoundTripsThroughUntoldGSFile() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianMeanSquaredExtentRoundTrip-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        let bakeResult = try bakeGaussianSplatProgressiveTiers(
            plyURL: try testPLYURL(),
            outputBaseURL: output,
            levelCount: 3
        )

        for tier in bakeResult.tiers {
            let readBack = try UntoldGSFormat.read(from: tier.url)
            XCTAssertGreaterThan(tier.meanSquaredSplatExtent, 0, "bake-time stat should be a real, non-degenerate value for a real asset")
            XCTAssertEqual(readBack.meanSquaredSplatExtent, tier.meanSquaredSplatExtent, "the value baked into the file must match what bakeGaussianSplatProgressiveTiers reported")
        }
    }

    func testProgressiveTierAutoPopulatesMeanSquaredSplatExtentOnLoad() async throws {
        let base = try bakeProgressiveBase(levelCount: 3)

        let entity = createEntity()
        translateTo(entityId: entity, position: .zero)
        setEntityGaussianProgressive(
            entityId: entity,
            baseFilename: base,
            levelCount: 3,
            maxDistances: [20, 50, .greatestFiniteMagnitude]
        )

        let lod = try XCTUnwrap(scene.get(component: GaussianLODComponent.self, for: entity))

        // Nothing was passed by the caller -- before the coarsest tier's async load completes,
        // its stat is unknown.
        XCTAssertNil(lod.lodLevels[2].meanSquaredSplatExtent)

        for _ in 0 ..< 20 where lod.currentLOD != 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Auto-populated from the .untoldgs file itself once it's actually read -- no caller
        // input required.
        let loadedExtent = try XCTUnwrap(lod.lodLevels[2].meanSquaredSplatExtent)
        XCTAssertGreaterThan(loadedExtent, 0)
    }

    // MARK: - Overdraw-aware LOD clamping

    func testEstimatedGaussianOverdrawMatchesHandComputedFormula() {
        // distance=10, fovY=90deg (tanHalfFovY=1), viewportHeight=1000 ->
        // projectionScaleFactor = 1000 / (2 * 1 * 10) = 50
        let overdraw = estimatedGaussianOverdraw(
            splatCount: 100,
            meanSquaredSplatExtent: 0.04,
            distance: 10,
            fovY: .pi / 2,
            viewportHeight: 1000,
            boundingRadius: 2
        )
        // projectedAreaPerSplat = 50^2 * 0.04 = 100
        // footprintRadius = 2 * 50 = 100 -> area = pi * 100^2 = pi * 10000
        // overdraw = (100 * 100) / (pi * 10000) = 10000 / (pi * 10000) = 1/pi
        XCTAssertEqual(overdraw, 1 / Float.pi, accuracy: 0.0001)
    }

    func testEstimatedGaussianOverdrawIsZeroForDegenerateInputs() {
        XCTAssertEqual(estimatedGaussianOverdraw(splatCount: 0, meanSquaredSplatExtent: 1, distance: 10, fovY: 1, viewportHeight: 1000, boundingRadius: 1), 0)
        XCTAssertEqual(estimatedGaussianOverdraw(splatCount: 100, meanSquaredSplatExtent: 1, distance: 0, fovY: 1, viewportHeight: 1000, boundingRadius: 1), 0)
        XCTAssertEqual(estimatedGaussianOverdraw(splatCount: 100, meanSquaredSplatExtent: 1, distance: 10, fovY: 1, viewportHeight: 1000, boundingRadius: 0), 0)
    }

    func testClampGaussianLODForOverdrawWalksToCoarserTierWhenOverBudget() {
        let lodComponent = GaussianLODComponent()
        var level0 = GaussianLODLevel(maxDistance: 20)
        level0.meanSquaredSplatExtent = 1.0
        level0.buffers = GaussianComponent()
        level0.buffers?.splatCount = 1_000_000 // deliberately huge -> massive overdraw at any sane distance

        var level1 = GaussianLODLevel(maxDistance: 50)
        level1.meanSquaredSplatExtent = 0.0001
        level1.buffers = GaussianComponent()
        level1.buffers?.splatCount = 10 // tiny -> comfortably under budget

        lodComponent.lodLevels = [level0, level1]

        let clamped = clampGaussianLODForOverdraw(
            desiredLOD: 0,
            lodComponent: lodComponent,
            distance: 10,
            fovY: .pi / 2,
            viewportHeight: 1000,
            boundingRadius: 2,
            budget: 12.0
        )
        XCTAssertEqual(clamped, 1)
    }

    func testClampGaussianLODForOverdrawIsNoOpWithoutBakedStats() {
        let lodComponent = GaussianLODComponent()
        var level0 = GaussianLODLevel(maxDistance: 20)
        level0.buffers = GaussianComponent()
        level0.buffers?.splatCount = 1_000_000 // huge, but no meanSquaredSplatExtent supplied

        lodComponent.lodLevels = [level0]

        let clamped = clampGaussianLODForOverdraw(
            desiredLOD: 0,
            lodComponent: lodComponent,
            distance: 10,
            fovY: .pi / 2,
            viewportHeight: 1000,
            boundingRadius: 2,
            budget: 12.0
        )
        XCTAssertEqual(clamped, 0, "Without a baked meanSquaredSplatExtent, selection must fall back to the distance-based choice unchanged")
    }

    func testClampGaussianLODForOverdrawStopsAtCoarsestTierWhenStillOverBudget() {
        let lodComponent = GaussianLODComponent()
        var level0 = GaussianLODLevel(maxDistance: 20)
        level0.meanSquaredSplatExtent = 1.0
        level0.buffers = GaussianComponent()
        level0.buffers?.splatCount = 1_000_000

        var level1 = GaussianLODLevel(maxDistance: 50)
        level1.meanSquaredSplatExtent = 1.0
        level1.buffers = GaussianComponent()
        level1.buffers?.splatCount = 1_000_000 // still huge -> still over budget

        lodComponent.lodLevels = [level0, level1]

        let clamped = clampGaussianLODForOverdraw(
            desiredLOD: 0,
            lodComponent: lodComponent,
            distance: 10,
            fovY: .pi / 2,
            viewportHeight: 1000,
            boundingRadius: 2,
            budget: 12.0
        )
        XCTAssertEqual(clamped, 1, "Should clamp to the coarsest available tier even if it's still over budget")
    }

    func testDraggingEntityForcesLODRefreshEvenWhenCameraIsStationary() async throws {
        LODConfig.shared.lodUpdateFrameInterval = 4 // matches the real production default

        let base = try bakeProgressiveBase(levelCount: 3)

        let entity = createEntity()
        translateTo(entityId: entity, position: simd_float3(0, 0, 5))
        setEntityGaussianProgressive(
            entityId: entity,
            baseFilename: base,
            levelCount: 3,
            maxDistances: [10, 50, .greatestFiniteMagnitude]
        )

        let camera = createEntity()
        scene.assign(to: camera, component: CameraComponent.self)?.localPosition = .zero
        _ = scene.assign(to: camera, component: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = camera

        let lod = try XCTUnwrap(scene.get(component: GaussianLODComponent.self, for: entity))

        // The non-streaming progressive path always loads the coarsest tier first,
        // independent of distance (see setEntityGaussianProgressive) -- wait that out.
        for _ in 0 ..< 20 where lod.currentLOD != 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(lod.currentLOD, 2)

        // Drive it to LOD0 (distance 5, within maxDistances[0] = 10). This requires an actual
        // tier load, so a handful of update() calls (crossing the interval) plus an await is
        // expected here -- this part isn't what's under test.
        for _ in 0 ..< 5 { GaussianLODSystem.shared.update(deltaTime: 0.1) }
        await lod.lodLevels[0].loadTask?.value
        for _ in 0 ..< 5 { GaussianLODSystem.shared.update(deltaTime: 0.1) }
        XCTAssertEqual(lod.currentLOD, 0)

        // "Drag" the entity back out to distance 60 in one move. LOD2 (coarsest) is already
        // resident from the very first load, so applying it needs no further async load --
        // just a single post-drag update() call. That call lands on frameCounter 11 (11 % 4 !=
        // 0, so the interval hasn't elapsed) with the camera stationary, so only the per-entity
        // fast path can catch this. Without it, this would silently do nothing until the
        // interval happened to elapse or the entity was dragged again.
        translateTo(entityId: entity, position: simd_float3(0, 0, 60))
        GaussianLODSystem.shared.update(deltaTime: 0.1)

        XCTAssertEqual(lod.currentLOD, 2, "A single post-drag update should pick up the entity's own displacement without waiting on the camera-driven throttle")
    }

    func testCameraDriftAccumulatesAcrossThrottledFramesInsteadOfResettingEachFrame() {
        // Disable the per-entity fast path so only the camera-driven cumulative-displacement
        // fast path can possibly catch this, and set the interval high enough that it can't
        // fire on its own within the handful of update() calls below.
        LODConfig.shared.minimumEntityDisplacementForLODUpdate = 1000
        LODConfig.shared.minimumCameraDisplacementForLODUpdate = 1.0
        LODConfig.shared.lodUpdateFrameInterval = 1000
        // Not testing hysteresis here -- the default (5.0) is larger than this test's near-tier
        // threshold (3), which would make switching back to LOD0 mathematically impossible
        // (3 - 5 = -2, an unreachable distance) and has nothing to do with what's under test.
        LODConfig.shared.hysteresis = 0

        let entity = createEntity()
        translateTo(entityId: entity, position: simd_float3(0, 0, 5))
        scene.get(component: LocalTransformComponent.self, for: entity)?.boundingBox = (
            min: simd_float3(-0.1, -0.1, -0.1), max: simd_float3(0.1, 0.1, 0.1)
        )

        let lod = scene.assign(to: entity, component: GaussianLODComponent.self)!
        var near = GaussianLODLevel(maxDistance: 3)
        near.buffers = GaussianComponent()
        near.residencyState = .resident
        var far = GaussianLODLevel(maxDistance: .greatestFiniteMagnitude)
        far.buffers = GaussianComponent()
        far.residencyState = .resident
        lod.lodLevels = [near, far]
        lod.currentLOD = 1
        lod.desiredLOD = 1
        lod.distanceSelectedLOD = 1

        let camera = createEntity()
        scene.assign(to: camera, component: CameraComponent.self)?.localPosition = .zero
        _ = scene.assign(to: camera, component: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = camera

        // Entity sits at distance 5 (over the "near" tier's threshold of 3) -- move the camera
        // toward it in many small steps (0.6 each), each individually under the 1.0
        // displacement threshold, ending well past distance 3 (final camera z = 6.0, so final
        // distance = 1.0). Only the cumulative fast path can possibly catch any of this (the
        // per-entity path is disabled above and the interval, 1000, never elapses in 10 calls).
        // If lastCameraPosition were being reset every frame instead of only on qualifying
        // frames, this fast path could never fire at all and lod.currentLOD would still be 1
        // after every one of these calls, regardless of how far the camera cumulatively moved.
        for step in 1 ... 10 {
            let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
            cameraComponent?.localPosition = simd_float3(0, 0, Float(step) * 0.6)
            GaussianLODSystem.shared.update(deltaTime: 0.1)
        }

        XCTAssertEqual(lod.currentLOD, 0, "Cumulative camera displacement across throttled-out frames should still trip the fast path")
    }

    func testProgressiveEntityWithoutExplicitBoundingBoxGetsAutoPopulatedFromLoadedTier() async throws {
        // The auto-populated box comes from the coarsest tier (a spatially-interleaved subset
        // of splats, loaded first) rather than the full asset, so it won't match the full
        // asset's box exactly -- just check it's in the same ballpark rather than requiring
        // precise equality.
        let asset = try PLYReader.readGaussianAsset(from: try testPLYURL())
        let trueBox = computeGaussianSplatBoundingBox(asset.splats)
        let trueExtent = simd_length(trueBox.max - trueBox.min)

        let base = try bakeProgressiveBase(levelCount: 3)
        let entity = createEntity()
        translateTo(entityId: entity, position: .zero)
        // Deliberately omit boundingBoxHalfExtent.
        setEntityGaussianProgressive(entityId: entity, baseFilename: base, levelCount: 3, maxDistances: [20, 50, .greatestFiniteMagnitude])

        let lod = try XCTUnwrap(scene.get(component: GaussianLODComponent.self, for: entity))
        for _ in 0 ..< 20 where lod.currentLOD != 2 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let boundingBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)?.boundingBox)
        XCTAssertNotEqual(boundingBox.min, simd_float3(-1, -1, -1), "Should not still be the default placeholder box")
        XCTAssertNotEqual(boundingBox.min, boundingBox.max, "Should not be degenerate")

        let gotExtent = simd_length(boundingBox.max - boundingBox.min)
        XCTAssertGreaterThan(gotExtent, trueExtent * 0.5, "Auto-populated box should be a reasonable approximation of the true asset extent")
        XCTAssertLessThan(gotExtent, trueExtent * 2.0, "Auto-populated box should be a reasonable approximation of the true asset extent")
    }

    func testOverdrawClampDoesNotContaminateDistanceHysteresisAnchor() {
        LODConfig.shared.gaussianOverdrawBudget = 0.001 // force the clamp to walk to the coarsest tier

        let entity = createEntity()
        translateTo(entityId: entity, position: simd_float3(0, 0, 1))
        scene.get(component: LocalTransformComponent.self, for: entity)?.boundingBox = (
            min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)
        )

        let lod = scene.assign(to: entity, component: GaussianLODComponent.self)!
        var level0 = GaussianLODLevel(maxDistance: 10)
        level0.meanSquaredSplatExtent = 1.0
        level0.buffers = GaussianComponent()
        level0.buffers?.splatCount = 100

        var level1 = GaussianLODLevel(maxDistance: 50)
        level1.meanSquaredSplatExtent = 0.0001
        level1.buffers = GaussianComponent()
        level1.buffers?.splatCount = 1

        lod.lodLevels = [level0, level1]
        // Stale anchor simulating "last frame we were logically at LOD 1" -- pure distance (1
        // unit, well under level0's threshold of 10) should move this back to LOD 0.
        lod.desiredLOD = 1
        lod.distanceSelectedLOD = 1

        let camera = createEntity()
        scene.assign(to: camera, component: CameraComponent.self)?.localPosition = .zero
        _ = scene.assign(to: camera, component: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = camera

        GaussianLODSystem.shared.update(deltaTime: 0.1)

        XCTAssertEqual(lod.desiredLOD, 1, "The tiny overdraw budget should force the actually-applied target to the coarser tier")
        XCTAssertEqual(lod.distanceSelectedLOD, 0, "distanceSelectedLOD must track the pure distance pick, uncontaminated by the overdraw-forced value")
    }

    func testBakeProgressiveTiersThrowsOnEmptyPLYRegardlessOfLodFractions() throws {
        let ply = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianEmptyPLY-\(UUID().uuidString)")
            .appendingPathExtension("ply")
        let lines = [
            "ply", "format ascii 1.0", "element vertex 0",
            "property float x", "property float y", "property float z",
            "property float scale_0", "property float scale_1", "property float scale_2",
            "property float f_dc_0", "property float f_dc_1", "property float f_dc_2",
            "property float opacity",
            "property float rot_0", "property float rot_1", "property float rot_2", "property float rot_3",
            "end_header",
        ]
        // Trailing newline required: PLYReader's header scan finds "end_header" by looking for
        // the newline that terminates it, so a file ending right after that line with none
        // would never be recognized.
        try (lines.joined(separator: "\n") + "\n").write(to: ply, atomically: true, encoding: .utf8)

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianEmptyPLYBake-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")

        XCTAssertThrowsError(try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0])) { error in
            guard case UntoldGSError.sizeMismatch = error else {
                XCTFail("Expected .sizeMismatch, got \(error)")
                return
            }
        }
    }

    func testComputeGaussianSplatBoundingBoxExpandsBySplatScaleNotJustCenter() {
        // A single splat sitting exactly at the origin with a large scale should produce a box
        // reflecting its true extent, not a degenerate single point.
        let splat = GaussianSplat(
            center: simd_float4(0, 0, 0, 1),
            scale: simd_float4(2, 0.5, 0.5, 1),
            color: simd_float4(1, 1, 1, 1),
            quat: simd_float4(0, 0, 0, 1),
            opacity: 1
        )
        let box = computeGaussianSplatBoundingBox([splat])
        XCTAssertEqual(box.min, simd_float3(-2, -2, -2))
        XCTAssertEqual(box.max, simd_float3(2, 2, 2))
    }

    // MARK: - UntoldGSFormat corrupt-header handling

    func testReadThrowsInsteadOfTrappingOnOverflowingHeaderCounts() throws {
        // Hand-crafted 48-byte header (magic "UTGS", version 1) declaring a splatCount of
        // UInt64.max, which overflows when multiplied by EncodedGaussianSplat's stride to
        // compute the expected encoded-splat byte count. Before the overflow-checked rewrite,
        // the unchecked `Int(UInt64)`/`*` in UntoldGSFormat.read would trap the process on a
        // file like this instead of throwing a catchable error.
        var bytes: [UInt8] = []
        bytes += [0x55, 0x54, 0x47, 0x53] // magic "UTGS", little-endian
        bytes += [1, 0, 0, 0] // version = 1
        bytes += [UInt8](repeating: 0xFF, count: 8) // splatCount = UInt64.max
        bytes += [0, 0, 0, 0] // shDegree
        bytes += [0, 0, 0, 0] // shCoefficientsPerChannel
        bytes += [0, 0, 0, 0] // shHigherOrderCoefficientsPerSplat
        bytes += [0, 0, 0, 0] // meanSquaredSplatExtent (0.0 as Float bit pattern)
        bytes += [UInt8](repeating: 0, count: 8) // encodedByteCount
        bytes += [UInt8](repeating: 0, count: 8) // shByteCount
        XCTAssertEqual(bytes.count, 48)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldGSFormat-overflow-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        try Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try UntoldGSFormat.read(from: url)) { error in
            guard case UntoldGSError.sizeMismatch = error else {
                XCTFail("Expected .sizeMismatch, got \(error)")
                return
            }
        }
    }
}
