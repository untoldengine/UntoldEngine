---
id: animationsystem
title: Animation System
sidebar_position: 4
---

#  Enabling Animation in Untold Engine

The Untold Engine simplifies adding animations to your rigged models, allowing for lifelike movement and dynamic interactions. This guide will show you how to set up and play animations for a rigged model.


## How to Enable Animation

### Step 1: Create an Entity

Start by creating an entity to represent your animated model.

```swift
let redPlayer = createEntity()
```

---

### Step 2: Link the Mesh to the Entity

Load your rigged model’s .usdc file and link it to the entity. This step ensures the entity is visually represented in the scene.

```swift
setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "usdc", flip: false)
```
>>> Note: If your model renders with the wrong orientation, set the flip parameter to false.

---

### Step 3: Load the Animation
Load the animation data for your model by providing the animation .usdc file and a name to reference the animation later.

```swift
setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "usdc", name: "running")
```

---

### Step 4: Set the Animation to play

Trigger the animation by referencing its name. This will set the animation to play on the entity.

```swift
changeAnimation(entityId: redPlayer, name: "running")
```

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

## Tips and Best Practices

- Name Animations Clearly: Use descriptive names like "running" or "jumping" to make it easier to manage multiple animations.
- Debug Orientation Issues: If the model’s animation appears misaligned, revisit the flip parameter or check the model’s export settings.
- Combine Animations: For complex behaviors, load multiple animations (e.g., walking, idle, jumping) and switch between them dynamically.
