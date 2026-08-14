# Animation Pose Layer

Status: **design — pending review**
Branch: `feature/animation_pose_layer`

## Purpose

This document specifies the first milestone (M1) of the data-driven character
animation effort: a runtime **pose layer** that upgrades the engine's skeletal
animation from "one clip, hard cuts, no locomotion" to a foundation that
supports motion matching and, later, learned controllers.

The overall roadmap (see *Context* below) is:

| Milestone | Deliverable |
|---|---|
| **M1 (this doc)** | Indexed pose representation, allocation-free clip sampling, inertialized transitions, root motion |
| M2 | Two-bone foot IK using the existing ray-picking systems |
| M3 | Motion matching: feature database, nearest-neighbour search, trajectory queries from `SteeringSystem` |
| M4 | Demo: AI character locomoting over real terrain on visionOS with no animation state machine |
| Later | Learned Motion Matching (network compression of the database); physics-based controllers |

M1 is valuable on its own even if nothing after it ships: every consumer of
`changeAnimation` gets smooth transitions, and locomotion clips stop sliding.

## Context: what exists today

- `Skeleton` (`Sources/UntoldEngine/Mesh/Skeleton.swift`) stores parallel
  arrays of `simd_float4x4` keyed by joint **string paths**.
- `AnimationClip.jointAnimation` is a `[String: Animation]` dictionary; every
  joint lookup, every frame, hashes a string path.
- `Animation.interpolateKeyframes` builds a `(previous, next)` tuple **array
  per joint per channel per frame** and linear-scans it — an allocation and an
  O(keys) walk in the hottest loop of the system.
- `changeAnimation` swaps `currentAnimation` with an instant pop; `currentTime`
  is not even reset, so the new clip starts at an arbitrary phase.
- Root joint translation is baked into the pose: a walk clip drags the mesh
  away from the entity transform, then snaps back on loop
  (`updateWorldPose` wraps with `fmod`).
- The per-skin joint `MTLBuffer` is single-buffered and CPU-written while
  earlier frames may still read it (contrast `TripleBuffer.swift` used for
  per-mesh uniforms).

None of this matters at "one idle clip per entity". All of it matters when a
controller samples multiple clips per frame and transitions constantly.

## Design

Four pieces, deliberately layered so each lands as its own PR with tests.

### 1. Indexed pose representation + compiled clips

New directory `Sources/UntoldEngine/Animation/`.

**Pose buffer** — structure-of-arrays, local space, indexed by skeleton joint
index (same order as `Skeleton.jointPaths`):

```swift
struct PoseBuffer {
    var translations: [simd_float3]   // local, per joint
    var rotations: [simd_quatf]       // local, per joint
    // scale is not animated by the runtime format; the rest-pose local
    // scale is folded in when matrices are built (matches current
    // AnimationClip.getPose behavior).
}
```

Local quaternions + translations are the canonical runtime representation.
Matrices are derived at the end of the frame; nothing blends matrices. (The 6D
rotation representation from the research plan is a *network I/O* format for
M3+/ML; it does not appear in the runtime.)

**Compiled clip** — built once when a clip is bound to a skeleton:

```swift
final class CompiledAnimationClip {
    let name: String
    let duration: Float
    // Per skeleton-joint channel, index-aligned with Skeleton.jointPaths.
    // Joints the clip does not animate fall back to the rest pose at
    // compile time — no per-frame dictionary miss handling.
    let rotationTimes: [[Float]]      // per joint, sorted
    let rotationValues: [[simd_quatf]]
    let translationTimes: [[Float]]
    let translationValues: [[simd_float3]]
    // Root motion metadata (section 3)
    let rootDisplacementPerLoop: simd_float3
    let rootYawPerLoop: Float
}
```

The string-path → index resolution happens exactly once, at compile time,
using the existing `Skeleton.mapJoints`. The existing `AnimationClip` remains
the loader-facing type; `AnimationComponent` gains a lazily-built
`compiledClips: [String: CompiledAnimationClip]` cache keyed by clip name.

**Sampler** — allocation-free, binary search with a per-player cursor hint
(consecutive frames advance monotonically, so the hint hits almost always):

```swift
struct ClipSampler {
    var cursor: [Int]   // per-joint last keyframe index hint
    mutating func sample(_ clip: CompiledAnimationClip, at time: Float,
                         into pose: inout PoseBuffer)
}
```

`Skeleton` gains one method to close the loop with the existing renderer:

```swift
func updateWorldPose(from localPose: PoseBuffer)
```

which composes the hierarchy exactly like the current `computeWorldPose`
(including the inverse-bind multiply) and writes `currentPose`. GPU skinning,
shaders, and `Skin.updateJointMatrices` are untouched.

**Compatibility gate:** unit tests sample the same clip through the old path
(`AnimationClip.getPose`) and the new path and assert per-joint equality
within epsilon. The old sampling code is removed only after that test is
green; `AnimationSystem.update` then routes through the compiled path
unconditionally.

### 2. Inertialized transitions

Replaces nothing (there is no blending today) and does not introduce
crossfades. On `changeAnimation`, instead of popping:

1. Sample the **outgoing** state one last time (pose + per-joint velocity,
   estimated by finite difference over the previous frame).
2. Compute the per-joint **offset** from the incoming clip's pose at its
   start time: translation offset as a vector, rotation offset as a rotation
   vector (quaternion log), plus offset velocities.
