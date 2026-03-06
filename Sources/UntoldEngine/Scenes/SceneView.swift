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

    // TODO: Maybe we should thow an error on init instead of allowing nil renderer value
    public init(renderer: UntoldRenderer? = nil) {
        self.renderer = renderer ?? UntoldRenderer.create()
        mtkView = self.renderer!.metalView
    }

    #if os(macOS)
        public func makeNSView(context _: Context) -> MTKView {
            mtkView
        }

        public func updateNSView(_: MTKView, context: Context) {
            updateView(mtkView, context: context)
        }
    #else
        public func makeUIView(context _: Context) -> MTKView {
            mtkView
        }

        public func updateUIView(_ mtkView: MTKView, context: Context) {
            updateView(mtkView, context: context)
        }
    #endif

    public func updateView(_: MTKView, context _: Context) {}

    public func onInit(block: @escaping () -> Void) -> Self {
        block()
        return self
    }
}
