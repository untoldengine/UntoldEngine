//
//  EngineCreatedEntityTests.swift
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

/// Entities the engine creates for a load keep the transform and scene graph components
/// `createEntity()` gave them. Registering them again made three more objects per entity
/// and asked for a scene graph traversal (a walk over every entity) on the next frame,
/// although the transform calls the loaders use update the world matrix at once.
@MainActor
final class EngineCreatedEntityTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        anyTransformDirty = false
    }

    override func tearDown() async throws {
        resetEngineTestState()
        anyTransformDirty = false
    }

    private func assertVector(
        _ value: simd_float3,
        equals expected: simd_float3,
        accuracy: Float = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(value.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(value.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(value.z, expected.z, accuracy: accuracy, file: file, line: line)
    }

    func testAStreamingEntityIsSpatialAndAsksForNoTraversal() {
        let entity = createStreamingEntity(filename: "model", withExtension: "untold")

        XCTAssertTrue(hasComponent(entityId: entity, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entity, componentType: WorldTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entity, componentType: ScenegraphComponent.self))
        XCTAssertFalse(anyTransformDirty, "an entity at the identity transform has nothing to derive")

        translateTo(entityId: entity, position: simd_float3(4.0, 5.0, 6.0))

        assertVector(getPosition(entityId: entity), equals: simd_float3(4.0, 5.0, 6.0))
    }

    func testADeserializedHierarchyIsPlacedWithoutATraversal() throws {
        let parent = createEntity()
        setEntityName(entityId: parent, name: "Parent")
        translateTo(entityId: parent, position: simd_float3(3.0, 0.0, -2.0))
        scaleTo(entityId: parent, scale: simd_float3(2.0, 2.0, 2.0))

        let child = createEntity()
        setEntityName(entityId: child, name: "Child")
        setParent(childId: child, parentId: parent)
        translateTo(entityId: child, position: simd_float3(1.0, 0.5, 0.0))

        let snapshot = serializeScene()
        resetEngineTestState()
        anyTransformDirty = false

        deserializeScene(sceneData: snapshot, meshLoadingMode: .sync)

        let restoredParent = try XCTUnwrap(reverseEntityNameMap["Parent"]?.first)
        let restoredChild = try XCTUnwrap(reverseEntityNameMap["Child"]?.first)
        XCTAssertEqual(getEntityParent(entityId: restoredChild), restoredParent)
        XCTAssertEqual(getEntityChildren(parentId: restoredParent), [restoredChild])
        assertVector(getLocalPosition(entityId: restoredChild), equals: simd_float3(1.0, 0.5, 0.0))
        assertVector(getPosition(entityId: restoredParent), equals: simd_float3(3.0, 0.0, -2.0))
        // World position of the child: the parent's translation plus its own, scaled by the parent.
        assertVector(getPosition(entityId: restoredChild), equals: simd_float3(5.0, 1.0, -2.0))
        XCTAssertFalse(anyTransformDirty, "the transforms were applied with the calls that update the world matrix at once")
    }
}
