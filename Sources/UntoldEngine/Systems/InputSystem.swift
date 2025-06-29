//
//  InputSystem.swift
//  Untold Engine
//  Created by Harold Serrano on 2/21/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import AppKit
import Cocoa
import Foundation
import GameController
import simd

public struct KeyState {
    public var wPressed = false
    public var aPressed = false
    public var sPressed = false
    public var dPressed = false
    public var qPressed = false
    public var ePressed = false
    public var spacePressed = false
    public var shiftPressed = false
    public var ctrlPressed = false
    var altPressed = false
    var leftMousePressed = false
    var rightMousePressed = false
    var middleMousePressed = false
    // Add more key states as needed
}

public struct GamePadState {
    public var aPressed = false
    public var bPressed = false
    public var leftThumbStickActive = false
}

enum PanGestureState {
    case began
    case changed
    // case changed(delta: simd_float2)
    case ended
}

enum PinchGestureState {
    case began
    case changed
    // case changed(delta: simd_float2)
    case ended
}

enum CameraControlMode {
    case idle
    case orbiting
    case moving
}

public class InputSystem {
    // key codes
    let kVK_ANSI_W: UInt16 = 13
    let kVK_ANSI_A: UInt16 = 0
    let kVK_ANSI_S: UInt16 = 1
    let kVK_ANSI_D: UInt16 = 2

    let kVK_ANSI_R: UInt16 = 15
    let kVK_ANSI_P: UInt16 = 35
    let kVK_ANSI_L: UInt16 = 37

    let kVK_ANSI_Q: UInt16 = 12
    let kVK_ANSI_E: UInt16 = 14

    let kVK_ANSI_1: UInt16 = 18
    let kVK_ANSI_2: UInt16 = 19

    let kVK_ANSI_G: UInt16 = 5
    let kVK_ANSI_X: UInt16 = 7
    let kVK_ANSI_Y: UInt16 = 16
    let kVK_ANSI_Z: UInt16 = 6

    let kVK_ANSI_Space: UInt16 = 49

    public var keyState = KeyState()
    public var gamePadState = GamePadState()

    // Current state of the pan gesture
    var currentPanGestureState: PanGestureState?
    var currentPinchGestureState: PinchGestureState?

    var cameraControlMode: CameraControlMode = .idle

    // Mouse states
    var mouseX: Float = 0.0
    var mouseY: Float = 0.0
    var lastMouseX: Float = 0.0
    var lastMouseY: Float = 0.0
    var mouseDeltaX: Float = 0.0
    var mouseDeltaY: Float = 0.0
    var mouseActive: Bool = false

    var initialPanLocation: CGPoint!
    var panDelta: simd_float2 = .init(0.0, 0.0)
    var scrollDelta: simd_float2 = .init(0.0, 0.0)

    var pinchDelta: simd_float3 = .init(0.0, 0.0, 0.0)
    var previousScale: CGFloat = 1.0

    public var currentGamepad: GCExtendedGamepad?

    weak var selectionDelegate: SelectionDelegate?

    init() {
        setupGameController()
    }

    private func setupGameController() {
        // Listen for controllers being connected
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )

        // Listen for controllers being disconnected
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Start discovery
        GCController.startWirelessControllerDiscovery {
            print("Controller discovery completed.")
        }
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        print("Controller connected: \(controller.vendorName ?? "Unknown Controller")")

        if let gamepad = controller.extendedGamepad {
            currentGamepad = gamepad
            configureGamepadHandlers(gamepad)
        } else {
            print("Connected controller does not support extendedGamepad")
        }
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        print("Controller disconnected: \(controller.vendorName ?? "Unknown Controller")")

        if currentGamepad === controller.extendedGamepad {
            currentGamepad = nil
        }
    }

    private func configureGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        gamepad.leftThumbstick.valueChangedHandler = { _, _, _ in
            // print("Left thumbstick moved: \(xValue), \(yValue)")
        }

        gamepad.rightThumbstick.valueChangedHandler = { _, _, _ in
            // print("Right thumbstick moved: \(xValue), \(yValue)")
        }

