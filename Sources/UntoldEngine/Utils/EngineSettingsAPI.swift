//
//  EngineSettingsAPI.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import simd

public enum LODFadeTransitionSetting: Sendable {
    case enabled(duration: Float? = nil)
    case disabled
}

public enum LODProperty: Sendable {
    case fadeTransitions(LODFadeTransitionSetting)
    case distanceBias(Float)
    case hysteresis(Float)
    case updateFrameInterval(Int)
    case minimumCameraDisplacement(Float)
    case distanceThresholds([Float])
}

public func setLOD(_ property: LODProperty) {
    var config = LODConfig.shared

    switch property {
    case let .fadeTransitions(.enabled(duration)):
        config.enableFadeTransitions = true
        if let duration {
            config.fadeTransitionTime = max(duration, 0.001)
        }
    case .fadeTransitions(.disabled):
        config.enableFadeTransitions = false
    case let .distanceBias(value):
        config.lodBias = max(value, 0.001)
    case let .hysteresis(value):
        config.hysteresis = max(value, 0)
    case let .updateFrameInterval(value):
        config.lodUpdateFrameInterval = max(value, 1)
    case let .minimumCameraDisplacement(value):
        config.minimumCameraDisplacementForLODUpdate = max(value, 0)
    case let .distanceThresholds(values):
        config.lodDistances = values.map { max($0, 0) }
    }

    LODConfig.shared = config
}

public enum RenderingProperty: Sendable {
    case antiAliasing(AntiAliasingMode)
    case debugView(RenderDebugViewMode)
    case postProcessing(RenderingToggle)
    case wireframe(WireframeProperty)
    case environment(RenderingEnvironmentProperty)
    case extensions(RenderExtensionProperty)
}

public enum RenderingToggle: Sendable {
    case enabled
    case disabled
}

public enum RenderExtensionProperty: Sendable {
    case register(any RenderExtension)
    case unregister(String)
    case removeAll
}

public enum RenderingEnvironmentProperty: Sendable {
    case ibl(Bool)
    case visible(Bool)
    case lightingMode(RuntimeEnvironmentLightingMode)
    case realWorldLightingContribution(Float)
    /// Scales the intensity of image-based lighting contributed by the environment.
    case intensity(Float)
    /// Loads an HDR environment asset and regenerates the IBL textures
    /// (mipmaps + pre-filtered irradiance/specular).
    ///
    /// When `directory` is provided, `name` (including extension) is resolved
    /// against it. Otherwise the engine's standard asset search is used —
    /// notably `assetBasePath` (GameData) and its `HDR/` subfolder — trying
    /// the `.hdr`, `.exr`, and `.png` extensions when `name` has none.
    case asset(String, directory: URL? = nil)
}

public enum WireframeProperty: Sendable {
    case color(simd_float4)
    case distanceFade(enabled: Bool, start: Float = 8.0, end: Float = 40.0, minimumAlpha: Float = 0.08)
    case params(color: simd_float4, fadeEnabled: Bool = false, fadeStart: Float = 8.0, fadeEnd: Float = 40.0, minimumAlpha: Float = 0.08)
}

public func setRendering(_ property: RenderingProperty) {
    switch property {
    case let .antiAliasing(mode):
        antiAliasingMode = mode
    case let .debugView(mode):
        renderDebugViewMode = mode
    case .postProcessing(.enabled):
        bypassPostProcessing = false
    case .postProcessing(.disabled):
        bypassPostProcessing = true
    case let .wireframe(property):
        applyWireframeProperty(property)
    case let .environment(property):
        applyRenderingEnvironmentProperty(property)
    case let .extensions(property):
        applyRenderExtensionProperty(property)
    }
}

public enum RenderResourceQuery {
    case texture(String)
}

public func getRenderResource(_ query: RenderResourceQuery) -> MTLTexture? {
    switch query {
    case let .texture(id):
        RenderResourceRegistry.shared.texture(id)
    }
}

