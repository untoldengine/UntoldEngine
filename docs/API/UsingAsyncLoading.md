---
id: asyncloadingsystem
title: Async Loading System
sidebar_position: 9
---

# Async USDZ Loading System - Usage Guide

## Overview

The async loading system allows you to load USDZ files with many models without blocking the main thread. The engine remains responsive during loading, and you can track progress for UI feedback.

## Features

✅ **Non-blocking loading** - Engine continues running while assets load  
✅ **Progress tracking** - Monitor loading progress per entity or globally  
✅ **Fallback meshes** - Automatically loads a cube if loading fails  
✅ **Backward compatible** - Old synchronous APIs still work  
✅ **Scene readiness guard** - Pause interaction while scene setup is unsafe  

---

## Scene Readiness Guard (Recommended)

The engine now provides global scene readiness APIs:

```swift
setSceneReady(_ ready: Bool)
isSceneReady() -> Bool
```

Use them to mark whether interaction systems should run safely.

### When to Use It

1. Use `setSceneReady(false)` before long or multi-step scene mutations.
2. Use `setSceneReady(true)` after the scene is stable.
3. Guard your input/update interaction paths with `isSceneReady()`.

### When You Usually Do NOT Need It

For standard `setEntityMeshAsync(...)` / streaming paths, the engine already uses loading gates internally.  
You mainly need `setSceneReady(...)` for custom workflows outside those built-in paths.

### Example: Custom Async Scene Setup

```swift
setSceneReady(false)

let root = createEntity()
setEntityMeshAsync(entityId: root, filename: "large_model", withExtension: "usdz") { isOutOfCore in
    if isOutOfCore {
        // Out-of-core: enable streaming so stubs start uploading
        GeometryStreamingSystem.shared.enabled = true
        enableStreaming(entityId: root, streamingRadius: 200, unloadRadius: 350, priority: 10)
    }
    // custom post-load work: hierarchy edits, batching, metadata pass, etc.
    setSceneReady(true)
}
```

### Example: Guard Input (XR or macOS)

```swift
func handleInput() {
    guard isSceneReady() else { return }
    // safe input logic
}
```

---

## Basic Usage

### Load Entity Mesh Asynchronously

```swift
// Create entity
let entityId = createEntity()

// Load mesh asynchronously (fire and forget)
setEntityMeshAsync(
    entityId: entityId,
    filename: "large_model",
    withExtension: "usdz"
)

// Engine continues running - mesh appears when loaded
```

### With Completion Callback

The completion Bool indicates how the asset was routed:

- `true` — asset was registered as out-of-core stubs; `GeometryStreamingSystem` must be enabled for anything to render.
- `false` — asset used the immediate path (all meshes GPU-resident) **or** loading failed (entity has a fallback cube).

```swift
let entityId = createEntity()

setEntityMeshAsync(
    entityId: entityId,
    filename: "large_model",
    withExtension: "usdz"
) { isOutOfCore in
    if isOutOfCore {
        // Asset was registered as streaming stubs — enable the system to start uploads.
        GeometryStreamingSystem.shared.enabled = true
        enableStreaming(entityId: entityId, streamingRadius: 200, unloadRadius: 350, priority: 10)
    } else {
        print("Model loaded immediately (small asset or error fallback)")
    }
}
```

### Controlling the Loading Path (`streamingPolicy`)

By default the engine automatically selects the loading path using `AssetProfiler`. You can override this with the `streamingPolicy` parameter:

```swift
// Always use the stub path — good for assets you know are large
setEntityMeshAsync(
    entityId: entityId,
    filename: "huge_city",
    withExtension: "usdz",
    streamingPolicy: .outOfCore
)

// Always upload immediately — good for small, always-visible assets
setEntityMeshAsync(
    entityId: entityId,
    filename: "small_prop",
    withExtension: "usdz",
    streamingPolicy: .immediate
)

// Let the engine decide (default — recommended for most cases)
setEntityMeshAsync(
    entityId: entityId,
    filename: "model",
    withExtension: "usdz",
    streamingPolicy: .auto
)
```

| Policy | Behavior |
|--------|----------|
| `.auto` (default) | `AssetProfiler` estimates geometry and texture bytes vs. the platform budget and independently selects `.streaming` or `.eager` for each domain |
| `.outOfCore` | Always stubs + geometry streaming; completion returns `true` |
| `.immediate` | Always direct GPU upload; completion returns `false` |

For `.auto`, the engine logs the classification so you can see exactly why each decision was made:

```
[AssetProfiler] 'dungeon3' (2.1 MB) → mixed | geo ~2.9 MB, tex ~6.2 MB | budget: 1024 MB | meshes: 410
[AssetProfiler] Policy → geometry: streaming, texture: eager (source: auto)
```

### Load Entire Scene Asynchronously

```swift
loadSceneAsync(
    filename: "complex_scene",
    withExtension: "usdz"
) { success in
    if success {
        print("Scene loaded with all entities")
    }
}
```

---

## Progress Tracking

### Check if Assets are Loading

```swift
Task {
    let isLoading = await AssetLoadingState.shared.isLoadingAny()
    if isLoading {
        print("Assets are currently loading...")
    }
}
```

