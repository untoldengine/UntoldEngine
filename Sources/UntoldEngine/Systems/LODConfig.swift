//
//  LODConfig.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
