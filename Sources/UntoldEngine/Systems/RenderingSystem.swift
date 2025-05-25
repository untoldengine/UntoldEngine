//
//  RenderingSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 11/11/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
import CShaderTypes
import Foundation
import MetalKit

func updateRenderingSystem(in view: MTKView) {
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

            let lightVisPass = RenderPass(
                id: "lightvis", dependencies: ["model"], execute: RenderPasses.lightVisualPass
            )

            graph[lightVisPass.id] = lightVisPass

//            let outlinePass = RenderPass(
//                id: "outline", dependencies: ["lightvis"], execute: RenderPasses.outlineExecution
//            )
//
//            graph[outlinePass.id] = outlinePass

            let hightlightPass = RenderPass(
                id: "highlight", dependencies: ["lightvis"], execute: RenderPasses.highlightExecution
            )

            graph[hightlightPass.id] = hightlightPass

            let tonemapPass = RenderPass(
                id: "tonemap", dependencies: [modelPass.id],
                execute: tonemapRenderPass
            )

            graph[tonemapPass.id] = tonemapPass

//            let blurPass = RenderPass(id: "blur", dependencies: [hightlightPass.id], execute: blurRenderPass)
//
//            graph[blurPass.id] = blurPass

            let preCompositePass = RenderPass(
                id: "precomp", dependencies: [hightlightPass.id], execute: RenderPasses.preCompositeExecution
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
            let sortedPasses = try! topologicalSortGraph(graph: graph)

            // execute it
            executeGraph(graph, sortedPasses, commandBuffer)
        }

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }
}

// Post process passes

func toneMappingCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &ToneMappingParams.shared.toneMapOperator,
        length: MemoryLayout<Int>.stride,
        index: Int(toneMapPassToneMappingIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ToneMappingParams.shared.exposure,
        length: MemoryLayout<Float>.stride,
        index: Int(toneMapPassExposureIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ToneMappingParams.shared.gamma,
        length: MemoryLayout<Float>.stride,
        index: Int(toneMapPassGammaIndex.rawValue)
    )
}

var tonemapRenderPass = RenderPasses.executePostProcess(
    tonemappingPipeline,
    debugTexture: textureResources.toneMapDebugTexture!,
    customization: toneMappingCustomization
)
