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
}

public enum RenderingToggle: Sendable {
    case enabled
    case disabled
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
    }
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
