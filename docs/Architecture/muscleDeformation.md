# Muscle Deformation: XPBD Muscles and the ML Deformer

The deformation compute pass (`DeformationSystem`, the `"deformation"`
render-graph node ahead of the shadow pass) deforms the meshes of every entity
carrying a `DeformationComponent` into per-mesh position/normal/tangent
buffers that the render passes bind in place of the base streams. Its kernel
order is:

1. morph targets and pose-space drivers (`deformMorphAccumulate`),
2. skinning: linear blend, dual quaternion or Direct Delta Mush
   (`deformSkinLBS` / `deformSkinDQS` / `deformSkinDDM`),
3. **volumetric muscles** (`muscleSkinWrap`) — this document,
4. **ML deformer** (`deformMLDecode`) — this document.

Muscles and the ML deformer produce the same thing, a per-vertex delta on top
of skinning; the first one simulates it, the second one predicts it from the
pose with a network trained on the simulation. A demo toggles between them.

## Volumetric muscles (XPBD)

### Rig

A `MuscleRig` (`Sources/UntoldEngine/Systems/Muscle/MuscleDefinition.swift`)
lists muscles as data, not geometry. Each `MuscleDefinition` is:

- two attachments (`MuscleAttachment`): a joint, a fraction along its bone
  (0 = joint, 1 = bone tip, the tip defaulting to the first non-twist child)
  and an offset in the *character frame* — lateral-left / up / forward, where
  forward comes from a foot → toe joint pair (`MuscleForwardReference`) so the
  same numbers work on any rig;
- a fusiform radius profile (`bellyRadius`, `tendonRadius`) and the cage
  resolution (`rings`, `segments`);
- XPBD compliances (fiber, cross-fiber, volume), damping, a bone-capsule
  collision radius and how far beyond its surface the muscle grips the skin
  (`skinInfluence`);
- an optional activation driver: a joint whose rest-relative rotation angle
  maps linearly from `startAngle` to `fullAngle` onto activation 0…1
  (`fullAngle < startAngle` inverts, e.g. a triceps that fires on extension).

Rigs reach the engine three ways: the asset's muscle table (chunk 27, written
by `untoldexplorer.py --muscles rig.json`), `MuscleRig(jsonData:)` (the same
JSON), or `setEntityMuscleRig(entityId:rig:)` from code.

### Cage

`MuscleGeometryBuilder.bake(rig:skeleton:)` resolves the joints on the bind
pose and builds, per muscle, a **membrane cage**: `rings` rings of `segments`
particles around the axis from origin to insertion with the fusiform radius,
plus one derived centre per ring (not simulated; it follows its ring's mean
and only serves the skin-wrap tets). End rings are pinned to their joints.

Constraints on the membrane:

- fiber edges (ring to ring, same slot) that contract with activation,
- hoop edges around each ring and one shear diagonal per quad,
- the two end slabs are **tendons**: no contraction and stretchy, so an
  isometric flex still shortens and thickens the belly,
- one **global volume constraint** per muscle over the closed surface (tube
  plus end caps).

Per-tet volume constraints were tried first and were unstable under the
Jacobi solver below (they exploded, then leaked volume); one exact volume
projection per muscle is both stable and what makes the belly bulge.

### Solver

`MuscleCompute.metal`, driven by `MuscleSimulator.encodeFrame`. Small-steps
XPBD: 8 substeps per frame, one iteration each, so Lagrange multipliers start
at zero every substep and need no storage.

- `musclePredict`: velocity from the previous position, damping, gravity,
  attachments snapped to the joint palette (`Skeleton.currentPose`).
- `muscleVolumeGradient`: per particle, the volume gradient of its incident
  surface triangles and `invMass·|∇|²`.
- `muscleSolve`: gather-based averaged Jacobi over the particle's edges
  (CSR adjacency, no atomics), then the exact volume projection
  (`V = ⅓ Σ pᵢ·∇ᵢ` and the summed norm are the same for every particle of a
  muscle, so each thread recomputes them), then a soft inelastic push-out of
  the muscle's two bone capsules (half the penetration per substep; the
  particle's velocity is killed on contact).

