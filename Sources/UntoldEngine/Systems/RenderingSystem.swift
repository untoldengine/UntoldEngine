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

        // Always refresh the scene-root matrices so that effectiveCameraPosition() and
        // effectiveViewMatrix() reflect any SceneRootTransform changes (position, rotation,
        // scale) that the app made this frame — including changes made while assets are loading.
        // updateIfNeeded() is a pure matrix recompute with no ECS traversal, so it is safe to
        // call unconditionally regardless of the loading gate state.
        SceneRootTransform.shared.updateIfNeeded()

        // Skip render prep (culling, gaussian, bitonic) while loading - these traverse ECS.
        // The render graph still executes using the stale visibleEntityIds.
        if !loading {
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

            EngineProfiler.shared.beginScope(.gaussianCull)
            executeGaussianFrustumCulling(commandBuffer)
            EngineProfiler.shared.endScope(.gaussianCull)

            executeGaussianPreprocess(commandBuffer)

            EngineProfiler.shared.beginScope(.gaussianDepth)
            executeGaussianDepth(commandBuffer)
            EngineProfiler.shared.endScope(.gaussianDepth)

            EngineProfiler.shared.beginScope(.gaussianSort)
            executeRadixSort(commandBuffer)
            EngineProfiler.shared.endScope(.gaussianSort)
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

            do {
                let graph = try buildExecutableGameModeGraph()

                #if ENGINE_STATS_ENABLED
                    let encodeStart = CACurrentMediaTime()
                #endif
                EngineProfiler.shared.beginScope(.encode)
                executeGraph(graph, commandBuffer)
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
            } catch {
                Logger.logError(message: "[RenderGraph] Skipping frame: \(error)")
            }
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

    do {
        let graph = try buildExecutableGameModeGraph()

        #if ENGINE_STATS_ENABLED
            let encodeStart = shouldRecordStatsInThisCallback ? CACurrentMediaTime() : 0.0
        #endif
        executeGraph(graph, commandBuffer)

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
    } catch {
        Logger.logError(message: "[RenderGraph] Skipping XR frame: \(error)")
    }

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

typealias RenderGraphResult = (graph: [String: RenderPass], finalPassID: String)
private typealias CompiledRenderGraphResult = (
    graph: [String: RenderPass],
    finalPassID: String,
    compiledGraph: CompiledRenderGraph
)

let gameModeReservedPassIDs: Set<String> = [
    "environment",
    "grid",
    "shadow",
    "batchedShadow",
    "spotShadow",
    "pointShadow",
    "model",
    "batchedModel",
    "hzbDepthSource",
    "ssao",
    "lightPass",
    "transparency",
    "wireframe",
    "spatialDebug",
    "gaussian",
    "postProcessBypass",
    "postProcessDisabledBypass",
    "depthOfField",
    "chromatic",
    "bloomThreshold",
    "blur_pass_hor_pass1",
    "blur_pass_ver_pass1",
    "blur_pass_hor_pass2",
    "blur_pass_ver_pass2",
    "blur_pass_hor_pass3",
    "blur_pass_ver_pass3",
    "blur_pass_hor_pass4",
    "blur_pass_ver_pass4",
    "bloomComposite",
    "vignette",
    "precomp",
    "look",
    "fxaa",
    "fxaaEdgeDebug",
    "smaaEdges",
    "smaaBlendWeights",
    "smaaNeighborhood",
    "smaaDifference",
    "outputTransform",
]

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

private func buildGameModeGraphWithCompilation() throws -> CompiledRenderGraphResult {
    updateGBufferStorageForCurrentDebugMode()
    updateOpaqueSampleCountForCurrentState()

    var builder = RenderGraphBuilder(reservedPassIDs: gameModeReservedPassIDs)
    let buildContext = makeRenderGraphBuildContext()
    RenderExtensionRegistry.shared.buildGraph(&builder, context: buildContext)

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

    let frameStartID = builder.resolveStage(.frameStart, after: nil)

    var backgroundGraph: [String: RenderPass] = [:]
    let basePassID = addSceneBackgroundPass(to: &backgroundGraph, mode: mode)
    if let basePassID, let frameStartID, var basePass = backgroundGraph[basePassID],
       !basePass.dependencies.contains(frameStartID)
    {
        basePass.dependencies.append(frameStartID)
        backgroundGraph[basePassID] = basePass
    }
    for passID in backgroundGraph.keys.sorted() {
        if let pass = backgroundGraph[passID] {
            builder.addPass(pass)
        }
    }
    let beforeShadowsAnchor = basePassID ?? frameStartID
    let beforeShadowsID = builder.resolveStage(.beforeShadows, after: beforeShadowsAnchor)
        ?? beforeShadowsAnchor
    let shadowDependency = beforeShadowsID.map { [$0] } ?? []

    let shadowPass = RenderPass(
        id: "shadow", dependencies: shadowDependency, execute: RenderPasses.shadowExecution
    )
    builder.addPass(shadowPass)

    // Add batched shadow pass (runs after regular shadow pass)
    let batchedShadowPass = RenderPass(
        id: "batchedShadow", dependencies: [shadowPass.id], execute: RenderPasses.batchedShadowExecution
    )
    builder.addPass(batchedShadowPass)

    let pointShadowPass = RenderPass(
        id: "pointShadow", dependencies: [batchedShadowPass.id], execute: RenderPasses.pointShadowExecution
    )
    builder.addPass(pointShadowPass)

    let spotShadowPass = RenderPass(
        id: "spotShadow", dependencies: [pointShadowPass.id], execute: RenderPasses.spotShadowExecution
    )
    builder.addPass(spotShadowPass)

    var opaqueGraph: [String: RenderPass] = [:]
    gBufferPass(graph: &opaqueGraph, shadowPass: spotShadowPass)
    for passID in opaqueGraph.keys.sorted() {
        if let pass = opaqueGraph[passID] {
            builder.addPass(pass)
        }
    }

    let afterOpaqueLightingID = builder.resolveStage(.afterOpaqueLighting, after: "lightPass") ?? "lightPass"
    let beforeTransparencyID = builder.resolveStage(.beforeTransparency, after: afterOpaqueLightingID) ?? afterOpaqueLightingID

    // Transparent forward pass after deferred lighting.
    let transparencyPass = RenderPass(
        id: "transparency",
        dependencies: [beforeTransparencyID],
        execute: RenderPasses.transparencyExecution
    )
    builder.addPass(transparencyPass)

    let afterTransparencyID = builder.resolveStage(.afterTransparency, after: transparencyPass.id) ?? transparencyPass.id

    let wireframePass = RenderPass(
        id: "wireframe",
        dependencies: [afterTransparencyID],
        execute: RenderPasses.wireframeExecution
    )
    builder.addPass(wireframePass)

    // Spatial debug overlays are rendered on top of lit scene color.
    let spatialDebugPass = RenderPass(
        id: "spatialDebug",
        dependencies: [wireframePass.id],
        execute: RenderPasses.spatialDebugBoundsExecution
    )
    builder.addPass(spatialDebugPass)

    // Gaussian pass depends on model pass - needs depth buffer from 3D models
    let gaussianPass = RenderPass(id: "gaussian", dependencies: ["model"], execute: RenderPasses.gaussianExecution)
    builder.addPass(gaussianPass)

    let beforePostProcessID = builder.resolveStage(.beforePostProcess, after: spatialDebugPass.id) ?? spatialDebugPass.id

    let postProcessID: String
    if bypassPostProcessing {
        let bypassPass = RenderPass(
            id: "postProcessBypass",
            dependencies: [beforePostProcessID],
            execute: { _ in
                guard let deferredDescriptor = renderInfo.deferredRenderPassDescriptor else {
                    return
                }
                renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0].texture =
                    deferredDescriptor.colorAttachments[0].texture
            }
        )
        builder.addPass(bypassPass)
        postProcessID = bypassPass.id
    } else {
        var postProcessGraph: [String: RenderPass] = [:]
        let postProcess = postProcessingEffects(
            graph: &postProcessGraph,
            deferredPassId: beforePostProcessID
        )
        for passID in postProcessGraph.keys.sorted() {
            if let pass = postProcessGraph[passID] {
                builder.addPass(pass)
            }
        }
        postProcessID = postProcess.id
    }

    let afterPostProcessID = builder.resolveStage(.afterPostProcess, after: postProcessID) ?? postProcessID
    let beforeCompositeID = builder.resolveStage(.beforeComposite, after: afterPostProcessID) ?? afterPostProcessID

    // PreComposite depends on both post-processing and gaussian
    let preCompPass = RenderPass(
        id: "precomp",
        dependencies: [beforeCompositeID, gaussianPass.id],
        execute: RenderPasses.preCompositeExecution
    )
    builder.addPass(preCompPass)

    let beforeLookID = builder.resolveStage(.beforeLook, after: preCompPass.id) ?? preCompPass.id

    let lookPass = RenderPass(
        id: "look",
        dependencies: [beforeLookID],
        execute: lookRenderPass
    )
    builder.addPass(lookPass)

    let outputDependency: String
    if renderDebugViewMode == .fxaaEdgeDebug {
        let fxaaEdgeDebugPass = RenderPass(id: "fxaaEdgeDebug", dependencies: [lookPass.id], execute: fxaaEdgeDebugRenderPass)
        builder.addPass(fxaaEdgeDebugPass)
        outputDependency = fxaaEdgeDebugPass.id
    } else if renderDebugViewMode == .smaaEdges {
        let smaaEdgesPass = RenderPass(id: "smaaEdges", dependencies: [lookPass.id], execute: smaaEdgesRenderPass)
        builder.addPass(smaaEdgesPass)
        outputDependency = smaaEdgesPass.id
    } else if renderDebugViewMode == .smaaBlend {
        let smaaEdgesPass = RenderPass(id: "smaaEdges", dependencies: [lookPass.id], execute: smaaEdgesRenderPass)
        builder.addPass(smaaEdgesPass)

        let smaaBlendWeightsPass = RenderPass(
            id: "smaaBlendWeights",
            dependencies: [smaaEdgesPass.id],
            execute: smaaBlendWeightsRenderPass
        )
        builder.addPass(smaaBlendWeightsPass)
        outputDependency = smaaBlendWeightsPass.id
    } else if renderDebugViewMode == .smaaDifference {
        let smaaEdgesPass = RenderPass(id: "smaaEdges", dependencies: [lookPass.id], execute: smaaEdgesRenderPass)
        builder.addPass(smaaEdgesPass)

        let smaaBlendWeightsPass = RenderPass(
            id: "smaaBlendWeights",
            dependencies: [smaaEdgesPass.id],
            execute: smaaBlendWeightsRenderPass
        )
        builder.addPass(smaaBlendWeightsPass)

        let smaaNeighborhoodPass = RenderPass(
            id: "smaaNeighborhood",
            dependencies: [smaaBlendWeightsPass.id],
            execute: smaaNeighborhoodRenderPass
        )
        builder.addPass(smaaNeighborhoodPass)

        let smaaDifferencePass = RenderPass(
            id: "smaaDifference",
            dependencies: [smaaNeighborhoodPass.id],
            execute: smaaDifferenceRenderPass
        )
        builder.addPass(smaaDifferencePass)
        outputDependency = smaaDifferencePass.id
    } else {
        switch antiAliasingMode {
        case .fxaa:
            let fxaaPass = RenderPass(id: "fxaa", dependencies: [lookPass.id], execute: fxaaRenderPass)
            builder.addPass(fxaaPass)
            outputDependency = fxaaPass.id
        case .smaa:
            let smaaEdgesPass = RenderPass(id: "smaaEdges", dependencies: [lookPass.id], execute: smaaEdgesRenderPass)
            builder.addPass(smaaEdgesPass)

            let smaaBlendWeightsPass = RenderPass(
                id: "smaaBlendWeights",
                dependencies: [smaaEdgesPass.id],
                execute: smaaBlendWeightsRenderPass
            )
            builder.addPass(smaaBlendWeightsPass)

            let smaaNeighborhoodPass = RenderPass(
                id: "smaaNeighborhood",
                dependencies: [smaaBlendWeightsPass.id],
                execute: smaaNeighborhoodRenderPass
            )
            builder.addPass(smaaNeighborhoodPass)
            outputDependency = smaaNeighborhoodPass.id
        case .none, .msaa:
            outputDependency = lookPass.id
        }
    }

    let beforeOutputID = builder.resolveStage(.beforeOutput, after: outputDependency) ?? outputDependency

    let outputPass = RenderPass(
        id: "outputTransform",
        dependencies: [beforeOutputID],
        execute: outputTransformRenderPass
    )
    builder.addPass(outputPass)

    let analysis = try builder.analyzeForCompilation()
    if let compiledGraph = analysis.compiledGraph {
        return (analysis.scheduledGraph, outputPass.id, compiledGraph)
    }

    let removedExtensionIDs = RenderExtensionRegistry.shared.rejectGraphValidationFailures(
        analysis.validationReport
    )
    if !removedExtensionIDs.isEmpty {
        return try buildGameModeGraphWithCompilation()
    }
    throw analysis.validationReport.errors[0]
}

