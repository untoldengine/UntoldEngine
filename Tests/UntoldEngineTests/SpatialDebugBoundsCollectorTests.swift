//
//  SpatialDebugBoundsCollectorTests.swift
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

final class SpatialDebugBoundsCollectorTests: XCTestCase {
    private let defaultColor = simd_float4(1.0, 1.0, 1.0, 1.0)
    private let residencyLoadedColor = simd_float4(0.25, 0.95, 0.35, 1.0)
    private let cullingVisibleColor = simd_float4(0.25, 0.95, 0.35, 1.0)

    override func setUp() {
        super.setUp()
        resetEngineTestState()
        SpatialDebugVisualization.shared.disableAll()
        OctreeSystem.shared.clear()
        visibleEntityIds.removeAll()
    }

    override func tearDown() {
        SpatialDebugVisualization.shared.disableAll()
        OctreeSystem.shared.clear()
        visibleEntityIds.removeAll()
        super.tearDown()
    }

    func testCollectSnapshotReturnsEmptyWhenDebugDisabled() {
        _ = createOctreeEntity(includeRenderComponent: true)

        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertTrue(snapshot.octreeLeafBounds.isEmpty)
    }

    func testCollectSnapshotReturnsLeafBoundsWithPlainColor() {
        _ = createOctreeEntity(includeRenderComponent: true)
        setOctreeLeafBoundsDebug(enabled: true, colorMode: .plain)

        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertFalse(snapshot.octreeLeafBounds.isEmpty)
        XCTAssertTrue(
            snapshot.octreeLeafBounds.allSatisfy { approximatelyEqual($0.color, defaultColor) },
            "All leaf bounds should use default color in plain mode"
        )
    }

    func testCollectSnapshotUsesCullingVisibleColor() {
        let entityId = createOctreeEntity(includeRenderComponent: true)
        visibleEntityIds = [entityId]
        setOctreeLeafBoundsDebug(enabled: true, colorMode: .culling)

        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertFalse(snapshot.octreeLeafBounds.isEmpty)
        XCTAssertTrue(
            snapshot.octreeLeafBounds.contains(where: { approximatelyEqual($0.color, cullingVisibleColor) }),
            "Expected at least one visible culling-colored leaf"
        )
    }

    func testCollectSnapshotUsesResidencyLoadedColorForStreamingLoadedEntity() {
        let entityId = createOctreeEntity(includeRenderComponent: false)
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)
        scene.get(component: StreamingComponent.self, for: entityId)?.state = .loaded

        setOctreeLeafBoundsDebug(enabled: true, colorMode: .residency)

        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertFalse(snapshot.octreeLeafBounds.isEmpty)
        XCTAssertTrue(
            snapshot.octreeLeafBounds.contains(where: { approximatelyEqual($0.color, residencyLoadedColor) }),
            "Expected residency loaded color for loaded streaming entity"
        )
    }

    func testCollectSnapshotUsesResidencyLoadedColorForResidentLOD() {
        let entityId = createOctreeEntity(includeRenderComponent: false)
        registerComponent(entityId: entityId, componentType: LODComponent.self)

        if let lod = scene.get(component: LODComponent.self, for: entityId) {
            var level = LODLevel(mesh: [], maxDistance: 50.0)
            level.residencyState = .resident
            lod.lodLevels = [level]
            lod.currentLOD = 0
        } else {
            XCTFail("Failed to create LOD component for test entity")
            return
        }

        setOctreeLeafBoundsDebug(enabled: true, colorMode: .residency)

        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertFalse(snapshot.octreeLeafBounds.isEmpty)
        XCTAssertTrue(
            snapshot.octreeLeafBounds.contains(where: { approximatelyEqual($0.color, residencyLoadedColor) }),
            "Expected residency loaded color for resident LOD entity"
        )
    }

    private func createOctreeEntity(includeRenderComponent: Bool) -> EntityID {
        let entityId = createEntity()
        if includeRenderComponent {
            registerComponent(entityId: entityId, componentType: RenderComponent.self)
        }
        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    private func approximatelyEqual(_ lhs: simd_float4, _ rhs: simd_float4, epsilon: Float = 0.0001) -> Bool {
        abs(lhs.x - rhs.x) <= epsilon &&
            abs(lhs.y - rhs.y) <= epsilon &&
            abs(lhs.z - rhs.z) <= epsilon &&
            abs(lhs.w - rhs.w) <= epsilon
    }
}
