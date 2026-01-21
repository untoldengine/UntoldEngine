//
//  PostFX.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

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
}
