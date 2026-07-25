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

private func collectDescendantEntities(
    entityId: EntityID,
    matches: (EntityID) -> Bool,
    visited: inout Set<EntityID>
) -> [EntityID] {
    guard visited.insert(entityId).inserted else {
        return []
    }

    var result: [EntityID] = []
    if matches(entityId) {
        result.append(entityId)
    }

    guard let scenegraph = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        return result
    }

    for childId in scenegraph.children {
        result.append(contentsOf: collectDescendantEntities(entityId: childId, matches: matches, visited: &visited))
    }

    return result
}

private func resolveDescendantEntities(
    entityId: EntityID,
    matches: (EntityID) -> Bool
) -> [EntityID] {
    var visited: Set<EntityID> = []
    return collectDescendantEntities(entityId: entityId, matches: matches, visited: &visited)
}

private func resolveDescendantEntity(
    entityId: EntityID,
    matches: (EntityID) -> Bool
) -> EntityID? {
    resolveDescendantEntities(entityId: entityId, matches: matches).first
}

func resolveEntitiesWithAnimationComponent(entityId: EntityID) -> [EntityID] {
    resolveDescendantEntities(entityId: entityId) {
        scene.get(component: AnimationComponent.self, for: $0) != nil
    }
}

func resolveEntityWithAnimationComponent(entityId: EntityID) -> EntityID? {
    resolveEntitiesWithAnimationComponent(entityId: entityId).first
}

func resolveEntitiesForAnimationBinding(entityId: EntityID) -> [EntityID] {
    resolveDescendantEntities(entityId: entityId) {
        scene.get(component: SkeletonComponent.self, for: $0) != nil &&
            scene.get(component: RenderComponent.self, for: $0) != nil
    }
}

func resolveEntityForAnimationBinding(entityId: EntityID) -> EntityID? {
    resolveEntitiesForAnimationBinding(entityId: entityId).first
}

private func animationComponentsForEntityOrDescendants(entityId: EntityID) -> [(EntityID, AnimationComponent)] {
    let targetEntityIds = resolveEntitiesWithAnimationComponent(entityId: entityId)
    return targetEntityIds.compactMap { targetEntityId in
        guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
            return nil
        }
        return (targetEntityId, animationComponent)
    }
}

private func animationComponentsContainingClip(entityId: EntityID, name: String) -> [(EntityID, AnimationComponent, AnimationClip)] {
    animationComponentsForEntityOrDescendants(entityId: entityId).compactMap { targetEntityId, animationComponent in
        guard let animationClip = animationComponent.animationClips[name] else {
            return nil
        }
        return (targetEntityId, animationComponent, animationClip)
    }
}

func resolveAnimationBindingTargetEntities(entityId: EntityID) -> [EntityID] {
    let targetEntityIds = resolveEntitiesForAnimationBinding(entityId: entityId)
    return targetEntityIds.isEmpty ? [entityId] : targetEntityIds
}

private func hasAnyAnimationComponent(entityId: EntityID) -> Bool {
    resolveDescendantEntity(entityId: entityId) {
        scene.get(component: AnimationComponent.self, for: $0) != nil
    } != nil
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

        if animationPolicyAllowsPlayback(animationComponent) == false {
            continue
        }

        if isAnimationComponentPaused(entityId: entity) {
            continue
        }

        animationComponent.currentTime += deltaTime * animationComponent.playbackSpeed

        guard let animationClip = animationComponent.currentAnimation else { continue }

        let compiledClip = animationComponent.compiledClip(
            for: animationClip,
            skeleton: skeletonComponent.skeleton
        )
        animationComponent.sampler.sample(
            compiledClip,
            time: animationComponent.currentTime,
            duration: animationClip.duration,
            speed: animationClip.speed,
            into: &animationComponent.localPose
        )
        skeletonComponent.skeleton.updateWorldPose(
            from: animationComponent.localPose,
            localScales: compiledClip.restScales
        )

        // Update the skin for each mesh in the render component
        for index in renderComponent.mesh.indices {
            if let skin = renderComponent.mesh[index].skin {
                skin.updateJointMatrices(skeleton: skeletonComponent.skeleton)
            }
        }
    }
}

/// Resolves whether an animation component may advance this frame given its
/// per-entity policy. The global `AnimationSystem.isEnabled` toggle has
/// already been applied by the time the update loop runs (disabled swaps in
/// a dummy update), so `.inherit` and `.forceOn` both animate here; they
/// diverge once per-view control exists, where `.forceOn` overrides a
/// view-level pause and `.inherit` honors it.
func animationPolicyAllowsPlayback(_ animationComponent: AnimationComponent) -> Bool {
    switch animationComponent.policy {
    case .inherit, .forceOn:
        return true
    case .forceOff:
        return false
    }
}

/// Sets the animation policy for the entity (or its descendants that carry
/// an `AnimationComponent`, matching how the other animation APIs resolve
/// hierarchical assets).
public func setAnimationPolicy(entityId: EntityID, policy: AnimationPolicy) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.policy = policy
    }
}

public func getAnimationPolicy(entityId: EntityID) -> AnimationPolicy {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return .inherit
    }

    return animationComponent.policy
}

public func pauseAnimationComponent(entityId: EntityID, isPaused: Bool) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.pause = isPaused
    }
}

public func isAnimationComponentPaused(entityId: EntityID) -> Bool {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return true
    }

    return animationComponents.allSatisfy { _, animationComponent in
        animationComponent.pause
    }
}

public func changeAnimation(entityId: EntityID, name: String, withPause: Bool = false) {
    guard hasAnyAnimationComponent(entityId: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    let matchingComponents = animationComponentsContainingClip(entityId: entityId, name: name)
    guard matchingComponents.isEmpty == false else {
        handleError(.noAnimationClip, name, entityId)
        return
    }

    for (_, animationComponent, animationClip) in matchingComponents {
        animationComponent.currentAnimation = animationClip
        animationComponent.pause = withPause
    }
}

public func setAnimationPlaybackSpeed(entityId: EntityID, speed: Float) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    let clampedSpeed = max(0.0, speed)
    for (_, animationComponent) in animationComponents {
        animationComponent.playbackSpeed = clampedSpeed
    }
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
    let clipNames = animationComponentsForEntityOrDescendants(entityId: entityId)
        .flatMap { _, animationComponent in animationComponent.getAllAnimationClips() }
    return Array(Set(clipNames)).sorted()
}

public func removeAnimationClip(entityId: EntityID, animationClip: String) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.removeAnimationClip(animationClip: animationClip)
    }
}
