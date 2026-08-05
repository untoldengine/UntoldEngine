//
//  UntoldViewOptions.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

/// Runtime-tunable settings for the SwiftUI host view.
///
/// Unlike `UntoldRendererConfig` — which is create-time, immutable renderer
/// configuration — these values may change while the view is alive. When
/// SwiftUI re-evaluates the view with new options, only the properties that
/// actually changed are applied to the live `MTKView`; the renderer is never
/// recreated. Every property in this struct must be applicable to the live
/// view — anything that requires rebuilding the render pipeline belongs in
/// `UntoldRendererConfig` instead, and anything that tunes the engine itself
/// (anti-aliasing, post-FX, LOD, ...) already has a live channel through the
/// engine settings API (`setRendering`, `setPostFX`, `setLOD`, ...).
public struct UntoldViewOptions: Equatable, Sendable {
    /// Target frame rate, applied to `MTKView.preferredFramesPerSecond`.
    public var preferredFramesPerSecond: Int

    /// Pauses the draw loop (`MTKView.isPaused`). Simulation and rendering
    /// stop and the last frame stays on screen. Use for menus, inactive
    /// tabs, or battery saving.
    public var isPaused: Bool

    /// Clear color of the drawable, linear RGBA.
    public var clearColor: simd_float4

    public init(
        preferredFramesPerSecond: Int = 60,
        isPaused: Bool = false,
        clearColor: simd_float4 = simd_float4(0, 0, 0, 1)
    ) {
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.isPaused = isPaused
        self.clearColor = clearColor
    }

    public static let `default` = UntoldViewOptions()
}
