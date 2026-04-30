//
//  RenderingSystem.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import MetalKit
import QuartzCore

public enum RenderingSystemContext {
    case view(_ view: MTKView)
    case xr(commandBuffer: MTLCommandBuffer, passDescriptor: MTLRenderPassDescriptor)
}

public typealias UpdateRenderingSystemCallback = @MainActor (MTKView) -> Void
public typealias UpdateXRRenderingSystemCallback = (RenderingSystemContext) -> Void

@MainActor
func UpdateRenderingSystem(in view: MTKView) {
    // Snapshot loading gate once per frame. While loading, keep rendering from the
    // last-known-good visible list and skip ECS traversal to avoid race conditions.
    let loading = AssetLoadingGate.shared.isLoadingAny

    // Update visible entity list only when not loading (avoids reading mutating ECS data)
    if !loading {
        visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
    }

    // Wait for available command buffer slot to prevent unbounded memory growth
    commandBufferSemaphore.wait()

    if let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() {
        #if ENGINE_STATS_ENABLED
            let renderTotalStart = CACurrentMediaTime()
        #endif
        renderInfo.lastCommandBuffer = commandBuffer
        renderInfo.currentInFlightFrameSlot = acquireUniformFrameSlot()

        // Skip render prep (culling, gaussian, bitonic) while loading - these traverse ECS.
        // The render graph still executes using the stale visibleEntityIds.
        if !loading {
            SceneRootTransform.shared.updateIfNeeded()
            #if ENGINE_STATS_ENABLED
                let renderPrepStart = CACurrentMediaTime()
            #endif
            EngineProfiler.shared.beginScope(.renderPrep)

            #if ENGINE_STATS_ENABLED
                let cullingStart = CACurrentMediaTime()
            #endif
            EngineProfiler.shared.beginScope(.culling)
            performFrustumCulling(commandBuffer: commandBuffer)
            EngineProfiler.shared.endScope(.culling)
            #if ENGINE_STATS_ENABLED
                let cullingMs = (CACurrentMediaTime() - cullingStart) * 1000.0
                EngineStatsMonitor.shared.update { snapshot in
                    snapshot.timing.cullingMs += cullingMs
                }
            #endif

            executeGaussianDepth(commandBuffer)
            executeBitonicSort(commandBuffer)
            EngineProfiler.shared.endScope(.renderPrep)
            #if ENGINE_STATS_ENABLED
                let renderPrepMs = (CACurrentMediaTime() - renderPrepStart) * 1000.0
                EngineStatsMonitor.shared.update { snapshot in
                    snapshot.timing.renderPrepMs += renderPrepMs
                }
            #endif
        }

        if let renderPassDescriptor = view.currentRenderPassDescriptor {
            renderInfo.renderPassDescriptor = renderPassDescriptor

            commandBuffer.label = "Rendering Command Buffer"

            // build a render graph
            let (graph, _) = buildGameModeGraph()

            // sorted it
            let sortedPasses = try! topologicalSortGraph(graph: graph)

            // execute it
            #if ENGINE_STATS_ENABLED
                let encodeStart = CACurrentMediaTime()
            #endif
            EngineProfiler.shared.beginScope(.encode)
            executeGraph(graph, sortedPasses, commandBuffer)
            // Temporal HZB schedule:
            // 1) current frame renders depth
            // 2) build HZB from that depth
            // 3) next frame culling consumes HZB
            buildHZBDepthPyramid(commandBuffer)
            EngineProfiler.shared.endScope(.encode)
            #if ENGINE_STATS_ENABLED
                let encodeMs = (CACurrentMediaTime() - encodeStart) * 1000.0
                EngineStatsMonitor.shared.update { snapshot in
                    snapshot.timing.encodeMs += encodeMs
                }
            #endif
        }

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        EngineProfiler.shared.attach(to: commandBuffer, label: "MainFrame")

        let visibleEntityIdsAtSubmission = visibleEntityIds
        commandBuffer.addCompletedHandler { cb in
            #if ENGINE_STATS_ENABLED
                let gpuExecutionMs = (cb.gpuEndTime - cb.gpuStartTime) * 1000.0
                EngineStatsMonitor.shared.recordGPUCompletion(executionMs: gpuExecutionMs)
            #endif
            // Signal that this command buffer slot is now available
            commandBufferSemaphore.signal()

            needsFinalizeDestroys = true
            MemoryBudgetManager.shared.markUsed(entityIds: visibleEntityIdsAtSubmission)
        }

        #if ENGINE_STATS_ENABLED
            let submitStart = CACurrentMediaTime()
        #endif
        commandBuffer.commit()
        #if ENGINE_STATS_ENABLED
            let submitMs = (CACurrentMediaTime() - submitStart) * 1000.0
            let renderTotalMs = (CACurrentMediaTime() - renderTotalStart) * 1000.0
            EngineStatsMonitor.shared.update { snapshot in
                snapshot.timing.submitMs += submitMs
                snapshot.timing.renderTotalMs += renderTotalMs
            }
        #endif
    } else {
        // Failed to create command buffer - release semaphore
        commandBufferSemaphore.signal()
    }
}

