//
//  EditorSceneView.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//
import MetalKit
import SwiftUI
import UntoldEngine

struct EditorSceneView: View, UntoldRendererDelegate {
    private var renderer: UntoldRenderer

    init(renderer: UntoldRenderer) {
        self.renderer = renderer
        self.renderer.delegate = self
    }

    public var body: some View {
        SceneView(renderer: renderer)
            .onInit {
                let sceneCamera = createEntity()
                createSceneCamera(entityId: sceneCamera)

                let gameCamera = createEntity()
                setEntityName(entityId: gameCamera, name: "Main Camera")
                createGameCamera(entityId: gameCamera)

                let light = createEntity()
                setEntityName(entityId: light, name: "Directional Light")
                createDirLight(entityId: light)

                CameraSystem.shared.activeCamera = sceneCamera

                // Initialize ray vs model pipeline
                initRayPickerCompute()

                // Load Debug meshes and other editor / debug resources
                loadLightDebugMeshes()
            }
    }

    // UntoldRenderer delegate functions
    func willDraw(in _: MTKView) {
        if hotReload {
            // updateRayKernelPipeline()
            updateShadersAndPipeline()
            hotReload = false
        }
    }

    func didDraw(in _: MTKView) {}
}
