//
//  RealSurfacePickingSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os
import simd

// MARK: - Public Types

/// The kind of real-world surface detected by ARKit plane classification.
public enum RealSurfaceKind: String, Sendable {
    case floor
    case ceiling
    case wall
    case table
    case seat
    case door
    case window
    case unknown
}

/// Alignment filter for real-surface picking.
public enum RealSurfaceAlignment: Sendable {
    case horizontal
    case vertical
    case any
}

/// Filter passed to `pickRealSurfacePosition` to restrict which detected planes are considered.
public struct RealSurfaceFilter: Sendable {
    public let alignment: RealSurfaceAlignment

    public init(alignment: RealSurfaceAlignment) {
        self.alignment = alignment
    }

    /// Accept any horizontal plane (floor, ceiling, table, etc.).
    public static let horizontalAny = RealSurfaceFilter(alignment: .horizontal)
    /// Accept any vertical plane (wall, door, window, etc.).
    public static let verticalAny = RealSurfaceFilter(alignment: .vertical)
    /// Accept any detected plane regardless of alignment.
    public static let any = RealSurfaceFilter(alignment: .any)
}

/// The result of a successful `pickRealSurfacePosition` call.
public struct RealSurfaceHit: Sendable {
    /// World-space hit position (accounting for `SceneRootTransform`).
    public let worldPosition: simd_float3
    /// Classification of the detected surface.
    public let surfaceKind: RealSurfaceKind
    /// Distance from the ray origin to the hit point.
    public let distance: Float
    /// World-space normal of the detected plane at the hit point.
    public let planeNormal: simd_float3

    public init(worldPosition: simd_float3, surfaceKind: RealSurfaceKind, distance: Float, planeNormal: simd_float3) {
        self.worldPosition = worldPosition
        self.surfaceKind = surfaceKind
        self.distance = distance
        self.planeNormal = planeNormal
    }
}

// MARK: - Tracked Plane (internal representation)

/// A snapshot of a single ARKit-detected plane, stored in a platform-agnostic form
/// so the picking logic in the core engine module has no ARKit dependency.
public struct TrackedPlane: Sendable {
    /// Unique identifier (mirrors ARKit anchor ID).
    public let id: UUID
    /// The full 4×4 transform that places the plane in world space (ARKit's originFromAnchorTransform).
    public let originFromAnchorTransform: simd_float4x4
    /// Plane extent along the plane's local X axis (width in meters).
    public let extentWidth: Float
    /// Plane extent along the plane's local Z axis (height/depth in meters).
    public let extentHeight: Float
    /// Alignment category.
    public let alignment: RealSurfaceAlignment
    /// Classification.
    public let classification: RealSurfaceKind

    public init(
        id: UUID,
        originFromAnchorTransform: simd_float4x4,
        extentWidth: Float,
        extentHeight: Float,
        alignment: RealSurfaceAlignment,
        classification: RealSurfaceKind
    ) {
        self.id = id
        self.originFromAnchorTransform = originFromAnchorTransform
        self.extentWidth = extentWidth
        self.extentHeight = extentHeight
        self.alignment = alignment
        self.classification = classification
    }
}

// MARK: - Plane Store

/// Thread-safe store that holds the latest set of ARKit-detected planes.
/// Populated by `UntoldEngineXR`; read by `pickRealSurfacePosition`.
public final class RealSurfacePlaneStore: @unchecked Sendable {
    public static let shared = RealSurfacePlaneStore()

    private let lock = OSAllocatedUnfairLock(initialState: [TrackedPlane]())

    private init() {}

    /// Replace the entire tracked plane set (called from the XR module on anchor updates).
    public func update(planes: [TrackedPlane]) {
        lock.withLock { state in
            state = planes
        }
    }

    /// Return a snapshot of all currently tracked planes.
    public func snapshot() -> [TrackedPlane] {
        lock.withLock { state in
            state
        }
    }

    /// Remove all tracked planes.
    public func clear() {
        lock.withLock { state in
            state.removeAll()
        }
    }
}

// MARK: - Picking Function

