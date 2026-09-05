# Root Motion

## Introduction

A locomotion clip authored with its root joint traveling — a walk that
actually moves forward — normally drags the mesh away from the entity
transform and snaps back when the clip loops. **Root motion** inverts that:
the root joint's horizontal movement and turning are extracted from the
animation each frame and applied to the entity transform, and the pose is
grounded in place. The character moves through the world because its
animation says so.

## Why Use It

- **No foot sliding from mismatched speeds.** When code moves the entity at
  one speed and the clip's stride implies another, feet skate. With root
  motion, the entity moves exactly as far as the animation does.
- **No loop snap.** The travel accumulates on the entity; the clip's loop
  wrap is corrected with the clip's per-loop displacement.
- **Authoring stays in the DCC tool.** Turns, lunges, and stumbles move the
  character exactly as animated.

## Step-by-Step Implementation

Enable it per entity — by default it is off and everything behaves as
before:

```swift
setEntityAnimations(entityId: zombie, filename: "shamble", withExtension: "untold", name: "shamble")
setRootMotionEnabled(entityId: zombie, enabled: true)
changeAnimation(entityId: zombie, name: "shamble")
```

The skeleton's first parentless joint drives root motion. If your rig uses
a different traveling joint, designate it by path:

```swift
setRootMotionEnabled(entityId: zombie, enabled: true, rootJointPath: "root/hips")
```

Query or turn it off at any time:

```swift
if isRootMotionEnabled(entityId: zombie) {
    setRootMotionEnabled(entityId: zombie, enabled: false)
}
```

## What Happens Behind the Scenes

1. Each frame, the raw sampled pose's root translation and yaw are compared
   with the previous frame's. The horizontal delta (rotated into the
   entity's current orientation) is applied with `translateBy`, and the yaw
   delta with a rotation about the up axis.
2. When the clip loops, the wrapped-time jump is corrected with the clip's
   precomputed per-loop displacement and yaw, so there is no backward snap.
3. The pose's root joint is then grounded: horizontal translation zeroed
   and yaw removed. **Vertical motion, pitch, and roll stay in the pose** —
   a crouch still lowers the character, a stagger still leans it.
4. Root motion runs inside the animation update, before physics and custom
   systems, so steering and gameplay code see the post-root-motion
   transform in the same frame.

Inertialized transitions compose cleanly with root motion: transitions
blend grounded poses, so switching clips never teleports the character.
The applied travel is inertialized too — at a switch the entity's
velocity crossfades from the outgoing clip's to the incoming clip's
with the same halflife the pose blends with, so a walk-to-sprint switch
accelerates the character in step with its legs instead of snapping to
the new speed (which would skate the feet). A zero halflife remains an
exact hard cut.

## Tips and Best Practices

- Author locomotion clips with the root traveling at the real stride; root
  motion makes that speed authoritative.
- Yaw is extracted about the up (+Y) axis. Clips that turn more than 180°
  in a single loop are ambiguous at the wrap — split extreme turns into
  shorter clips.
- Switching clips re-baselines the extraction: the first frame after a
  `changeAnimation` contributes no delta.
- One-shot channels (`repeatAnimation` off) clamp at their last key, and
  root motion clamps with them: a lunge travels its authored distance and
  stops, with no spurious loop correction.
- Gameplay code can still move the entity (steering, knockback); root
  motion adds deltas rather than overwriting the transform.
- Hierarchical assets (loaded via `setEntityMeshAsync`) keep their
  `AnimationComponent` on a skinned child, but the deltas are applied to
  the entity you called `setRootMotionEnabled` on — the same handle your
  game steers — so the asset root moves and nothing drifts inside it.

## Running the Feature

1. Load a clip whose root actually travels (verify in Blender: the root
   bone moves across the ground).
2. Enable root motion and play the clip in game mode.
3. The entity's transform now follows the stride — watch the entity gizmo
   move with the character, and note the mesh no longer snaps back when
   the clip loops.
