//
//  EditorSceneView.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 23/9/25.
//
import SwiftUI
import UntoldEngine
import MetalKit

struct EditorSceneView: View, UntoldRendererDelegate {
    
    private var renderer: UntoldRenderer
    
    init(renderer: UntoldRenderer) {
        self.renderer = renderer
        self.renderer.delegate = self
    }
    
    public var body: some View {
        SceneView( renderer: renderer )
            .onInit {
                let sceneCamera = createEntity()
                createSceneCamera(entityId: sceneCamera)
                
                let gameCamera = createEntity()
                setEntityName(entityId: gameCamera, name: "Main Camera")
                createGameCamera(entityId: gameCamera)
                  
                let light = createEntity()
                setEntityName(entityId: light, name: "Directional Light")
                createDirLight(entityId: light)
                
                // Initialize ray vs model pipeline
                initRayPickerCompute()
                
                // Load Debug meshes and other editor / debug resources
                loadLightDebugMeshes()
            }
    }
    
    // UntoldRenderer delegate functions
    func willDraw(in view: MTKView) {
        if hotReload {
            // updateRayKernelPipeline()
            updateShadersAndPipeline()
            hotReload = false
        }
    }
    
    func didDraw(in view: MTKView) { }
}
