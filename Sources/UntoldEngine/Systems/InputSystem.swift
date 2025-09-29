//
//  InputSystem.swift
//  Untold Engine
//  Created by Harold Serrano on 2/21/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import GameController
import simd

public struct GamePadState {
    public var aPressed = false
    public var bPressed = false
    public var leftThumbStickActive = false
}

public enum PanGestureState { case began, changed, ended }
public enum PinchGestureState { case began, changed, ended }
public enum CameraControlMode { case idle, orbiting, moving }


public protocol InputSystemDelegate : AnyObject
{
    func didUpdateKeyState()
}

public final class InputSystem {
    public static let shared: InputSystem = { return InputSystem() }()
    public weak var delegate: InputSystemDelegate? = nil
    
    public let kVK_ANSI_W: UInt16 = 13, kVK_ANSI_A: UInt16 = 0,  kVK_ANSI_S: UInt16 = 1,  kVK_ANSI_D: UInt16 = 2
    public let kVK_ANSI_R: UInt16 = 15, kVK_ANSI_P: UInt16 = 35, kVK_ANSI_L: UInt16 = 37
    public let kVK_ANSI_Q: UInt16 = 12, kVK_ANSI_E: UInt16 = 14
    public let kVK_ANSI_1: UInt16 = 18, kVK_ANSI_2: UInt16 = 19
    public let kVK_ANSI_G: UInt16 = 5,  kVK_ANSI_X: UInt16 = 7,  kVK_ANSI_Y: UInt16 = 16, kVK_ANSI_Z: UInt16 = 6
    public let kVK_ANSI_Space: UInt16 = 49

    public var keyState = KeyState()
    public var gamePadState = GamePadState()
    public var currentGamepad: GCExtendedGamepad?

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
            
    init() { setupGameController() }

    private func setupGameController() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect, object: nil)

        NotificationCenter.default.addObserver(self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect, object: nil)

        GCController.startWirelessControllerDiscovery { /* done */ }
    }

    @objc private func controllerDidConnect(_ note: Notification) {
        guard let controller = note.object as? GCController, let gamepad = controller.extendedGamepad else { return }
        currentGamepad = gamepad
        configureGamepadHandlers(gamepad)
    }

    @objc private func controllerDidDisconnect(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        if currentGamepad === controller.extendedGamepad { currentGamepad = nil }
    }

    private func configureGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in self?.gamePadState.aPressed = pressed }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in self?.gamePadState.bPressed = pressed }
        // add thumbstick/trigger mapping as needed…
    }
}

