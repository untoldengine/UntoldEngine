//
//  InputSystem.swift
//  Untold Engine
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import GameController
import simd

public struct GameControllerState {
    public var aPressed = false
    public var bPressed = false
    public var xPressed = false
    public var yPressed = false

    public var dpadUpPressed = false
    public var dpadDownPressed = false
    public var dpadLeftPressed = false
    public var dpadRightPressed = false

    public var leftShoulderPressed = false
    public var rightShoulderPressed = false
    public var leftTriggerPressed = false
    public var rightTriggerPressed = false
    public var leftTriggerValue: Float = 0
    public var rightTriggerValue: Float = 0

    public var leftThumbstickX: Float = 0
    public var leftThumbstickY: Float = 0
    public var rightThumbstickX: Float = 0
    public var rightThumbstickY: Float = 0
    public var leftThumbStickActive = false
    public var rightThumbStickActive = false
    public var leftThumbstickPressed = false
    public var rightThumbstickPressed = false
}

public enum PanGestureState { case began, changed, ended }
public enum PinchGestureState { case began, changed, ended }
public enum CameraControlMode { case idle, orbiting, moving }

public protocol InputSystemDelegate: AnyObject {
    func didUpdateKeyState()
}

public final class InputSystem {
    public static let shared: InputSystem = .init()
    public weak var delegate: InputSystemDelegate?

    public let kVK_ANSI_W: UInt16 = 13, kVK_ANSI_A: UInt16 = 0, kVK_ANSI_S: UInt16 = 1, kVK_ANSI_D: UInt16 = 2
    public let kVK_ANSI_R: UInt16 = 15, kVK_ANSI_P: UInt16 = 35, kVK_ANSI_L: UInt16 = 37
    public let kVK_ANSI_Q: UInt16 = 12, kVK_ANSI_E: UInt16 = 14
    public let kVK_ANSI_1: UInt16 = 18, kVK_ANSI_2: UInt16 = 19
    public let kVK_ANSI_G: UInt16 = 5, kVK_ANSI_X: UInt16 = 7, kVK_ANSI_Y: UInt16 = 16, kVK_ANSI_Z: UInt16 = 6
    public let kVK_ANSI_Space: UInt16 = 49, kVK_ANSI_J: UInt16 = 38, kVK_ANSI_K: UInt16 = 40

    public var keyState = KeyState()
    public var gameControllerState = GameControllerState()
    public var currentGameController: GCExtendedGamepad?

    // Shared state
    public var currentPanGestureState: PanGestureState?
    public var currentPinchGestureState: PinchGestureState?
    public var cameraControlMode: CameraControlMode = .idle

    public var mouseX: Float = 0, mouseY: Float = 0, lastMouseX: Float = 0, lastMouseY: Float = 0
    public var mouseDeltaX: Float = 0, mouseDeltaY: Float = 0, mouseActive: Bool = false

    public var initialPanLocation: CGPoint!
    public var panDelta: simd_float2 = .init(0, 0)
    public var scrollDelta: simd_float2 = .init(0, 0)

    public var pinchDelta: simd_float3 = .init(0, 0, 0)
    public var previousScale: CGFloat = 1

    init() { registerGameControllerEvents() }

    public func registerGameControllerEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidConnect(_:)),
                                               name: .GCControllerDidConnect, object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidDisconnect(_:)),
                                               name: .GCControllerDidDisconnect, object: nil)

        GCController.startWirelessControllerDiscovery { /* done */ }
    }

    @objc private func controllerDidConnect(_ note: Notification) {
        guard let controller = note.object as? GCController, let gameController = controller.extendedGamepad else { return }
        currentGameController = gameController
        configureGameControllerHandlers(gameController)
        Logger.log(message: "Game Controller \(controller.vendorName ?? "unknown vendor") connected and Configured")
    }

    @objc private func controllerDidDisconnect(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        if currentGameController === controller.extendedGamepad { currentGameController = nil }
        Logger.log(message: "Game Controller \(controller.vendorName ?? "unknown vendor") disconnected")
    }

    private func configureGameControllerHandlers(_ gameController: GCExtendedGamepad) {
        gameController.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.aPressed = pressed }
        gameController.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.bPressed = pressed }
        gameController.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.xPressed = pressed }
        gameController.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.yPressed = pressed }

        gameController.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else { return }
            gameControllerState.dpadUpPressed = yValue > 0.5
            gameControllerState.dpadDownPressed = yValue < -0.5
            gameControllerState.dpadLeftPressed = xValue < -0.5
            gameControllerState.dpadRightPressed = xValue > 0.5
        }

        gameController.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gameControllerState.leftShoulderPressed = pressed
        }
        gameController.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gameControllerState.rightShoulderPressed = pressed
        }

        gameController.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard let self else { return }
            gameControllerState.leftTriggerValue = value
            gameControllerState.leftTriggerPressed = pressed
        }
        gameController.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            guard let self else { return }
            gameControllerState.rightTriggerValue = value
            gameControllerState.rightTriggerPressed = pressed
        }

        gameController.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else { return }
            gameControllerState.leftThumbstickX = xValue
            gameControllerState.leftThumbstickY = yValue
            gameControllerState.leftThumbStickActive = abs(xValue) > 0.1 || abs(yValue) > 0.1
        }
        gameController.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            guard let self else { return }
            gameControllerState.rightThumbstickX = xValue
            gameControllerState.rightThumbstickY = yValue
            gameControllerState.rightThumbStickActive = abs(xValue) > 0.1 || abs(yValue) > 0.1
        }

        gameController.leftThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gameControllerState.leftThumbstickPressed = pressed
        }
        gameController.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.gameControllerState.rightThumbstickPressed = pressed
        }
    }
}
