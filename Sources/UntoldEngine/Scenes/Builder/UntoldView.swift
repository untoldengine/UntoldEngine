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
    @State private var metalView: MTKView
    private var renderer: UntoldRenderer?
    private var content: [any NodeProtocol] = []
    private var updateHandler: (@MainActor (UpdateEvent) -> Void)?

    public init(renderer: UntoldRenderer? = nil, @SceneBuilder _ content: @escaping @MainActor () -> [any NodeProtocol]) {
        self.renderer = renderer ?? UntoldRenderer.create()
        metalView = self.renderer?.metalView ?? MTKView()
        self.content = content()
    }

    public var body: some View {
        SceneView(renderer: renderer, updateHandler: updateHandler)
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
}
