# MeshResourceManager

`MeshResourceManager` is the shared GPU mesh cache for immediate and
cache-backed `.untold` loads. It caches all renderable mesh arrays produced from
one `.untold` file, tracks which entities retain each named mesh, and evicts
unused cached geometry under memory pressure.

It is not the OCC CPU registry. Tile-owned OCC stubs use
`ProgressiveAssetLoader` and `CPURuntimeEntry`.

---

## Core Data Model

```
resources:      URL -> MeshResource       (one cache entry per .untold file)
entityToMesh:   EntityID -> (URL, name)   (which cached mesh an entity retains)
```

A `MeshResource` stores all renderable mesh groups from a `.untold` file:

```swift
struct MeshResource {
    var meshesByName: [String: [Mesh]]
    var refCountByName: [String: Int]
    var totalMemorySize: Int
    var sourceURL: URL
    var lastAccessFrame: Int
}
```

The cache key is the source URL. The per-mesh key is the runtime asset name.

---

## Loading

When a caller requests a mesh:

```swift
let meshes = await MeshResourceManager.shared.loadMesh(url: url, meshName: "building_01")
```

The manager:

1. Checks `resources[url]` for a cached mesh group.
2. Uses a single-flight gate so concurrent requests for the same URL share one load.
3. Loads the `.untold` file through `NativeFormatLoader`.
4. Converts every renderable `RuntimeAssetNode` to `[Mesh]`.
5. Stores the result in `meshesByName`.

Only `.untold` files are supported by this runtime cache.

---

## Reference Counting

When an entity begins using a cached mesh:

```swift
MeshResourceManager.shared.retain(url: url, meshName: "building_01", for: entityId)
```

This records the entity-to-mesh mapping and increments the mesh name's reference
count. When the entity unloads or is destroyed:

```swift
MeshResourceManager.shared.release(entityId: entityId)
```

The mapping is removed and the reference count is decremented. Cache entries
with live references are not eligible for eviction.

---

## Cache Prewarming

Immediate registration paths can call:

```swift
MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshArrays)
```

This seeds the cache with meshes that were already loaded during registration,
so later cache-backed requests do not reparse the file.

---

## Eviction

Three cleanup paths are available:

| Method | Purpose |
|---|---|
| `evict(url:)` | Force-remove one URL if it has no live refs |
| `evictUnused()` | Sweep all zero-ref cache entries |
| `evictToFreeMemory(targetBytes:)` | LRU eviction of zero-ref entries until the target is reached |

Eviction calls `mesh.cleanUp()` on cached meshes to release Metal resources.

---

## Relationship to Streaming

`GeometryStreamingSystem` uses two residency layers:

| Path | CPU/GPU source |
|---|---|
| Immediate/full-load `.untold` geometry | `MeshResourceManager` cache and entity-local mesh copies |
| Tile-owned OCC stubs | `ProgressiveAssetLoader.CPURuntimeEntry` uploaded on demand |

Full-load tile geometry is not tracked in `loadedStreamingEntities`, so ordinary
OCC LRU eviction does not free it. Tile unload or
`GeometryStreamingSystem.forceUnloadAllParsedTiles()` is responsible for
tearing down full-load tile geometry.
