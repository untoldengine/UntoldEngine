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
    case dribbling
    case decelerating
}

public class BallComponent: Component, Codable {
    var motionAccumulator: simd_float3 = .zero
    // var state: BallState = .idle
    public required init() {}
}

public func ballSystemUpdate(deltaTime: Float) {
    let customId = getComponentId(for: BallComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    guard let playerEntity: EntityID = findEntity(name: "player") else {
        return
    }

    guard let playerComponent = scene.get(component: DribblinComponent.self, for: playerEntity) else {
        return
    }

    let playerPosition: simd_float3 = getPosition(entityId: playerEntity)
    let playerVelocity: simd_float3 = getVelocity(entityId: playerEntity) * playerComponent.kickSpeed

    for entity in entities {
        guard let ballComponent = scene.get(component: BallComponent.self, for: entity) else { continue }

        let ballPosition = getPosition(entityId: entity)

        let distanceToPlayer: Float = simd_length(ballPosition - playerPosition)

//        switch ballComponent.state{
//        case .idle:
//            if distanceToPlayer < 0.7{
//                ballComponent.state = .dribbling
//                applyVelocity(finalVelocity: playerVelocity, deltaTime: deltaTime, ball: entity)
//            }
//        case .dribbling:
//            if distanceToPlayer >= 0.9{
//                ballComponent.state = .decelerating
//                decelerate(deltaTime: deltaTime, ball: entity)
//            }
//        case .decelerating:
//            if(simd_length(getVelocity(entityId: entity)) < 0.1){
//                ballComponent.state = .idle
//            }
//
//        }
        if distanceToPlayer < 1.0 {
            applyVelocity(finalVelocity: playerVelocity, deltaTime: deltaTime, ball: entity)
        } else {
            decelerate(deltaTime: deltaTime, ball: entity)
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
    let bias: Float = 0.95
    let vComp: simd_float3 = velocity * (1.0 - bias)
    customComponent.motionAccumulator = customComponent.motionAccumulator * bias + vComp

    var force: simd_float3 = (customComponent.motionAccumulator * getMass(entityId: ball)) / deltaTime
    force *= 0.75
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
    view: { selectedId, _, _ in
        AnyView(
            VStack {
                if selectedId != nil {
                    Text("Ball Component")
                }
            }
        )
    },
    onAdd: { entityId in
        registerComponent(entityId: entityId, componentType: BallComponent.self)
    }
)
