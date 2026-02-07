# Streaming → LOD → Batching Integration

This document describes how the three rendering optimization systems work together in Untold Engine.

## Overview

Four systems collaborate to optimize rendering performance:

| System | Purpose | Optimizes |
|--------|---------|----------|
| **Streaming Region** | Volume-based streaming (load/unload zones) | Memory usage (coarse) |
| **Geometry Streaming** | Entity-based streaming (per-object radius) | Memory usage (fine) |
| **LOD System** | Selects which detail level to render | GPU triangle count |
| **Static Batching** | Combines meshes into single draw calls | CPU draw call overhead |

### Two Streaming Approaches

| Approach | System | Best For |
|----------|--------|----------|
| **Volume-based** | StreamingRegionManager | Level chunks, rooms, zones - load many assets at once |
| **Entity-based** | GeometryStreamingSystem | Scattered props, hero objects - fine-grained control |

Both can be used together: regions load chunks, then individual entities use per-entity streaming + LOD.

## Key Principles

1. **Streaming decides what exists in memory** - It is the source of truth for mesh residency
2. **LOD decides which representation is active** - From what's available in memory
3. **Batching consumes the active LOD meshes** - Produces draw batches for rendering
4. **Never batch across different LOD levels** - Each LOD level gets its own batch
5. **Never block the render thread** - LOD uses fallbacks if mesh isn't resident

## Frame Pipeline

Each frame, the systems execute in this order:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FRAME LOOP                                   │
└─────────────────────────────────────────────────────────────────────┘
                                │
┌───────────────┐               │
│    REGION     │               │
│   STREAMING   │───────────────┤
│   (tick 0)    │    events     │
└───────────────┘               │
     ┌──────────────────────────┼──────────────────────────┐
     │                          │                          │
     ▼                          ▼                          ▼
┌─────────────┐          ┌─────────────┐          ┌─────────────┐
│  GEOMETRY   │ ──────▶  │     LOD     │ ──────▶  │  BATCHING   │
│  STREAMING  │  events  │   (tick 2)  │  events  │   (tick 3)  │
│   (tick 1)  │          └─────────────┘          └─────────────┘
└─────────────┘                │                        │
      │                        │ emits:                 │ rebuilds only
      │ emits:                 │ EntityLODChanged       │ affected batches
      │ AssetResidency         │ Event                  │
      │ ChangedEvent           │                        │
      ▼                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           RENDER                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Execution

```swift
// In UntoldEngine.runFrame():

// 0. Region streaming (volume-based, loads entire zones)
StreamingRegionManager.shared.update(cameraPosition, deltaTime)
// → Queues AssetResidencyChangedEvent for each entity in loaded/unloaded regions

// 1. Geometry streaming (entity-based, per-object radius)
GeometryStreamingSystem.shared.update(cameraPosition, deltaTime)
// → Queues AssetResidencyChangedEvent for each load/unload

// 2. LOD selection (queries residency, picks best available)
LODSystem.shared.update(deltaTime)
// → Queues EntityLODChangedEvent when LOD changes

// 3. Flush events (subscribers receive events)
SystemEventBus.shared.flushEvents()

// 4. Batching patch (consumes events, rebuilds dirty batches)
BatchingSystem.shared.tick()

// 5. Stats monitoring
SystemIntegrationMonitor.shared.tick()

// 6. Render
render()
```

## Data Ownership

| System | Owns | Reads | Mutates |
|--------|------|-------|--------|
| **Region Streaming** | Region definitions, region state | Camera position, AABB bounds | `StreamingRegion.state`, entities |
| **Geometry Streaming** | Mesh cache, residency state | Entity distance | `StreamingComponent.state` |
| **LOD** | LOD selection per entity | Residency state, distance | `LODComponent.currentLOD`, `RenderComponent.mesh` |
| **Batching** | Batch groups, GPU buffers | LOD selection, mesh data | `BatchGroup` membership |

## Event System

### Events

```swift
// Emitted by GeometryStreamingSystem when mesh loads/unloads
struct AssetResidencyChangedEvent {
    let entityId: EntityID
    let assetURL: URL
    let meshName: String
    let isResident: Bool  // true = loaded, false = evicted
}

// Emitted by LODSystem when entity's active LOD changes
struct EntityLODChangedEvent {
    let entityId: EntityID
    let previousLODIndex: Int
    let newLODIndex: Int
    let meshAssetID: String
}
```

### Subscriptions

| Event | Publisher | Subscribers |
|-------|-----------|------------|
| `AssetResidencyChanged` | Streaming | Batching (to invalidate/rebuild) |
| `EntityLODChanged` | LOD | Batching (to update membership) |

## LOD Fallback Logic

When LOD selects a detail level, it checks if that mesh is actually in memory:

```
LOD wants LOD0 (high detail) at distance 10m
  │
  ├─ Is LOD0 mesh resident? 
  │     YES → use LOD0 ✓
  │     NO  → request streaming (async)
  │           └─ Is LOD1 mesh resident?
  │                 YES → use LOD1 (fallback) ✓
  │                 NO  → Is LOD2 mesh resident?
  │                       YES → use LOD2 (fallback) ✓
  │                       NO  → keep current LOD ✓
```

