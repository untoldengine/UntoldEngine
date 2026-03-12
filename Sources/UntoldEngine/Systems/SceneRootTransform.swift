
//
//  SceneRootTransform.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// A single transform applied to the entire scene without modifying individual entity transforms.
//
// The scene root transform is implemented via a "virtual camera" trick:
// instead of moving every entity, we apply the *inverse* of this transform to the camera
// (and related matrices). This keeps static batching intact — no rebatching is needed
// when the scene moves.
//
// Call `updateIfNeeded()` once per frame (before culling) to recompute cached matrices.

/*
 The core rule

 Any system that compares camera position against entity data must use effectiveCameraPosition. Entity transforms are never modified, so anything reading entity-space data (positions, AABBs, G-buffer values) needs the camera in that same space.

 Where it matters today

 •  Shader uniforms (cameraPosition in Uniforms struct) — used for specular/view-direction in both the deferred light pass and forward transparency pass. These read surface positions from the G-buffer or from modelMatrix * vertex, both in entity space.
 •  Shadow lookups — the light pass samples the shadow map using effectiveLightMatrix * g_buffer_position. Since g_buffer positions are entity-space, the light matrix must also account for the scene root.
 •  Octree queries — queryNearCamera, streaming distance checks.
 •  Picking ray — transformed at entry, hit back-transformed at exit.

 What to watch for when adding new systems

 Any time you write new code that does one of these, you need to decide which space you're in:

 1. Reading cameraComponent.localPosition to compare against entity positions or G-buffer data → use effectiveCameraPosition
 2. Reading cameraComponent.viewSpace to build a view-projection matrix for rendering → use effectiveViewMatrix
 3. Reading shadowSystem.dirLightSpaceMatrix for shadow map rendering or shadow lookup → use effectiveLightMatrix
 4. Taking a ray from user input (ARKit, screen-space) and intersecting with entities → transform ray by inverseMatrix before testing, transform hit by matrix after
 5. Pure entity-to-entity comparisons (e.g., distance between two entities) → no transform needed, they're already in the same space
 6. Displaying positions to the user (UI, debug overlays) → add SceneRootTransform.shared.position to entity positions to get the visual position

 The one easy mistake

 If you add a new render pass or post-process effect that reads cameraComponent.localPosition directly and combines it with G-buffer data, lighting will break when the scene is shifted. Always go through the SceneRootTransform.shared helpers for camera/light values that touch entity-space data.
 */

public class SceneRootTransform: @unchecked Sendable {
    public static let shared = SceneRootTransform()

    /// Scene-root position in world space.
    public var position: simd_float3 = .zero {
        didSet { isDirty = true }
    }

    /// Scene-root rotation.
    public var rotation: simd_quatf = .init() {
        didSet { isDirty = true }
    }

    /// Scene-root scale.
    public var scale: simd_float3 = .one {
        didSet { isDirty = true }
    }

    /// The composed scene-root matrix (T * R * S). Read-only externally.
    public private(set) var matrix: simd_float4x4 = .identity

    /// The inverse of `matrix`. Read-only externally.
    public private(set) var inverseMatrix: simd_float4x4 = .identity

    private var isDirty: Bool = false

    private init() {}

    /// Reset scene-root transform to identity and refresh cached matrices immediately.
    public func reset() {
        position = .zero
        rotation = simd_quatf()
        scale = .one
        updateIfNeeded()
    }

    /// Recompute `matrix` and `inverseMatrix` if any property changed since the last call.
    /// Call this once at the top of each frame, before culling / rendering.
    public func updateIfNeeded() {
        guard isDirty else { return }
        isDirty = false

        let T = matrix4x4Translation(position.x, position.y, position.z)
        let R = getMatrix4x4FromQuaternion(q: rotation)
        let S = matrix4x4Scale(scale.x, scale.y, scale.z)

        matrix = T * R * S
        inverseMatrix = simd_inverse(matrix)
    }

    /// Convenience: returns `true` when the scene root is at the identity transform
    /// (position zero, no rotation, unit scale). Useful for fast-path skipping.
    public var isIdentity: Bool {
        position == .zero
            && rotation == simd_quatf()
            && scale == .one
    }

    // MARK: - Helpers for render passes

    /// Returns `cameraView * matrix`.  When the scene root is identity this is a no-op.
    /// This makes entities appear at their position *plus* the scene root offset,
    /// without actually modifying per-entity transforms.
    public func effectiveViewMatrix(_ cameraView: simd_float4x4) -> simd_float4x4 {
        guard !isIdentity else { return cameraView }
        return simd_mul(cameraView, matrix)
    }

    /// Returns the camera position transformed into "shifted" world space.
    public func effectiveCameraPosition(_ cameraPos: simd_float3) -> simd_float3 {
        guard !isIdentity else { return cameraPos }
        let p = simd_mul(inverseMatrix, simd_float4(cameraPos, 1.0))
        return simd_float3(p.x, p.y, p.z)
    }

    /// Returns `lightMatrix * matrix` for shadow / light ortho-view.
    public func effectiveLightMatrix(_ lightMatrix: simd_float4x4) -> simd_float4x4 {
        guard !isIdentity else { return lightMatrix }
        return simd_mul(lightMatrix, matrix)
    }

    /// Convert a point from scene-local/entity space to visual world space.
    public func sceneLocalToVisualWorld(_ position: simd_float3) -> simd_float3 {
        updateIfNeeded()
        guard !isIdentity else { return position }
        let p = simd_mul(matrix, simd_float4(position, 1.0))
        return simd_float3(p.x, p.y, p.z)
    }

    /// Convert a point from visual world space back into scene-local/entity space.
    public func visualWorldToSceneLocal(_ position: simd_float3) -> simd_float3 {
        updateIfNeeded()
        guard !isIdentity else { return position }
        let p = simd_mul(inverseMatrix, simd_float4(position, 1.0))
        return simd_float3(p.x, p.y, p.z)
    }
}