public func getRenderResource(_ id: RenderTextureResourceID) -> MTLTexture? {
    RenderResourceRegistry.shared.texture(id)
}

public func getRenderResource(_ id: RenderBufferResourceID) -> MTLBuffer? {
    RenderResourceRegistry.shared.buffer(id)
}

private func applyRenderExtensionProperty(_ property: RenderExtensionProperty) {
    switch property {
    case let .register(renderExtension):
        RenderExtensionRegistry.shared.register(renderExtension)
    case let .unregister(id):
        RenderExtensionRegistry.shared.unregister(id: id)
    case .removeAll:
        RenderExtensionRegistry.shared.removeAll()
    }
}

private func applyRenderingEnvironmentProperty(_ property: RenderingEnvironmentProperty) {
    switch property {
    case let .ibl(value):
        applyIBL = value
    case let .visible(value):
        renderEnvironment = value
    case let .lightingMode(value):
        RuntimeEnvironmentLightingStore.shared.mode = value
    case let .realWorldLightingContribution(value):
        RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution = value
    case let .intensity(value):
        ambientIntensity = value
    case let .asset(name, directory):
        applyEnvironmentAsset(name, directory: directory)
    }
}

private func applyEnvironmentAsset(_ name: String, directory: URL?) {
    // Explicit directory: preserve generateHDR's legacy behavior (name must
    // include the file extension).
    if let directory {
        generateHDR(name, from: directory)
        return
    }

    // No directory: resolve through the engine's standard asset search
    // (assetBasePath/GameData incl. the HDR/ subfolder, app bundle, engine bundle).
    let nsName = name as NSString
    let providedExtension = nsName.pathExtension
    let candidates: [(base: String, ext: String)] = providedExtension.isEmpty
        ? ["hdr", "exr", "png"].map { (name, $0) }
        : [(nsName.deletingPathExtension, providedExtension)]

    for candidate in candidates {
        if let url = LoadingSystem.shared.resourceURL(
            forResource: candidate.base, withExtension: candidate.ext, subResource: nil
        ) {
            generateHDR(url.lastPathComponent, from: url.deletingLastPathComponent())
            return
        }
    }

    // Fall back to generateHDR's own resolution (engine bundle) so behavior
    // degrades to the legacy path and its error reporting.
    generateHDR(name, from: nil)
}

private func applyWireframeProperty(_ property: WireframeProperty) {
    wireframeRenderStateLock.lock()
    let current = wireframeRenderState
    wireframeRenderStateLock.unlock()

    switch property {
    case let .color(color):
        setWireframeParams(
            color: color,
            fadeEnabled: current.distanceFadeEnabled,
            fadeStart: current.fadeStartDistance,
            fadeEnd: current.fadeEndDistance,
            minimumAlpha: current.minimumAlpha
        )
    case let .distanceFade(enabled, start, end, minimumAlpha):
        setWireframeParams(
            color: current.color,
            fadeEnabled: enabled,
            fadeStart: start,
            fadeEnd: end,
            minimumAlpha: minimumAlpha
        )
    case let .params(color, fadeEnabled, fadeStart, fadeEnd, minimumAlpha):
        setWireframeParams(
            color: color,
            fadeEnabled: fadeEnabled,
            fadeStart: fadeStart,
            fadeEnd: fadeEnd,
            minimumAlpha: minimumAlpha
        )
    }
}

public enum EngineProperty: Sendable {
    case assetBasePath(URL?)
    case metrics(EngineMetricsSetting)
}

public enum EngineMetricsSetting: Sendable {
    case enabled
    case disabled
}

public func setEngine(_ property: EngineProperty) {
    switch property {
    case let .assetBasePath(url):
        assetBasePath = url
    case .metrics(.enabled):
        enableEngineMetrics = true
    case .metrics(.disabled):
        enableEngineMetrics = false
    }
}

