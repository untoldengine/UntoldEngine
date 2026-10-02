# Animation Pose Pipeline

Status: **shipped** — covers the full animation foundation and character
deformation stack: pose layers, physics pose, compute skinning, DQS/DDM, morph
targets, pose drivers, XPBD muscles, ML deformer, and motion-capture seams.

## Purpose

`Sources/UntoldEngine/Animation/` is a data-driven character animation
pipeline that replaced the engine's original "one clip, hard cuts, no
locomotion" skeletal animation with indexed, allocation-free clip sampling,
inertialized transitions, root motion, pose layering, two kinds of IK, motion
matching, and a physics-pose seam. It is built **in-engine**, not as a
pluggable external system — see *Extensibility* below for why.

This document describes the pose-production pipeline: turning clips (and,
optionally, motion matching or a physics plugin) into the per-frame joint pose
that gets composed into world space and uploaded to the skin. It does not
cover the post-skinning deformation stack (compute skinning variants, DQS/DDM,
morph targets, XPBD muscles, the ML deformer) — that lives downstream of this
pipeline's output and is documented separately in
[`muscleDeformation.md`](muscleDeformation.md).

## Runtime representation

**Pose buffer** (`PoseBuffer.swift`) — structure-of-arrays, local space,
indexed by skeleton joint index (same order as `Skeleton.jointPaths`):
translations (`[simd_float3]`) and rotations (`[simd_quatf]`). Scale is not
animated by the runtime format; rest-pose local scale is folded in when
matrices are built.

**Compiled clip** (`CompiledAnimationClip.swift`) — built once when a clip is
bound to a skeleton. The loader-facing `AnimationClip`'s string-path joint
lookups are resolved to skeleton-joint-index-aligned arrays exactly once, at
compile time (via `Skeleton.mapJoints`); joints the clip doesn't animate fall
back to the rest pose at compile time, so there's no per-frame dictionary-miss
handling. `AnimationComponent` lazily builds and caches `compiledClip(for:
skeleton:)` per clip name.

**Sampler** (`ClipSampler.swift`) — allocation-free, binary search with a
per-player cursor hint; consecutive frames advance monotonically so the hint
hits almost always.

## Per-frame pipeline

`updateAnimationSystem` (`Sources/UntoldEngine/Systems/AnimationSystem.swift`)
runs this sequence per entity, every frame, in this order:

1. **Motion matching** (if `animationComponent.motionMatching.isEnabled`) may
   switch the current clip/time before anything else samples it — it reads
   the goal trajectory and feature database and picks the best-matching
   clip/time for this frame. See `MotionMatching.swift`/`MotionDatabase.swift`
   and [`UsingMotionMatching.md`](../API/UsingMotionMatching.md).
2. **Sample** the compiled clip into `localPose` (raw, no transitions applied
   yet).
3. **Root motion** (`RootMotion.swift`) runs on the *raw* sampled pose, before
   transition offsets — deltas come straight from the clip; extracts the root
   joint's horizontal translation/yaw delta per frame, applies it to the
   entity transform, and removes it from the pose (vertical motion, pitch,
   and roll stay in the pose — a stumbling zombie still leans). Opt-in per
   entity via `setRootMotionEnabled`. See
   [`UsingRootMotion.md`](../API/UsingRootMotion.md).
4. **Inertialized transition** (`Inertialization.swift`) decays in real time
   (independent of playback speed) toward zero offset, blending the outgoing
   pose's offset on top of the incoming clip — no second clip is sampled
   after the transition frame, which is the point of inertialization over
   crossfade. Triggered by `changeAnimation(transitionHalflife:)`. See
   [`UsingAnimationTransitions.md`](../API/UsingAnimationTransitions.md).
5. **External pose** (`ExternalPose.swift`) overrides the animated rotations
   of whichever joints a motion-capture (or other external) source is
   driving, on top of the transitioned pose.
6. **Pose layer** (`PoseLayer.swift`) — one override clip, sampled on its own
   clock, whose local rotations replace those of a joint subset (given as
   subtree roots, e.g. both clavicles → the whole upper body). Layer clip
   switches crossfade over a halflife, and influence eases toward a target
   weight, so a posture change reads as a movement rather than a cut. Runs
   after the base clip's transition but before IK, so motion matching (which
   reads feet/hips) never sees it, and reach IK bends the layered arms. See
   [`UsingPoseLayers.md`](../API/UsingPoseLayers.md).
7. **Reach IK** (`ReachIK.swift`) — multi-chain IK (e.g. hand-to-target)
   applied after the pose layer.