func UpdateXRRenderingSystem(commandBuffer: MTLCommandBuffer, passDescriptor: MTLRenderPassDescriptor) {
    #if ENGINE_STATS_ENABLED
        let shouldRecordStatsInThisCallback = (renderInfo.immersionStyle == .ar)
        let renderTotalStart = shouldRecordStatsInThisCallback ? CACurrentMediaTime() : 0.0
    #endif
    // Note: Per-frame work (culling, gaussian, bitonic) is done BEFORE the eye loop in XR
    // to avoid running it twice (once per eye). See executeXRSystemPass in UntoldEngineXR.swift

    renderInfo.renderPassDescriptor = passDescriptor

    commandBuffer.label = "XR Rendering Command Buffer"

    // build a render graph
    let (graph, _) = buildGameModeGraph()

    // sorted it
    let sortedPasses = try! topologicalSortGraph(graph: graph)

    // execute it
    #if ENGINE_STATS_ENABLED
        let encodeStart = shouldRecordStatsInThisCallback ? CACurrentMediaTime() : 0.0
    #endif
    executeGraph(graph, sortedPasses, commandBuffer)

    // AR path renders a single eye through this callback, so build HZB here.
    // XR stereo path builds once after both eyes in UntoldEngineXR.executeXRSystemPass.
    if renderInfo.immersionStyle == .ar {
        buildHZBDepthPyramid(commandBuffer)
    }
    #if ENGINE_STATS_ENABLED
        if shouldRecordStatsInThisCallback {
            let encodeMs = (CACurrentMediaTime() - encodeStart) * 1000.0
            let renderTotalMs = (CACurrentMediaTime() - renderTotalStart) * 1000.0
            EngineStatsMonitor.shared.update { snapshot in
                snapshot.timing.encodeMs += encodeMs
                snapshot.timing.renderTotalMs += renderTotalMs
            }
        }
    #endif

    // Note: Semaphore signaling is handled by executeXRSystemPass completion handler
    let visibleEntityIdsAtSubmission = visibleEntityIds
    commandBuffer.addCompletedHandler { cb in
        #if ENGINE_STATS_ENABLED
            if renderInfo.immersionStyle == .ar {
                let gpuExecutionMs = (cb.gpuEndTime - cb.gpuStartTime) * 1000.0
                EngineStatsMonitor.shared.recordGPUCompletion(executionMs: gpuExecutionMs)
            }
        #endif
        needsFinalizeDestroys = true
        MemoryBudgetManager.shared.markUsed(entityIds: visibleEntityIdsAtSubmission)
    }
}

// graphs

public typealias RenderGraphResult = (graph: [String: RenderPass], finalPassID: String)

enum BasePassMode {
    case environment
    case grid
    case ar
    case none
}

