//
//  ScenePickingGPUNormalTests.swift
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
final class ScenePickingGPUNormalTests: BaseRenderSetup {
    func testGPUOnlyPickReturnsMeshSurfaceNormalForPlaneHit() throws {
        guard scenePickingCanUseGPU() else {
            throw XCTSkip("GPU scene picking is unavailable on this device")
        }

        let planeEntity = createEntity()
        setEntityName(entityId: planeEntity, name: "gpu_pick_normal_plane")
        setEntityMeshDirect(
            entityId: planeEntity,
            meshes: BasicPrimitives.createPlane(width: 4.0, depth: 4.0),
            assetName: "gpu_pick_normal_plane"
        )
        translateBy(entityId: planeEntity, position: simd_float3(20.0, 0.0, 0.0))

        visibleEntityIds = [planeEntity]
        for frame in 0 ..< 3 {
            tripleVisibleEntities.setWrite(frame: frame, with: visibleEntityIds)
        }

        let hit = pickEntity(
            rayOrigin: simd_float3(20.0, 2.0, 0.0),
            rayDirection: simd_float3(0.0, -1.0, 0.0),
            options: ScenePickOptions(backend: .gpuOnly)
        )

        guard let hit else {
            XCTFail("Expected GPU scene picking to hit the test plane")
            return
        }
        guard let worldNormal = hit.worldNormal else {
            XCTFail("GPU mesh picking should report a world-space surface normal")
            return
        }

        XCTAssertEqual(hit.entityId, planeEntity)
        XCTAssertEqual(hit.worldPosition.x, 20.0, accuracy: 0.01)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.01)
        XCTAssertEqual(hit.worldPosition.z, 0.0, accuracy: 0.01)
        XCTAssertEqual(simd_length(worldNormal), 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(abs(simd_dot(worldNormal, simd_float3(0.0, 1.0, 0.0))), 0.99)
        XCTAssertNotNil(hit.triangleIndex)
    }
}
