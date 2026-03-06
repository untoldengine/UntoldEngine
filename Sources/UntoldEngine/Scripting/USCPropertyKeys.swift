//
//  USCPropertyKeys.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

    // Engine properties
    case deltaTime // Time elapsed since last frame
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
