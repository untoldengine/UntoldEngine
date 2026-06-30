//
//  InputSystem+PSVR2.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import GameController

/// Finger dead-zone for touchpad touch detection. Positions below this magnitude
/// are treated as center / no-touch to avoid floating-point noise at rest.
private let psvr2TouchpadEpsilon: Float = 0.01

// MARK: - PSVR2 Trigger Effect

/// Adaptive trigger effects for the PSVR2 Sense controller. All position and
/// strength values are normalized to [0, 1]. For `weapon` and `slopeFeedback`,
/// `endPosition` must be greater than `startPosition`.
public enum PSVR2TriggerEffect: Sendable, Equatable {
    /// Disables any active adaptive trigger effect.
    case off
    /// Constant resistive feedback from `startPosition` onwards.
    case feedback(startPosition: Float, strength: Float)
    /// Resistance builds from `startPosition` to `endPosition`, then releases —
    /// emulating the feel of pulling a trigger on a weapon.
    case weapon(startPosition: Float, endPosition: Float, strength: Float)
    /// Repeating strike vibration from `startPosition` onwards.
    case vibration(startPosition: Float, amplitude: Float, frequency: Float)
    /// Linearly interpolated feedback between `startStrength` at `startPosition`
    /// and `endStrength` at `endPosition`.
    case slopeFeedback(startPosition: Float, endPosition: Float, startStrength: Float, endStrength: Float)
}

// MARK: - PSVR2 Sense Controller State

public struct PSVR2SenseControllerState {
    public var isConnected = false

    // Buttons unique to the PSVR2 Sense (not on a generic GCExtendedGamepad)
    public var createButtonPressed = false
    public var homeButtonPressed = false
    public var touchpadButtonPressed = false

    // Touchpad surface position (−1…1 per axis); touchpadTouched is true while a finger rests on the pad
    public var touchpadX: Float = 0
    public var touchpadY: Float = 0
    public var touchpadTouched = false

    // How much resistance the adaptive trigger is currently applying (0…1)
    public var leftAdaptiveTriggerValue: Float = 0
    public var rightAdaptiveTriggerValue: Float = 0

    // Motion data — populated only when InputSystem.psvr2MotionEnabled is true
    public var motionGravityX: Float = 0
    public var motionGravityY: Float = 0
    public var motionGravityZ: Float = 0
    public var motionRotationRateX: Float = 0
    public var motionRotationRateY: Float = 0
    public var motionRotationRateZ: Float = 0

    public init() {}
}

// MARK: - InputSystem PSVR2 Hooks (called from controllerDidConnect / controllerDidDisconnect)

extension InputSystem {
    func configurePSVR2IfNeeded(_ controller: GCController) {
        guard let dualsense = controller.extendedGamepad as? GCDualSenseGamepad,
              isPSVR2SenseController(controller) else { return }
        psvr2SenseControllerState = PSVR2SenseControllerState()
        psvr2SenseControllerState.isConnected = true
        configurePSVR2Handlers(dualsense, controller: controller)
        Logger.log(message: "PSVR2 Sense controller detected and configured")
    }

    func clearPSVR2IfNeeded(_ controller: GCController) {
        guard isPSVR2SenseController(controller), psvr2SenseControllerState.isConnected else { return }
        if psvr2Motion?.sensorsRequireManualActivation == true {
            psvr2Motion?.sensorsActive = false
        }
        psvr2Motion = nil
        psvr2SenseControllerState = PSVR2SenseControllerState()
        psvr2LeftTrigger = nil
        psvr2RightTrigger = nil
    }

    /// Internal so tests can exercise the touchpadTouched inference without hardware.
    func applyTouchpadSurface(x: Float, y: Float) {
        psvr2SenseControllerState.touchpadX = x
        psvr2SenseControllerState.touchpadY = y
        psvr2SenseControllerState.touchpadTouched = abs(x) > psvr2TouchpadEpsilon || abs(y) > psvr2TouchpadEpsilon
    }

    /// Internal so tests can verify the motion opt-in guard without hardware.
    func applyMotionData(gravityX: Float, gravityY: Float, gravityZ: Float,
                         rotationRateX: Float, rotationRateY: Float, rotationRateZ: Float)
    {
        guard psvr2MotionEnabled else { return }
        psvr2SenseControllerState.motionGravityX = gravityX
        psvr2SenseControllerState.motionGravityY = gravityY
        psvr2SenseControllerState.motionGravityZ = gravityZ
        psvr2SenseControllerState.motionRotationRateX = rotationRateX
        psvr2SenseControllerState.motionRotationRateY = rotationRateY
        psvr2SenseControllerState.motionRotationRateZ = rotationRateZ
    }
}