func buildGameModeGraph() throws -> RenderGraphResult {
    let result = try buildGameModeGraphWithCompilation()
    return (result.graph, result.finalPassID)
}

func buildExecutableGameModeGraph() throws -> CompiledRenderGraph {
    try buildGameModeGraphWithCompilation().compiledGraph
}

/// G-Buffer Pass (TBDR)
///
/// All geometry and lighting run inside a single MTLRenderCommandEncoder via
/// combinedModelLightExecution. G-buffer attachments are memoryless; lighting
/// reads them from tile memory via framebuffer fetch. SSAO runs afterward from
/// the stored opaque depth texture and is applied during pre-composite.
func gBufferPass(graph: inout [String: RenderPass], shadowPass: RenderPass) {
    // Combined pass: fills G-buffer and runs the lighting quad in one encoder.
    let modelPass = RenderPass(
        id: "model",
        dependencies: [shadowPass.id],
        execute: RenderPasses.combinedModelLightExecution
    )
    graph[modelPass.id] = modelPass

    // Stub: downstream nodes that depend on "batchedModel" still resolve correctly.
    // Work is done inside modelPass (combinedModelLightExecution).
    let batchedModelPass = RenderPass(id: "batchedModel", dependencies: [modelPass.id], execute: nil)
    graph[batchedModelPass.id] = batchedModelPass

    // HZB depth copy must happen after all opaque geometry is drawn.
    let hzbDepthSourcePass = RenderPass(
        id: "hzbDepthSource",
        dependencies: [batchedModelPass.id],
        execute: RenderPasses.copyOpaqueDepthForHZBExecution
    )
    graph[hzbDepthSourcePass.id] = hzbDepthSourcePass

    let ssaoPass = RenderPass(
        id: "ssao",
        dependencies: [hzbDepthSourcePass.id],
        execute: RenderPasses.ssaoOptimizedExecution
    )
    graph[ssaoPass.id] = ssaoPass

    // Stub: transparency and other downstream passes depend on "lightPass".
    // Lighting is done inside modelPass; this node only exists to satisfy the dependency.
    let lightPassStub = RenderPass(id: "lightPass", dependencies: [ssaoPass.id], execute: nil)
    graph[lightPassStub.id] = lightPassStub
}

