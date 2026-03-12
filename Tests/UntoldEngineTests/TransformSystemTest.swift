//
//  TransformSystemTest.swift
//
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
final class TransformSystemTests: XCTestCase {
    var entityId: EntityID!

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        resetEngineTestState()

        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
    }

    override func tearDown() async throws {
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()

        destroyEntity(entityId: entityId)
    }

    // MARK: - Position Tests

    func testGetLocalPosition() {
        let position = simd_float3(1.0, 2.0, 3.0)

        translateTo(entityId: entityId, position: position)
        let result = getLocalPosition(entityId: entityId)
        XCTAssertEqual(result, position)
    }

    // MARK: - Orientation Tests

    func testGetLocalOrientation() {
        let rotationMatrix = simd_float4x4(columns: (
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        ))

        rotateTo(entityId: entityId, rotation: rotationMatrix)

        let orientation = getLocalOrientation(entityId: entityId)
        let expectedOrientation = matrix3x3_upper_left(rotationMatrix)

        XCTAssertEqual(orientation, expectedOrientation)
    }

    // MARK: - Translation Tests

    func testTranslateTo() {
        let position = simd_float3(10.0, 20.0, 30.0)
        translateTo(entityId: entityId, position: position)

        let result = getLocalPosition(entityId: entityId)
        XCTAssertEqual(result, position)
    }

    func testTranslateBy() {
        translateBy(entityId: entityId, position: simd_float3(1, 2, 3))

        let result = getLocalPosition(entityId: entityId)
        XCTAssertEqual(result, simd_float3(1, 2, 3))
    }

    // MARK: - Axis Tests

    func testGetForwardAxisVector() {
        rotateTo(entityId: entityId, rotation: simd_float4x4.identity)
        let forward = getForwardAxisVector(entityId: entityId)
        XCTAssertEqual(forward, simd_float3(0, 0, 1))
    }

    func testGetRightAxisVector() {
        rotateTo(entityId: entityId, rotation: simd_float4x4.identity)
        let right = getRightAxisVector(entityId: entityId)
        XCTAssertEqual(right, simd_float3(1, 0, 0))
    }

    func testGetUpAxisVector() {
        rotateTo(entityId: entityId, rotation: simd_float4x4.identity)
        let up = getUpAxisVector(entityId: entityId)
        XCTAssertEqual(up, simd_float3(0, 1, 0))
    }

    // MARK: - Rotation Tests

    func testRotateTo() {
        let angle: Float = 90
        let axis = simd_float3(0, 1, 0)
        rotateTo(entityId: entityId, angle: angle, axis: axis)

        let result = getLocalOrientation(entityId: entityId)

        let expectedMatrix = transformQuaternionToMatrix3x3(q: simd_quatf(angle: degreesToRadians(degrees: angle), axis: axis))

        // XCTAssertEqual(result, expectedMatrix)
        XCTAssertEqual(result.columns.0.x, expectedMatrix.columns.0.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.y, expectedMatrix.columns.0.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.z, expectedMatrix.columns.0.z, accuracy: 0.01)

        XCTAssertEqual(result.columns.1.x, expectedMatrix.columns.1.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.1.y, expectedMatrix.columns.1.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.1.z, expectedMatrix.columns.1.z, accuracy: 0.01)

        XCTAssertEqual(result.columns.2.x, expectedMatrix.columns.2.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.2.y, expectedMatrix.columns.2.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.2.z, expectedMatrix.columns.2.z, accuracy: 0.01)
    }

    func testRotateBy() {
        let angle: Float = 45
        let axis = simd_float3(0, 0, 1)
        rotateBy(entityId: entityId, angle: angle, axis: axis)

        let updatedMatrix = getLocalOrientation(entityId: entityId)
        XCTAssertNotEqual(updatedMatrix, simd_float3x3(1)) // Ensure it updated
    }

    func testGetLocalOrientationEuler() {
        let angle: Float = 45.0
        let axis = simd_float3(0, 1, 0)
        rotateTo(entityId: entityId, angle: angle, axis: axis)

        let result = getLocalOrientationEuler(entityId: entityId)

        XCTAssertEqual(result.pitch, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.yaw, radiansToDegrees(radians: 0.7853981), accuracy: 0.01)
        XCTAssertEqual(result.roll, 0.0, accuracy: 0.01)
    }

    func testRotateToEuler() {
        rotateTo(entityId: entityId, pitch: 45.0, yaw: 60.0, roll: 30.0)

        let m = getLocalOrientation(entityId: entityId)

        XCTAssertEqual(m.columns.0.x, 0.4330127, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.y, 0.2500000, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.z, -0.8660254, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.1.x, 0.1767767, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.y, 0.9185587, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.z, 0.3535534, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.2.x, 0.8838835, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.y, -0.3061862, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.z, 0.3535534, accuracy: 0.001, "component should be equal")
    }

    func testApplyAxisRotation() {
        applyAxisRotations(entityId: entityId, axis: simd_float3(45.0, 0.0, 0.0))
        let m = getLocalOrientation(entityId: entityId)

        XCTAssertEqual(m.columns.0.x, 1.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.y, 0.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.z, 0.0, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.1.x, 0.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.y, 0.7071068, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.z, 0.7071068, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.2.x, 0.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.y, -0.7071068, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.z, 0.7071068, accuracy: 0.001, "component should be equal")
    }

    func testLookAtOrientsForwardTowardTarget() {
        let entity = createEntity()
        let target = createEntity()

        translateTo(entityId: entity, position: simd_float3(0, 0, 0))
        translateTo(entityId: target, position: simd_float3(0, 0, 1))

        lookAt(entityId: entity, targetPosition: getLocalPosition(entityId: target))

        let forward = getForwardAxisVector(entityId: entity)
        XCTAssertEqual(forward.x, 0, accuracy: 0.0001)
        XCTAssertEqual(forward.y, 0, accuracy: 0.0001)
        XCTAssertEqual(forward.z, 1, accuracy: 0.0001)
    }

    // MARK: - Scene Root Yaw Tests

    func testRotateSceneToYawSetsAbsoluteYaw() {
        rotateSceneToYaw(.pi / 2.0)
        SceneRootTransform.shared.updateIfNeeded()

        let rotatedForward = simd_act(SceneRootTransform.shared.rotation, simd_float3(0, 0, 1))
        XCTAssertEqual(rotatedForward.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rotatedForward.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(rotatedForward.z, 0.0, accuracy: 0.0001)
    }

    func testRotateSceneByYawAccumulatesDelta() {
        rotateSceneToYaw(0)
        rotateSceneByYaw(.pi / 4.0)
        rotateSceneByYaw(.pi / 4.0)
        SceneRootTransform.shared.updateIfNeeded()

        let rotatedForward = simd_act(SceneRootTransform.shared.rotation, simd_float3(0, 0, 1))
        XCTAssertEqual(rotatedForward.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rotatedForward.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(rotatedForward.z, 0.0, accuracy: 0.0001)
    }

    func testSceneYawComposesWithTranslationAroundSceneRootPosition() {
        translateSceneTo(position: simd_float3(10, 0, 0))
        rotateSceneToYaw(.pi / 2.0)
        SceneRootTransform.shared.updateIfNeeded()

        let localPoint = simd_float4(1, 0, 0, 1)
        let transformed = SceneRootTransform.shared.matrix * localPoint
        XCTAssertEqual(transformed.x, 10.0, accuracy: 0.0001)
        XCTAssertEqual(transformed.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(transformed.z, -1.0, accuracy: 0.0001)
    }

    func testSceneSpaceConversionRoundTrip() {
        translateSceneTo(position: simd_float3(10, 0, 0))
        rotateSceneToYaw(.pi / 2.0)
        SceneRootTransform.shared.updateIfNeeded()

        let sceneLocal = simd_float3(1, 0, 0)
        let visualWorld = sceneLocalToVisualWorld(sceneLocal)
        let roundTrip = visualWorldToSceneLocal(visualWorld)

        XCTAssertEqual(visualWorld.x, 10.0, accuracy: 0.0001)
        XCTAssertEqual(visualWorld.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(visualWorld.z, -1.0, accuracy: 0.0001)

        XCTAssertEqual(roundTrip.x, sceneLocal.x, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.y, sceneLocal.y, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.z, sceneLocal.z, accuracy: 0.0001)
    }

    func testGetVisualPositionAppliesSceneRootTransform() {
        translateTo(entityId: entityId, position: simd_float3(0, 0, 5))
        rotateSceneToYaw(.pi / 2.0)
        SceneRootTransform.shared.updateIfNeeded()

        let visualPosition = getVisualPosition(entityId: entityId)
        XCTAssertEqual(visualPosition.x, 5.0, accuracy: 0.0001)
        XCTAssertEqual(visualPosition.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(visualPosition.z, 0.0, accuracy: 0.0001)
    }

    func testResetSceneRootTransformRestoresIdentity() {
        translateSceneTo(position: simd_float3(3, 4, 5))
        rotateSceneToYaw(.pi / 3.0)
        SceneRootTransform.shared.scale = simd_float3(2, 2, 2)
        SceneRootTransform.shared.updateIfNeeded()

        resetSceneRootTransform()

        XCTAssertEqual(SceneRootTransform.shared.position, .zero)
        XCTAssertEqual(SceneRootTransform.shared.scale, .one)
        XCTAssertEqual(sceneYawRadians(from: SceneRootTransform.shared.rotation), 0.0, accuracy: 0.0001)
        XCTAssertTrue(SceneRootTransform.shared.isIdentity)
    }
}
