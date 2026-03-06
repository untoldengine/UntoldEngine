//
//  AABB.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import Foundation
import simd

/// Axis-Aligned Bounding Box
public struct AABB {
    public var min: simd_float3
    public var max: simd_float3

    public init(min: simd_float3, max: simd_float3) {
        self.min = min
        self.max = max
    }

    public init(center: simd_float3, halfExtents: simd_float3) {
        self.min = center - halfExtents
        self.max = center + halfExtents
    }

    /// Center point of the box
    public var center: simd_float3 {
        (min + max) * 0.5
    }

    /// Half-size in each dimension
    public var halfExtents: simd_float3 {
        (max - min) * 0.5
    }

    /// Full size in each dimension
    public var size: simd_float3 {
        max - min
    }

    /// Volume of the box
    public var volume: Float {
        let s = size
        return s.x * s.y * s.z
    }

    /// Check if a point is inside the box
    public func contains(_ point: simd_float3) -> Bool {
        point.x >= min.x && point.x <= max.x &&
            point.y >= min.y && point.y <= max.y &&
            point.z >= min.z && point.z <= max.z
    }

    /// Check if this box fully contains another box
    public func contains(_ other: AABB) -> Bool {
        other.min.x >= min.x && other.max.x <= max.x &&
            other.min.y >= min.y && other.max.y <= max.y &&
            other.min.z >= min.z && other.max.z <= max.z
    }

    /// Check if two boxes overlap
    public func intersects(_ other: AABB) -> Bool {
        min.x <= other.max.x && max.x >= other.min.x &&
            min.y <= other.max.y && max.y >= other.min.y &&
            min.z <= other.max.z && max.z >= other.min.z
    }

    /// Check if box intersects a sphere
    public func intersects(_ sphere: BoundingSphere) -> Bool {
        // Find closest point on AABB to sphere center
        let closest = simd_float3(
            simd_clamp(sphere.center.x, min.x, max.x),
            simd_clamp(sphere.center.y, min.y, max.y),
            simd_clamp(sphere.center.z, min.z, max.z)
        )

        let distanceSquared = simd_length_squared(closest - sphere.center)
        return distanceSquared <= (sphere.radius * sphere.radius)
    }

    /// Subdivide into 8 child boxes (octants)
    public func subdivide() -> [AABB] {
        let c = center
        return [
            // Bottom 4 (y = min)
            AABB(min: simd_float3(min.x, min.y, min.z), max: simd_float3(c.x, c.y, c.z)),
            AABB(min: simd_float3(c.x, min.y, min.z), max: simd_float3(max.x, c.y, c.z)),
            AABB(min: simd_float3(min.x, min.y, c.z), max: simd_float3(c.x, c.y, max.z)),
            AABB(min: simd_float3(c.x, min.y, c.z), max: simd_float3(max.x, c.y, max.z)),
            // Top 4 (y = max)
            AABB(min: simd_float3(min.x, c.y, min.z), max: simd_float3(c.x, max.y, c.z)),
            AABB(min: simd_float3(c.x, c.y, min.z), max: simd_float3(max.x, max.y, c.z)),
            AABB(min: simd_float3(min.x, c.y, c.z), max: simd_float3(c.x, max.y, max.z)),
            AABB(min: simd_float3(c.x, c.y, c.z), max: simd_float3(max.x, max.y, max.z)),
        ]
    }

    /// Expand box to include a point
    public mutating func expand(toInclude point: simd_float3) {
        min = simd_min(min, point)
        max = simd_max(max, point)
    }

    /// Expand box to include another box
    public mutating func expand(toInclude other: AABB) {
        min = simd_min(min, other.min)
        max = simd_max(max, other.max)
    }

    /// Create a box that encompasses both boxes
    public func union(_ other: AABB) -> AABB {
        AABB(
            min: simd_min(min, other.min),
            max: simd_max(max, other.max)
        )
    }

    /// A zero-sized box at origin
    public static let zero = AABB(min: .zero, max: .zero)

    /// An "infinite" box that contains everything
    public static let infinite = AABB(
        min: simd_float3(repeating: -Float.greatestFiniteMagnitude),
        max: simd_float3(repeating: Float.greatestFiniteMagnitude)
    )
}

/// Bounding sphere for radius-based queries
public struct BoundingSphere {
    public var center: simd_float3
    public var radius: Float

    public init(center: simd_float3, radius: Float) {
        self.center = center
        self.radius = radius
    }

    /// Check if sphere contains a point
    public func contains(_ point: simd_float3) -> Bool {
        simd_length_squared(point - center) <= (radius * radius)
    }

    /// Check if two spheres overlap
    public func intersects(_ other: BoundingSphere) -> Bool {
        let combinedRadius = radius + other.radius
        return simd_length_squared(center - other.center) <= (combinedRadius * combinedRadius)
    }

    /// Convert to AABB (bounding box of the sphere)
    public var aabb: AABB {
        let r = simd_float3(repeating: radius)
        return AABB(min: center - r, max: center + r)
    }
}

public extension AABB {
    /// Calculate distance from this AABB to a point
    /// Returns 0 if point is inside the AABB
    func distanceToPoint(_ point: simd_float3) -> Float {
        let dx = Swift.max(min.x - point.x, 0.0, point.x - max.x)
        let dy = Swift.max(min.y - point.y, 0.0, point.y - max.y)
        let dz = Swift.max(min.z - point.z, 0.0, point.z - max.z)
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    /// Check if AABB intersects with a sphere (useful for radius checks)
    func intersectsSphere(center: simd_float3, radius: Float) -> Bool {
        distanceToPoint(center) <= radius
    }
}
