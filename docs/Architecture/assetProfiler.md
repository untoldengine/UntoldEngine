# Asset Profiler

`AssetProfiler` is a lightweight policy helper for choosing geometry and texture
residency from an `AssetProfile`. The current `.untold` streaming path no
longer profiles `MDLAsset` / `MDLMesh` data. OCC admission for tile payloads is
based on native `RuntimeAssetNode` signals gathered during `.untold` loading.

---

## Current Tile OCC Admission

When `setEntityStreamScene(...)` loads a tile, the tile path calls
`setEntityMeshAsync(..., streamingPolicy: .auto, blockRenderLoop: false)`.
For `.untold` assets, registration loads a `RuntimeAsset` and decides whether to
use OCC from native runtime data:

```swift
let renderableNodes = runtimeAsset.nodes.filter { !$0.primitives.isEmpty }
let estimatedGeometryBytes = renderableNodes
    .flatMap(\.primitives)
    .reduce(0) { $0 + $1.estimatedGPUBytes }
let budgetFraction = Float(estimatedGeometryBytes) / Float(MemoryBudgetManager.shared.geometryBudget)

useOCC = renderableNodes.count >= 50 || budgetFraction > 0.30
```

Named-node loads never use OCC. `.immediate` never uses OCC. `.outOfCore`
forces OCC, but the supported public streaming entry point is still
`setEntityStreamScene(...)`.

---

## AssetProfile

The `AssetProfile` type remains as a general residency summary:

```swift
struct AssetProfile {
    let totalFileBytes: Int
    let estimatedGeometryBytes: Int
    let estimatedTextureBytes: Int
    let meshCount: Int
    let materialCount: Int
    let largestSingleMeshBytes: Int
    let isEffectivelyMonolithic: Bool
    let assetCharacter: AssetCharacter
}
```

`AssetProfiler.classifyPolicy(profile:budget:)` maps this profile to an
`AssetLoadingPolicy`:

| Signal | Geometry policy |
|---|---|
| `meshCount >= 50` | `.streaming` |
| `estimatedGeometryBytes / budget > 0.30` | `.streaming` |
| otherwise | `.eager` |

Texture policy is `.streaming` when estimated texture bytes exceed 10% of the
budget or 32 MB.

---

## Current Runtime Format Boundary

USD/USDZ are authoring/import formats for the exporter. Runtime mesh loading,
tile streaming, and OCC registration use `.untold`:

- `.untold` parsing uses `NativeFormatLoader` / `UntoldReader`.
- Geometry estimates come from `RuntimePrimitive.estimatedGPUBytes`.
- OCC CPU residency stores `RuntimeAssetNode` values in `CPURuntimeEntry`.
- The old ModelIO profiler assumptions for `MDLMaterial` texture URL scanning
  and USDZ embedded texture heuristics no longer describe the streaming path.

---

## Relationship to Other Systems

| System | Relationship |
|---|---|
| `RegistrationSystem` | Performs current `.untold` OCC admission in the `.auto` tile path |
| `ProgressiveAssetLoader` | Stores `CPURuntimeEntry` data for OCC stubs |
| `MemoryBudgetManager` | Provides the geometry budget used by admission checks |
| `GeometryStreamingSystem` | Uploads and evicts OCC stubs selected by registration |
| `TextureStreamingSystem` | Manages texture residency independently of OCC admission |
