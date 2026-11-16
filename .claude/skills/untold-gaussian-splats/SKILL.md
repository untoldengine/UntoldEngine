---
name: untold-gaussian-splats
description: Use when attaching or tuning a Gaussian-splat (.ply/.untoldgs) capture on a live entity at runtime — loading a splat onto an entity, progressive LOD tiers, streaming splat props across a tile-streamed scene, a splat standing in for a mesh (occluder shells, fades, alignment), memory/paging budgets, or splat render-quality knobs. Triggers on "add this gaussian splat to the scene", "the splat pops in/out", "splat is using too much memory", "swap this splat for its mesh at distance", "splat LOD". Not for exporting/baking a .ply into .untoldgs or linking a payload into a .untold file (see untold-asset-pipeline), or ordinary mesh tile streaming via setEntityStreamScene (see untold-geometry-streaming) — Gaussian paging is a separate mechanism from tile/mesh streaming, even though setEntityGaussianTileStreaming attaches to the tile stubs that creates. Mesh LOD on a regular entity is a different system (see untold-lod-system).
version: 0.1.0
---

# Gaussian Splats at Runtime in Untold Engine

This covers loading and tuning a Gaussian-splat capture on a live entity. Exporting a `.ply` to `.untoldgs`, baking LOD tiers, and linking a payload into a `.untold` file's `gaussianAsset` record are covered by `untold-asset-pipeline` — this skill assumes that artifact already exists and focuses on what the engine does with it per frame.

## 1. Pick the right loading function

| Function | Resident/Streamed | LOD | Use when |
| --- | --- | --- | --- |
| `setEntityGaussian(entityId:filename:withExtension:)` | Resident, loads immediately (blocks) | None | Small number of splats that should always be visible (hero object, standalone demo) |
| `setEntityGaussian(entityId:source:)` | Resident | `.single` (none) or `.progressive` (coarse-to-fine) | Same, plus one call site that can also take `.progressive(...)` without a tile-streamed scene |
| `setEntityGaussianAsync` | Resident, loads off-thread | None | Same as `setEntityGaussian`, avoids a frame hitch on a large `.ply` |
| `setEntityGaussianTileStreaming(source:options:)` | Streamed via `GeometryStreamingSystem` | `.single` (none) or `.progressive` | Props scattered across a tile-streamed scene that should load/unload with camera distance |

```swift
let myEntity = createEntity()
setEntityGaussian(entityId: myEntity, filename: "splat")   // omit withExtension (recommended)
```

**Omitting `withExtension` is the recommended default** — it probes `.untoldgs` first, then `.ply` (same convention `setEntityMeshAsync` uses for `.untoldpack`/`.untold`), so the caller doesn't need to know which is on disk. A baked `.untoldgs` is the faster path: chunks are read by byte range and decoded on the GPU, nothing parses on CPU. Pass `withExtension` explicitly only to force one format.

Both sync and async forms load resident for the entity's lifetime and compute `LocalTransformComponent.boundingBox` automatically from the splat positions — no bounding-box parameter needed on this path.

## 2. Multiple splat entities share one working-set budget

Every frame the engine compacts the visible splats of **all** Gaussian entities into one shared working set, sorts it once by depth, and draws it with one instanced draw — so overlapping captures (a chair in front of a splat floor) blend in correct depth order regardless of creation order. Up to 256 splat entities can draw in one frame.

The shared set is sized by `GaussianRuntimeLimits.workingSetSplats` (1M on Vision Pro/iPhone/iPad/Apple TV, 6M on Mac), not by what's loaded. `.ply` entities aren't budgeted — their visible count is reserved first, out of the budget, and a `.ply` that fills the budget leaves `.untoldgs` entities nothing. `.untoldgs` entities are fitted chunk-by-chunk to what's left via a screen-area-weighted density cap, so near/large chunks keep all their splats while far/dense chunks get cut — with hysteresis so the cut doesn't pop as the camera moves. **If a scene asks for more than the budget holds, excess is dropped for that frame and reported as overflow via `handleError` and the `[Gaussian][Preprocess]` profile line — that's a defect to fix (raise the budget, cut splat counts, or clamp how many splat entities are visible at once), not a mode of operation to expect.**

## 3. Memory and the paging threshold — the gotcha that actually bites

A `.untoldgs` asset whose raw records exceed the **paging threshold** (64 MiB on Vision Pro/iPhone/iPad/Apple TV, 512 MiB on Mac) is **not loaded whole**. Only the chunk table stays resident; the actual splat records stream into a bounded **page pool** (256-rank tiers, filled from disk on demand, sized from a quarter of `MemoryBudgetManager.geometryBudget`). This is automatic and usually transparent — you don't opt into it — but it has real consequences:

