---
layout: page
title: Physics
permalink: /physics/
nav_order: 11
---

# Enabling Physics System in Untold Engine

The physics system in the Untold Engine enables realistic simulations such as gravity, forces, and dynamic interactions. While collision support is still under development, this guide will walk you through adding physics to your entities.

## Why Add Physics?

Adding physics brings life to your entities by making them responsive to external forces and environmental effects like gravity. Use cases include:

- Simulating falling objects.
- Moving entities dynamically with forces.
- Enabling more immersive, interactive gameplay.

## How to Enable Physics

### Step 1: Create an Entity

Start by creating an entity that represents the object you want to add physics to.

```swift
let redPlayer = createEntity()
```
---

### Step 2: Link a Mesh to the Entity
Next, load your model’s mesh file and link it to the entity. This step visually represents your entity in the scene.

```swift
setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "usdc")
```
---

### Step 3: Enable Physics on the Entity
Activate the physics simulation for your entity using the setEntityKinetics function. This function prepares the entity for movement and dynamic interaction.

```swift
setEntityKinetics(entityId: redPlayer)
```
---

#### Step 4: Configure Physics Properties
You can customize the entity’s physics behavior by defining its mass and gravity scale:

- Mass: Determines the force needed to move the object. Heavier objects require more force.
- Gravity Scale: Controls how strongly gravity affects the entity (default is 0.0).

```swift
setMass(entityId: redPlayer, mass: 0.5)
setGravityScale(entityId: redPlayer, gravityScale: 1.0)
```
---

#### Step 5: Apply Forces (Optional)
You can apply a custom force to the entity for dynamic movement. This is useful for simulating actions like jumps or pushes.

```swift
applyForce(entityId: redPlayer, force: simd_float3(0.0, 0.0, 5.0))
```

> Note: Forces are applied per frame. To avoid unintended behavior, only apply forces when necessary.

---

#### Step 6: Use the Steering System
For advanced movement behaviors, leverage the Steering System to steer entities toward or away from targets. This system automatically calculates the required forces.

Example: Steering Toward a Position

```swift
steerTo(entityId: redPlayer, targetPosition: simd_float3(0.0, 0.0, 5.0), maxSpeed: 2.0, deltaTime: deltaTime)
```

---

#### Additional Steering Functions

The Steering System includes other useful behaviors, such as:

- steerAway()
- steerPursuit()
- followPath()

These functions simplify complex movement patterns, making them easy to implement.

---

### What Happens Behind the Scenes?

1. Physics Simulation:
- Entities with physics enabled are updated each frame to account for forces, gravity, and other dynamic factors.
- Transformations are recalculated based on velocity, acceleration, and forces applied.
2. Realistic Motion:
- The system ensures consistent, physics-based movement without manual updates to the transform.

---

### Running the Simulation
Once you've set up physics, run the project to see it in action:

1. Launch the project: Your model will appear in the game window.
2. Press "P" to enter Game Mode:
- Gravity and forces will affect the entity.
- If forces are applied, you’ll see dynamic motion in real time.

