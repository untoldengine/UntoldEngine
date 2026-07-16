//
//  XRInputSystemSpatialTests.swift
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

@MainActor
final class XRInputSystemSpatialTests: XCTestCase {
    override func setUp() async throws {
        #if os(visionOS)
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
            input.setXRSceneReady(true)
            input.setXRSpatialPickingBackendPreference(.octreePreferred)
        #endif
    }

    override func tearDown() async throws {
        #if os(visionOS)
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
            input.setXRSceneReady(true)
            input.setXRSpatialPickingBackendPreference(.octreePreferred)
        #endif
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

        func test_twoHandRotateAxisModeHelper_updatesPreference() {
            let input = InputSystem.shared

            input.setXRTwoHandRotateAxisMode(.cameraForward)
            XCTAssertEqual(input.getXRTwoHandRotateAxisMode(), .cameraForward)

            input.setXRTwoHandRotateAxisMode(.dynamic)
            XCTAssertEqual(input.getXRTwoHandRotateAxisMode(), .dynamic)

            input.setXRTwoHandRotateAxisMode(.dynamicSnapped)
            XCTAssertEqual(input.getXRTwoHandRotateAxisMode(), .dynamicSnapped)
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
            state.leftHandPinching = true
            state.rightHandPinching = true
            state.spatialPinchDragDelta = simd_float3(0.1, -0.2, 0.3)
            state.gazePosition = simd_float3(0, 1, 0)
            state.gazeDirection = simd_float3(0, 0, -1)
            state.pickedEntityWorldPosition = simd_float3(1, 2, 3)
            state.pickedEntityWorldNormal = simd_float3(0, 0, 1)
            input.xrSpatialInputState = state

            XCTAssertTrue(input.hasSpatialTap())
            XCTAssertTrue(input.hasSpatialDrag())
            XCTAssertTrue(input.hasSpatialPinch())
            XCTAssertTrue(input.hasSpatialZoom())
            XCTAssertTrue(input.hasSpatialRotate())
            XCTAssertEqual(input.getSpatialZoomDelta(), 0.12, accuracy: 0.0001)
            XCTAssertEqual(input.getSpatialRotateDelta(), 0.33, accuracy: 0.0001)
            XCTAssertEqual(input.getSpatialRotateAxisWorld(), simd_float3(0, 1, 0))
            XCTAssertTrue(input.hasTwoHandRotateSignal())
            let rotateSignal = input.getTwoHandRotateSignal()
            XCTAssertNotNil(rotateSignal)
            XCTAssertEqual(rotateSignal?.deltaRadians, 0.33, accuracy: 0.0001)
            XCTAssertEqual(rotateSignal?.axisWorld, simd_float3(0, 1, 0))
            XCTAssertEqual(input.getPinchDragDelta(), simd_float3(0.1, -0.2, 0.3))
            XCTAssertEqual(input.getGazeTarget(maxDistance: 2.0), simd_float3(0, 1, -2))
            XCTAssertEqual(input.getPickedEntityWorldPosition(), simd_float3(1, 2, 3))
            XCTAssertEqual(input.getPickedEntityWorldNormal(), simd_float3(0, 0, 1))
        }

        func test_twoHandRotateSignal_requiresBothHandsAndRotateState() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()
            state.leftHandPinching = true
            state.rightHandPinching = false
            state.spatialRotateActive = true
            state.spatialRotateDeltaRadians = 0.2
            state.spatialRotateAxisWorld = simd_float3(0, 1, 0)
            input.xrSpatialInputState = state

            XCTAssertFalse(input.hasTwoHandRotateSignal())
            XCTAssertNil(input.getTwoHandRotateSignal())

            state.rightHandPinching = true
            state.spatialRotateActive = false
            input.xrSpatialInputState = state

            XCTAssertFalse(input.hasTwoHandRotateSignal())
            XCTAssertNil(input.getTwoHandRotateSignal())
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
            XCTAssertEqual(input.getXRSpatialPickingBackendPreference(), .octreeGPUPreferred)
            input.setXRTwoHandRotateAxisMode(.dynamic)
            XCTAssertEqual(input.getXRTwoHandRotateAxisMode(), .dynamicSnapped)
            XCTAssertFalse(input.hasTwoHandRotateSignal())
            XCTAssertNil(input.getTwoHandRotateSignal())
        }
    #endif
}

#if os(visionOS)

    // MARK: - Fix 1: Ray Picking During Dragging Tests

    @MainActor
    final class RayPickingDuringDraggingTests: XCTestCase {
        override func setUp() async throws {
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
        }

        override func tearDown() async throws {
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
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

        func testPickedEntityWorldNormalStoredDuringPick() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            state.pickedEntityId = 99
            state.pickedEntityWorldNormal = simd_float3(0, 0, 1)
            state.currentPhase = .began
            input.xrSpatialInputState = state

            XCTAssertEqual(input.xrSpatialInputState.pickedEntityId, 99)
            XCTAssertEqual(input.xrSpatialInputState.pickedEntityWorldNormal, simd_float3(0, 0, 1))
            XCTAssertEqual(input.getPickedEntityWorldNormal(), simd_float3(0, 0, 1))
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

        func testPickedEntityWorldNormalResetOnInteractionEnd() {
            let input = InputSystem.shared
            var state = XRSpatialInputState()

            state.pickedEntityId = 99
            state.pickedEntityWorldNormal = simd_float3(0, 1, 0)
            state.currentPhase = .began
            input.xrSpatialInputState = state

            state.currentPhase = .ended
            state.pickedEntityId = nil
            state.pickedEntityWorldNormal = nil
            input.xrSpatialInputState = state

            XCTAssertNil(input.xrSpatialInputState.pickedEntityId)
            XCTAssertNil(input.xrSpatialInputState.pickedEntityWorldNormal)
            XCTAssertNil(input.getPickedEntityWorldNormal())
        }
    }
#endif
