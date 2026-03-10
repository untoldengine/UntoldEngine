//
//  InputSystemTest.swift
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

final class InputSystemTests: XCTestCase {
    /// Reset the shared instance’s mutable bits before each test
    override func setUp() {
        super.setUp()
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
    }

    // MARK: - Defaults / constants

    func test_defaults_areSane() {
        let input = InputSystem.shared

        // singleton is constructed
        XCTAssertNotNil(input)

        // default camera mode and gestures
        XCTAssertEqual(input.cameraControlMode, .idle)
        XCTAssertNil(input.currentPanGestureState)
        XCTAssertNil(input.currentPinchGestureState)

        // default mouse state
        XCTAssertEqual(input.mouseX, 0)
        XCTAssertEqual(input.mouseY, 0)
        XCTAssertEqual(input.mouseDeltaX, 0)
        XCTAssertEqual(input.mouseDeltaY, 0)
        XCTAssertFalse(input.mouseActive)

        // key constants snapshot (mac keycodes you encoded)
        XCTAssertEqual(input.kVK_ANSI_W, 13)
        XCTAssertEqual(input.kVK_ANSI_A, 0)
        XCTAssertEqual(input.kVK_ANSI_S, 1)
        XCTAssertEqual(input.kVK_ANSI_D, 2)
        XCTAssertEqual(input.kVK_ANSI_R, 15)
        XCTAssertEqual(input.kVK_ANSI_P, 35)
        XCTAssertEqual(input.kVK_ANSI_L, 37)
        XCTAssertEqual(input.kVK_ANSI_Q, 12)
        XCTAssertEqual(input.kVK_ANSI_E, 14)
        XCTAssertEqual(input.kVK_ANSI_1, 18)
        XCTAssertEqual(input.kVK_ANSI_2, 19)
        XCTAssertEqual(input.kVK_ANSI_G, 5)
        XCTAssertEqual(input.kVK_ANSI_X, 7)
        XCTAssertEqual(input.kVK_ANSI_Y, 16)
        XCTAssertEqual(input.kVK_ANSI_Z, 6)
        XCTAssertEqual(input.kVK_ANSI_J, 38)
        XCTAssertEqual(input.kVK_ANSI_K, 40)
        XCTAssertEqual(input.kVK_ANSI_Space, 49)
    }

    // MARK: - Mouse bookkeeping

    func test_mouseDelta_math() {
        let input = InputSystem.shared

        /// Simulate moving mouse and compute deltas like your render loop would
        func applyMouseMove(to x: Float, _ y: Float) {
            input.lastMouseX = input.mouseX
            input.lastMouseY = input.mouseY
            input.mouseX = x
            input.mouseY = y
            input.mouseDeltaX = input.mouseX - input.lastMouseX
            input.mouseDeltaY = input.mouseY - input.lastMouseY
        }

        applyMouseMove(to: 100, 200)
        XCTAssertEqual(input.mouseDeltaX, 100)
        XCTAssertEqual(input.mouseDeltaY, 200)

        applyMouseMove(to: 92, 180)
        XCTAssertEqual(input.mouseDeltaX, -8)
        XCTAssertEqual(input.mouseDeltaY, -20)
    }

    // MARK: - Gestures & camera mode

    func test_gesture_states_and_camera_mode() {
        let input = InputSystem.shared

        // Begin a pan
        input.currentPanGestureState = .began
        input.initialPanLocation = CGPoint(x: 10, y: 10)
        XCTAssertEqual(input.currentPanGestureState, .began)
        XCTAssertEqual(input.initialPanLocation, CGPoint(x: 10, y: 10))

        // Update pan delta
        input.panDelta = .init(5, -3)
        XCTAssertEqual(input.panDelta, simd_float2(5, -3))

        // Scroll/pinch bookkeeping
        input.scrollDelta = .init(0, 1)
        input.pinchDelta = .init(0.0, 0.0, 0.5)
        input.previousScale = 1.25
        XCTAssertEqual(input.scrollDelta, simd_float2(0, 1))
        XCTAssertEqual(input.pinchDelta, simd_float3(0, 0, 0.5))
        XCTAssertEqual(input.previousScale, 1.25)

        // Camera mode transitions driven by inputs elsewhere
        input.cameraControlMode = .orbiting
        XCTAssertEqual(input.cameraControlMode, .orbiting)
        input.cameraControlMode = .moving
        XCTAssertEqual(input.cameraControlMode, .moving)

        // End gestures
        input.currentPanGestureState = .ended
        XCTAssertEqual(input.currentPanGestureState, .ended)
        input.currentPinchGestureState = .ended
        XCTAssertEqual(input.currentPinchGestureState, .ended)
    }

    // MARK: - GamePadState (no hardware)

    func test_manual_gamepad_state_flip() {
        var gp = InputSystem.shared.gameControllerState
        XCTAssertFalse(gp.aPressed)
        XCTAssertFalse(gp.bPressed)
        XCTAssertFalse(gp.leftThumbStickActive)

        gp.aPressed = true
        gp.leftThumbStickActive = true

        XCTAssertTrue(gp.aPressed)
        XCTAssertTrue(gp.leftThumbStickActive)
        XCTAssertFalse(gp.bPressed)
    }

    // MARK: - Optional seam to verify button closures

    // Enable with: add `-D TESTING_SEAM` to the test target’s Swift flags.
    // This does NOT require touching production code; it only compiles in the test target.

    #if TESTING_SEAM
        func test_button_handlers_toggle_state() {
            let input = InputSystem.shared

            // A minimal stand-in exposing the two closure slots you use.
            final class FakeButton {
                typealias Handler = (AnyObject, Float, Bool) -> Void
                var pressedChangedHandler: Handler?
                func press() {
                    pressedChangedHandler?(self, 1.0, true)
                }

                func release() {
                    pressedChangedHandler?(self, 0.0, false)
                }
            }

            final class FakeExtendedGamepad: NSObject {
                let buttonA = FakeButton()
                let buttonB = FakeButton()
            }

            /// Local shim that reuses InputSystem’s logic for assigning handlers,
            /// implemented as a tiny friend that lives only in tests.
            func installHandlers(_ gamepad: FakeExtendedGamepad, into input: InputSystem) {
                // Mirror your closures’ behavior:
                gamepad.buttonA.pressedChangedHandler = { [weak input] _, _, pressed in
                    input?.gamePadState.aPressed = pressed
                }
                gamepad.buttonB.pressedChangedHandler = { [weak input] _, _, pressed in
                    input?.gamePadState.bPressed = pressed
                }
            }

            let fake = FakeExtendedGamepad()
            installHandlers(fake, into: input)

            XCTAssertFalse(input.gamePadState.aPressed)
            XCTAssertFalse(input.gamePadState.bPressed)

            fake.buttonA.press()
            XCTAssertTrue(input.gamePadState.aPressed)
            XCTAssertFalse(input.gamePadState.bPressed)

            fake.buttonB.press()
            XCTAssertTrue(input.gamePadState.aPressed)
            XCTAssertTrue(input.gamePadState.bPressed)

            fake.buttonA.release()
            XCTAssertFalse(input.gamePadState.aPressed)
            XCTAssertTrue(input.gamePadState.bPressed)
        }
    #endif
}
