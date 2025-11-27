//
//  USCActionKeys.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

public enum ScriptArgKey: String {
    case targetPosition
    case threatPosition
    case maxSpeed
    case slowingRadius
    case targetEntity
    case threatEntity
    case deltaTime
    case turnSpeed
    case weight
    case centerPosition
    case radius
    case strength
    case speed
}

public enum ScriptActionName: String {
    case seek
    case flee
    case arrive
    case pursuit
    case evade

    case steerSeek
    case steerArrive
    case steerFlee
    case steerPursuit
    case steerFollowPath
    case orbit
}

extension [String: Value] {
    subscript(_ key: ScriptArgKey) -> Value? {
        self[key.rawValue]
    }
}

extension USCActionRegistry {
    func register(name action: ScriptActionName,
                  _ handler: @escaping (USCContext, [String: Value]) -> Value?)
    {
        register(name: action.rawValue, action: handler)
    }
}