/// Post process passes
func postProcessingEffects(graph: inout [String: RenderPass], deferredPassId: String) -> RenderPass {
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

    let bloomThresholdPass = RenderPass(id: "bloomThreshold", dependencies: [chromaticAberrationPass.id], execute: bloomThresholdRenderPass)
    graph[bloomThresholdPass.id] = bloomThresholdPass

    // 4 ping-pong passes × 9-tap kernel gives a wide, soft bloom spread.
    let blurPassCount = BloomThresholdParams.shared.enabled ? 4 : 0
    let blurRadius: Float = 6.0

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
func buildGaussianGraph() -> RenderGraphResult {
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
    let colorLUT = ColorLUTParams.shared.snapshot()

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

    encoder.setFragmentTexture(colorLUT.lutTexture, index: Int(lookPassColorLUTTextureIndex.rawValue))

    var colorLUTEnabled = colorLUT.enabled && colorLUT.lutTexture != nil
    encoder.setFragmentBytes(
        &colorLUTEnabled,
        length: MemoryLayout<Bool>.stride,
        index: Int(colorLUTEnabledIndex.rawValue)
    )

    var colorLUTShaperMinStops = colorLUT.shaperMinStops
    encoder.setFragmentBytes(
        &colorLUTShaperMinStops,
        length: MemoryLayout<Float>.stride,
        index: Int(colorLUTShaperMinStopsIndex.rawValue)
    )

    var colorLUTShaperMaxStops = colorLUT.shaperMaxStops
    encoder.setFragmentBytes(
        &colorLUTShaperMaxStops,
        length: MemoryLayout<Float>.stride,
        index: Int(colorLUTShaperMaxStopsIndex.rawValue)
    )

    var colorLUTSize = Int32(colorLUT.lutSize)
    encoder.setFragmentBytes(
        &colorLUTSize,
        length: MemoryLayout<Int32>.stride,
        index: Int(colorLUTSizeIndex.rawValue)
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
          let destinationTexture = textureResources.antiAliasingTexture,
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

public let fxaaEdgeDebugRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.lookTexture,
          let destinationTexture = textureResources.antiAliasingTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.fxaaEdgeDebug]
    else {
        handleError(.renderPassCreationFailed, "FXAA Edge Debug Pass: missing texture or pipeline")
        return
    }

    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: fxaaCustomization
    )(commandBuffer)
}

