---
id: staticbatchingsystem
title: Static Batching System
sidebar_position: 11
---

# Static Batching System - Usage Guide

The Untold Engine provides a static batching system that dramatically reduces draw calls by combining static (non-moving) geometry into optimized batches.

## Quick Start

### Basic Static Batching Setup

```swift
// Create entities
let cube1 = createEntity()
setEntityMesh(entityId: cube1, filename: "cube", withExtension: "usdz")
translateTo(entityId: cube1, position: simd_float3(0, 0, 0))

let cube2 = createEntity()
setEntityMesh(entityId: cube2, filename: "cube", withExtension: "usdz")
translateTo(entityId: cube2, position: simd_float3(2, 0, 0))

let cube3 = createEntity()
setEntityMesh(entityId: cube3, filename: "cube", withExtension: "usdz")
translateTo(entityId: cube3, position: simd_float3(4, 0, 0))

// Mark entities as static
setEntityStaticBatchComponent(entityId: cube1)
setEntityStaticBatchComponent(entityId: cube2)
setEntityStaticBatchComponent(entityId: cube3)

// Enable batching and generate batches
enableBatching(true)
generateBatches()
```

**How it works:**
- Static entities are marked for batching
- `generateBatches()` combines entities with the same material into batch groups
- Rendering system uses batched draw calls instead of per-entity calls

### With Async Mesh Loading (Recommended)

For better performance, use async loading and enable batching in the completion handler:

```swift
let stadium = createEntity()
setEntityMeshAsync(entityId: stadium, filename: "stadium", withExtension: "usdz") { success in
    if success {
        print("Scene loaded successfully")
        
        // Mark as static AFTER mesh is loaded
        setEntityStaticBatchComponent(entityId: stadium)
        
        // Enable batching system
        enableBatching(true)
        
        // Generate batches
        generateBatches()
    }
}
```

**Important:** Always call `setEntityStaticBatchComponent()` **after** the mesh loads successfully, then enable and generate batches.

### Multi-Mesh Assets (USDZ with Multiple Objects)

For USDZ files with multiple meshes (like a building with walls, roof, windows):

```swift
let building = createEntity()
setEntityMeshAsync(entityId: building, filename: "office_building", withExtension: "usdz") { success in
    if success {
        // Mark parent entity - automatically marks all children as static
        setEntityStaticBatchComponent(entityId: building)
        
        enableBatching(true)
        generateBatches()
    }
}
```

**How it works:** `setEntityStaticBatchComponent()` recursively marks the parent and all children, so the entire building is batched.

## API Reference

### Core Functions

#### `setEntityStaticBatchComponent(entityId:)`
Marks an entity (and all its children) as static for batching.

```swift
setEntityStaticBatchComponent(entityId: entity)
```

**Note:** Entity must have a `RenderComponent` (i.e., mesh must be loaded).

#### `removeEntityStaticBatchComponent(entityId:)`
Removes static batching from an entity (and all its children).

```swift
removeEntityStaticBatchComponent(entityId: entity)
```

**Use case:** If you need to move a previously static object.

#### `enableBatching(_:)`
Globally enables or disables the batching system.

```swift
enableBatching(true)   // Enable batching
enableBatching(false)  // Disable batching
```

#### `isBatchingEnabled() -> Bool`
Checks if batching is currently enabled.

```swift
if isBatchingEnabled() {
    print("Batching is active")
}
```

#### `generateBatches()`
Generates batch groups from all entities marked as static.

```swift
generateBatches()
```

**Important:** Call this after marking entities as static and enabling batching.

#### `clearSceneBatches()`
Clears all generated batches.

```swift
clearSceneBatches()
```

**Use case:** When loading a new scene or reconfiguring static geometry.

## Complete Workflow Examples

### Example 1: Multiple Static Objects

