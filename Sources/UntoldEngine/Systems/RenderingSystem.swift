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
            var (graph, preCompID) = gameMode ? buildGameModeGraph() : buildEditModeGraph()
                    
            if visualDebug == false {
                let compositePass = RenderPass(
                    id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
                )

                graph[compositePass.id] = compositePass
            } else {
                let debugPass = RenderPass(
                    id: "debug", dependencies: [preCompID], execute: RenderPasses.debuggerExecution
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

// graphs

typealias RenderGraphResult = (graph: [String: RenderPass], finalPassID: String)

func buildEditModeGraph() -> RenderGraphResult {
    var graph = [String: RenderPass]()
    
    let basePassID: String
    if renderEnvironment {
        let environmentPass = RenderPass(
            id: "environment", dependencies: [], execute: RenderPasses.executeEnvironmentPass
        )
        graph[environmentPass.id] = environmentPass
        basePassID = environmentPass.id
    } else {
        let gridPass = RenderPass(
            id: "grid", dependencies: [], execute: RenderPasses.gridExecution
        )
        graph[gridPass.id] = gridPass
        basePassID = gridPass.id
    }
    
    let modelPass = RenderPass(
        id: "model", dependencies: [basePassID], execute: RenderPasses.modelExecution
    )
    graph[modelPass.id] = modelPass
    
    let highlightPass = RenderPass(
        id: "highlight", dependencies: [modelPass.id], execute: RenderPasses.highlightExecution
    )
    graph[highlightPass.id] = highlightPass
    
    let preCompPass = RenderPass(
        id: "precomp", dependencies: [highlightPass.id], execute: RenderPasses.preCompositeExecution
    )
    graph[preCompPass.id] = preCompPass
    
    return (graph, preCompPass.id)
}

func buildGameModeGraph() -> RenderGraphResult {
    var graph = [String: RenderPass]()
    
    let basePassID: String
    if renderEnvironment {
        let environmentPass = RenderPass(
            id: "environment", dependencies: [], execute: RenderPasses.executeEnvironmentPass
        )
        graph[environmentPass.id] = environmentPass
        basePassID = environmentPass.id
    } else {
        let gridPass = RenderPass(
            id: "grid", dependencies: [], execute: RenderPasses.gridExecution
        )
        graph[gridPass.id] = gridPass
        basePassID = gridPass.id
    }
    
    let shadowPass = RenderPass(
        id: "shadow", dependencies: [basePassID], execute: RenderPasses.shadowExecution
    )
    graph[shadowPass.id] = shadowPass
    
    let modelPass = RenderPass(
        id: "model", dependencies: [shadowPass.id], execute: RenderPasses.modelExecution
    )
    graph[modelPass.id] = modelPass
    
    let tonemapPass = RenderPass(id: "tonemap", dependencies: [modelPass.id], execute: tonemapRenderPass)
    graph[tonemapPass.id] = tonemapPass
    
    let colorCorrectionPass = RenderPass(id: "colorcorrection", dependencies: [tonemapPass.id], execute: colorCorrectionRenderPass)
    graph[colorCorrectionPass.id] = colorCorrectionPass
    
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
    
    let blurCompositePass = RenderPass(id: "blurComposite", dependencies: [blurPassVer.id], execute: bloomCompositeRenderPass)
    graph[blurCompositePass.id] = blurCompositePass
    
    let colorgradingPass = RenderPass(id: "colorgrading", dependencies: [blurCompositePass.id], execute: colorGradingRenderPass)
    graph[colorgradingPass.id] = colorgradingPass
    
    let vignettePass = RenderPass(id: "vignette", dependencies: [colorgradingPass.id], execute: vignetteRenderPass)
    
    graph[vignettePass.id] = vignettePass
    
    let chromaticAberrationPass = RenderPass(id: "chromatic", dependencies: [vignettePass.id], execute: chromaticAberrationRenderPass)
    
    graph[chromaticAberrationPass.id] = chromaticAberrationPass
    
    let depthOfFieldPass = RenderPass(id: "depthOfField", dependencies: [chromaticAberrationPass.id], execute: depthOfFieldRenderPass)
    
    graph[depthOfFieldPass.id] = depthOfFieldPass

    
    let preCompPass = RenderPass(id: "precomp", dependencies: [colorgradingPass.id], execute: RenderPasses.preCompositeExecution)
    graph[preCompPass.id] = preCompPass
    
    return (graph, preCompPass.id)
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
    source: textureResources.bloomCompositeTexture!,
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

    encoder.setFragmentTexture(textureResources.colorCorrectionTexture, index: 1)
}

var vignetteRenderPass = RenderPasses.executePostProcess(
    vignettePipeline,
    source: textureResources.colorGradingTexture!,
    destination: textureResources.vignetteTexture!,
    customization: vignetteCustomization
)

func vignetteCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &VignetteParams.shared.intensity,
        length: MemoryLayout<Float>.stride,
        index: Int(vignettePassIntensityIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &VignetteParams.shared.radius,
        length: MemoryLayout<Float>.stride,
        index: Int(vignettePassRadiusIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &VignetteParams.shared.softness,
        length: MemoryLayout<Float>.stride,
        index: Int(vignettePassSoftnessIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &VignetteParams.shared.center,
        length: MemoryLayout<simd_float2>.stride,
        index: Int(vignettePassCenterIndex.rawValue)
    )

}

var chromaticAberrationRenderPass = RenderPasses.executePostProcess(
    chromaticAberrationPipeline,
    source: textureResources.vignetteTexture!,
    destination: textureResources.chromaticAberrationTexture!,
    customization: chromaticAberrationCustomization
)

func chromaticAberrationCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &ChromaticAberrationParams.shared.intensity,
        length: MemoryLayout<Float>.stride,
        index: Int(chromaticAberrationPassIntensityIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &ChromaticAberrationParams.shared.center,
        length: MemoryLayout<simd_float2>.stride,
        index: Int(chromaticAberrationPassCenterIndex.rawValue)
    )
}

var depthOfFieldRenderPass = RenderPasses.executePostProcess(
    depthOfFieldPipeline,
    source: textureResources.chromaticAberrationTexture!,
    destination: textureResources.depthOfFieldTexture!,
    customization: depthOfFieldCustomization
)

func depthOfFieldCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &DepthOfFieldParams.shared.focusDistance,
        length: MemoryLayout<Float>.stride,
        index: Int(depthOfFieldPassFocusDistanceIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &DepthOfFieldParams.shared.focusRange,
        length: MemoryLayout<Float>.stride,
        index: Int(depthOfFieldPassFocusRangeIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &DepthOfFieldParams.shared.maxBlur,
        length: MemoryLayout<Float>.stride,
        index: Int(depthOfFieldPassMaxBlurIndex.rawValue)
    )
    
    encoder.setFragmentTexture(textureResources.depthMap, index: 1)
    
    var frustumPlanes: simd_float2 = simd_float2(near, far)
    encoder.setFragmentBytes(&frustumPlanes, length: MemoryLayout<simd_float2>.stride, index: Int(depthOfFieldPassFrustumIndex.rawValue))
}


var ssaoRenderPass = RenderPasses.executePostProcess(
    ssaoPipeline,
    source: textureResources.depthOfFieldTexture!,
    destination: textureResources.ssaoTexture!,
    customization: ssaoCustomization
)

func ssaoCustomization(encoder: MTLRenderCommandEncoder) {
    encoder.setFragmentBytes(
        &SSAOParams.shared.radius,
        length: MemoryLayout<Float>.stride,
        index: Int(ssaoPassRadiusIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &SSAOParams.shared.bias,
        length: MemoryLayout<Float>.stride,
        index: Int(ssaoPassBiasIndex.rawValue)
    )
    
    encoder.setFragmentBytes(
        &SSAOParams.shared.intensity,
        length: MemoryLayout<Float>.stride,
        index: Int(ssaoPassIntensityIndex.rawValue)
    )
}
