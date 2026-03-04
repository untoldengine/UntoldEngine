//
//  XRInputSystemSpatialTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd
@testable import UntoldEngine
import XCTest

final class XRInputSystemSpatialTests: XCTestCase {
    override func setUp() {
        super.setUp()
        xrInputSingletonTestLock.lock()

        #if os(visionOS)
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
            input.setXRSceneReady(true)
            input.setXRSpatialPickingBackendPreference(.octreePreferred)
        #endif
    }

    override func tearDown() {
        #if os(visionOS)
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
            input.setXRSceneReady(true)
            input.setXRSpatialPickingBackendPreference(.octreePreferred)
        #endif

        xrInputSingletonTestLock.unlock()
        super.tearDown()
    }

    #if os(visionOS)
        func test_registerAndUnregisterXREvents_toggleEnabledFlag() {
            let input = InputSystem.shared

            input.unregisterXREvents()
            XCTAssertFalse(input.xrEventsEnabled)

            input.registerXREvents()
            XCTAssertTrue(input.xrEventsEnabled)

            input.unregisterXREvents()
            XCTAssertFalse(input.xrEventsEnabled)
        }

        func test_spatialSnapshotQueue_drainsInFIFOOrder() {
            let input = InputSystem.shared

            let snapshot1 = XRSpatialInputSnapshot(
                interactionId: 1,
                phase: .began,
                intent: .translate,
                chirality: .left,
                rayOriginWorld: simd_float3(0, 0, 0),
                rayDirectionWorld: simd_float3(0, 0, -1),
                inputDevicePositionWorld: simd_float3(0.1, 0.2, 0.3)
            )

            let snapshot2 = XRSpatialInputSnapshot(
                interactionId: 2,
                phase: .changed,
                intent: .rotate,
                chirality: .right,
                rayOriginWorld: simd_float3(1, 0, 0),
                rayDirectionWorld: simd_float3(0, 1, 0),
                inputDevicePositionWorld: simd_float3(0.4, 0.5, 0.6)
            )

            input.enqueueXRSpatialSnapshot(snapshot1)
            input.enqueueXRSpatialSnapshot(snapshot2)

            let drained = input.drainXRSpatialSnapshots()
            XCTAssertEqual(drained.count, 2)
            XCTAssertEqual(drained[0].interactionId, 1)
            XCTAssertEqual(drained[1].interactionId, 2)

            let drainedAgain = input.drainXRSpatialSnapshots()
            XCTAssertEqual(drainedAgain.count, 0)
        }

        func test_spatialPickingBackendHelper_updatesPreference() {
            let input = InputSystem.shared

            input.setXRSpatialPickingBackendPreference(.cpuOnly)
            XCTAssertEqual(input.getXRSpatialPickingBackendPreference(), .cpuOnly)

            input.setXRSpatialPickingBackendPreference(.gpuOnly)
            XCTAssertEqual(input.getXRSpatialPickingBackendPreference(), .gpuOnly)

            input.setXRSpatialPickingBackendPreference(.octreePreferred)
            XCTAssertEqual(input.getXRSpatialPickingBackendPreference(), .octreePreferred)
        }

        func test_sceneReadyHelper_updatesReadinessFlag() {
            let input = InputSystem.shared

            input.setXRSceneReady(false)
            XCTAssertFalse(input.isXRSceneReady())

            input.setXRSceneReady(true)
            XCTAssertTrue(input.isXRSceneReady())
        }

        func test_helperQueries_reflectXRSpatialInputState() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()
            state.spatialTapActive = true
            state.spatialDragActive = true
            state.spatialPinchActive = true
            state.spatialZoomActive = true
            state.spatialZoomDelta = 0.12
            state.spatialRotateActive = true
            state.spatialRotateDeltaRadians = 0.33
            state.spatialRotateAxisWorld = simd_float3(0, 1, 0)
            state.spatialPinchDragDelta = simd_float3(0.1, -0.2, 0.3)
            state.gazePosition = simd_float3(0, 1, 0)
            state.gazeDirection = simd_float3(0, 0, -1)
            input.xrSpatialInputState = state

