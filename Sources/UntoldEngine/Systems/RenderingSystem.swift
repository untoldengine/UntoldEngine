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

            let hightlightPass = RenderPass(
                id: "highlight", dependencies: ["lightvis"], execute: RenderPasses.highlightExecution
            )

            graph[hightlightPass.id] = hightlightPass

            let tonemapPass = RenderPass(
                id: "tonemap", dependencies: [modelPass.id],
                execute: tonemapRenderPass
            )

            graph[tonemapPass.id] = tonemapPass

            let colorCorrectionPass = RenderPass(
                id: "colorcorrection", dependencies: [tonemapPass.id], execute: colorCorrectionRenderPass
            )

            graph[colorCorrectionPass.id] = colorCorrectionPass

            let colorgradingPass = RenderPass(
                id: "colorgrading", dependencies: [colorCorrectionPass.id],
                execute: colorGradingRenderPass
            )

            graph[colorgradingPass.id] = colorgradingPass
            
            let bloomThresholdPass = RenderPass(id: "bloomThreshold", dependencies: [colorCorrectionPass.id], execute: bloomThresholdRenderPass)

            graph[bloomThresholdPass.id] = bloomThresholdPass

            let blurPassHor = RenderPass(id: "blur_pass_hor", dependencies: [bloomThresholdPass.id], execute: RenderPasses.executePostProcess(
                blurPipeline,
                source: textureResources.bloomThresholdTextuture!,
                destination: textureResources.blurTextureHor!,
                customization: makeBlurCustomization(direction: simd_float2(1.0, 0.0), radius: 4.0)))

            graph[blurPassHor.id] = blurPassHor

            let blurPassVer = RenderPass(id: "blur_pass_ver", dependencies: [blurPassHor.id], execute: RenderPasses.executePostProcess(
                blurPipeline,
                source: textureResources.blurTextureHor!,
                destination: textureResources.blurTextureVer!,
                customization: makeBlurCustomization(direction: simd_float2(0.0, 1.0), radius: 4.0)))

            graph[blurPassVer.id] = blurPassVer

            let blurCompositePass = RenderPass(id: "blurComposite" , dependencies: [blurPassVer.id], execute: bloomCompositeRenderPass)  

            graph[blurCompositePass.id] = blurCompositePass

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
    source: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!,
    destination: textureResources.tonemapTexture!,
    customization: toneMappingCustomization
)

func colorCorrectionCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &ColorCorrectionParams.shared.temperature,
        length: MemoryLayout<Float>.stride,
        index: Int(colorCorrectionPassTemperatureIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorCorrectionParams.shared.tint,
        length: MemoryLayout<Float>.stride,
        index: Int(colorCorrectionPassTintIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorCorrectionParams.shared.lift,
        length: MemoryLayout<simd_float3>.stride,
        index: Int(colorCorrectionPassLiftIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorCorrectionParams.shared.gamma,
        length: MemoryLayout<simd_float3>.stride,
        index: Int(colorCorrectionPassGammaIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorCorrectionParams.shared.gain,
        length: MemoryLayout<simd_float3>.stride,
        index: Int(colorCorrectionPassGainIndex.rawValue)
    )
}

var colorCorrectionRenderPass = RenderPasses.executePostProcess(
    colorCorrectionPipeline,
    source: textureResources.tonemapTexture!,
    destination: textureResources.colorCorrectionTexture!,
    customization: colorCorrectionCustomization
)

func colorGradingCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &ColorGradingParams.shared.brightness,
        length: MemoryLayout<Float>.stride,
        index: Int(colorGradingPassBrightnessIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorGradingParams.shared.saturation,
        length: MemoryLayout<Float>.stride,
        index: Int(colorGradingPassSaturationIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorGradingParams.shared.contrast,
        length: MemoryLayout<Float>.stride,
        index: Int(colorGradingPassContrastIndex.rawValue)
    )
}

var colorGradingRenderPass = RenderPasses.executePostProcess(
    colorGradingPipeline,
    source: textureResources.colorCorrectionTexture!,
    destination: textureResources.colorGradingTexture!,
    customization: colorGradingCustomization
)

func makeBlurCustomization(direction: simd_float2, radius: Float) -> (MTLRenderCommandEncoder) -> Void {
    { encoder in
        var dir = direction
        var r = radius

        encoder.setFragmentBytes(
            &dir,
            length: MemoryLayout<simd_float2>.stride,
            index: Int(blurPassDirectionIndex.rawValue)
        )
        encoder.setFragmentBytes(
            &r,
            length: MemoryLayout<Float>.stride,
            index: Int(blurPassRadiusIndex.rawValue)
        )
    }
}

var bloomThresholdRenderPass = RenderPasses.executePostProcess(
    bloomThresholdPipeline,
    source: textureResources.colorCorrectionTexture!,
    destination: textureResources.bloomThresholdTextuture!,
    customization: bloomThresholdCustomization
)

func bloomThresholdCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &BloomThresholdParams.shared.threshold,
        length: MemoryLayout<Float>.stride,
        index: Int(bloomThresholdPassCutoffIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &BloomThresholdParams.shared.intensity,
        length: MemoryLayout<Float>.stride,
        index: Int(bloomThresholdPassIntensityIndex.rawValue)
    )

}

var bloomCompositeRenderPass = RenderPasses.executePostProcess(
    bloomCompositePipeline,
    source: textureResources.blurTextureVer!,
    destination: textureResources.bloomCompositeTexture!,
    customization: bloomCompositeCustomization
)

func bloomCompositeCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &BloomCompositeParams.shared.intensity,
        length: MemoryLayout<Float>.stride,
        index: Int(bloomCompositePassIntensityIndex.rawValue)
    )


    encoder.setFragmentTexture(textureResources.colorMap, index: 1)

}
