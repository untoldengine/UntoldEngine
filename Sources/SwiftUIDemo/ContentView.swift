//
//  ContentView.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import SwiftUI
import UntoldEngine
import simd
import MetalKit

struct ContentView: View {
    var mtkView: MTKView
    var renderer: UntoldRenderer?
    
    init() {
        self.renderer = UntoldRenderer.create()
        self.mtkView = self.renderer?.metalView ?? MTKView( )
    }
    
    var body: some View {
        VStack {
            SceneView( renderer: renderer )
        }
    }
}
