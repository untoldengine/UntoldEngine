//
//  GroundPickingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

public struct PlanePickHit {
    public let worldPosition: simd_float3
    public let distance: Float

    public init(worldPosition: simd_float3, distance: Float) {
        self.worldPosition = worldPosition
        self.distance = distance
    }
}

/// Cast a ray against a horizontal ground plane and return the hit position.
///
/// - Parameters:
///   - rayOrigin: World-space ray origin (e.g. from `XRSpatialInputState.rayOriginWorld`).
///   - rayDirection: World-space ray direction (does not need to be normalized).
///   - planeY: The Y-coordinate of the ground plane. Defaults to `0`.
/// - Returns: A `PlanePickHit` with the world-space hit position and distance, or `nil` if the
///   ray does not intersect the plane (e.g. the ray is parallel or pointing away).
public func pickGroundPosition(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    planeY: Float = 0.0
) -> PlanePickHit? {
    pickPlanePosition(
        rayOrigin: rayOrigin,
        rayDirection: rayDirection,
        planePoint: simd_float3(0, planeY, 0),
        planeNormal: simd_float3(0, 1, 0)
    )
}

/// Cast a ray against an arbitrary plane and return the hit position.
///
/// - Parameters:
///   - rayOrigin: World-space ray origin.
///   - rayDirection: World-space ray direction (does not need to be normalized).
///   - planePoint: Any point on the target plane, in world space.
///   - planeNormal: The plane normal (does not need to be normalized).
/// - Returns: A `PlanePickHit` with the world-space hit position and distance, or `nil` if the
///   ray does not intersect the plane.
public func pickPlanePosition(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    planePoint: simd_float3,
    planeNormal: simd_float3
) -> PlanePickHit? {
    // Validate ray direction.
    let rayLengthSquared = simd_length_squared(rayDirection)
    guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedRayDirection = rayDirection / sqrt(rayLengthSquared)

    // Validate plane normal.
    let normalLengthSquared = simd_length_squared(planeNormal)
    guard normalLengthSquared.isFinite, normalLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedPlaneNormal = planeNormal / sqrt(normalLengthSquared)

    // Transform the ray into entity-local space via the inverse scene root,
    // matching the pattern used by pickEntity() in ScenePickingSystem.swift.
    let srt = SceneRootTransform.shared
    let localOrigin: simd_float3
    let localDirection: simd_float3
    let localPlanePoint: simd_float3
    let localPlaneNormal: simd_float3

    if srt.isIdentity {
        localOrigin = rayOrigin
        localDirection = normalizedRayDirection
        localPlanePoint = planePoint
        localPlaneNormal = normalizedPlaneNormal
    } else {
        let invM = srt.inverseMatrix
        let o = simd_mul(invM, simd_float4(rayOrigin, 1.0))
        localOrigin = simd_float3(o.x, o.y, o.z)
        let d = simd_mul(invM, simd_float4(normalizedRayDirection, 0.0))
        localDirection = simd_normalize(simd_float3(d.x, d.y, d.z))
        let pp = simd_mul(invM, simd_float4(planePoint, 1.0))
        localPlanePoint = simd_float3(pp.x, pp.y, pp.z)
        let pn = simd_mul(invM, simd_float4(normalizedPlaneNormal, 0.0))
        localPlaneNormal = simd_normalize(simd_float3(pn.x, pn.y, pn.z))
    }

    // Perform ray-plane intersection in local space.
    guard let hitPosition = rayPlaneIntersection(
        rayOrigin: localOrigin,
        rayDirection: localDirection,
        planePoint: localPlanePoint,
        planeNormal: localPlaneNormal
    ) else {
        return nil
    }

    let distance = simd_length(hitPosition - localOrigin)

    // Transform hit position back to scene-root-shifted world space.
    guard !srt.isIdentity else {
        return PlanePickHit(worldPosition: hitPosition, distance: distance)
    }

    let wp = simd_mul(srt.matrix, simd_float4(hitPosition, 1.0))
    return PlanePickHit(
        worldPosition: simd_float3(wp.x, wp.y, wp.z),
        distance: distance
    )
}
