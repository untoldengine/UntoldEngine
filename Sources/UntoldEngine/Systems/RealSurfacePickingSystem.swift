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
    /// When non-nil, only planes whose classification is in this set are considered.
    /// Pass `nil` (the default) to accept any surface kind within the alignment.
    public let kinds: Set<RealSurfaceKind>?

    public init(alignment: RealSurfaceAlignment, kinds: Set<RealSurfaceKind>? = nil) {
        self.alignment = alignment
        self.kinds = kinds
    }

    /// Accept any horizontal plane (floor, ceiling, table, etc.).
    public static let horizontalAny = RealSurfaceFilter(alignment: .horizontal)
    /// Accept any vertical plane (wall, door, window, etc.).
    public static let verticalAny = RealSurfaceFilter(alignment: .vertical)
    /// Accept any detected plane regardless of alignment.
    public static let any = RealSurfaceFilter(alignment: .any)
    /// Accept floor planes only.
    public static let floorOnly = RealSurfaceFilter(alignment: .horizontal, kinds: [.floor])
    /// Accept table planes only.
    public static let tableOnly = RealSurfaceFilter(alignment: .horizontal, kinds: [.table])
    /// Accept wall planes only.
    public static let wallOnly = RealSurfaceFilter(alignment: .vertical, kinds: [.wall])
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
    /// World-space normal of the detected surface at the hit point.
    public var surfaceNormal: simd_float3 {
        planeNormal
    }

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
    /// Transform from extent-local space to anchor-local space (accounts for extent center offset).
    public let anchorFromExtentTransform: simd_float4x4
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
        anchorFromExtentTransform: simd_float4x4 = matrix_identity_float4x4,
        extentWidth: Float,
        extentHeight: Float,
        alignment: RealSurfaceAlignment,
        classification: RealSurfaceKind
    ) {
        self.id = id
        self.originFromAnchorTransform = originFromAnchorTransform
        self.anchorFromExtentTransform = anchorFromExtentTransform
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

    /// Print every currently tracked plane to the console — useful for diagnosing missing
    /// or misclassified surfaces (e.g. a desk showing up as `.unknown` instead of `.table`).
    public func logAllPlanes() {
        let planes = snapshot()
        print("── RealSurfacePlaneStore: \(planes.count) plane(s) ──────────────────")
        for plane in planes {
            let t = plane.originFromAnchorTransform
            let y = t.columns.3.y
            print(
                String(
                    format: "  [%@] alignment=%-10@ classification=%-8@ y=%+.2fm  size=%.2fx%.2f",
                    String(plane.id.uuidString.prefix(8)),
                    "\(plane.alignment)",
                    "\(plane.classification)",
                    y,
                    plane.extentWidth,
                    plane.extentHeight
                )
            )
        }
        print("────────────────────────────────────────────────────────────────────")
    }
}

// MARK: - Picking Function

/// Cast a ray against ARKit-detected real-world planes and return the closest hit.
///
/// - Parameters:
///   - rayOrigin: World-space ray origin (e.g. from `XRSpatialInputState.rayOriginWorld`).
///   - rayDirection: World-space ray direction (does not need to be normalized).
///   - filter: Which plane alignments and classifications to consider.
///   - hitYRange: When non-nil, only hits whose world-space Y coordinate falls within this
///     range are accepted. Use this to disambiguate surfaces by height when ARKit does not
///     classify them correctly — e.g. `0.5...1.2` to target desk height, `(-0.2)...0.2`
///     for the floor. Defaults to unlimited (no Y constraint).
///   - maxDistance: Maximum ray distance (in meters) to accept a hit. Defaults to unlimited.
/// - Returns: A `RealSurfaceHit` with the world-space hit position, surface kind, distance,
///   and plane normal, or `nil` if no detected plane was hit.
public func pickRealSurfacePosition(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    filter: RealSurfaceFilter = .any,
    hitYRange: ClosedRange<Float>? = nil,
    maxDistance: Float = .greatestFiniteMagnitude
) -> RealSurfaceHit? {
    // Validate ray direction.
    let rayLengthSquared = simd_length_squared(rayDirection)
    guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedRayDirection = rayDirection / sqrt(rayLengthSquared)

    let planes = RealSurfacePlaneStore.shared.snapshot()
    guard !planes.isEmpty else { return nil }

    // Prepare SceneRootTransform for entity-local ↔ world conversion.
    // Cache SRT values to avoid redundant property accesses in the loop.
    let srt = SceneRootTransform.shared
    let srtIsIdentity = srt.isIdentity
    let srtInvM = srt.inverseMatrix
    let srtM = srt.matrix
    let localRayOrigin: simd_float3
    let localRayDirection: simd_float3

    if srtIsIdentity {
        localRayOrigin = rayOrigin
        localRayDirection = normalizedRayDirection
    } else {
        let o = simd_mul(srtInvM, simd_float4(rayOrigin, 1.0))
        localRayOrigin = simd_float3(o.x, o.y, o.z)
        let d = simd_mul(srtInvM, simd_float4(normalizedRayDirection, 0.0))
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

        // Filter by surface kind when the caller requested specific classifications.
        if let kinds = filter.kinds {
            guard kinds.contains(plane.classification) else { continue }
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

        if srtIsIdentity {
            localPlaneCenter = planeCenter
            localPlaneNormal = planeNormal
        } else {
            let pc = simd_mul(srtInvM, simd_float4(planeCenter, 1.0))
            localPlaneCenter = simd_float3(pc.x, pc.y, pc.z)
            let pn = simd_mul(srtInvM, simd_float4(planeNormal, 0.0))
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
        // Transform hit from local space to extent-local space, accounting for
        // the extent's offset from the anchor origin (anchorFromExtentTransform).
        let extentInWorld = anchorTransform * plane.anchorFromExtentTransform
        let worldToExtent = simd_inverse(extentInWorld)

        // First, bring hit back to world space so we can go to extent-local.
        let hitWorld: simd_float3
        if srtIsIdentity {
            hitWorld = hitPosition
        } else {
            let wp = simd_mul(srtM, simd_float4(hitPosition, 1.0))
            hitWorld = simd_float3(wp.x, wp.y, wp.z)
        }

        let hitInExtent = simd_mul(worldToExtent, simd_float4(hitWorld, 1.0))
        let halfWidth = plane.extentWidth * 0.5
        let halfHeight = plane.extentHeight * 0.5

        // In extent-local space the plane lies in XZ. Check that the hit
        // falls within the finite extent rectangle.
        guard abs(hitInExtent.x) <= halfWidth,
              abs(hitInExtent.z) <= halfHeight
        else {
            continue
        }

        // Optional Y-range filter applied in world space. This is the reliable
        // fallback when ARKit has not yet classified a surface (e.g. desk stays
        // `.unknown` instead of `.table`): callers can bracket by physical height.
        if let yRange = hitYRange {
            guard yRange.contains(hitWorld.y) else { continue }
        }

        let distance = simd_length(hitPosition - localRayOrigin)
        guard distance <= maxDistance, distance < bestDistance else { continue }

        // Compute final world-space position (with SRT applied).
        let finalWorldPosition: simd_float3
        let finalPlaneNormal: simd_float3
        if srtIsIdentity {
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