8. **Foot IK** (`FootIK.swift`) — corrects the final pose by planting feet on
   real geometry (via a ground query), after root motion and transitions have
   settled the pose. Includes optional stance locking
   (`FootIKStanceLockSource`). See [`UsingFootIK.md`](../API/UsingFootIK.md).
9. **Physics pose** (`PhysicsPose.swift`) lands last, on the fully animated
   pose: for the joints it weights, a physics plugin's bodies win over every
   stage above. The animation's own local pose is captured aside first (via
   `Skeleton.captureAnimatedPose`) so a plugin driving its bodies toward the
   animation never chases its own already-blended result; it's restored after
   skinning (`restoreAnimatedLocalPose`) so pose history for the *next*
   frame's transitions/inertialization stays the animation's own, not the
   physics-blended one. See [`UsingPhysicsPose.md`](../API/UsingPhysicsPose.md).
10. **Compose** — `Skeleton.updateWorldPose(from:localScales:)` turns the
    final local pose into world-space joint matrices (hierarchy compose,
    including the inverse-bind multiply), matching the pre-pipeline
    `computeWorldPose` behavior exactly.
11. **Skin** — `Skin.updateJointMatrices(skeleton:)` per mesh in the render
    component. GPU skinning, shaders, and the skin buffer itself are
    unaffected by anything above; downstream deformation (compute skinning
    variants, DQS/DDM, morph targets, XPBD muscles, ML deformer) consumes this
    output — see [`muscleDeformation.md`](muscleDeformation.md).

## Extensibility: where the plugin seam is

A recurring question: should this live outside the engine as a plugin, with
the engine exposing only a minimal API — so a game could swap in a different
animation system later?

The realistic case is not "one game uses a different animation system"; it is
"one *scene* uses several at once": crowd characters on motion matching, props
on plain clip playback, a hero character with physics-driven joints. That
argues for a seam **per entity**, not a globally replaceable system. The
layering is:

```
┌────────────────────────────────────────────────────────┐
│ Controllers (pluggable, per entity)                    │
│   built-in clip player · motion matching ·             │
│   physics pose (external bodies) · motion capture      │
├────────────────────────────────────────────────────────┤
│ Pose machinery (engine-owned, this doc)                │
│   PoseBuffer · compiled clips · sampler ·              │
│   inertialization · root motion application ·          │
│   pose layer · reach/foot IK · hierarchy compose ·     │
│   skinning upload                                       │
└────────────────────────────────────────────────────────┘
```

The contract between the layers stays small: *given an entity and a delta
time, fill (or override part of) a `PoseBuffer` (local space), optionally
reporting a root-motion delta or taking over weighted joints*. Everything
below that line is machinery every controller needs and should not be
reimplemented per plugin; everything above it is strategy.

There is still no general-purpose public `AnimationPoseController` protocol —
each controller (motion matching, physics pose, external/motion-capture pose,
pose layer) is a dedicated built-in stage with its own public setup API
(`setMotionMatching`, `setPhysicsPose`, `setPoseLayerMask/Clip/Weight`, etc.)
rather than a registrable plugin type. Publishing a generic controller
protocol remains deferred until a concrete third-party use case needs it; the
cost of freezing the wrong API before a second independent implementation has
exercised it reliably still outweighs the convenience.

## What this pipeline does not do

- No layered/partial-body **state machines** — pose layer crossfades and
  inertialized transitions cover the cases this engine's consumers need
  without one.
- No new shaders or metallib changes from the pose pipeline itself; skinning
  consumes its output unchanged. (The separate deformation stack in
  `muscleDeformation.md` does add shaders/kernels, downstream of this.)
- No changes to the `.untold` format from the pose pipeline itself (motion
  matching's offline database builder and the muscle/ML-deformer work added
  their own format additions, documented in their own docs).

## See Also

- [`UsingAnimationSystem.md`](../API/UsingAnimationSystem.md) — basic clip
  playback and policy API
- [`UsingAnimationTransitions.md`](../API/UsingAnimationTransitions.md) —
  inertialized transitions
- [`UsingPoseLayers.md`](../API/UsingPoseLayers.md) — pose layer + reach IK API
- [`UsingFootIK.md`](../API/UsingFootIK.md) — foot IK API
- [`UsingRootMotion.md`](../API/UsingRootMotion.md) — root motion API
- [`UsingPhysicsPose.md`](../API/UsingPhysicsPose.md) — physics pose seam
- [`UsingMotionMatching.md`](../API/UsingMotionMatching.md) — motion matching
  API
- [`muscleDeformation.md`](muscleDeformation.md) — post-skinning deformation
  stack (compute skinning, DQS/DDM, morph targets, XPBD muscles, ML deformer)
