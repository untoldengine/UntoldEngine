//
//  InputSystemExtensionsTest.swift
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
final class InputSystemExtensionsTests: XCTestCase {
    /// Reset the shared instance's mutable bits before each test
    override func setUp() async throws {
        let input = InputSystem.shared
        input.delegate = nil

        input.keyState = KeyState()
        input.gameControllerState = GameControllerState()
        input.currentGameController = nil

        input.currentPanGestureState = nil
        input.currentPinchGestureState = nil
        input.cameraControlMode = .idle

        input.mouseX = 0
        input.mouseY = 0
        input.lastMouseX = 0
        input.lastMouseY = 0
        input.mouseDeltaX = 0
        input.mouseDeltaY = 0
        input.mouseActive = false

        input.initialPanLocation = nil
        input.panDelta = .init(0, 0)
        input.scrollDelta = .init(0, 0)

        input.pinchDelta = .init(0, 0, 0)
        input.previousScale = 1

        #if os(visionOS)
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
        #endif
    }

    override func tearDown() async throws {
        #if os(visionOS)
            let input = InputSystem.shared
            input.unregisterXREvents()
            input.clearXRSpatialSnapshots()
            input.xrSpatialInputState = XRSpatialInputState()
        #endif
    }

    // MARK: - Mouse Input Tests

    func test_mouseButtonStates_inKeyState() {
        let input = InputSystem.shared

        // Verify mouse button states are part of KeyState
        XCTAssertFalse(input.keyState.leftMousePressed)
        XCTAssertFalse(input.keyState.rightMousePressed)
        XCTAssertFalse(input.keyState.middleMousePressed)

        // Simulate mouse button presses
        input.keyState.leftMousePressed = true
        XCTAssertTrue(input.keyState.leftMousePressed)
        XCTAssertFalse(input.keyState.rightMousePressed)

        input.keyState.rightMousePressed = true
        XCTAssertTrue(input.keyState.leftMousePressed)
        XCTAssertTrue(input.keyState.rightMousePressed)

        input.keyState.middleMousePressed = true
        XCTAssertTrue(input.keyState.middleMousePressed)
    }

    func test_mousePosition_tracking() {
        let input = InputSystem.shared

        // Simulate mouse movement tracking
        input.lastMouseX = 0
        input.lastMouseY = 0
        input.mouseX = 100
        input.mouseY = 200
        input.mouseDeltaX = input.mouseX - input.lastMouseX
        input.mouseDeltaY = input.mouseY - input.lastMouseY

        XCTAssertEqual(input.mouseX, 100)
        XCTAssertEqual(input.mouseY, 200)
        XCTAssertEqual(input.mouseDeltaX, 100)
        XCTAssertEqual(input.mouseDeltaY, 200)

        // Next frame
        input.lastMouseX = input.mouseX
        input.lastMouseY = input.mouseY
        input.mouseX = 150
        input.mouseY = 250
        input.mouseDeltaX = input.mouseX - input.lastMouseX
        input.mouseDeltaY = input.mouseY - input.lastMouseY

        XCTAssertEqual(input.mouseDeltaX, 50)
        XCTAssertEqual(input.mouseDeltaY, 50)
    }

    func test_mouseActive_flag() {
        let input = InputSystem.shared

        XCTAssertFalse(input.mouseActive)

        // Simulate mouse button down
        input.keyState.leftMousePressed = true
        input.mouseActive = true

        XCTAssertTrue(input.mouseActive)

        // Simulate mouse button up
        input.keyState.leftMousePressed = false
        input.mouseActive = false

        XCTAssertFalse(input.mouseActive)
    }

    func test_scrollDelta_tracking() {
        let input = InputSystem.shared

        XCTAssertEqual(input.scrollDelta, simd_float2(0, 0))

        // Simulate scroll wheel input
        input.scrollDelta.x = 10
        input.scrollDelta.y = -5

        XCTAssertEqual(input.scrollDelta.x, 10)
        XCTAssertEqual(input.scrollDelta.y, -5)

        // Reset for next frame
        input.scrollDelta = .init(0, 0)
        XCTAssertEqual(input.scrollDelta, simd_float2(0, 0))
    }

    func test_mouseOrbiting_workflow() {
        let input = InputSystem.shared

        // Initial state
        XCTAssertEqual(input.cameraControlMode, .idle)
        XCTAssertFalse(input.keyState.rightMousePressed)

        // User presses right mouse button to start orbiting
        input.keyState.rightMousePressed = true
        input.mouseActive = true
        input.cameraControlMode = .orbiting

        XCTAssertEqual(input.cameraControlMode, .orbiting)
        XCTAssertTrue(input.keyState.rightMousePressed)

        // Simulate mouse drag
        input.lastMouseX = 100
        input.lastMouseY = 100
        input.mouseX = 120
        input.mouseY = 90
        input.mouseDeltaX = input.mouseX - input.lastMouseX
        input.mouseDeltaY = input.mouseY - input.lastMouseY

        XCTAssertEqual(input.mouseDeltaX, 20)
        XCTAssertEqual(input.mouseDeltaY, -10)

        // User releases right mouse button
        input.keyState.rightMousePressed = false
        input.mouseActive = false
        input.cameraControlMode = .idle
        input.mouseDeltaX = 0
        input.mouseDeltaY = 0

        XCTAssertEqual(input.cameraControlMode, .idle)
        XCTAssertFalse(input.keyState.rightMousePressed)
    }

