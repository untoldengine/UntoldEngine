# Pose Layers and Reach IK

## Introduction

Motion matching (and plain clip playback) decides what the legs do. It
does not decide what the arms do: a jump is chosen on feet, hips and path,
so the upper body lands wherever the winning clip put it. A **pose layer**
takes a joint subset — both arms, say — away from the playing clip and
gives it a posture of its own: a second clip, looping on its own clock,
whose rotations replace those joints by an eased weight. **Reach IK** then
bends the arms toward a world target: a hand touches what it can reach and
points at what it cannot.

## Why Use It

- **Coherent upper body.** The arms hang while roaming and rise while
  chasing because gameplay says so, not because the clips that won the
  search happened to agree.
- **Fewer clips.** One posture take covers every gait; the locomotion set
  does not need an "arms up" variant of every walk.
- **Intent.** Hands that point at the player read as a threat no clip can
  aim.

## Step-by-Step Implementation

1. Name the joint subtrees the layer owns (every joint at or under each
   path):

```swift
setPoseLayerMask(entityId: zombie, rootJointPaths: [
    "/root/pelvis/spine_01/spine_02/spine_03/clavicle_l",
    "/root/pelvis/spine_01/spine_02/spine_03/clavicle_r",
])
```

2. Give it a clip (loaded on the entity like any other) and a weight. The
   clip loops on its own clock; a later clip fades the previous one out
   over the halflife, and the weight eases to its target:

```swift
setPoseLayerClip(entityId: zombie, name: "arms_raised", transitionHalflife: 0.4)
setPoseLayerWeight(entityId: zombie, weight: 1, halflife: 0.3)
```

   Weight 0 hands the joints back to the base clip; weight 1 replaces
   their rotations entirely.

3. Optionally point the arms at something:

```swift
setReachIKChains(entityId: zombie, chains: [
    ReachIKChainDescriptor(shoulderPath: ".../upperarm_l", elbowPath: ".../lowerarm_l", handPath: ".../hand_l"),
    ReachIKChainDescriptor(shoulderPath: ".../upperarm_r", elbowPath: ".../lowerarm_r", handPath: ".../hand_r"),
])
// every frame, from gameplay:
setReachIKTarget(entityId: zombie, worldPosition: playerHead, weight: 1, halflife: 0.25)
// and to let go:
setReachIKTarget(entityId: zombie, worldPosition: nil)
// per-arm multipliers on the influence, for a grab cycle — one hand
// lunging while the other pulls back:
setReachIKChainWeights(entityId: zombie, weights: [0.9, 0.2])
```

## What Happens Behind the Scenes

Every frame, after the base clip is sampled, root motion extracted and
the inertialized transition applied — and before foot IK plants the feet:

1. The layer eases its weight, advances its clip (and the outgoing clip
   while a crossfade is in flight), and slerps the masked joints' local
   rotations toward the layer pose by the weight.
2. Reach IK eases its influence, runs forward kinematics on the result,
   and for each chain solves the two-bone problem (the solver foot IK
   uses) toward the target: within reach the hand lands on it; beyond
   reach the target is pulled in to `reach` (default 95%) of the chain's
   length along the same direction, so the arm points without locking the
   elbow. The target itself is eased over a short halflife (80 ms), so a
   tracked head that jitters or a player who moves abruptly pulls the
   hands over a few frames instead of one. The elbow keeps the bend plane
   the pose already has — the layer's posture decides where the elbows go
   — and the solved rotations blend in by the influence.

Motion matching reads feet and hips before any of this and never sees
the layer, so a layered character matches exactly as an unlayered one.
Hand positions can be added to the matching features
(`MotionMatchingDescriptor.leftHandPath`/`rightHandPath`) to keep jumps
from landing on clips whose arms are far from the current ones; with a
layer at full weight that mostly stops mattering.

## Tips and Best Practices

- One layer per entity. Masks are subtrees, so include the clavicles for
  a whole arm and leave the spine to the locomotion clip: the torso keeps
  swaying with the gait.
- Posture clips are best in place and looping (a hold idle, an "arms up"
  take). Their own motion — a slow sway — plays over any gait; arms will
  not swing with the legs, which suits a stiff character and not a
  sprinter.
- Halflives of 0.3-0.5 s make a posture change read as the character
  lifting its arms; 0.1 s reads as a cut.
- Reach IK aims the whole chain. For a hand that should also *orient*
  toward the target (a palm on a wall), align the hand joint yourself
  after the solve or author it in the posture clip.