public enum PostFXProperty: Sendable {
    case preset(PostFXPreset)
    case colorGrading(ColorGradingProperty)
    case colorLUT(ColorLUTProperty)
    case colorGradeLUT(ColorGradeLUTProperty)
    case colorCorrection(ColorCorrectionProperty)
    case bloomThreshold(BloomThresholdProperty)
    case bloomComposite(BloomCompositeProperty)
    case vignette(VignetteProperty)
    case chromaticAberration(ChromaticAberrationProperty)
    case depthOfField(DepthOfFieldProperty)
    case ssao(SSAOProperty)
}

public enum ColorGradingProperty: Sendable {
    case enabled(Bool)
    case exposure(Float)
    case brightness(Float)
    case contrast(Float)
    case saturation(Float)
    case temperature(Float)
    case tint(Float)
}

/// The color-grading LUT itself is asset-derived (baked from the source
/// Blender scene, see ColorLUTParams) — this only lets a developer toggle it
/// off to compare against the default ACES tonemap, not author new LUT data.
public enum ColorLUTProperty: Sendable {
    case enabled(Bool)
}

/// An externally-authored standard .cube LUT (see ColorGradeLUTParams),
/// applied as a post-tonemap creative grade -- composes with either the
/// native tonemap or the whole-transform bake above. Also asset-derived;
/// this only lets a developer toggle it off, not author new LUT data.
public enum ColorGradeLUTProperty: Sendable {
    case enabled(Bool)
}

public enum ColorCorrectionProperty: Sendable {
    case enabled(Bool)
    case lift(simd_float3)
    case gamma(simd_float3)
    case gain(simd_float3)
}

public enum BloomThresholdProperty: Sendable {
    case enabled(Bool)
    case threshold(Float)
    case intensity(Float)
}

public enum BloomCompositeProperty: Sendable {
    case enabled(Bool)
    case intensity(Float)
}

public enum VignetteProperty: Sendable {
    case enabled(Bool)
    case intensity(Float)
    case radius(Float)
    case softness(Float)
    case center(simd_float2)
}

public enum ChromaticAberrationProperty: Sendable {
    case enabled(Bool)
    case intensity(Float)
    case center(simd_float2)
}

public enum DepthOfFieldProperty: Sendable {
    case enabled(Bool)
    case focusDistance(Float)
    case focusRange(Float)
    case maxBlur(Float)
}

public enum SSAOProperty: Sendable {
    case enabled(Bool)
    case radius(Float)
    case bias(Float)
    case intensity(Float)
    case quality(SSAOQuality)
}

public func setPostFX(_ property: PostFXProperty) {
    switch property {
    case let .preset(preset):
        PostFX.apply(preset)
    case let .colorGrading(property):
        applyColorGradingProperty(property)
    case let .colorLUT(property):
        applyColorLUTProperty(property)
    case let .colorGradeLUT(property):
        applyColorGradeLUTProperty(property)
    case let .colorCorrection(property):
        applyColorCorrectionProperty(property)
    case let .bloomThreshold(property):
        applyBloomThresholdProperty(property)
    case let .bloomComposite(property):
        applyBloomCompositeProperty(property)
    case let .vignette(property):
        applyVignetteProperty(property)
    case let .chromaticAberration(property):
        applyChromaticAberrationProperty(property)
    case let .depthOfField(property):
        applyDepthOfFieldProperty(property)
    case let .ssao(property):
        applySSAOProperty(property)
    }
}

public enum GeometryStreamingProperty: Sendable {
    case enabled(Bool)
    case tileConcurrency(Int)
    case meshConcurrency(Int)
    case lodConcurrency(Int)
    case hlodConcurrency(Int)
    case queryRadius(Float)
    case floorProximityGateY(Float)
    case interiorZone(AABB?)
    case frustumGate(GeometryStreamingFrustumGateSetting)
    case velocityLookAhead(time: Float, minSpeed: Float)
    case candidateSorting(importance: Bool, occlusion: Bool)
    case minimumParsedTileResidentSeconds(Double)
    case timeouts(tileParse: Double, meshLoad: Double)
}

