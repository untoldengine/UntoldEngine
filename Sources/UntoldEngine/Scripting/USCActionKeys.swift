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
    case magnitude
    case minSpeed
    case damping
    case duration
    case offset
    case localOffset
    case pitch
    case yaw
    case sensitivity
    case smoothFactor

    case position

    // Camera look-at
    case eye
    case target
    case up

    // Camera movement with input
    case inputW
    case inputA
    case inputS
    case inputD
    case inputQ
    case inputE
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

    case cameraMoveTo
    case cameraLookAt
    case cameraMoveWithInput
    case cameraMoveBy
    case cameraRotate
    case cameraFollow
    case cameraFollowLocal
    case cameraOrbitTarget

    // Physics linear motion
    case applyLinearImpulse
    case applyWorldForce
    case setLinearVelocity
    case addLinearVelocity
    case clampLinearSpeed
    case applyLinearDamping
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
