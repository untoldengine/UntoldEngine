//
//  LODConfig.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct LODConfig {
    public static var shared = LODConfig()

    // Default distance thresholds (in world units)
    public var lodDistances: [Float] = [
        50.0, // LOD0 -> LOD1
        100.0, // LOD1 -> LOD2
        200.0, // LOD2 -> LOD3
        500.0, // LOD3 -> LOD4 (or culled)
    ]

    // Bias multiplier (1.0 = normal, 2.0 = switch 2x earlier)
    public var lodBias: Float = 1.0

    // Hysteresis to prevent flickering ( add to distance when switching up)
    public var hysteresis: Float = 5.0

    // Enable smooth transitions - Not yet implemented
    public var enableFadeTransitions: Bool = false
    public var fadeTransitionTime: Float = 0.3
}
