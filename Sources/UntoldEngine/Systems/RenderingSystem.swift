//
//  RenderingSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 11/11/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.

import CShaderTypes
import Foundation
import MetalKit

public typealias UpdateRenderingSystemCallback = (MTKView) -> Void

func UpdateRenderingSystem(in view: MTKView) {
    
    if let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() {
        
        executeFrustumCulling(commandBuffer)
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor {
            renderInfo.renderPassDescriptor = renderPassDescriptor

            commandBuffer.label = "Rendering Command Buffer"
            
            // build a render graph
            var (graph, preCompID) = buildGameModeGraph()

            let compositePass = RenderPass(
                id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
            )

            graph[compositePass.id] = compositePass

            // sorted it
            let sortedPasses = try! topologicalSortGraph(graph: graph)

            // execute it
            executeGraph(graph, sortedPasses, commandBuffer)
        }

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.addCompletedHandler { _ in

            DispatchQueue.main.async {
                needsFinalizeDestroys = true
                visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
            }
        }

        commandBuffer.commit()
    }
}

// graphs

public typealias RenderGraphResult = (graph: [String: RenderPass], finalPassID: String)

public func buildGameModeGraph() -> RenderGraphResult {
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

    let ssaoPass = RenderPass(id: "ssao", dependencies: [modelPass.id], execute: RenderPasses.ssaoExecution)

    graph[ssaoPass.id] = ssaoPass

    let ssaoBlurPass = RenderPass(id: "ssaoBlur", dependencies: [ssaoPass.id], execute: RenderPasses.ssaoBlurExecution)

    graph[ssaoBlurPass.id] = ssaoBlurPass

    let lightPass = RenderPass(id: "lightPass", dependencies: [modelPass.id, shadowPass.id, ssaoBlurPass.id], execute: RenderPasses.lightExecution)

    graph[lightPass.id] = lightPass

    let depthOfFieldPass = RenderPass(id: "depthOfField", dependencies: [lightPass.id], execute: depthOfFieldRenderPass)

    graph[depthOfFieldPass.id] = depthOfFieldPass

    let chromaticAberrationPass = RenderPass(id: "chromatic", dependencies: [depthOfFieldPass.id], execute: chromaticAberrationRenderPass)

    graph[chromaticAberrationPass.id] = chromaticAberrationPass

    let bloomThresholdPass = RenderPass(id: "bloomThreshold", dependencies: [chromaticAberrationPass.id, modelPass.id], execute: bloomThresholdRenderPass)
    graph[bloomThresholdPass.id] = bloomThresholdPass

    // define params for the blur pass
    let blurPassCount = BloomThresholdParams.shared.enabled ? 2 : 0
    let blurRadius: Float = 4.0

    var previousPassID = bloomThresholdPass.id
    var useFirstTexture = true

    for i in 0 ..< blurPassCount {
        let horID = "blur_pass_hor_pass\(i + 1)"
        let verID = "blur_pass_ver_pass\(i + 1)"

        let horSource = useFirstTexture ? textureResources.bloomThresholdTextuture! : textureResources.blurTextureVer!
        let horDestination = textureResources.blurTextureHor!

        let horPass = RenderPass(
            id: horID,
            dependencies: [previousPassID],
            execute: RenderPasses.executePostProcess(
                PipelineManager.shared.renderPipelinesByType[.blur]!,
                source: horSource,
                destination: horDestination,
                customization: makeBlurCustomization(direction: simd_float2(1.0, 0.0), radius: blurRadius)
            )
        )

        graph[horID] = horPass

        let verPass = RenderPass(
            id: verID,
            dependencies: [horID],
            execute: RenderPasses.executePostProcess(
                PipelineManager.shared.renderPipelinesByType[.blur]!,
                source: horDestination,
                destination: textureResources.blurTextureVer!,
                customization: makeBlurCustomization(direction: simd_float2(0.0, 1.0), radius: blurRadius)
            )
        )

        graph[verID] = verPass

        previousPassID = verID

        useFirstTexture = false // only use bloomthreshold texture for first iteration
    }

    let bloomCompositePass = RenderPass(id: "bloomComposite", dependencies: [previousPassID], execute: bloomCompositeRenderPass)
    graph[bloomCompositePass.id] = bloomCompositePass

    let colorgradingPass = RenderPass(id: "colorgrading", dependencies: [bloomCompositePass.id], execute: colorGradingRenderPass)
    graph[colorgradingPass.id] = colorgradingPass

    let vignettePass = RenderPass(id: "vignette", dependencies: [colorgradingPass.id], execute: vignetteRenderPass)

    graph[vignettePass.id] = vignettePass

    let preCompPass = RenderPass(id: "precomp", dependencies: [vignettePass.id], execute: RenderPasses.preCompositeExecution)
    graph[preCompPass.id] = preCompPass

    return (graph, preCompPass.id)
}

