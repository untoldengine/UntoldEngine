# Texture Streaming System

`TextureStreamingSystem.swift` dynamically adjusts the resolution of textures on entities based on their distance from the camera. Instead of keeping every texture at full resolution all the time, it streams textures up or down as the player moves through the scene — saving GPU memory while keeping nearby geometry crisp.

---

## Scenario: A City Block with 500 Buildings

Imagine a tiled scene with a city block containing 500 buildings. Each building has a `RenderComponent` with meshes and submeshes, and each submesh has a `Material` containing up to four PBR textures:

- **Base Color** (sRGB)
- **Roughness** (linear)
- **Metallic** (linear)
- **Normal** (linear)

At full resolution, each building's textures might be 2048×2048 or larger. Loading all 500 buildings at full resolution at once would immediately exhaust GPU memory, causing frame drops or crashes.

The `TextureStreamingSystem` solves this by managing three quality tiers and promoting/demoting each building's textures as the camera moves.

---

## Quality Tiers

The system operates with three tiers, controlled by two distance thresholds:

| Tier | Condition | Max Dimension |
|------|-----------|---------------|
| **Full** | `distance <= upgradeRadius` (default 12m) | Native source resolution (nil cap) |
| **Medium** | `upgradeRadius < distance <= downgradeRadius` (default 20m) | `maxTextureDimension` (1024px on macOS, 768px on visionOS) |
| **Minimum** | `distance > downgradeRadius` | `minimumTextureDimension` (256px on macOS, 192px on visionOS) |

On first import, `TextureLoader` caps all textures at `minimumTextureDimension` (256px). The streaming system then only **upgrades** as the camera approaches — it never immediately downgrades a freshly-loaded entity.

---

## The Update Loop

Every frame, the game loop calls:

```swift
TextureStreamingSystem.shared.update(cameraPosition: ..., deltaTime: ...)
```

**Throttle:** The system only does real work every `updateInterval` seconds (default 0.2s). This prevents spending every frame scanning all entities.

**Concurrency cap:** At most `maxConcurrentOps` (default 3) async streaming operations run simultaneously. If all slots are busy, the tick exits early.

```
Frame N arrives
 └─ timeSinceLastUpdate += deltaTime
 └─ if < 0.2s → return (skip this frame)
 └─ availableSlots = maxConcurrentOps − activeOps.count
 └─ if 0 slots → return
 └─ Priority-0 burst pass: drain priorityEntities (tile-freshly-loaded)
 └─ Priority-1 pass: visible entities
 └─ Priority-2 pass: upgraded-but-not-visible entities
```

---

## Priority-0 Burst Pass: Freshly-Loaded Tile Entities

When a tile finishes loading, `GeometryStreamingSystem` calls `notifyEntitiesReady(_:)` to register the tile's render-descendant entity IDs as priority candidates:

```swift
TextureStreamingSystem.shared.notifyEntitiesReady(tileRenderIds)
```

On the next update tick, these entities are processed **before** the normal visible-entity pass. This ensures newly-streamed-in tile geometry gets its texture tier evaluated immediately — without waiting for the entity to appear in the frustum-culled visible set.

Entities tagged with `TileLODTagComponent` (HLOD and per-tile LOD proxy meshes) are skipped in this pass — they are transient geometry whose textures do not need progressive streaming.

The `priorityEntities` set is drained every tick and is also cleared by `reset()`.

---

## Priority Pass 1: Visible Entities

