---
id: registrationsystem
title: Registration System
sidebar_position: 2
---

#  Using the Registration System in Untold Engine

The Registration System in the Untold Engine is an integral part of its Entity-Component-System (ECS) architecture. It provides core functionalities to manage entities and components, such as:

- Creating and destroying entities.
- Registering components to entities.
- Setting up helper functions for other systems by configuring necessary components.


## How to Use the Registration System

### Step 1: Create an Entity

Entities represent objects in the scene. Use the createEntity() function to create a new entity.

```swift
let entity = createEntity()
```

---

### Step 2: Register Components

Components define the behavior or attributes of an entity. Use registerComponent to add a component to an entity.

```swift
registerComponent(entityId: entity, componentType: RenderComponent.self)
```
Example:

When you load a mesh for rendering, the system automatically registers the required components:

```swift
setEntityMesh(entityId: entity, filename: "model", withExtension: "usdz")
```

This function:

- Loads the mesh from the specified .usdc file.
- Associates the mesh with the entity.
- Registers default components like RenderComponent and TransformComponent.

---

### Step 3: Destroy an Entity

To remove an entity and its components from the scene, use destroyEntity.

```swift
destroyEntity(entityId: entity)
```

This ensures the entity is properly removed from all systems.

---

### Step 4: Destroy All Entities Safely

Use `destroyAllEntities(completion:)` when you need to clear the world before loading new content.

```swift
destroyAllEntities {
    // Safe point: pending destroys have been finalized.
    // Load new content here (USDZ, deserializeScene, etc).
}
```

Important behavior:

- `destroyAllEntities` is a deferred operation. Entities are marked for destroy first.
- Final cleanup runs during the engine frame finalization step (`finalizePendingDestroys()`).
- The `completion` block runs only after that finalization step has finished.

This prevents race conditions where new entities are created while old entities are still pending destroy.

Example: clear world, then load a new USDZ

```swift
destroyAllEntities {
    let entity = createEntity()
    setEntityMeshAsync(entityId: entity, filename: "office", withExtension: "usdz")
}
```

Example: `playSceneAt` pattern

```swift
public func playSceneAt(url: URL, completion: (() -> Void)? = nil) {
    guard let scene = loadGameScene(from: url) else {
        completion?()
        return
    }

    destroyAllEntities {
        deserializeScene(sceneData: scene) {
            completion?()
        }

        // Early camera rebind during async mesh loading window.
        CameraSystem.shared.activeCamera = findGameCamera()
    }
}
```