3. Each frame, decay the offset toward zero with a critically damped
   spring (Daniel Holden's inertialization formulation, halflife-parameterized)
   and add it on top of the incoming clip's sampled pose.

State lives in a `PoseTransition` struct on `AnimationComponent` (offset
buffers + halflife + remaining flag). Cost: two `PoseBuffer`s per entity and
a few fused multiply-adds per joint — no second clip is sampled after the
transition frame, which is the point of inertialization vs. crossfade.

Public API — extend, don't break:

```swift
public func changeAnimation(entityId: EntityID, name: String,
                            transitionHalflife: Float = 0.1,
                            withPause: Bool = false)
```

`transitionHalflife: 0` reproduces today's hard cut. `currentTime` resets to
0 on change (bug fix; noted in the PR).

### 3. Root motion

Opt-in per entity (default off — existing content behaves exactly as today):

```swift
public func setRootMotionEnabled(entityId: EntityID, enabled: Bool, rootJointPath: String? = nil)
```

When enabled, for the designated root joint (the first joint with a `nil`
parent, overridable by joint path):

- The sampler extracts the root's **horizontal translation delta and yaw
  delta** per frame in character space. Loop wrap is handled with the
  precomputed `rootDisplacementPerLoop` / `rootYawPerLoop`: when the clip
  time wraps, the delta is `(end→loopEnd) + (loopStart→newTime)` rather than
  the raw negative jump.
- Those deltas are applied to the entity via the existing
  `translateBy` / `rotateBy` (`TransformSystem`), rotated into world space by
  the entity's current orientation.
- The root joint's horizontal translation and yaw are **removed from the
  pose** (vertical motion, pitch and roll stay — a stumbling zombie leans).

This runs inside `AnimationSystem.update`, which executes before
`PhysicsSystem` in the frame (`UntoldEngine.swift` update order), so physics
and steering see the post-root-motion transform in the same frame.

### 4. Joint buffer frames-in-flight fix

Independent `[Patch]` PR: `Skin.jointTransformsBuffer` becomes a ring of
`totalPerMeshUniformBuffers()` buffers indexed by the frame-in-flight counter,
mirroring the existing per-mesh uniform pattern, with the bind site in
`RenderPasses.swift` selecting the current slot. Today's single buffer is a
latent CPU-write/GPU-read race that becomes visible tearing the moment poses
change every frame on multiple entities.

## Extensibility: where the plugin seam is

A recurring question: should this live outside the engine as a plugin, with
the engine exposing only a minimal API — so a game could swap in a different
animation system later?

The realistic future is not "one game uses a different animation system"; it
is "one *scene* uses several at once": crowd characters on motion matching,
props on plain clip playback, a hero character on a learned controller. That
argues for a seam **per entity**, not a globally replaceable system. The
layering is:

```
┌────────────────────────────────────────────────────────┐
│ Controllers (pluggable, per entity)                    │
│   built-in clip player · motion matching (M3) · ML     │
├────────────────────────────────────────────────────────┤
│ Pose machinery (engine-owned, this doc)                │
│   PoseBuffer · compiled clips · sampler ·              │
│   inertialization · root motion application ·          │
│   hierarchy compose · skinning upload                  │
└────────────────────────────────────────────────────────┘
```

The contract between the layers is small: *given an entity and a delta time,
fill a `PoseBuffer` (local space) and optionally report a root-motion delta*.
Everything below that line is machinery every controller needs and should not
be reimplemented per plugin; everything above it is strategy.

Consequences for M1:

- The machinery is built **in-engine** (as decided), but `AnimationSystem`'s
  update is structured as *evaluate controller → inertialize → apply root
  motion → compose → skin* from the start, with the existing clip player as
  the built-in controller. No public protocol yet.
- The controller interface (`PoseBuffer` + an `AnimationPoseController`
  protocol + registration) is **published only when M3 exists** — motion
  matching is the first real external consumer, and freezing a public API
  before a second implementation has exercised it reliably produces the
  wrong API. Publishing it is a small `[Feature]` PR at that point; under
  the repo's auto-semver it must be additive.
- Until then nothing new is `public`; the engine's API surface (and semver)
  is untouched by PRs ①–②.

## What M1 does not do

- No motion database, feature vectors, or nearest-neighbour search (M3).
- No IK (M2).
- No layered/partial-body blending, no state machines — the target
  architecture (motion matching) does not need them.
- No new shaders or metallib changes; skinning stays as-is.
- No changes to the `.untold` format or the Blender exporter. (M3 will need
  an offline motion-database builder that consumes `.untold` clips; format
  additions are deferred until then.)

## PR breakdown

Per the contribution guidelines (one feature per PR, tests required,
how-to guide for new systems):

1. `[Feature]` Compiled clips + allocation-free pose sampling — internal,
   behavior-identical, gated by the old-vs-new equality test.
2. `[Patch]` Joint transform buffer frames-in-flight ring.
3. `[Feature]` Inertialized animation transitions — public API change,
   how-to guide (`docs/API/UsingAnimationTransitions.md`), demo snippet.
4. `[Feature]` Root motion — public API, how-to guide, test with a synthetic
   clip whose root displacement is known analytically.

## Testing

- **Equality gate:** old sampler vs. compiled sampler, all clips in the test
  assets, epsilon 1e-5.
- **Sampler correctness:** synthetic clips with hand-computed keyframe values
  (mid-key interpolation, exact-key hits, wrap, single-key channels, unanimated
  joints preserving rest translation/scale).
- **Inertialization:** offset decays monotonically to zero within ~4×
  halflife; zero halflife reproduces a hard cut; pose is continuous (C0) at
  the transition frame by construction.
- **Root motion:** synthetic 4-key straight-walk clip — accumulated entity
  displacement over exactly N loops equals N × known displacement; no snap at
  the wrap frame.
- **Performance guard:** the sampler's buffers must not grow after warm-up
  (steady-state sampling reuses `PoseBuffer` and scratch storage), plus a
  `measure`-based regression test over many sequential frames.
