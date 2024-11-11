//
//  RenderingSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 11/11/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.

import Foundation
import MetalKit

func updateRenderingSystem(in view: MTKView){
    
    if let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() {
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor {
            renderInfo.renderPassDescriptor = renderPassDescriptor

            // build a render graph
            var graph = [String: RenderPass]()

            var passthrough: String

            if renderEnvironment == false {
                let gridPass = RenderPass(
                    id: "grid", dependencies: [], execute: RenderPasses.gridExecution
                )
                graph[gridPass.id] = gridPass

                passthrough = gridPass.id
            } else {
                let environmentPass = RenderPass(
                    id: "environment", dependencies: [], execute: RenderPasses.executeEnvironmentPass
                )
                graph[environmentPass.id] = environmentPass

                passthrough = environmentPass.id
            }

            let shadowPass = RenderPass(
                id: "shadow", dependencies: [passthrough], execute: RenderPasses.shadowExecution
            )

            graph[shadowPass.id] = shadowPass

            let modelPass = RenderPass(
                id: "model", dependencies: ["shadow"], execute: RenderPasses.modelExecution
            )

            graph[modelPass.id] = modelPass

            let highlightPass = RenderPass(
                id: "highlight", dependencies: ["model"], execute: RenderPasses.highlightExecution
            )

            graph[highlightPass.id] = highlightPass

            let tonemapPass = RenderPass(
                id: "tonemap", dependencies: ["highlight"],
                execute: RenderPasses.executeTonemapPass(tonemappingPipeline)
            )

            graph[tonemapPass.id] = tonemapPass

            let preCompositePass = RenderPass(
                id: "precomp", dependencies: ["tonemap"], execute: RenderPasses.preCompositeExecution
            )

            graph[preCompositePass.id] = preCompositePass

            if visualDebug == false {
                let compositePass = RenderPass(
                    id: "composite", dependencies: ["precomp"], execute: RenderPasses.compositeExecution
                )

                graph[compositePass.id] = compositePass
            } else {
                let debugPass = RenderPass(
                    id: "debug", dependencies: ["precomp"], execute: RenderPasses.debuggerExecution
                )

                graph[debugPass.id] = debugPass
            }

            // sorted it
            let sortedPasses = topologicalSortGraph(graph: graph)

            // execute it
            executeGraph(graph, sortedPasses, commandBuffer)
        }

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }
    
}
