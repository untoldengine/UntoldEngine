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
import simd

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

        // A paused clip still re-poses when an external pose drives it
        // (motion capture over a frozen base pose); time just stands still.
        let paused = isAnimationComponentPaused(entityId: entity)
        if paused, animationComponent.externalPose.isActive == false {
            continue
        }

        // Motion matching may switch the clip/time before this frame's
        // pose is sampled.
        if animationComponent.motionMatching.isEnabled {
            updateMotionMatching(
                entityId: entity,
                animationComponent: animationComponent,
                skeleton: skeletonComponent.skeleton,
                deltaTime: deltaTime
            )
        }

        if paused == false {
            animationComponent.currentTime += deltaTime * animationComponent.playbackSpeed
        }

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
            clipSpeed: animationClip.speed,
            deltaTime: deltaTime
        )

        // Transitions decay in real time, independent of playback speed.
        animationComponent.transition.apply(
            to: &animationComponent.localPose,
            deltaTime: deltaTime
        )
        // External pose sources (motion capture) override the animated
        // rotations of the joints they drive.
        applyExternalPose(
            state: &animationComponent.externalPose,
            skeleton: skeletonComponent.skeleton,
            pose: &animationComponent.localPose
        )
        // The override layer (an upper-body posture) and reach IK shape the
        // displayed pose before the feet are planted.
        applyPoseLayer(
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton,
            deltaTime: deltaTime
        )
        applyReachIK(
            entityId: entity,
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton,
            deltaTime: deltaTime
        )
        // Foot IK corrects the final pose: plant feet on real geometry
        // after root motion and transitions have settled the pose.
        applyFootIK(
            entityId: entity,
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton,
            deltaTime: deltaTime
        )
        // The physics pose lands last, on the fully animated pose, so for
        // the joints it weights the plugin's bodies win over every stage
        // above. The animation's own pose is kept aside first, so a plugin
        // driving its bodies toward the animation never chases its own
        // blended result.
        if animationComponent.physicsPose.isActive {
            skeletonComponent.skeleton.captureAnimatedPose(
                from: animationComponent.localPose,
                localScales: compiledClip.restScales
            )
        } else {
            skeletonComponent.skeleton.animatedPoseCaptured = false
        }
        applyPhysicsPose(
            entityId: entity,
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton,
            localScales: compiledClip.restScales
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

        // The physics pose was for the skin: the pose history stays the
        // animation's own.
        restoreAnimatedLocalPose(animationComponent: animationComponent)
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
        // Re-baseline root motion on the new clip (the first frame after a
        // switch contributes no delta) and crossfade the applied velocity
        // with the same halflife the pose blends with.
        animationComponent.rootMotion.beginVelocityBlend(halflife: transitionHalflife)
        animationComponent.rootMotion.resetHistory()
    }
}