/// Cast a ray against ARKit-detected real-world planes and return the closest hit.
///
/// - Parameters:
///   - rayOrigin: World-space ray origin (e.g. from `XRSpatialInputState.rayOriginWorld`).
///   - rayDirection: World-space ray direction (does not need to be normalized).
///   - filter: Which plane alignments to consider.
/// - Returns: A `RealSurfaceHit` with the world-space hit position, surface kind, distance,
///   and plane normal, or `nil` if no detected plane was hit.
public func pickRealSurfacePosition(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    filter: RealSurfaceFilter = .any
) -> RealSurfaceHit? {
    // Validate ray direction.
    let rayLengthSquared = simd_length_squared(rayDirection)
    guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedRayDirection = rayDirection / sqrt(rayLengthSquared)

    let planes = RealSurfacePlaneStore.shared.snapshot()
    guard !planes.isEmpty else { return nil }

    // Prepare SceneRootTransform for entity-local ↔ world conversion.
    let srt = SceneRootTransform.shared
    let localRayOrigin: simd_float3
    let localRayDirection: simd_float3

    if srt.isIdentity {
        localRayOrigin = rayOrigin
        localRayDirection = normalizedRayDirection
    } else {
        let invM = srt.inverseMatrix
        let o = simd_mul(invM, simd_float4(rayOrigin, 1.0))
        localRayOrigin = simd_float3(o.x, o.y, o.z)
        let d = simd_mul(invM, simd_float4(normalizedRayDirection, 0.0))
        localRayDirection = simd_normalize(simd_float3(d.x, d.y, d.z))
    }

    var bestHit: RealSurfaceHit?
    var bestDistance: Float = .greatestFiniteMagnitude

    for plane in planes {
        // Filter by alignment.
        switch filter.alignment {
        case .horizontal:
            guard plane.alignment == .horizontal else { continue }
        case .vertical:
            guard plane.alignment == .vertical else { continue }
        case .any:
            break
        }

        // Extract plane center and normal from the anchor transform.
        // Column 3 = translation (center), Column 1 = local Y axis (normal).
        let anchorTransform = plane.originFromAnchorTransform
        let planeCenter = simd_float3(
            anchorTransform.columns.3.x,
            anchorTransform.columns.3.y,
            anchorTransform.columns.3.z
        )
        let planeNormal = simd_normalize(simd_float3(
            anchorTransform.columns.1.x,
            anchorTransform.columns.1.y,
            anchorTransform.columns.1.z
        ))

        // Transform plane into entity-local space (same space as the ray).
        let localPlaneCenter: simd_float3
        let localPlaneNormal: simd_float3

        if srt.isIdentity {
            localPlaneCenter = planeCenter
            localPlaneNormal = planeNormal
        } else {
            let invM = srt.inverseMatrix
            let pc = simd_mul(invM, simd_float4(planeCenter, 1.0))
            localPlaneCenter = simd_float3(pc.x, pc.y, pc.z)
            let pn = simd_mul(invM, simd_float4(planeNormal, 0.0))
            localPlaneNormal = simd_normalize(simd_float3(pn.x, pn.y, pn.z))
        }

        // Ray-plane intersection in local space.
        guard let hitPosition = rayPlaneIntersection(
            rayOrigin: localRayOrigin,
            rayDirection: localRayDirection,
            planePoint: localPlaneCenter,
            planeNormal: localPlaneNormal
        ) else {
            continue
        }

        // Check that the hit falls within the plane's extent.
        // Transform hit from local space back to the plane's own coordinate frame
        // to compare against half-extents.
        let inverseAnchor = simd_inverse(anchorTransform)

        // First, bring hit back to world space so we can go to anchor-local.
        let hitWorld: simd_float3
        if srt.isIdentity {
            hitWorld = hitPosition
        } else {
            let wp = simd_mul(srt.matrix, simd_float4(hitPosition, 1.0))
            hitWorld = simd_float3(wp.x, wp.y, wp.z)
        }

        let hitInAnchor = simd_mul(inverseAnchor, simd_float4(hitWorld, 1.0))
        let halfWidth = plane.extentWidth * 0.5
        let halfHeight = plane.extentHeight * 0.5

        // In ARKit plane-local space, the plane lies in the XZ plane (Y ≈ 0).
        guard abs(hitInAnchor.x) <= halfWidth, abs(hitInAnchor.z) <= halfHeight else {
            continue
        }

        let distance = simd_length(hitPosition - localRayOrigin)
        guard distance < bestDistance else { continue }

        // Compute final world-space position (with SRT applied).
        let finalWorldPosition: simd_float3
        let finalPlaneNormal: simd_float3
        if srt.isIdentity {
            finalWorldPosition = hitPosition
            finalPlaneNormal = planeNormal
        } else {
            finalWorldPosition = hitWorld
            finalPlaneNormal = planeNormal
        }

        bestDistance = distance
        bestHit = RealSurfaceHit(
            worldPosition: finalWorldPosition,
            surfaceKind: plane.classification,
            distance: distance,
            planeNormal: finalPlaneNormal
        )
    }

    return bestHit
}
