# Animation Transitions

## Introduction

When a character switches clips — idle to walk, walk to run — the engine
eases it into the new clip instead of popping. The technique is
**inertialization**: at the moment of the switch, the engine captures the
difference between the pose on screen and the incoming clip's first pose
(plus how fast that difference is changing), then decays that difference to
zero with a critically damped spring while only the new clip plays.

## Why Use It

- **No pops.** The character's pose *and* its velocity are continuous at
  the switch — a mid-stride walk-to-run doesn't snap legs to a new phase.
- **Cheaper than crossfades.** A crossfade samples both clips for the whole
  blend. An inertialized transition samples only the incoming clip after
  the switch frame; the decaying offset is a handful of math operations per
  joint.
- **No blend-tree authoring.** Transitions work between any two clips with
  no setup.

## Step-by-Step Implementation

Transitions are built into `changeAnimation`. If you already switch clips,
you already have them:

```swift
// Eases into "running" with the default halflife (0.1 s).
changeAnimation(entityId: player, name: "running")
```

Control the feel with `transitionHalflife` — the time it takes the offset
to decay by roughly half:

```swift
// Snappier switch for a dodge.
changeAnimation(entityId: player, name: "dodge", transitionHalflife: 0.05)

// Lazier settle for an idle.
changeAnimation(entityId: player, name: "idle", transitionHalflife: 0.25)

// Exact hard cut (the old behavior).
changeAnimation(entityId: player, name: "teleport", transitionHalflife: 0)
```

Playback of the new clip starts at its beginning, and `withPause` behaves
as before.

## What Happens Behind the Scenes

1. On `changeAnimation`, the engine samples the incoming clip at its start
   (and one small step later, to know its initial velocity).
2. For every joint it stores an offset — translation as a vector, rotation
   as a rotation vector (scaled angle-axis) — between the pose displayed
   last frame and the incoming pose, plus the velocity difference.
3. Every frame, each offset is advanced by an exact critically damped
   spring toward zero and added on top of the incoming clip's sampled pose.
4. When every offset is visually zero, the transition switches itself off.
   There is no fixed blend duration; the spring runs until it settles
   (visually, a few times the halflife).

Transitions decay in real time, independent of the clip's playback speed.
A transition that begins before the entity has ever displayed a pose (for
example, right after scene load) falls back to a hard cut — there is
nothing on screen to blend from.

## Tips and Best Practices

- Halflife, not duration: the pose covers half the remaining gap every
  `transitionHalflife` seconds. As a rule of thumb the transition looks
  settled after 4–6 halflives, so `0.1` reads as roughly a quarter-second
  ease.
- Very long halflives (> 0.5 s) make characters feel like they're moving
  through syrup; prefer shorter values and let the spring's velocity
  matching do the work.
- Rapid-fire `changeAnimation` calls are safe: each new transition captures
  the currently displayed pose, including any offset still decaying, so
  chains of switches stay continuous.

## Running the Feature

1. Load two clips on an entity (see *Enabling Animation*).
2. Enter game mode and call `changeAnimation` between them — from a key
   press, a script, or AI.
3. Compare with `transitionHalflife: 0` to see the hard cut the spring is
   removing.
