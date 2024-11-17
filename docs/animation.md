#  Enabling Animation

The Untold Engine makes it easy to add animations to your models. This tutorial will walk you through setting up and playing animations for a rigged model.

### Step 1: Create an Entity

Start by creating an entity for your animated model.

```swift
let redPlayer = createEntity()
```

---

### Step 2: Link the Mesh to the Entity

Load the .usdc file for your rigged model and link it to the entity.

```swift
setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "usdc", flip: false)
```
>>> Note: If your model renders with the wrong orientation, set the flip parameter to false.

---

### Step 3: Load the Animation
Next, load the animation for your model. Provide the animation .usdc file and a name for the animation, which the engine will use as a reference.

```swift
setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "usdc", name: "running")
```

---

### Step 4: Play the Animation

Set the animation to play by referencing its name.

```swift
changeAnimation(entityId: redPlayer, name: "running")
```

---

### Running the Animation

After you Run the project in Xcode:

- Your model should appear in the game window.
- Press L to enter Game Mode, and you’ll see your model animating.


Previous: [Enabling Physics](physics.md)
