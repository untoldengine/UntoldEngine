//
//  UntoldView.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 6/9/25.
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
