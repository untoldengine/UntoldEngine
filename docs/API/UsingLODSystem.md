# LOD (Level of Detail) System - Usage Guide

The Untold Engine provides a flexible LOD system for optimizing rendering performance by displaying different mesh details based on camera distance.

## Overview

The LOD system allows you to:
- Add multiple levels of detail to any entity
- Automatically switch between LOD levels based on distance
- Customize distance thresholds for each LOD level
- Configure LOD behavior (bias, hysteresis, fade transitions)

> **Choose Your Path:** You can set up LOD via the **Editor** (no code required) or **programmatically** in Swift.

---

## Using the Editor

### Adding LOD Support to an Entity

1. **Select your entity** in the Scene Hierarchy
2. **Open the Inspector** and click **"Add Components"**
3. **Select "LOD Component"** from the list
4. An LOD Levels panel will appear in the Inspector

### Adding LOD Levels

1. **Select a model** from the Asset Browser (Models folder)
2. In the LOD Levels panel, click **"Add LOD Level"**
3. The selected model will be added as the next LOD level with a default distance:
   - LOD0: 50 units
   - LOD1: 100 units
   - LOD2: 150 units, etc.

### Adjusting LOD Distances

1. Click the **distance value** next to any LOD level
2. Enter a new distance and press **Enter**
3. Objects will switch to this LOD when the camera is within this distance

### Removing LOD Levels

Click the **trash icon** next to any LOD level to remove it.

---

## Using Code

### Quick Start

### Basic LOD Setup

```swift
// Create entity
let tree = createEntity()

// Add LOD component
setEntityLodComponent(entityId: tree)

// Add LOD levels (from highest to lowest detail)
addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "untold", maxDistance: 50.0)
addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "untold", maxDistance: 100.0)
addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "untold", maxDistance: 200.0)
addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "untold", maxDistance: 400.0)
```

**How it works:**
- LOD0 (highest detail) renders when camera is < 50 units away
- LOD1 renders between 50-100 units
- LOD2 renders between 100-200 units
- LOD3 (lowest detail) renders beyond 200 units

### Loading Multiple LOD Levels (Recommended)

Use `addLODLevels` to load all LOD levels with a single completion handler. This is especially important when combining LOD with static batching:

```swift
let tree = createEntity()
setEntityLodComponent(entityId: tree)

// Load all LOD levels and wait for completion
addLODLevels(entityId: tree, levels: [
    (0, "tree_LOD0", "untold", 50.0, 0.0),
    (1, "tree_LOD1", "untold", 100.0, 0.0),
    (2, "tree_LOD2", "untold", 200.0, 0.0),
    (3, "tree_LOD3", "untold", 400.0, 0.0)
]) { success in
    if success {
        print("All LOD levels loaded")
        
        // Apply transforms AFTER mesh is loaded
        translateTo(entityId: tree, position: simd_float3(10, 0, 5))
        
        // Apply static batching if necessary
    }
}
```

> **Important:** When using LOD with async loading, apply transforms (`translateTo`, `rotateTo`, `scaleTo`) inside the completion handler. Transforms applied before the mesh loads may not take effect.

### With Initial Mesh Loading

You can also load an initial mesh synchronously before adding LOD levels:

```swift
let tree = createEntity()

// Load initial mesh synchronously (shows immediately)
setEntityMesh(entityId: tree, filename: "tree_LOD0", withExtension: "untold")

// Add LOD component
setEntityLodComponent(entityId: tree)

// Add LOD levels (will replace initial mesh when ready)
addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "untold", maxDistance: 50.0)
addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "untold", maxDistance: 100.0)
addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "untold", maxDistance: 200.0)
addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "untold", maxDistance: 400.0)
```

### With Completion Handler

Since `addLODLevel` loads meshes asynchronously, use the completion handler when you need to perform actions after loading completes:

```swift
let tree = createEntity()
setEntityLodComponent(entityId: tree)

// Chain completion handlers for sequential loading
addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "untold", maxDistance: 50.0) { success in
    if success {
        print("LOD0 loaded")
        // Now it's safe to use the mesh data
    }
}
```

## File Organization

LOD files should be organized in subdirectories:

```
GameData/
└── Models/
    ├── tree_LOD0/
    │   └── tree_LOD0.untold
    ├── tree_LOD1/
    │   └── tree_LOD1.untold
    ├── tree_LOD2/
    │   └── tree_LOD2.untold
    └── tree_LOD3/
        └── tree_LOD3.untold
```

**Note:** Each LOD file should be in its own folder with the same name as the file (without extension).

## API Reference

### Core Functions

#### `setEntityLodComponent(entityId:)`
Registers an LOD component on an entity. Call this before adding LOD levels.