func addSceneBackgroundPass(
    to graph: inout [String: RenderPass],
    mode: BasePassMode
) -> String? {
    switch mode {
    case .environment:
        let environmentPass = RenderPass(
            id: "environment", dependencies: [], execute: RenderPasses.executeEnvironmentPass
        )
        graph[environmentPass.id] = environmentPass
        return environmentPass.id
    case .grid:
        let gridPass = RenderPass(
            id: "grid", dependencies: [], execute: RenderPasses.gridExecution
        )
        graph[gridPass.id] = gridPass
        return gridPass.id
    case .none, .ar:
        return nil
    }
}

public func buildGameModeGraph() -> RenderGraphResult {
    var graph = [String: RenderPass]()

    // Determine base pass mode based on immersion style
    let mode: BasePassMode
    switch renderInfo.immersionStyle {
    case .none:
        // macOS/iOS path: use environment or grid
        mode = renderEnvironment ? .environment : .grid
    case .mixed:
        // XR passthrough: no base pass needed
        mode = .none
    case .full:
        // XR full immersion: use environment
        mode = .environment
    case .ar:
        mode = .ar
    @unknown default:
        mode = renderEnvironment ? .environment : .grid
    }

    let basePassID = addSceneBackgroundPass(to: &graph, mode: mode)
    let shadowDependency = basePassID.map { [$0] } ?? []

    let shadowPass = RenderPass(
        id: "shadow", dependencies: shadowDependency, execute: RenderPasses.shadowExecution
    )
    graph[shadowPass.id] = shadowPass

    // Add batched shadow pass (runs after regular shadow pass)
    let batchedShadowPass = RenderPass(
        id: "batchedShadow", dependencies: [shadowPass.id], execute: RenderPasses.batchedShadowExecution
    )
    graph[batchedShadowPass.id] = batchedShadowPass

    gBufferPass(graph: &graph, shadowPass: batchedShadowPass)

    // Transparent forward pass after deferred lighting.
    let transparencyPass = RenderPass(
        id: "transparency",
        dependencies: ["lightPass"],
        execute: RenderPasses.transparencyExecution
    )
    graph[transparencyPass.id] = transparencyPass

    // Spatial debug overlays are rendered on top of lit scene color.
    let spatialDebugPass = RenderPass(
        id: "spatialDebug",
        dependencies: [transparencyPass.id],
        execute: RenderPasses.spatialDebugBoundsExecution
    )
    graph[spatialDebugPass.id] = spatialDebugPass

    // Gaussian pass depends on model pass - needs depth buffer from 3D models
    let gaussianPass = RenderPass(id: "gaussian", dependencies: ["model"], execute: RenderPasses.gaussianExecution)
    graph[gaussianPass.id] = gaussianPass

    let postProcessID: String
    if bypassPostProcessing {
        let bypassPass = RenderPass(
            id: "postProcessBypass",
            dependencies: [spatialDebugPass.id],
            execute: { _ in
                guard let deferredDescriptor = renderInfo.deferredRenderPassDescriptor else {
                    return
                }
                renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0].texture =
                    deferredDescriptor.colorAttachments[0].texture
            }
        )
        graph[bypassPass.id] = bypassPass
        postProcessID = bypassPass.id
    } else {
        let postProcess = postProcessingEffects(graph: &graph, deferredPassId: spatialDebugPass.id, geometryPassId: "model")
        postProcessID = postProcess.id
    }

    // PreComposite depends on both post-processing and gaussian
    let preCompPass = RenderPass(
        id: "precomp",
        dependencies: [postProcessID, gaussianPass.id],
        execute: RenderPasses.preCompositeExecution
    )
    graph[preCompPass.id] = preCompPass

    let lookPass = RenderPass(
        id: "look",
        dependencies: [preCompPass.id],
        execute: lookRenderPass
    )
    graph[lookPass.id] = lookPass

    let outputDependency: String
    if FXAAParams.shared.enabled {
        let fxaaPass = RenderPass(
            id: "fxaa",
            dependencies: [lookPass.id],
            execute: fxaaRenderPass
        )
        graph[fxaaPass.id] = fxaaPass
        outputDependency = fxaaPass.id
    } else {
        outputDependency = lookPass.id
    }

    let outputPass = RenderPass(
        id: "outputTransform",
        dependencies: [outputDependency],
        execute: outputTransformRenderPass
    )
    graph[outputPass.id] = outputPass

    return (graph, outputPass.id)
}

