//
//  AnimationSystem.swift
//
//
//  Created by Harold Serrano on 11/15/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.

import Foundation

public func updateAnimationSystem(deltaTime: Float) {
    
    currentGlobalTime += deltaTime
    
    let skeletonId = getComponentId(for: SkeletonComponent.self)
    let animationId = getComponentId(for: AnimationComponent.self)
    
    let entities = queryEntitiesWithComponentIds([skeletonId, animationId], in: scene)

    for entity in entities {
        
        guard let animationComponent = scene.get(component: AnimationComponent.self, for: entity) else {
            
            continue
        }
        
        guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entity) else {
            
            continue
        }
        
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entity) else {
            
            continue
        }
        
        guard let animationClip = animationComponent.currentAnimation else { return }
            skeletonComponent.skeleton.updateWorldPose(
            at: currentGlobalTime,
            animationClip: animationClip)
        
        renderComponent.mesh.skin?.updateJointMatrices(skeleton: skeletonComponent.skeleton)
    }
}

public func changeAnimation(entityId:EntityID, name: String){
    
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
            print("Entity \(entityId) does not have an animation component.")
            return
        }
        
    guard let animationClip = animationComponent.animationClips[name] else {
        print("Animation clip with name '\(name)' does not exist for entity \(entityId).")
        return
    }
    
    animationComponent.currentAnimation = animationClip
    
}