Activation is smoothed over 80 ms. A global override
(`setEntityMuscleActivationOverride`) beats a manual per-muscle value
(`setEntityMuscleActivation`), which beats the driver.

### Skin coupling

At bind time each skin vertex is attached to the nearest wedge tet of the
muscle whose influence is strongest there (`MuscleGeometryBuilder.bindSkin`,
run in the background per mesh): weight 1 inside the muscle, falling off over
`skinInfluence` outside it, and fading to zero near the tendons so the pinned
ends never tug the skin.

`muscleSkinWrap` then adds, after skinning,
`w · Σ bᵢ (xᵢ − x̂ᵢ)`: the tet corners' simulated positions minus their
**passive reference** — where the cage would sit if it just followed its
attachments at rest length (axis interpolation plus the rotated radial
offset). A relaxed muscle therefore adds nothing; only contraction, collision
and dynamics show. Normals and tangents are re-oriented with the tet's
deformation gradient (cofactor for the normal), blended by the weight.

Placement rule of thumb: keep a muscle's offset from its bone at least
`boneRadius + bellyRadius`; a cage overlapping its bone capsule inflates on
one side while the volume constraint pulls the other side in. The debug
overlay (`setMuscleDebugOverlay(enabled:)`, the `"muscleDebug"` graph node)
draws every cage — green → red by activation, grey when disabled with
`setEntityMuscleEnabled` — and the bone capsules in cyan.

## ML deformer

The simulation costs a few compute dispatches and a skin binding per mesh.
The ML deformer replaces it with a lookup: a small network maps the pose to
the coefficients of a PCA basis of the deltas, and one dense kernel decodes
them. It is trained by **self-distillation** from the simulation.

### 1. Bake (`MLDeformerBaker`, `untoldengine bake-mldeformer`)

`MLDeformerBaker.bake(asset:clips:rig:options:outputBase:)` runs headless on
Metal: it builds the cages, binds every skinned primitive of the asset, then
plays each clip at `frameRate` (default 90 Hz) once as authored and
`augmentationPasses` more times with smooth random rotation offsets on the
muscle joints (a sine per joint with random axis, amplitude up to
`maxAugmentationAngle`, frequency and phase). The muscle simulation steps
every frame; after `settleFrames`, every `sampleEveryFrames` frames it skins
the meshes on the CPU (linear blend), runs `muscleSkinWrap` and records:

- **features**: for every joint a muscle attaches to or is driven by, the
  first two columns of its rest-relative local rotation
  (`rest⁻¹ ∘ current`, 6 floats per joint);
- **deltas**: position and normal delta (6 float16) of every *active*
  vertex, i.e. every vertex the skin binding attached to a muscle.

Output: `<base>.json` (header: joints, meshes with their active vertex
ranges, active vertex indices, counts), `<base>.features.f32`,
`<base>.deltas.f16`.

### 2. Train (`scripts/train_mldeformer.py`)

Plain numpy, no PyTorch:

- PCA of the deltas via the N×N Gram matrix (`--components`, default 48),
- an MLP features → normalized coefficients with two SiLU hidden layers
  (`--hidden`, default 128), Adam with cosine decay, a held-out split whose
  position error it reports in millimetres next to the PCA floor and the
  signal magnitude,
- writes the `.untoldml` payload: header, joint paths, mesh ranges, active
  indices, input normalization, weights, coefficient scale, and the PCA mean
  and basis as float16 (`MLDeformerPayload` is the Swift mirror; its
  `encode()`/`init(data:)` round-trip is tested).

### 3. Runtime

`NativeFormatLoader` attaches `<asset>.untoldml` next to the file (or the
chunk-28 record's path) to the skeleton. With `setEntityMLDeformer(enabled:)`
the deformation pass loads the payload in the background, evaluates the
network on the CPU once per entity per frame (`MLDeformerModel`,
microseconds) and dispatches `deformMLDecode` per mesh: one thread per active
vertex reconstructs `mean + Σ cₖ · basisₖ` and adds it to the skinned position
and normal, scaled by `setEntityMLDeformerWeight`. Mesh tables are matched by
primitive name and vertex count.

Both features can be on at once; the demo treats them as alternatives
(off / XPBD simulation / ML deformer).