- **Per-entity splat caps exist and a load fails hard above them**, not gracefully: `GaussianRuntimeLimits.maxSplatsPerEntity` (20M on Vision Pro/iPhone/iPad/Apple TV with paging, 40M on Mac) for `.untoldgs`, or the much lower `maxWholeBufferSplatsPerEntity` (≈5.2M on Vision Pro/iPhone/iPad/Apple TV, ≈16.8M on Mac) for a `.ply` or a whole-buffer-decoded `.untoldgs`. An asset over its path's cap fails to load with an "exceeds maximum" error — cook with a splat budget (`untoldengine export --splat-max-count`) or split into streamed tiles instead of hitting this at runtime.
- **Cook Vision Pro assets at spherical-harmonics degree 2 or below.** At degree 3 a page slot is 15 KiB and a 256 MiB pool only holds *most* of a 20M-splat asset's heads, not all of them — this is a real, easy-to-hit quality cliff on that platform specifically.
- Read live paging state with `gaussianPagingStats(entityId:)` (pool/resident slots/chunks, reads pending/in-flight, faulted/corrupt chunks) or the `[Gaussian][FrustumCull]` profile line (`paged=… pool=… pending=… evicted=… saturated=… faults=…`). Use this before assuming a popping/missing-detail bug is a bug — it may just be the pool under its target.
- Debug knobs for isolating paging behavior: `GaussianDebugOptions.shared.disablePaging` (force whole-resident regardless of size), `freezePaging` (hold the resident set static for bisecting), `residencyDebugTint` (color by resident fraction — green whole, red head-only).

## 4. Progressive LOD tiers (no tile streaming required)

Use this when a splat should appear quickly at a coarse tier and refine as the camera gets closer — independent of whether the scene uses tile streaming at all.

```bash
untoldengine export --input "chair.ply" --output "chair.untoldgs" --lod-levels 4
```

Produces `chair_lod0.untoldgs` (finest) through `chair_lod3.untoldgs` (coarsest). Register with the source-based API:

```swift
setEntityGaussian(
    entityId: chair,
    source: .progressive(
        baseFilename: "chair",
        levelCount: 4,
        maxDistances: [5.0, 15.0, 25.0, .greatestFiniteMagnitude]
    )
)
```

`maxDistances` has one entry per LOD — the farthest camera distance at which that tier is still allowed (`lod0` within 5.0, `lod1` 5.0–15.0, etc; the last entry should be `.greatestFiniteMagnitude` as a catch-all). The system always falls back to the best tier already resident, and a paged tier **warms** in the background before switching to it (waits for 80% of wanted ranks resident, or 90 ticks) so a paged tier never comes in empty. No bounding-box parameter is needed — it's read from the coarsest tier's baked header at registration.

`GaussianLODSystem` also clamps to a coarser tier automatically when a distance-selected tier would exceed `LODConfig.shared.gaussianOverdrawBudget` (default `12.0`) — this is fully automatic for exporter-baked assets (uses the baked `meanSquaredSplatExtent`) and needs no wiring, but tune the budget on-device by watching GPU frame time if a dense capture is still too expensive at its distance-selected tier.

Debug with the same overlay mesh LODs use:

```swift
setSpatialDebug(.lodLevels(true))
```

## 5. Streaming splat props in a tile-streamed scene

`setEntityGaussian`/`setEntityGaussianAsync` keep a splat resident for the entity's lifetime — fine for a handful of always-visible splats, wrong for many small props scattered across a large tile-streamed scene (chairs, decor inside a streamed building), since nothing would ever unload them. For that case, register through `GeometryStreamingSystem` instead:

```swift
setEntityGaussianTileStreaming(
    entityId: streamSplat,
    source: .single(filename: "chair", withExtension: "untoldgs"),
    options: GaussianStreamingOptions(streamingRadius: 30.0, unloadRadius: 45.0)
)
```

