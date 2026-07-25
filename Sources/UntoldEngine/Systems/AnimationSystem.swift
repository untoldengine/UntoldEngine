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

        // Preserve the pose displayed last frame (post-transition offsets)
        // for velocity estimation when the next transition begins. Swapping
        // the buffers avoids any copy; the sampler fully overwrites
        // localPose below.
        swap(&animationComponent.previousPose, &animationComponent.localPose)
        animationComponent.hasPreviousPose = animationComponent.hasSampledPose

        animationComponent.sampler.sample(
            compiledClip,
            time: animationComponent.currentTime,
            duration: animationClip.duration,
            speed: animationClip.speed,
            into: &animationComponent.localPose
        )

        // Root motion runs on the raw sampled pose, before transition
        // offsets: deltas come from the clip, transitions blend grounded
        // poses.
        applyRootMotion(
            entityId: entity,
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton,
            compiledClip: compiledClip,
            clipDuration: animationClip.duration,
            clipSpeed: animationClip.speed
        )

        // Transitions decay in real time, independent of playback speed.
        animationComponent.transition.apply(
            to: &animationComponent.localPose,
            deltaTime: deltaTime
        )
        // Foot IK corrects the final pose: plant feet on real geometry
        // after root motion and transitions have settled the pose.
        applyFootIK(
            entityId: entity,
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton
        )

        animationComponent.hasSampledPose = true
        animationComponent.lastSampleDeltaTime = deltaTime

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

/// Returns the policy shared by the entity's (or its descendants')
/// animation components, or nil when they disagree — mirroring how
/// `setAnimationPolicy` applies to every descendant. A nil result means a
/// policy was set on an individual child rather than the asset root;
/// callers building UI or LOD logic on top should treat it as "mixed"
/// rather than assuming any single value.
public func getAnimationPolicy(entityId: EntityID) -> AnimationPolicy? {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard let firstPolicy = animationComponents.first?.1.policy else {
        handleError(.noAnimationComponent, entityId)
        return nil
    }

    let allAgree = animationComponents.allSatisfy { _, animationComponent in
        animationComponent.policy == firstPolicy
    }
    return allAgree ? firstPolicy : nil
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

/// Default halflife for inertialized clip switches, shared by every public
/// entry point (`changeAnimation`, the node builder, USC `.playAnimation`).
public let defaultAnimationTransitionHalflife: Float = 0.1

/// Switches the entity to the named clip.
///
/// With a positive `transitionHalflife`, the switch is inertialized: the
/// offset between the pose on screen and the incoming clip is captured and
/// decayed to zero with a critically damped spring, so the character eases
/// into the new clip instead of popping. `transitionHalflife: 0` reproduces
/// a hard cut. Playback restarts at the beginning of the new clip.
///
/// Calling this with the clip that is already playing is a no-op apart from
/// the `withPause` flag: playback keeps its phase and any in-flight
/// transition keeps decaying, so callers may reassert the current clip
/// every frame without restarting it.
public func changeAnimation(entityId: EntityID, name: String, transitionHalflife: Float = defaultAnimationTransitionHalflife, withPause: Bool = false) {
    guard hasAnyAnimationComponent(entityId: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    let matchingComponents = animationComponentsContainingClip(entityId: entityId, name: name)
    guard matchingComponents.isEmpty == false else {
        handleError(.noAnimationClip, name, entityId)
        return
    }

    for (targetEntityId, animationComponent, animationClip) in matchingComponents {
        guard animationComponent.currentAnimation !== animationClip else {
            animationComponent.pause = withPause
            continue
        }
        beginAnimationTransition(
            entityId: targetEntityId,
            animationComponent: animationComponent,
            to: animationClip,
            halflife: transitionHalflife
        )
        animationComponent.currentAnimation = animationClip
        animationComponent.currentTime = 0
        animationComponent.pause = withPause
        // Re-baseline root motion on the new clip; the first frame after a
        // switch contributes no delta.
        animationComponent.rootMotion.resetHistory()
    }
}

/// Enables or disables root motion for the entity (or its descendants that
/// carry an `AnimationComponent`). While enabled, the root joint's
/// horizontal translation and yaw drive the entity transform instead of the
/// pose; vertical motion, pitch, and roll stay in the pose. By default the
/// skeleton's first parentless joint is the root; pass `rootJointPath` to
/// designate a different joint.
public func setRootMotionEnabled(entityId: EntityID, enabled: Bool, rootJointPath: String? = nil) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.rootMotion.isEnabled = enabled
        animationComponent.rootMotion.rootJointPath = rootJointPath
        animationComponent.rootMotion.anchorEntity = entityId
        animationComponent.rootMotion.resolvedRootIndex = nil
        animationComponent.rootMotion.resetHistory()
    }
}