// MARK: - Adaptive Trigger Effect API (public)

public extension InputSystem {
    /// Applies an adaptive trigger effect to the left trigger.
    /// Has no effect when no PSVR2 Sense controller is connected.
    func setLeftTriggerEffect(_ effect: PSVR2TriggerEffect) {
        guard let trigger = psvr2LeftTrigger else { return }
        applyEffect(effect, to: trigger)
    }

    /// Applies an adaptive trigger effect to the right trigger.
    /// Has no effect when no PSVR2 Sense controller is connected.
    func setRightTriggerEffect(_ effect: PSVR2TriggerEffect) {
        guard let trigger = psvr2RightTrigger else { return }
        applyEffect(effect, to: trigger)
    }
}

// MARK: - Detection & Configuration (private to this file)

private extension InputSystem {
    /// GCDualSenseGamepad : GCExtendedGamepad, so cast extendedGamepad to detect the profile.
    /// The vendor name further narrows it to the PSVR2 Sense vs a standard DualSense
    /// ("DualSense Wireless Controller").
    func isPSVR2SenseController(_ controller: GCController) -> Bool {
        guard controller.extendedGamepad is GCDualSenseGamepad else { return false }
        let vendor = controller.vendorName?.lowercased() ?? ""
        return vendor.contains("vr2") || vendor.contains("playstation vr")
    }

    func configurePSVR2Handlers(_ gamepad: GCDualSenseGamepad, controller: GCController) {
        // buttonOptions = DualSense "Create" button; buttonHome = PS button.
        // Both are nullable on GCExtendedGamepad — not all controllers expose them.
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.psvr2SenseControllerState.createButtonPressed = pressed
        }
        gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.psvr2SenseControllerState.homeButtonPressed = pressed
        }

        // Touchpad click (non-nullable on GCDualSenseGamepad)
        gamepad.touchpadButton.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.psvr2SenseControllerState.touchpadButtonPressed = pressed
        }

        // touchpadPrimary tracks the first finger's position on the pad surface.
        gamepad.touchpadPrimary.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.applyTouchpadSurface(x: xValue, y: yValue)
        }

        // Adaptive triggers: store references for later effect application,
        // then wire value handlers to track current pull depth.
        psvr2LeftTrigger = gamepad.leftTrigger
        psvr2RightTrigger = gamepad.rightTrigger

        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, value, _ in
            self?.psvr2SenseControllerState.leftAdaptiveTriggerValue = value
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, value, _ in
            self?.psvr2SenseControllerState.rightAdaptiveTriggerValue = value
        }

        // Motion — opt-in via psvr2MotionEnabled. The handler calls applyMotionData
        // which returns early when the flag is false, so toggling at runtime takes
        // effect immediately without re-connecting the controller.
        if let motion = controller.motion {
            psvr2Motion = motion
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = true
            }
            motion.valueChangedHandler = { [weak self] m in
                self?.applyMotionData(
                    gravityX: Float(m.gravity.x),
                    gravityY: Float(m.gravity.y),
                    gravityZ: Float(m.gravity.z),
                    rotationRateX: Float(m.rotationRate.x),
                    rotationRateY: Float(m.rotationRate.y),
                    rotationRateZ: Float(m.rotationRate.z)
                )
            }
        }
    }

    func applyEffect(_ effect: PSVR2TriggerEffect, to trigger: GCDualSenseAdaptiveTrigger) {
        switch effect {
        case .off:
            trigger.setModeOff()
        case let .feedback(startPosition, strength):
            trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: strength)
        case let .weapon(startPosition, endPosition, strength):
            trigger.setModeWeaponWithStartPosition(startPosition, endPosition: endPosition, resistiveStrength: strength)
        case let .vibration(startPosition, amplitude, frequency):
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: amplitude, frequency: frequency)
        case let .slopeFeedback(startPosition, endPosition, startStrength, endStrength):
            trigger.setModeSlopeFeedback(startPosition: startPosition, endPosition: endPosition, startStrength: startStrength, endStrength: endStrength)
        }
    }
}