/// Enables or disables root motion for the entity (or its descendants that
/// carry an `AnimationComponent`). While enabled, the root joint's
/// horizontal translation and yaw drive the entity transform instead of the
/// pose; vertical motion, pitch, and roll stay in the pose. By default the
/// skeleton's first parentless joint is the root; pass `rootJointPath` to
/// designate a different joint.
///
/// Modular assets resolve to several animation components; only the first
/// one drives the anchor's transform, so the deltas apply once no matter
/// how many skinned parts share the skeleton. Every component still grounds
/// its own pose.
public func setRootMotionEnabled(entityId: EntityID, enabled: Bool, rootJointPath: String? = nil) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (index, (_, animationComponent)) in animationComponents.enumerated() {
        animationComponent.rootMotion.isEnabled = enabled
        animationComponent.rootMotion.rootJointPath = rootJointPath
        animationComponent.rootMotion.anchorEntity = entityId
        animationComponent.rootMotion.drivesAnchor = index == 0
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

/// Enables or disables stance locking for the entity's foot IK chains:
/// while a foot is planted the IK target pins to the world position where
/// it landed, absorbing slide; the lock releases when the foot lifts, with
/// a short catch-up decay. `source` says what counts as planted: the
/// displayed ankle's own speed (the default: catches slide baked into a
/// clip's root motion), or the playing clip's contact (`.clipContact`: a
/// foot the clip holds still stays pinned through a transition, the
/// root-velocity crossfade or the heading warp, and lets go only when the
/// clip lifts it). Requires foot IK chains to be configured and enabled.
public func setFootIKStanceLocking(entityId: EntityID, enabled: Bool, source: FootIKStanceLockSource = .displayedFoot) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        if enabled {
            precondition(
                animationComponent.footIK.maxLockDistance <= animationComponent.footIK.maxAdjustment,
                "Foot IK stance lock distance must not exceed maxAdjustment"
            )
        }
        animationComponent.footIK.stanceLockEnabled = enabled
        animationComponent.footIK.lockSource = source
        animationComponent.footIK.lockStates = []
        animationComponent.footIK.rawClip = nil
        animationComponent.footIK.rawAnkles = []
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

/// Configures the pose layer's joint subset: every joint at or under the
/// given paths (both clavicles, for the arms). Reconfiguring keeps the
/// layer's clip and weight. See `setPoseLayerClip`.
public func setPoseLayerMask(entityId: EntityID, rootJointPaths: [String]) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.poseLayer.maskRootPaths = rootJointPaths
        animationComponent.poseLayer.invalidateResolution()
    }
}

/// Plays the named clip on the pose layer: it loops on its own clock, and
/// the local rotations of the masked joints (`setPoseLayerMask`) follow it
/// by the layer's weight (`setPoseLayerWeight`) on top of whatever the
/// entity plays or motion-matches. The layer's previous clip fades out
/// over `transitionHalflife` (zero cuts); restating the current clip is a
/// no-op. The clip must be loaded on the entity.
public func setPoseLayerClip(entityId: EntityID, name: String, transitionHalflife: Float = defaultAnimationTransitionHalflife) {
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
        animationComponent.poseLayer.play(animationClip, halflife: transitionHalflife)
    }
}

/// Eases the pose layer's influence to `weight` — 0 leaves the base pose
/// untouched, 1 replaces the masked joints' rotations — over `halflife`.
public func setPoseLayerWeight(entityId: EntityID, weight: Float, halflife: Float = 0.2) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.poseLayer.targetWeight = min(max(weight, 0), 1)
        animationComponent.poseLayer.weightHalflife = max(halflife, 0)
        if halflife <= 0 {
            animationComponent.poseLayer.weight = animationComponent.poseLayer.targetWeight
        }
    }
}

/// Configures the arm chains reach IK bends toward a target
/// (`setReachIKTarget`). Chains whose joint paths do not exist in the
/// skeleton are ignored.
public func setReachIKChains(entityId: EntityID, chains: [ReachIKChainDescriptor]) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.reachIK.descriptors = chains
        animationComponent.reachIK.invalidateResolution()
    }
}

/// Points the reach chains at a world position: a hand lands on it within
/// reach and points at it beyond, the arm extended to `reach` of its
/// length. The influence eases to `weight` over `halflife`; a nil position
/// eases it back out.
public func setReachIKTarget(
    entityId: EntityID,
    worldPosition: simd_float3?,
    weight: Float = 1,
    halflife: Float = 0.25,
    reach: Float = 0.95
) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        if let worldPosition {
            animationComponent.reachIK.targetWorld = worldPosition
            animationComponent.reachIK.targetWeight = min(max(weight, 0), 1)
        } else {
            animationComponent.reachIK.targetWeight = 0
        }
        animationComponent.reachIK.halflife = max(halflife, 0)
        animationComponent.reachIK.reach = min(max(reach, 0.05), 1)
        if halflife <= 0 {
            animationComponent.reachIK.weight = animationComponent.reachIK.targetWeight
        }
    }
}