public let smaaEdgesRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.lookTexture,
          let destinationTexture = textureResources.smaaEdgesTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaEdges]
    else {
        handleError(.renderPassCreationFailed, "SMAA Edge Pass: missing texture or pipeline")
        return
    }

    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: smaaEdgesCustomization
    )(commandBuffer)
}

public let smaaBlendWeightsRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.smaaEdgesTexture,
          let destinationTexture = textureResources.smaaBlendTexture,
          let areaTexture = textureResources.smaaAreaTexture,
          let searchTexture = textureResources.smaaSearchTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaBlendWeights]
    else {
        handleError(.renderPassCreationFailed, "SMAA Blend Weight Pass: missing texture or pipeline")
        return
    }

    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: { encoder in
            smaaBlendWeightsCustomization(
                encoder: encoder,
                areaTexture: areaTexture,
                searchTexture: searchTexture
            )
        }
    )(commandBuffer)
}

public let smaaNeighborhoodRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.lookTexture,
          let destinationTexture = textureResources.antiAliasingTexture,
          let blendTexture = textureResources.smaaBlendTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaNeighborhood]
    else {
        handleError(.renderPassCreationFailed, "SMAA Neighborhood Pass: missing texture or pipeline")
        return
    }

    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: { encoder in
            smaaNeighborhoodCustomization(encoder: encoder, blendTexture: blendTexture)
        }
    )(commandBuffer)
}

