//
//  SceneView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//
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

    //TODO: Maybe we should thow an error on init instead of allowing nil renderer value
    public init( renderer: UntoldRenderer? = nil) {
        self.renderer = renderer ?? UntoldRenderer.create()
        self.mtkView = self.renderer!.metalView
    }
    
#if os(macOS)
    public func makeNSView(context: Context) -> MTKView {
        mtkView
    }

    public func updateNSView( _ view: MTKView, context : Context) {
        updateView(mtkView, context: context)
    }
#else
    public func makeUIView(context: Context) -> MTKView {
        mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        updateView(mtkView, context: context)
    }
#endif
    
    public func updateView(_ view: MTKView, context: Context) { }
    
    public func onInit( block: @escaping () -> Void ) -> Self {
        block()
        return self
    }
}