/// G-Buffer Pass
func gBufferPass(graph: inout [String: RenderPass], shadowPass: RenderPass) {
    let modelPass = RenderPass(
        id: "model", dependencies: [shadowPass.id], execute: RenderPasses.modelExecution
    )
    graph[modelPass.id] = modelPass
    // Add batched model pass (runs after regular model pass)
    let batchedModelPass = RenderPass(
        id: "batchedModel", dependencies: [modelPass.id], execute: RenderPasses.batchedModelExecution
    )
    graph[batchedModelPass.id] = batchedModelPass
    // Update SSAO to depend on batched pass
    let ssaoPass = RenderPass(
        id: "ssao",
        dependencies: [batchedModelPass.id], // Changed from "model" to "batchedModel"
        execute: RenderPasses.ssaoOptimizedExecution
    )

    graph[ssaoPass.id] = ssaoPass

    // Note: ssaoOptimizedExecution handles all blur/upsample internally
    // No need for separate ssaoBlur pass in the graph

    let lightPass = RenderPass(id: "lightPass", dependencies: [batchedModelPass.id, modelPass.id, shadowPass.id, ssaoPass.id], execute: RenderPasses.lightExecution)
    graph[lightPass.id] = lightPass
}

/// Post process passes
func postProcessingEffects(graph: inout [String: RenderPass], deferredPassId: String, geometryPassId: String) -> RenderPass {
    // Fast path: skip entire chain when every post-process effect is disabled.
    // This avoids allocating ~142 MB of render targets that would only pass data through.
    let anyEffectEnabled = BloomThresholdParams.shared.enabled
        || VignetteParams.shared.enabled
        || ChromaticAberrationParams.shared.enabled
        || DepthOfFieldParams.shared.enabled

    if !anyEffectEnabled {
        let bypassPass = RenderPass(
            id: "postProcessDisabledBypass",
            dependencies: [deferredPassId],
            execute: { _ in
                // Point the post-process descriptor at the deferred output so
                // preCompositeExecution picks it up correctly.
                renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0].texture =
                    renderInfo.deferredRenderPassDescriptor?.colorAttachments[0].texture
            }
        )
        graph[bypassPass.id] = bypassPass
        return bypassPass
    }

    // At least one effect is active — make sure textures exist.
    ensurePostProcessTexturesExist()

    let depthOfFieldPass = RenderPass(id: "depthOfField", dependencies: [deferredPassId], execute: depthOfFieldRenderPass)

    graph[depthOfFieldPass.id] = depthOfFieldPass

    let chromaticAberrationPass = RenderPass(id: "chromatic", dependencies: [depthOfFieldPass.id], execute: chromaticAberrationRenderPass)

    graph[chromaticAberrationPass.id] = chromaticAberrationPass

    let bloomThresholdPass = RenderPass(id: "bloomThreshold", dependencies: [chromaticAberrationPass.id, geometryPassId], execute: bloomThresholdRenderPass)
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

    let vignettePass = RenderPass(id: "vignette", dependencies: [bloomCompositePass.id], execute: vignetteRenderPass)

    graph[vignettePass.id] = vignettePass

    return vignettePass
}

/// Gaussian render graph
public func buildGaussianGraph() -> RenderGraphResult {
    var graph = [String: RenderPass]()

    let gaussianPass = RenderPass(id: "gaussian", dependencies: [], execute: RenderPasses.gaussianExecution)

    graph[gaussianPass.id] = gaussianPass

    let preCompPass = RenderPass(id: "precomp", dependencies: [gaussianPass.id], execute: RenderPasses.preCompositeExecution)
    graph[preCompPass.id] = preCompPass

    return (graph, preCompPass.id)
}

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

let colorCorrectionRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.tonemapTexture,
          let destinationTexture = textureResources.colorCorrectionTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.colorCorrection]
    else {
        return
    }
    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: colorCorrectionCustomization
    )(commandBuffer)
}

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

let bloomThresholdRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.chromaticAberrationTexture,
          let destinationTexture = textureResources.bloomThresholdTextuture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.bloomThreshold]
    else {
        return
    }
    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: bloomThresholdCustomization
    )(commandBuffer)
}

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

let bloomCompositeRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.blurTextureVer,
          let destinationTexture = textureResources.bloomCompositeTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.bloomComposite]
    else {
        return
    }
    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: bloomCompositeCustomization
    )(commandBuffer)
}

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

let vignetteRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.bloomCompositeTexture,
          let destinationTexture = textureResources.vignetteTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.vignette]
    else {
        return
    }
    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: vignetteCustomization
    )(commandBuffer)
}

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

let chromaticAberrationRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.depthOfFieldTexture,
          let destinationTexture = textureResources.chromaticAberrationTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.chromaticAberration]
    else {
        return
    }
    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: chromaticAberrationCustomization
    )(commandBuffer)
}

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

let depthOfFieldRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.deferredColorMap,
          let destinationTexture = textureResources.depthOfFieldTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.depthOfField]
    else {
        return
    }
    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: depthOfFieldCustomization
    )(commandBuffer)
}

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

    var reverseZ = renderInfo.reverseZEnabled
    encoder.setFragmentBytes(&reverseZ, length: MemoryLayout<Bool>.stride, index: Int(depthOfFieldPassReverseZIndex.rawValue))
}

public let fxaaRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.lookTexture,
          let destinationTexture = textureResources.fxaaTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.fxaa]
    else {
        handleError(.renderPassCreationFailed, "FXAA Pass: missing texture or pipeline")
        return
    }

    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: fxaaCustomization
    )(commandBuffer)
}

func fxaaCustomization(encoder: MTLRenderCommandEncoder) {
    let srcW = Float(max(textureResources.lookTexture?.width ?? 1, 1))
    let srcH = Float(max(textureResources.lookTexture?.height ?? 1, 1))
    var texelSize = simd_float2(1.0 / srcW, 1.0 / srcH)
    encoder.setFragmentBytes(&texelSize, length: MemoryLayout<simd_float2>.stride,
                             index: Int(fxaaPassTexelSizeIndex.rawValue))

    var enabled = Int32(FXAAParams.shared.enabled ? 1 : 0)
    encoder.setFragmentBytes(&enabled, length: MemoryLayout<Int32>.stride,
                             index: Int(fxaaPassEnabledIndex.rawValue))

    var subpixel = FXAAParams.shared.subpixelQuality
    encoder.setFragmentBytes(&subpixel, length: MemoryLayout<Float>.stride,
                             index: Int(fxaaPassSubpixelIndex.rawValue))

    var edgeThreshold = FXAAParams.shared.edgeThreshold
    encoder.setFragmentBytes(&edgeThreshold, length: MemoryLayout<Float>.stride,
                             index: Int(fxaaPassEdgeThresholdIndex.rawValue))

    var edgeThresholdMin = FXAAParams.shared.edgeThresholdMin
    encoder.setFragmentBytes(&edgeThresholdMin, length: MemoryLayout<Float>.stride,
                             index: Int(fxaaPassEdgeThresholdMinIndex.rawValue))
}

func outputTransformCustomization(encoder: MTLRenderCommandEncoder) {
    var mode = renderInfo.colorPipeline.present.encodingMode.rawValue

    encoder.setFragmentBytes(
        &mode,
        length: MemoryLayout<Int32>.stride,
        index: Int(outputTransformPassEncodingModeIndex.rawValue)
    )
}

private func debugSourceTexture(for mode: RenderDebugViewMode) -> MTLTexture? {
    switch mode {
    case .lit:
        return textureResources.sceneCompositeTexture
    case .albedo:
        return textureResources.colorMap
    case .normal:
        return textureResources.normalMap
    case .depth:
        return textureResources.colorMap ?? textureResources.sceneCompositeTexture
    case .ssaoBlurred:
        return textureResources.ssaoBlurTexture
    }
}

