//
//  UntoldView.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import SwiftUI
import MetalKit

public struct UntoldView: View {
    @State private var metalView: MTKView
    private var renderer: UntoldRenderer?
    private var content:[any NodeProtocol] = []
    
    public init(renderer: UntoldRenderer? = nil, @SceneBuilder _ content: @escaping () -> [any NodeProtocol]) {
        self.renderer = renderer ?? UntoldRenderer.create( )
        self.metalView = self.renderer?.metalView ?? MTKView()
        self.content = content()
    }
    
    public var body: some View {
        SceneView(renderer: renderer)
    }
}