```swift
setEntityLodComponent(entityId: tree)
```

#### `addLODLevel(entityId:lodIndex:fileName:withExtension:maxDistance:completion:)`
Adds a single LOD level to an entity.

**Parameters:**
- `entityId`: The entity to add LOD to
- `lodIndex`: LOD level index (0 = highest detail)
- `fileName`: Name of the mesh file (without extension)
- `withExtension`: File extension (e.g., "untold")
- `maxDistance`: Maximum camera distance for this LOD
- `completion`: Optional callback when loading completes

```swift
addLODLevel(
    entityId: tree,
    lodIndex: 0,
    fileName: "tree_LOD0",
    withExtension: "untold",
    maxDistance: 50.0
) { success in
    if success {
        print("LOD0 loaded successfully")
    }
}
```

#### `addLODLevels(entityId:levels:completion:)`
Adds multiple LOD levels with a single completion handler. Useful when you need to wait for all LOD levels to load.

**Parameters:**
- `entityId`: The entity to add LOD levels to
- `levels`: Array of tuples: `(lodIndex, fileName, withExtension, maxDistance, screenPercentage)`
- `completion`: Called when ALL levels finish loading (true only if all succeeded)

```swift
addLODLevels(entityId: tree, levels: [
    (0, "tree_LOD0", "untold", 50.0, 0.0),
    (1, "tree_LOD1", "untold", 100.0, 0.0),
    (2, "tree_LOD2", "untold", 200.0, 0.0)
]) { success in
    if success {
        print("All LODs loaded")
    }
}
```

#### `removeLODLevel(entityId:lodIndex:)`
Removes a specific LOD level from an entity.

```swift
removeLODLevel(entityId: tree, lodIndex: 2)
```

#### `replaceLODLevel(entityId:lodIndex:fileName:withExtension:maxDistance:completion:)`
Replaces an existing LOD level with a new mesh.

```swift
replaceLODLevel(
    entityId: tree,
    lodIndex: 1,
    fileName: "tree_LOD1_new",
    withExtension: "untold",
    maxDistance: 100.0
)
```

#### `getLODLevelCount(entityId:) -> Int`
Returns the number of LOD levels for an entity.

```swift
let count = getLODLevelCount(entityId: tree)
print("Entity has \(count) LOD levels")
```

---

## Advanced Usage

### Custom Distance Thresholds

Adjust distances based on your scene scale:

```swift
// Small scene (indoor environment)
addLODLevel(entityId: prop, lodIndex: 0, fileName: "prop_LOD0", withExtension: "untold", maxDistance: 10.0)
addLODLevel(entityId: prop, lodIndex: 1, fileName: "prop_LOD1", withExtension: "untold", maxDistance: 20.0)

// Large scene (outdoor landscape)
addLODLevel(entityId: mountain, lodIndex: 0, fileName: "mountain_LOD0", withExtension: "untold", maxDistance: 500.0)
addLODLevel(entityId: mountain, lodIndex: 1, fileName: "mountain_LOD1", withExtension: "untold", maxDistance: 1000.0)
addLODLevel(entityId: mountain, lodIndex: 2, fileName: "mountain_LOD2", withExtension: "untold", maxDistance: 2000.0)
```

### LOD Configuration

Configure global LOD behavior:

```swift
// Adjust LOD bias (higher = switch to lower detail sooner)
LODConfig.shared.lodBias = 1.5  // Performance mode
LODConfig.shared.lodBias = 0.75 // Quality mode

// Adjust hysteresis to prevent flickering
LODConfig.shared.hysteresis = 10.0

// Enable fade transitions between LODs - Not yet implemented
LODConfig.shared.enableFadeTransitions = true
LODConfig.shared.fadeTransitionTime = 0.5 // seconds
```

### Forced LOD Override

Force a specific LOD level (useful for debugging):

```swift
if let lodComponent = scene.get(component: LODComponent.self, for: tree) {
    lodComponent.forcedLOD = 2  // Always show LOD2
    // lodComponent.forcedLOD = nil  // Resume automatic LOD selection
}
```

### Programmatic LOD Management

```swift
// Create entity with LOD component
let rock = createEntity()
setEntityLodComponent(entityId: rock)

// Add LODs dynamically based on performance
let lodFiles = ["rock_LOD0", "rock_LOD1", "rock_LOD2"]
let distances: [Float] = [30.0, 60.0, 120.0]

for (index, fileName) in lodFiles.enumerated() {
    addLODLevel(
        entityId: rock,
        lodIndex: index,
        fileName: fileName,
        withExtension: "untold",
        maxDistance: distances[index]
    )
}

// Check LOD count
let lodCount = getLODLevelCount(entityId: rock)
print("Rock has \(lodCount) LOD levels")

// Remove highest detail LOD on low-end hardware
if isLowEndDevice {
    removeLODLevel(entityId: rock, lodIndex: 0)
}
```