// Post process passes

func colorCorrectionCustomization(encoder: MTLRenderCommandEncoder) {
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

    encoder.setFragmentBytes(
        &ColorCorrectionParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(colorCorrectionPassEnabledIndex.rawValue)
    )
}

var colorCorrectionRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.colorCorrection]!,
    source: textureResources.tonemapTexture!,
    destination: textureResources.colorCorrectionTexture!,
    customization: colorCorrectionCustomization
)

func colorGradingCustomization(encoder: MTLRenderCommandEncoder) {
    var exposure = powf(2.0, ColorGradingParams.shared.exposure)
    var contrast = ColorGradingParams.shared.contrast
    var whiteBalanceCoeffs: simd_float3 = colorBalanceToLMSCoeffs(temperature: ColorGradingParams.shared.temperature, tint: ColorGradingParams.shared.tint)

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
        &contrast,
        length: MemoryLayout<Float>.stride,
        index: Int(colorGradingPassContrastIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &exposure,
        length: MemoryLayout<Float>.stride,
        index: Int(colorGradingPassExposureIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &ColorGradingParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(colorGradingPassEnabledIndex.rawValue)
    )

    encoder.setFragmentBytes(
        &whiteBalanceCoeffs,
        length: MemoryLayout<simd_float3>.stride,
        index: Int(colorGradingWhiteBalanceCoeffsIndex.rawValue)
    )
}

var colorGradingRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.colorGrading]!,
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

        encoder.setFragmentBytes(
            &BloomThresholdParams.shared.enabled,
            length: MemoryLayout<Bool>.stride,
            index: Int(blurPassEnabledIndex.rawValue)
        )
    }
}

var bloomThresholdRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.bloomThreshold]!,
    source: textureResources.chromaticAberrationTexture!,
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

    encoder.setFragmentBytes(
        &BloomThresholdParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(bloomThresholdPassEnabledIndex.rawValue)
    )

    encoder.setFragmentTexture(textureResources.emissiveMap, index: 1)
}

var bloomCompositeRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.bloomComposite]!,
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

    encoder.setFragmentTexture(textureResources.chromaticAberrationTexture, index: 1)

    encoder.setFragmentBytes(
        &BloomThresholdParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(bloomCompositePassEnabledIndex.rawValue)
    )
}

var vignetteRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.vignette]!,
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

    encoder.setFragmentBytes(
        &VignetteParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(vignettePassEnabledIndex.rawValue)
    )
}

var chromaticAberrationRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.chromaticAberration]!,
    source: textureResources.depthOfFieldTexture!,
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

    encoder.setFragmentBytes(
        &ChromaticAberrationParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(chromaticAberrationPassEnabledIndex.rawValue)
    )
}

var depthOfFieldRenderPass = RenderPasses.executePostProcess(
    PipelineManager.shared.renderPipelinesByType[.depthOfField]!,
    source: textureResources.deferredColorMap!,
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

    encoder.setFragmentBytes(
        &DepthOfFieldParams.shared.enabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(depthOfFieldPassEnabledIndex.rawValue)
    )

    encoder.setFragmentTexture(textureResources.depthMap, index: 1)

    var frustumPlanes = simd_float2(near, far)
    encoder.setFragmentBytes(&frustumPlanes, length: MemoryLayout<simd_float2>.stride, index: Int(depthOfFieldPassFrustumIndex.rawValue))
}

/*
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

     encoder.setFragmentBytes(
         &SSAOParams.shared.enabled,
         length: MemoryLayout<Bool>.stride,
         index: Int(ssaoPassEnabledIndex.rawValue)
     )
 }
 */
