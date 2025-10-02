//
//  DribblingSystem.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
        var maxSpeed: Float = 5.0 // Maximum movement speed for dribbling
        var kickSpeed: Float = 15.0 // Speed applied when kicking the ball
        var direction: simd_float3 = .zero // Current movement direction (from input)
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
            if InputSystem.shared.keyState.wPressed { newPosition.z += 1.0 }
            if InputSystem.shared.keyState.sPressed { newPosition.z -= 1.0 }
            if InputSystem.shared.keyState.aPressed { newPosition.x -= 1.0 }
            if InputSystem.shared.keyState.dPressed { newPosition.x += 1.0 }

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

    
#endif
