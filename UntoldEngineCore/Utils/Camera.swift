//
//  Camera.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/17/23.
//

import Foundation
import simd

struct Camera{
    
    mutating func translateTo(_ translationX: Float, _ translationY: Float, _ translationZ: Float){
    
        localPosition.x=translationX
        localPosition.y=translationY
        localPosition.z=translationZ
        
        updateViewMatrix()
    }

    
    mutating func translateBy(delU:Float, delV:Float, delN:Float){
             
        localPosition.x+=delU*xAxis.x+delV*yAxis.x+delN*zAxis.x
        localPosition.y+=delU*xAxis.y+delV*yAxis.y+delN*zAxis.y
        localPosition.z+=delU*xAxis.z+delV*yAxis.z+delN*zAxis.z
        updateViewMatrix()
    }
    
    mutating func updateViewMatrix(){
        
        rotation=quaternion_normalize(q: rotation)
        
        xAxis=right_direction_vector_from_quaternion(q: rotation)
        yAxis=up_direction_vector_from_quaternion(q: rotation)
        zAxis=forward_direction_vector_from_quaternion(q: rotation)
        
        viewSpace=matrix4x4_from_quaterion(q: rotation)
        
        viewSpace.columns.3=simd_float4(-simd_dot(xAxis, localPosition),
                                        -simd_dot(yAxis, localPosition),
                                        -simd_dot(zAxis, localPosition),
                                        1.0)
        
        localOrientation=zAxis
        
        /*
        //if you are new to this: see this: http://www.songho.ca/opengl/gl_anglestoaxes.html
        let cosPitch:Float=cos(pitch)
        let sinPitch:Float=sin(pitch)
        let cosYaw:Float=cos(yaw)
        let sinYaw:Float=sin(yaw)
        let cosRoll:Float=cos(roll)
        let sinRoll:Float=sin(roll)
    
        
        xAxis=simd_float3(cosRoll*cosYaw,sinRoll*cosYaw,-sinYaw)
        yAxis=simd_float3(cosRoll*sinYaw*sinPitch-sinRoll*cosPitch,sinRoll*sinYaw*sinPitch+cosRoll*cosPitch,cosYaw*sinPitch)
        zAxis=simd_float3(cosRoll*sinYaw*cosPitch+sinRoll*sinPitch,sinRoll*sinYaw*cosPitch-cosRoll*sinPitch,cosPitch*cosYaw)
        
        viewSpace=simd_float4x4.init(columns: (simd_float4(xAxis.x,yAxis.x,zAxis.x,0.0),
                                               simd_float4(xAxis.y,yAxis.y,zAxis.y,0.0),
                                               simd_float4(xAxis.z,yAxis.z,zAxis.z,0.0),
                                               simd_float4(-simd_dot(xAxis,localPosition),-simd_dot(yAxis, localPosition),-simd_dot(zAxis, localPosition),1.0)))
        */
        
    }
    
    mutating func orbitAround(_ uPosition:simd_float2){
        
        let target:simd_float3=localPosition-orbitTarget
        let length:Float=simd_length(target)
        var direction:simd_float3=simd_normalize(target)
        
        //rot about yaw first
        let rotationX:quaternion=quaternion_from_axis_angle(axis: simd_float3(0.0,1.0,0.0), radians: uPosition.x)
        direction=quaternion_rotate_vector(q: rotationX, v: direction)
        var newUpAxis=quaternion_rotate_vector(q: rotationX, v: yAxis)
        
        direction=simd_normalize(direction)
        newUpAxis=simd_normalize(newUpAxis)
        
        //now compute the right axis
        var rightAxis:simd_float3=simd_cross(newUpAxis, direction)
        rightAxis=simd_normalize(rightAxis)
        
        //then rotate about right axis
        let rotationY:quaternion=quaternion_from_axis_angle(axis: rightAxis, radians: uPosition.y)
        direction=quaternion_rotate_vector(q: rotationY, v: direction)
        newUpAxis=quaternion_rotate_vector(q: rotationY, v: newUpAxis)
        
        direction=simd_normalize(direction)
        newUpAxis=simd_normalize(newUpAxis)
        
        localPosition=orbitTarget+direction*length
        
        //compute the matrix
        lookAt(eye: localPosition, target: orbitTarget, up: newUpAxis)
        
        
    }
    
    // Returns a right-handed matrix which looks from a point (the "eye") at a target point, given the up vector.
    mutating func lookAt(eye: simd_float3, target: simd_float3, up: simd_float3) {
        
        rotation=quaternion_normalize(q: quaternion_conjugate(q:quaternion_lookAt(eye: eye,target: target,up: up)))
        
        localPosition=eye
        
        updateViewMatrix();
        
    }
    
    //data
    var viewSpace=simd_float4x4.init(1.0)
   
    var xAxis:simd_float3=simd_float3(0.0,0.0,0.0)
    var yAxis:simd_float3=simd_float3(0.0,0.0,0.0)
    var zAxis:simd_float3=simd_float3(0.0,0.0,0.0)
    
    //quaternion
    var rotation:quaternion=quaternion_identity()
    var localOrientation:simd_float3=simd_float3(0.0,0.0,0.0)
    var localPosition:simd_float3=simd_float3(0.0,0.0,0.0)
    var orbitTarget:simd_float3=simd_float3(0.0,0.0,0.0)
}
