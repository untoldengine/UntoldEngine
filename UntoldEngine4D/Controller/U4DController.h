//
//  U4DController.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 8/30/23.
//

#ifndef U4DController_hpp
#define U4DController_hpp

#include <stdio.h>
#import <simd/simd.h>

#include "U4DCamera.h"
#include "U4DMathUtils.h"
#include "CommonProtocols.h"
#import <TargetConditionals.h>
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
#include <Carbon/Carbon.h>
#endif

extern U4DEngine::U4DCamera camera;
extern U4DEngine::KeyState keyState;
namespace U4DEngine {
struct U4DController{
    
    void dollyTrackBoom(simd::float3 uDelta){
        uDelta.x*=-1.0;
        uDelta.z*=-1.0;
        camera.translateBy(uDelta);
    }
    
    void flyCamera(simd::float2 uDelta){
        
        float rotationAngleX = uDelta.x * 0.01;
        float rotationAngleY = uDelta.y * 0.01;

        quaternion_float rotationX = quaternion_from_axis_angle( simd_float3 { 0.0, 1.0, 0.0 }, rotationAngleX );
        quaternion_float rotationY = quaternion_from_axis_angle( simd_float3 { 1.0, 0.0, 0.0 }, rotationAngleY );

        // apply y-axis rotation first

        quaternion_float newRotation = quaternion_multiply( rotationY, camera.rotation );

        // apply x-axis
        camera.rotation = quaternion_multiply( newRotation, rotationX );

        camera.updateViewMatrix();
        
    }
    
    void orbitCamera(simd::float2 uDelta){
        // inverting x and y input
        uDelta.x *= -0.01;
        uDelta.y *= -0.01;

        camera.orbitAround( uDelta );
    }
    
    void setOrbitTarget(float uOffset){
        simd_float3 direction = -1.0 * camera.localOrientation;
        camera.orbitTarget = camera.localPosition + direction * uOffset;
    }
    
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    
    void keyPressed(unsigned short keyCode) {
        switch (keyCode) {
            case kVK_ANSI_W:
                keyState.wPressed = true;
                break;
            case kVK_ANSI_A:
                keyState.aPressed = true;
                break;
            case kVK_ANSI_S:
                keyState.sPressed = true;
                break;
            case kVK_ANSI_D:
                keyState.dPressed = true;
                break;
            case kVK_Space:
                keyState.spacePressed = true;
                break;
            case kVK_Shift:
                keyState.shiftPressed = true;
                break;
            case kVK_Control:
                keyState.ctrlPressed = true;
                break;
            case kVK_Option:
                keyState.altPressed = true;
                break;
            
            // Add more key cases as needed
            default:
                break;
        }
    }

    
    void keyReleased(unsigned short keyCode) {
        switch (keyCode) {
            case kVK_ANSI_W:
                keyState.wPressed = false;
                break;
            case kVK_ANSI_A:
                keyState.aPressed = false;
                break;
            case kVK_ANSI_S:
                keyState.sPressed = false;
                break;
            case kVK_ANSI_D:
                keyState.dPressed = false;
                break;
            case kVK_Space:
                keyState.spacePressed = false;
                break;
            case kVK_Shift:
                keyState.shiftPressed = false;
                break;
            case kVK_Control:
                keyState.ctrlPressed = false;
                break;
            case kVK_Option:
                keyState.altPressed = false;
                break;
            
            // Add more key cases as needed
            default:
                break;
        }
    }

#endif
    
};
}
#endif /* U4DController_hpp */