    // MARK: - iOS/Touch Input Tests

    func test_panGesture_stateTransitions() {
        let input = InputSystem.shared

        // Begin pan
        input.currentPanGestureState = .began
        input.initialPanLocation = CGPoint(x: 50, y: 50)
        input.mouseActive = true

        XCTAssertEqual(input.currentPanGestureState, .began)
        XCTAssertEqual(input.initialPanLocation, CGPoint(x: 50, y: 50))
        XCTAssertTrue(input.mouseActive)

        // Changed
        input.currentPanGestureState = .changed
        input.panDelta = simd_float2(10, -5)

        XCTAssertEqual(input.currentPanGestureState, .changed)
        XCTAssertEqual(input.panDelta.x, 10)
        XCTAssertEqual(input.panDelta.y, -5)

        // Ended
        input.currentPanGestureState = .ended
        input.mouseActive = false
        input.panDelta = .init(0, 0)

        XCTAssertEqual(input.currentPanGestureState, .ended)
        XCTAssertFalse(input.mouseActive)
        XCTAssertEqual(input.panDelta, simd_float2(0, 0))
    }

    func test_twoFingerPan_orbiting() {
        let input = InputSystem.shared

        // Two-finger pan begins -> orbiting mode
        input.cameraControlMode = .orbiting
        input.currentPanGestureState = .began

        XCTAssertEqual(input.cameraControlMode, .orbiting)
        XCTAssertEqual(input.currentPanGestureState, .began)

        // Pan gesture changes
        input.currentPanGestureState = .changed
        input.panDelta = simd_float2(15, 20)

        XCTAssertEqual(input.panDelta.x, 15)
        XCTAssertEqual(input.panDelta.y, 20)

        // Pan gesture ends
        input.currentPanGestureState = .ended
        input.cameraControlMode = .idle
        input.panDelta = .init(0, 0)

        XCTAssertEqual(input.cameraControlMode, .idle)
        XCTAssertEqual(input.currentPanGestureState, .ended)
    }

    func test_pinchGesture_zoom() {
        let input = InputSystem.shared

        // Begin pinch
        input.currentPinchGestureState = .began
        input.previousScale = 1.0

        XCTAssertEqual(input.currentPinchGestureState, .began)
        XCTAssertEqual(input.previousScale, 1.0)

        // Changed - pinch in
        input.currentPinchGestureState = .changed
        let currentScale: CGFloat = 0.8
        let scaleDelta = currentScale - input.previousScale
        input.pinchDelta.z = Float(scaleDelta)
        input.previousScale = currentScale

        XCTAssertEqual(input.currentPinchGestureState, .changed)
        XCTAssertEqual(input.pinchDelta.z, -0.2, accuracy: 0.001)
        XCTAssertEqual(input.previousScale, 0.8)

        // Changed - pinch out
        let newScale: CGFloat = 1.2
        let newDelta = newScale - input.previousScale
        input.pinchDelta.z = Float(newDelta)
        input.previousScale = newScale

        XCTAssertEqual(input.pinchDelta.z, 0.4, accuracy: 0.001)

        // Ended
        input.currentPinchGestureState = .ended
        input.pinchDelta = .init(0, 0, 0)
        input.previousScale = 1.0

        XCTAssertEqual(input.currentPinchGestureState, .ended)
        XCTAssertEqual(input.pinchDelta, simd_float3(0, 0, 0))
    }

    // MARK: - XR/Spatial Input Tests

    #if os(visionOS)
        func test_spatialInputState_defaults() {
            let input = InputSystem.shared
            let xrState = input.xrSpatialInputState

            XCTAssertFalse(xrState.spatialTapActive)
            XCTAssertFalse(xrState.spatialDragActive)
            XCTAssertFalse(xrState.spatialPinchActive)
            XCTAssertFalse(xrState.handTrackingActive)

            XCTAssertEqual(xrState.leftHandPosition, simd_float3.zero)
            XCTAssertEqual(xrState.rightHandPosition, simd_float3.zero)
            XCTAssertFalse(xrState.leftHandPinching)
            XCTAssertFalse(xrState.rightHandPinching)

            XCTAssertEqual(xrState.gazePosition, simd_float3.zero)
            XCTAssertEqual(xrState.gazeDirection, simd_float3.zero)
        }

