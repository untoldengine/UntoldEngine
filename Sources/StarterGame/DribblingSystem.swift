//
//  DribblingSystem.swift
//
//
//  Created by Harold Serrano on 2/25/25.
//

import Foundation
import simd
import SwiftUI
import UntoldEngine

public class DribblinComponent: Component, Codable {
    public required init() {}
    var maxSpeed: Float = 5.0
    var kickSpeed: Float = 15.0
    // var turnSpeed: Float = 10.0
    var direction: simd_float3 = .zero
}

// func getTurnSpeed(entityId: EntityID) -> Float {
//    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
//        return 0.0
//    }
//
//    return dribblingComponent.turnSpeed
// }
//
// func setTurnSpeed(entityId: EntityID, turnSpeed: Float) {
//    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
//        return
//    }
//
//    dribblingComponent.turnSpeed = turnSpeed
// }

func getMaxSpeed(entityId: EntityID) -> Float {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return 0.0
    }

    return dribblingComponent.maxSpeed
}

func setMaxSpeed(entityId: EntityID, maxSpeed: Float) {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return
    }

    dribblingComponent.maxSpeed = maxSpeed
}

func getKickSpeed(entityId: EntityID) -> Float {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return 0.0
    }

    return dribblingComponent.kickSpeed
}

func setPlayerDirection(entityId: EntityID, direction: simd_float3) {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return
    }

    dribblingComponent.direction = direction
}

func getPlayerDirection(entityId: EntityID) -> simd_float3 {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return .zero
    }

    return dribblingComponent.direction
}

func setKickSpeed(entityId: EntityID, maxSpeed: Float) {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return
    }

    dribblingComponent.kickSpeed = maxSpeed
}

public func dribblingSystemUpdate(deltaTime: Float) {
    let customId = getComponentId(for: DribblinComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    guard let ball = findEntity(name: "ball") else {
        return
    }

    guard let ballComponent = scene.get(component: BallComponent.self, for: ball) else {
        return
    }

    for entity in entities {
        guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entity) else {
            continue
        }

        if isWASDPressed() {
            changeAnimation(entityId: entity, name: "running")
            pausePhysicsComponent(entityId: entity, isPaused: false)
        } else {
            changeAnimation(entityId: entity, name: "idle")
            pausePhysicsComponent(entityId: entity, isPaused: true)
            return
        }
        var newPosition: simd_float3 = .zero

        if inputSystem.keyState.wPressed {
            newPosition.z += 1.0
        }

        if inputSystem.keyState.sPressed {
            newPosition.z -= 1.0
        }

        if inputSystem.keyState.aPressed {
            newPosition.x -= 1.0
        }

        if inputSystem.keyState.dPressed {
            newPosition.x += 1.0
        }

        var ballPosition: simd_float3 = getPosition(entityId: ball)
        ballPosition.y = 0.0
        // newPosition = newPosition + ballPosition*0.1

        if simd_length(getPosition(entityId: entity) - getPosition(entityId: ball)) < 1.0 {
            ballComponent.state = .kick
            ballComponent.velocity = simd_normalize(newPosition)
        }

        steerSeek(entityId: entity, targetPosition: ballPosition, maxSpeed: dribblingComponent.maxSpeed, deltaTime: deltaTime, turnSpeed: 50.0)
    }
}


var DribblingComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: DribblinComponent.self),
    name: "Dribbling Component",
    type: DribblinComponent.self,
    view: { selectedId, _, refreshView in
        AnyView(
            VStack {
                if selectedId != nil {
                    var maxSpeed = getMaxSpeed(entityId: selectedId!)
                    var kickSpeed = getKickSpeed(entityId: selectedId!)
//                    var turnSpeed = getTurnSpeed(entityId: selectedId!)
                    var playerDirection = getPlayerDirection(entityId: selectedId!)
                    Text("Dribbling Component")
                    TextInputNumberView(label: "Max Speed", value: Binding(
                        get: { maxSpeed },
                        set: { newMaxSpeed in
                            setMaxSpeed(entityId: selectedId!, maxSpeed: newMaxSpeed)
                            refreshView()
                        }))
                    TextInputNumberView(label: "Kick Speed", value: Binding(
                        get: { kickSpeed },
                        set: { newKickSpeed in
                            setKickSpeed(entityId: selectedId!, maxSpeed: newKickSpeed)
                            refreshView()
                        }))
//                    TextInputNumberView(label: "Turn Speed", value: Binding(
//                        get: { turnSpeed },
//                        set: { newTurnSpeed in
//                            setTurnSpeed(entityId: selectedId!, turnSpeed: newTurnSpeed)
//                            refreshView()
//                        }))
                    TextInputVectorView(label: "Direction", value: Binding(
                        get: { playerDirection },
                        set: { newPlayerDirection in
                            setPlayerDirection(entityId: selectedId!, direction: newPlayerDirection)
                            refreshView()
                        }))
                }
            }
        )
    },
    onAdd: { entityId in
        registerComponent(entityId: entityId, componentType: DribblinComponent.self)
    }
)