//            gamepad.leftTrigger.valueChangedHandler = { _, value in
//                print("Left trigger pressed: \(value)")
//
//            }
//
//            gamepad.rightTrigger.valueChangedHandler = { _, value in
//                print("Right trigger pressed: \(value)")
//
//            }

        gamepad.buttonA.pressedChangedHandler = { _, _, isPressed in
            self.gamePadState.aPressed = isPressed
        }

        gamepad.buttonB.pressedChangedHandler = { _, _, isPressed in
            self.gamePadState.bPressed = isPressed
        }
    }

    public func setupGestureRecognizers(view: NSView) {
        // Pinch gesture
        let pinchGesture = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        // Pan gesture
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

        view.addGestureRecognizer(panGesture)

        // Click gesture
        let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
        view.addGestureRecognizer(rightClickGesture)
        rightClickGesture.buttonMask = 0x2 // 0x1 = left, 0x2 = right, 0x4 = middle
    }

    private func shouldHandleKey(_: NSEvent) -> Bool {
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView {
                return false // allow normal text input
            }
        }

        return true // handle the key event
    }

    public func setupEventMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.shouldHandleKey(event) == true {
                self?.keyPressed(event.keyCode)
                return nil // Mark event as handled
            }
            return event // Pass event to the system
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if self?.shouldHandleKey(event) == true {
                self?.keyReleased(event.keyCode)
                return nil // Mark event as handled
            }
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.leftMouseDown(event)
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.leftMouseDragged(simd_float2(Float(event.deltaX), Float(event.deltaY)))
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.leftMouseUp(event)
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleMouseScroll(event)
            return event
        }
    }

    @objc func handlePinch(_ gestureRecognizer: NSMagnificationGestureRecognizer) {
        handlePinchGesture(gestureRecognizer, in: gestureRecognizer.view!)
    }

    @objc func handlePan(_ gestureRecognizer: NSPanGestureRecognizer) {
        handlePanGesture(gestureRecognizer, in: gestureRecognizer.view!)
    }

    @objc func handleRightClick(_ gestureRecognizer: NSClickGestureRecognizer) {
        mouseRaycast(gestureRecognizer: gestureRecognizer, in: gestureRecognizer.view!)
    }

    public func handleMouseScroll(_ event: NSEvent) {
        var deltaX: Double = event.scrollingDeltaX
        var deltaY: Double = event.scrollingDeltaY

        if abs(deltaX) < abs(deltaY) {
            deltaX = 0.0
        } else {
            deltaY = 0.0
            deltaX = -1.0 * deltaX
        }

        if abs(deltaX) <= 1.0 {
            deltaX = 0.0
        }

        if abs(deltaY) <= 1.0 {
            deltaY = 0.0
        }

        scrollDelta = 0.01 * simd_float2(Float(deltaX), Float(deltaY))

        if deltaX != 0.0 || deltaY != 0.0 {
            //            if shiftKey{
            //                delta=0.01*simd_float3(0.0,Float(deltaY),0.0)
            //                camera.moveCameraAlongAxis(uDelta: delta)
            //            }

            // camera.moveCameraAlongAxis(uDelta: delta)
        }
    }

    public func handlePinchGesture(_ gestureRecognizer: NSMagnificationGestureRecognizer, in _: NSView) {
        let currentScale = gestureRecognizer.magnification

        if gestureRecognizer.state == .began {
            // store the initial scale
            previousScale = currentScale
            currentPinchGestureState = .began

        } else if gestureRecognizer.state == .changed {
            // determine the direction of the pinch
            let scaleDiff = currentScale - previousScale
            pinchDelta = 3.0 * simd_float3(0.0, 0.0, Float(1.0) * Float(scaleDiff))

            previousScale = currentScale

            currentPinchGestureState = .changed

        } else if gestureRecognizer.state == .ended {
            previousScale = 1.0

            currentPinchGestureState = .ended
        }
    }

    public func mouseRaycast(gestureRecognizer: NSClickGestureRecognizer, in view: NSView) {
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        let currentLocation = gestureRecognizer.location(in: view)

        let (entityId, hit) = getRaycastedEntity(currentLocation: currentLocation, view: view)

        gizmoActive = false
        removeGizmo()
        editorController?.activeMode = .none
        editorController?.activeAxis = .none
        activeHitGizmoEntity = .invalid
        
        if hit {
            activeEntity = entityId

            guard let localTransform = scene.get(component: LocalTransformComponent.self, for: activeEntity) else { return }
           
            let scale: simd_float3 = localTransform.scale
            updateBoundingBoxBuffer(min: localTransform.boundingBox.min*scale, max: localTransform.boundingBox.max*scale)

            selectionDelegate?.didSelectEntity(activeEntity)
            selectionDelegate?.resetActiveAxis()

            createGizmo(name: "translateGizmo")
        } else {
            activeEntity = .invalid
            removeGizmo()
        }
    }

    public func handlePanGesture(_ gestureRecognizer: NSPanGestureRecognizer, in view: NSView) {
        let currentPanLocation = gestureRecognizer.translation(in: view)

        guard let editorController else {
            return
        }

        if editorController.activeMode != .none, activeEntity != .invalid, keyState.shiftPressed {
            return
        }
        let currentLocation = gestureRecognizer.location(in: view)

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        switch gestureRecognizer.state {
        case .began:
            // Store the initial touch location and perform any initial setup
            initialPanLocation = currentPanLocation
            currentPanGestureState = .began
            setOrbitOffset(entityId: findSceneCamera(), uTargetOffset: length(cameraComponent.localPosition))
            cameraControlMode = .orbiting

            if gizmoActive {
                let (hitEntityId, hit) = getRaycastedEntity(currentLocation: currentLocation, view: view)

                if hit {
                    activeHitGizmoEntity = hitEntityId

                } else {
                    activeHitGizmoEntity = .invalid
                    editorController.activeMode = .none
                    editorController.activeAxis = .none
                }
            }
        case .changed:

            processGizmoAction(entityId: activeHitGizmoEntity)

            if activeHitGizmoEntity != .invalid {
                return
            }
            // Calculate the deltas from the initial touch location
            var deltaX = currentPanLocation.x - initialPanLocation.x
            var deltaY = currentPanLocation.y - initialPanLocation.y

            if abs(deltaX) < abs(deltaY) {
                deltaX = 0.0
            } else {
                deltaY = 0.0
                deltaX = -1.0 * deltaX
            }

            if abs(deltaX) <= 1.0 {
                deltaX = 0.0
            }

            if abs(deltaY) <= 1.0 {
                deltaY = 0.0
            }

            // Add your code for touch moved here
            panDelta = simd_float2(Float(deltaX), Float(deltaY))
            currentPanGestureState = .changed
            initialPanLocation = currentPanLocation
            orbitAround(entityId: findSceneCamera(), uPosition: inputSystem.panDelta * 0.005)
        case .ended, .cancelled, .failed:

            // reset
            panDelta = simd_float2(0, 0)
            initialPanLocation = nil
            currentPanGestureState = .ended
            cameraControlMode = .idle
        default:
            break
        }
    }

    public func leftMouseDragged(_ delta: simd_float2) {
        mouseDeltaX = delta.x
        mouseDeltaY = delta.y

        if abs(mouseDeltaX) < abs(mouseDeltaY) {
            mouseDeltaX = 0.0
        } else {
            mouseDeltaY = 0.0
            // mouseDeltaX = -1.0 * mouseDeltaX
        }

        if abs(mouseDeltaX) <= 1.0 {
            mouseDeltaX = 0.0
        }

        if abs(mouseDeltaY) <= 1.0 {
            mouseDeltaY = 0.0
        }

        lastMouseX = mouseX
        lastMouseY = mouseY

        mouseX += mouseDeltaX
        mouseY += mouseDeltaY

        if mouseDeltaX != 0.0 || mouseDeltaY != 0.0 {
            // mouse is active
            mouseActive = true

        } else {
            //
            mouseActive = false
        }
    }

    public func leftMouseDown(_ event: NSEvent) {
        switch event.buttonNumber {
        case 0:
            keyState.leftMousePressed = true
        case 1:
            keyState.rightMousePressed = true
        default:
            break
        }
    }

    public func leftMouseUp(_ event: NSEvent) {
        mouseActive = false
        switch event.buttonNumber {
        case 0:
            keyState.leftMousePressed = false
        case 1:
            keyState.rightMousePressed = false
        default:
            break
        }
    }

    public func keyPressed(_ keyCode: UInt16) {
        switch keyCode {
        case kVK_ANSI_A:
            keyState.aPressed = true
        case kVK_ANSI_W:
            keyState.wPressed = true
        case kVK_ANSI_D:
            keyState.dPressed = true
        case kVK_ANSI_S:
            keyState.sPressed = true
        case kVK_ANSI_Space:
            keyState.spacePressed = true
        case kVK_ANSI_Q:
            keyState.qPressed = true
        case kVK_ANSI_E:
            keyState.ePressed = true
//        case kVK_ANSI_G:
//            print("G pressed")
        case kVK_ANSI_X:
            guard let editorController else {
                return
            }
            editorController.activeAxis = .x
        case kVK_ANSI_Y:
            guard let editorController else {
                return
            }
            editorController.activeAxis = .y
        case kVK_ANSI_Z:
            guard let editorController else {
                return
            }
            editorController.activeAxis = .z
        case kVK_ANSI_1:
            break
        case kVK_ANSI_2:
            break
        default:
            break
        }
    }

    public func keyReleased(_ keyCode: UInt16) {
        switch keyCode {
        case kVK_ANSI_A:
            keyState.aPressed = false
        case kVK_ANSI_W:
            keyState.wPressed = false
        case kVK_ANSI_D:
            keyState.dPressed = false
        case kVK_ANSI_S:
            keyState.sPressed = false
        case kVK_ANSI_Space:
            keyState.spacePressed = false
        case kVK_ANSI_Q:
            keyState.qPressed = false
        case kVK_ANSI_E:
            keyState.ePressed = false
        case kVK_ANSI_P:
            gameMode = !gameMode
        case kVK_ANSI_R:

            if keyState.shiftPressed {
                hotReload = !hotReload
            }
        case kVK_ANSI_L:
            if keyState.shiftPressed {
                visualDebug = !visualDebug
                currentDebugSelection = DebugSelection.normalOutput
            }
        case kVK_ANSI_1:
            currentDebugSelection = DebugSelection.normalOutput
        case kVK_ANSI_2:
            currentDebugSelection = DebugSelection.iblOutput
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Shift key
        keyState.shiftPressed = event.modifierFlags.contains(.shift)

        // Control key
        keyState.ctrlPressed = event.modifierFlags.contains(.control)
    }

    func getRaycastedEntity(currentLocation: NSPoint, view: NSView) -> (entityId: EntityID, hit: Bool) {
        var hitEntityId: EntityID = .invalid
        var hitEntity = false

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return (hitEntityId, hitEntity)
        }

        let currentCGPoint = simd_float2(Float(currentLocation.x), Float(currentLocation.y))

        let rayDirection: simd_float3 = rayDirectionInWorldSpace(uMouseLocation: currentCGPoint, uViewPortDim: simd_float2(Float(view.bounds.width), Float(view.bounds.height)), uPerspectiveSpace: renderInfo.perspectiveSpace, uViewSpace: cameraComponent.viewSpace)

        if getAllGameEntitiesWithMeshes().count == 0 {
            return (hitEntityId, hitEntity)
        }

        if let rtxCommandBuffer = renderInfo.commandQueue.makeCommandBuffer() {
            executeRayVsModelHit(rtxCommandBuffer, cameraComponent.localPosition, rayDirection)

            rtxCommandBuffer.addCompletedHandler { commandBuffer in
                if let error = commandBuffer.error {
                    // Handle error if any
                    print("Command buffer completed with error: \(error)")
                } else {
                    if let data = bufferResources.rayModelInstanceBuffer?.contents().assumingMemoryBound(to: Int32.self) {
                        let value = data.pointee

                        if value != -1 {
                            hitEntityId = accelStructResources.entityIDIndex[Int(value)]
                            hitEntity = true
                        }
                    }
                }

                cleanUpAccelStructures()
            }

            rtxCommandBuffer.commit()
            rtxCommandBuffer.waitUntilCompleted()
        }

        if hitEntity {
            return (hitEntityId, hitEntity)
        }

        return (hitEntityId, hitEntity)
    }
}