This is **per-entity** streaming — one whole Gaussian asset (or tier set) loads/unloads as a unit based on distance, the same way surrounding tile geometry does. It does **not** break one large splat into pieces streamed independently (that's a separate, not-yet-implemented capability).

**Prerequisites and ordering matter:**
- Needs a scene already loaded with `setEntityStreamScene` (see `untold-geometry-streaming`) — call this *after* that completion handler fires, since it attaches to whichever tile stub's bounds contain the entity's position.
- **Position the entity before calling this** — the position at call time determines which tile it's attached to.
- If no tile contains the position, it logs a warning and leaves the entity as a plain non-streaming entity (no crash, but it silently won't stream) — double-check position against the manifest's tile bounds if a prop never appears.
- `boundingBoxHalfExtent` is read automatically from a `.untoldgs` baked header when left `nil`. **A raw `.ply` source has no baked header — you must supply this explicitly**, or the entity is left non-streaming entirely (not registered with a zero-size placeholder, which would break re-streaming once the camera leaves and returns).

```swift
setEntityStreamScene(entityId: sceneRoot, manifest: "dungeon", withExtension: "json") { success in
    guard success else { setSceneReady(false); return }

    let splat = createEntity()
    translateTo(entityId: splat, position: simd_float3(2.0, 0.0, -4.0))
    setEntityGaussianTileStreaming(
        entityId: splat,
        source: .progressive(baseFilename: "pooltable", levelCount: 4,
                              maxDistances: [15.0, 25.0, 35.0, .greatestFiniteMagnitude]),
        options: GaussianStreamingOptions(streamingRadius: 100.0, unloadRadius: 140.0)
    )
    setSceneReady(true)
}
```

Guard on `success` before registering the splat — without it a failed scene load still tries to attach a prop to tile stubs that were never created.

## 6. A splat standing in for a mesh (swap-at-distance pattern)

A captured object looks best as a splat up close and costs least as a mesh far away. The engine provides the pieces; your app owns the policy of when to swap:

- `setEntityGaussianAsync(entityId:url:opacityScale:)` attaches a splat to an entity that already draws a mesh — the mesh stays primary (keeps the bounding box, and the splat's bytes ride on the mesh's `MemoryBudgetManager` entry so mesh streaming doesn't drop them). Start with `opacityScale: 0` to load resident but hidden.
- `GaussianComponent.opacityScale` weighs every splat's opacity — `0` hides and skips culling, values between cross-fade.
- `MeshOccluderComponent(shrinkMeters:)` draws the mesh depth-only, pushed slightly along its normals, so the splat passes the depth test just outside the surface — raise `shrinkMeters` until the capture stops clipping. Set `drawsColor = false` to hide the mesh's color while shadows/physics/picking keep using it.
- `MeshFadeComponent` (`.fadeOut`/`.fadeIn`) dithers the mesh's colour during the transition.
- A typical swap: load the splat at `opacityScale: 0` when near; add `MeshOccluderComponent`; add `MeshFadeComponent(.fadeOut)` and ramp its `progress` + the splat's `opacityScale` to 1 together over ~250ms; then set `drawsColor = false` and remove the fade. Reverse when the camera leaves.
- A mesh carrying `MeshOccluderComponent`/`MeshFadeComponent` is automatically excluded from static batching while they're present, and re-admitted once removed — no manual batching call needed.
- `setGaussianSplatToEntity(entityId:_:)` sets `GaussianComponent.splatToEntity` to align a capture that doesn't share its mesh's frame (different origin/up-axis/scale) without re-baking.

## 7. Calibration and render-quality knobs worth knowing about

- Splats are unlit emissive surfaces blended in the capture's own display-referred (sRGB) space — the scene's tonemap/color-grade pass leaves splat pixels alone by design, so a capture keeps the tones it was trained with.
- `GaussianComponent.colorGain` / the per-asset `exposureOffsetEV` compensate a capture recorded at a non-neutral exposure.
- `GaussianRuntimeLimits.maxBlendedSplatsPerPixel` (64 mobile, 128 Mac) and `maxScreenRadius` (512px mobile, 1024px Mac) are real quality ceilings — a capture whose splats are mostly faint can need more than 64 to saturate a pixel, and a splat the camera stands very close to is clamped to the screen-radius cap rather than drawn over the whole screen. Both have `...Override` escape hatches if a specific capture needs different limits.

## 8. Common pitfalls to flag proactively

- Don't assume a splat silently handles unlimited size — there's a hard per-entity splat cap that fails the load outright; budget the capture at cook time instead of discovering this at runtime.
- Don't expect `setEntityGaussianTileStreaming` to page a single huge splat in pieces — it streams whole-asset-per-entity; a capture too large for memory as a single unit needs to be split into multiple entities/props, not handed to this API as one.
- Don't reposition a streaming splat entity after registering it and expect it to re-attach to the correct tile — position must be set before `setEntityGaussianTileStreaming` is called.
- A `.ply` source with no `boundingBoxHalfExtent` supplied to `GaussianStreamingOptions` silently fails to stream (logged warning) rather than crashing — easy to miss.

Full reference: `docs/API/UsingGaussianSystem.md`, `docs/Architecture/geometryStreamingSystem.md`, `docs/Architecture/untoldgsFormat.md`.
