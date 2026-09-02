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

When you load a mesh for rendering, the system automatically registers the required components. For normal runtime code, use the async path:

```swift
setEntityMeshAsync(entityId: entity, filename: "model", withExtension: "untold") { success in
    guard success else { return }
    // RenderComponent, TransformComponent, material data, and mesh resources are ready.
}
```

This function:

- Loads the mesh from the specified `.untold` file.
- Associates the mesh with the entity.
- Registers default components like RenderComponent and TransformComponent.
- Calls the completion handler when the mesh has been registered.

For immediate loading, use:

```swift
setEntityMesh(entityId: entity, filename: "model", withExtension: "untold")
```

The immediate path is useful for tools and tests that need the mesh to be GPU-resident when the function returns.

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

---

### Loading Scene-Authored Data

Some data exported from Blender is scene-wide rather than per-mesh:
scene-authored lights/cameras, and a `.cube` creative grade LUT (from
`--color-grade-lut`, see [Using the Exporter](UsingTheExporter.md)). None
of this is registered by a normal mesh load — `setEntityMesh`/
`setEntityMeshAsync` only bring in geometry and materials. Use
`loadSceneAuthored` alongside your mesh load to bring in the rest:

```swift
// From a single .untold asset (file-type: shared)
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras and any .cube grade are now registered.
}

// From a tile manifest
loadSceneAuthored(url: manifestURL) { success in
    // Same, sourced from the manifest's scene_lights/scene_cameras/colorGradeLUT keys.
}
```

Important behavior:

- Calling either overload clears any previously-loaded `.cube` grade first
  (`ColorGradeLUTParams.shared.clear()`), then re-populates it only if the
  asset/manifest actually has one staged.
- If the source has no `.cube` staged, the engine applies no creative
  grade — this is not an error.
- The `.cube` grade can be toggled off at runtime (e.g. to compare against
  the tonemap operator alone) with `setPostFX(.colorGradeLUT(.enabled(false)))`.
  See [Using Post-Effects](UsingPostFX.md).
- A `.cube` can also be applied without any scene export, via
  `setColorGradeLUT(filename:withExtension:)`, resolved the same way
  `getResourceURL` resolves any other asset (a `LUT/` folder under
  `assetBasePath`, or the app bundle).
- Assets exported before `--bake-color-management` was removed may still
  carry a legacy `colorLUT` baked whole-transform LUT; `loadSceneAuthored`
  still loads and clears it (`ColorLUTParams.shared.clear()`) for backward
  compatibility.

See [Using Color Management](UsingColorManagement.md) for the full export +
load workflow.
