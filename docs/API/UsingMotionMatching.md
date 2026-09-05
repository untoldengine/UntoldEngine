# Motion Matching

## Introduction

Motion matching animates a character with **no animation state machine**.
Instead of authoring transitions between clips, gameplay states a *goal* —
a desired velocity and facing, typically straight from the steering
system — and every tenth of a second the engine searches all loaded
animation frames for the one that best matches what the character is
currently doing *and* where it should be heading, then eases playback to
that frame with an inertialized transition. The clips' own root motion
moves the character.

## Why Use It

- **No state machine to author or maintain.** Adding a clip to the entity
  adds it to the vocabulary; the search decides when it's used.
- **Natural movement.** The character is always playing real captured
  motion; transitions happen at the frames where poses genuinely match.
- **AI-friendly.** "Walk toward the player through the environment" is one
  `setMotionMatchingGoal` call per frame with the steering output.

## Step-by-Step Implementation

1. Load the entity's clips as usual and **enable root motion** — motion
   matching relies on the clips' travel to move the entity:

```swift
setEntityAnimations(entityId: zombie, filename: "locomotion", withExtension: "untold", name: "locomotion")
setRootMotionEnabled(entityId: zombie, enabled: true)
```

2. Describe the character and build the database (built lazily on the
   first enabled frame, from the loaded clips — a few minutes of animation
   resamples in milliseconds):

```swift
setMotionMatching(entityId: zombie, descriptor: MotionMatchingDescriptor(
    leftFootPath: "root/hips/thigh_l/calf_l/foot_l",
    rightFootPath: "root/hips/thigh_r/calf_r/foot_r"
))
setMotionMatchingEnabled(entityId: zombie, enabled: true)
```

3. Feed it a goal every frame from your AI:

```swift
// e.g. inside the game update, from the steering system:
let toPlayer = getPosition(entityId: player) - getPosition(entityId: zombie)
let desired = simd_normalize(simd_float3(toPlayer.x, 0, toPlayer.z)) * zombieSpeed
setMotionMatchingGoal(entityId: zombie, desiredVelocity: desired)
```

That's the whole integration — no `changeAnimation` calls, no states.

## What Happens Behind the Scenes

1. **Database build:** every clip is resampled at `sampleRate` (default
   30 Hz). Each frame stores a 27-dimensional feature vector in character
   space: foot positions and velocities, hip velocity, and the root's
   future positions and facings at 0.33/0.66/1.0 s (loop-wrapped with the
   clip's per-loop displacement). Features are normalized per dimension
   and weighted per group (`MotionMatchingWeights`).
2. **Query:** on each search (default every 0.1 s) the current pose's foot
   features are measured, velocities as world-space finite differences
   rotated into the character frame, and the future trajectory is
   *predicted* by easing the current simulated velocity toward the goal
   with `predictionHalflife`.
3. **Search:** brute force over every frame — a few thousand frames is a
   few hundred microseconds. The currently playing frame's cost is
   discounted 10% as hysteresis, so only meaningfully better frames cause
   a jump, and a winner near the natural playback position is skipped
   entirely.
4. **Jump:** playback switches clip and time through the same
   inertialized transition `changeAnimation` uses, and root motion
   re-baselines — no pops, no teleports.

## Tips and Best Practices

- **Coverage beats quantity:** the search can only pick frames that
  exist. For locomotion you want starts, stops, turns, and speed
  variations; a single straight walk loop will turn by sliding.
- **Weights are the tuning surface.** Raise `trajectoryPosition`/
  `trajectoryDirection` for responsiveness to the goal; raise the foot
  weights for pose fidelity (less foot sliding at transitions).
- `minPlayTime` (default 0.3 s) is the floor on how long a chosen frame
  plays before the next jump may fire. Without it, a frame that
  systematically beats the incumbent — the velocity peak of a cycle
  whenever the goal speed exceeds the clip's mean — wins every search
  and playback treadmills on one spot: a frozen-looking pose drifting
  across the floor. Raise it for calmer motion, lower it for snappier
  reactions.
- `searchInterval` trades responsiveness for cost; 0.1 s is a good
  default. Databases of a few thousand frames need no acceleration
  structure.
- Hierarchical assets (loaded via `setEntityMeshAsync`) keep their
  `AnimationComponent` on a skinned child, but heading, world position,
  and root-motion deltas all anchor to the entity you called the APIs on
  — the same handle your game steers.
- Combine with **foot IK** for terrain and **animation policy**
  (`.forceOff`) as a distance LOD lever — freeze far characters and stop
  calling `setMotionMatchingGoal` for them.
- Clips are assumed to loop with keys spanning their full duration
  (standard for locomotion loops).

## Running the Feature

1. Load a character with at least an idle and a walk whose root travels.
2. Enable root motion + motion matching with both foot paths.
3. In game mode, drive the goal from input or AI and watch the character
   pick clips by itself — zero the goal and it settles into idle.
