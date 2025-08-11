//
//  CustomSystem.swift
//
//
//  Created by Harold Serrano on 2/24/25.
//
import simd
import SwiftUI
import UntoldEngine

enum BallState: Codable {
    case idle
    case kick
    case moving
    case decelerating
}

public class BallComponent: Component, Codable {
    var motionAccumulator: simd_float3 = .zero
    var state: BallState = .idle
    var velocity: simd_float3 = .zero
    public required init() {}
}

public func ballSystemUpdate(deltaTime: Float) {
    let customId = getComponentId(for: BallComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    for entity in entities {
        guard let ballComponent = scene.get(component: BallComponent.self, for: entity) else { continue }

        setLinearDragCoefficient(entityId: entity, coefficients: simd_float2(0.7, 0.0))
        setAngularDragCoefficient(entityId: entity, coefficients: simd_float2(0.07, 0.0))

        switch ballComponent.state {
        case .idle:
            break
        case .kick:
            ballComponent.state = .moving
            applyVelocity(finalVelocity: ballComponent.velocity * 5.0, deltaTime: deltaTime, ball: entity)
        case .moving:

            if simd_length(getVelocity(entityId: entity)) <= 0.1 {
                ballComponent.state = .decelerating
            }
        case .decelerating:
            decelerate(deltaTime: deltaTime, ball: entity)
            if simd_length(getVelocity(entityId: entity)) < 0.1 {}
        }
    }
}

func applyVelocity(finalVelocity: simd_float3, deltaTime: Float, ball: EntityID) {
    guard let customComponent = scene.get(component: BallComponent.self, for: ball) else { return }

    let mass: Float = getMass(entityId: ball)
    let ballDim = getDimension(entityId: ball)
    let bias: Float = 0.4
    let vComp: simd_float3 = finalVelocity * (1.0 - bias)
    customComponent.motionAccumulator = customComponent.motionAccumulator * bias + vComp

    var force: simd_float3 = (customComponent.motionAccumulator * mass) / deltaTime
    applyForce(entityId: ball, force: force)

    let upAxis = simd_float3(0.0, ballDim.depth / 2.0, 0.0)

    force *= 0.25

    applyMoment(entityId: ball, force: force, at: upAxis)

    clearVelocity(entityId: ball)
    clearAngularVelocity(entityId: ball)
}

func decelerate(deltaTime: Float, ball: EntityID) {
    guard let customComponent = scene.get(component: BallComponent.self, for: ball) else { return }

    let ballDim = getDimension(entityId: ball)
    let velocity: simd_float3 = getVelocity(entityId: ball)
    let bias: Float = 0.5
    let vComp: simd_float3 = velocity * (1.0 - bias)
    customComponent.motionAccumulator = customComponent.motionAccumulator * bias + vComp

    var force: simd_float3 = (customComponent.motionAccumulator * getMass(entityId: ball)) / deltaTime
    force *= 0.15
    applyForce(entityId: ball, force: force)

    let upAxis = simd_float3(0.0, ballDim.depth / 2.0, 0.0)

    force *= 0.25

    applyMoment(entityId: ball, force: force, at: upAxis)

    clearVelocity(entityId: ball)
    clearAngularVelocity(entityId: ball)
}

var BallComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: BallComponent.self),
    name: "Ball Component",
    type: BallComponent.self,
    view: makeEditorView(fields: []),
    onAdd: { entityId in
        registerComponent(entityId: entityId, componentType: DribblinComponent.self)
    }
)
