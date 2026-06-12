# Using the Registration System in Untold Engine

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
setEntityMesh(entityId: entity, filename: "model", withExtension: "untold")
```

This function:

- Loads the mesh from the specified `.untold` file.
- Associates the mesh with the entity.
- Registers default components like RenderComponent and TransformComponent.
- Uses the immediate path; the mesh is GPU-resident when the function returns.

For asynchronous always-resident loading, use:

```swift
setEntityMeshAsync(entityId: entity, filename: "model", withExtension: "untold") { success in
    // Mesh is registered on success.
}
```

For large streamed scenes, use `setEntityStreamScene(...)`. The streaming/OCC path is owned by the tile manifest pipeline, not by direct `StreamingComponent` authoring.

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
    // Load new content here (.untold, deserializeScene, etc).
}
```

Important behavior:

- `destroyAllEntities` is a deferred operation. Entities are marked for destroy first.
- Final cleanup runs during the engine frame finalization step (`finalizePendingDestroys()`).
- The `completion` block runs only after that finalization step has finished.

This prevents race conditions where new entities are created while old entities are still pending destroy.

Example: clear world, then load a new `.untold` asset

```swift
destroyAllEntities {
    let entity = createEntity()
    setEntityMeshAsync(entityId: entity, filename: "office", withExtension: "untold")
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
        setCamera(.active(findGameCamera()))
    }
}
```
