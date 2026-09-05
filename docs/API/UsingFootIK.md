# Foot IK

## Introduction

Animation clips are authored against a flat ground plane, but game terrain
isn't flat — on slopes and steps, feet float above the ground or sink into
it. **Foot IK** samples the real geometry beneath each foot every frame and
adjusts the leg so the foot lands on it, using an analytic two-bone solver
(hip and knee; no iteration).

## Why Use It

- Foot floating/sinking on uneven terrain is the first artifact players
  notice on animated characters.
- It composes with root motion: root motion moves the character across the
  terrain, foot IK plants each foot on it.
- The solver is closed-form — two joints per leg, a handful of math
  operations, no per-frame convergence loop.

## Step-by-Step Implementation

Describe each leg as a hip → knee → ankle chain of skeleton joint paths,
then enable:

```swift
setFootIKChains(entityId: zombie, chains: [
    FootIKChainDescriptor(
        hipPath: "root/hips/thigh_l",
        kneePath: "root/hips/thigh_l/calf_l",
        anklePath: "root/hips/thigh_l/calf_l/foot_l"
    ),
    FootIKChainDescriptor(
        hipPath: "root/hips/thigh_r",
        kneePath: "root/hips/thigh_r/calf_r",
        anklePath: "root/hips/thigh_r/calf_r/foot_r"
    ),
])
setFootIKEnabled(entityId: zombie, enabled: true)
```

By default the ground is found with a downward scene ray pick (the octree
picking system), skipping hits on the character itself. If your game has a
cheaper or more authoritative ground source — a heightfield, a navmesh, a
physics query — plug it in:

```swift
setFootIKGroundQuery(entityId: zombie) { worldPosition in
    guard let height = myTerrain.height(atX: worldPosition.x, z: worldPosition.z) else {
        return nil // no ground here: leave the foot as authored
    }
    return FootIKGroundSample(height: height)
}
```

Pass `nil` to restore the default ray probe.

## What Happens Behind the Scenes

1. After sampling, root motion, and transitions, the engine computes the
   model-space position of each configured ankle.
2. The ground is sampled beneath the ankle (in world space). The ankle's
   authored height above the clip's ground plane is preserved above the
   real terrain: a foot lifted mid-stride stays lifted.
3. Corrections larger than 0.5 m are ignored — a sample that far from the
   animated foot is a ledge or a bad probe, not ground.
4. The two-bone solver rotates the hip and knee so the ankle reaches the
   corrected position, bending the knee the way the clip already bends it.
   For a perfectly straight leg the pose gives no bend to follow, so the
   knee bows toward the chain's `bendDirection` (model space, default
   character forward — set it per chain in `FootIKChainDescriptor` if your
   rig faces elsewhere). Unreachable targets clamp to full leg extension.
5. The corrected pose is then composed and skinned as usual.

Chains whose joint paths don't exist in the skeleton are dropped silently —
double-check paths against your rig's joint naming when a leg doesn't
respond. Leg joints are assumed to have unit scale.

## Stance Locking

Even perfect data slides a little: root motion can only match one foot at
a time, so the trailing foot in double support drifts a few centimeters,
and any mismatch between commanded and authored speed shows up at ground
contact. Stance locking absorbs it:

```swift
setFootIKStanceLocking(entityId: player, enabled: true)
```

While a foot's animated world velocity is below the enter threshold the
IK target pins to the world position where the foot planted — the foot is
world-stationary no matter what the root does. The lock releases when the
animation swings the foot away (speed above the exit threshold, or pulled
past the lock distance), and a short decay lets the foot catch up without
a pop. Thresholds are hysteretic so a foot never flickers between states.

## Tips and Best Practices

- Feed the query point terrain, not props: with the default ray probe, a
  foot over a small rock will step onto it — usually what you want, but a
  custom ground query gives you the authority to decide.
- Foot IK adjusts legs only; it does not (yet) lower the pelvis, so a
  downhill foot beyond leg reach clamps at full extension rather than
  forcing the hips down.
- The ankle's *orientation* is not yet aligned to the ground normal; the
  sample's normal is provided for when that lands.

## Running the Feature

1. Load a character on uneven ground (a ramp or stairs).
2. Enable foot IK with both leg chains and play a locomotion clip.
3. Toggle `setFootIKEnabled` on and off to compare — watch the feet stop
   floating on the high side and stop sinking on the low side.
