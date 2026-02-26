//
//  SpatialManipulationSystemTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
    }
#endif