public let smaaDifferenceRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    guard let sourceTexture = textureResources.antiAliasingTexture,
          let originalTexture = textureResources.lookTexture,
          let destinationTexture = textureResources.smaaBlendTexture,
          let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaDifference]
    else {
        handleError(.renderPassCreationFailed, "SMAA Difference Pass: missing texture or pipeline")
        return
    }

    RenderPasses.executePostProcess(
        pipeline,
        source: sourceTexture,
        destination: destinationTexture,
        customization: { encoder in
            encoder.setFragmentTexture(originalTexture, index: 1)
        }
    )(commandBuffer)
}

func fxaaCustomization(encoder: MTLRenderCommandEncoder) {
    let srcW = Float(max(textureResources.lookTexture?.width ?? 1, 1))
    let srcH = Float(max(textureResources.lookTexture?.height ?? 1, 1))
    var texelSize = simd_float2(1.0 / srcW, 1.0 / srcH)
    encoder.setFragmentBytes(&texelSize, length: MemoryLayout<simd_float2>.stride,
                             index: Int(fxaaPassTexelSizeIndex.rawValue))

    var enabled = Int32(1) // pass is only inserted when FXAA is the active mode
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

func smaaEdgesCustomization(encoder: MTLRenderCommandEncoder) {
    let srcW = Float(max(textureResources.lookTexture?.width ?? 1, 1))
    let srcH = Float(max(textureResources.lookTexture?.height ?? 1, 1))
    var texelSize = simd_float2(1.0 / srcW, 1.0 / srcH)
    encoder.setFragmentBytes(
        &texelSize,
        length: MemoryLayout<simd_float2>.stride,
        index: Int(smaaPassTexelSizeIndex.rawValue)
    )

    var threshold = SMAAParams.shared.edgeThreshold
    encoder.setFragmentBytes(
        &threshold,
        length: MemoryLayout<Float>.stride,
        index: Int(smaaPassEdgeThresholdIndex.rawValue)
    )
}

func smaaBlendWeightsCustomization(
    encoder: MTLRenderCommandEncoder,
    areaTexture: MTLTexture,
    searchTexture: MTLTexture
) {
    let srcW = Float(max(textureResources.smaaEdgesTexture?.width ?? 1, 1))
    let srcH = Float(max(textureResources.smaaEdgesTexture?.height ?? 1, 1))
    var texelSize = simd_float2(1.0 / srcW, 1.0 / srcH)
    encoder.setFragmentBytes(
        &texelSize,
        length: MemoryLayout<simd_float2>.stride,
        index: Int(smaaPassTexelSizeIndex.rawValue)
    )

    encoder.setFragmentTexture(areaTexture, index: 1)
    encoder.setFragmentTexture(searchTexture, index: 2)
}

func smaaNeighborhoodCustomization(
    encoder: MTLRenderCommandEncoder,
    blendTexture: MTLTexture
) {
    let srcW = Float(max(textureResources.lookTexture?.width ?? 1, 1))
    let srcH = Float(max(textureResources.lookTexture?.height ?? 1, 1))
    var texelSize = simd_float2(1.0 / srcW, 1.0 / srcH)
    encoder.setFragmentBytes(
        &texelSize,
        length: MemoryLayout<simd_float2>.stride,
        index: Int(smaaPassTexelSizeIndex.rawValue)
    )

    encoder.setFragmentTexture(blendTexture, index: 1)
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
    case .position:
        return textureResources.positionMap
    case .roughness, .metallic, .heightDebug, .pomOffsetDebug:
        return textureResources.materialMap
    case .ssaoBlurred:
        return textureResources.ssaoBlurTexture
    case .depth:
        // colorMap is memoryless in the TBDR path; use sceneCompositeTexture as the
        // colour source. The debug shader samples depth separately via texture index 1.
        return textureResources.sceneCompositeTexture
    case .fxaaEdgeDebug:
        return textureResources.lookTexture
    case .smaaEdges:
        return textureResources.smaaEdgesTexture
    case .smaaBlend:
        return textureResources.smaaBlendTexture
    case .smaaDifference:
        return textureResources.smaaBlendTexture
    case .occlusionDebug:
        return textureResources.sceneCompositeTexture
    case .preTonemapHDRLuminance:
        return textureResources.sceneCompositeTexture
    case .postTonemapOutput:
        return textureResources.lookTexture
    }
}

