//
//  GaussianProgressiveLODTest.swift
//  UntoldEngine
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
final class GaussianProgressiveLODTest: BaseRenderSetup {
    private var savedLODUpdateFrameInterval = 1

    override func setUp() async throws {
        try await super.setUp()
        savedLODUpdateFrameInterval = LODConfig.shared.lodUpdateFrameInterval
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
        let urls = try bakeGaussianSplatProgressiveTiers(
            plyURL: try testPLYURL(),
            outputBaseURL: output,
            levelCount: 3
        )

        let tiers = try urls.map { try UntoldGSFormat.read(from: $0) }
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

        let urls = try bakeGaussianSplatProgressiveTiers(
            plyURL: ply,
            outputBaseURL: output,
            lodFractions: [1.0, 0.25]
        )
        let coarse = try UntoldGSFormat.read(from: urls[1])
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
}
