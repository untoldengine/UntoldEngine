//
//  SceneView.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import MetalKit
import SwiftUI

#if os(macOS)
    public typealias ViewRepresentable = NSViewRepresentable
#else
    public typealias ViewRepresentable = UIViewRepresentable
#endif

public struct SceneView: ViewRepresentable {
    private var renderer: UntoldRenderer?
    private var options: UntoldViewOptions
    private var updateHandler: (@MainActor (UpdateEvent) -> Void)?
    private var setupHandler: (@MainActor () -> Void)?

    public init(
        renderer: UntoldRenderer? = nil,
        options: UntoldViewOptions = .default,
        setup: (@MainActor () -> Void)? = nil,
        updateHandler: (@MainActor (UpdateEvent) -> Void)? = nil
    ) {
        self.renderer = renderer
        self.options = options
        setupHandler = setup
        self.updateHandler = updateHandler
    }

    /// Persists across SwiftUI re-inits of the view struct. Owns the renderer
    /// (so a fallback-created one is made exactly once, not on every body
    /// re-evaluation), the one-shot setup, the frame-event subscription, and
    /// the last options applied to the MTKView.
    @MainActor
    public final class Coordinator {
        var renderer: UntoldRenderer?
        var handler: (@MainActor (UpdateEvent) -> Void)?
        var subscription: EventSubscription?
        var didRunSetup = false
        var appliedOptions: UntoldViewOptions?

        /// Applies only the properties that differ from the last applied
        /// options, so unrelated SwiftUI re-evaluations never touch the view.
        func apply(_ options: UntoldViewOptions, to view: MTKView) {
            let previous = appliedOptions
            guard previous != options else { return }

            if previous?.preferredFramesPerSecond != options.preferredFramesPerSecond {
                view.preferredFramesPerSecond = options.preferredFramesPerSecond
            }
            if previous?.isPaused != options.isPaused {
                view.isPaused = options.isPaused
            }
            if previous?.clearColor != options.clearColor {
                let c = options.clearColor
                view.clearColor = MTLClearColor(
                    red: Double(c.x), green: Double(c.y), blue: Double(c.z), alpha: Double(c.w)
                )
            }
            appliedOptions = options
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Resolves the stable renderer: adopts the injected one on the first
    /// call, creates a fallback otherwise, and never swaps it afterwards —
    /// SwiftUI may re-init this struct freely without recreating anything.
    @MainActor
    private func resolveRenderer(_ coordinator: Coordinator) -> UntoldRenderer? {
        if coordinator.renderer == nil {
            coordinator.renderer = renderer ?? UntoldRenderer.create()
        }
        return coordinator.renderer
    }

    /// Runs the setup block exactly once, after the renderer exists so the
    /// Metal device is available to resource-loading calls inside it.
    @MainActor
    private func runSetupIfNeeded(_ coordinator: Coordinator) {
        guard !coordinator.didRunSetup else { return }
        coordinator.didRunSetup = true
        setupHandler?()
    }

    @MainActor
    private func connect(_ coordinator: Coordinator) {
        coordinator.handler = updateHandler
        guard coordinator.subscription == nil, updateHandler != nil,
              let renderer = coordinator.renderer else { return }
        coordinator.subscription = renderer.onUpdate { [weak coordinator] event in
            // The MTKView delegate draws on the main thread; trap loudly if a
            // future host ever drives this renderer off-main.
            MainActor.assumeIsolated {
                coordinator?.handler?(event)
            }
        }
    }

    @MainActor
    private func makeView(context: Context) -> MTKView {
        let view = resolveRenderer(context.coordinator)?.metalView ?? MTKView()
        runSetupIfNeeded(context.coordinator)
        connect(context.coordinator)
        context.coordinator.apply(options, to: view)
        return view
    }

    @MainActor
    private func updateView(_ view: MTKView, context: Context) {
        connect(context.coordinator)
        context.coordinator.apply(options, to: view)
    }

    @MainActor
    private static func dismantleView(coordinator: Coordinator) {
        coordinator.subscription?.cancel()
        coordinator.subscription = nil
        coordinator.handler = nil
        coordinator.appliedOptions = nil
    }

    #if os(macOS)
        public func makeNSView(context: Context) -> MTKView {
            makeView(context: context)
        }

        public func updateNSView(_ view: MTKView, context: Context) {
            updateView(view, context: context)
        }

        public static func dismantleNSView(_: MTKView, coordinator: Coordinator) {
            dismantleView(coordinator: coordinator)
        }
    #else
        public func makeUIView(context: Context) -> MTKView {
            makeView(context: context)
        }

        public func updateUIView(_ view: MTKView, context: Context) {
            updateView(view, context: context)
        }

        public static func dismantleUIView(_: MTKView, coordinator: Coordinator) {
            dismantleView(coordinator: coordinator)
        }
    #endif

    /// Registers a block that runs exactly once, when the platform view is
    /// created and the renderer is ready. Use it for imperative scene setup
    /// (loading meshes, creating entities).
    ///
    /// - Note: The block used to run immediately at body-evaluation time, on
    ///   every SwiftUI re-evaluation. It is now deferred until the renderer
    ///   exists and runs a single time for the lifetime of the view.
    public func onInit(block: @escaping @MainActor () -> Void) -> Self {
        var copy = self
        copy.setupHandler = block
        return copy
    }
}
