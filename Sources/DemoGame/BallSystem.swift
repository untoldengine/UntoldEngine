//
//  CustomSystem.swift
//
//
//  Created by Harold Serrano on 2/24/25.
//
#if os(macOS)
import simd
import SwiftUI
import UntoldEngine

// BallState represents the different states a ball can be in during gameplay.
// This makes it easier to manage transitions like idle → kick → moving → decelerating.
enum BallState: Codable {
    case idle
    case kick
    case moving
    case decelerating
}

// BallComponent is a custom ECS component that stores the ball's state and motion data.
// Every entity with this component will behave like a ball in the game.
public class BallComponent: Component, Codable {
    var motionAccumulator: simd_float3 = .zero   // Used to accumulate velocity for smoother force application
    var state: BallState = .idle                 // Current state of the ball (idle, moving, etc.)
    var velocity: simd_float3 = .zero            // Current velocity of the ball
    public required init() {}
}

// ballSystemUpdate runs once per frame and updates all entities that have a BallComponent.
// This is where we apply physics, update states, and define how the ball behaves.
public func ballSystemUpdate(deltaTime: Float) {
    // Get the ID of the BallComponent so we can query entities that use it
    let customId = getComponentId(for: BallComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    for entity in entities {
        guard let ballComponent = scene.get(component: BallComponent.self, for: entity) else { continue }

        // Apply drag to simulate resistance as the ball moves
        setLinearDragCoefficient(entityId: entity, coefficients: simd_float2(0.7, 0.0))
        setAngularDragCoefficient(entityId: entity, coefficients: simd_float2(0.07, 0.0))

        // Update the ball based on its current state
        switch ballComponent.state {
        case .idle:
            // Do nothing, the ball is at rest
            break
        case .kick:
            // Transition to moving when the ball is kicked
            ballComponent.state = .moving
            applyVelocity(finalVelocity: ballComponent.velocity * 5.0, deltaTime: deltaTime, ball: entity)
        case .moving:
            // If the velocity drops below a threshold, start decelerating
            if simd_length(getVelocity(entityId: entity)) <= 0.1 {
                ballComponent.state = .decelerating
            }
        case .decelerating:
            // Gradually slow down the ball
            decelerate(deltaTime: deltaTime, ball: entity)
            if simd_length(getVelocity(entityId: entity)) < 0.1 {
                // You could transition back to .idle here if desired
            }
        }
    }
}

// Apply a force to the ball to simulate a kick or strong push.
// Uses an accumulator to smooth motion and applies both linear and angular forces.
func applyVelocity(finalVelocity: simd_float3, deltaTime: Float, ball: EntityID) {
    guard let customComponent = scene.get(component: BallComponent.self, for: ball) else { return }

    let mass: Float = getMass(entityId: ball)
    let ballDim = getDimension(entityId: ball)

    // Blend previous motion with new input for smoother physics
    let bias: Float = 0.4
    let vComp: simd_float3 = finalVelocity * (1.0 - bias)
    customComponent.motionAccumulator = customComponent.motionAccumulator * bias + vComp

    // Apply linear force based on mass and deltaTime
    var force: simd_float3 = (customComponent.motionAccumulator * mass) / deltaTime
    applyForce(entityId: ball, force: force)

    // Apply angular force so the ball spins as it moves
    let upAxis = simd_float3(0.0, ballDim.depth / 2.0, 0.0)
    force *= 0.25
    applyMoment(entityId: ball, force: force, at: upAxis)

    // Reset velocity so physics is only applied through forces
    clearVelocity(entityId: ball)
    clearAngularVelocity(entityId: ball)
}

// Gradually slow down the ball by applying counter-forces.
// Works similarly to applyVelocity, but reduces motion instead of adding it.
func decelerate(deltaTime: Float, ball: EntityID) {
    guard let customComponent = scene.get(component: BallComponent.self, for: ball) else { return }

    let ballDim = getDimension(entityId: ball)
    let velocity: simd_float3 = getVelocity(entityId: ball)

    // Blend down velocity for smoother deceleration
    let bias: Float = 0.5
    let vComp: simd_float3 = velocity * (1.0 - bias)
    customComponent.motionAccumulator = customComponent.motionAccumulator * bias + vComp

    // Apply counter-force to slow down
    var force: simd_float3 = (customComponent.motionAccumulator * getMass(entityId: ball)) / deltaTime
    force *= 0.15
    applyForce(entityId: ball, force: force)

    // Apply spin reduction
    let upAxis = simd_float3(0.0, ballDim.depth / 2.0, 0.0)
    force *= 0.25
    applyMoment(entityId: ball, force: force, at: upAxis)

    // Clear velocity so deceleration is handled through applied forces
    clearVelocity(entityId: ball)
    clearAngularVelocity(entityId: ball)
}
// BallComponent_Editor integrates the BallComponent with the Editor.
// This makes the component visible and editable in the UI.
var BallComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: BallComponent.self),
    name: "Ball Component",
    type: BallComponent.self,
    view: makeEditorView(fields: [
        .text(
            label: "Ball Component",
            placeholder: "Entity name",
            get: { entityId in
                getEntityName(entityId: entityId) ?? "None"
            },
            set: { entityId, targetName in
                setEntityName(entityId: entityId, name: targetName)
            }
        ),
    ]),
    onAdd: { entityId in
        // When a BallComponent is added in the Editor, register it with the entity
        registerComponent(entityId: entityId, componentType: BallComponent.self)
    }
)
#endif
