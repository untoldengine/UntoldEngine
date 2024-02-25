//
//  InputSystem.swift
//  Mac_Untold
//
//  Created by Harold Serrano on 2/21/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import Cocoa

struct KeyState {
    var wPressed = false
    var aPressed = false
    var sPressed = false
    var dPressed = false
    var spacePressed = false
    var shiftPressed = false
    var ctrlPressed = false
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

class InputSystem{
    
    var keyState=KeyState()

    // Current state of the pan gesture
    var currentPanGestureState: PanGestureState?
    var currentPinchGestureState: PinchGestureState?
    
    //Mouse states
    var mouseX:Float = 0.0
    var mouseY:Float = 0.0
    var mouseDeltaX:Float = 0.0
    var mouseDeltaY:Float = 0.0
    var mouseActive:Bool = false
    
    var initialPanLocation:CGPoint!
    var panDelta:simd_float2=simd_float2(0.0,0.0)
    var scrollDelta:simd_float2=simd_float2(0.0,0.0)
    
    var pinchDelta:simd_float3=simd_float3(0.0,0.0,0.0)
    var previousScale:CGFloat=1.0
    
    init(){
        
    }
    
    func mouseMoved(_ delta: simd_float2){
        mouseDeltaX = delta.x
        mouseDeltaY = delta.y
        
        mouseX+=mouseDeltaX
        mouseY+=mouseDeltaY
    
        if mouseDeltaX != 0.0 || mouseDeltaY != 0.0{
            //mouse is active
            mouseActive=true
            
        }else{
            //
            mouseActive=false
            
        }
    }
    
    func handleMouseScroll(_ event:NSEvent){
        var deltaX:Double=event.scrollingDeltaX
        var deltaY:Double=event.scrollingDeltaY

        if(abs(deltaX)<abs(deltaY)){
            deltaX=0.0
        }else{
            deltaY=0.0
            deltaX = -1.0*deltaX
        }

        if(abs(deltaX)<=1.0){
            deltaX=0.0
        }

        if(abs(deltaY)<=1.0){
            deltaY=0.0
        }

        scrollDelta=0.01*simd_float2(Float(deltaX),Float(deltaY))

        if(deltaX != 0.0 || deltaY != 0.0){

//            if shiftKey{
//                delta=0.01*simd_float3(0.0,Float(deltaY),0.0)
//                camera.moveCameraAlongAxis(uDelta: delta)
//            }
            
            //camera.moveCameraAlongAxis(uDelta: delta)
        }
    }
    
    func handlePinchGesture(_  gestureRecognizer:NSMagnificationGestureRecognizer, in view:NSView){
         let currentScale = gestureRecognizer.magnification

             if gestureRecognizer.state == .began {
                 // store the initial scale
                 self.previousScale = currentScale
                 currentPinchGestureState = .began
                 
             } else if gestureRecognizer.state == .changed {
                 //determine the direction of the pinch
                 let scaleDiff=currentScale-self.previousScale
                 self.pinchDelta=3.0*simd_float3(0.0,0.0,Float(1.0)*Float(scaleDiff))

                 self.previousScale=currentScale
                 
                 currentPinchGestureState = .changed
                 
             } else if gestureRecognizer.state == .ended {
                 
                 self.previousScale=1.0
                 
                 currentPinchGestureState = .ended
                 
             }
    }
    
    func handlePanGesture(_ gestureRecognizer:NSPanGestureRecognizer, in view:NSView){
        
        let currentPanLocation=gestureRecognizer.translation(in: view)
        
        switch gestureRecognizer.state {
        case .began:
            //Store the initial touch location and perform any initial setup
            self.initialPanLocation=currentPanLocation
            self.currentPanGestureState = .began
            
        case .changed:
            //Calculate the deltas from the initial touch location
            var deltaX=currentPanLocation.x-initialPanLocation.x
            var deltaY=currentPanLocation.y-initialPanLocation.y
            
            if(abs(deltaX)<abs(deltaY)){
                deltaX=0.0
            }else{
                deltaY=0.0
                deltaX = -1.0*deltaX
            }

            if(abs(deltaX)<=1.0){
                deltaX=0.0
            }

            if(abs(deltaY)<=1.0){
                deltaY=0.0
            }

            // Add your code for touch moved here
            self.panDelta = simd_float2(Float(deltaX),Float(deltaY))
            self.currentPanGestureState = .changed
            
            self.initialPanLocation=currentPanLocation
            
        case .ended:
            
            //reset
            self.initialPanLocation=nil
            self.currentPanGestureState = .ended
            
        default:
            break
        }
    }
    
    func mouseDown(_ event:NSEvent){
        
        switch event.buttonNumber {
        case 0:
            keyState.leftMousePressed=true
        case 1:
            keyState.rightMousePressed=true
        default:
            break
        }
    }
    
    func mouseUp(_ event:NSEvent){
        switch event.buttonNumber {
        case 0:
            keyState.leftMousePressed=false
        case 1:
            keyState.rightMousePressed=false
        default:
            break
        }
    }
    
    func keyPressed(_ keyCode:UInt16){
        switch keyCode{
        case kVK_ANSI_A:
            keyState.aPressed=true
        case kVK_ANSI_W:
            keyState.wPressed=true
        case kVK_ANSI_D:
            keyState.dPressed=true
        case kVK_ANSI_S:
            keyState.sPressed=true
        default:
            break
        }
    }
    
    func keyReleased(_ keyCode:UInt16){
        switch keyCode{
        case kVK_ANSI_A:
            keyState.aPressed=false
        case kVK_ANSI_W:
            keyState.wPressed=false
        case kVK_ANSI_D:
            keyState.dPressed=false
        case kVK_ANSI_S:
            keyState.sPressed=false
        case kVK_ANSI_P:
            visualDebug = !visualDebug
        case kVK_ANSI_L:
            gameMode = !gameMode
        default:
            break
        }
    }
    
}
