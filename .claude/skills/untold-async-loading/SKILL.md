---
name: untold-async-loading
description: Use when loading a single always-resident asset and sequencing what happens after it loads — choosing setEntityMesh vs setEntityMeshAsync, gating setSceneReady across one or more dependent loads, resolving a bare asset name against GameData's folder convention, loading Blender-authored lights/cameras/color-grade data with loadSceneAuthored, enabling IBL, or tearing down/reloading the world with destroyAllEntities. Triggers on "load this mesh and then do X", "why didn't my asset load", "the completion handler never fires", "load the scene's lights and cameras too", "clear the scene and load a new one". Not for general entity/material/light/camera work once something is already loaded (see untold-entity-scene), producing the .untold/.untoldanim files themselves (see untold-asset-pipeline), or the async-load pattern for manifest-driven tiled scenes via setEntityStreamScene (see untold-geometry-streaming).
version: 0.1.0
---

# Async Loading, Registration, and Asset Paths in Untold Engine

Covers the loading-lifecycle layer underneath normal entity work: choosing a load path, what belongs in a completion block, gating scene readiness across multiple loads, resolving asset names to files, loading Blender-authored scene data separately from geometry, and tearing down/reloading the world safely.

## 1. Choosing the right loading path

| Use case | API |
|---|---|
| Small asset needed immediately on the next line (tools, tests, editor-style setup) | `setEntityMesh(...)` — blocking, immediate |
| Normal always-resident asset (props, characters, gameplay objects, HUD meshes) | `setEntityMeshAsync(...)` — **preferred for most scene setup** |
| Large streamed world (cities, terrain, remote manifests) | `setEntityStreamScene(...)` — see `untold-geometry-streaming` |

`setEntityMesh` blocks the calling thread until the mesh is registered — don't use it for large runtime assets or tile-streamed worlds. `setEntityMeshAsync` loads immediately into GPU residency without stalling the render loop; it does **not** opt the asset into tile streaming, no matter how large the asset is.

```swift
let crate = createEntity()
setEntityName(entityId: crate, name: "crate")
setEntityMesh(entityId: crate, filename: "crate")
translateTo(entityId: crate, position: simd_float3(0.0, 0.0, 0.0))
```

```swift
setEntityMeshAsync(entityId: robot, filename: "robot") { success in
    if success {
        translateTo(entityId: robot, position: simd_float3(0.0, 0.0, 0.0))
        rotateTo(entityId: robot, angle: 0.0, axis: simd_float3(0.0, 1.0, 0.0))
    }
    setSceneReady(success)
}
```

The completion `Bool` is a success flag, not a "did it finish" flag: `false` means loading failed and the engine fell back to a default placeholder mesh — it still "completed." Always branch on it before doing dependent work.

## 2. What belongs in the completion block

Apply dependent transforms, physics setup, animation registration, and batching **inside** the completion block, not after the `setEntityMeshAsync` call — the mesh isn't registered yet when that call returns:

```swift
setEntityMeshAsync(entityId: entity, filename: "stadium", withExtension: "untold") { success in
    if success {
        setEntityStaticBatchComponent(entityId: entity)
    }
}
```

Chain dependent async steps (e.g. mesh → scene-authored data) rather than firing them in parallel if one depends on the other having succeeded first (see §5).

## 3. `withExtension` and name resolution

`withExtension` is optional on every `filename`/`withExtension` pair in the engine (`setEntityMesh`, `setEntityMeshAsync`, `setEntityAnimations`, `setEntityGaussian`, `loadSceneAuthored`, `setColorGradeLUT`) — when given, it takes priority. Leaving it out lets `setEntityMesh`/`setEntityMeshAsync`/`setEntityAnimations` probe for the format that needs disambiguating first, falling back to plain `.untold`:

```swift
// Resolves "model.untoldpack" if the source .blend had more than one
// independent model, otherwise "model.untold".
setEntityMeshAsync(entityId: entity, filename: "model") { success in }

// Resolves "walk.untoldanim", or a plain "walk.untold" from before that extension existed.
setEntityAnimations(entityId: entity, filename: "walk", name: "Walk")
```

This probing form is the recommended default — reach for an explicit `withExtension` only when you need to force one specific file regardless of what else exists at that name.

## 4. Asset path resolution (why "why didn't my asset load?" happens)

Every by-name load resolves against `assetBasePath` (set via `setupAssetPaths()` in a generated project, or `setEngine(.assetBasePath(url))`/`assetBasePath = ...` directly for a custom host app), in this order:

1. **Flat root** — `<assetBasePath>/<name>.<ext>` (fast path for assets dropped directly at the root).
2. **Structured subdirectories** — the canonical folder for that type, e.g. `Models/<name>/<name>.untold`, `Textures/<name>.png`, `Scenes/<name>.untoldscene`. Most assets resolve here.
3. **App bundle fallback** — `Bundle.main`, then the engine's own module bundle.

Canonical `GameData` folders: `Scenes/`, `Scripts/`, `Models/`, `StreamModels/`, `Animations/`, `Gaussians/`, `Textures/`, `Shaders/`, `LUT/`. Materials are the one exception — they resolve under `Materials/<subName>/...` keyed by the material name, not a fixed top-level folder, so a texture referenced *as part of a material* won't be found by `loadTexture(textureName:)` (which only ever searches the flat root and top-level folders).

