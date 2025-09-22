//
//  ContentView.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 20/9/25.
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
        self.renderer?.initResources( )
    }
    
    var body: some View {
        VStack {
            SceneView( mtkView: mtkView )
        }
    }
}