public enum GeometryStreamingFrustumGateSetting: Sendable {
    case enabled(meshPadding: Float = 5.0, tilePadding: Float = 20.0)
    case disabled
}

public func setGeometryStreaming(_ property: GeometryStreamingProperty) {
    let streaming = GeometryStreamingSystem.shared

    switch property {
    case let .enabled(value):
        streaming.enabled = value
    case let .tileConcurrency(value):
        streaming.maxConcurrentTileLoads = max(value, 1)
    case let .meshConcurrency(value):
        streaming.maxConcurrentLoads = max(value, 1)
    case let .lodConcurrency(value):
        streaming.maxConcurrentLODLoads = max(value, 1)
    case let .hlodConcurrency(value):
        streaming.maxConcurrentHLODLoads = max(value, 1)
    case let .queryRadius(value):
        streaming.maxQueryRadius = max(value, 0)
    case let .floorProximityGateY(value):
        streaming.floorProximityGateY = max(value, 0)
    case let .interiorZone(value):
        streaming.interiorZone = value
    case let .frustumGate(.enabled(meshPadding, tilePadding)):
        streaming.enableFrustumGate = true
        streaming.frustumGatePadding = max(meshPadding, 0)
        streaming.tileFrustumGatePadding = max(tilePadding, 0)
    case .frustumGate(.disabled):
        streaming.enableFrustumGate = false
    case let .velocityLookAhead(time, minSpeed):
        streaming.velocityLookAheadTime = max(time, 0)
        streaming.velocityLookAheadMinSpeed = max(minSpeed, 0)
    case let .candidateSorting(importance, occlusion):
        streaming.enableImportanceSort = importance
        streaming.enableOcclusionSort = occlusion
    case let .minimumParsedTileResidentSeconds(value):
        streaming.minimumParsedTileResidentSeconds = max(value, 0)
    case let .timeouts(tileParse, meshLoad):
        streaming.tileParseTimeoutSeconds = max(tileParse, 0)
        streaming.meshLoadTimeoutSeconds = max(meshLoad, 0)
    }
}

public enum BatchingProperty: Sendable {
    case enabled(Bool)
    case cellSize(Float)
    case runtimeTuning(RuntimeBatchingTuning)
    case maxDirtyCellsPerTick(Int)
    case retireDelayFrames(Int)
    case maxRetirementsPerTick(Int)
    case backgroundArtifactBuild(Bool)
    case visibilityGatedBuild(Bool)
    case maxBuildDispatchesPerTick(Int)
    case maxArtifactAppliesPerTick(Int)
    case rebuildBudgets(vertices: Int, indices: Int, bytes: Int)
    case runtimeCellLimits(vertices: Int, indices: Int, bytes: Int)
    case quiescenceFramesBeforeBuild(Int)
    case recentVisibilityWindowFrames(Int)
}

public func setBatching(_ property: BatchingProperty) {
    let batching = BatchingSystem.shared

    switch property {
    case let .enabled(value):
        batching.setEnabled(value)
    case let .cellSize(value):
        batching.setBatchCellSize(value)
    case let .runtimeTuning(value):
        batching.applyRuntimeBatchingTuning(value)
    case let .maxDirtyCellsPerTick(value):
        batching.setMaxDirtyCellsPerTick(value)
    case let .retireDelayFrames(value):
        batching.setBatchRetireDelayFrames(value)
    case let .maxRetirementsPerTick(value):
        batching.setMaxRetirementsPerTick(value)
    case let .backgroundArtifactBuild(value):
        batching.setBackgroundArtifactBuildEnabled(value)
    case let .visibilityGatedBuild(value):
        batching.setVisibilityGatedBatchBuildEnabled(value)
    case let .maxBuildDispatchesPerTick(value):
        batching.setMaxBuildDispatchesPerTick(value)
    case let .maxArtifactAppliesPerTick(value):
        batching.setMaxArtifactAppliesPerTick(value)
    case let .rebuildBudgets(vertices, indices, bytes):
        batching.setMaxRebuildVerticesPerTick(vertices)
        batching.setMaxRebuildIndicesPerTick(indices)
        batching.setMaxRebuildBufferBytesPerTick(bytes)
    case let .runtimeCellLimits(vertices, indices, bytes):
        batching.setMaxRuntimeCellVertices(vertices)
        batching.setMaxRuntimeCellIndices(indices)
        batching.setMaxRuntimeCellBufferBytes(bytes)
    case let .quiescenceFramesBeforeBuild(value):
        batching.setQuiescenceFramesBeforeBatchBuild(value)
    case let .recentVisibilityWindowFrames(value):
        batching.setRecentVisibilityWindowFrames(value)
    }
}

