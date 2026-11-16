---
name: untold-animation-advanced
description: Use for procedural/advanced animation on top of clip playback — root motion (letting a clip's own travel move the entity), foot IK (planting feet on uneven terrain), pose layers + reach IK (giving the upper body its own posture and aiming at a target), motion matching (goal-driven animation with no state machine), and physics-driven poses (ragdolls, powered limbs). Triggers on "feet slide on slopes", "the character doesn't move with the walk clip", "make the arms reach toward the player", "animate with no state machine", "blend in a ragdoll". Not for basic clip loading/switching (see untold-animation), the physics backend itself (see untold-physics), or general mesh/entity setup (see untold-entity-scene).
version: 0.1.0
---

# Advanced and Procedural Animation in Untold Engine

These systems compose on top of basic clip playback (see `untold-animation` first). They run in a fixed pipeline each animation update: **clip sample → root motion extraction → inertialized transition → pose layer blend → reach IK → foot IK → physics pose blend → skin**. Each stage only sees the result of the ones before it — e.g. motion matching reads feet/hips before any of this and never sees a pose layer or physics pose, so a layered character matches exactly like an unlayered one.

## 1. Root motion — let the clip's own travel move the entity

Without it, a locomotion clip whose root joint travels drags the mesh away from the entity transform and snaps back on loop. With it, the root joint's horizontal movement/turning is extracted each frame, applied to the entity transform via `translateBy`, and the displayed pose is grounded in place.

```swift
setEntityAnimations(entityId: zombie, filename: "shamble", withExtension: "untold", name: "shamble")
setRootMotionEnabled(entityId: zombie, enabled: true)
changeAnimation(entityId: zombie, name: "shamble")

// non-default traveling joint:
setRootMotionEnabled(entityId: zombie, enabled: true, rootJointPath: "root/hips")
isRootMotionEnabled(entityId: zombie)
```

Vertical motion, pitch, and roll stay in the pose (a crouch still lowers the character) — only horizontal translation and yaw are extracted and grounded. Root motion runs inside the animation update, before physics/custom systems, so your steering/gameplay code sees the post-root-motion transform the same frame. It composes with inertialized transitions: the applied travel itself crossfades velocity between clips over the same halflife, so a walk-to-sprint switch accelerates in step with the legs instead of snapping speed (which would skate the feet).

Pitfalls: yaw is extracted about +Y, so clips that turn >180° in one loop are ambiguous at the wrap — split them. Switching clips re-baselines extraction (first frame after `changeAnimation` contributes no delta). Gameplay code (steering, knockback) can still move the entity — root motion adds deltas, it doesn't overwrite the transform. On hierarchical assets, deltas apply to the entity you called `setRootMotionEnabled` on (your steering handle), not the skinned child.

## 2. Foot IK — plant feet on real geometry

Clips are authored against a flat ground; foot IK samples real geometry under each foot and bends the leg (closed-form two-bone solver, hip+knee, no iteration) so the foot lands correctly.

```swift
setFootIKChains(entityId: zombie, chains: [
    FootIKChainDescriptor(hipPath: "root/hips/thigh_l", kneePath: "root/hips/thigh_l/calf_l", anklePath: "root/hips/thigh_l/calf_l/foot_l"),
    FootIKChainDescriptor(hipPath: "root/hips/thigh_r", kneePath: "root/hips/thigh_r/calf_r", anklePath: "root/hips/thigh_r/calf_r/foot_r"),
])
setFootIKEnabled(entityId: zombie, enabled: true)
```

Default ground source is a downward scene ray pick (skips the character itself). Plug in a cheaper/authoritative source (heightfield, navmesh, physics query) instead:

```swift
setFootIKGroundQuery(entityId: zombie) { worldPosition in
    guard let height = myTerrain.height(atX: worldPosition.x, z: worldPosition.z) else { return nil }
    return FootIKGroundSample(height: height)
}
// pass nil to restore the default ray probe
```

Corrections beyond 0.5m are ignored (treated as a ledge/bad probe, not ground). Chains with joint paths that don't exist in the skeleton are dropped silently — double check paths against the rig if a leg doesn't respond. Foot IK adjusts legs only; it does not lower the pelvis, so a downhill foot beyond reach clamps at full leg extension.

**Stance locking** absorbs residual slide (root motion can only match one foot at a time, so the trailing foot drifts):

```swift
setFootIKStanceLocking(entityId: player, enabled: true, source: .clipContact)
```

`.displayedFoot` (default) watches the displayed ankle's world speed. `.clipContact` watches the clip's own ankle motion — preferred for motion-matched characters (drift fell from 12 to 4 cm/s in testing); it stays pinned through inertialized jumps and heading warps, releasing only when the clip itself lifts the foot.

## 3. Pose layers + reach IK — give the upper body its own posture, then aim it

Motion matching/clip playback decides the legs; it doesn't decide the arms. A **pose layer** takes a joint subtree away from the base clip and gives it a second, independently-looping clip, blended in by weight. **Reach IK** then bends the arms toward a world target.

```swift
setPoseLayerMask(entityId: zombie, rootJointPaths: [
    "/root/pelvis/spine_01/spine_02/spine_03/clavicle_l",
    "/root/pelvis/spine_01/spine_02/spine_03/clavicle_r",
])
setPoseLayerClip(entityId: zombie, name: "arms_raised", transitionHalflife: 0.4)
setPoseLayerWeight(entityId: zombie, weight: 1, halflife: 0.3)   // 0 = base clip owns the joints, 1 = layer owns them fully

setReachIKChains(entityId: zombie, chains: [
    ReachIKChainDescriptor(shoulderPath: ".../upperarm_l", elbowPath: ".../lowerarm_l", handPath: ".../hand_l"),
    ReachIKChainDescriptor(shoulderPath: ".../upperarm_r", elbowPath: ".../lowerarm_r", handPath: ".../hand_r"),
])
setReachIKTarget(entityId: zombie, worldPosition: playerHead, weight: 1, halflife: 0.25)
setReachIKTarget(entityId: zombie, worldPosition: nil)                       // let go
setReachIKChainWeights(entityId: zombie, weights: [0.9, 0.2])                // per-arm influence multiplier
```

Within reach the hand lands on the target; beyond reach the target is pulled in to `reach` (default 95%) of the chain length, so the arm points without locking the elbow. The elbow keeps the bend plane the posture clip already gives it.

An entity has **one** shared reach influence (`weight`/`halflife`/`reach`) — whichever of `setReachIKTarget`/`setReachIKChainTargets` runs last in a frame wins for every chain; pass the same values to both and use `setReachIKChainWeights` for per-chain differences. One pose layer per entity (masks are subtrees — include the clavicles for a whole arm, leave the spine to locomotion). Reach IK aims the whole chain but doesn't orient the hand itself — align it yourself or author it in the posture clip if a palm needs to face a surface.

## 4. Motion matching — goal-driven animation, no state machine

Instead of authoring transitions, you state a desired velocity/facing every frame; the engine searches loaded clip frames for the best match and eases to it.

```swift
setEntityAnimations(entityId: zombie, filename: "locomotion", withExtension: "untold", name: "locomotion")
setRootMotionEnabled(entityId: zombie, enabled: true)   // required — motion matching relies on clip travel

setMotionMatching(entityId: zombie, descriptor: MotionMatchingDescriptor(
    leftFootPath: "root/hips/thigh_l/calf_l/foot_l",
    rightFootPath: "root/hips/thigh_r/calf_r/foot_r"
))
setMotionMatchingEnabled(entityId: zombie, enabled: true)

// every frame, typically from steering:
let toPlayer = getPosition(entityId: player) - getPosition(entityId: zombie)
let desired = simd_normalize(simd_float3(toPlayer.x, 0, toPlayer.z)) * zombieSpeed
setMotionMatchingGoal(entityId: zombie, desiredVelocity: desired)
```

No `changeAnimation` calls — adding a clip to the entity adds it to the vocabulary. **Coverage beats quantity**: the search can only pick frames that exist, so include starts, stops, turns, and speed variations, not just a straight walk loop. Tune with weights (`MotionMatchingWeights`) — raise `trajectoryPosition`/`trajectoryDirection` for goal responsiveness, raise foot weights for pose fidelity. `minPlayTime` (default 0.3s) stops a systematically-winning frame from treadmilling playback on one spot. Name non-looping clips (starts, stops, pivots) in `oneShotClipNames` — a looping database wrongly predicts a one-shot clip's future into its own beginning.

Combine with foot IK for terrain and `.forceOff` animation policy as a distance LOD lever (stop calling `setMotionMatchingGoal` for frozen characters too). Add `leftHandPath`/`rightHandPath` to the descriptor to factor arm position into the match, or remove the arms from the clips entirely via a pose layer instead.

## 5. Physics pose — hand joints to a physics rig

A physics plugin (ragdoll, powered limb, simulated arm) can take over any joint subset. The engine composes poses and does skinning; the plugin owns simulation only. This stage runs **after** clip sample, root motion, transitions, pose layer, reach IK, and foot IK — physics wins for the joints it weights. See `untold-physics` for the physics backend itself; this is only the animation-side seam.

```swift
// 1. read the skeleton once to build the rig
guard let joints = getSkeletonJointInfo(entityId: zombie) else { return }

// 2. each frame: drive the rig from the animated pose (kinematic targets / motors)
if let model = getAnimatedJointModelTransforms(entityId: zombie) {
    for (index, transform) in model.enumerated() {
        rig.setKinematicTarget(index, world * transform)
    }
}
// or seed a ragdoll from the displayed pose (physics pose included):
// getJointModelTransforms(entityId:)

// 3. after the simulation step, hand the result back with a per-joint weight
setPhysicsPose(entityId: zombie, jointModelTransforms: pose, jointWeights: weights)
// and to hand the character back to the animation:
clearPhysicsPose(entityId: zombie)
```

Both arrays must have exactly one entry per skeleton joint in `jointPaths` order — a mismatched call is ignored and logged. Weight 1 on every joint is a full ragdoll; weight 1 on one arm is a limb that swings from a grab; easing a weight from 1 to 0 is a get-up. A joint at the **top of a physics-driven subtree** (no parent, or parent weight 0) blends both rotation and translation; joints below it keep their animated bone offsets, so the rig never stretches/tears the skin — only rotations follow further down. Ease weights over a few frames when handing a limb to/from physics; a weight jump reads as a cut, same as a pose-layer weight.

A `changeAnimation`/motion-matching jump while a physics pose is active inertializes from the **animation's** own pose history, not the physics result — a powered ragdoll never drags the animation after itself. Getting up gracefully is the game's job: read the displayed pose, hand it back as a physics pose, fade the weights out.

## 6. Common pitfalls across these systems

- Enabling motion matching without root motion — it relies on clip travel to move the entity.
- Forgetting coverage clips (turns, stops, speed variants) for motion matching — a single loop will visibly slide through turns.
- Jumping a pose-layer or reach-IK weight instead of easing it — reads as a pop just like a bad transition.
- Driving physics from `getJointModelTransforms` (post-physics-blend pose) when you meant to drive from `getAnimatedJointModelTransforms` (pre-blend) — the former already contains the physics result, so aiming at it just holds bodies where they are.
- Mismatched array counts to `setPhysicsPose` — silently ignored and logged, not a crash; check logs if a physics pose seems to do nothing.

Full reference: `docs/API/UsingRootMotion.md`, `docs/API/UsingFootIK.md`, `docs/API/UsingPoseLayers.md`, `docs/API/UsingMotionMatching.md`, `docs/API/UsingPhysicsPose.md`. For basic clip playback, see `untold-animation`.
