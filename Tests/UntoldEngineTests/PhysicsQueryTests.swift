//
//  PhysicsQueryTests.swift
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

private final class RaycastPhysicsBackend: PhysicsBackend, @unchecked Sendable {
    let id: String
    let capabilities: PhysicsCapabilities

    var cannedHit: PhysicsRayHit?
    private(set) var raycastCallCount = 0

    init(id: String = "com.example.raycastphysics", capabilities: PhysicsCapabilities) {
        self.id = id
        self.capabilities = capabilities
    }

    func configure(_: PhysicsWorldConfiguration) {}

    func step(deltaTime _: Float) {}

    func raycast(_: PhysicsRay, filter _: PhysicsQueryFilter) -> PhysicsRayHit? {
        raycastCallCount += 1
        return cannedHit
    }
}

private struct RaycastBackendPlugin: PhysicsBackendPlugin {
    let manifest: PhysicsBackendPluginManifest
    let backend: RaycastPhysicsBackend

    init(pluginID: String = "com.example.raycastphysics", capabilities: PhysicsCapabilities) {
        manifest = PhysicsBackendPluginManifest(
            id: pluginID,
            displayName: "Raycast Physics",
            version: PhysicsBackendVersion(major: 1, minor: 0, patch: 0),
            requiredAPIVersion: .current
        )
        backend = RaycastPhysicsBackend(id: pluginID, capabilities: capabilities)
    }

    func makeBackend() -> any PhysicsBackend {
        backend
    }
}