public enum SpatialDebugProperty: Sendable {
    case disabled
    case octreeLeafBounds(SpatialDebugOctreeLeafBoundsSetting)
    case tileBounds(enabled: Bool, maxTileNodeCount: Int = 500)
    case staticBatchCellBounds(enabled: Bool, maxCellCount: Int = 2000, colorMode: SpatialDebugBatchCellColorMode = .plain)
    case lodLevels(Bool)
    case textureStreamingTiers(Bool)
}

public enum SpatialDebugOctreeLeafBoundsSetting: Sendable {
    case enabled(maxLeafNodeCount: Int = 2000, occupiedOnly: Bool = true, colorMode: SpatialDebugLeafColorMode = .plain)
    case disabled
}

public func setSpatialDebug(_ property: SpatialDebugProperty) {
    switch property {
    case .disabled:
        disableSpatialDebugVisualization()
    case let .octreeLeafBounds(.enabled(maxLeafNodeCount, occupiedOnly, colorMode)):
        setOctreeLeafBoundsDebug(
            enabled: true,
            maxLeafNodeCount: maxLeafNodeCount,
            occupiedOnly: occupiedOnly,
            colorMode: colorMode
        )
    case .octreeLeafBounds(.disabled):
        setOctreeLeafBoundsDebug(enabled: false)
    case let .tileBounds(enabled, maxTileNodeCount):
        setTileBoundsDebug(enabled: enabled, maxTileNodeCount: maxTileNodeCount)
    case let .staticBatchCellBounds(enabled, maxCellCount, colorMode):
        setStaticBatchCellBoundsDebug(enabled: enabled, maxCellCount: maxCellCount, colorMode: colorMode)
    case let .lodLevels(value):
        setLODLevelDebug(enabled: value)
    case let .textureStreamingTiers(value):
        setTextureStreamingTierDebug(enabled: value)
    }
}

public enum LoggerProperty: Sendable {
    case level(LogLevel)
    case category(LogCategory, Bool)
    case categories([LogCategory], Bool)
    case resetCategories
}

public func setLogger(_ property: LoggerProperty) {
    switch property {
    case let .level(value):
        Logger.logLevel = value
    case let .category(category, enabled):
        Logger.set(category: category, enabled: enabled)
    case let .categories(categories, enabled):
        for category in categories {
            Logger.set(category: category, enabled: enabled)
        }
    case .resetCategories:
        Logger.resetCategoryToggles()
    }
}

public enum CameraProperty: Sendable {
    case active(EntityID?)
    case defaultFOV(Float)
    case clipPlanes(near: Float, far: Float)
}

public enum DirectionalLightProperty: Sendable {
    case active(EntityID?)
}

public func setCamera(_ property: CameraProperty) {
    switch property {
    case let .active(entityId):
        CameraSystem.shared.activeCamera = entityId
    case let .defaultFOV(value):
        fov = value
    case let .clipPlanes(near: nearPlane, far: farPlane):
        near = nearPlane
        far = farPlane
    }
}

