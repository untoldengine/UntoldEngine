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
    /// Which hand each connected PSVR2 Sense wand belongs to. Both wands expose their
    /// single stick under the same generic `.thumbstick`/`.thumbstickButton` physical
    /// input keys, so the handler needs this to know which side of GameControllerState
    /// to update. Populated from ARKit accessory chirality once it loads (see
    /// InputSystem+PSVR2.swift); until then, thumbstick events for that wand are dropped.
    var psvr2ControllerChirality: [ObjectIdentifier: XRSpatialChirality] = [:]
    #if os(visionOS)
        var psvr2SpatialControllers: [GCController] = []
        // Loaded Accessory objects ([Any] to avoid @available on a stored property).
        // Kept instead of a long-lived provider: ARKit data providers are one-shot,
        // so a fresh AccessoryTrackingProvider is built from these for every
        // ARKitSession run (see makePSVR2AccessoryTrackingProviderForSessionRun).
        var psvr2AccessoriesStorage: [Any] = []
        var psvr2AccessoryTrackingProviderStorage: AnyObject?
        var psvr2AccessoryLoadTask: Task<Void, Never>?
        var psvr2AnchorMonitorTask: Task<Void, Never>?
        var psvr2AccessoryGeneration = 0

        /// The provider most recently created for a session run. May already have
        /// been run — never pass this to ARKitSession.run again; use
        /// makePSVR2AccessoryTrackingProviderForSessionRun for that.
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
            configurePhysicalGameControllerHandlers(controller)
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
    private func configurePhysicalGameControllerHandlers(_ controller: GCController) {
        let profile = controller.physicalInputProfile

        // Each wand physically has only two face buttons (Cross/Circle on the right
        // wand, Square/Triangle on the left), and GCPhysicalInputProfile labels both
        // as the generic "Button A"/"Button B" regardless of wand — there is no
        // "Button X"/"Button Y" key and no Left/Right prefix. Which GameControllerState
        // field to update is resolved per-event from the wand's chirality, same as the
        // thumbstick handling below. Right wand maps onto the existing aPressed/bPressed
        // fields (Cross/Circle); left wand maps onto xPressed/yPressed (Square/Triangle),
        // matching the documented PlayStation face-button mapping.
        profile.buttons["Button A"]?.pressedChangedHandler = { [weak self, weak controller] _, _, pressed in
            guard let self, let controller else { return }
            updatePSVR2ButtonA(pressed, for: controller)
        }
        profile.buttons["Button B"]?.pressedChangedHandler = { [weak self, weak controller] _, _, pressed in
            guard let self, let controller else { return }
            updatePSVR2ButtonB(pressed, for: controller)
        }

        // Grip and Trigger are likewise single generic keys per wand (no Left/Right
        // prefix); route to the existing left/right shoulder and trigger fields by
        // chirality instead.
        profile.buttons["Grip"]?.pressedChangedHandler = { [weak self, weak controller] _, _, pressed in
            guard let self, let controller else { return }
            updatePSVR2Grip(pressed, for: controller)
        }
        profile.buttons["Trigger"]?.valueChangedHandler = { [weak self, weak controller] _, value, pressed in
            guard let self, let controller else { return }
            updatePSVR2Trigger(value: value, pressed: pressed, for: controller)
        }

        // Each wand has a single stick, exposed under the generic GCInputThumbstick /
        // GCInputThumbstickButton physical input keys (added in visionOS 26) rather than
        // the "Left Thumbstick"/"Right Thumbstick" keys GCExtendedGamepad uses for
        // two-stick gamepads. Which GameControllerState side to update is resolved
        // per-event from the wand's ARKit-derived chirality rather than the key name.
        profile.dpads["Thumbstick"]?.valueChangedHandler = { [weak self, weak controller] _, x, y in
            guard let self, let controller else { return }
            updatePSVR2Thumbstick(x: x, y: y, for: controller)
        }
        profile.buttons["Thumbstick Button"]?.pressedChangedHandler = { [weak self, weak controller] _, _, pressed in
            guard let self, let controller else { return }
            updatePSVR2ThumbstickPressed(pressed, for: controller)
        }
    }

    func updatePSVR2Thumbstick(x: Float, y: Float, for controller: GCController) {
        switch psvr2ControllerChirality[ObjectIdentifier(controller)] {
        case .left:
            gameControllerState.leftThumbstickX = x
            gameControllerState.leftThumbstickY = y
            gameControllerState.leftThumbStickActive = abs(x) > 0.1 || abs(y) > 0.1
        case .right:
            gameControllerState.rightThumbstickX = x
            gameControllerState.rightThumbstickY = y
            gameControllerState.rightThumbStickActive = abs(x) > 0.1 || abs(y) > 0.1
        case nil:
            break
        }
    }

    func updatePSVR2ThumbstickPressed(_ pressed: Bool, for controller: GCController) {
        switch psvr2ControllerChirality[ObjectIdentifier(controller)] {
        case .left: gameControllerState.leftThumbstickPressed = pressed
        case .right: gameControllerState.rightThumbstickPressed = pressed
        case nil: break
        }
    }

    /// Right wand's "Button A" (Cross) -> aPressed; left wand's "Button A" (Square) -> xPressed.
    func updatePSVR2ButtonA(_ pressed: Bool, for controller: GCController) {
        switch psvr2ControllerChirality[ObjectIdentifier(controller)] {
        case .right: gameControllerState.aPressed = pressed
        case .left: gameControllerState.xPressed = pressed
        case nil: break
        }
    }

    /// Right wand's "Button B" (Circle) -> bPressed; left wand's "Button B" (Triangle) -> yPressed.
    func updatePSVR2ButtonB(_ pressed: Bool, for controller: GCController) {
        switch psvr2ControllerChirality[ObjectIdentifier(controller)] {
        case .right: gameControllerState.bPressed = pressed
        case .left: gameControllerState.yPressed = pressed
        case nil: break
        }
    }

    func updatePSVR2Grip(_ pressed: Bool, for controller: GCController) {
        switch psvr2ControllerChirality[ObjectIdentifier(controller)] {
        case .left: gameControllerState.leftShoulderPressed = pressed
        case .right: gameControllerState.rightShoulderPressed = pressed
        case nil: break
        }
    }

    func updatePSVR2Trigger(value: Float, pressed: Bool, for controller: GCController) {
        switch psvr2ControllerChirality[ObjectIdentifier(controller)] {
        case .left:
            gameControllerState.leftTriggerValue = value
            gameControllerState.leftTriggerPressed = pressed
        case .right:
            gameControllerState.rightTriggerValue = value
            gameControllerState.rightTriggerPressed = pressed
        case nil: break
        }
    }
}
