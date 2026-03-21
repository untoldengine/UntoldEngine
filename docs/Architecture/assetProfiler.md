# Asset Profiler

## Purpose

`AssetProfiler` is a lightweight classification layer that runs between `Mesh.parseAssetAsync()` and ECS entity creation. It analyzes a parsed asset's composition — geometry bytes, texture bytes, mesh count — and recommends an `AssetLoadingPolicy` that selects the most appropriate residency strategy for each memory domain independently.

Its job is to answer: **given this asset and this platform's memory budget, should geometry stream or load eagerly, and should textures stream or load eagerly?**

---

## Where It Fits

```
setEntityMeshAsync(.auto)
  │
  ├─ Mesh.parseAssetAsync()         ← CPU-only parse, no GPU allocation
  │       └─ ProgressiveAssetData   ← MDLMesh objects in CPU RAM
  │
  ├─ AssetProfiler.profile()        ← analyze ProgressiveAssetData
  │       └─ AssetProfile           ← geo bytes, tex bytes, mesh count, character
  │
  ├─ AssetProfiler.classifyPolicy() ← compare profile against platform budget
  │       └─ AssetLoadingPolicy     ← geometryPolicy + texturePolicy
  │
  └─ Routing decision
        geometryPolicy == .streaming → out-of-core stubs path
        geometryPolicy == .eager     → immediate GPU upload path
```

The profiler runs entirely on the CPU in the async registration task. No GPU resources are allocated during classification.

---

## AssetProfile

```swift
struct AssetProfile {
    let totalFileBytes: Int
    let estimatedGeometryBytes: Int   // vertex + index bytes, summed across all MDLMesh objects
    let estimatedTextureBytes: Int    // estimated GPU footprint after decompression
    let meshCount: Int
    let materialCount: Int
    let largestSingleMeshBytes: Int
    let isEffectivelyMonolithic: Bool // meshCount <= 2
    let assetCharacter: AssetCharacter
}
```

### AssetCharacter

| Value | Meaning |
|---|---|
| `.textureDominated` | Textures > 75% of combined estimate. Few or small meshes with large maps. |
| `.geometryDominated` | Geometry > 75% of combined estimate. Many or large meshes with minimal textures. |
| `.mixed` | Neither domain exceeds 75%. Both contribute meaningfully. |
| `.monolithic` | ≤ 2 meshes. Streaming still prevents OOM at registration, but the mesh loads in one step rather than incrementally. |

---

## Geometry Byte Estimation

Geometry bytes are estimated using the same formula as `CPUMeshEntry.estimatedGPUBytes` — this keeps the profiler and the budget manager consistent:

```
vertexBytes  = vertexCount × vertexDescriptor.stride   (stride default: 48 bytes)
indexBytes   = vertexCount × 3 × 4                     (~3 indices/vertex, 4 bytes each)
meshBytes    = vertexBytes + indexBytes
```

Summed across all `MDLMesh` leaves in `ProgressiveAssetData.topLevelObjects`.

---

## Texture Byte Estimation

Texture bytes are estimated **without decompressing any texture data**. The profiler scans `MDLMaterial` semantic slots for texture URL references and uses file sizes as a proxy:

**For regular file URLs** (external textures):
```
textureBytes += fileSize × 3    // PNG/JPEG decode expansion; conservative cross-format estimate
```

**For USDZ-embedded textures** (bracket-notation paths like `file:///scene.usdz[0/tex.png]`):
Individual zip entries cannot be statted without decompressing. A file-level heuristic is used instead:
```
packedTextureBytes = max(0, fileSizeBytes − (geometryBytes / 10))
textureBytes = packedTextureBytes × 3
```
The geometry division by 10 approximates the compression ratio of vertex/index data in the USDZ package. This overestimates for geometry-heavy assets, which is intentional — it is always safer to over-estimate texture cost (triggers streaming) than to under-estimate it (causes OOM).

**If no texture URLs are found**, `estimatedTextureBytes` is 0 and `texturePolicy` defaults to `.eager`.

### Scanned Material Semantics

```swift
.baseColor, .roughness, .metallic, .bump, .emission, .opacity, .ambientOcclusion
```

---

## AssetLoadingPolicy

