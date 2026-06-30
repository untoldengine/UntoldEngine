//
//  PSVR2InputSystemTests.swift
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

@MainActor
final class PSVR2InputSystemTests: XCTestCase {
    override func setUp() async throws {
        let input = InputSystem.shared
        input.psvr2SenseControllerState = PSVR2SenseControllerState()
        input.psvr2MotionEnabled = false
        input.psvr2Motion = nil
    }

    // MARK: - PSVR2SenseControllerState default values

    func test_psvr2State_struct_defaultValues() {
        let state = PSVR2SenseControllerState()

        XCTAssertFalse(state.isConnected)

        XCTAssertFalse(state.createButtonPressed)
        XCTAssertFalse(state.homeButtonPressed)
        XCTAssertFalse(state.touchpadButtonPressed)

        XCTAssertEqual(state.touchpadX, 0)
        XCTAssertEqual(state.touchpadY, 0)
        XCTAssertFalse(state.touchpadTouched)

        XCTAssertEqual(state.leftAdaptiveTriggerValue, 0)
        XCTAssertEqual(state.rightAdaptiveTriggerValue, 0)

        XCTAssertEqual(state.motionGravityX, 0)
        XCTAssertEqual(state.motionGravityY, 0)
        XCTAssertEqual(state.motionGravityZ, 0)
        XCTAssertEqual(state.motionRotationRateX, 0)
        XCTAssertEqual(state.motionRotationRateY, 0)
        XCTAssertEqual(state.motionRotationRateZ, 0)
    }

