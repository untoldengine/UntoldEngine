//
//  AnimationSystem.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public final class AnimationSystem: @unchecked Sendable {
    /// Thread-safe shared instance
    public static let shared: AnimationSystem = .init()

    private let queue = DispatchQueue(label: "com.untoldengine.animation-system-queue", attributes: .concurrent)

    var _isEnabled: Bool = true
    /// Read and Write (thread-safe)
    public var isEnabled: Bool {
        get { queue.sync { _isEnabled } }
        set {
            queue.sync(flags: .barrier) {
                if newValue {
                    self._updateAnimationCallback = updateAnimationSystem
                } else {
                    self._updateAnimationCallback = updateAnimationSystemDummy
                }
                self._isEnabled = newValue
            }
        }
    }

    public typealias UpdateAnimationCallback = (Float) -> Void

    var _updateAnimationCallback: UpdateAnimationCallback = updateAnimationSystem
    public var update: UpdateAnimationCallback {
        _updateAnimationCallback
    }
}

/// Small performance trick.
/// It's always faster to have a funciton pointers inside the render loop and switch to dummy functions if you don't need them
/// instead of add an ifelse conditional jump.
private func updateAnimationSystemDummy(deltaTime _: Float) {}

private func resolveDescendantEntity(
    entityId: EntityID,
    matches: (EntityID) -> Bool
) -> EntityID? {
    if matches(entityId) {
        return entityId
    }

    guard let scenegraph = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        return nil
    }

    for childId in scenegraph.children {
        if let resolved = resolveDescendantEntity(entityId: childId, matches: matches) {
            return resolved
        }
    }

    return nil
}

func resolveEntityWithAnimationComponent(entityId: EntityID) -> EntityID? {
    resolveDescendantEntity(entityId: entityId) {
        scene.get(component: AnimationComponent.self, for: $0) != nil
    }
}

func resolveEntityForAnimationBinding(entityId: EntityID) -> EntityID? {
    resolveDescendantEntity(entityId: entityId) {
        scene.get(component: SkeletonComponent.self, for: $0) != nil &&
            scene.get(component: RenderComponent.self, for: $0) != nil
    }
}

private func updateAnimationSystem(deltaTime: Float) {
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

        animationComponent.currentTime += deltaTime * animationComponent.playbackSpeed

        guard let animationClip = animationComponent.currentAnimation else { continue }

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
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.pause = isPaused
}

public func isAnimationComponentPaused(entityId: EntityID) -> Bool {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return true
    }

    return animationComponent.pause
}

public func changeAnimation(entityId: EntityID, name: String, withPause: Bool = false) {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
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

public func setAnimationPlaybackSpeed(entityId: EntityID, speed: Float) {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.playbackSpeed = max(0.0, speed)
}

public func getAnimationPlaybackSpeed(entityId: EntityID) -> Float {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return 1.0
    }

    return animationComponent.playbackSpeed
}

public func getAllAnimationClips(entityId: EntityID) -> [String] {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        return []
    }

    return animationComponent.getAllAnimationClips()
}

public func removeAnimationClip(entityId: EntityID, animationClip: String) {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.removeAnimationClip(animationClip: animationClip)
}
