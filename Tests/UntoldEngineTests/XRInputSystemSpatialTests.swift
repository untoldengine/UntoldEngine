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
    #if os(visionOS)
        override func setUp() {
            super.setUp()
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
            super.tearDown()
        }

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
        }
    #endif
}