@MainActor
final class PhysicsQueryTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() {
        PhysicsBackendRegistry.shared.resetForTesting()
        super.tearDown()
    }

    /// Creates an entity with world-space AABB `center ± halfExtents`,
    /// registered with the octree the same way renderable entities are.
    private func makeObstacle(
        center: simd_float3,
        halfExtents: simd_float3 = simd_float3(repeating: 0.5)
    ) -> EntityID {
        let entityId = createEntity()
        scene.get(component: LocalTransformComponent.self, for: entityId)?.boundingBox =
            (min: -halfExtents, max: halfExtents)
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            var space = matrix_identity_float4x4
            space.columns.3 = simd_float4(center.x, center.y, center.z, 1.0)
            worldTransform.space = space
        }
        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    // MARK: - Octree fallback

    func testFallbackReturnsNearestHitWithSurfaceData() {
        let near = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))
        _ = makeObstacle(center: simd_float3(0.0, 0.0, -10.0))

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0))
        )

        XCTAssertEqual(hit?.entity, near)
        XCTAssertEqual(hit?.distance ?? 0, 4.5, accuracy: 1.0e-4)
        XCTAssertEqual(hit?.position.z ?? 0, -4.5, accuracy: 1.0e-4)
        XCTAssertEqual(hit?.normal, simd_float3(0.0, 0.0, 1.0))
    }

    func testFallbackNormalizesDirectionAndReportsWorldDistance() {
        _ = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -8.0))
        )

        XCTAssertEqual(hit?.distance ?? 0, 4.5, accuracy: 1.0e-4)
    }

    func testFallbackHonorsMaxDistance() {
        _ = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0), maxDistance: 3.0)
        )

        XCTAssertNil(hit)
    }

    func testFallbackHonorsExcludedEntities() {
        let near = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))
        let far = makeObstacle(center: simd_float3(0.0, 0.0, -10.0))

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0)),
            filter: PhysicsQueryFilter(excludedEntities: [near])
        )

        XCTAssertEqual(hit?.entity, far)
        XCTAssertEqual(hit?.distance ?? 0, 9.5, accuracy: 1.0e-4)
    }

    func testFallbackAppliesLayerMaskToBodiesAndPassesBodylessEntities() {
        let near = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))
        registerComponent(entityId: near, componentType: RigidBodyComponent.self)
        scene.get(component: RigidBodyComponent.self, for: near)?.layer = 1
        let far = makeObstacle(center: simd_float3(0.0, 0.0, -10.0))

        // Mask selects only layer 0: the layer-1 body is skipped, the bodyless
        // far entity (treated as layer 0) is hit.
        let maskedHit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0)),
            filter: PhysicsQueryFilter(layerMask: 1 << 0)
        )
        XCTAssertEqual(maskedHit?.entity, far)

        // The default all-layers mask hits the near body.
        let openHit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0))
        )
        XCTAssertEqual(openHit?.entity, near)
    }

    func testFallbackRayStartingInsideBoxHitsAtOrigin() {
        let box = makeObstacle(center: simd_float3(0.0, 0.0, -0.2), halfExtents: simd_float3(repeating: 1.0))

        let direction = simd_float3(0.0, 0.0, -1.0)
        let hit = PhysicsQuery.raycast(PhysicsRay(origin: .zero, direction: direction))

        XCTAssertEqual(hit?.entity, box)
        XCTAssertEqual(hit?.distance, 0.0)
        XCTAssertEqual(hit?.position, .zero)
        XCTAssertEqual(hit?.normal, -direction)
    }

    func testInsideBoxHitBeatsCloserSortedOutsideCandidate() throws {
        // Regression for the sorted-scan early exit (owner's review case):
        // the ray starts inside a big box whose broad-phase distance is its
        // far EXIT distance, sorting it behind a small box further down the
        // ray. The inside-origin hit (distance 0) must still win.
        let bigBox = makeObstacle(
            center: simd_float3(0, 0, -50),
            halfExtents: simd_float3(50, 50, 100)
        )
        _ = makeObstacle(
            center: simd_float3(0, 0, -50),
            halfExtents: simd_float3(repeating: 0.5)
        )

        let direction = simd_float3(0, 0, -1)
        let hit = try XCTUnwrap(PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: direction)
        ))

        XCTAssertEqual(hit.entity, bigBox)
        XCTAssertEqual(hit.distance, 0.0)
        XCTAssertEqual(hit.position, .zero)
        XCTAssertEqual(hit.normal, -direction)
    }

    func testInsideBoxHitSurvivesTightMaxDistance() throws {
        // Regression: the broad-phase cull inside OctreeSystem.query compares
        // maxDistance against the sorted distance, which for an inside-origin
        // box is its far EXIT distance, not the true hit distance (0). Passing
        // the caller's maxDistance straight through to that query would drop
        // this box before the narrow phase ever saw it, even though the real
        // hit (distance 0, at the ray origin) is well inside a tight budget.
        let bigBox = makeObstacle(
            center: simd_float3(0, 0, -50),
            halfExtents: simd_float3(50, 50, 100)
        )

        let direction = simd_float3(0, 0, -1)
        let hit = try XCTUnwrap(PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: direction, maxDistance: 5.0)
        ))

        XCTAssertEqual(hit.entity, bigBox)
        XCTAssertEqual(hit.distance, 0.0)
        XCTAssertEqual(hit.position, .zero)
        XCTAssertEqual(hit.normal, -direction)
    }

    func testFallbackMissReturnsNil() {
        _ = makeObstacle(center: simd_float3(0.0, 10.0, -5.0))

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0))
        )

        XCTAssertNil(hit)
    }

    // MARK: - Backend routing

    func testBackendWithRaycastCapabilityIsAuthoritative() {
        _ = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))

        let plugin = RaycastBackendPlugin(capabilities: [.raycast])
        XCTAssertEqual(PhysicsBackendRegistry.shared.install(plugin), .installed)
        plugin.backend.cannedHit = PhysicsRayHit(
            entity: 999,
            position: simd_float3(0.0, 0.0, -2.0),
            normal: simd_float3(0.0, 0.0, 1.0),
            distance: 2.0
        )

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0))
        )

        XCTAssertEqual(plugin.backend.raycastCallCount, 1)
        XCTAssertEqual(hit?.entity, 999, "A capable backend's answer wins over the octree")

        // A capable backend's miss is also authoritative — no octree fallback.
        plugin.backend.cannedHit = nil
        XCTAssertNil(PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0))
        ))
    }

    func testBackendWithoutRaycastCapabilityFallsBackToOctree() {
        let obstacle = makeObstacle(center: simd_float3(0.0, 0.0, -5.0))

        let plugin = RaycastBackendPlugin(capabilities: [])
        XCTAssertEqual(PhysicsBackendRegistry.shared.install(plugin), .installed)
        plugin.backend.cannedHit = PhysicsRayHit(
            entity: 999,
            position: .zero,
            normal: simd_float3(0.0, 1.0, 0.0),
            distance: 1.0
        )

        let hit = PhysicsQuery.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0.0, 0.0, -1.0))
        )

        XCTAssertEqual(plugin.backend.raycastCallCount, 0, "Backends without .raycast are never asked")
        XCTAssertEqual(hit?.entity, obstacle)
    }
}