```swift
import UntoldEngine

// Create multiple static props
var props: [EntityID] = []

for i in 0..<50 {
    let rock = createEntity()
    setEntityName(entityId: rock, name: "Rock_\(i)")
    
    // Load mesh
    setEntityMesh(entityId: rock, filename: "rock", withExtension: "usdz")
    
    // Position randomly
    let x = Float.random(in: -20...20)
    let z = Float.random(in: -20...20)
    translateTo(entityId: rock, position: simd_float3(x, 0, z))
    
    // Mark as static
    setEntityStaticBatchComponent(entityId: rock)
    
    props.append(rock)
}

// Enable and generate batches
enableBatching(true)
generateBatches()

print("Batched \(props.count) rocks")
```

### Example 2: Scene Loading with Batching

```swift
// Load scene from file
if let sceneData = loadGameScene(from: sceneURL) {
    deserializeScene(sceneData: sceneData)
    
    // Scene automatically restores StaticBatchComponent for marked entities
    // Enable batching and generate
    enableBatching(true)
    generateBatches()
    
    print("Scene loaded with batching enabled")
}
```

### Example 3: Dynamic Scene with Mixed Objects

```swift
// Static environment
let ground = createEntity()
setEntityMesh(entityId: ground, filename: "ground_plane", withExtension: "usdz")
setEntityStaticBatchComponent(entityId: ground)

let walls = createEntity()
setEntityMesh(entityId: walls, filename: "walls", withExtension: "usdz")
setEntityStaticBatchComponent(entityId: walls)

// Dynamic objects (NOT marked as static)
let player = createEntity()
setEntityMesh(entityId: player, filename: "character", withExtension: "usdz")
// Do NOT call setEntityStaticBatchComponent for moving objects

let enemy = createEntity()
setEntityMesh(entityId: enemy, filename: "enemy", withExtension: "usdz")
// Enemies move, so no static batching

// Enable batching (only affects static entities)
enableBatching(true)
generateBatches()
```

### Example 4: Large Async Scene Loading

```swift
let cityBlock = createEntity()
setEntityMeshAsync(entityId: cityBlock, filename: "city_block", withExtension: "usdz") { success in
    if success {
        print("City block loaded with all buildings")
        
        // Mark entire hierarchy as static
        setEntityStaticBatchComponent(entityId: cityBlock)
        
        // Enable batching system
        enableBatching(true)
        
        // Generate batches
        generateBatches()
        
        print("Static batching enabled - draw calls optimized")
    } else {
        print("Failed to load city block")
    }
}
```

## Best Practices

### What to Mark as Static
✅ **Good candidates:**
- Environment geometry (walls, floors, ceilings)
- Props that never move (rocks, trees, furniture)
- Buildings and structures
- Terrain meshes
- Static decorations

❌ **Bad candidates:**
- Characters and NPCs
- Vehicles
- Projectiles
- Animated objects
- UI elements

### Batching Requirements
For entities to batch together, they must have:
- ✅ Same material (textures, colors)
- ✅ `StaticBatchComponent` marked
- ✅ Valid `RenderComponent` (mesh loaded)

Entities with different materials will be in separate batch groups.

### Performance Tips

1. **Mark entities AFTER mesh loading:**
   ```swift
   setEntityMeshAsync(...) { success in
       setEntityStaticBatchComponent(entityId: entity) // ✅ Correct timing
   }
   ```

2. **Enable batching once per scene:**
   ```swift
   // Game initialization or scene load
   enableBatching(true)
   generateBatches()
   ```

3. **Group entities by material:**
   - Entities with the same material batch better
   - Reduce material variations for better batching

4. **Regenerate batches when needed:**
   ```swift
   // When adding/removing static entities
   clearSceneBatches()
   generateBatches()
   ```

## Limitations

- **No dynamic batching:** Only works for static geometry
- **Transform baked:** Entity positions are baked into batch geometry
- **Material grouping:** Different materials create separate batches
- **No skeletal meshes:** Animated/skinned meshes cannot be batched

