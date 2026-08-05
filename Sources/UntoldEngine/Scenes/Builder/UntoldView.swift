//
//  UntoldView.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit
import SwiftUI

@MainActor
public struct UntoldView: View {
    private var renderer: UntoldRenderer?
    var options: UntoldViewOptions
    private var contentBuilder: @MainActor () -> [any NodeProtocol]
    private var updateHandler: (@MainActor (UpdateEvent) -> Void)?

    /// - Parameters:
    ///   - renderer: An externally owned renderer, or nil to let the view
    ///     create one. Either way the renderer is resolved once and survives
    ///     SwiftUI re-evaluations of this struct.
    ///   - options: Runtime-tunable view settings (target FPS, pause, clear
    ///     color). When SwiftUI re-evaluates the view with changed options,
    ///     only the difference is applied to the live `MTKView` — the
    ///     renderer and the scene are never recreated. Also settable through
    ///     the `options(_:)` / `preferredFramesPerSecond(_:)` / `paused(_:)`
    ///     modifiers.
    ///   - content: Scene content, built exactly once when the underlying
    ///     platform view is created (after the renderer is ready, so mesh
    ///     loading has a Metal device).
    public init(
        renderer: UntoldRenderer? = nil,
        options: UntoldViewOptions = .default,
        @SceneBuilder _ content: @escaping @MainActor () -> [any NodeProtocol]
    ) {
        self.renderer = renderer
        self.options = options
        contentBuilder = content
    }

    public var body: some View {
        SceneView(
            renderer: renderer,
            options: options,
            setup: { _ = contentBuilder() },
            updateHandler: updateHandler
        )
    }

    /// Subscribes to the engine's per-frame update event (RealityKit
    /// `SceneEvents.Update` style). The handler fires every frame on the main
    /// thread, regardless of `gameMode`, after simulation and before rendering.
    ///
    /// - Warning: Do not mutate SwiftUI `@State` that this view's scene content
    ///   depends on from inside the handler — that re-evaluates the body every
    ///   frame and re-runs the scene builder. Keep per-frame values in a
    ///   reference type or in the ECS.
    public func onUpdate(_ handler: @escaping @MainActor (UpdateEvent) -> Void) -> UntoldView {
        var copy = self
        copy.updateHandler = handler
        return copy
    }

    /// Replaces all runtime view options.
    public func options(_ options: UntoldViewOptions) -> UntoldView {
        var copy = self
        copy.options = options
        return copy
    }

    /// Sets the target frame rate of the live view.
    public func preferredFramesPerSecond(_ fps: Int) -> UntoldView {
        var copy = self
        copy.options.preferredFramesPerSecond = fps
        return copy
    }

    /// Pauses or resumes the draw loop of the live view.
    public func paused(_ paused: Bool) -> UntoldView {
        var copy = self
        copy.options.isPaused = paused
        return copy
    }
}