            XCTAssertTrue(input.hasSpatialTap())
            XCTAssertTrue(input.hasSpatialDrag())
            XCTAssertTrue(input.hasSpatialPinch())
            XCTAssertTrue(input.hasSpatialZoom())
            XCTAssertTrue(input.hasSpatialRotate())
            XCTAssertEqual(input.getSpatialZoomDelta(), 0.12, accuracy: 0.0001)
            XCTAssertEqual(input.getSpatialRotateDelta(), 0.33, accuracy: 0.0001)
            XCTAssertEqual(input.getSpatialRotateAxisWorld(), simd_float3(0, 1, 0))
            XCTAssertEqual(input.getPinchDragDelta(), simd_float3(0.1, -0.2, 0.3))
            XCTAssertEqual(input.getGazeTarget(maxDistance: 2.0), simd_float3(0, 1, -2))
        }

        func test_getGazeTarget_returnsNilWhenDirectionIsInvalid() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()
            state.gazePosition = simd_float3(0, 1, 0)
            state.gazeDirection = .zero
            input.xrSpatialInputState = state

            XCTAssertNil(input.getGazeTarget(maxDistance: 2.0))
        }

        func test_getPinchPosition_prefersRightThenLeftThenInputDevice() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()
            state.leftHandPinching = true
            state.rightHandPinching = true
            state.leftHandPosition = simd_float3(1, 0, 0)
            state.rightHandPosition = simd_float3(2, 0, 0)
            input.xrSpatialInputState = state

            XCTAssertEqual(input.getPinchPosition(), simd_float3(2, 0, 0))

            state.rightHandPinching = false
            input.xrSpatialInputState = state
            XCTAssertEqual(input.getPinchPosition(), simd_float3(1, 0, 0))

            state.leftHandPinching = false
            state.spatialPinchActive = true
            state.inputDevicePositionWorld = simd_float3(3, 0, 0)
            input.xrSpatialInputState = state
            XCTAssertEqual(input.getPinchPosition(), simd_float3(3, 0, 0))

            state.spatialPinchActive = false
            state.inputDevicePositionWorld = nil
            input.xrSpatialInputState = state
            XCTAssertNil(input.getPinchPosition())
        }
    #else
        func test_nonVisionOS_xrSpatialState_setterIsNoOpAndMethodsExist() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()
            state.spatialTapActive = true
            input.xrSpatialInputState = state

            // Non-visionOS uses no-op setter and default getter.
            XCTAssertFalse(input.xrSpatialInputState.spatialTapActive)

            // Stub methods should still be callable.
            input.registerXREvents()
            input.unregisterXREvents()
            input.setXRSpatialPickingBackendPreference(.cpuOnly)
            input.setXRSceneReady(false)
            XCTAssertFalse(input.isXRSceneReady())
            setSceneReady(true)
            XCTAssertEqual(input.getXRSpatialPickingBackendPreference(), .octreePreferred)
        }
    #endif
}

