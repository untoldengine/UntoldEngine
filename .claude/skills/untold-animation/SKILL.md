---
name: untold-animation
description: Use when playing or switching skeletal animation clips on a rigged entity — loading clips, changing/pausing/speeding playback, eased clip-to-clip transitions, and per-entity/global animation enable policy. Triggers on "play this animation", "switch from idle to running", "pause the animation", "the clip pops when it switches", "freeze this character but keep others animating". Not for root motion, foot IK, pose layers/reach IK, motion matching, or physics-driven poses (see untold-animation-advanced), general mesh loading (see untold-entity-scene), or the physics backend itself (see untold-physics).
version: 0.1.0
---

# Playing Animations in Untold Engine

Covers the basic clip-playback workflow: loading clips onto a rigged entity, switching between them, and controlling whether an entity animates at all. All animation functions are free functions keyed by `EntityID` — there's no `AnimationController` object to reach for.

## 1. Load and play a clip

```swift
let redPlayer = createEntity()
setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "untold")
setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "untoldanim", name: "running")
changeAnimation(entityId: redPlayer, name: "running")
```

Load multiple clips on the same entity and switch by name:

```swift
setEntityAnimations(entityId: player, filename: "idle", name: "idle")
setEntityAnimations(entityId: player, filename: "running", name: "running")
changeAnimation(entityId: player, name: "idle")
// later:
changeAnimation(entityId: player, name: "running")
```

**Order matters**: the mesh must be loaded (and, for async loads, the completion handler fired) before calling `setEntityAnimations`/`changeAnimation` — see `UsageExamples.md`'s "Play an Animation" pattern, which nests all animation setup inside the `setEntityMeshAsync` completion block.

For **hierarchical/multi-mesh `.untold` assets**, call every animation API on the asset's load root, not on individual child meshes. The engine resolves the root to every skinned descendant and installs/applies the call on each one that has both a `SkeletonComponent` and a `RenderComponent` — this keeps split characters or multi-part rigs animating as one actor. Treat the load root as the only public animation handle.

## 2. Playback control

```swift
pauseAnimationComponent(entityId: player, isPaused: true)
pauseAnimationComponent(entityId: player, isPaused: false)
setAnimationPlaybackSpeed(entityId: player, speed: 1.5)
removeAnimationClip(entityId: player, animationClip: "idle")
getAllAnimationClips(entityId: player)            // -> union of clip names on the entity's descendants
getAnimationPlaybackSpeed(entityId: player)        // -> speed from the first resolved animation component
```

All of these operate on the entity and its descendant animation components, same resolution rule as above.

## 3. Transitions between clips are automatic — don't hand-roll a crossfade

Every `changeAnimation` call eases into the new clip via **inertialization**: the engine captures the on-screen pose's offset from the incoming clip's first pose (plus its rate of change) and decays that offset to zero with a critically damped spring while only the new clip plays. This is cheaper than a crossfade (it doesn't sample both clips) and needs no blend-tree authoring — it works between any two clips with zero setup.

```swift
changeAnimation(entityId: player, name: "running")                              // default halflife 0.1s
changeAnimation(entityId: player, name: "dodge", transitionHalflife: 0.05)      // snappier
changeAnimation(entityId: player, name: "idle", transitionHalflife: 0.25)       // lazier settle
changeAnimation(entityId: player, name: "teleport", transitionHalflife: 0)      // exact hard cut
```

Halflife is the time for the pose offset to decay by half — not a fixed blend duration. A transition looks settled after roughly 4-6 halflives, so `0.1` reads as about a quarter-second ease. Avoid halflives above ~0.5s; they make a character feel like it's moving through syrup.

**Calling `changeAnimation` with the clip that's already playing is a safe no-op** (aside from `withPause`) — playback keeps its phase and any in-flight transition keeps decaying. A state machine that defensively reasserts "make sure this entity is playing idle" every frame will not restart the clip. To force a clip to replay from the beginning, switch to another clip first (or reset the component's time directly).

Rapid-fire `changeAnimation` calls are safe and compose — each new transition captures whatever pose (including any still-decaying offset) is currently displayed, so chains of quick switches stay continuous. A transition that begins before the entity has ever shown a pose (e.g. right after scene load) falls back to a hard cut — there's nothing to blend from. Switching clips on a **paused** (or policy `.forceOff`) entity captures the static displayed pose with zero velocity.

The same transition control is available from other entry points if you're using them:

```swift
MeshNode(name: "player", resource: "player.usdz").changeAnimation(name: "running", transitionHalflife: 0.05)
```

## 4. Controlling which entities animate

Two levels, with clear precedence — global wins over per-entity:

```swift
AnimationSystem.shared.isEnabled = false   // global kill switch; nothing animates regardless of per-entity policy

setAnimationPolicy(entityId: zombie, policy: .forceOff)   // freeze this one character
setAnimationPolicy(entityId: zombie, policy: .inherit)    // restore default (follows global)
setAnimationPolicy(entityId: zombie, policy: .forceOn)    // always animate when global is on
let policy = getAnimationPolicy(entityId: zombie)         // nil means descendants disagree — treat as "mixed"
```

`.forceOff` freezes the entity's playback clock **without** touching its play/pause state — switching back to `.inherit`/`.forceOn` resumes exactly where it left off. This makes `.forceOff` a cheap animation LOD lever: freeze distant characters and unfreeze them later without disturbing anything. Like the other APIs, setting policy on an asset root applies to every descendant with an `AnimationComponent`.

## 5. Common pitfalls

- Calling animation APIs before the mesh finishes loading (especially with `setEntityMeshAsync`) — nest them in the completion block.
- Calling animation APIs on a child mesh of a multi-part rig instead of the load root — the call may silently miss sibling parts.
- Expecting a fixed-duration blend from `transitionHalflife` — it's a decay constant, not a timer; don't build gameplay logic assuming the transition ends at an exact time.
- Reasserting `changeAnimation` with the already-playing clip name out of caution is fine — it does not restart playback.

Full reference: `docs/API/UsingAnimationSystem.md`, `docs/API/UsingAnimationTransitions.md`. For root motion, foot IK, pose layers, motion matching, and physics-driven poses, see `untold-animation-advanced`.
