//
//  SmallObjectCulling.swift
//  UntoldEngine
//
//  Leaves out of a frame the objects that would only be a pixel or so tall.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// The small-object test of one frame.
///
/// A scene with tens of thousands of parts (a building model with every clip and bolt)
/// shows most of them at a pixel or less from any distance, and each still costs a draw
/// and, near a light, a shadow draw. An object is left out when the sphere around its
/// bounds is under `minimumPixels` tall on screen. The sphere is the largest the object
/// can look, so a long thin object goes only once its whole length is that small.
struct SmallObjectCulling {
    /// Objects under this many pixels tall are not drawn and cast no shadow. Zero draws
    /// everything. Set with `setRendering(.smallObjectCulling(pixels:))`.
    nonisolated(unsafe) static var minimumPixels: Float = 1.0

    /// The camera, in the space the entities' world transforms are in.
    let cameraPosition: simd_float3
    /// The square of the radius, per unit of distance, at which a sphere is exactly
    /// `minimumPixels` tall.
    let radiusPerDistanceSquared: Float

    /// - Parameters:
    ///   - viewportHeight: height of the view in pixels.
    ///   - tanHalfFovY: tangent of half the vertical field of view.
    init(cameraPosition: simd_float3, minimumPixels: Float, viewportHeight: Float, tanHalfFovY: Float) {
        self.cameraPosition = cameraPosition
        // A sphere of radius r at distance d is r * viewportHeight / (d * tanHalfFovY) pixels tall.
        let radiusPerDistance = viewportHeight > 0 ? max(minimumPixels, 0) * tanHalfFovY / viewportHeight : 0
        radiusPerDistanceSquared = radiusPerDistance * radiusPerDistance
    }

    /// The test for the frame being drawn, or nil when nothing is to be culled by size:
    /// the setting is zero, there is no camera, or the projection is not a perspective.
    static func forCurrentFrame() -> SmallObjectCulling? {
        let pixels = minimumPixels
        guard pixels > 0,
              let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else { return nil }

        let projection = renderInfo.perspectiveSpace
        let viewPort: simd_float2? = renderInfo.viewPort
        // A perspective projection has no constant term in w; its [1][1] is 1 / tan(fovY / 2).
        guard let viewPort, viewPort.y > 0, projection.columns.3.w == 0, projection.columns.1.y > 0 else {
            return nil
        }
        // Pixels of the screen the eye sees: under a rasterization rate map (XR foveation) the
        // textures are smaller than that screen, and a size in their pixels would cull early.
        let screenHeight = renderInfo.xrFoveation?.screenSize.y ?? viewPort.y
        return SmallObjectCulling(
            cameraPosition: SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition),
            minimumPixels: pixels,
            viewportHeight: screenHeight,
            tanHalfFovY: 1 / projection.columns.1.y
        )
    }

    /// Whether a sphere is too small on screen to be worth drawing. A sphere the camera
    /// is inside of never is, and neither is one with no size: bounds that are a single
    /// point say nothing about what the object draws.
    func culls(center: simd_float3, radius: Float) -> Bool {
        radius > 0 && radius * radius < simd_distance_squared(center, cameraPosition) * radiusPerDistanceSquared
    }

    /// Whether the box between `worldMin` and `worldMax` is too small on screen.
    func culls(worldMin: simd_float3, worldMax: simd_float3) -> Bool {
        culls(center: (worldMin + worldMax) * 0.5, radius: simd_length(worldMax - worldMin) * 0.5)
    }
}

/// The current value set via `setRendering(.smallObjectCulling(pixels:))`.
public func getSmallObjectCullingPixels() -> Float {
    SmallObjectCulling.minimumPixels
}
