//
//  SSAO.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
