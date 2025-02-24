//
//  SceneView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import MetalKit
import SwiftUI

struct SceneView: NSViewRepresentable {
    var mtkView: MTKView

    func makeNSView(context _: Context) -> MTKView {
        mtkView
    }

    func updateNSView(_: MTKView, context _: Context) {}
}