```swift
struct AssetLoadingPolicy {
    var geometryPolicy: GeometryResidencyPolicy  // .eager or .streaming
    var texturePolicy:  TextureResidencyPolicy   // .eager or .streaming
    var source:         PolicySource             // .auto or .userForced
}
```

The two policies are independent. A texture-dominated asset with 3 meshes and 150 MB of maps gets `geometry: .eager, texture: .streaming`. A geometry-dominated city with 400 small meshes gets `geometry: .streaming, texture: .eager`.

### Built-in Presets

| Preset | Geometry | Texture |
|---|---|---|
| `.fullLoad` | `.eager` | `.eager` |
| `.geometryStreaming` | `.streaming` | `.eager` |
| `.textureStreaming` | `.eager` | `.streaming` |
| `.combinedStreaming` | `.streaming` | `.streaming` |

---

## Classification Logic

### Geometry Policy

```
if isMonolithic:
    streaming if geometryBytes / budget > 0.30
    else eager

if meshCount >= 50:
    streaming   ← many meshes spike GPU allocation regardless of total size

if geometryBytes / budget > 0.30:
    streaming

else:
    eager
```

### Texture Policy

```
if textureBytes / budget > 0.10 OR textureBytes > 32 MB:
    streaming

else:
    eager
```

### Why fractions of budget, not fixed thresholds

The same 200 MB asset routes differently depending on the device:

| Device | Budget | Geo fraction | Geometry policy |
|---|---|---|---|
| macOS | 1 GB | 20% | `.eager` — fits comfortably |
| iOS high-end | 512 MB | 39% | `.streaming` — too large |
| iOS low-end | 256 MB | 78% | `.streaming` — far too large |
| visionOS | 512 MB | 39% | `.streaming` — too large |

Fixed thresholds (the old `fileSizeThresholdBytes = 50 MB`) applied the same cutoff on all platforms. A 200 MB asset would always trigger streaming, even on a macOS workstation with 1 GB of headroom.

---

## Log Output

For every `.auto` classification the profiler emits two log lines:

```
[AssetProfiler] 'dungeon3' (2.1 MB) → mixed | geo ~2.9 MB, tex ~6.2 MB | budget: 1024 MB | meshes: 410
[AssetProfiler] Policy → geometry: streaming, texture: eager (source: auto)
```

**Line 1** — profile snapshot: filename, file size, asset character, estimated geometry bytes, estimated texture bytes, platform budget, mesh count.

**Line 2** — the chosen policy for each domain and whether it was auto-selected or user-forced.

If geometry streaming is selected, the out-of-core log also captures the reason:

```
[OutOfCore] 'dungeon3': mixed asset, geo ~2.9 MB on 1024 MB budget → out-of-core stub registration (410 stubs)
```

---

## Limitations and Known Heuristics

**Texture estimation for USDZ-embedded textures is approximate.** The `(fileSizeBytes − geometryBytes/10) × 3` heuristic overestimates for geometry-heavy assets and underestimates for assets with highly compressed textures (e.g. ASTC at 8:1). It is biased toward overestimation intentionally.

**Monolithic assets stream but do not incrementally load.** An asset with 1 mesh and 400 MB of geometry enters the streaming path (to prevent OOM at registration) but loads its full geometry in a single upload step. There is no incremental benefit beyond registration-time safety.

**External texture files must be accessible at classification time.** If textures are on a remote URL or behind a slow filesystem, the `stat()` calls in `estimateTextureBytes` will block the registration task. This is only a concern for non-local assets.

**Material semantics scanned are limited to the seven standard PBR slots.** Custom material properties outside those semantics are not counted. If an asset uses non-standard semantic names, its texture estimate will be lower than the true cost.

---

## Relationship to Other Systems

| System | Relationship |
|---|---|
| `ProgressiveAssetLoader` | Provides `ProgressiveAssetData` that `AssetProfiler.profile()` analyzes |
| `MemoryBudgetManager` | Provides `meshBudget`; all thresholds are fractions of this value |
| `GeometryStreamingSystem` | Activated when `geometryPolicy == .streaming`; manages GPU residency per entity |
| `TextureStreamingSystem` | Runs on all entities with `RenderComponent` regardless of texture policy; the policy makes the intent explicit for future per-entity gating |
| `RegistrationSystem` | Calls `AssetProfiler` in the `.auto` branch of `setEntityMeshAsync`; maps the result to `useOutOfCore` |