---

## Best Practices

### Recommended LOD Counts
- **Small props**: 2-3 LODs
- **Characters**: 3-4 LODs
- **Vehicles**: 3-4 LODs
- **Buildings**: 4-5 LODs
- **Terrain**: 5-8 LODs

### Polygon Reduction Guidelines
- **LOD0** (full detail): 100% polygons
- **LOD1**: ~50% polygon reduction
- **LOD2**: ~75% polygon reduction
- **LOD3**: ~90% polygon reduction or billboard

### Distance Thresholds
Base distances on object importance and size:
- **Hero objects**: Longer high-detail distance
- **Background objects**: Shorter high-detail distance
- **Large objects**: Visible from farther away, need more LODs

### Performance Tips
1. Always use async loading (`setEntityMeshAsync`) for better performance
2. Keep LOD0 for objects within 50 units of camera
3. Use billboards or impostors for very distant objects (LOD3+)
4. Test LOD transitions in-game to ensure smooth visual quality
5. Use `forcedLOD` during development to preview each LOD level

## Troubleshooting

### LODs Not Switching
- Verify LOD component is registered: `hasComponent(entityId: tree, componentType: LODComponent.self)`
- Check distance thresholds are set correctly
- Ensure camera has `CameraComponent` and is active

### Visual Popping Between LODs
- Increase `LODConfig.shared.hysteresis` value
- Enable fade transitions: `LODConfig.shared.enableFadeTransitions = true` - not yet implemented
- Adjust LOD bias for smoother transitions

### File Not Found Errors
- Verify file organization follows the subdirectory structure
- Check file names match exactly (case-sensitive)
- Ensure files are in the correct `GameData/Models/` path

### Performance Issues
- Reduce number of LOD levels for less important objects
- Increase distance thresholds to switch LODs sooner
- Use LOD bias > 1.0 for performance mode

## Example: Complete LOD Setup

```swift
import UntoldEngine

// Create multiple trees with LODs
var trees: [EntityID] = []

for i in 0..<10 {
    let tree = createEntity()
    setEntityName(entityId: tree, name: "Tree_\(i)")
    
    // Position trees
    translateTo(entityId: tree, position: simd_float3(Float(i * 10), 0, 0))
    
    // Add LOD component
    setEntityLodComponent(entityId: tree)
    
    // Add 4 LOD levels
    addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "untold", maxDistance: 50.0)
    addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "untold", maxDistance: 100.0)
    addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "untold", maxDistance: 200.0)
    addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "untold", maxDistance: 400.0)
    
    trees.append(tree)
}

// Configure LOD system for this scene
LODConfig.shared.lodBias = 1.2  // Slightly favor performance
LODConfig.shared.hysteresis = 8.0  // Prevent flickering

print("Created \(trees.count) trees with LOD support")
```

## Example: LOD with Static Batching

When combining LOD with static batching, ensure transforms and batching setup happen **after** meshes are loaded:

```swift
import UntoldEngine

private func setupLODWithBatching() {
    var loadedCount = 0
    let totalTrees = 20
    
    for i in 0..<totalTrees {
        let tree = createEntity()
        setEntityName(entityId: tree, name: "Tree_\(i)")
        
        // Capture position for the closure
        let x = Float(i % 5) * 10.0
        let z = Float(i / 5) * 10.0
        
        // Add LOD component BEFORE loading levels
        setEntityLodComponent(entityId: tree)
        
        // Load all LOD levels with completion handler
        addLODLevels(entityId: tree, levels: [
            (0, "tree_LOD0", "untold", 50.0, 0.0),
            (1, "tree_LOD1", "untold", 100.0, 0.0),
            (2, "tree_LOD2", "untold", 200.0, 0.0)
        ]) { success in
            if success {
                // Apply transform AFTER mesh is loaded
                translateTo(entityId: tree, position: simd_float3(x, 0, z))
                
                // Mark for batching
                setEntityStaticBatchComponent(entityId: tree)
            }
            
            // Track completion
            loadedCount += 1
            if loadedCount == totalTrees {
                // All trees loaded - generate batches
                enableBatching(true)
                generateBatches()
                print("\(totalTrees) trees configured with LOD + Batching")
            }
        }
    }
}
```

**Key points:**
1. Call `setEntityLodComponent()` before loading LOD levels
2. Apply transforms (`translateTo`) inside the completion handler
3. Call `setEntityStaticBatchComponent()` after mesh is loaded
4. Call `generateBatches()` only after all entities are ready
