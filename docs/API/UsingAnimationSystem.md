# Enabling Animation in Untold Engine

The Untold Engine simplifies adding animations to your rigged models, allowing for lifelike movement and dynamic interactions. This guide will show you how to set up and play animations for a rigged model.


## How to Enable Animation

### Step 1: Create an Entity

Start by creating an entity to represent your animated model.

```swift
let redPlayer = createEntity()
```

---

### Step 2: Link the Mesh to the Entity

Load your rigged model's `.untold` runtime asset and link it to the entity. This step ensures the entity is visually represented in the scene.

```swift
setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "untold")
```

---

### Step 3: Load the Animation
Load the animation data for your model by providing the exported animation `.untold` file and a name to reference the animation later.

```swift
setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "untold", name: "running")
```

For hierarchical or multi-mesh `.untold` assets, call animation APIs on the asset root. The engine resolves the root to every skinned render descendant and installs the clip on each target that has both a `SkeletonComponent` and a `RenderComponent`. This keeps split characters or multi-part rigged models animated as one actor.

---

### Step 4: Set the Animation to play

Trigger the animation by referencing its name. This will set the animation to play on the entity.

```swift
changeAnimation(entityId: redPlayer, name: "running")
```

`changeAnimation(entityId:name:withPause:)`, `pauseAnimationComponent(entityId:isPaused:)`, `setAnimationPlaybackSpeed(entityId:speed:)`, and `removeAnimationClip(entityId:animationClip:)` all operate on the entity and any descendant animation components. `getAllAnimationClips(entityId:)` returns the union of clip names found under the entity. `getAnimationPlaybackSpeed(entityId:)` returns the speed from the first resolved animation component.

---

### Step 5. Pause the animation (Optional)

To pause the current animation, simply call the following function. The animation component will be paused for the current entity.

```swift
pauseAnimationComponent(entityId: redPlayer, isPaused: true)
```

---

### Running the Animation

Once the animation is set up:

1. Run the project: Your model will appear in the game window.
2. Click on "Play" to enter Game Mode:
- The model will play the assigned animation in real time.

---

## Controlling Which Entities Animate

Animation can be controlled at two levels, with a clear precedence:

1. **Global** — `AnimationSystem.shared.isEnabled`. When `false`, nothing
   animates, regardless of any per-entity setting. Useful for packaged
   builds, performance testing, or editing a static world.
2. **Per entity** — each `AnimationComponent` carries an `AnimationPolicy`:
   - `.inherit` (default): follow the effective value from the levels above.
   - `.forceOn`: always animate (when the global toggle is on).
   - `.forceOff`: never animate.

```swift
// Freeze one character while the rest of the scene keeps animating.
setAnimationPolicy(entityId: zombie, policy: .forceOff)

// Restore the default layered behavior.
setAnimationPolicy(entityId: zombie, policy: .inherit)

// nil means descendants disagree (a policy was set on an individual
// child instead of the asset root) — treat as "mixed".
let policy = getAnimationPolicy(entityId: zombie)
```

Like the other animation APIs, `setAnimationPolicy` called on an asset root
applies to every descendant that carries an `AnimationComponent`, so split
or multi-mesh rigged assets behave as one actor.

`.forceOff` freezes the entity's playback clock without touching its
play/pause state — switching the policy back resumes exactly where the
entity left off, with whatever pause state it had. This also makes
`.forceOff` a cheap animation LOD lever: distant characters can be frozen
and unfrozen without disturbing their playback state.

---

## Tips and Best Practices

- Name Animations Clearly: Use descriptive names like "running" or "jumping" to make it easier to manage multiple animations.
- For split rigged assets, treat the load root as the public animation handle; do not manually chase child mesh entities unless you need custom per-part behavior.
- Debug Orientation Issues: If the model’s animation appears misaligned, revisit the flip parameter or check the model’s export settings.
- Combine Animations: For complex behaviors, load multiple animations (e.g., walking, idle, jumping) and switch between them dynamically.
