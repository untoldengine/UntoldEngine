//
//  ContentView.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import MetalKit
import simd
import SwiftUI
import UntoldEngine

struct ContentView: View {
    var mtkView: MTKView
    var renderer: UntoldRenderer?

    init() {
        renderer = UntoldRenderer.create()
        mtkView = renderer?.metalView ?? MTKView()
    }

    var body: some View {
        VStack {
            SceneView(renderer: renderer)
        }
    }
}
