//
//  SSAO.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

public enum SSAO {
    public static func setEnabled(_ isEnabled: Bool) {
        SSAOParams.shared.enabled = isEnabled
    }

    public static func isEnabled() -> Bool {
        SSAOParams.shared.enabled
    }

    public static func setQuality(_ quality: SSAOQuality) {
        SSAOParams.shared.quality = quality
    }

    public static func getQuality() -> SSAOQuality {
        SSAOParams.shared.quality
    }

    public static func setRadius(_ radius: Float) {
        SSAOParams.shared.radius = radius
    }

    public static func getRadius() -> Float {
        SSAOParams.shared.radius
    }

    public static func setBias(_ bias: Float) {
        SSAOParams.shared.bias = bias
    }

    public static func getBias() -> Float {
        SSAOParams.shared.bias
    }

    public static func setIntensity(_ intensity: Float) {
        SSAOParams.shared.intensity = intensity
    }

    public static func getIntensity() -> Float {
        SSAOParams.shared.intensity
    }
}
