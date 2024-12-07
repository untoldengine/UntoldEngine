# Enabling Physics

Adding physics to your models in the Untold Engine enables realistic interactions such as gravity, forces and collisions(not supported yet). Follow this tutorial to enable physics on an entity.

### Step 1: Create an Entity

As always, begin by creating an entity for your model.

```swift
let redPlayer = createEntity()
```
---

### Step 2: Link the Mesh to the Entity

Load the .usdc file for your model and link it to the entity.

```swift
setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "usdc")
```

---

### Step 3: Enable Physics
Enable physics on the entity by calling the setEntityKinetics function. This will allow the engine to simulate movement and collisions for the entity.

```swift
setEntityKinetics(entityId: redPlayer)
```

---

### Step 4: Set Mass and Gravity Scale
Customize the physics behavior of your entity:

- Use setMass to define the entity's mass. A heavier object will require more force to move.
- Use setGravityScale to control how strongly gravity affects the entity.


```swift
setMass(entityId: redPlayer, mass: 0.5)
setGravityScale(entityId: redPlayer, gravityScale: 1.0)
```

---

### Step 5: Apply Forces (Optional)
You can apply a force to the entity dynamically in the Update function. This is useful for simulating motion or interactions in real time.

```swift
applyForce(entityId: redPlayer, force: simd_float3(0.0, 0.0, 5.0))
```

>>> Note: Forces are applied per frame, so ensure you only apply them when needed to avoid unintended behavior.

---

### Step 6. Steering System
Instead of applying forces manually, you can use the Steering System to apply forces indirectly. For example, if you want your entity to steer to a position, you can call the following function:

```swift
steerTo(entityId: redPlayer, targetPosition: simd_float3(0.0,0.0,5.0), maxSpeed: 2.0, deltaTime: deltaTime)
```

There are several other steer functions that you can use such as

```swift
steerAway()
steerPursuit()
followPath()
```

### Running the Physics Simulation

After you Run the project in Xcode:

1. Your model will appear in the game window.
2. Press **P** to enter Game Mode.
    - Your entity will respond to gravity, forces, and collisions.
    - If you applied a force, you’ll see your model move accordingly.


Next: [Enabling Animation](animation.md)
Previous: [Detecting User Inputs](DetectingUserInputs.md)
