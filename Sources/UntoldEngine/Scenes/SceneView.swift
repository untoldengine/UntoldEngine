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
    var mtkView: MTKView
    private var renderer: UntoldRenderer?
    private var updateHandler: (@MainActor (UpdateEvent) -> Void)?

    // TODO: Maybe we should thow an error on init instead of allowing nil renderer value
    public init(renderer: UntoldRenderer? = nil, updateHandler: (@MainActor (UpdateEvent) -> Void)? = nil) {
        self.renderer = renderer ?? UntoldRenderer.create()
        self.updateHandler = updateHandler
        mtkView = self.renderer!.metalView
    }

    /// Persists across SwiftUI re-inits of the view struct; owns the frame-event
    /// subscription so it is created once and cancelled on dismantle.
    @MainActor
    public final class Coordinator {
        var handler: (@MainActor (UpdateEvent) -> Void)?
        var subscription: EventSubscription?
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func connect(_ coordinator: Coordinator) {
        coordinator.handler = updateHandler
        guard coordinator.subscription == nil, updateHandler != nil, let renderer else { return }
        coordinator.subscription = renderer.onUpdate { [weak coordinator] event in
            // The MTKView delegate draws on the main thread; trap loudly if a
            // future host ever drives this renderer off-main.
            MainActor.assumeIsolated {
                coordinator?.handler?(event)
            }
        }
    }

    #if os(macOS)
        public func makeNSView(context: Context) -> MTKView {
            connect(context.coordinator)
            return mtkView
        }

        public func updateNSView(_: MTKView, context: Context) {
            connect(context.coordinator)
            updateView(mtkView, context: context)
        }

        public static func dismantleNSView(_: MTKView, coordinator: Coordinator) {
            coordinator.subscription?.cancel()
            coordinator.subscription = nil
            coordinator.handler = nil
        }
    #else
        public func makeUIView(context: Context) -> MTKView {
            connect(context.coordinator)
            return mtkView
        }

        public func updateUIView(_ mtkView: MTKView, context: Context) {
            connect(context.coordinator)
            updateView(mtkView, context: context)
        }

        public static func dismantleUIView(_: MTKView, coordinator: Coordinator) {
            coordinator.subscription?.cancel()
            coordinator.subscription = nil
            coordinator.handler = nil
        }
    #endif

    public func updateView(_: MTKView, context _: Context) {}

    public func onInit(block: @escaping () -> Void) -> Self {
        block()
        return self
    }
}
