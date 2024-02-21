//
//  InputSystem.swift
//  Mac_Untold
//
//  Created by Harold Serrano on 2/21/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation

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

class InputSystem{
    
    var keyState=KeyState()
    
    //Mouse states
    var mouseX:Float = 0.0
    var mouseY:Float = 0.0
    var mouseDeltaX:Float = 0.0
    var mouseDeltaY:Float = 0.0
    
    init(){
        //setMouseTracking()
    }
    
    func setupMouseTracking() {
//            let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .mouseEnteredAndExited]
//            let trackingArea = NSTrackingArea(rect: yourView.bounds, options: options, owner: yourView, userInfo: nil)
//            yourView.addTrackingArea(trackingArea)
        }
    
    func mouseMoved(_ delta: simd_float2){
        Logger.log(vector: simd_float3(delta.x,delta.y,0.0))
        mouseDeltaX = delta.x
        mouseDeltaY = delta.y
        
        mouseX+=mouseDeltaX
        mouseY+=mouseDeltaY
    }
    
    func mouseDown(_ event:Int){
        switch event {
        case 0:
            keyState.leftMousePressed=true
        case 1:
            keyState.rightMousePressed=true
        default:
            break
        }
    }
    
    func mouseUp(_ event:Int){
        switch event {
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