private func lookPassShouldRenderLitOutput(for mode: RenderDebugViewMode) -> Bool {
    switch mode {
    case .lit, .fxaaEdgeDebug, .smaaEdges, .smaaBlend, .smaaDifference, .occlusionDebug, .postTonemapOutput:
        return true
    case .albedo, .normal, .position, .roughness, .metallic, .ssaoBlurred, .depth, .preTonemapHDRLuminance,
         .heightDebug, .pomOffsetDebug:
        return false
    }
}

public let lookRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    let viewMode = renderDebugViewMode
    guard let destinationTexture = textureResources.lookTexture else {
        handleError(.renderPassCreationFailed, "Look Pass: destination texture is nil")
        return
    }

    if lookPassShouldRenderLitOutput(for: viewMode) {
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
    guard let debugDepth = textureResources.depthMap ?? renderInfo.offscreenRenderPassDescriptor?.depthAttachment.texture else {
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

            var reverseZ = renderInfo.reverseZEnabled
            encoder.setFragmentBytes(
                &reverseZ,
                length: MemoryLayout<Bool>.stride,
                index: Int(debugPassReverseZIndex.rawValue)
            )

            encoder.setFragmentTexture(debugDepth, index: 1)
        }
    )(commandBuffer)
}

public let outputTransformRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    let sourceTexture: MTLTexture?
    switch renderDebugViewMode {
    case .fxaaEdgeDebug:
        sourceTexture = textureResources.antiAliasingTexture
    case .smaaEdges:
        sourceTexture = textureResources.smaaEdgesTexture
    case .smaaBlend:
        sourceTexture = textureResources.smaaBlendTexture
    case .smaaDifference:
        sourceTexture = textureResources.smaaBlendTexture
    default:
        sourceTexture = antiAliasingMode.usesPostLookPass
            ? textureResources.antiAliasingTexture
            : textureResources.lookTexture
    }
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
    // Do not override clearColor here: the XR layer sets it per immersion mode
    // (UntoldEngineXR.swift), and the fullscreen quad overwrites every pixel anyway.

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
