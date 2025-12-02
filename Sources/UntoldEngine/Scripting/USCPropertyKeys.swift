//
//  USCPropertyKeys.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

/// Engine-backed properties that USC can read/write via USCPropertyAccess.
public enum ScriptProperty: String {
    // LocalTransformComponent
    case position
    case rotation
    case scale

    // PhysicsComponents
    case velocity
    case acceleration
    case mass
    case angularVelocity

    // LightComponent
    case intensity
    case color
}

/// Sub-components of a vec3 property (x, y, z)
public enum ScriptAxis: String {
    case x
    case y
    case z
}

public extension ScriptProperty {
    /// Build the string key used by USCPropertyAccess, like "position" or "velocity.x"
    func keyPath(axis: ScriptAxis? = nil) -> String {
        if let axis {
            return "\(rawValue).\(axis.rawValue)"
        } else {
            return rawValue
        }
    }
}