public func setDirectionalLight(_ property: DirectionalLightProperty) {
    switch property {
    case let .active(entityId):
        guard let entityId else {
            LightingSystem.shared.activeDirectionalLight = nil
            return
        }

        guard hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self) else {
            Logger.logWarning(message: "[LightingSystem] Cannot set active directional light. Entity \(entityId) has no DirectionalLightComponent.")
            return
        }

        LightingSystem.shared.activeDirectionalLight = entityId
    }
}

private func applyColorGradingProperty(_ property: ColorGradingProperty) {
    switch property {
    case let .enabled(value):
        ColorGradingParams.shared.enabled = value
    case let .exposure(value):
        ColorGradingParams.shared.exposure = value
    case let .brightness(value):
        ColorGradingParams.shared.brightness = value
    case let .contrast(value):
        ColorGradingParams.shared.contrast = value
    case let .saturation(value):
        ColorGradingParams.shared.saturation = value
    case let .temperature(value):
        ColorGradingParams.shared.temperature = value
    case let .tint(value):
        ColorGradingParams.shared.tint = value
    }
}

private func applyColorLUTProperty(_ property: ColorLUTProperty) {
    switch property {
    case let .enabled(value):
        ColorLUTParams.shared.setEnabled(value)
    }
}

private func applyColorGradeLUTProperty(_ property: ColorGradeLUTProperty) {
    switch property {
    case let .enabled(value):
        ColorGradeLUTParams.shared.setEnabled(value)
    }
}

private func applyColorCorrectionProperty(_ property: ColorCorrectionProperty) {
    switch property {
    case let .enabled(value):
        ColorCorrectionParams.shared.enabled = value
    case let .lift(value):
        ColorCorrectionParams.shared.lift = value
    case let .gamma(value):
        ColorCorrectionParams.shared.gamma = value
    case let .gain(value):
        ColorCorrectionParams.shared.gain = value
    }
}

private func applyBloomThresholdProperty(_ property: BloomThresholdProperty) {
    switch property {
    case let .enabled(value):
        BloomThresholdParams.shared.enabled = value
    case let .threshold(value):
        BloomThresholdParams.shared.threshold = value
    case let .intensity(value):
        BloomThresholdParams.shared.intensity = value
    }
}

private func applyBloomCompositeProperty(_ property: BloomCompositeProperty) {
    switch property {
    case let .enabled(value):
        BloomCompositeParams.shared.enabled = value
    case let .intensity(value):
        BloomCompositeParams.shared.intensity = value
    }
}

private func applyVignetteProperty(_ property: VignetteProperty) {
    switch property {
    case let .enabled(value):
        VignetteParams.shared.enabled = value
    case let .intensity(value):
        VignetteParams.shared.intensity = value
    case let .radius(value):
        VignetteParams.shared.radius = value
    case let .softness(value):
        VignetteParams.shared.softness = value
    case let .center(value):
        VignetteParams.shared.center = value
    }
}

private func applyChromaticAberrationProperty(_ property: ChromaticAberrationProperty) {
    switch property {
    case let .enabled(value):
        ChromaticAberrationParams.shared.enabled = value
    case let .intensity(value):
        ChromaticAberrationParams.shared.intensity = value
    case let .center(value):
        ChromaticAberrationParams.shared.center = value
    }
}

private func applyDepthOfFieldProperty(_ property: DepthOfFieldProperty) {
    switch property {
    case let .enabled(value):
        DepthOfFieldParams.shared.enabled = value
    case let .focusDistance(value):
        DepthOfFieldParams.shared.focusDistance = value
    case let .focusRange(value):
        DepthOfFieldParams.shared.focusRange = value
    case let .maxBlur(value):
        DepthOfFieldParams.shared.maxBlur = value
    }
}

private func applySSAOProperty(_ property: SSAOProperty) {
    switch property {
    case let .enabled(value):
        SSAOParams.shared.enabled = value
    case let .radius(value):
        SSAOParams.shared.radius = value
    case let .bias(value):
        SSAOParams.shared.bias = value
    case let .intensity(value):
        SSAOParams.shared.intensity = value
    case let .quality(value):
        SSAOParams.shared.quality = value
    }
}