        func test_spatialTap_interaction() {
            let input = InputSystem.shared

            // Simulate spatial tap
            input.xrSpatialInputState.spatialTapActive = true
            input.keyState.leftMousePressed = true
            input.mouseX = 100
            input.mouseY = 200

            XCTAssertTrue(input.xrSpatialInputState.spatialTapActive)
            XCTAssertTrue(input.keyState.leftMousePressed)
            XCTAssertEqual(input.mouseX, 100)
            XCTAssertEqual(input.mouseY, 200)

            // Reset after tap
            input.xrSpatialInputState.spatialTapActive = false
            input.keyState.leftMousePressed = false

            XCTAssertFalse(input.xrSpatialInputState.spatialTapActive)
        }

        func test_spatialDrag_orbiting() {
            let input = InputSystem.shared

            // Begin drag
            input.xrSpatialInputState.spatialDragActive = true
            input.cameraControlMode = .orbiting

            XCTAssertTrue(input.xrSpatialInputState.spatialDragActive)
            XCTAssertEqual(input.cameraControlMode, .orbiting)

            // Update drag
            input.panDelta = simd_float2(20, -15)
            input.mouseDeltaX = 20
            input.mouseDeltaY = -15

            XCTAssertEqual(input.panDelta.x, 20)
            XCTAssertEqual(input.panDelta.y, -15)

            // End drag
            input.xrSpatialInputState.spatialDragActive = false
            input.cameraControlMode = .idle
            input.panDelta = .init(0, 0)

            XCTAssertFalse(input.xrSpatialInputState.spatialDragActive)
            XCTAssertEqual(input.cameraControlMode, .idle)
        }

        func test_handTracking_states() {
            let input = InputSystem.shared

            // Enable hand tracking
            input.xrSpatialInputState.handTrackingActive = true
            input.xrSpatialInputState.leftHandPosition = simd_float3(1, 2, 3)
            input.xrSpatialInputState.rightHandPosition = simd_float3(4, 5, 6)

            XCTAssertTrue(input.xrSpatialInputState.handTrackingActive)
            XCTAssertEqual(input.xrSpatialInputState.leftHandPosition, simd_float3(1, 2, 3))
            XCTAssertEqual(input.xrSpatialInputState.rightHandPosition, simd_float3(4, 5, 6))

            // Pinching gestures
            input.xrSpatialInputState.leftHandPinching = true
            input.xrSpatialInputState.rightHandPinching = false

            XCTAssertTrue(input.xrSpatialInputState.leftHandPinching)
            XCTAssertFalse(input.xrSpatialInputState.rightHandPinching)

            // Test helper methods
            XCTAssertTrue(input.isUserPinching())
            XCTAssertEqual(input.getPinchPosition(), simd_float3(1, 2, 3))
        }

        func test_gazeTracking() {
            let input = InputSystem.shared

            // Set gaze position and direction
            input.xrSpatialInputState.gazePosition = simd_float3(0, 1.5, 0)
            input.xrSpatialInputState.gazeDirection = simd_float3(0, 0, -1)

            XCTAssertEqual(input.xrSpatialInputState.gazePosition, simd_float3(0, 1.5, 0))
            XCTAssertEqual(input.xrSpatialInputState.gazeDirection, simd_float3(0, 0, -1))

            // Test gaze target calculation
            let target = input.getGazeTarget(maxDistance: 5.0)
            XCTAssertEqual(target, simd_float3(0, 1.5, -5))
        }
    #else
        func test_xrMethods_existOnNonVisionOS() {
            let input = InputSystem.shared

            // Verify stub methods exist on non-visionOS platforms
            input.registerXREvents()
            input.unregisterXREvents()

            // No crashes - stubs work
            XCTAssertTrue(true)
        }
    #endif

    // MARK: - Cross-Platform Input State Consistency

    func test_unifiedInputState_acrossPlatforms() {
        let input = InputSystem.shared

        // All platforms share these core input properties
        XCTAssertEqual(input.mouseX, 0)
        XCTAssertEqual(input.mouseY, 0)
        XCTAssertEqual(input.mouseDeltaX, 0)
        XCTAssertEqual(input.mouseDeltaY, 0)
        XCTAssertFalse(input.mouseActive)

        XCTAssertEqual(input.panDelta, simd_float2(0, 0))
        XCTAssertEqual(input.scrollDelta, simd_float2(0, 0))
        XCTAssertEqual(input.pinchDelta, simd_float3(0, 0, 0))

        XCTAssertEqual(input.cameraControlMode, .idle)
    }

    func test_cameraControlMode_transitions() {
        let input = InputSystem.shared

        // Test all camera control modes
        input.cameraControlMode = .idle
        XCTAssertEqual(input.cameraControlMode, .idle)

        input.cameraControlMode = .orbiting
        XCTAssertEqual(input.cameraControlMode, .orbiting)

        input.cameraControlMode = .moving
        XCTAssertEqual(input.cameraControlMode, .moving)

        input.cameraControlMode = .idle
        XCTAssertEqual(input.cameraControlMode, .idle)
    }
}
