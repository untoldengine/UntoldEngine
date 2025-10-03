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

// Scene Builder style to create a scene with herarchy
struct ContentView: View {
    @State var playerAngle: Float = 0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    var rootID: EntityID = createEntity()
    
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