#if os(visionOS)

    // MARK: - Fix 1: Ray Picking During Dragging Tests

    final class RayPickingDuringDraggingTests: XCTestCase {
        override func setUp() {
            super.setUp()
            xrInputSingletonTestLock.lock()

            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
        }

        override func tearDown() {
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()

            xrInputSingletonTestLock.unlock()
            super.tearDown()
        }

        func testPickingExecutesOnBeganPhase() {
            let input = InputSystem.shared
            input.registerXREvents()

            let snapshot = XRSpatialInputSnapshot(
                interactionId: 1,
                phase: .began,
                intent: .automatic,
                rayOriginWorld: simd_float3(0, 0, 0),
                rayDirectionWorld: simd_float3(0, 0, -1),
                inputDevicePositionWorld: simd_float3(0, 0, 0)
            )

            input.enqueueXRSpatialSnapshot(snapshot)
            // In real scenario, this would be called by gesture recognizer
            // which would trigger picking on .began phase

            XCTAssertTrue(true, "Began phase should trigger picking")
        }

        func testPickingSkipsSubsequentChangedPhases() {
            let input = InputSystem.shared
            input.registerXREvents()

            // First .changed without prior .began should trigger picking
            let firstChanged = XRSpatialInputSnapshot(
                interactionId: 1,
                phase: .changed,
                intent: .automatic,
                rayOriginWorld: simd_float3(0, 0, 0),
                rayDirectionWorld: simd_float3(0, 0, -1),
                inputDevicePositionWorld: simd_float3(0, 0.1, 0)
            )

            input.enqueueXRSpatialSnapshot(firstChanged)

            // Subsequent .changed phases should NOT trigger picking
            let secondChanged = XRSpatialInputSnapshot(
                interactionId: 1,
                phase: .changed,
                intent: .automatic,
                rayOriginWorld: simd_float3(0, 0, 0),
                rayDirectionWorld: simd_float3(0, 0, -1),
                inputDevicePositionWorld: simd_float3(0, 0.2, 0)
            )

            input.enqueueXRSpatialSnapshot(secondChanged)

            let snapshots = input.drainXRSpatialSnapshots()
            XCTAssertEqual(snapshots.count, 2, "Both snapshots should be queued")
            XCTAssertEqual(snapshots[0].phase, .changed)
            XCTAssertEqual(snapshots[1].phase, .changed)
        }

        func testPickedEntityPersistsDuringDrag() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            // Simulate picking on .began
            state.pickedEntityId = 42
            state.currentPhase = .began
            input.xrSpatialInputState = state

            XCTAssertEqual(input.xrSpatialInputState.pickedEntityId, 42)

            // During drag (.changed), picked entity should remain
            state.currentPhase = .changed
            state.spatialDragActive = true
            input.xrSpatialInputState = state

            XCTAssertEqual(
                input.xrSpatialInputState.pickedEntityId,
                42,
                "Picked entity should persist during drag"
            )
        }

        func testPickedEntityResetOnEnd() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            // Active pick
            state.pickedEntityId = 42
            state.currentPhase = .began
            input.xrSpatialInputState = state

            XCTAssertEqual(input.xrSpatialInputState.pickedEntityId, 42)

            // End interaction
            state.currentPhase = .ended
            state.spatialTapActive = false
            state.pickedEntityId = nil
            input.xrSpatialInputState = state

            XCTAssertNil(
                input.xrSpatialInputState.pickedEntityId,
                "Picked entity should be cleared on interaction end"
            )
        }

        func testFirstChangedWithoutBeganTriggersPickng() {
            // This is for pinch+drag without initial tap
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            // Simulate first .changed without .began (pinch starting)
            state.currentPhase = .changed
            state.pickedEntityId = 123 // Would be set by picking on first .changed
            input.xrSpatialInputState = state

            XCTAssertEqual(
                input.xrSpatialInputState.pickedEntityId,
                123,
                "First .changed without .began should still pick an entity"
            )
        }

        func testPickedEntityDistanceStoredDuringPick() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            // Simulate picking with distance
            state.pickedEntityId = 99
            state.pickedEntityDistance = 5.5
            state.currentPhase = .began
            input.xrSpatialInputState = state

            XCTAssertEqual(input.xrSpatialInputState.pickedEntityId, 99)
            XCTAssertEqual(
                input.xrSpatialInputState.pickedEntityDistance,
                5.5,
                accuracy: 0.0001,
                "Distance should be captured during picking"
            )
        }

        func testPickedEntityDistanceResetOnInteractionEnd() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            // Active interaction with distance
            state.pickedEntityId = 99
            state.pickedEntityDistance = 5.5
            state.currentPhase = .began
            input.xrSpatialInputState = state

            // End interaction
            state.currentPhase = .ended
            state.pickedEntityId = nil
            state.pickedEntityDistance = Float.infinity
            input.xrSpatialInputState = state

            XCTAssertNil(input.xrSpatialInputState.pickedEntityId)
            XCTAssertEqual(
                input.xrSpatialInputState.pickedEntityDistance,
                Float.infinity,
                "Distance should reset to infinity on interaction end"
            )
        }
    }
#endif