The system gets the current list of visible entity IDs (from the scene's frustum culling or visibility tracking) and iterates them first:

```
For each visible entity:
  1. Calculate distance from camera to entity's world-space bounding box center
  2. Determine desired tier via desiredMaxDimension(distance:)
  3. Build work items — which textures actually need to change
  4. If work items exist → scheduleResolutionChange(...)
  5. Decrement available slots
```

**City block example:** The camera is standing on the sidewalk in front of Building #42. Buildings #42 and #43 are within 12m (full tier). Buildings #44–#60 are within 20m (medium tier). The remaining 440 buildings are beyond 20m (minimum tier).

On this tick, the three available slots might be assigned to:
- Building #42: upgrade base color from 1024px → full resolution (2048px)
- Building #43: upgrade roughness from 1024px → full resolution
- Building #57: already at 1024px medium — no change needed, slot freed

---

## Priority Pass 2: Upgraded-but-Not-Visible Entities

After handling visible entities, the system checks its `upgradedEntities` set — entities whose textures are currently above the minimum tier. Even if they're off-screen now (the camera rotated away), they may still be nearby and deserve high-res textures so there's no quality drop when the camera rotates back.

```
For each entity in upgradedEntities that is NOT in the visible set:
  1. Calculate actual distance (do not assume minimum)
  2. Determine desired tier
  3. Build work items
  4. Schedule if needed
```

**City block example:** The camera rotated 90°, so Building #42 left the frustum. It is still 3m away. The system sees it in `upgradedEntities`, computes distance = 3m, desired tier = full — no downgrade is needed. It stays tracked.

If the camera then walks 20m away, Building #42's distance becomes 20m > 12m, so the system schedules a downgrade from full → 256px minimum.

---

## Building Work Items

`buildWorkItems(entityId:targetMaxDimension:)` inspects every texture slot on the entity's meshes and filters to only the ones that actually need to change:

```
For each mesh → submesh → material:
  For each texture type (baseColor, roughness, metallic, normal):
    currentMax = max(currentTexture.width, currentTexture.height)
    desiredMax = min(targetMaxDimension, sourceMaxDimension)

    if currentMax == desiredMax → skip (already correct)
    if upgrading but source is no bigger than current → skip

    else → emit StreamWorkItem(slot, direction, targetMaxDimension)
```

Each `StreamWorkItem` carries:
- The mesh/submesh index to know where to write back
- The direction (`.upgrade` or `.downgrade`)
- The target max dimension (`nil` means full source resolution)
- The texture source: either a decoded texture object or a `URL` on disk

---

## Scheduling: The Async Task

`scheduleResolutionChange(...)` is where the real work happens — but critically it happens **off the main thread**:

```
1. reserveOp(entityId) — mark entity as busy, return false if already active
2. Initialize MTLCommandQueue and MTKTextureLoader once (reused across ticks)
3. Spawn a Swift Task (async, off main thread)
```

Inside the `Task`, for each work item:

### Upgrade Path

```
loadSourceTexture(source, isSRGB:, loader:)
  └─ MTKTextureLoader loads the original texture source or URL from disk
  └─ options: shaderRead | pixelFormatView, generateMipmaps: true, SRGB flag
  └─ Returns a full-resolution MTLTexture

resampleTextureIfNeeded(sourceTexture, targetMaxDimension:, commandQueue:)
  └─ if targetMaxDimension == nil → return texture as-is (full res)
  └─ else → GPU downsample to targetMaxDimension
```

### Downgrade Path

```
resampleTextureIfNeeded(currentTexture, targetMaxDimension:, commandQueue:)
  └─ GPU downsample the already-loaded texture to targetMaxDimension
  └─ No disk I/O needed — current texture is the source
```

### GPU Resampling (`downsampleTexture`)

```
1. Compute target dimensions preserving aspect ratio
2. Allocate new MTLTexture (private storage, mipmapped)
3. Encode MPSImageBilinearScale → bilinear downsample
4. Encode BlitCommandEncoder.generateMipmaps(for:)
5. commit() and await completion via CheckedContinuation
```

Using `MPSImageBilinearScale` means the downsampled texture is high quality (bilinear filtering by the GPU shader), and the full mip chain is generated immediately so the renderer can use the appropriate mip level right away.

---

## Applying Results Back to ECS

After all textures in the task are loaded/resampled, execution returns to the main thread via `await MainActor.run { withWorldMutationGate { ... } }`:

```
For each LoadedTexture:
  1. textureViewMatchingSRGB(texture, wantSRGB:) — full-resolution textures only
     (targetMaxDimension == nil). Resampled (medium/minimum tier) textures skip
     this step; see "The sRGB View" below.

  2. updateMaterial(entityId:meshIndex:submeshIndex:) { material in
       // Three-tier level: .full (nil cap), .capped (medium), .minimum
       let streamLevel: TextureStreamingLevel = item.targetMaxDimension == nil
           ? .full
           : (item.targetMaxDimension! <= capturedMinimumDim ? .minimum : .capped)
       material.baseColor.texture = item.texture
       material.baseColorStreamingLevel = streamLevel
       // (same for roughness, metallic, normal)
     }

  3. BatchingSystem.shared.updateBatchMaterialInPlace(for: entityId) { batchMaterial in
       // Mirror the same three-tier level into the batch group's representative
       // material so the new texture is visible on the next frame with zero batch churn
     }
```

The `withWorldMutationGate` wrapper ensures the ECS is not mutated mid-render. The `BatchingSystem` update ensures batched draw calls reflect the new texture without rebuilding the batch.

After applying, the entity's membership in `upgradedEntities` is updated: if any texture is still above the minimum tier, the entity stays tracked.

---

## The sRGB View

`downsampleTexture` resamples via `MPSImageBilinearScale`. Metal disallows a compute-writable sRGB texture, so the destination is allocated in the linear sibling format (`mpsWritableFormat`). MPS reads an sRGB source through the texture unit, which auto-decodes sRGB → linear before filtering, and writes the raw (already-linear) result to the linear destination — no re-encoding occurs. **The output bytes are genuinely linear, not sRGB-encoded**, so the destination's linear pixel format is already correct as-is.

An earlier version of this code re-viewed that result back to the source's sRGB pixel format via `MTLTextureView`, on the assumption it was just restoring a format label MPS had stripped. That was wrong: it caused the material shader's hardware sRGB decode to run a second time on data that was already linear, visibly darkening/shifting base color textures on every downgrade or partial upgrade. Base color is the only texture type marked `isSRGB`, which is why the symptom was a pure color/tint shift with no effect on roughness, metallic, or normal maps — and why it only appeared once tier oscillation (e.g. `SpatialManipulationSystem` drags with amplified sensitivity) caused frequent resamples.

`textureViewMatchingSRGB` is now only invoked for textures returned at full source resolution (`targetMaxDimension == nil`), where it reconciles `loadSourceTexture`'s loader-assigned format — a case that's normally already a no-op since the loader honors the `.SRGB` option directly. Resampled (medium/minimum tier) textures are used as returned by `downsampleTexture`, unmodified.

---

## Full Walk-Through: Building #42 Goes from Far to Near

| Event | Action |
|-------|--------|
| Scene loads | All 500 buildings loaded at 256px (minimum tier) by TextureLoader |
| Camera 30m away from Building #42 | distance > 20m → already at minimum, no work |
| Camera walks to 18m away | distance 18m → desired = 1024px medium; upgrade scheduled |
| Upgrade task runs | Loads texture from source → 1024px; applied to ECS + batch |
| Building #42 added to `upgradedEntities` | (1024px > minimum) |
| Camera walks to 10m away | distance 10m ≤ 12m → desired = nil (full); upgrade scheduled |
| Upgrade task runs | Loads texture → full 2048px, no GPU resample needed; applied |
| Camera walks away to 15m | distance 15m > 12m × (1 + 0.15) → downgrade to 1024px; scheduled |
| Downgrade task runs | GPU resamples 2048px → 1024px; applied |
| Camera walks away to 25m | distance 25m > 20m × (1 + 0.15) → downgrade to 256px minimum; scheduled |
| Downgrade task runs | GPU resamples 1024px → 256px; applied; entity removed from tracking |

At no point are more than 3 buildings being streamed simultaneously, keeping GPU command submission predictable.

---

## Threading Model

| Thread | What happens there |
|--------|-------------------|
| Main / game loop | `update()` called; distance math; `buildWorkItems`; `reserveOp`; resource init |
| Swift Task (async) | Disk I/O (`MTKTextureLoader`); GPU encode + await (`MPSImageBilinearScale`) |
| MainActor | ECS mutation (`updateMaterial`); batch update; `upgradedEntities` bookkeeping |

`activeOps` and `upgradedEntities` are protected by `NSLock`. The command queue and texture loader are initialized once on the main thread before any `Task` is spawned, then captured as local constants — no concurrent access to instance state from async tasks.

---

## Memory Relief: `shedTextureMemory`

`TextureStreamingSystem` exposes a public method for on-demand texture downgrade under memory pressure:

```swift
@discardableResult
public func shedTextureMemory(cameraPosition: simd_float3, maxEntities: Int = 4) -> Int
```

This is called by `GeometryStreamingSystem` — not on a timer, but reactively whenever combined GPU memory (mesh + texture) hits the 85% high-water mark. It bypasses the normal distance-band schedule and forces immediate action.

**What it does:**
1. Snapshots `upgradedEntities` — the set of entities currently holding textures above `minimumTextureDimension`
2. Calculates the camera distance for each
3. Sorts **farthest-first** — the least visually valuable textures at their current resolution get downgraded first
4. Schedules up to `maxEntities` force-downgrades to `minimumTextureDimension`, skipping any entity already in an active op
5. Returns the number of entities scheduled

**Why farthest-first?** A distant entity's 1024 px texture dropping to 256 px is nearly invisible. A nearby entity's texture downgrading would be immediately obvious. This ordering gives the maximum memory relief for the minimum perceptible quality loss.

**Relationship to the update loop:** Normal `update()` ticks also schedule downgrades for out-of-range entities, but only as slots become available and on the 0.2 s timer. `shedTextureMemory` is a burst — it fills up to `maxEntities` slots immediately, regardless of the timer, to respond to pressure before the next geometry load attempt.

### When it is called

| Caller | `maxEntities` | Condition |
|---|---|---|
| `GeometryStreamingSystem.update()` | 4 | Combined pressure high, geometry pressure low — texture relief only, no geometry eviction |
| `GeometryStreamingSystem.update()` | 8 | Geometry pressure also high — shed texture first, then evict geometry |
| OS `.warning` pressure callback | 8 | `MemoryBudgetManager.onMemoryPressureWarning` fires — proactive shed before OS escalates |
| OS `.critical` pressure callback | 20 | `MemoryBudgetManager.onMemoryPressureCritical` fires — aggressive shed + double geometry eviction pass (16 evictions each) |

The larger batch size (8) when geometry is also under pressure reflects that more aggressive texture shedding is needed before the costlier geometry eviction path runs. The OS pressure rows bypass the normal per-tick budget check entirely — they fire out-of-band whenever the OS signals memory pressure, and the actual shedding runs on the next `GeometryStreamingSystem.update()` tick (deferred via a flag to stay on the main thread).

---

## Tuning Profiles

Apply a built-in profile at scene init instead of setting every property individually:

```swift
TextureStreamingSystem.shared.apply(.detailed)   // close-inspection / high-detail assets
TextureStreamingSystem.shared.apply(.superdetailed) // hero assets / showroom inspection
TextureStreamingSystem.shared.apply(.openWorld)  // large outdoor scenes
TextureStreamingSystem.shared.apply(.balanced)   // general-purpose default
TextureStreamingSystem.shared.apply(.tiled)      // tile-based streaming (see alignToManifest)
```

Individual properties can be overridden after applying a profile:

```swift
TextureStreamingSystem.shared.apply(.detailed)
TextureStreamingSystem.shared.upgradeRadius = 3.0  // widen full-res zone
```

For tiled scenes, `setEntityStreamScene(...)` calls `TextureStreamingSystem.shared.alignToManifest(streamingRadius:unloadRadius:)` automatically after decoding the manifest. That applies the `.tiled` profile and derives:

```swift
upgradeRadius = max(streamingRadius * 0.70, 2.5)
downgradeRadius = max(unloadRadius, upgradeRadius + 1.0, upgradeRadius * 2.0)
```

The floors keep small scenes usable, while large scenes still align texture tiers to their authored tile streaming bands.

| Profile | `upgradeRadius` | `downgradeRadius` | `minDim` | `maxConcurrentOps` | Best for |
|---|---|---|---|---|---|
| `.detailed` | 2.5 m | 6.0 m | 512 px | 6 | Vehicles, products, characters, props, interiors |
| `.superdetailed` | 4.0 m | 8.0 m | 1024 px | 6 | Showroom vehicles, product configurators, hero assets |
| `.openWorld` | 15.0 m | 60.0 m | 256 px | 3 | Cities, landscapes, terrain |
| `.balanced` | 12.0 m | 20.0 m | platform default | 3 | Mixed / unknown scene type |
| `.tiled` | 30.0 m* | 70.0 m* | 256 px | 6 | Tile-based streaming scenes |

\* Placeholder defaults only — immediately overridden by `alignToManifest` (see below).

**Detailed rationale:** close-inspection content keeps nearby surfaces large on screen, whether the subject is a car, product, character, prop, or room. The minimum tier is raised to 512 px (from the engine default of 256 px) because low-resolution mips look visibly compressed at a few metres. `maxConcurrentOps = 6` is safe here because these streaming ops are GPU-bound (no cold disk I/O on the warm path). `.archviz` remains available as a deprecated compatibility alias for `.detailed`.

**Superdetailed rationale:** hero assets may be inspected from a few metres away while still filling a large portion of the view. This profile keeps full-resolution textures through 4 m, uses a 2048 px medium tier, and only drops to 1024 px beyond 8 m. Use compressed formats such as ASTC for large source textures before enabling this profile on memory-constrained devices.

**Open-world rationale:** tiers are spread across a city-block scale. The minimum tier stays at 256 px because objects beyond 60 m occupy very few pixels. Keeping `maxConcurrentOps = 3` avoids GPU memory spikes when hundreds of entities enter range simultaneously.

**Tiled rationale:** tile streaming scenes have manifest-defined streaming and unload radii that vary per-scene. The `.tiled` profile sets concurrency (`maxConcurrentOps = 6`) and quality (`minimumTextureDimension = 256`, `maxTextureDimension = 1024`) for tile-scale geometry, then `alignToManifest` overrides the radii with values derived from the manifest's `streaming_defaults`.

---

## Tile Streaming Integration

### alignToManifest

When `setEntityStreamScene()` decodes a tile manifest, it calls:

```swift
TextureStreamingSystem.shared.alignToManifest(
    streamingRadius: manifest.streamingDefaults.streamingRadius,
    unloadRadius: manifest.streamingDefaults.unloadRadius
)
```

This applies the `.tiled` profile (concurrency, dimensions) then derives the texture tier radii from the manifest geometry streaming bands:

```
upgradeRadius   = max(streamingRadius × 0.70, 2.5)
downgradeRadius = max(unloadRadius, upgradeRadius + 1.0, upgradeRadius × 2.0)
```

**Why max(streamingRadius × 0.70, 2.5)?** The streaming radius is the distance at which tile geometry *loads*. Upgrading to full-res at 70% of that radius means the camera has already moved well inside the loaded zone before the texture upgrade fires. The 2.5 m floor keeps small scenes from requiring centimetre-level camera distances before full-resolution textures appear.

**Why the downgrade radius floors?** Tile geometry unloads at `unloadRadius`, so large scenes use that as the minimum-tier boundary. For small scenes, `upgradeRadius + 1.0` and `upgradeRadius × 2.0` guarantee a usable medium-quality band instead of dropping directly from full to minimum.

**Example** (city.json: `streaming_radius = 38.5m`, `unload_radius = 57.8m`):
- `upgradeRadius   = 38.5 × 0.70 = 26.97m` — full res within ~one tile diagonal
- `downgradeRadius = 57.8m` — minimum tier at the tile unload boundary

### notifyEntitiesReady / cancelEntities

`GeometryStreamingSystem` informs the texture system about tile lifecycle events:

```swift
// Tile finished loading — schedule priority texture evaluation
TextureStreamingSystem.shared.notifyEntitiesReady(tileRenderIds)

// Tile unloading — cancel any in-flight or queued ops for its entities
TextureStreamingSystem.shared.cancelEntities(renderIds)
```

`cancelEntities` removes the entity IDs from `upgradedEntities`, `activeOps`, and `priorityEntities`, ensuring no stale texture upgrade lands on a destroyed entity.

---

## Key Configuration

```swift
TextureStreamingSystem.shared.upgradeRadius = 4.0      // meters: go full-res inside this
TextureStreamingSystem.shared.downgradeRadius = 12.0   // meters: go minimum beyond this
TextureStreamingSystem.shared.maxTextureDimension = 1024
TextureStreamingSystem.shared.minimumTextureDimension = 256
TextureStreamingSystem.shared.updateInterval = 0.2     // seconds between evaluations
TextureStreamingSystem.shared.maxConcurrentOps = 3     // parallel streaming tasks
TextureStreamingSystem.shared.hysteresisFraction = 0.15 // dead-band fraction at tier boundaries
TextureStreamingSystem.shared.verboseLogging = true    // log each up/downgrade
```

---

## Hysteresis Dead Band

Without hysteresis, an entity hovering exactly at a tier boundary (e.g. `downgradeRadius = 20 m`) oscillates between tiers on alternate streaming ticks, causing mip-map flicker on distant meshes.

`hysteresisFraction` (default `0.15`) applies an asymmetric dead band at each tier boundary:

| Transition | Triggers at |
|---|---|
| Upgrade to full (boundary: `upgradeRadius`) | `distance < upgradeRadius × (1 − h)` |
| Downgrade from full | `distance > upgradeRadius × (1 + h)` |
| Upgrade to medium (boundary: `downgradeRadius`) | `distance < downgradeRadius × (1 − h)` |
| Downgrade to minimum | `distance > downgradeRadius × (1 + h)` |

At defaults (`upgradeRadius = 12 m`, `downgradeRadius = 20 m`, `h = 0.15`):
- Full ↔ medium transition: upgrade at < 10.2 m, downgrade at > 13.8 m
- Medium ↔ minimum transition: upgrade at < 17 m, downgrade at > 23 m

`shedTextureMemory` always bypasses hysteresis (passes `Float.greatestFiniteMagnitude` as distance) so memory-pressure downgrades are never suppressed.

---

## ASTC Texture Pipeline

The engine ships a native ASTC texture loader (`NativeTexFormat.swift`, `NativeTextureLoader.swift`) that decodes ASTC-compressed textures stored inside `.untold` binary asset files without going through `ModelIO` or `MTKTextureLoader`.

**How it interacts with texture streaming:**

- ASTC textures embedded in `.untold` files are decoded by `NativeTextureLoader` at load time and handed to the same `TextureLoader` GPU cache. From the streaming system's perspective, they are ordinary `MTLTexture` objects.
- All three streaming tiers (full, medium, minimum) apply normally — the system GPU-resamples the decoded ASTC texture to the target tier dimension using `MPSImageBilinearScale`, just as it does for PNG or JPEG source textures.
- ASTC textures are typically much smaller on disk than uncompressed equivalents, so they reduce download time for remote tile assets and reduce `ProgressiveAssetLoader` CPU heap pressure.
- The `.superdetailed` and `.detailed` streaming profiles note ASTC as the recommended source format for high-resolution hero assets on memory-constrained devices.

**Format support:** The engine targets `MTLPixelFormatASTC_*_LDR` block sizes (4×4, 6×6, 8×8). HDR ASTC is not currently supported. Use the Blender export pipeline's ASTC conversion step to produce compatible `.untold` files.

---

## Bootstrap Tier Alignment

`TextureLoader.defaultMaxTextureDimension` (set in `Mesh.swift`) is aligned to `TextureStreamingSystem.platformDefaultMinimumTextureDimension`:

- **visionOS:** 192 px
- **macOS / iOS:** 256 px

This ensures every freshly loaded entity starts at the streaming system's minimum tier. The streaming system then only **upgrades** as the camera approaches — it never issues an immediate downgrade on a newly-loaded entity (which would have been visible as a resolution pop on the first frame the entity appeared).
