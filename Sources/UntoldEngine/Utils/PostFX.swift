//
//  PostFX.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// MARK: - PostFXPreset

public struct PostFXPreset: Sendable {
    public let name: String
    public var colorGrading: Bool
    public var exposure: Float
    public var brightness: Float
    public var contrast: Float
    public var saturation: Float
    public var temperature: Float
    public var tint: Float
    public var ssao: Bool
    public var ssaoRadius: Float
    public var ssaoBias: Float
    public var ssaoIntensity: Float

    public init(
        name: String,
        colorGrading: Bool = false,
        exposure: Float = 0.0,
        brightness: Float = 0.0,
        contrast: Float = 1.0,
        saturation: Float = 1.0,
        temperature: Float = 0.0,
        tint: Float = 0.0,
        ssao: Bool = false,
        ssaoRadius: Float = 0.5,
        ssaoBias: Float = 0.025,
        ssaoIntensity: Float = 0.0
    ) {
        self.name = name
        self.colorGrading = colorGrading
        self.exposure = exposure
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.tint = tint
        self.ssao = ssao
        self.ssaoRadius = ssaoRadius
        self.ssaoBias = ssaoBias
        self.ssaoIntensity = ssaoIntensity
    }
}

public extension PostFXPreset {
    static let neutral = PostFXPreset(name: "Neutral")

    static let cinematic = PostFXPreset(
        name: "Cinematic",
        colorGrading: true,
        exposure: -0.2,
        brightness: -0.05,
        contrast: 1.15,
        saturation: 0.9,
        ssao: true,
        ssaoRadius: 0.5,
        ssaoBias: 0.02,
        ssaoIntensity: 0.5
    )

    static let highContrast = PostFXPreset(
        name: "High Contrast",
        colorGrading: true,
        exposure: 0.15,
        brightness: 0.08,
        contrast: 1.35,
        saturation: 1.2,
        ssao: true,
        ssaoRadius: 0.5,
        ssaoBias: 0.018,
        ssaoIntensity: 0.6
    )

    static let softAO = PostFXPreset(
        name: "Soft AO",
        colorGrading: true,
        exposure: 0.0,
        brightness: 0.02,
        contrast: 1.05,
        saturation: 1.0,
        ssao: true,
        ssaoRadius: 0.7,
        ssaoBias: 0.03,
        ssaoIntensity: 0.3
    )

    static let archviz = PostFXPreset(
        name: "Archviz",
        colorGrading: true,
        exposure: 0.15,
        brightness: 0.05,
        contrast: 1.1,
        saturation: 0.95,
        temperature: 0.08,
        ssao: true,
        ssaoRadius: 0.5,
        ssaoBias: 0.02,
        ssaoIntensity: 0.4
    )
}

// MARK: - PostFXEffect

public enum PostFXEffect: CaseIterable {
    case colorGrading
    case colorCorrection
    case bloomThreshold
    case bloomComposite
    case vignette
    case chromaticAberration
    case depthOfField
}

public enum PostFX {
    public static func setEnabled(_ effect: PostFXEffect, _ isEnabled: Bool) {
        switch effect {
        case .colorGrading:
            ColorGradingParams.shared.enabled = isEnabled
        case .colorCorrection:
            ColorCorrectionParams.shared.enabled = isEnabled
        case .bloomThreshold:
            BloomThresholdParams.shared.enabled = isEnabled
        case .bloomComposite:
            BloomCompositeParams.shared.enabled = isEnabled
        case .vignette:
            VignetteParams.shared.enabled = isEnabled
        case .chromaticAberration:
            ChromaticAberrationParams.shared.enabled = isEnabled
        case .depthOfField:
            DepthOfFieldParams.shared.enabled = isEnabled
        }
    }

    public static func isEnabled(_ effect: PostFXEffect) -> Bool {
        switch effect {
        case .colorGrading:
            return ColorGradingParams.shared.enabled
        case .colorCorrection:
            return ColorCorrectionParams.shared.enabled
        case .bloomThreshold:
            return BloomThresholdParams.shared.enabled
        case .bloomComposite:
            return BloomCompositeParams.shared.enabled
        case .vignette:
            return VignetteParams.shared.enabled
        case .chromaticAberration:
            return ChromaticAberrationParams.shared.enabled
        case .depthOfField:
            return DepthOfFieldParams.shared.enabled
        }
    }

    public static func enableColorGrading(_ isEnabled: Bool) {
        setEnabled(.colorGrading, isEnabled)
    }

    public static func enableColorCorrection(_ isEnabled: Bool) {
        setEnabled(.colorCorrection, isEnabled)
    }

    public static func enableBloomThreshold(_ isEnabled: Bool) {
        setEnabled(.bloomThreshold, isEnabled)
    }

    public static func enableBloomComposite(_ isEnabled: Bool) {
        setEnabled(.bloomComposite, isEnabled)
    }

    public static func enableVignette(_ isEnabled: Bool) {
        setEnabled(.vignette, isEnabled)
    }

    public static func enableChromaticAberration(_ isEnabled: Bool) {
        setEnabled(.chromaticAberration, isEnabled)
    }

    public static func enableDepthOfField(_ isEnabled: Bool) {
        setEnabled(.depthOfField, isEnabled)
    }

    public static func apply(_ preset: PostFXPreset) {
        ColorGradingParams.shared.enabled = preset.colorGrading
        ColorGradingParams.shared.exposure = preset.exposure
        ColorGradingParams.shared.brightness = preset.brightness
        ColorGradingParams.shared.contrast = preset.contrast
        ColorGradingParams.shared.saturation = preset.saturation
        ColorGradingParams.shared.temperature = preset.temperature
        ColorGradingParams.shared.tint = preset.tint
        SSAOParams.shared.enabled = preset.ssao
        SSAOParams.shared.radius = preset.ssaoRadius
        SSAOParams.shared.bias = preset.ssaoBias
        SSAOParams.shared.intensity = preset.ssaoIntensity
    }
}