**Key invariant**: Rendering never stalls waiting for a mesh to load.

### LODComponent Fields

```swift
class LODComponent {
    var lodLevels: [LODLevel]     // Available LOD levels
    var desiredLOD: Int           // What we want based on distance
    var currentLOD: Int           // What we're actually using
    var isUsingFallback: Bool     // true if currentLOD != desiredLOD
    var activeMeshAssetID: String // For batching key generation
}
```

## Batching Integration

### Batch Key

Batches are keyed by **material + LOD level**:

```swift
let batchKey = "\(materialHash)_LOD\(lodIndex)"
```

This ensures:
- Same material, different LOD → different batches
- Same LOD, different material → different batches
- Same material + same LOD → same batch ✓

### Incremental Updates

When LOD changes for a batched entity:

1. `EntityLODChangedEvent` is emitted
2. Batching receives event via subscription
3. Entity is removed from old batch (marked dirty)
4. Entity is added to new batch (marked dirty)
5. On `tick()`, dirty batches are rebuilt

```swift
// BatchingSystem handles LOD change:
func handleLODChange(_ event: EntityLODChangedEvent) {
    if let batchInfo = entityToBatch[event.entityId] {
        // Mark for removal from old batch
        pendingEntityRemovals.append((event.entityId, batchInfo.batchId))
        // Mark for addition to new batch
        pendingEntityAdditions.append(event.entityId)
        dirtyBatchIds.insert(batchInfo.batchId)
    }
}
```

## Streaming Eviction Handling

When streaming evicts a mesh that's currently in use:

1. Streaming emits `AssetResidencyChangedEvent(isResident: false)`
2. LOD will fall back to next available LOD on next frame
3. Batching removes entity from its batch immediately

```
Mesh M evicted by streaming
  │
  ├─ LOD: Next frame, finds M not resident → falls back
  │
  └─ Batching: Removes entity from batch → marks dirty
```

## Debug Monitoring

Enable debug logging to track system interactions:

```swift
SystemIntegrationMonitor.shared.enableLogging = true
```

Outputs per-second stats:
- Streaming loads/unloads
- LOD switches
- LOD fallbacks (when desired LOD unavailable)
- Batch rebuilds

Example output:
```
[Integration] Loads: 3, Unloads: 1, LOD switches: 5, Fallbacks: 2, Batch rebuilds: 1
```

## Component Compatibility

### Valid Combinations

| Entity Type | Components | Notes |
|-------------|------------|-------|
| Static batched | `StaticBatchComponent` | No LOD, no streaming |
| LOD entity | `LODComponent` | Can combine with streaming |
| Streamed entity | `StreamingComponent` | Can combine with LOD |
| Streamed + LOD | `StreamingComponent` + `LODComponent` | Full integration |

### Recommendations

- **Static background props**: Use `StaticBatchComponent` only
- **Hero objects**: Use `LODComponent` for quality at distance
- **Large open worlds**: Use `StreamingComponent` for memory management
- **Distant detail objects**: Use `StreamingComponent` + `LODComponent`

## Usage Example

This example shows how to set up an entity that uses all three systems together:

```swift
import UntoldEngine

private func setupOptimizedEntity() {
    let dungeon = createEntity()
    setEntityName(entityId: dungeon, name: "dungeon")
    
    // 1. Load mesh asynchronously
    setEntityMeshAsync(entityId: dungeon, filename: "dungeon", withExtension: "usdz") { success in
        guard success else {
            print("Failed to load dungeon mesh")
            return
        }
        
        print("Dungeon loaded successfully")
        
        // Apply transforms
        rotateTo(entityId: dungeon, angle: 90, axis: simd_float3(1.0, 0.0, 0.0))
        
        // 2. Enable geometry streaming (memory management)
        enableStreaming(
            entityId: dungeon,
            streamingRadius: 200.0,  // Load when camera is within 200 units
            unloadRadius: 300.0,     // Unload when camera is beyond 300 units
            priority: 10             // Higher priority loads first
        )
        
        // 3. Add LOD component for distance-based detail switching
        setEntityLodComponent(entityId: dungeon)
        
        // Add LOD levels (high detail → low detail)
        addLODLevel(
            entityId: dungeon,
            lodIndex: 0,
            fileName: "dungeon_LOD0",
            withExtension: "usdz",
            maxDistance: 50.0  // Full detail within 50 units
        )
        addLODLevel(
            entityId: dungeon,
            lodIndex: 1,
            fileName: "dungeon_LOD1",
            withExtension: "usdz",
            maxDistance: 100.0  // Medium detail 50-100 units
        )
        addLODLevel(
            entityId: dungeon,
            lodIndex: 2,
            fileName: "dungeon_LOD2",
            withExtension: "usdz",
            maxDistance: 200.0  // Low detail 100-200 units
        )
        
        // 4. Mark as static for batching (reduces draw calls)
        setEntityStaticBatchComponent(entityId: dungeon)
        
        // 5. Enable batching system and generate batches
        enableBatching(true)
        generateBatches()
        
        print("Entity configured with Streaming + LOD + Batching")
    }
}
```

