//
//  ScenePickingSystemTests.swift
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

@MainActor
final class ScenePickingSystemTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        InputSystem.shared.keyState.shiftPressed = false
        setIgnoreRayIntersectionWithTransparents(false)
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()
    }

    override func tearDown() async throws {
        InputSystem.shared.keyState.shiftPressed = false
        setIgnoreRayIntersectionWithTransparents(false)
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()
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
        isGizmo: Bool = false,
        pickParticipation: Bool? = nil,
        hitRepresentationMode: PickHitRepresentationMode? = nil
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
        if let pickParticipation {
            setEntityPickParticipation(entityId: entityId, enabled: pickParticipation)
        }
        if let hitRepresentationMode {
            setEntityPickHitRepresentationMode(entityId: entityId, mode: hitRepresentationMode)
        }

        return entityId
    }

    func testPickInteractionDefaultsPreserveCurrentBehavior() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        XCTAssertTrue(getEntityPickParticipation(entityId: entity))
        XCTAssertEqual(getEntityPickHitRepresentationMode(entityId: entity), .mesh)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, entity)
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

    func testPickEntityWithSceneRootYawHitsExpectedWorldSpaceGeometry() {
        SceneRootTransform.shared.rotation = simd_quatf(angle: .pi / 2.0, axis: simd_float3(0, 1, 0))
        SceneRootTransform.shared.updateIfNeeded()

        let entity = createRenderableEntity(position: simd_float3(0, 0, 5))
        visibleEntityIds = [entity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit with scene-root yaw")
            return
        }

        XCTAssertEqual(hit.entityId, entity)
        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.x, 4.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.z, 0.0, accuracy: 0.0001)
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

    func testPickEntitySkipsNonParticipatingEntitiesInCPUPath() {
        let nonPickableNearEntity = createRenderableEntity(
            position: simd_float3(3, 0, 0),
            pickParticipation: false
        )
        let pickableFarEntity = createRenderableEntity(position: simd_float3(8, 0, 0))
        visibleEntityIds = [nonPickableNearEntity, pickableFarEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(result?.entityId, pickableFarEntity)
    }

    func testPickEntitySkipsHitRepresentationNoneInCPUPath() {
        let noneModeEntity = createRenderableEntity(
            position: simd_float3(3, 0, 0),
            hitRepresentationMode: PickHitRepresentationMode.none
        )
        let pickableFarEntity = createRenderableEntity(position: simd_float3(8, 0, 0))
        visibleEntityIds = [noneModeEntity, pickableFarEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(result?.entityId, pickableFarEntity)
    }

    func testPickEntityBoundsModeHitsInCPUPath() {
        let boundsModeEntity = createRenderableEntity(
            position: simd_float3(5, 0, 0),
            hitRepresentationMode: .bounds
        )
        visibleEntityIds = [boundsModeEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(result?.entityId, boundsModeEntity)
    }

    func testPickEntityMeshModePreservesCPUBehavior() {
        let meshModeEntity = createRenderableEntity(
            position: simd_float3(5, 0, 0),
            hitRepresentationMode: .mesh
        )
        visibleEntityIds = [meshModeEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(result?.entityId, meshModeEntity)
    }

    func testPickEntityPrefersParentWhenChildIsNonPickableInCPUPath() {
        let decorativeChild = createRenderableEntity(
            position: simd_float3(3, 0, 0),
            pickParticipation: false
        )
        let parent = createRenderableEntity(position: simd_float3(8, 0, 0))
        visibleEntityIds = [decorativeChild, parent]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertEqual(result?.entityId, parent)
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

    func testSetIgnoreRayIntersectionWithTransparentsTogglesFlag() {
        setIgnoreRayIntersectionWithTransparents(true)
        XCTAssertTrue(isIgnoringRayIntersectionWithTransparents())

        setIgnoreRayIntersectionWithTransparents(false)
        XCTAssertFalse(isIgnoringRayIntersectionWithTransparents())
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
            options: ScenePickOptions(backend: .octreeGPUPreferred)
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
            options: ScenePickOptions(backend: .octreeGPUPreferred)
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
            options: ScenePickOptions(backend: .octreeGPUPreferred)
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
            options: ScenePickOptions(backend: .octreeGPUPreferred)
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
            rayOrigin: simd_float3(10, 0, 0), // Ray starts behind entity
            rayDirection: simd_float3(-1, 0, 0), // Ray points backward
            options: ScenePickOptions(backend: .octreeGPUPreferred)
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
            options: ScenePickOptions(maxDistance: 4.1, backend: .octreeGPUPreferred)
        )

        let outsideDistance = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(maxDistance: 3.9, backend: .octreeGPUPreferred)
        )

        XCTAssertNotNil(withinDistance)
        XCTAssertEqual(withinDistance?.entityId, entity)
        XCTAssertNil(outsideDistance)
    }

    func testOctreePickingSkipsNonParticipatingEntities() {
        let nonPickableNearEntity = createRenderableEntity(
            position: simd_float3(3, 0, 0),
            pickParticipation: false
        )
        let pickableFarEntity = createRenderableEntity(position: simd_float3(8, 0, 0))
        visibleEntityIds = [nonPickableNearEntity, pickableFarEntity]

        OctreeSystem.shared.registerEntity(nonPickableNearEntity)
        OctreeSystem.shared.registerEntity(pickableFarEntity)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreeGPUPreferred)
        )

        XCTAssertEqual(result?.entityId, pickableFarEntity)
    }

    func testOctreePickingSkipsHitRepresentationNone() {
        let noneModeEntity = createRenderableEntity(
            position: simd_float3(3, 0, 0),
            hitRepresentationMode: PickHitRepresentationMode.none
        )
        let pickableFarEntity = createRenderableEntity(position: simd_float3(8, 0, 0))
        visibleEntityIds = [noneModeEntity, pickableFarEntity]

        OctreeSystem.shared.registerEntity(noneModeEntity)
        OctreeSystem.shared.registerEntity(pickableFarEntity)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreeGPUPreferred)
        )

        XCTAssertEqual(result?.entityId, pickableFarEntity)
    }

    func testOctreePickingPrefersParentWhenChildIsNonPickable() {
        let decorativeChild = createRenderableEntity(
            position: simd_float3(3, 0, 0),
            pickParticipation: false
        )
        let parent = createRenderableEntity(position: simd_float3(8, 0, 0))
        visibleEntityIds = [decorativeChild, parent]

        OctreeSystem.shared.registerEntity(decorativeChild)
        OctreeSystem.shared.registerEntity(parent)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreeGPUPreferred)
        )

        XCTAssertEqual(result?.entityId, parent)
    }

    func testUpdatingPickInteractionStateTakesEffectImmediately() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        var result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )
        XCTAssertEqual(result?.entityId, entity)

        setEntityPickParticipation(entityId: entity, enabled: false)
        result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )
        XCTAssertNil(result)

        setEntityPickParticipation(entityId: entity, enabled: true)
        result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )
        XCTAssertEqual(result?.entityId, entity)
    }

    func testDestroyedEntityDoesNotLeaveStalePickState() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let beforeDestroy = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )
        XCTAssertEqual(beforeDestroy?.entityId, entity)

        destroyEntity(entityId: entity)
        finalizePendingDestroys()

        let afterDestroy = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )
        XCTAssertNil(afterDestroy)
    }

    func testPickInteractionSettingsPersistThroughSceneSerialization() {
        let entity = createEntity()
        setEntityPickParticipation(entityId: entity, enabled: false)
        setEntityPickHitRepresentationMode(entityId: entity, mode: .bounds)

        let snapshot = serializeScene()
        resetEngineTestState()
        deserializeScene(sceneData: snapshot, meshLoadingMode: .sync)

        let entities = scene.getAllEntities()
        XCTAssertEqual(entities.count, 1)
        guard let restored = entities.first else {
            XCTFail("Expected one restored entity")
            return
        }

        XCTAssertFalse(getEntityPickParticipation(entityId: restored))
        XCTAssertEqual(getEntityPickHitRepresentationMode(entityId: restored), .bounds)
    }
}
