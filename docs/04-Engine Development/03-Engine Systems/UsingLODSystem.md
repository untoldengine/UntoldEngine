---
id: lodsystem
title: LOD System
sidebar_position: 10
---

# LOD (Level of Detail) System - Usage Guide

The Untold Engine provides a flexible LOD system for optimizing rendering performance by displaying different mesh details based on camera distance.

## Overview

The LOD system allows you to:
- Add multiple levels of detail to any entity
- Automatically switch between LOD levels based on distance
- Customize distance thresholds for each LOD level
- Configure LOD behavior (bias, hysteresis, fade transitions)

## Quick Start

### Basic LOD Setup

```swift
// Create entity
let tree = createEntity()

// Add LOD component
setEntityLodComponent(entityId: tree)

// Add LOD levels (from highest to lowest detail)
addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "usdz", maxDistance: 50.0)
addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "usdz", maxDistance: 100.0)
addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "usdz", maxDistance: 200.0)
addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "usdz", maxDistance: 400.0)
```

**How it works:**
- LOD0 (highest detail) renders when camera is < 50 units away
- LOD1 renders between 50-100 units
- LOD2 renders between 100-200 units
- LOD3 (lowest detail) renders beyond 200 units

### With Initial Mesh Loading

You can also load an initial mesh synchronously before adding LOD levels:

```swift
let tree = createEntity()

// Load initial mesh synchronously (shows immediately)
setEntityMesh(entityId: tree, filename: "tree_LOD0", withExtension: "usdz")

// Add LOD component
setEntityLodComponent(entityId: tree)

// Add LOD levels (will replace initial mesh when ready)
addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "usdz", maxDistance: 50.0)
addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "usdz", maxDistance: 100.0)
addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "usdz", maxDistance: 200.0)
addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "usdz", maxDistance: 400.0)
```

### With Async Mesh Loading

For better performance, use async loading:

```swift
let tree = createEntity()

// Load initial mesh asynchronously
setEntityMeshAsync(entityId: tree, filename: "tree_LOD0", withExtension: "usdz") { success in
    if success {
        print("Initial mesh loaded")
    }
}

// Add LOD component
setEntityLodComponent(entityId: tree)

// Add LOD levels
addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "usdz", maxDistance: 50.0)
addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "usdz", maxDistance: 100.0)
addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "usdz", maxDistance: 200.0)
addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "usdz", maxDistance: 400.0)
```

## File Organization

LOD files should be organized in subdirectories:

```
GameData/
└── Models/
    ├── tree_LOD0/
    │   └── tree_LOD0.usdz
    ├── tree_LOD1/
    │   └── tree_LOD1.usdz
    ├── tree_LOD2/
    │   └── tree_LOD2.usdz
    └── tree_LOD3/
        └── tree_LOD3.usdz
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
- `withExtension`: File extension (e.g., "usdz")
- `maxDistance`: Maximum camera distance for this LOD
- `completion`: Optional callback when loading completes

```swift
addLODLevel(
    entityId: tree,
    lodIndex: 0,
    fileName: "tree_LOD0",
    withExtension: "usdz",
    maxDistance: 50.0
) { success in
    if success {
        print("LOD0 loaded successfully")
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
    withExtension: "usdz",
    maxDistance: 100.0
)
```

#### `getLODLevelCount(entityId:) -> Int`
Returns the number of LOD levels for an entity.

```swift
let count = getLODLevelCount(entityId: tree)
print("Entity has \(count) LOD levels")
```

## Advanced Usage

### Custom Distance Thresholds

Adjust distances based on your scene scale:

```swift
// Small scene (indoor environment)
addLODLevel(entityId: prop, lodIndex: 0, fileName: "prop_LOD0", withExtension: "usdz", maxDistance: 10.0)
addLODLevel(entityId: prop, lodIndex: 1, fileName: "prop_LOD1", withExtension: "usdz", maxDistance: 20.0)

// Large scene (outdoor landscape)
addLODLevel(entityId: mountain, lodIndex: 0, fileName: "mountain_LOD0", withExtension: "usdz", maxDistance: 500.0)
addLODLevel(entityId: mountain, lodIndex: 1, fileName: "mountain_LOD1", withExtension: "usdz", maxDistance: 1000.0)
addLODLevel(entityId: mountain, lodIndex: 2, fileName: "mountain_LOD2", withExtension: "usdz", maxDistance: 2000.0)
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
        withExtension: "usdz",
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
    addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "usdz", maxDistance: 50.0)
    addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "usdz", maxDistance: 100.0)
    addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "usdz", maxDistance: 200.0)
    addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "usdz", maxDistance: 400.0)
    
    trees.append(tree)
}

// Configure LOD system for this scene
LODConfig.shared.lodBias = 1.2  // Slightly favor performance
LODConfig.shared.hysteresis = 8.0  // Prevent flickering
LODConfig.shared.enableFadeTransitions = true

print("Created \(trees.count) trees with LOD support")
```