public let lookRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    let viewMode = renderDebugViewMode
    guard let destinationTexture = textureResources.lookTexture else {
        handleError(.renderPassCreationFailed, "Look Pass: destination texture is nil")
        return
    }

    if viewMode == .lit {
        guard let sourceTexture = textureResources.sceneCompositeTexture else {
            handleError(.renderPassCreationFailed, "Look Pass: source texture is nil")
            return
        }
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.look] else {
            handleError(.pipelineStateNulled, "Look Pipeline is nil")
            return
        }
        if !pipeline.success {
            handleError(.pipelineStateNulled, pipeline.name ?? "Look Pipeline")
            return
        }

        RenderPasses.executePostProcess(
            pipeline,
            source: sourceTexture,
            destination: destinationTexture,
            customization: colorGradingCustomization
        )(commandBuffer)
        return
    }

    guard let debugSource = debugSourceTexture(for: viewMode) else {
        handleError(.renderPassCreationFailed, "Debug View Pass: source texture is nil")
        return
    }
    guard let debugDepth = renderInfo.offscreenRenderPassDescriptor?.depthAttachment.texture ?? textureResources.depthMap else {
        handleError(.renderPassCreationFailed, "Debug View Pass: depth texture is nil")
        return
    }
    guard let debugPipeline = PipelineManager.shared.renderPipelinesByType[.debug] else {
        handleError(.pipelineStateNulled, "Debug Pipeline is nil")
        return
    }
    if !debugPipeline.success {
        handleError(.pipelineStateNulled, debugPipeline.name ?? "Debug Pipeline")
        return
    }

    RenderPasses.executePostProcess(
        debugPipeline,
        source: debugSource,
        destination: destinationTexture,
        customization: { encoder in
            var mode = Int32(viewMode.rawValue)
            encoder.setFragmentBytes(
                &mode,
                length: MemoryLayout<Int32>.stride,
                index: Int(debugPassModeIndex.rawValue)
            )

            var frustumPlanes = simd_float2(near, far)
            encoder.setFragmentBytes(
                &frustumPlanes,
                length: MemoryLayout<simd_float2>.stride,
                index: Int(debugPassFrustumPlanesIndex.rawValue)
            )

            encoder.setFragmentTexture(debugDepth, index: 1)
        }
    )(commandBuffer)
}

public let outputTransformRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    let sourceTexture = FXAAParams.shared.enabled
        ? textureResources.fxaaTexture
        : textureResources.lookTexture
    guard let sourceTexture else {
        handleError(.renderPassCreationFailed, "Output Transform Pass: source texture is nil")
        return
    }
    guard let sourceDepthTexture = textureResources.depthMap else {
        handleError(.renderPassCreationFailed, "Output Transform Pass: source depth texture is nil")
        return
    }
    guard let pipeline = PipelineManager.shared.renderPipelinesByType[.outputTransform] else {
        handleError(.pipelineStateNulled, "Output Transform Pipeline is nil")
        return
    }
    if !pipeline.success {
        handleError(.pipelineStateNulled, pipeline.name ?? "Output Transform Pipeline")
        return
    }
    guard let renderPassDescriptor = renderInfo.renderPassDescriptor else {
        handleError(.renderPassCreationFailed, "Output Transform Pass: render pass descriptor is nil")
        return
    }

    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)

    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
        handleError(.renderPassCreationFailed, "Output Transform Pass: encoder creation failed")
        return
    }

    renderEncoder.label = "Output Transform Pass"
    renderEncoder.pushDebugGroup("Output Transform Pass")

    renderEncoder.setRenderPipelineState(pipeline.pipelineState!)
    if let depthState = pipeline.depthState {
        renderEncoder.setDepthStencilState(depthState)
    }
    renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
    renderEncoder.setFragmentTexture(sourceTexture, index: 0)
    renderEncoder.setFragmentTexture(sourceDepthTexture, index: 1)

    outputTransformCustomization(encoder: renderEncoder)

    renderEncoder.drawIndexedPrimitivesTracked(
        type: .triangle,
        indexCount: 6,
        indexType: .uint16,
        indexBuffer: bufferResources.quadIndexBuffer!,
        indexBufferOffset: 0
    )

    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()
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
