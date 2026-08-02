//
//  PluginSpatialSystemTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

private final class TestPluginSpatialProvider: PluginSpatialProvider, @unchecked Sendable {
    let ownerID: String
    var bounds: [PluginSpatialBounds]
    var customHits: [PluginSpatialHit]?

    init(
        ownerID: String,
        bounds: [PluginSpatialBounds],
        customHits: [PluginSpatialHit]? = nil
    ) {
        self.ownerID = ownerID
        self.bounds = bounds
        self.customHits = customHits
    }

    func boundsSnapshot() -> [PluginSpatialBounds] {
        bounds
    }

    func raycast(_ ray: PluginSpatialRay, options: PluginSpatialQueryOptions) -> [PluginSpatialHit] {
        if let customHits {
            return customHits
        }

        return PluginSpatialRegistry.raycastBounds(bounds, ray: ray, options: options)
    }
}

@MainActor
final class PluginSpatialSystemTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() async throws {
        resetEngineTestState()
    }

    func testRegisterRejectsDuplicateOwnerID() {
        let firstProvider = TestPluginSpatialProvider(ownerID: "com.example.water", bounds: [])
        let secondProvider = TestPluginSpatialProvider(ownerID: "com.example.water", bounds: [])

        XCTAssertEqual(PluginSpatialRegistry.shared.register(firstProvider), .installed)
        XCTAssertEqual(
            PluginSpatialRegistry.shared.register(secondProvider),
            .duplicateOwnerID("com.example.water")
        )
    }

    func testQueryRangeReturnsIntersectingPluginBounds() {
        let nearBounds = PluginSpatialBounds(
            ownerID: "com.example.water",
            objectID: "patch.near",
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(2, 2, 2))
        )
        let farBounds = PluginSpatialBounds(
            ownerID: "com.example.water",
            objectID: "patch.far",
            bounds: AABB(min: simd_float3(10, 10, 10), max: simd_float3(12, 12, 12))
        )
        let provider = TestPluginSpatialProvider(
            ownerID: "com.example.water",
            bounds: [nearBounds, farBounds]
        )

        PluginSpatialRegistry.shared.register(provider)

        let results = PluginSpatialRegistry.shared.query(
            range: AABB(min: simd_float3(-1, -1, -1), max: simd_float3(3, 3, 3))
        )

        XCTAssertEqual(results.map(\.objectID), ["patch.near"])
    }

    func testDefaultProviderRaycastUsesBoundsAndSortsByDistance() {
        let farBounds = PluginSpatialBounds(
            ownerID: "com.example.cloth",
            objectID: "cloth.far",
            bounds: AABB(min: simd_float3(8, -1, -1), max: simd_float3(10, 1, 1))
        )
        let nearBounds = PluginSpatialBounds(
            ownerID: "com.example.cloth",
            objectID: "cloth.near",
            bounds: AABB(min: simd_float3(4, -1, -1), max: simd_float3(6, 1, 1))
        )
        let provider = TestPluginSpatialProvider(
            ownerID: "com.example.cloth",
            bounds: [farBounds, nearBounds]
        )

        PluginSpatialRegistry.shared.register(provider)

        let hits = PluginSpatialRegistry.shared.raycastAll(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertEqual(hits.map(\.objectID), ["cloth.near", "cloth.far"])
        XCTAssertEqual(hits.first?.distance ?? -1, 4.0, accuracy: 0.0001)
    }

    func testCustomProviderRaycastCanReturnPluginOnlyObject() {
        let provider = TestPluginSpatialProvider(
            ownerID: "com.example.saber",
            bounds: [],
            customHits: [
                PluginSpatialHit(
                    ownerID: "com.example.saber",
                    objectID: "blade",
                    distance: 2,
                    worldPosition: simd_float3(2, 0, 0),
                    worldNormal: simd_float3(-1, 0, 0)
                ),
            ]
        )

        PluginSpatialRegistry.shared.register(provider)

        let hit = pickPluginSpatialObject(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertEqual(hit?.ownerID, "com.example.saber")
        XCTAssertEqual(hit?.objectID, "blade")
        XCTAssertNil(hit?.entityId)
    }

    func testPickEntityCanReturnPluginHitMappedToEntity() {
        let engineEntity = createEntity()
        registerComponent(entityId: engineEntity, componentType: RenderComponent.self)
        visibleEntityIds = [engineEntity]

        if let localTransform = scene.get(component: LocalTransformComponent.self, for: engineEntity) {
            localTransform.boundingBox = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
        }
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: engineEntity) {
            var matrix = matrix_identity_float4x4
            matrix.columns.3 = simd_float4(10, 0, 0, 1)
            worldTransform.space = matrix
        }

        let pluginEntity = createEntity()
        let provider = TestPluginSpatialProvider(
            ownerID: "com.example.water",
            bounds: [
                PluginSpatialBounds(
                    ownerID: "com.example.water",
                    objectID: "surface",
                    entityId: pluginEntity,
                    bounds: AABB(min: simd_float3(4, -1, -1), max: simd_float3(6, 1, 1))
                ),
            ]
        )

        PluginSpatialRegistry.shared.register(provider)

        let hit = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(hit?.entityId, pluginEntity)
        XCTAssertEqual(hit?.distance ?? -1, 4.0, accuracy: 0.0001)
    }

    func testPickEntityIgnoresPluginOnlyObjectWithoutEntityMapping() {
        let engineEntity = createEntity()
        registerComponent(entityId: engineEntity, componentType: RenderComponent.self)
        visibleEntityIds = [engineEntity]

        if let localTransform = scene.get(component: LocalTransformComponent.self, for: engineEntity) {
            localTransform.boundingBox = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
        }
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: engineEntity) {
            var matrix = matrix_identity_float4x4
            matrix.columns.3 = simd_float4(10, 0, 0, 1)
            worldTransform.space = matrix
        }

        let provider = TestPluginSpatialProvider(
            ownerID: "com.example.water",
            bounds: [
                PluginSpatialBounds(
                    ownerID: "com.example.water",
                    objectID: "surface",
                    bounds: AABB(min: simd_float3(4, -1, -1), max: simd_float3(6, 1, 1))
                ),
            ]
        )

        PluginSpatialRegistry.shared.register(provider)

        let entityHit = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )
        let pluginHit = pickPluginSpatialObject(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertEqual(entityHit?.entityId, engineEntity)
        XCTAssertEqual(pluginHit?.objectID, "surface")
    }

    func testPickEntityFallsBackToFartherPluginHitWhenNearestIsIgnored() {
        let ignoredEntity = createEntity()
        let pickableEntity = createEntity()
        registerComponent(entityId: ignoredEntity, componentType: PickInteractionComponent.self)
        scene.get(component: PickInteractionComponent.self, for: ignoredEntity)?
            .participatesInPicking = false

        let provider = TestPluginSpatialProvider(
            ownerID: "com.example.water",
            bounds: [
                PluginSpatialBounds(
                    ownerID: "com.example.water",
                    objectID: "near.ignored",
                    entityId: ignoredEntity,
                    bounds: AABB(min: simd_float3(4, -1, -1), max: simd_float3(6, 1, 1))
                ),
                PluginSpatialBounds(
                    ownerID: "com.example.water",
                    objectID: "far.pickable",
                    entityId: pickableEntity,
                    bounds: AABB(min: simd_float3(8, -1, -1), max: simd_float3(10, 1, 1))
                ),
            ]
        )

        PluginSpatialRegistry.shared.register(provider)

        let hit = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(hit?.entityId, pickableEntity)
        XCTAssertEqual(hit?.distance ?? -1, 8.0, accuracy: 0.0001)
    }
}
