//
//  DribblingSystem.swift
//
//
//  Created by Harold Serrano on 2/25/25.
//

#if os(macOS)
import Foundation
import simd
import SwiftUI
import UntoldEngine

// DribblinComponent stores data related to the player’s dribbling behavior.
// It defines how fast the player can move, how hard they can kick the ball,
// and the current input direction. This component will be attached to entities
// (like a player) that can dribble the ball.
public class DribblinComponent: Component, Codable {
    public required init() {}
    var maxSpeed: Float = 5.0        // Maximum movement speed for dribbling
    var kickSpeed: Float = 15.0      // Speed applied when kicking the ball
    var direction: simd_float3 = .zero // Current movement direction (from input)
}

// -----------------------------------------------------------------------------
// Helper functions for accessing and modifying DribblinComponent values
// -----------------------------------------------------------------------------

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

func setKickSpeed(entityId: EntityID, maxSpeed: Float) {
    guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entityId) else {
        return
    }
    dribblingComponent.kickSpeed = maxSpeed
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

// -----------------------------------------------------------------------------
// Dribbling System
// This system is called every frame and updates entities with a DribblinComponent.
// It handles input (WASD keys), animations, and ball interactions.
// -----------------------------------------------------------------------------

public func dribblingSystemUpdate(deltaTime: Float) {
    let customId = getComponentId(for: DribblinComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    // Look up the ball in the scene by name
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

        // If WASD keys are pressed → player is moving
        if isWASDPressed() {
            changeAnimation(entityId: entity, name: "running")
            pausePhysicsComponent(entityId: entity, isPaused: false)
        } else {
            // No input → idle animation, freeze physics
            changeAnimation(entityId: entity, name: "idle")
            pausePhysicsComponent(entityId: entity, isPaused: true)
            return
        }

        // Compute direction from key inputs
        var newPosition: simd_float3 = .zero
        if inputSystem.keyState.wPressed { newPosition.z += 1.0 }
        if inputSystem.keyState.sPressed { newPosition.z -= 1.0 }
        if inputSystem.keyState.aPressed { newPosition.x -= 1.0 }
        if inputSystem.keyState.dPressed { newPosition.x += 1.0 }

        // Get the ball’s position (ignore height for ground movement)
        var ballPosition: simd_float3 = getPosition(entityId: ball)
        ballPosition.y = 0.0

        // Check distance: if close to the ball, apply a kick
        if simd_length(getPosition(entityId: entity) - getPosition(entityId: ball)) < 1.0 {
            ballComponent.state = .kick
            ballComponent.velocity = simd_normalize(newPosition)
        }

        // Steer the player toward the ball position (dribbling behavior)
        steerSeek(
            entityId: entity,
            targetPosition: ballPosition,
            maxSpeed: dribblingComponent.maxSpeed,
            deltaTime: deltaTime,
            turnSpeed: 50.0
        )
    }
}

// -----------------------------------------------------------------------------
// Editor Integration
// Makes DribblinComponent editable in the Editor (Inspector panel).
// -----------------------------------------------------------------------------
var DribblingComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: DribblinComponent.self),
    name: "Dribbling Component",
    type: DribblinComponent.self,
    view: makeEditorView(fields: [
        // Editable field for max speed
        .number(label: "Max Speed",
                get: { entityId in getMaxSpeed(entityId: entityId) },
                set: { entityId, newMaxSpeed in setMaxSpeed(entityId: entityId, maxSpeed: newMaxSpeed) }),

        // Editable field for kick speed
        .number(label: "Kick Speed",
                get: { entityId in getKickSpeed(entityId: entityId) },
                set: { entityId, newKickSpeed in setKickSpeed(entityId: entityId, maxSpeed: newKickSpeed) }),

        // Editable field for movement direction
        .vector3(label: "Direction",
                 get: { entityId in getPlayerDirection(entityId: entityId) },
                 set: { entityId, newDirection in setPlayerDirection(entityId: entityId, direction: newDirection) }),
    ]),
    onAdd: { entityId in
        // When added in the Editor, register this component with the entity
        registerComponent(entityId: entityId, componentType: DribblinComponent.self)
    }
)
#endif
