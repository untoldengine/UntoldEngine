//
//  Controller.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/18/23.
//

import Foundation
import simd

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

struct Controller{
    
    mutating func cameraLookAboutAxis( uDelta: simd_float2){
        
        let rotationAngleX:Float = uDelta.x*0.01
        let rotationAngleY:Float = uDelta.y*0.01
        
        let rotationX:quaternion=quaternion_from_axis_angle(axis: simd_float3(0.0,1.0,0.0), radians: rotationAngleX)
        let rotationY:quaternion=quaternion_from_axis_angle(axis: simd_float3(1.0,0.0,0.0), radians: rotationAngleY)
        
        let newRotation:quaternion=quaternion_multiply(q0:rotationY,q1:camera.rotation)
        
        camera.rotation=quaternion_multiply(q0:newRotation,q1:rotationX)
        
        camera.updateViewMatrix()
    }
    
    mutating func moveCameraAlongAxis(uDelta: simd_float3){
        
        camera.translateBy(delU: uDelta.x * -1.0, delV: uDelta.y, delN: uDelta.z * -1.0)
        
    }
    
    mutating func setOrbitOffset(uTargetOffset: Float){
        
        let direction:simd_float3 = -1.0*camera.localOrientation
        
        camera.orbitTarget=camera.localPosition+direction*uTargetOffset
    }
    
    mutating func orbitCameraAround(uDelta:inout simd_float2){
        
        uDelta.x *= -0.01
        uDelta.y *= -0.01
         
        camera.orbitAround(uDelta)
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
        default:
            break
        }
    }
    
}