If an asset silently fails to load, check which canonical folder it's actually in versus where the resolver looks for that asset type — this is the most common cause, well ahead of anything exotic. Don't hardcode absolute paths in code or scenes; `.untoldscene` files store references relative to `assetBasePath` specifically so projects survive a move between machines.

## 5. Gating scene readiness across multiple loads

`setSceneReady(...)` is for *your own* multi-step scene setup — ordinary `setEntityMeshAsync`/`setEntityStreamScene` already use internal loading gates. Use it when several dependent mutations must all land before the scene is considered ready:

```swift
setSceneReady(false)

setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold") { success in
    if success {
        setEntityKinetics(entityId: entity)
        translateTo(entityId: entity, position: simd_float3(0, 0, 0))
    }
    setSceneReady(success)
}
```

For multiple independent loads that must all finish before the scene is ready, count completions rather than nesting:

```swift
private var pendingLoads = 2
private var sceneFailed = false

private func finishLoad(_ success: Bool) {
    if !success { sceneFailed = true }
    pendingLoads -= 1
    if pendingLoads == 0 {
        setSceneReady(!sceneFailed)
    }
}
```

Each independent load (player, ball, ...) calls `finishLoad(success)` from its own completion block.

## 6. Loading Blender-authored scene data (lights/cameras/color grade) separately from geometry

`setEntityMesh`/`setEntityMeshAsync` only bring in geometry and materials. Scene-wide data exported from Blender — scene-authored lights/cameras, and a `.cube` creative grade LUT staged with `--color-grade-lut` — is registered separately with `loadSceneAuthored`, chained after the mesh load succeeds:

```swift
setEntityMeshAsync(entityId: office, filename: "office") { meshLoaded in
    guard meshLoaded else {
        setSceneReady(false)
        return
    }

    loadSceneAuthored(filename: "office", withExtension: "untold") { authoredLoaded in
        setSceneReady(authoredLoaded)
    }
}
```

`loadSceneAuthored(filename:withExtension:)` **always needs `withExtension: "untold"` explicitly** — unlike the mesh load above it, it never probes for `.untoldpack`, because a multi-model pack has no scene-level slot for this data in the first place.

For a tiled scene, load the manifest geometry and scene-authored payload from the same manifest, resolving the manifest URL through `LoadingSystem.shared`:

```swift
setEntityStreamScene(entityId: city, manifest: "city", withExtension: "json") { streamLoaded in
    guard streamLoaded,
          let manifestURL = LoadingSystem.shared.resourceURL(
              forResource: "city", withExtension: "json", subResource: nil
          )
    else {
        setSceneReady(false)
        return
    }

    loadSceneAuthored(url: manifestURL) { authoredLoaded in
        setSceneReady(authoredLoaded)
    }
}
```

Calling either `loadSceneAuthored` overload clears any previously-loaded `.cube` grade first, then re-populates it only if the asset/manifest actually has one staged — a source with no grade staged is not an error, the engine just applies none. Toggle the grade at runtime with `setPostFX(.colorGradeLUT(.enabled(false)))` to compare against the tonemap operator alone.

## 7. Image-based lighting is separate from `loadSceneAuthored`

`loadSceneAuthored` loads lights, cameras, and color management — it does **not** configure IBL. If the scene expects an HDR environment, call `setRendering(.environment(...))` separately:

```swift
setRendering(.environment(.ibl(true)))
setRendering(.environment(.asset("forest.exr")))
setRendering(.environment(.intensity(0.9)))
```

`.asset` resolves the HDR name against the standard asset search (`GameData`, its `HDR/` subfolder, then app/engine bundles) unless you pass `directory:` for an explicit location. `.asset` also regenerates the prefiltered IBL textures, so expect a brief cost when it's called.

## 8. Progress tracking

```swift
Task {
    let isLoading = await AssetLoadingState.shared.isLoadingAny()
    let count = await AssetLoadingState.shared.loadingCount()
    let (current, total) = await AssetLoadingState.shared.totalProgress()
    let summary = await AssetLoadingState.shared.loadingSummary()
}
```

Per-entity: `await AssetLoadingState.shared.getProgress(for: entity)` → `(filename, currentMesh, totalMeshes)`.

## 9. Destroying and reloading the world

`destroyEntity(entityId:)` removes one entity and its components. For a full reset, use `destroyAllEntities(completion:)` rather than looping `destroyEntity` yourself — it's a deferred operation (entities are marked for destroy, then finalized during the engine's frame-finalization step), and the completion block only runs after that finalization has actually happened:

```swift
destroyAllEntities {
    // Safe point: pending destroys have been finalized.
    let entity = createEntity()
    setEntityMeshAsync(entityId: entity, filename: "office", withExtension: "untold")
}
```

This prevents a race where new entities get created while old ones are still pending destroy. Don't assume a bare `destroyEntity` loop followed immediately by new `createEntity` calls is equivalently safe for a full-world reset.

Full reference: `docs/API/UsingAsyncLoading.md`, `docs/API/UsingAssetPaths.md`, `docs/API/UsingRegistrationSystem.md`, `docs/API/UsageExamples.md`.
