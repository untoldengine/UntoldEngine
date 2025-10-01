//
//  AnimationSystem.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.

import Foundation

public final class AnimationSystem
{
    // Thread-safe shared instance
    public static let shared: AnimationSystem = { return AnimationSystem() }()
    
    private let queue = DispatchQueue(label: "com.untoldengine.animation-system-queue", attributes: .concurrent)
    
    var _isEnabled: Bool = true
    // Read and Write (thread-safe)
    public var isEnabled: Bool {
        get { queue.sync { _isEnabled } }
        set {
            queue.sync(flags: .barrier) {
                self._updateAnimationCallback = newValue ? updateAnimationSystem : updateAnimationSystemDummy
                self._isEnabled = newValue
            }
        }
    }
        
    public typealias UpdateAnimationCallback = ( (Float) -> Void )
    
    var _updateAnimationCallback: UpdateAnimationCallback = updateAnimationSystem
    public var update: UpdateAnimationCallback { _updateAnimationCallback }
}

// Small performance trick.
// It's always faster to have a funciton pointers inside the render loop and switch to dummy functions if you don't need them
// instead of add an ifelse conditional jump.
fileprivate func updateAnimationSystemDummy(deltaTime: Float) { }

fileprivate func updateAnimationSystem(deltaTime: Float) {
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

        if isAnimationComponentPaused(entityId: entity) {
            continue
        }

        animationComponent.currentTime += deltaTime

        guard let animationClip = animationComponent.currentAnimation else { return }

        skeletonComponent.skeleton.updateWorldPose(
            at: animationComponent.currentTime,
            animationClip: animationClip
        )

        // Update the skin for each mesh in the render component
        for index in renderComponent.mesh.indices {
            if let skin = renderComponent.mesh[index].skin {
                skin.updateJointMatrices(skeleton: skeletonComponent.skeleton)
            }
        }
    }
}

public func pauseAnimationComponent(entityId: EntityID, isPaused: Bool) {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.pause = isPaused
}

public func isAnimationComponentPaused(entityId: EntityID) -> Bool {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return true
    }

    return animationComponent.pause
}

public func changeAnimation(entityId: EntityID, name: String, withPause: Bool = false) {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    guard let animationClip = animationComponent.animationClips[name] else {
        handleError(.noAnimationClip, name, entityId)
        return
    }

    animationComponent.currentAnimation = animationClip
    animationComponent.pause = withPause
}

public func getAllAnimationClips(entityId: EntityID) -> [String] {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        return []
    }

    return animationComponent.getAllAnimationClips()
}

public func removeAnimationClip(entityId: EntityID, animationClip: String) {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.removeAnimationClip(animationClip: animationClip)
}
