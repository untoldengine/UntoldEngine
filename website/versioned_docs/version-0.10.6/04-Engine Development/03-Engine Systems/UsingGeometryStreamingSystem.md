---
id: geometrystreaminggsystem
title: Geometry Streaming System
sidebar_position: 13
---

# Geometry Streaming System

The Geometry Streaming System dynamically loads and unloads geometry based on the camera's proximity to objects. This system is essential for large-scale scenes where loading all geometry at once would exceed available memory or cause performance issues.

## How It Works

The streaming system monitors the distance between the camera and entities that have streaming enabled. Based on configurable radius values, the system automatically:

1. **Loads geometry** when the camera moves within the streaming radius
2. **Keeps geometry loaded** while the camera remains between the streaming and unload radii
3. **Unloads geometry** when the camera moves beyond the unload radius

This creates a "bubble" of loaded geometry around the camera that moves with it through the scene.

## When to Use Geometry Streaming

**Ideal for:**
- Large open-world environments with distant objects
- Scenes where not all objects are visible simultaneously
- Memory-constrained scenarios
- Games with large view distances (forests, cities, landscapes)

**Not recommended for:**
- Small scenes where all objects fit comfortably in memory
- Objects that are always visible
- Dynamic objects that move frequently
- Critical gameplay objects that must always be loaded

## Basic Usage

Here's a simple example of enabling streaming for a single entity:

```swift
private func setupStreaming(){
    let stadium = createEntity()
    setEntityMeshAsync(entityId: stadium, filename: "stadium", withExtension: "usdz") { success in
        if success {
            
            print("Scene loaded successfully")

            enableStreaming(
                entityId: stadium,
                streamingRadius: 250.0, // Load when within 250 units
                unloadRadius: 350.0, // Unload when beyond 350 units
                priority: 10
            )
        }
    }
}
```

### Important Notes

1. **Load mesh first**: Always call `setEntityMeshAsync()` before enabling streaming
2. **Use completion callback**: Enable streaming inside the completion callback to ensure the mesh is loaded
3. **Async loading**: The `setEntityMeshAsync()` function loads the mesh asynchronously, preventing frame drops

## Parameters Explained

### `streamingRadius`
The distance from the camera at which geometry will be loaded.
- Objects closer than this distance will have their geometry loaded
- Should be set based on your camera's view distance and scene requirements
- **Typical values**: 100-500 units depending on object size and importance

### `unloadRadius`
The distance from the camera at which geometry will be unloaded.
- Must be **larger** than `streamingRadius` to create a buffer zone
- Prevents "thrashing" (rapid loading/unloading as camera moves near the boundary)
- **Recommended**: At least 50-100 units larger than `streamingRadius`

### `priority`
Determines the loading order when multiple objects need to be streamed.
- Higher values = loaded first
- Lower values = loaded last
- **Range**: Typically 1-10, but can be any positive integer
- **Usage**:
  - High priority (8-10): Important landmarks, gameplay-critical objects
  - Medium priority (4-7): Standard environment objects
  - Low priority (1-3): Background details, distant decorations

## Radius Configuration Guidelines

Choosing the right radius values is crucial for optimal performance:

```
Camera Position
    |
    |<-- streamingRadius (250) -->|<-- buffer zone -->|<-- unloadRadius (350) -->|
    |
    |    Geometry LOADS here      |  Stays loaded    |  Geometry UNLOADS here
```

### Example Configurations

**Small objects (trees, props):**
- `streamingRadius`: 150-250 units
- `unloadRadius`: 250-350 units
- Buffer: 100 units

**Medium objects (buildings, vehicles):**
- `streamingRadius`: 250-400 units  
- `unloadRadius`: 400-550 units
- Buffer: 150 units

**Large objects (stadiums, mountains):**
- `streamingRadius`: 500-1000 units
- `unloadRadius`: 700-1300 units
- Buffer: 200-300 units

## Combining with Other Systems

Geometry streaming works seamlessly with LOD and Batching systems:

- **LOD + Streaming**: Use LOD for quality management and streaming for memory management
- **Batching + Streaming**: Batches are automatically updated as geometry loads/unloads
- **All three together**: Optimal for large open-world scenes

See the [Combining LOD, Batching, and Streaming](./UsingLOD-Batching-Streaming.md) guide for detailed examples.

## Best Practices

1. **Test radius values**: Start conservative and adjust based on performance metrics
2. **Monitor memory**: Use profiling tools to ensure streaming is reducing memory usage
3. **Priority assignment**: Reserve high priorities for gameplay-critical objects
4. **Buffer zones**: Always maintain adequate buffer between streaming and unload radii
5. **Camera speed**: Faster-moving cameras may need larger streaming radii to prevent pop-in
6. **Position before streaming**: Set entity transforms before enabling streaming

## Common Issues

### Objects Not Loading
- Ensure `streamingRadius` is large enough for your camera's viewing distance
- Check that the mesh was loaded successfully in the completion callback
- Verify the entity has been positioned in the scene

### Geometry "Popping" In and Out
- Increase the buffer between `streamingRadius` and `unloadRadius`
- Consider using LOD to smooth transitions
- Adjust camera movement speed or increase radii

### Performance Issues
- Too many objects loading simultaneously: Adjust priorities to stagger loading
- Streaming radius too large: Reduce radius to load fewer objects
- Use LOD to reduce complexity of loaded geometry