/// Per-chain multipliers on the reach influence, index-aligned with the
/// chains: 0 leaves that arm to the pose, 1 gives it the full influence —
/// one hand lunging while the other holds back.
public func setReachIKChainWeights(entityId: EntityID, weights: [Float]) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.reachIK.chainWeights = weights
    }
}

/// The skeleton the animation APIs act on for `entityId`: on the entity or
/// its first descendant that carries an `AnimationComponent`.
private func resolveAnimatedSkeleton(entityId: EntityID) -> Skeleton? {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let skeleton = scene.get(component: SkeletonComponent.self, for: targetEntityId)?.skeleton else {
        handleError(.noSkeletonComponent, entityId)
        return nil
    }
    return skeleton
}

/// The entity's skeleton — joint paths, parents and the model-space bind
/// pose — for a physics plugin to build a rig that maps onto it. Resolves
/// the skeleton on the entity or its first descendant that carries an
/// `AnimationComponent`, as the other animation APIs do. Nil when there is
/// no skeleton.
public func getSkeletonJointInfo(entityId: EntityID) -> SkeletonJointInfo? {
    guard let skeleton = resolveAnimatedSkeleton(entityId: entityId) else { return nil }
    return SkeletonJointInfo(
        jointPaths: skeleton.jointPaths,
        parentIndices: skeleton.parentIndices,
        bindModelTransforms: skeleton.bindTransform
    )
}

/// Model-space joint transforms of the displayed pose, in skeleton joint
/// order: what the last animation update composed (physics pose included),
/// or the bind pose before the first update. Model space is the entity's
/// space — the skin matrices carry no entity transform, the shader applies
/// it — so a joint's world transform is the entity's world transform times
/// its entry here. Nil when there is no skeleton.
public func getJointModelTransforms(entityId: EntityID) -> [simd_float4x4]? {
    guard let skeleton = resolveAnimatedSkeleton(entityId: entityId) else { return nil }
    return skeleton.displayedModelPose
}

/// Model-space joint transforms of the animation alone — the pose the last
/// update composed before the physics pose was blended in — in skeleton
/// joint order and model space like `getJointModelTransforms`, and equal
/// to it while no physics pose is active. A plugin drives its bodies
/// toward this pose: the displayed pose already carries the bodies' own
/// result, so aiming at it would only hold them where they are. Nil when
/// there is no skeleton.
public func getAnimatedJointModelTransforms(entityId: EntityID) -> [simd_float4x4]? {
    guard let skeleton = resolveAnimatedSkeleton(entityId: entityId) else { return nil }
    return skeleton.animatedModelPose
}

/// Hands in a pose from physics: one model-space transform and one weight
/// (0…1) per joint, in skeleton joint order, blended into the displayed
/// pose on every animation update after foot IK until `clearPhysicsPose`.
/// A weighted joint takes the physics rotation, slerped by its weight; it
/// also takes the physics translation (lerped) when it has no parent or
/// its parent's weight is 0 — the top of a physics-driven subtree — while
/// the joints below keep their animated bone offsets. Joints at weight 0
/// keep the animated pose relative to their (possibly physics-driven)
/// parent. Both arrays must hold exactly one entry per skeleton joint, or
/// the call is ignored.
///
/// The blend happens inside the animation update, so the pose is not
/// applied while the entity is paused (`pauseAnimationComponent`): a
/// paused entity keeps showing the last pose it composed.
public func setPhysicsPose(entityId: EntityID, jointModelTransforms: [simd_float4x4], jointWeights: [Float]) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (componentEntityId, animationComponent) in animationComponents {
        guard let skeleton = scene.get(component: SkeletonComponent.self, for: componentEntityId)?.skeleton,
              skeleton.jointPaths.count == jointModelTransforms.count,
              skeleton.jointPaths.count == jointWeights.count
        else {
            handleError(.physicsPoseJointCountMismatch, entityId)
            continue
        }
        // The transforms share the caller's storage; the weights are
        // clamped into storage kept from the previous call, so a plugin
        // feeding a pose every frame does not allocate here.
        animationComponent.physicsPose.modelTransforms = jointModelTransforms
        if animationComponent.physicsPose.weights.count != jointWeights.count {
            animationComponent.physicsPose.weights = jointWeights
        }
        for index in jointWeights.indices {
            animationComponent.physicsPose.weights[index] = min(max(jointWeights[index], 0), 1)
        }
        animationComponent.physicsPose.isActive = true
    }
}