/// Enables or disables foot IK for the entity (or its descendants that
/// carry an `AnimationComponent`). Configure the leg chains first with
/// `setFootIKChains`.
public func setFootIKEnabled(entityId: EntityID, enabled: Bool) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.footIK.isEnabled = enabled
    }
}

public func isFootIKEnabled(entityId: EntityID) -> Bool {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return false
    }

    return animationComponent.footIK.isEnabled
}

/// Configures the leg chains foot IK operates on. Chains whose joint paths
/// do not exist in the skeleton are ignored.
public func setFootIKChains(entityId: EntityID, chains: [FootIKChainDescriptor]) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.footIK.descriptors = chains
        animationComponent.footIK.invalidateResolution()
    }
}

/// Overrides how foot IK samples the ground beneath each foot. Pass nil to
/// restore the default scene ray-pick probe.
public func setFootIKGroundQuery(entityId: EntityID, query: FootIKGroundQuery?) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.footIK.groundQuery = query
    }
}

public func isRootMotionEnabled(entityId: EntityID) -> Bool {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return false
    }

    return animationComponent.rootMotion.isEnabled
}

/// Captures inertialization offsets for a clip switch. Falls back to a hard
/// cut (no transition) when there is nothing to blend from: no clip playing,
/// no pose displayed yet, no skeleton, or a zero halflife.
private func beginAnimationTransition(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    to clip: AnimationClip,
    halflife: Float
) {
    guard halflife > 0,
          animationComponent.currentAnimation != nil,
          animationComponent.hasSampledPose,
          let skeleton = scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton
    else {
        animationComponent.transition.cancel()
        return
    }

    let compiledClip = animationComponent.compiledClip(for: clip, skeleton: skeleton)
    guard compiledClip.jointCount == animationComponent.localPose.jointCount else {
        animationComponent.transition.cancel()
        return
    }

    // Sample the incoming clip at its start and one small step later to
    // estimate its initial velocity. The component sampler rebinds to the
    // new clip here, which it would do on the next frame anyway.
    let velocityStep: Float = 1.0 / 60.0
    animationComponent.sampler.sample(
        compiledClip,
        time: 0,
        duration: clip.duration,
        speed: clip.speed,
        into: &animationComponent.transition.scratchTarget
    )
    animationComponent.sampler.sample(
        compiledClip,
        time: velocityStep,
        duration: clip.duration,
        speed: clip.speed,
        into: &animationComponent.transition.scratchTargetNext
    )

    // With root motion enabled the displayed pose is grounded, so the
    // incoming clip's samples must be grounded too — otherwise the captured
    // offset would reintroduce the horizontal root displacement.
    if animationComponent.rootMotion.isEnabled,
       let rootIndex = resolveRootMotionJointIndex(
           state: &animationComponent.rootMotion,
           skeleton: skeleton,
           compiledClip: compiledClip
       )
    {
        stripRootMotion(from: &animationComponent.transition.scratchTarget, rootIndex: rootIndex)
        stripRootMotion(from: &animationComponent.transition.scratchTargetNext, rootIndex: rootIndex)
    }

    // Copy the scratch poses out (COW, no allocation) so the mutating
    // begin() call does not overlap a read of the same property.
    let targetPose = animationComponent.transition.scratchTarget
    let targetNext = animationComponent.transition.scratchTargetNext

    // While playback is frozen (pause or .forceOff) the update loop stops
    // swapping pose history, so `previousPose`/`lastSampleDeltaTime` describe
    // motion from before the freeze. The pose actually on screen is static —
    // treat its velocity as zero instead of the stale history.
    let isFrozen = animationComponent.pause
        || animationPolicyAllowsPlayback(animationComponent) == false

    animationComponent.transition.begin(
        halflife: halflife,
        sourcePose: animationComponent.localPose,
        sourcePrevious: animationComponent.previousPose,
        hasSourcePrevious: animationComponent.hasPreviousPose && !isFrozen,
        sourceDeltaTime: animationComponent.lastSampleDeltaTime,
        targetPose: targetPose,
        targetNext: targetNext,
        targetDeltaTime: velocityStep
    )
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
