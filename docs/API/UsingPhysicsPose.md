# Physics Pose

## Introduction

Clips, motion matching and IK decide where a character's joints go; a
physics engine decides where its body would go if it were pushed, hit or
dropped. A **physics pose** lets a physics plugin — a Jolt rig, a ragdoll,
a simulated arm — take over any subset of the skeleton: it reads the
skeleton and the displayed joint transforms to build and drive its bodies,
then hands a model-space pose back that the animation update blends in,
joint by joint, by a weight it chooses. Weight 1 on every joint is a
ragdoll; weight 1 on one arm is a limb that swings from a grab; a weight
easing from 1 back to 0 is a get-up.

## Why Use It

- **One seam for any physics.** The engine owns pose composition and
  skinning; the plugin owns the simulation. Neither reimplements the other.
- **Partial takeover.** A physics-driven subtree sits on an animated
  parent, and animated joints sit under physics-driven ones, without a
  second skeleton or a second skin.
- **Ordering that reads right.** The pose lands after every animated stage
  — layer, reach IK, foot IK — so for the joints it weights, physics wins.

## Step-by-Step Implementation

1. Read the skeleton once, to build the rig:

```swift
guard let joints = getSkeletonJointInfo(entityId: zombie) else { return }
// joints.jointPaths: skeleton joint order, parents before children
// joints.parentIndices: nil for a parentless joint
// joints.bindModelTransforms: model-space bind pose, one per joint
```

2. Each frame, read the pose to drive the rig (kinematic bodies follow
   the animation, motors pull toward it) or to seed it (a ragdoll starts
   from the pose it fell out of). `getJointModelTransforms` is the pose
   on screen, physics pose included — right for seeding, since that is
   where the body visibly is. `getAnimatedJointModelTransforms` is the
   animation's own pose before the physics blend — right for driving,
   since the displayed pose already contains the bodies' result and
   aiming at it would only hold them where they are (they agree while no
   physics pose is active). The transforms are in the entity's model
   space; multiply by the entity's world transform for world space:

```swift
let world = scene.get(component: WorldTransformComponent.self, for: zombie)?.space ?? .identity
if let model = getAnimatedJointModelTransforms(entityId: zombie) {
    for (index, transform) in model.enumerated() {
        rig.setKinematicTarget(index, world * transform)
    }
}
```

3. After the simulation step, hand the result back, in model space, with a
   weight per joint. It stays in effect on every animation update until
   cleared:

```swift
let inverseWorld = world.inverse
let pose = rig.bodyTransforms.map { inverseWorld * $0 }
setPhysicsPose(entityId: zombie, jointModelTransforms: pose, jointWeights: weights)
// and to hand the character back to the animation:
clearPhysicsPose(entityId: zombie)
```

Both arrays must hold exactly one entry per skeleton joint, in
`jointPaths` order; a call with the wrong counts is ignored and logged.

## What Happens Behind the Scenes

Every frame, after the clip is sampled, root motion extracted, the
transition applied, the pose layer and reach IK blended and the feet
planted, the physics pose runs over the joints in skeleton order, keeping
a model-space forward kinematics of the pose *as it is being modified*:

1. A joint with weight above 0 slerps its local rotation toward the
   physics rotation — the physics transform taken into the frame of its
   parent's *blended* transform, so a joint under a physics-driven parent
   is measured against where physics put that parent.
2. The same joint also lerps its local translation toward the physics
   translation when it is the **top of a physics-driven subtree**: it has
   no parent, or its parent's weight is 0. Joints below a driven parent
   keep their animated bone offsets, so a rig whose bodies drift apart
   under joint limits never stretches or tears the skin; only their
   rotations follow.
3. A joint with weight 0 keeps its animated local transform, relative to
   its parent wherever that parent ended up — an animated hand rides on a
   physics-driven forearm.

Rotations compose rigidly, as in the IK stages. Rest scale enters only
where it moves a joint: a child's local translation is scaled by its
ancestors' rest scales when the skeleton builds the skin, and the blend
applies the same factor both ways, so a pose read with
`getJointModelTransforms` (rest scale included) comes back through
`setPhysicsPose` unchanged. Uniform rest scales round-trip exactly; a
non-uniform rest scale under a rotation is approximated by its per-axis
factors.

**Clip switches and pose history.** The blend reaches the skin and nothing
else: the local pose the engine keeps between updates is the animation's
own, so a `changeAnimation` or a motion-matching jump while a physics pose
is active inertializes from the animation, not from the bodies. A body
driven toward the animation (a powered ragdoll) therefore never drags the
animation after itself. A get-up that should ease out of the fallen pose
is the game's to author: read the displayed pose, hand it back as a
physics pose and fade its weights.

**Model space.** The skin matrices carry no entity transform — the shader
applies it — so model space is the entity's space. A joint's world
transform is the entity's world transform times its model transform, and
a world-space physics result is brought back with the inverse.

**Before the first update.** `getJointModelTransforms` returns the bind
pose until the entity has animated once, matching the identity skin the
mesh shows until then.

**Pause.** The blend happens inside the animation update. A paused entity
(`pauseAnimationComponent`) skips the update entirely and keeps showing
the last pose it composed, so a physics pose set while paused lands on the
first update after the entity resumes.

## Tips and Best Practices

- Weights are per joint, clamped to 0…1. Ease them over a few frames when
  handing a limb to or from physics — a weight that jumps reads as a cut,
  just as a pose-layer weight does.
- Drive the top of a physics subtree from a joint whose parent stays at
  weight 0 (the pelvis for a full ragdoll, the upper arm for an arm) so
  its translation follows the body; everything below inherits the offsets
  the clip was authored with.
- Motion matching, reach IK and foot IK never see the physics pose: they
  read and shape the animated pose before it. A ragdoll at full weight
  therefore keeps matching in the background and will be ready the frame
  the weights ease out.
