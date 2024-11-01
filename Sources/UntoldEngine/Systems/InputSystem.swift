//
//  InputSystem.swift
//  Untold Engine
//  Created by Harold Serrano on 2/21/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Cocoa
import Foundation
import simd

public struct KeyState {
  public var wPressed = false
  public var aPressed = false
  public var sPressed = false
  public var dPressed = false
  var spacePressed = false
  public var shiftPressed = false
  public var ctrlPressed = false
  var altPressed = false
  var leftMousePressed = false
  var rightMousePressed = false
  var middleMousePressed = false
  // Add more key states as needed
}

enum PanGestureState {
  case began
  case changed
  //case changed(delta: simd_float2)
  case ended
}

enum PinchGestureState {
  case began
  case changed
  //case changed(delta: simd_float2)
  case ended
}

public class InputSystem {

   //key codes
    let kVK_ANSI_W: UInt16 = 13
    let kVK_ANSI_A: UInt16 = 0
    let kVK_ANSI_S: UInt16 = 1
    let kVK_ANSI_D: UInt16 = 2

    let kVK_ANSI_R: UInt16 = 15
    let kVK_ANSI_P: UInt16 = 35
    let kVK_ANSI_L: UInt16 = 37

 
  public var keyState = KeyState()

  // Current state of the pan gesture
  var currentPanGestureState: PanGestureState?
  var currentPinchGestureState: PinchGestureState?

  //Mouse states
  var mouseX: Float = 0.0
  var mouseY: Float = 0.0
  var mouseDeltaX: Float = 0.0
  var mouseDeltaY: Float = 0.0
  var mouseActive: Bool = false

  var initialPanLocation: CGPoint!
  var panDelta: simd_float2 = simd_float2(0.0, 0.0)
  var scrollDelta: simd_float2 = simd_float2(0.0, 0.0)

  var pinchDelta: simd_float3 = simd_float3(0.0, 0.0, 0.0)
  var previousScale: CGFloat = 1.0

  init() {


  }

    public func setupGestureRecognizers(view: NSView) {

        // Pinch gesture
        let pinchGesture = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        // Pan gesture
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        // Click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        view.addGestureRecognizer(clickGesture)
    }


    public func setupEventMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.keyPressed(event.keyCode)
            return nil // Mark event as handled
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.keyReleased(event.keyCode)
            return nil // Mark event as handled
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
    }

    @objc func handlePinch(_ gestureRecognizer: NSMagnificationGestureRecognizer) {
        handlePinchGesture(gestureRecognizer, in: gestureRecognizer.view!)
    }

    @objc func handlePan(_ gestureRecognizer: NSPanGestureRecognizer) {
        handlePanGesture(gestureRecognizer, in: gestureRecognizer.view!)
    }

    @objc func handleClick(_ gestureRecognizer: NSClickGestureRecognizer) {
        print("Click detected at: \(gestureRecognizer.location(in: gestureRecognizer.view))")
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

      //camera.moveCameraAlongAxis(uDelta: delta)
    }
  }

  public func handlePinchGesture(_ gestureRecognizer: NSMagnificationGestureRecognizer, in view: NSView) {

    let currentScale = gestureRecognizer.magnification

    if gestureRecognizer.state == .began {
      // store the initial scale
      self.previousScale = currentScale
      currentPinchGestureState = .began

    } else if gestureRecognizer.state == .changed {
      //determine the direction of the pinch
      let scaleDiff = currentScale - self.previousScale
      self.pinchDelta = 3.0 * simd_float3(0.0, 0.0, Float(1.0) * Float(scaleDiff))

      self.previousScale = currentScale

      currentPinchGestureState = .changed

    } else if gestureRecognizer.state == .ended {

      self.previousScale = 1.0

      currentPinchGestureState = .ended

    }
  }

  public func handleClickGesture(_ gestureRecognizer: NSClickGestureRecognizer, in view: NSView) {

    let currentPanLocation = gestureRecognizer.location(in: view)

  }


  public func handlePanGesture(_ gestureRecognizer: NSPanGestureRecognizer, in view: NSView) {

    let currentPanLocation = gestureRecognizer.translation(in: view)

    switch gestureRecognizer.state {
    case .began:
      //Store the initial touch location and perform any initial setup
      self.initialPanLocation = currentPanLocation
      self.currentPanGestureState = .began

    case .changed:
      //Calculate the deltas from the initial touch location
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
      self.panDelta = simd_float2(Float(deltaX), Float(deltaY))
      self.currentPanGestureState = .changed
      self.initialPanLocation = currentPanLocation

    case .ended:

      //reset
      self.initialPanLocation = nil
      self.currentPanGestureState = .ended

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

    mouseX += mouseDeltaX
    mouseY += mouseDeltaY


    if mouseDeltaX != 0.0 || mouseDeltaY != 0.0 {
      //mouse is active
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
    case kVK_ANSI_P:
      visualDebug = !visualDebug
    case kVK_ANSI_R:
      hotReload = !hotReload
    case kVK_ANSI_L:
      gameMode = !gameMode
    default:
      break
    }
  }

    private func handleFlagsChanged(_ event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            keyState.shiftPressed = event.keyCode == 56
        }
        if event.modifierFlags.contains(.control) {
            keyState.ctrlPressed = event.keyCode == 59
        }

    }


}
