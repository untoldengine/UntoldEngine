//
//  SceneBuilderNodeTests.swift
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

/// Covers the scene builder DSL pieces that don't need a Metal device:
/// the result builder, Node identity/parenting, transform modifiers, and
/// CameraNode.
@MainActor
final class SceneBuilderNodeTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        Logger.logLevel = .none
    }

    // MARK: - Result builder

    @SceneBuilder private func makeMixedBlock(includeExtra: Bool) -> [any NodeProtocol] {
        Node(name: "first")
        for index in 0 ..< 3 {
            Node(name: "loop\(index)")
        }
        if includeExtra {
            Node(name: "extra")
        }
    }

    func testBuilderMixesSingleNodesAndLoops() {
        let nodes = makeMixedBlock(includeExtra: false)

        XCTAssertEqual(nodes.count, 4, "One single node plus a 3-iteration loop should yield 4 nodes")
        XCTAssertEqual(getEntityName(entityId: nodes[0].entityID), "first")
        XCTAssertEqual(getEntityName(entityId: nodes[1].entityID), "loop0")
        XCTAssertEqual(getEntityName(entityId: nodes[3].entityID), "loop2")
    }

    func testBuilderSupportsConditionals() {
        let withExtra = makeMixedBlock(includeExtra: true)
        XCTAssertEqual(withExtra.count, 5)
        XCTAssertEqual(getEntityName(entityId: withExtra[4].entityID), "extra")
    }

    func testEmptyBlockBuildsNoNodes() {
        let node = Node(name: "parent") {}
        XCTAssertTrue(node.subNodes.isEmpty)
    }

    // MARK: - Node

    func testNodeCreatesEntity() {
        let node = Node()
        XCTAssertTrue(scene.exists(node.entityID))
    }

    func testNodeWrapsExistingEntity() {
        let existing = createEntity()
        let node = Node(entityID: existing)
        XCTAssertEqual(node.entityID, existing)
    }

    func testNodeAssignsName() {
        let node = Node(name: "Hero")
        XCTAssertEqual(getEntityName(entityId: node.entityID), "Hero")
    }

    func testNodeParentsDeclaredChildren() {
        let child = Node(name: "child")
        let parent = Node(name: "parent") { child }

        XCTAssertEqual(parent.subNodes.count, 1)
        XCTAssertEqual(getEntityParent(entityId: child.entityID), parent.entityID)
    }

    // MARK: - Transform modifiers

    func testTranslateToIsIdempotent() {
        let node = Node().registerTransformComponent()

        _ = node.translateTo(x: 1, y: 2, z: 3)
        _ = node.translateTo(x: 1, y: 2, z: 3)

        XCTAssertEqual(getLocalPosition(entityId: node.entityID), simd_float3(1, 2, 3),
                       "translateTo must set an absolute position so re-evaluating a scene body doesn't drift")
    }

    func testTranslateByAccumulates() {
        let node = Node().registerTransformComponent()

        _ = node.translateBy(x: 1, y: 0, z: 0)
        _ = node.translateBy(x: 1, y: 0, z: 0)

        XCTAssertEqual(getLocalPosition(entityId: node.entityID), simd_float3(2, 0, 0))
    }

    // MARK: - CameraNode

    func testCameraNodeDefaultsToGameCamera() {
        let camera = CameraNode()

        XCTAssertTrue(hasComponent(entityId: camera.entityID, componentType: CameraComponent.self))
        XCTAssertEqual(CameraSystem.shared.activeCamera, camera.entityID)
    }

    func testCameraNodeReusesActiveGameCamera() {
        let first = CameraNode()
        let second = CameraNode()

        XCTAssertEqual(first.entityID, second.entityID,
                       "Declaring CameraNode() twice should wrap the same game camera, not create a second one")
    }

    func testCameraNodeCreatesCameraComponentForPlainEntity() {
        let entity = createEntity()
        XCTAssertFalse(hasComponent(entityId: entity, componentType: CameraComponent.self))

        let camera = CameraNode(entityID: entity)

        XCTAssertEqual(camera.entityID, entity)
        XCTAssertTrue(hasComponent(entityId: entity, componentType: CameraComponent.self),
                      "CameraNode(entityID:) must create the camera component when missing, like the light nodes do")
        XCTAssertEqual(CameraSystem.shared.activeCamera, entity)
    }

    func testCameraNodePreservesCustomNameWhenPromotingEntity() {
        let entity = createEntity()
        _ = CameraNode(entityID: entity, name: "Chase Cam")

        XCTAssertEqual(getEntityName(entityId: entity), "Chase Cam")
    }

    func testCameraNodeLookAtAppliesToPromotedEntity() throws {
        let entity = createEntity()
        let eye = simd_float3(0, 1, 2.7)
        let target = simd_float3(0, 0.5, 0)

        _ = CameraNode(entityID: entity).lookAt(eye: eye, target: target)

        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: entity))
        XCTAssertEqual(cameraComponent.eye, eye)
        XCTAssertEqual(cameraComponent.target, target)
        XCTAssertEqual(getCameraPosition(entityId: entity), eye)
    }

    func testCameraNodeLookAtOnDefaultCamera() throws {
        let camera = CameraNode().lookAt(eye: simd_float3(0, 0, 5))

        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera.entityID))
        XCTAssertEqual(cameraComponent.eye, simd_float3(0, 0, 5))
        XCTAssertEqual(cameraComponent.target, .zero)
    }
}
