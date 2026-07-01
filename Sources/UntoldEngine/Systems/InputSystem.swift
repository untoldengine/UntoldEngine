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
#if os(visionOS)
    import ARKit
#endif
#if os(macOS)
    import AppKit
#endif
#if os(iOS)
    import UIKit
#endif

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

public final class InputSystem: @unchecked Sendable {
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
    public var psvr2SenseControllerState = PSVR2SenseControllerState()
    #if os(visionOS)
        var psvr2SpatialControllers: [GCController] = []
        var psvr2AccessoryTrackingProviderStorage: AnyObject?
        var psvr2AccessoryLoadTask: Task<Void, Never>?
        var psvr2AnchorMonitorTask: Task<Void, Never>?
        var psvr2AccessoryGeneration = 0

        @available(visionOS 26.0, *)
        public var psvr2AccessoryTrackingProvider: AccessoryTrackingProvider? {
            psvr2AccessoryTrackingProviderStorage as? AccessoryTrackingProvider
        }
    #endif

    public var iosTouchState = IOSTouchState()

    #if os(iOS)
        var iosTouchGestureRecognizers: [UIGestureRecognizer] = []
        weak var iosTouchView: UIView?
    #endif

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

    #if os(macOS)
        var keyboardEventMonitorTokens: [Any] = []
        var textInputObserverTokens: [NSObjectProtocol] = []
        var isTextInputFocused = false
    #endif

    init() {
        registerGameControllerEvents()
    }

    public func registerGameControllerEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidConnect(_:)),
                                               name: .GCControllerDidConnect, object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidDisconnect(_:)),
                                               name: .GCControllerDidDisconnect, object: nil)

        // A controller can already be connected before InputSystem.shared is first
        // accessed. Connection notifications are not replayed to late observers.
        for controller in GCController.controllers() {
            configureConnectedController(controller)
        }

        GCController.startWirelessControllerDiscovery { /* done */ }
    }

    @objc private func controllerDidConnect(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        configureConnectedController(controller)
    }

    private func configureConnectedController(_ controller: GCController) {
        configurePSVR2IfNeeded(controller)

        if let gameController = controller.extendedGamepad {
            currentGameController = gameController
            configureGameControllerHandlers(gameController)
        } else if isPSVR2SpatialController(controller) {
            configurePhysicalGameControllerHandlers(controller.physicalInputProfile)
        } else {
            Logger.log(message: "Game Controller \(controller.vendorName ?? "unknown vendor") has no supported input profile")
            return
        }
        Logger.log(message: "Game Controller \(controller.vendorName ?? "unknown vendor") connected and configured (category=\(controller.productCategory))")
    }

    @objc private func controllerDidDisconnect(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        if currentGameController === controller.extendedGamepad { currentGameController = nil }
        clearPSVR2IfNeeded(controller)
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

    /// Spatial gamepads expose their controls through the physical profile rather
    /// than GCExtendedGamepad. Each PSVR2 wand contributes only its own elements.
    private func configurePhysicalGameControllerHandlers(_ profile: GCPhysicalInputProfile) {
        profile.buttons["Button A"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.aPressed = pressed }
        profile.buttons["Button B"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.bPressed = pressed }
        profile.buttons["Button X"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.xPressed = pressed }
        profile.buttons["Button Y"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.yPressed = pressed }

        profile.buttons["Left Shoulder"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.leftShoulderPressed = pressed }
        profile.buttons["Right Shoulder"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.rightShoulderPressed = pressed }
        profile.buttons["Left Trigger"]?.valueChangedHandler = { [weak self] _, value, pressed in
            self?.gameControllerState.leftTriggerValue = value
            self?.gameControllerState.leftTriggerPressed = pressed
        }
        profile.buttons["Right Trigger"]?.valueChangedHandler = { [weak self] _, value, pressed in
            self?.gameControllerState.rightTriggerValue = value
            self?.gameControllerState.rightTriggerPressed = pressed
        }

        profile.dpads["Left Thumbstick"]?.valueChangedHandler = { [weak self] _, x, y in
            self?.gameControllerState.leftThumbstickX = x
            self?.gameControllerState.leftThumbstickY = y
            self?.gameControllerState.leftThumbStickActive = abs(x) > 0.1 || abs(y) > 0.1
        }
        profile.dpads["Right Thumbstick"]?.valueChangedHandler = { [weak self] _, x, y in
            self?.gameControllerState.rightThumbstickX = x
            self?.gameControllerState.rightThumbstickY = y
            self?.gameControllerState.rightThumbStickActive = abs(x) > 0.1 || abs(y) > 0.1
        }
        profile.buttons["Left Thumbstick Button"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.leftThumbstickPressed = pressed }
        profile.buttons["Right Thumbstick Button"]?.pressedChangedHandler = { [weak self] _, _, pressed in self?.gameControllerState.rightThumbstickPressed = pressed }
    }
}