/// Stops blending the physics pose in: the next animation update shows the
/// animated pose again.
public func clearPhysicsPose(entityId: EntityID) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.physicsPose.clear()
    }
}

/// Configures motion matching for the entity (or its descendants that
/// carry an `AnimationComponent`). The motion database is built lazily on
/// the first enabled update, from the clips loaded on the entity. Enable
/// root motion as well — the clips' own travel is what moves the entity.
public func setMotionMatching(entityId: EntityID, descriptor: MotionMatchingDescriptor) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.motionMatching.descriptor = descriptor
        animationComponent.motionMatching.anchorEntity = entityId
        animationComponent.motionMatching.reset()
    }
}

/// Builds the motion database now rather than on the first enabled update,
/// so enabling motion matching later — say, handing a character over from
/// a scripted idle — does not stall that frame. Needs a descriptor and the
/// clips already loaded; a no-op once the database exists.
public func prepareMotionMatching(entityId: EntityID) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (componentEntityId, animationComponent) in animationComponents {
        guard animationComponent.motionMatching.database == nil,
              let descriptor = animationComponent.motionMatching.descriptor,
              let skeletonComponent = scene.get(component: SkeletonComponent.self, for: componentEntityId)
        else { continue }
        buildMotionDatabase(
            animationComponent: animationComponent,
            skeleton: skeletonComponent.skeleton,
            descriptor: descriptor
        )
        // Search on the first enabled update, as the lazy path does.
        animationComponent.motionMatching.searchClock = descriptor.searchInterval
    }
}

public func setMotionMatchingEnabled(entityId: EntityID, enabled: Bool) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.motionMatching.isEnabled = enabled
        if animationComponent.motionMatching.anchorEntity == .invalid {
            animationComponent.motionMatching.anchorEntity = entityId
        }
    }
}

public func isMotionMatchingEnabled(entityId: EntityID) -> Bool {
    let targetEntityId = resolveEntityWithAnimationComponent(entityId: entityId) ?? entityId
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId) else {
        handleError(.noAnimationComponent, entityId)
        return false
    }

    return animationComponent.motionMatching.isEnabled
}

/// States the world-space goal motion matching should steer toward —
/// typically the steering system's desired velocity. `desiredFacing` nil
/// faces along the desired velocity.
public func setMotionMatchingGoal(
    entityId: EntityID,
    desiredVelocity: simd_float3,
    desiredFacing: simd_float3? = nil
) {
    let animationComponents = animationComponentsForEntityOrDescendants(entityId: entityId)
    guard animationComponents.isEmpty == false else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    for (_, animationComponent) in animationComponents {
        animationComponent.motionMatching.desiredVelocity = desiredVelocity
        animationComponent.motionMatching.desiredFacing = desiredFacing
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
func beginAnimationTransition(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    to clip: AnimationClip,
    halflife: Float,
    targetTime: Float = 0
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

    // Sample the incoming clip at its target time and one small step
    // later to estimate its initial velocity. The component sampler
    // rebinds to the new clip here, which it would do next frame anyway.
    let velocityStep: Float = 1.0 / 60.0
    animationComponent.sampler.sample(
        compiledClip,
        time: targetTime,
        duration: clip.duration,
        speed: clip.speed,
        into: &animationComponent.transition.scratchTarget
    )
    animationComponent.sampler.sample(
        compiledClip,
        time: targetTime + velocityStep,
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
