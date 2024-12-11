# Creating a Game Entity

The **Untold Engine** is built on the Entity-Component-System (ECS) architecture. In this tutorial, you’ll learn how to create a game entity and link a mesh model to it.

## What is an Entity?

An entity is a unique identifier that represents an object in your game world. By itself, an entity is just an ID; it gains functionality when you attach components to it.

Let’s walk through the steps to create an entity and link a mesh to it.

---

### Step 1: Creating an Entity
To create an entity, use the createEntity() function. For example:

```swift
let bluePlayer = createEntity()
```
This creates a new entity ID, which you can now use to add components like meshes, transformations, and physics.

----

### Step 2: Linking a Mesh to the Entity
Next, load a mesh from a .usdc file and link it to the entity. The function setEntityMesh handles this:

```swift
setEntityMesh(entityId: bluePlayer, filename: "blueplayer", withExtension: "usdc")
```

In this example:

- bluePlayer is the entity ID.
- blueplayer is the name of the file (without the extension).
- usdc is the file extension.

---

### Step 3: Positioning the Entity

Once the mesh is linked, you can use the Transform System to move or rotate the entity in the game world. For instance, to move the entity to a new position:

```swift
translateTo(entityId: bluePlayer, position: simd_float3(2.0, 0.0, 0.0))
```

This moves the entity to the position (2.0, 0.0, 0.0) in world space.

Explore TransformSystem.swift to find more operations like rotation and scaling.

---

### Common Issue: My Model Isn’t Visible!

If you don’t see your model, it’s likely because the scene has no light. Lighting is essential for rendering visible objects.

To fix this, follow the next tutorial on adding lights to your game scene.

---

### Full Example Code
Here’s the complete code for creating a game entity and linking it to a mesh:

```swift
class GameScene {
    init() {
        // Step 1: Create an entity ID
        let bluePlayer = createEntity()
        
        // Step 2: Link a mesh model to the entity
        setEntityMesh(entityId: bluePlayer, filename: "blueplayer", withExtension: "usdc")
        
        // Step 3: Move the entity to a new position
        translateTo(entityId: bluePlayer, position: simd_float3(2.0, 0.0, 0.0))
    }
}
```

---

Next: [Adding Light to your game](AddingLighttoyourgame.md)
Previous: [Importing USDC Files](Importing-USD-Files.md)
