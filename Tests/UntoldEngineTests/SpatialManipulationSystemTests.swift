//
//  SpatialManipulationSystemTests.swift
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

#if os(visionOS)
    final class SpatialManipulationSystemTests: XCTestCase {
        private var parentEntity: EntityID!
        private var childEntity: EntityID!
        private var standaloneEntity: EntityID!

        override func setUp() {
            super.setUp()
            xrInputSingletonTestLock.lock()

            parentEntity = createEntity()
            childEntity = createEntity()
            standaloneEntity = createEntity()

            registerManipulationEntity(parentEntity)
            registerManipulationEntity(childEntity)
            registerManipulationEntity(standaloneEntity)

            setParent(childId: childEntity, parentId: parentEntity)

            scaleTo(entityId: parentEntity, scale: simd_float3(1, 1, 1))
            scaleTo(entityId: childEntity, scale: simd_float3(1, 1, 1))
            scaleTo(entityId: standaloneEntity, scale: simd_float3(1, 1, 1))

            SpatialManipulationSystem.shared.reset()
            InputSystem.shared.xrSpatialInputState = XRSpatialInputState()
        }

        override func tearDown() {
            SpatialManipulationSystem.shared.reset()
            InputSystem.shared.xrSpatialInputState = XRSpatialInputState()

            destroyEntity(entityId: childEntity)
            destroyEntity(entityId: parentEntity)
            destroyEntity(entityId: standaloneEntity)

            xrInputSingletonTestLock.unlock()
            super.tearDown()
        }

        func test_applyTwoHandZoomIfNeeded_scalesParentOfPickedEntity() {
            scaleTo(entityId: parentEntity, scale: simd_float3(2, 1, 0.5))
            scaleTo(entityId: childEntity, scale: simd_float3(1, 1, 1))

            let state = makeTwoHandZoomState(
                pickedEntityId: childEntity,
                zoomDelta: 0.25,
                zoomActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)

            let parentScale = getScale(entityId: parentEntity)
            let childScale = getScale(entityId: childEntity)

            XCTAssertEqual(parentScale.x, 2.5, accuracy: 0.0001)
            XCTAssertEqual(parentScale.y, 1.25, accuracy: 0.0001)
            XCTAssertEqual(parentScale.z, 0.625, accuracy: 0.0001)
            XCTAssertEqual(childScale, simd_float3(1, 1, 1))
        }

        func test_applyTwoHandZoomIfNeeded_fallsBackToPickedEntityWhenNoParent() {
            scaleTo(entityId: standaloneEntity, scale: simd_float3(1, 1, 1))

            let state = makeTwoHandZoomState(
                pickedEntityId: standaloneEntity,
                zoomDelta: 0.2,
                zoomActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)

            let scale = getScale(entityId: standaloneEntity)
            XCTAssertEqual(scale.x, 1.2, accuracy: 0.0001)
            XCTAssertEqual(scale.y, 1.2, accuracy: 0.0001)
            XCTAssertEqual(scale.z, 1.2, accuracy: 0.0001)
        }

        func test_applyTwoHandZoomIfNeeded_usesExplicitEntityId() {
            scaleTo(entityId: parentEntity, scale: simd_float3(1, 1, 1))
            scaleTo(entityId: childEntity, scale: simd_float3(1, 1, 1))

            let state = makeTwoHandZoomState(
                pickedEntityId: childEntity,
                zoomDelta: 0.25,
                zoomActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(
                from: state,
                entityId: childEntity,
                sensitivity: 1.0
            )

            let parentScale = getScale(entityId: parentEntity)
            let childScale = getScale(entityId: childEntity)
            XCTAssertEqual(parentScale, simd_float3(1, 1, 1))
            XCTAssertEqual(childScale, simd_float3(1.25, 1.25, 1.25))
        }

        func test_applyTwoHandZoomIfNeeded_clampsToConfiguredBounds() {
            scaleTo(entityId: standaloneEntity, scale: simd_float3(19, 19, 19))
            var state = makeTwoHandZoomState(
                pickedEntityId: standaloneEntity,
                zoomDelta: 0.5,
                zoomActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)

            var scale = getScale(entityId: standaloneEntity)
            XCTAssertEqual(scale.x, SpatialManipulationSystem.shared.maxZoomScale, accuracy: 0.0001)
            XCTAssertEqual(scale.y, SpatialManipulationSystem.shared.maxZoomScale, accuracy: 0.0001)
            XCTAssertEqual(scale.z, SpatialManipulationSystem.shared.maxZoomScale, accuracy: 0.0001)

            scaleTo(entityId: standaloneEntity, scale: simd_float3(0.06, 0.06, 0.06))
            state = makeTwoHandZoomState(
                pickedEntityId: standaloneEntity,
                zoomDelta: -0.5,
                zoomActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)

            scale = getScale(entityId: standaloneEntity)
            XCTAssertEqual(scale.x, SpatialManipulationSystem.shared.minZoomScale, accuracy: 0.0001)
            XCTAssertEqual(scale.y, SpatialManipulationSystem.shared.minZoomScale, accuracy: 0.0001)
            XCTAssertEqual(scale.z, SpatialManipulationSystem.shared.minZoomScale, accuracy: 0.0001)
        }

        func test_applyTwoHandZoomIfNeeded_doesNothingWhenZoomIsInactive() {
            scaleTo(entityId: standaloneEntity, scale: simd_float3(1, 1, 1))

            let state = makeTwoHandZoomState(
                pickedEntityId: standaloneEntity,
                zoomDelta: 0.7,
                zoomActive: false
            )
            SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)

            XCTAssertEqual(getScale(entityId: standaloneEntity), simd_float3(1, 1, 1))
        }

        func test_applyTwoHandRotateIfNeeded_rotatesParentOfPickedEntity() {
            rotateTo(entityId: parentEntity, rotation: simd_float4x4.identity)
            rotateTo(entityId: childEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: childEntity,
                rotateDeltaRadians: 0.1,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: state)

            let parentRotation = getLocalOrientation(entityId: parentEntity)
            let expectedRotation = transformQuaternionToMatrix3x3(q: simd_quatf(angle: 0.1, axis: simd_float3(0, 1, 0)))
            assertMatrixApproximatelyEqual(parentRotation, expectedRotation, accuracy: 0.0001)
            XCTAssertEqual(getLocalOrientation(entityId: childEntity), simd_float3x3(1))
        }

        func test_applyTwoHandRotateIfNeeded_usesExplicitEntityId() {
            rotateTo(entityId: parentEntity, rotation: simd_float4x4.identity)
            rotateTo(entityId: childEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: childEntity,
                rotateDeltaRadians: 0.1,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
                from: state,
                entityId: childEntity,
                sensitivity: 1.0
            )

            let childRotation = getLocalOrientation(entityId: childEntity)
            let expectedRotation = transformQuaternionToMatrix3x3(q: simd_quatf(angle: 0.1, axis: simd_float3(0, 1, 0)))
            assertMatrixApproximatelyEqual(childRotation, expectedRotation, accuracy: 0.0001)
            XCTAssertEqual(getLocalOrientation(entityId: parentEntity), simd_float3x3(1))
        }

        func test_applyTwoHandRotateIfNeeded_fallsBackToPickedEntityWhenNoParent() {
            rotateTo(entityId: standaloneEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.08,
                rotateAxisWorld: simd_float3(0, 0, 1),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: state)

            let rotation = getLocalOrientation(entityId: standaloneEntity)
            let expectedRotation = transformQuaternionToMatrix3x3(q: simd_quatf(angle: 0.08, axis: simd_float3(0, 0, 1)))
            assertMatrixApproximatelyEqual(rotation, expectedRotation, accuracy: 0.0001)
        }

        func test_applyTwoHandRotateIfNeeded_clampsDeltaToConfiguredBounds() {
            rotateTo(entityId: standaloneEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 1.0,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: state)

            let rotation = getLocalOrientation(entityId: standaloneEntity)
            let expected = transformQuaternionToMatrix3x3(
                q: simd_quatf(angle: SpatialManipulationSystem.shared.maxTwoHandRotationDeltaPerFrameRadians, axis: simd_float3(0, 1, 0))
            )
            assertMatrixApproximatelyEqual(rotation, expected, accuracy: 0.0001)
        }

        func test_applyTwoHandRotateIfNeeded_usesAxisOverrideWorld() {
            rotateTo(entityId: standaloneEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.1,
                rotateAxisWorld: simd_float3(0, 0, 1),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
                from: state,
                sensitivity: 1.0,
                axisOverrideWorld: simd_float3(0, 1, 0)
            )

            let rotation = getLocalOrientation(entityId: standaloneEntity)
            let expected = transformQuaternionToMatrix3x3(q: simd_quatf(angle: 0.1, axis: simd_float3(0, 1, 0)))
            assertMatrixApproximatelyEqual(rotation, expected, accuracy: 0.0001)
        }

        func test_applyTwoHandRotateIfNeeded_appliesSensitivity() {
            rotateTo(entityId: standaloneEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.05,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: state, sensitivity: 2.0)

            let rotation = getLocalOrientation(entityId: standaloneEntity)
            let expected = transformQuaternionToMatrix3x3(q: simd_quatf(angle: 0.1, axis: simd_float3(0, 1, 0)))
            assertMatrixApproximatelyEqual(rotation, expected, accuracy: 0.0001)
        }

        func test_applyTwoHandRotateIfNeeded_accumulatesAcrossGestureBursts() {
            rotateTo(entityId: standaloneEntity, rotation: simd_float4x4.identity)

            let firstState = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.1,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: firstState)

            let inactiveState = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.0,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: false
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: inactiveState)

            let secondState = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.1,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: secondState)

            let rotation = getLocalOrientation(entityId: standaloneEntity)
            let expected = transformQuaternionToMatrix3x3(q: simd_quatf(angle: 0.2, axis: simd_float3(0, 1, 0)))
            assertMatrixApproximatelyEqual(rotation, expected, accuracy: 0.0001)
        }

        func test_applyTwoHandRotateIfNeeded_appliesWorldAxisWhenTargetHasRotatedParent() {
            let grandParent = createEntity()
            defer { destroyEntity(entityId: grandParent) }
            registerManipulationEntity(grandParent)
            setParent(childId: parentEntity, parentId: grandParent)

            rotateTo(entityId: grandParent, angle: 90, axis: simd_float3(1, 0, 0))
            rotateTo(entityId: parentEntity, rotation: simd_float4x4.identity)

            let initialWorld = simd_normalize(simd_quatf(getOrientation(entityId: parentEntity)))

            let state = makeTwoHandRotateState(
                pickedEntityId: childEntity,
                rotateDeltaRadians: 0.1,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: true
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
                from: state,
                sensitivity: 1.0,
                axisOverrideWorld: simd_float3(0, 1, 0)
            )

            let updatedWorld = getOrientation(entityId: parentEntity)
            let expectedWorld = transformQuaternionToMatrix3x3(
                q: simd_normalize(simd_quatf(angle: 0.1, axis: simd_float3(0, 1, 0)) * initialWorld)
            )
            assertMatrixApproximatelyEqual(updatedWorld, expectedWorld, accuracy: 0.0001)
        }

        func test_applyTwoHandRotateIfNeeded_doesNothingWhenRotateIsInactive() {
            rotateTo(entityId: standaloneEntity, rotation: simd_float4x4.identity)

            let state = makeTwoHandRotateState(
                pickedEntityId: standaloneEntity,
                rotateDeltaRadians: 0.3,
                rotateAxisWorld: simd_float3(0, 1, 0),
                rotateActive: false
            )
            SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: state)

            XCTAssertEqual(getLocalOrientation(entityId: standaloneEntity), simd_float3x3(1))
        }

        private func registerManipulationEntity(_ entityId: EntityID) {
            registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
            registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
            registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        }

        private func makeTwoHandZoomState(
            pickedEntityId: EntityID,
            zoomDelta: Float,
            zoomActive: Bool
        ) -> XRSpatialInputState {
            var state = XRSpatialInputState()
            state.leftHandPinching = true
            state.rightHandPinching = true
            state.spatialZoomActive = zoomActive
            state.pickedEntityId = pickedEntityId

            var inputState = XRSpatialInputState()
            inputState.spatialZoomDelta = zoomDelta
            InputSystem.shared.xrSpatialInputState = inputState
            return state
        }

        private func makeTwoHandRotateState(
            pickedEntityId: EntityID,
            rotateDeltaRadians: Float,
            rotateAxisWorld: simd_float3,
            rotateActive: Bool
        ) -> XRSpatialInputState {
            var state = XRSpatialInputState()
            state.leftHandPinching = true
            state.rightHandPinching = true
            state.spatialRotateActive = rotateActive
            state.pickedEntityId = pickedEntityId

            var inputState = XRSpatialInputState()
            inputState.spatialRotateDeltaRadians = rotateDeltaRadians
            inputState.spatialRotateAxisWorld = rotateAxisWorld
            InputSystem.shared.xrSpatialInputState = inputState
            return state
        }

        private func assertMatrixApproximatelyEqual(_ lhs: simd_float3x3, _ rhs: simd_float3x3, accuracy: Float) {
            XCTAssertEqual(lhs.columns.0.x, rhs.columns.0.x, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.0.y, rhs.columns.0.y, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.0.z, rhs.columns.0.z, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.1.x, rhs.columns.1.x, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.1.y, rhs.columns.1.y, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.1.z, rhs.columns.1.z, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.2.x, rhs.columns.2.x, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.2.y, rhs.columns.2.y, accuracy: accuracy)
            XCTAssertEqual(lhs.columns.2.z, rhs.columns.2.z, accuracy: accuracy)
        }
    }
#endif
