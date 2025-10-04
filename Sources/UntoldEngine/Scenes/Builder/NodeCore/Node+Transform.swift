//
//  Node+Transform.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd

public enum Axis {
    case x
    case y
    case z
}

public protocol NodeTransform : NodeProtocol
{
    func registerTransformComponent() -> Self
    
    func translateBy ( x: Float, y: Float, z: Float ) -> Self
    func rotateBy(angle: Float, axis: [Axis] ) -> Self
    func scaleTo(x:Float, y:Float, z:Float) -> Self
}

extension NodeTransform
{
    @discardableResult
    public func registerTransformComponent() -> Self {
        UntoldEngine.registerTransformComponent(entityId: entityID)
        return self
    }
    
    public func translateBy ( x: Float, y: Float, z: Float ) -> Self {
        UntoldEngine.translateBy(entityId: entityID, position: simd_float3(x, y, z))
        return self
    }

    func axisToSimdFloat3(_ axis: [Axis]) -> simd_float3 {
        var x:Float = 0, y:Float = 0, z:Float = 0
        for a in axis { switch a { case .x: x = 1; case .y: y = 1; case .z: z = 1 } }
        return simd_float3(x, y, z)
    }
    
    public func rotateBy(angle: Float, axis: [Axis] ) -> Self {
        UntoldEngine.rotateBy(entityId: entityID, angle: angle, axis: axisToSimdFloat3(axis))
        return self
    }
     
    public func rotateTo(angle: Float, axis: [Axis]) -> Self {
        UntoldEngine.rotateTo(entityId: entityID, angle: angle, axis: axisToSimdFloat3(axis))
        return self
    }
    
    public func rotateTo(rotation: simd_float4x4 ) -> Self {
        UntoldEngine.rotateTo(entityId: entityID, rotation: rotation)
        return self
    }
    
    public func rotateTo(pitch: Float = 0, yaw: Float = 0, roll: Float = 0) -> Self {
        UntoldEngine.rotateTo(entityId: entityID, pitch: pitch, yaw: yaw, roll: roll)
        return self
    }
        
    public func scaleTo(x:Float = 0, y:Float = 0, z:Float = 0) -> Self {
        UntoldEngine.scaleTo(entityId: entityID, scale: simd_float3( x, y, z))
        return self
    }
}