### Get Loading Count

```swift
Task {
    let count = await AssetLoadingState.shared.loadingCount()
    print("Loading \(count) entities")
}
```

### Get Detailed Progress

```swift
Task {
    let (current, total) = await AssetLoadingState.shared.totalProgress()
    let percentage = Float(current) / Float(total) * 100
    print("Progress: \(percentage)% (\(current)/\(total) meshes)")
}
```

### Get Progress Summary String

```swift
Task {
    let summary = await AssetLoadingState.shared.loadingSummary()
    print(summary) // "Loading large_model.usdz: 5/20 meshes"
}
```

### Track Specific Entity

```swift
Task {
    if let progress = await AssetLoadingState.shared.getProgress(for: entityId) {
        print("\(progress.filename): \(progress.currentMesh)/\(progress.totalMeshes)")
        print("Percentage: \(progress.percentage * 100)%")
    }
}
```

---

## Untold Editor Integration

### Display Loading UI

```swift
// In your editor's update loop or UI
Task {
    if await AssetLoadingState.shared.isLoadingAny() {
        let summary = await AssetLoadingState.shared.loadingSummary()
        // Show loading indicator with summary text
        showLoadingIndicator(text: summary)
    } else {
        // Hide loading indicator
        hideLoadingIndicator()
    }
}
```

### Progress Bar Example

```swift
Task {
    let allProgress = await AssetLoadingState.shared.getAllProgress()
    
    for progress in allProgress {
        let percentage = progress.percentage * 100
        print("📦 \(progress.filename): \(Int(percentage))%")
        
        // Update UI progress bar
        updateProgressBar(
            id: progress.entityId,
            filename: progress.filename,
            percentage: percentage
        )
    }
}
```

---

## Error Handling

### Automatic Fallback

When async loading fails, a fallback cube mesh is automatically loaded:

```swift
setEntityMeshAsync(
    entityId: entityId,
    filename: "missing_file",
    withExtension: "usdz"
) { success in
    if !success {
        // Entity now has a cube mesh as fallback
        print("Loaded fallback cube")
    }
}
```

### Manual Error Handling

```swift
setEntityMeshAsync(
    entityId: entityId,
    filename: "model",
    withExtension: "usdz"
) { success in
    if !success {
        // Handle error - entity has fallback cube
        showErrorDialog("Failed to load model.usdz")
        
        // Optionally destroy entity or retry
        // destroyEntity(entityId: entityId)
    }
}
```

---

## Backward Compatibility

The old synchronous APIs still work unchanged:

```swift
// Old way (blocks main thread)
setEntityMesh(
    entityId: entityId,
    filename: "model",
    withExtension: "usdz"
)

// New way (non-blocking)
setEntityMeshAsync(
    entityId: entityId,
    filename: "model",
    withExtension: "usdz"
)
```

---

## Advanced Usage

### Loading Multiple Models

```swift
let entity1 = createEntity()
let entity2 = createEntity()
let entity3 = createEntity()

// All three load in parallel without blocking
setEntityMeshAsync(entityId: entity1, filename: "model1", withExtension: "usdz")
setEntityMeshAsync(entityId: entity2, filename: "model2", withExtension: "usdz")
setEntityMeshAsync(entityId: entity3, filename: "model3", withExtension: "usdz")

// Track total progress
Task {
    while await AssetLoadingState.shared.isLoadingAny() {
        let summary = await AssetLoadingState.shared.loadingSummary()
        print(summary)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    print("All models loaded!")
}
```

### Coordinate System Conversion

```swift
setEntityMeshAsync(
    entityId: entityId,
    filename: "blender_model",
    withExtension: "usdz",
    coordinateConversion: .forceZUpToYUp
)
```

---

## Implementation Details

### What Runs on Background Thread

- Reading USDZ file from disk
- Parsing MDL data structures
- Loading texture data
- Applying coordinate transformations

### What Runs on Main Thread

- Creating Metal resources (MTKMesh, MTLTexture)
- Registering ECS components
- Updating entity transforms
- Creating fallback meshes on error

### Thread Safety

All `AssetLoadingState` operations are thread-safe via Swift's actor model. You can safely query loading state from any thread.

---

## Performance Tips

1. **Prefer async for large files** (&gt;20 models or &gt;50MB)
2. **Use sync for small files** (1-5 models, &lt;10MB) - less overhead
3. **Batch loads together** - loading multiple files in parallel is efficient
4. **Monitor progress** - use for UI feedback during long loads

---

## Migration Guide

### Before (Blocking)

```swift
func loadGameAssets() {
    let entity = createEntity()
    setEntityMesh(entityId: entity, filename: "huge_scene", withExtension: "usdz")
    // Engine was frozen here ❌
}
```

### After (Non-blocking)

```swift
func loadGameAssets() {
    let entity = createEntity()
    setEntityMeshAsync(entityId: entity, filename: "huge_scene", withExtension: "usdz") {
        success in
        if success {
            print("Scene ready!")
        }
    }
    // Engine continues running ✅
}
```

---