    func test_psvr2StateOnInputSystem_defaultValues() {
        let state = InputSystem.shared.psvr2SenseControllerState

        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.createButtonPressed)
        XCTAssertFalse(state.homeButtonPressed)
        XCTAssertFalse(state.touchpadButtonPressed)
        XCTAssertFalse(state.touchpadTouched)
        XCTAssertEqual(state.touchpadX, 0)
        XCTAssertEqual(state.touchpadY, 0)
        XCTAssertEqual(state.leftAdaptiveTriggerValue, 0)
        XCTAssertEqual(state.rightAdaptiveTriggerValue, 0)
    }

    func test_psvr2MotionEnabled_defaultsFalse() {
        XCTAssertFalse(InputSystem.shared.psvr2MotionEnabled)
    }

    // MARK: - Button fields

    func test_psvr2State_buttons_flipIndependently() {
        var state = PSVR2SenseControllerState()

        state.createButtonPressed = true
        XCTAssertTrue(state.createButtonPressed)
        XCTAssertFalse(state.homeButtonPressed)
        XCTAssertFalse(state.touchpadButtonPressed)

        state.homeButtonPressed = true
        XCTAssertTrue(state.createButtonPressed)
        XCTAssertTrue(state.homeButtonPressed)
        XCTAssertFalse(state.touchpadButtonPressed)

        state.touchpadButtonPressed = true
        XCTAssertTrue(state.createButtonPressed)
        XCTAssertTrue(state.homeButtonPressed)
        XCTAssertTrue(state.touchpadButtonPressed)

        state.createButtonPressed = false
        XCTAssertFalse(state.createButtonPressed)
        XCTAssertTrue(state.homeButtonPressed)
        XCTAssertTrue(state.touchpadButtonPressed)
    }

    // MARK: - Touchpad surface

    func test_psvr2State_touchpad_positionAndTouched() {
        var state = PSVR2SenseControllerState()

        state.touchpadX = 0.75
        state.touchpadY = -0.5
        state.touchpadTouched = true

        XCTAssertEqual(state.touchpadX, 0.75, accuracy: 0.0001)
        XCTAssertEqual(state.touchpadY, -0.5, accuracy: 0.0001)
        XCTAssertTrue(state.touchpadTouched)

        state.touchpadX = -1.0
        state.touchpadY = 1.0
        XCTAssertEqual(state.touchpadX, -1.0, accuracy: 0.0001)
        XCTAssertEqual(state.touchpadY, 1.0, accuracy: 0.0001)

        state.touchpadTouched = false
        XCTAssertFalse(state.touchpadTouched)
    }

    // MARK: - Adaptive trigger values

    func test_psvr2State_adaptiveTriggers_trackIndependently() {
        var state = PSVR2SenseControllerState()

        state.leftAdaptiveTriggerValue = 0.3
        state.rightAdaptiveTriggerValue = 0.9

        XCTAssertEqual(state.leftAdaptiveTriggerValue, 0.3, accuracy: 0.0001)
        XCTAssertEqual(state.rightAdaptiveTriggerValue, 0.9, accuracy: 0.0001)

        state.leftAdaptiveTriggerValue = 1.0
        XCTAssertEqual(state.leftAdaptiveTriggerValue, 1.0, accuracy: 0.0001)
        XCTAssertEqual(state.rightAdaptiveTriggerValue, 0.9, accuracy: 0.0001)
    }

    // MARK: - Motion fields

    func test_psvr2State_motionFields_gravityAndRotationRate() {
        var state = PSVR2SenseControllerState()

        state.motionGravityX = 0.1
        state.motionGravityY = -9.8
        state.motionGravityZ = 0.05
        state.motionRotationRateX = 0.3
        state.motionRotationRateY = -0.1
        state.motionRotationRateZ = 0.7

        XCTAssertEqual(state.motionGravityX, 0.1, accuracy: 0.0001)
        XCTAssertEqual(state.motionGravityY, -9.8, accuracy: 0.0001)
        XCTAssertEqual(state.motionGravityZ, 0.05, accuracy: 0.0001)
        XCTAssertEqual(state.motionRotationRateX, 0.3, accuracy: 0.0001)
        XCTAssertEqual(state.motionRotationRateY, -0.1, accuracy: 0.0001)
        XCTAssertEqual(state.motionRotationRateZ, 0.7, accuracy: 0.0001)
    }

    // MARK: - State reset

    func test_psvr2State_reset_clearsAllFields() {
        var state = PSVR2SenseControllerState()
        state.isConnected = true
        state.createButtonPressed = true
        state.homeButtonPressed = true
        state.touchpadButtonPressed = true
        state.touchpadX = 0.5
        state.touchpadY = -0.3
        state.touchpadTouched = true
        state.leftAdaptiveTriggerValue = 0.8
        state.rightAdaptiveTriggerValue = 0.6
        state.motionGravityX = 1.0
        state.motionGravityY = -9.8
        state.motionGravityZ = 0.2
        state.motionRotationRateX = 0.4
        state.motionRotationRateY = 0.1
        state.motionRotationRateZ = -0.3

        state = PSVR2SenseControllerState()

        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.createButtonPressed)
        XCTAssertFalse(state.homeButtonPressed)
        XCTAssertFalse(state.touchpadButtonPressed)
        XCTAssertEqual(state.touchpadX, 0)
        XCTAssertEqual(state.touchpadY, 0)
        XCTAssertFalse(state.touchpadTouched)
        XCTAssertEqual(state.leftAdaptiveTriggerValue, 0)
        XCTAssertEqual(state.rightAdaptiveTriggerValue, 0)
        XCTAssertEqual(state.motionGravityX, 0)
        XCTAssertEqual(state.motionGravityY, 0)
        XCTAssertEqual(state.motionGravityZ, 0)
        XCTAssertEqual(state.motionRotationRateX, 0)
        XCTAssertEqual(state.motionRotationRateY, 0)
        XCTAssertEqual(state.motionRotationRateZ, 0)
    }

    // MARK: - Simulated connect / disconnect lifecycle

    func test_psvr2_simulatedConnect_setsIsConnectedAndState() {
        let input = InputSystem.shared

        // Simulate what configurePSVR2IfNeeded would do on a real connect
        input.psvr2SenseControllerState = PSVR2SenseControllerState()
        input.psvr2SenseControllerState.isConnected = true

        XCTAssertTrue(input.psvr2SenseControllerState.isConnected)
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.homeButtonPressed)
    }

    func test_psvr2_simulatedDisconnect_resetsAllState() {
        let input = InputSystem.shared

        // Simulate a live session with some active state
        input.psvr2SenseControllerState.isConnected = true
        input.psvr2SenseControllerState.createButtonPressed = true
        input.psvr2SenseControllerState.touchpadX = 0.4
        input.psvr2SenseControllerState.leftAdaptiveTriggerValue = 0.7
        input.psvr2SenseControllerState.motionGravityY = -9.8

        // Simulate what clearPSVR2IfNeeded does when the controller disconnects
        input.psvr2SenseControllerState = PSVR2SenseControllerState()

        XCTAssertFalse(input.psvr2SenseControllerState.isConnected)
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.leftAdaptiveTriggerValue, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, 0)
    }

    func test_psvr2MotionEnabled_canBeToggled() {
        let input = InputSystem.shared

        XCTAssertFalse(input.psvr2MotionEnabled)

        input.psvr2MotionEnabled = true
        XCTAssertTrue(input.psvr2MotionEnabled)

        input.psvr2MotionEnabled = false
        XCTAssertFalse(input.psvr2MotionEnabled)
    }

    // MARK: - M2: Button & touchpad handler logic

    func test_applyTouchpadSurface_touchedWhenXAboveEpsilon() {
        let input = InputSystem.shared
        input.applyTouchpadSurface(x: 0.5, y: 0.0)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadTouched)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, 0.5, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadY, 0.0, accuracy: 0.0001)
    }

    func test_applyTouchpadSurface_touchedWhenYAboveEpsilon() {
        let input = InputSystem.shared
        input.applyTouchpadSurface(x: 0.0, y: -0.8)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadTouched)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, 0.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadY, -0.8, accuracy: 0.0001)
    }

    func test_applyTouchpadSurface_notTouchedAtCenter() {
        let input = InputSystem.shared
        input.applyTouchpadSurface(x: 0.0, y: 0.0)
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadTouched)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, 0.0)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadY, 0.0)
    }

    func test_applyTouchpadSurface_notTouchedBelowEpsilon() {
        let input = InputSystem.shared
        // Values below psvr2TouchpadEpsilon (0.01) must not set touchedTouched
        input.applyTouchpadSurface(x: 0.005, y: 0.005)
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadTouched)
    }

    func test_applyTouchpadSurface_clearsWhenReturnsToCenter() {
        let input = InputSystem.shared
        input.applyTouchpadSurface(x: 0.6, y: 0.3)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadTouched)

        input.applyTouchpadSurface(x: 0.0, y: 0.0)
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadTouched)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, 0.0)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadY, 0.0)
    }

    func test_applyTouchpadSurface_extremeCorners() {
        let input = InputSystem.shared

        input.applyTouchpadSurface(x: 1.0, y: 1.0)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, 1.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadY, 1.0, accuracy: 0.0001)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadTouched)

        input.applyTouchpadSurface(x: -1.0, y: -1.0)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadX, -1.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.touchpadY, -1.0, accuracy: 0.0001)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadTouched)
    }

    func test_psvr2_createButton_pressReleaseCycle() {
        let input = InputSystem.shared
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)

        // Simulate handler firing on press
        input.psvr2SenseControllerState.createButtonPressed = true
        XCTAssertTrue(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.homeButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadButtonPressed)

        // Simulate handler firing on release
        input.psvr2SenseControllerState.createButtonPressed = false
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
    }

    func test_psvr2_homeButton_pressReleaseCycle() {
        let input = InputSystem.shared
        XCTAssertFalse(input.psvr2SenseControllerState.homeButtonPressed)

        input.psvr2SenseControllerState.homeButtonPressed = true
        XCTAssertTrue(input.psvr2SenseControllerState.homeButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadButtonPressed)

        input.psvr2SenseControllerState.homeButtonPressed = false
        XCTAssertFalse(input.psvr2SenseControllerState.homeButtonPressed)
    }

    func test_psvr2_touchpadButton_pressReleaseCycle() {
        let input = InputSystem.shared
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadButtonPressed)

        input.psvr2SenseControllerState.touchpadButtonPressed = true
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.homeButtonPressed)

        input.psvr2SenseControllerState.touchpadButtonPressed = false
        XCTAssertFalse(input.psvr2SenseControllerState.touchpadButtonPressed)
    }

    func test_psvr2_buttons_doNotCrossContaminate() {
        let input = InputSystem.shared

        input.psvr2SenseControllerState.createButtonPressed = true
        input.psvr2SenseControllerState.homeButtonPressed = true
        input.psvr2SenseControllerState.touchpadButtonPressed = true

        // Releasing one must not clear the others
        input.psvr2SenseControllerState.createButtonPressed = false
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertTrue(input.psvr2SenseControllerState.homeButtonPressed)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadButtonPressed)

        input.psvr2SenseControllerState.homeButtonPressed = false
        XCTAssertFalse(input.psvr2SenseControllerState.createButtonPressed)
        XCTAssertFalse(input.psvr2SenseControllerState.homeButtonPressed)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadButtonPressed)
    }

    func test_applyTouchpadSurface_doesNotAffectButtons() {
        let input = InputSystem.shared
        input.psvr2SenseControllerState.touchpadButtonPressed = true

        input.applyTouchpadSurface(x: 0.5, y: 0.3)

        // Surface update must not clear the click state
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadButtonPressed)
        XCTAssertTrue(input.psvr2SenseControllerState.touchpadTouched)
    }

    // MARK: - M3: PSVR2TriggerEffect enum

    func test_psvr2TriggerEffect_offEquality() {
        XCTAssertEqual(PSVR2TriggerEffect.off, PSVR2TriggerEffect.off)
    }

    func test_psvr2TriggerEffect_feedbackEquality() {
        let a = PSVR2TriggerEffect.feedback(startPosition: 0.2, strength: 0.8)
        let b = PSVR2TriggerEffect.feedback(startPosition: 0.2, strength: 0.8)
        let c = PSVR2TriggerEffect.feedback(startPosition: 0.5, strength: 0.8)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_psvr2TriggerEffect_weaponEquality() {
        let a = PSVR2TriggerEffect.weapon(startPosition: 0.1, endPosition: 0.9, strength: 1.0)
        let b = PSVR2TriggerEffect.weapon(startPosition: 0.1, endPosition: 0.9, strength: 1.0)
        let c = PSVR2TriggerEffect.weapon(startPosition: 0.2, endPosition: 0.9, strength: 1.0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_psvr2TriggerEffect_vibrationEquality() {
        let a = PSVR2TriggerEffect.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 10.0)
        let b = PSVR2TriggerEffect.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 10.0)
        let c = PSVR2TriggerEffect.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 20.0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_psvr2TriggerEffect_slopeFeedbackEquality() {
        let a = PSVR2TriggerEffect.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.2, endStrength: 0.8)
        let b = PSVR2TriggerEffect.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.2, endStrength: 0.8)
        let c = PSVR2TriggerEffect.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.3, endStrength: 0.8)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_psvr2TriggerEffect_differentCasesNotEqual() {
        XCTAssertNotEqual(PSVR2TriggerEffect.off, PSVR2TriggerEffect.feedback(startPosition: 0, strength: 0))
        XCTAssertNotEqual(
            PSVR2TriggerEffect.feedback(startPosition: 0, strength: 0),
            PSVR2TriggerEffect.weapon(startPosition: 0, endPosition: 1, strength: 0)
        )
    }

    // MARK: - M3: setLeftTriggerEffect / setRightTriggerEffect when disconnected

    func test_setLeftTriggerEffect_noCrashWhenDisconnected() {
        let input = InputSystem.shared
        // psvr2LeftTrigger is nil (no hardware); calling must not crash
        input.setLeftTriggerEffect(.off)
        input.setLeftTriggerEffect(.feedback(startPosition: 0.3, strength: 0.7))
        input.setLeftTriggerEffect(.weapon(startPosition: 0.2, endPosition: 0.8, strength: 1.0))
        input.setLeftTriggerEffect(.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 15.0))
        input.setLeftTriggerEffect(.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.2, endStrength: 1.0))
    }

    func test_setRightTriggerEffect_noCrashWhenDisconnected() {
        let input = InputSystem.shared
        // psvr2RightTrigger is nil (no hardware); calling must not crash
        input.setRightTriggerEffect(.off)
        input.setRightTriggerEffect(.feedback(startPosition: 0.3, strength: 0.7))
        input.setRightTriggerEffect(.weapon(startPosition: 0.2, endPosition: 0.8, strength: 1.0))
        input.setRightTriggerEffect(.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 15.0))
        input.setRightTriggerEffect(.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.2, endStrength: 1.0))
    }

    // MARK: - M3: Adaptive trigger value state fields

    func test_psvr2_adaptiveTriggerValues_defaultToZero() {
        let input = InputSystem.shared
        XCTAssertEqual(input.psvr2SenseControllerState.leftAdaptiveTriggerValue, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.rightAdaptiveTriggerValue, 0)
    }

    func test_psvr2_adaptiveTriggerValues_trackIndependentlyOnSystem() {
        let input = InputSystem.shared

        input.psvr2SenseControllerState.leftAdaptiveTriggerValue = 0.6
        input.psvr2SenseControllerState.rightAdaptiveTriggerValue = 0.2

        XCTAssertEqual(input.psvr2SenseControllerState.leftAdaptiveTriggerValue, 0.6, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.rightAdaptiveTriggerValue, 0.2, accuracy: 0.0001)

        // Updating left must not disturb right
        input.psvr2SenseControllerState.leftAdaptiveTriggerValue = 1.0
        XCTAssertEqual(input.psvr2SenseControllerState.leftAdaptiveTriggerValue, 1.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.rightAdaptiveTriggerValue, 0.2, accuracy: 0.0001)
    }

    func test_psvr2_adaptiveTriggerValues_resetOnDisconnect() {
        let input = InputSystem.shared
        input.psvr2SenseControllerState.leftAdaptiveTriggerValue = 0.9
        input.psvr2SenseControllerState.rightAdaptiveTriggerValue = 0.7

        // Simulate disconnect
        input.psvr2SenseControllerState = PSVR2SenseControllerState()

        XCTAssertEqual(input.psvr2SenseControllerState.leftAdaptiveTriggerValue, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.rightAdaptiveTriggerValue, 0)
    }

    // MARK: - M4: Motion sensing

    func test_applyMotionData_updatesAllFieldsWhenEnabled() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = true

        input.applyMotionData(
            gravityX: 0.1, gravityY: -9.8, gravityZ: 0.05,
            rotationRateX: 0.3, rotationRateY: -0.1, rotationRateZ: 0.7
        )

        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityX, 0.1, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, -9.8, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityZ, 0.05, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateX, 0.3, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateY, -0.1, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateZ, 0.7, accuracy: 0.0001)
    }

    func test_applyMotionData_ignoredWhenDisabled() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = false

        input.applyMotionData(
            gravityX: 1.0, gravityY: -9.8, gravityZ: 0.5,
            rotationRateX: 0.4, rotationRateY: 0.2, rotationRateZ: -0.3
        )

        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityX, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityZ, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateX, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateY, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateZ, 0)
    }

    func test_applyMotionData_toggleAtRuntime() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = true

        input.applyMotionData(
            gravityX: 0.2, gravityY: -9.5, gravityZ: 0.1,
            rotationRateX: 0.0, rotationRateY: 0.0, rotationRateZ: 0.0
        )
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, -9.5, accuracy: 0.0001)

        // Disable mid-session — subsequent data must be ignored
        input.psvr2MotionEnabled = false
        input.applyMotionData(
            gravityX: 99.0, gravityY: 99.0, gravityZ: 99.0,
            rotationRateX: 99.0, rotationRateY: 99.0, rotationRateZ: 99.0
        )

        // Fields must retain the last value written while enabled
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityX, 0.2, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, -9.5, accuracy: 0.0001)
        XCTAssertNotEqual(input.psvr2SenseControllerState.motionGravityX, 99.0)
    }

    func test_applyMotionData_gravityAndRotationRateIndependent() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = true

        input.applyMotionData(
            gravityX: 1.0, gravityY: 2.0, gravityZ: 3.0,
            rotationRateX: 4.0, rotationRateY: 5.0, rotationRateZ: 6.0
        )

        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityX, 1.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, 2.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityZ, 3.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateX, 4.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateY, 5.0, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateZ, 6.0, accuracy: 0.0001)
    }

    func test_applyMotionData_resetOnDisconnect() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = true
        input.applyMotionData(
            gravityX: 0.5, gravityY: -9.8, gravityZ: 0.2,
            rotationRateX: 1.0, rotationRateY: -0.5, rotationRateZ: 0.3
        )

        // Simulate disconnect
        input.psvr2SenseControllerState = PSVR2SenseControllerState()

        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityX, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityZ, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateX, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateY, 0)
        XCTAssertEqual(input.psvr2SenseControllerState.motionRotationRateZ, 0)
    }

    // MARK: - M5: Public API surface

    func test_setInput_psvr2_motionEnabled_true() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = false

        setInput(.psvr2(.motionEnabled(true)))

        XCTAssertTrue(input.psvr2MotionEnabled)
    }

    func test_setInput_psvr2_motionEnabled_false() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = true

        setInput(.psvr2(.motionEnabled(false)))

        XCTAssertFalse(input.psvr2MotionEnabled)
    }

    func test_setInput_psvr2_leftTriggerEffect_noCrashWhenDisconnected() {
        // psvr2LeftTrigger is nil; calling via the public API must not crash
        setInput(.psvr2(.leftTriggerEffect(.off)))
        setInput(.psvr2(.leftTriggerEffect(.feedback(startPosition: 0.2, strength: 0.8))))
        setInput(.psvr2(.leftTriggerEffect(.weapon(startPosition: 0.1, endPosition: 0.9, strength: 1.0))))
        setInput(.psvr2(.leftTriggerEffect(.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 20.0))))
        setInput(.psvr2(.leftTriggerEffect(.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.2, endStrength: 1.0))))
    }

    func test_setInput_psvr2_rightTriggerEffect_noCrashWhenDisconnected() {
        setInput(.psvr2(.rightTriggerEffect(.off)))
        setInput(.psvr2(.rightTriggerEffect(.feedback(startPosition: 0.3, strength: 0.6))))
    }

    func test_getPSVR2SenseState_returnsCurrentState() {
        let input = InputSystem.shared
        input.psvr2SenseControllerState.touchpadX = 0.42
        input.psvr2SenseControllerState.createButtonPressed = true

        let state = getPSVR2SenseState()

        XCTAssertEqual(state.touchpadX, 0.42, accuracy: 0.0001)
        XCTAssertTrue(state.createButtonPressed)
    }

    func test_isPSVR2SenseConnected_reflectsState() {
        let input = InputSystem.shared

        input.psvr2SenseControllerState.isConnected = false
        XCTAssertFalse(isPSVR2SenseConnected())

        input.psvr2SenseControllerState.isConnected = true
        XCTAssertTrue(isPSVR2SenseConnected())
    }

    // MARK: - M6: Integration and edge cases

    func test_setInput_motionEnabled_integratedWithApplyMotionData() {
        let input = InputSystem.shared

        // Enable via public API, then verify applyMotionData writes through
        setInput(.psvr2(.motionEnabled(true)))
        input.applyMotionData(gravityX: 0.1, gravityY: -9.8, gravityZ: 0.0,
                              rotationRateX: 0.2, rotationRateY: 0.0, rotationRateZ: -0.1)

        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, -9.8, accuracy: 0.0001)

        // Disable via public API, then verify applyMotionData is blocked
        setInput(.psvr2(.motionEnabled(false)))
        input.applyMotionData(gravityX: 99.0, gravityY: 99.0, gravityZ: 99.0,
                              rotationRateX: 99.0, rotationRateY: 99.0, rotationRateZ: 99.0)

        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, -9.8, accuracy: 0.0001)
    }

    func test_getPSVR2SenseState_returnsValueSnapshot() {
        let input = InputSystem.shared
        input.psvr2SenseControllerState.touchpadX = 0.3
        input.psvr2SenseControllerState.createButtonPressed = true

        let snapshot = getPSVR2SenseState()

        // Mutate live state after taking the snapshot
        input.psvr2SenseControllerState.touchpadX = 0.9
        input.psvr2SenseControllerState.createButtonPressed = false

        // Snapshot must be unaffected (struct copy semantics)
        XCTAssertEqual(snapshot.touchpadX, 0.3, accuracy: 0.0001)
        XCTAssertTrue(snapshot.createButtonPressed)
    }

    func test_psvr2_motionAndTriggerFields_doNotContaminate() {
        let input = InputSystem.shared
        input.psvr2MotionEnabled = true

        input.psvr2SenseControllerState.leftAdaptiveTriggerValue = 0.75
        input.psvr2SenseControllerState.rightAdaptiveTriggerValue = 0.5

        input.applyMotionData(gravityX: 1.0, gravityY: -9.8, gravityZ: 0.5,
                              rotationRateX: 0.3, rotationRateY: 0.1, rotationRateZ: -0.2)

        // Motion update must not disturb trigger values
        XCTAssertEqual(input.psvr2SenseControllerState.leftAdaptiveTriggerValue, 0.75, accuracy: 0.0001)
        XCTAssertEqual(input.psvr2SenseControllerState.rightAdaptiveTriggerValue, 0.5, accuracy: 0.0001)

        // Trigger update must not disturb motion values
        input.psvr2SenseControllerState.leftAdaptiveTriggerValue = 1.0
        XCTAssertEqual(input.psvr2SenseControllerState.motionGravityY, -9.8, accuracy: 0.0001)
    }
}
