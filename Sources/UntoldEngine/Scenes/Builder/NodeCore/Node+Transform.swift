//
//  Node+Transform.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

public enum Axis {
    case x
    case y
    case z
}

@MainActor
public protocol NodeTransform: NodeProtocol {
    func registerTransformComponent() -> Self

    func translateBy(x: Float, y: Float, z: Float) -> Self
    func rotateBy(angle: Float, axis: [Axis]) -> Self
    func scaleTo(x: Float, y: Float, z: Float) -> Self
}

@MainActor
public extension NodeTransform {
    @discardableResult
    func registerTransformComponent() -> Self {
        UntoldEngine.registerTransformComponent(entityId: entityID)
        return self
    }

    func translateBy(x: Float, y: Float, z: Float) -> Self {
        UntoldEngine.translateBy(entityId: entityID, position: simd_float3(x, y, z))
        return self
    }

    func translateTo(x: Float = 0, y: Float = 0, z: Float = 0) -> Self {
        UntoldEngine.translateTo(entityId: entityID, position: simd_float3(x, y, z))
        return self
    }

    internal func axisToSimdFloat3(_ axis: [Axis]) -> simd_float3 {
        var x: Float = 0, y: Float = 0, z: Float = 0
        for a in axis {
            switch a { case .x: x = 1; case .y: y = 1; case .z: z = 1 }
        }
        return simd_float3(x, y, z)
    }

    func rotateBy(angle: Float, axis: [Axis]) -> Self {
        UntoldEngine.rotateBy(entityId: entityID, angle: angle, axis: axisToSimdFloat3(axis))
        return self
    }

    func rotateTo(angle: Float, axis: [Axis]) -> Self {
        UntoldEngine.rotateTo(entityId: entityID, angle: angle, axis: axisToSimdFloat3(axis))
        return self
    }

    func rotateTo(rotation: simd_float4x4) -> Self {
        UntoldEngine.rotateTo(entityId: entityID, rotation: rotation)
        return self
    }

    func rotateTo(pitch: Float = 0, yaw: Float = 0, roll: Float = 0) -> Self {
        UntoldEngine.rotateTo(entityId: entityID, pitch: pitch, yaw: yaw, roll: roll)
        return self
    }

    func scaleTo(x: Float = 1, y: Float = 1, z: Float = 1) -> Self {
        UntoldEngine.scaleTo(entityId: entityID, scale: simd_float3(x, y, z))
        return self
    }
}
