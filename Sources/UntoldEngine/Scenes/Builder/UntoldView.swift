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

    public init(renderer: UntoldRenderer? = nil, @SceneBuilder _ content: @escaping @MainActor () -> [any NodeProtocol]) {
        self.renderer = renderer ?? UntoldRenderer.create()
        metalView = self.renderer?.metalView ?? MTKView()
        self.content = content()
    }

    public var body: some View {
        SceneView(renderer: renderer)
    }
}