### What This Achieves

| System | Benefit |
|--------|---------|
| **Streaming** | Mesh unloads from memory when camera is >300 units away, reloads when <200 units |
| **LOD** | GPU renders fewer triangles as camera moves away (LOD0 → LOD1 → LOD2) |
| **Batching** | Multiple entities with same material+LOD combined into single draw call |

### Runtime Behavior

```
Camera at 30 units:
  - Streaming: Mesh resident ✓
  - LOD: LOD0 (full detail) active
  - Batching: Entity in "material_X_LOD0" batch

Camera at 80 units:
  - Streaming: Mesh resident ✓
  - LOD: LOD1 (medium detail) active → triggers batch rebuild
  - Batching: Entity moved to "material_X_LOD1" batch

Camera at 250 units:
  - Streaming: Mesh evicted (>200 units) → AssetResidencyChangedEvent
  - LOD: Falls back to coarser LOD if available
  - Batching: Entity removed from batch

Camera returns to 150 units:
  - Streaming: Mesh loads async (<200 units)
  - LOD: Uses fallback until LOD2 loads, then switches
  - Batching: Entity re-added to appropriate batch
```

### Simpler Setup (Streaming Only)

If you only need streaming without LOD or batching:

```swift
private func setupStreamedEntity() {
    let stadium = createEntity()
    
    setEntityMeshAsync(entityId: stadium, filename: "stadium", withExtension: "usdz") { success in
        if success {
            rotateTo(entityId: stadium, angle: 90, axis: simd_float3(1.0, 0.0, 0.0))
            
            // Just enable streaming
            enableStreaming(
                entityId: stadium,
                streamingRadius: 200.0,
                unloadRadius: 300.0,
                priority: 10
            )
        }
    }
}
```

### LOD + Batching (No Streaming)

Streaming is optional. LOD and Batching work together without any streaming system. This is useful when:
- Memory is not a constraint
- All assets fit comfortably in VRAM
- You want simpler setup without async loading concerns

```swift
import UntoldEngine

private func setupLODWithBatching() {
    for i in 0..<20 {
        let tree = createEntity()
        setEntityName(entityId: tree, name: "Tree_\(i)")
        
        // Capture position values for the closure
        let x = Float(i % 5) * 10.0
        let z = Float(i / 5) * 10.0
        
        setEntityLodComponent(entityId: tree)
        
        addLODLevels(entityId: tree, levels: [
            (0, "tree_LOD0", "usdz", 50.0, 0.0),
            (1, "tree_LOD1", "usdz", 100.0, 0.0),
            (2, "tree_LOD2", "usdz", 200.0, 0.0)
        ]) { success in
            if success {
                // Apply transform AFTER mesh is loaded
                translateTo(entityId: tree, position: simd_float3(x, 0, z))
                setEntityStaticBatchComponent(entityId: tree)
            }
        }
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        enableBatching(true)
        generateBatches()
        print("20 trees configured with LOD + Batching")
    }
}
```

#### How It Works (Without Streaming)

```
LODSystem.update():
  │
  ├─ Calculate distance → desiredLOD = 1
  │
  ├─ isLODResident(1)?
  │    └─ Checks: !lodLevels[1].mesh.isEmpty
  │    └─ Mesh was loaded via addLODLevel() → returns TRUE
  │
  ├─ Use LOD1 directly (no fallback needed)
  │
  └─ LOD changed? → Emit EntityLODChangedEvent
                         │
                         ▼
                    BatchingSystem receives event
                         │
                         └─ Move entity to new batch
```

Since all LOD meshes are pre-loaded, they are always "resident" (mesh array is non-empty). The LOD system selects based purely on distance, and batching updates automatically via events.

#### Runtime Behavior (No Streaming)

```
Camera at 30 units:
  - LOD: LOD0 (full detail) active
  - Batching: Entity in "material_tree_LOD0" batch

Camera at 70 units:
  - LOD: LOD1 (medium detail) active
  - Event: EntityLODChangedEvent emitted
  - Batching: Entity moved to "material_tree_LOD1" batch

Camera at 150 units:
  - LOD: LOD2 (low detail) active
  - Event: EntityLODChangedEvent emitted
  - Batching: Entity moved to "material_tree_LOD2" batch
```

All 20 trees with the same material and LOD level get batched into a single draw call, and batches update incrementally as LOD switches occur.

## File Locations

| File | Purpose |
|------|---------|
| `Systems/SystemEvents.swift` | Event bus and event types |
| `Systems/GeometryStreamingSystem.swift` | Mesh streaming logic |
| `Systems/LODSystem.swift` | LOD selection with fallback |
| `Systems/BatchingSystem.swift` | Incremental batch updates |
| `ECS/Components.swift` | `LODComponent`, `StreamingComponent`, `StaticBatchComponent` |
| `Renderer/UntoldEngine.swift` | Frame loop with system ordering |
