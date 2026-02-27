//
//  ScenePickingSystemTests.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd
@testable import UntoldEngine
import XCTest

final class ScenePickingSystemTests: XCTestCase {
    override func setUp() {
        super.setUp()
        scene = Scene()
        visibleEntityIds.removeAll()
        scenePickingDirtyEntities.removeAll()
        scenePickingSystemInitialized = false
        scenePickingGPUAvailable = false
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()
        entityMeshMap.removeAll()
        InputSystem.shared.keyState.shiftPressed = false
    }

    override func tearDown() {
        InputSystem.shared.keyState.shiftPressed = false
        super.tearDown()
    }

    private func makeTranslationMatrix(_ translation: simd_float3) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = simd_float4(translation.x, translation.y, translation.z, 1.0)
        return matrix
    }

    @discardableResult
    private func createRenderableEntity(
        position: simd_float3,
        bounds: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
        isVisible: Bool = true,
        isGizmo: Bool = false
    ) -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RenderComponent.self)

        if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
            localTransform.boundingBox = bounds
        }

        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(position)
        }

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
            renderComponent.isVisible = isVisible
        }

        if isGizmo {
            registerComponent(entityId: entityId, componentType: GizmoComponent.self)
        }

        return entityId
    }

    func testPickEntityReturnsNearestIntersection() {
        let fartherEntity = createRenderableEntity(position: simd_float3(10, 0, 0))
        let nearerEntity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [fartherEntity, nearerEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        XCTAssertEqual(hit.entityId, nearerEntity, "Picker should choose the closest hit")
        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.0001, "Expected entry distance at x = 4")
        XCTAssertEqual(hit.worldPosition.x, 4.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.z, 0.0, accuracy: 0.0001)
        XCTAssertNil(hit.triangleIndex, "CPU picker should not report triangle index")
    }

    func testPickEntitySkipsInvisibleEntities() {
        let hiddenNearEntity = createRenderableEntity(position: simd_float3(3, 0, 0), isVisible: false)
        let visibleFarEntity = createRenderableEntity(position: simd_float3(8, 0, 0), isVisible: true)
        visibleEntityIds = [hiddenNearEntity, visibleFarEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, visibleFarEntity, "Invisible entities should be ignored")
    }

    func testPickEntityReturnsNilForInvalidRayDirection() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let zeroDirection = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(0, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        let nanDirection = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(.nan, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertNil(zeroDirection)
        XCTAssertNil(nanDirection)
    }

    func testPickEntityGizmoModeOnlyQueriesGizmoEntitiesWhenShiftNotPressed() {
        let regularEntity = createRenderableEntity(position: simd_float3(3, 0, 0), isGizmo: false)
        let gizmoEntity = createRenderableEntity(position: simd_float3(8, 0, 0), isGizmo: true)
        visibleEntityIds = [regularEntity, gizmoEntity]
        InputSystem.shared.keyState.shiftPressed = false

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(isGizmoActive: true, backend: .cpuOnly)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, gizmoEntity, "When gizmo mode is active, only gizmo entities should be considered")
    }

    func testPickEntityGizmoModeWithShiftFallsBackToVisibleEntities() {
        let regularEntity = createRenderableEntity(position: simd_float3(3, 0, 0), isGizmo: false)
        let gizmoEntity = createRenderableEntity(position: simd_float3(8, 0, 0), isGizmo: true)
        visibleEntityIds = [regularEntity, gizmoEntity]
        InputSystem.shared.keyState.shiftPressed = true

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(isGizmoActive: true, backend: .cpuOnly)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, regularEntity, "Shift should disable gizmo-only filtering")
    }

    func testPickEntityRespectsMaxDistance() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let withinDistance = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(maxDistance: 4.1, backend: .cpuOnly)
        )

        let outsideDistance = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(maxDistance: 3.9, backend: .cpuOnly)
        )

        XCTAssertNotNil(withinDistance)
        XCTAssertEqual(withinDistance?.entityId, entity)
        XCTAssertNil(outsideDistance)
    }

    func testPickEntityGPUOnlyReturnsNilWhenGPUUnavailable() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let gpuOnly = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .gpuOnly)
        )

        let cpuOnly = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertNil(gpuOnly, "GPU-only picking should fail when GPU picker is unavailable")
        XCTAssertEqual(cpuOnly?.entityId, entity, "CPU backend should still succeed with the same ray")
    }

    // MARK: - Octree-Based Ray Picking Tests

    func testOctreePickingReturnsNearestEntity() {
        let fartherEntity = createRenderableEntity(position: simd_float3(10, 0, 0))
        let nearerEntity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [fartherEntity, nearerEntity]

        // Register entities with octree
        OctreeSystem.shared.registerEntity(fartherEntity)
        OctreeSystem.shared.registerEntity(nearerEntity)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreePreferred)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        XCTAssertEqual(hit.entityId, nearerEntity, "Octree picker should choose the closest hit")
        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.0001, "Expected entry distance at x = 4")
    }

    func testOctreePickingSkipsInvisibleEntities() {
        let hiddenNearEntity = createRenderableEntity(position: simd_float3(3, 0, 0), isVisible: false)
        let visibleFarEntity = createRenderableEntity(position: simd_float3(8, 0, 0), isVisible: true)
        visibleEntityIds = [hiddenNearEntity, visibleFarEntity]

        OctreeSystem.shared.registerEntity(hiddenNearEntity)
        OctreeSystem.shared.registerEntity(visibleFarEntity)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreePreferred)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, visibleFarEntity, "Octree picker should ignore invisible entities")
    }

    func testOctreePickingReturnsAccurateDistance() {
        let entity = createRenderableEntity(position: simd_float3(7.5, 0, 0))
        visibleEntityIds = [entity]

        OctreeSystem.shared.registerEntity(entity)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreePreferred)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        XCTAssertEqual(hit.distance, 6.5, accuracy: 0.0001, "Expected accurate distance calculation")
    }

    func testOctreePickingFallsBackToCPUWhenOctreeDisabled() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        // Disable octree
        OctreeSystem.shared.enabled = false

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreePreferred)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, entity, "Should fallback to CPU when Octree is disabled")

        // Re-enable for other tests
        OctreeSystem.shared.enabled = true
    }

    func testOctreePickingHandlesRayBehindEntity() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        OctreeSystem.shared.registerEntity(entity)

        let result = pickEntity(
            rayOrigin: simd_float3(10, 0, 0),  // Ray starts behind entity
            rayDirection: simd_float3(-1, 0, 0), // Ray points backward
            options: ScenePickOptions(backend: .octreePreferred)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        XCTAssertEqual(hit.entityId, entity, "Octree picker should intersect ray pointing backward")
        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.0001, "Distance should be 4.0 (10 - 6) from x=10 to AABB at x=6")
    }

    func testOctreePickingRespectsMaxDistance() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        OctreeSystem.shared.registerEntity(entity)

        let withinDistance = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(maxDistance: 4.1, backend: .octreePreferred)
        )

        let outsideDistance = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(maxDistance: 3.9, backend: .octreePreferred)
        )

        XCTAssertNotNil(withinDistance)
        XCTAssertEqual(withinDistance?.entityId, entity)
        XCTAssertNil(outsideDistance)
    }
}
