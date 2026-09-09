# Gaussian Splat Streaming: object twins, windows, and worlds

**Status:** Rows 2–7 of §8 are implemented (fork and upstream); the chunk-level cull that row 6 planned shipped separately as Stage 1 of `feature/gaussian_budgeted_working_set` (row 8). Phase 2 and 3 remain proposals.
**Scope:** Gaussian splat assets in UntoldEngine core: a cooked payload format, an offline cooker in the Swift CLI, and the runtime residency, culling, LOD and sort changes needed to render millions of splats inside a normal mesh scene. All Apple platforms; designed against Apple Vision Pro.
**Baseline:** `develop` as of 2026-09-04 (revised the same day after auditing the gaussian work landed on `develop` in August 2026; the first draft had surveyed an older branch).
**Series tracker:** see §8 for the planned PR breakdown; the live status of each PR is kept in the tracking issue on the fork.

---

## 1. Purpose

UntoldEngine already renders, streams and LOD-switches Gaussian splats (§2). What it lacks is a payload that can be read by range and held at a fraction of today's bytes per splat, a sort that is correct across several splat entities, and the scene-side links that let a splat stand in for a mesh. Those are what the use the engine now needs requires:

1. **Object twins (first).** The scene renders through the standard Metal geometry pipeline. Chosen objects, a table, a sofa, hand over to a captured Gaussian splat twin. Several at once, composited correctly with each other and with the meshes around them.
2. **A world through a window (second).** A mesh room has a window; through it the user sees a captured splat world. The user stays in the room, leans and looks; quality just beyond the glass must be excellent.
3. **World splat (must keep working).** Load one splat file as the scene and move through it, as `setEntityGaussian` does today.
4. **Streamed environment (later).** A room or larger becomes a splat that does not fit in memory and is mostly behind walls.

All four share one payload format, one cooker and one renderer. This proposal fixes the format, the container decision, the cooker, the runtime pipeline, the anti-popping rules, and a PR series to deliver mode 1 first.

Three rules apply throughout:

- **The plain world-splat path never breaks.** Loading a `.ply` keeps working; it becomes the degenerate case of the new path.
- **Every per-frame decision about a splat changes continuously with the camera or is hidden behind a blend.** On Vision Pro the camera never stops moving, so anything discrete is visible.
- **Vision Pro is the bar.** Stereo at 90 Hz on the M2 model is the floor content is authored to; the M5 model and other platforms scale the budget at runtime.

---

## 2. Where the engine stands today

Facts read from `develop` on 2026-09-04. The gaussian pipeline below was landed by the upstream maintainer between 5 and 22 August 2026; this series extends it and must not duplicate it.

| Area | Today | Where |
|---|---|---|
| Native format | `.untoldgs` version 2: a 72-byte header (splat count, SH metadata, `meanSquaredSplatExtent`, asset bounding box) followed by one flat array of GPU-encoded splats (48 B each: float3 position, half3 × 2 covariance, half4 colour+opacity) and the 8-bit SH block in the renderer's fixed `[-1, 1]` contract. Read whole with `Data(contentsOf:)`; `readHeader` reads the box through a bounded `FileHandle`. Declared "a regeneratable cache of the source .ply": a version bump means re-bake. | `RegistrationSystem.swift` (`UntoldGSFormat`, `UntoldGSAsset`) |
| Bake | `untoldengine export --input x.ply --output x.untoldgs --lod-levels N` → `bakeGaussianSplatProgressiveTiers`: nested progressive tiers by a spatially interleaved importance ranking, one file per tier (`x_lod0.untoldgs` finest … coarsest), each carrying the shared asset box and its own overdraw statistic. | `RegistrationSystem.swift:4304`, `Tools/UntoldEngineCLI/ExportCommand.swift` |
| Registration | `setEntityGaussian(entityId:filename:withExtension:)` (sync), `setEntityGaussianAsync`, `setEntityGaussian(source: .single / .progressive)`, `setEntityGaussianStreaming(source:options:)` which attaches the entity to its containing tile. PLY and `.untoldgs` both accepted. Load-time culling of negligible-opacity splats. | `RegistrationSystem.swift:3745–4010` |
| LOD | `GaussianLODSystem` + `GaussianLODComponent`: distance thresholds per tier, hysteresis, coarsest tier first, fallback to the best resident tier, an overdraw-aware clamp from `meanSquaredSplatExtent` against `LODConfig.gaussianOverdrawBudget`, LOD debug tint. | `Systems/GaussianLODSystem.swift` |
| Streaming | Gaussian props share the tile streaming path: load and unload by radius, near band, `MemoryBudgetManager` registration by estimated GPU bytes, eviction under pressure, progressive tiers pulled on demand. | `Systems/GeometryStreamingSystem+GaussianStreaming.swift` |
| Per frame | Per entity: reset + frustum cull per splat fused with an HZB occlusion pre-cull against the temporal depth pyramid; depth keys; a 4-pass 8-bit radix sort **per entity**; `gaussianPreprocess` computes conic, axes and SH colour once per visible splat; TBDR draw of instanced quads accumulating in an imageblock with a raster order group, transmittance early-out at 0.999, per-fragment occlusion against the opaque depth, a cap of 64 blends per pixel, alpha-weighted depth written for later passes. Per-frame buffers are triple-buffered. | `Systems/GaussianSystem.swift`, `Shaders/Gaussians.metal`, `Renderer/RenderPasses.swift` |
| Colour | Captured colour decoded sRGB→linear in the preprocess kernel; composite before the look and output transform. | `Shaders/Gaussians.metal` |
| XR | Compositor Services, one render loop per eye, no vertex amplification. Cull, depth keys and sort run once before the eye loop; shadows on eye 0; Hi-Z built after both eyes. `XREnvironmentLightingSystem` exposes a smoothed real-world intensity scale and tint. | `UntoldEngineXR/` |

**What is missing, and what this series adds:**

- The payload is one flat blob: no chunking, no byte-range reads, no spatial order or tree. Streaming inside one asset (the window and environment modes) is impossible, and every resident splat costs 48 B plus SH where a quantised record needs 16 B plus SH.
- Progressive tiers are separate files, so an asset with four tiers stores its coarse splats up to four times and a tier switch is a whole-file load.
- Sort and draw are per entity, so two overlapping splat entities blend in entity order, not depth order.
- Nothing links a splat entity to a mesh twin, and there is no occluder shell, cross-fade, exposure gain or tint.
- No window bake, no per-cell visibility.

## 3. What the field settled on

Condensed from the 2024–2026 literature and the shipping viewers (Spark 2.0, PlayCanvas Streamed SOG, Cesium 3D Tiles splats, Inria hierarchical 3DGS). Sources in Appendix B.

### 3.1 Level of detail

| Family | Mechanism | Fit |
|---|---|---|
| Cluster DAG (Nanite-style) — Virtualized 3D Gaussians, NanoGS | Clusters of 4096 splats; pairs simplified 2:1 and re-optimised against renderings of the originals; per-cluster footprint test. 96 M → 27 M drawn far away. | **Objects.** Designed for composed scenes of instanced assets. |
| Discrete level sets — LODGE, CityGaussian, FLoD, Streamed SOG | 2–4 independent or nested sets by distance band; coarse levels by importance pruning plus a depth-aware smoothing filter. LODGE: 877 K resident of 2.6 M, iPhone 13 mini 41 fps incl. 7 ms sort. | **Objects, first version.** Decimation needs no training. |
| Merge hierarchy — Hierarchical 3DGS, Spark `.rad`, A LoD of Gaussians | Median-split BVH; interior node = one Gaussian (weights opacity × area, moment-matched covariance). Cut by projected size; children interpolate to parent with an opacity remap. BigCity: 8.2 M of ~100 M at 56 fps, τ=6 px. | **Environment.** |
| Continuous per-splat — CLoD-GS | Learned per-splat distance decay of opacity; −38 % splats at no PSNR loss. | Optional; needs retraining. |

### 3.2 Occlusion for semi-transparent splats

| Approach | How | Fit |
|---|---|---|
| Proxy-mesh depth pre-pass + Hi-Z — Proxy-GS | Depth-only coarse mesh, depth pyramid, cull deeper than proxy + margin γ (0.3 optimal). 76 % of anchors culled, 2.5–3× fps. | **Objects: free**, the mesh twin is the proxy. Environment: proxy must be baked. |
| Precomputed per-region visible sets — OccluGaussian, RadSplat | Per camera-cluster region, mark a splat visible if its α·T contribution exceeds 0.01 from any camera; draw only that set. 189 → 289 fps indoors, PSNR unchanged. | **Window and environment.** The Quake PVS idea for splats. |
| Opaque-core depth writers — PAGS | Highly opaque splats depth-only first, Early-Z the colour pass. | Superseded by the mesh twin for objects. |
| Transmittance termination | Stop blending once a pixel or tile saturates. | Both; fragment work only. |
| Learned visibility — NVGS | Per-asset MLP predicts visibility; 28–40 % of in-frustum culled. | Not worth per-asset training while the twin exists. |

### 3.3 Formats worth borrowing from

| Format | B/splat (SH0 / SH3) | Random access | LOD | Take |
|---|---|---|---|---|
| 3DGS `.ply` | 56 / 248 | stride | no | Import only. |
| Niantic SPZ v4 | ~20 / ~65 then zstd | none | no | Import only; good quantisation recipe. |
| PlayCanvas `compressed.ply` | 16 (+0.2) / 61 | 256-splat chunks | no | **The core record we adopt.** Per-chunk min/max after Morton sort; ~20 ALU ops to decode. |
| SOG / Streamed SOG | ≈6–8 with SH palette | per chunk file | one LOD per chunk | Borrow the SH palette (2 B/splat) and the one-LOD-per-chunk rule. |
| Spark 2.0 `.rad` | GPU 16 (+40 SH) | 64 K chunks | merge tree, root first | Borrow the paged GPU pool and the coarse-first chunk. |
| glTF `KHR_gaussian_splatting` | float accessors | yes | via 3D Tiles | Ratified 2026; interop export target. |
| RealityKit 27 `GaussianSplatResource` | your buffers | n/a | no | Apple's renderer; format-agnostic, undocumented cap, no LOD, cannot run inside our Compositor Services pipeline. |

### 3.4 Sorting on Apple GPUs

The engine's reduce-then-scan 8-bit radix sort is the right design for Metal; single-pass look-back sorts (Onesweep) need forward-progress guarantees Apple GPUs do not give, and the FidelityFX port misbehaves on M1 and iPhone. Calibration: LODGE sorts ~0.9 M keys in 7 ms on an iPhone 13 mini; Unity's Metal path draws 6.1 M splats in 21.5 ms on an M1 Max; browser viewers hold 60 fps at 2 M splats on an iPhone 15 Pro. Vision Pro viewers with a CPU sort report wobble above ~300 K splats because the sort lags head motion. Sort only the post-cull working set, every frame, on the GPU.

---

## 4. Proposed design

### 4.1 Container decision: `.untoldgs` version 3, referenced from `.untold`

The engine already has a native splat container, a baker and a loader for it, and the format is declared a regeneratable cache whose version bump means "re-bake". So the chunked payload becomes **`.untoldgs` version 3** rather than a second format: same magic and extension, same `UntoldGSFormat.read` / `readHeader` entry points and `UntoldGSAsset` result, same `export` command and `bakeGaussianSplatProgressiveTiers`, same registration and streaming APIs. Version 1 and 2 files are rejected with `.unsupportedVersion`, which is the contract the format already states.

Everything the scene needs to know about a splat beyond its payload stays small and lives in `.untold` as a new core chunk type, `gaussianAsset`: path to the payload, mesh-twin link, budget table, window view cell and portal bake, skybox reference. `TileManifest` references it like a LOD level. This mirrors how textures live in `.utex` and are referenced. One payload format for all four modes, so there is one load path.

The `.untold` reader itself is untouched by the payload: it reads whole files and hashes every payload on open, which is right for meshes and wrong for a streamed splat payload.

### 4.2 The `.untoldgs` v3 payload

Goals in priority order: any chunk loads on its own by byte range; a chunk lands in a GPU page with no CPU transform; the first read shows the whole asset coarsely; rotation and scale survive for LOD and re-encoding; SH is optional per device tier; an object file carries its registration and capture lighting.

```
[0]        FileHeader          256 B, padded to 16 KB
[16 KB]    ChunkIndex          chunkCount × 64 B, padded to 16 KB multiple
[…]        NodeTree            nodeCount × 48 B, padded
[…]        Palettes            optional SH palette, 16 KB aligned
[…]        Chunk payloads      each 16 KB aligned: core block, then optional SH block
```

Every payload offset is a multiple of 16 384 bytes, the page size on all current Apple devices: `makeBuffer(bytesNoCopy:)` over an mmap needs page-aligned pointer and length, and Metal fast resource loading decompresses on 64 KB chunk boundaries.

```c
struct UntoldGSHeaderV3 {           // 256 B; magic and version at the same offsets as v1/v2
  char     magic[4];                // "UTGS"
  uint32_t version;                 // 3
  uint32_t flags;                   // hasSphericalHarmonics, shPalette (reserved), antialiased, environment
  uint8_t  shDegree;                // 0..3
  uint8_t  coordSys;                // 0 = right/up/back, the engine convention
  uint8_t  colorSpace;              // 0 = sRGB display-referred
  uint8_t  log2ChunkSplats;         // 10 → 1024 (objects), 12 → 4096 (environments)
  uint32_t splatCount, chunkCount, nodeCount;
  uint8_t  lodLevels;               // ≤ 8
  uint8_t  reserved[3];
  float    boundsMin[3], boundsMax[3];            // splat centres
  float    boundingBoxMin[3], boundingBoxMax[3];  // asset box, what readHeader returns
  float    meanSquaredSplatExtent;                // overdraw statistic of this tier
  float    captureExposureEV;
  float    captureWhiteBalance[3];
  float    splatToMesh[16];                       // registration; identity for worlds
  uint64_t chunkIndexOffset, nodeTreeOffset, paletteOffset, payloadOffset, fileSize;
  uint8_t  reserved1[52];
};

struct UntoldGSChunkEntry {         // 64 B — everything needed to serve one byte range
  uint64_t payloadOffset;           // multiple of 16384
  uint32_t payloadBytes;            // padded core + SH
  uint32_t coreBytes;               // 16 × splatCount
  uint32_t splatCount;
  uint16_t lodLevel;                // 0 = coarsest root level
  uint16_t nodeId;
  float    aabbMin[3], aabbMax[3];  // decode constants for 11/10/11 positions
  float    logScaleMin, logScaleMax;
  uint32_t reserved;
  uint32_t crc32;                   // per-chunk integrity
};

struct UntoldGSTreeNode {           // 48 B — k-d tree over the Morton-sorted chunk array
  float    aabbMin[3], aabbMax[3];
  uint32_t child[2];                // 0xFFFFFFFF on leaves
  uint32_t firstChunk, chunkCount;  // chunks contiguous per (node, lod)
  float    geometricError;
  uint32_t visibilityMaskOffset;    // environments only
};
```

**Core record, 16 bytes**, the PlayCanvas `compressed.ply` bit layout:

| Word | Bits | Meaning | Decode |
|---|---|---|---|
| `pos` | 11·10·11 | x, y, z normalised in the chunk AABB | `mix(aabbMin, aabbMax, t)` |
| `rot` | 2 + 3×10 | smallest-three quaternion, index of largest component | 3 masks, 1 sqrt, swizzle |
| `scale` | 11·10·11 | log-scale in the chunk's range | `mix(lo, hi, t)` then `exp` |
| `rgba` | 8×4 | SH DC colour, opacity post-sigmoid | `/ 255` |

A Morton-sorted chunk of 1024 splats on a sofa spans a few centimetres, so 11-bit positions land well under a millimetre. Rotation and scale are kept rather than baked; a per-frame decode pass produces today's `EncodedGaussianSplat` for the existing shaders.

**Optional SH block**, SoA after the core block, in the renderer's existing byte contract (`quantizeGaussianSHCoefficient`, fixed `[-1, 1]`, dequantised by `Gaussians.metal`), 9 / 24 / 45 B per splat, so the chunk bytes bind to the GPU as-is with no second quantisation. A 16-bit palette (up to 65 536 SH vectors, 2 B per splat) is reserved by a flag for large environments. Objects viewed close ship degree 2 or 3.

**Within-chunk order** is importance descending, so a partial read of a chunk yields its most important splats first.

### 4.3 The baker: `untoldengine export`

`export` already takes a `.ply` and writes `.untoldgs` tiers; the cooking steps join it as flags, and the logic lives in the engine as a testable library (`UntoldGSCooker`) so the command stays thin.

1. **Import, register, crop.** Parse (`PLYReader`). Bake a similarity transform (`--splat-scale`, `--splat-yaw-degrees`, `--splat-translate`, `--splat-flip-yz` for the 3DGS training convention) into positions, rotations and scales and record it in the header. Crop to a box (`--splat-crop`, `--splat-crop-margin`) to remove floaters and the captured floor. Drop opacity under `--splat-min-opacity` (default 0.005) and degenerate geometry. Registration by ICP against the mesh twin is a follow-up; the editor can override the transform.
2. **Prune, order, chunk.** Importance ranking as today (spatially interleaved, opacity × area), later replaced by rendered contribution (max α·T over sample views) from a headless Metal pass. Morton-sort; cut into chunks of 1024 (`--splat-chunk-splats`); per-chunk AABB and log-scale ranges; the k-d tree over the sorted array; SH degree selection (`--splat-sh-degree`).
3. **Tiers.** `--lod-levels N` keeps producing nested tiers, now as v3 files; phase 2 folds the tiers into one file as `lodLevel` chunk ranges under the same tree, and adds merged coarse levels (opacity × area weights, moment-matched covariance) with a root level ≤ 32 K splats. The budget table (splat count per level, screen-height switch points) is written into the `gaussianAsset` record.

For a **window** the baker additionally takes the view cell and the portal rectangle and bakes portal visibility, per-chunk finest LOD, importance from the room, and a splat skybox (§4.6).

### 4.4 Runtime

Budgets are set for Vision Pro and scaled per platform, and the budget is a **runtime variable**: a conservative default per detected GPU family, then adjusted each frame from the measured splat-pass GPU time (slow ramp up, fast ramp down).

| Platform | Frame | Post-cull splats | Resident | SH tier | Load path |
|---|---|---|---|---|---|
| Vision Pro M2 (2024) — floor | 11.1 ms · 2 eyes | 0.5–0.8 M per eye | 15–20 M | degree 2 or palette | Metal IO |
| Vision Pro M5 (2025) — target | 11.1 ms, or 8.3 ms at 120 Hz | 0.8–1.5 M per eye | 20–30 M | degree 3 or palette | Metal IO |
| Apple silicon Mac | 16.7 ms | 4–8 M | 30 M+ | degree 3 | mmap or Metal IO |
| iPad Pro | 8.3 / 16.7 ms | 2–4 M | 10–20 M | degree 2 or palette | Metal IO |
| iPhone | 16.7 ms | 1–2 M | 5–10 M | degree ≤ 2 or palette | Metal IO |

Per-eye draw cost dominates on Vision Pro; vertex amplification is a later renderer-wide optimisation, not a dependency.

**Once per frame, before the eye loop:**

1. *Object gate.* Per splat entity: world AABB, padded frustum test, screen-height estimate, LOD pick from the budget table adjusted so the sum across visible objects fits the frame budget. Entities that fail are skipped entirely.
2. *Chunk cull.* One thread per chunk of the chosen LOD of each visible object: frustum test with extent; Hi-Z test optional for objects, mandatory for environments; portal-frustum test for windows; output a compact chunk list with entity index and LOD blend weight.
3. *Decode, project, compact.* One thread per splat of surviving chunks, indirect dispatch: unpack the 16-byte record with the chunk's constants, apply the entity transform and LOD opacity weight, build covariance, project with the head-centre view, reject off-screen footprints, append a depth key plus packed (entity, splat) index into **one shared key buffer** sized to the frame budget.
4. *One sort.* Today's radix sort over the shared key buffer; overlapping objects blend in true depth order. A 24-bit key needs three passes.

**Per eye (once per frame elsewhere):**

5. *Opaque pass with occluder shells.* Each swapped object's mesh twin renders **depth-only**, shrunk along its normals by a per-object margin (default 2 cm) so it sits just inside the splat surface: hides the splats behind the object while letting surface splats through. The unshrunk twin keeps rendering into the shadow map and stays in the physics world.
6. *Splat draw.* The existing tile-memory pass, one instanced draw over the sorted shared list; the vertex stage reads the entity index for transform and decode constants. Depth test enabled (less-equal, no write) against the opaque depth; fragment stage terminates once the tile's accumulated alpha saturates; post-process still writes alpha-weighted depth.

Foveation: the Compositor Services rasterisation rate map applies to the splat pass directly; it must change shading rate only, never the splat set.

### 4.5 The swap

1. **Armed.** Entity has a mesh and a `gaussianAsset` link. Nothing loaded; optional prefetch inside the streaming radius.
2. **Loading.** Root LOD first, then finer levels. Nothing changes on screen until the chosen level is resident.
3. **Cross-fading**, 200–300 ms. Mesh fades out with `LODSystem`'s dithered cross-fade; splat fades in by opacity in the decode pass. Depth stays continuous because the shrunk occluder shell is already drawn and the splat writes alpha-weighted depth.
4. **Swapped.** Mesh colour draw disabled; depth-only shell, shadow-map draw and collision stay on.
5. **Reverting** runs the fade in reverse and releases pages under memory pressure.

The engine provides the mechanisms (the shell, the dither, the per-entity opacity weight, the scene link, a two-phase splat load) and stays a renderer; steps 1–5 are application policy and live outside the engine in a small package that depends on it (`UntoldGaussianTwins`, first version: whole-payload load on arming, distance with hysteresis, the cross-fade both ways, payload kept resident after a revert; prefetch, per-level loading and release under memory pressure follow with the streamed environment).

**Lighting (decided).** Splats are unlit emissive surfaces in the linear scene. The shader already decodes sRGB→linear and the composite runs before the look and output transform, so a splat is tone-mapped exactly once like an emissive mesh; this keeps a twin consistent with neighbouring meshes under exposure, bloom, fog and grading. The capture was already tone-mapped by the camera, so contrast flattens slightly; the remedy is calibration: a per-asset gain from `captureExposureEV` applied in linear, the real-world tint from `XREnvironmentLightingSystem`, and an editor exposure offset per asset. Compositing after the output transform was rejected: it puts splats outside fog and bloom and breaks ordering with transparent meshes drawn over them. Capture discipline (soft, neutral, even light, recorded exposure) decides most of the result.

**Registration.** ICP against the twin fixes scale and orientation at cook time. Soft objects differ from their model by centimetres; the shell margin must cover it (manifest value, editor slider).

### 4.6 The world through a window

The head stays in the room and everything is seen through one rectangle, so the set of chunks that can ever be visible (union over head positions of the portal frustum) and the finest LOD each chunk ever needs (from its minimum distance to the view cell) are both fixed at cook time. The result is a baked resident set that loads once at scene start; streaming and LOD popping are gone by construction.

Authoring: the view cell (room volume, including the space against the glass), the portal rectangle (from the mesh; multiple windows share one baked set), and placement so ground, horizon and scale agree with the room (stored as the world's registration transform).

Cooker bake: sample head positions across the cell; a chunk is visible if it intersects any sample's portal frustum and is not fully behind the world's own opaque core from every sample; per-chunk finest LOD from minimum distance at Vision Pro pixel density; importance rendered from the room through the window; a splat skybox beyond the distance where head parallax across the room is under a pixel; manifest entry with the baked (chunk, level) list.

Runtime: load once (near band finest first); chunk cull with the portal pyramid from the current eye; walls, frame and mullions occlude through the depth buffer; shared sort with any splat object in the room; degree-3 SH for the near band; if the head leaves the cell, clamp, or hand the same file to the streamed-environment mode.

The near band is decided at capture: dense coverage of the first few metres beyond the window from the angles and heights the room allows.

### 4.7 The streamed environment (later)

Same file, same renderer, three additions: a `SplatStreamingSystem` mirroring `GeometryStreamingSystem` with a private heap sub-allocated into 64 KB pages, a chunk-to-page table, LRU eviction under the memory budget and Metal IO loads from a LZFSE-compressed file signalled by shared events; a baked proxy (voxelise opacity ≥ 0.1 at 5 cm, seal, marching cubes, QEM) yielding an eroded occluder, a carved collision mesh and a vertex-coloured impostor; per-room visible sets from carved navigable voxels as view cells. LOD becomes a merge hierarchy with a traversal-free cut at τ ≈ 6 px.

---

## 5. No popping while moving

| Symptom | Cause | Countermeasure |
|---|---|---|
| Flicker inside an object as the head turns | Sort-order popping: overlapping splats swap depth order; worst with a stale sort or per-eye sorts | GPU sort every frame, never skipped, over the shared key buffer, 24–32-bit keys; one order for both eyes along the head-centre axis. Optional later: per-tile re-sort queue in the tile shader (StopThePop). |
| Splats vanishing at the screen edge | Culling popping: today's centre-point test | Chunk test with extent, splat test on the projected 3σ footprint with a guard band; hysteresis on Hi-Z and visibility thresholds. |
| Detail jumping when walking toward an object | LOD popping | Level by projected size, not distance; parent–child opacity remap `1 − (1 − α_parent)^(1/K)` interpolated over a band of τ; hysteresis per node; camera-position cross-fade between independent sets. |
| A region snapping from blurry to sharp | Streaming popping | Coarse level always resident; arriving chunks fade in over 150–300 ms; prefetch by velocity look-ahead; hold the current level under a stall. |
| Shimmer on fine detail | Aliasing: sub-pixel splats; the shader's 0.1 px low-pass is too small | Mip-Splatting: 3D smoothing filter at cook time sized to capture density, 0.3 px dilation at render time, `antialiased` flag in the header; coarser LOD removes sub-pixel splats at distance. |
| The object flashing at the swap | Swap popping | §4.5: nothing changes until the level is resident, then a 200–300 ms dithered cross-fade with continuous depth. |

Principle: the cut is updated every frame but every change passes through a blend; the resident set is diffed, not rebuilt; hysteresis is the default on every threshold; the sort is never skipped.

Tests: an orbit around one swapped object at arm's length, and a walk through a world splat past a LOD boundary. Record per frame the number of splats whose draw state changed, sort-order flips among overlapping pairs in a sample tile, and frame-to-frame image difference on a static-scene path.

---

## 6. Compatibility guarantees

- Every registration entry point keeps its signature and behaviour: `setEntityGaussian(entityId:filename:withExtension:)`, `setEntityGaussianAsync`, `setEntityGaussian(source:)`, `setEntityGaussianStreaming(source:options:)`. `.ply` keeps loading directly.
- `UntoldGSFormat.read(from:)` still returns `UntoldGSAsset` in the layout the renderer consumes; `readHeader(from:)` still returns the baked bounding box through a bounded read. Only `write` changes shape (it takes splats with rotation and scale, not baked covariances), and its only caller is the bake.
- `.untoldgs` v1 and v2 files fail with `.unsupportedVersion`; re-run `untoldengine export`. This is the format's own contract.
- `untoldengine export` keeps every existing flag; the cooking flags are optional and default to today's behaviour.
- Existing gaussian render tests (`GaussianRenderingTest`, `GaussianStreamingTest`, `GaussianProgressiveLODTest`) keep passing, with the three tests that pinned v2 header offsets moved to v3.
- No new package dependencies. `Package.swift` keeps `dependencies: []`.
- The `.untold` format version does not change; `gaussianAsset` is a new core chunk type that older runtimes ignore.

## 7. Decisions locked before PR 2

| Decision | Choice |
|---|---|
| Container | `.untoldgs` version 3 (chunked payload under the existing name, magic and entry points), referenced from a `gaussianAsset` chunk in `.untold` (§4.1). |
| Cooker location | Flags on the existing `untoldengine export`; logic in the engine as `UntoldGSCooker`. |
| First test asset | One captured object with its mesh twin. |
| Colour pipeline | Linear, pre-tone-map, as the shader already does; add per-asset gain, XR tint, editor offset. |
| Chunk size | 1024 splats (16 KB core) for objects; 4096 (64 KB) for environments; header field. |
| Core record | 16 B, PlayCanvas `compressed.ply` bit layout. |
| Sort | Existing radix sort over one shared, budget-sized key buffer across all splat entities; every frame; 24-bit keys. |
| SH bytes | The renderer's existing `[-1, 1]` byte contract, so chunk bytes bind to the GPU unchanged. |
| Occluder for twins | The mesh itself, depth-only, shrunk by a per-object margin (default 2 cm). |

---

## 8. Delivery plan — PR breakdown

Each PR is one reviewable unit, lands on the fork first, and is replayed to `untoldengine/UntoldEngine` once the series is verified end to end, with any follow-up patches the fork accumulated folded into it (parts 7 and its refactor squash into one). PR N+1 is based on PR N's branch when it depends on it. The first draft of this plan proposed a separate `.usplat` format and a `cook-splats` command; both were folded into the existing `.untoldgs` format and `export` command once the August 2026 gaussian work on `develop` was audited.

| # | Branch | Title | Contents | Depends on |
|---|---|---|---|---|
| 1 | `docs/gaussian_splat_streaming_proposal` | [Docs] Gaussian splat streaming proposal | This document. | — |
| 2 | `feature/usplat_format` | [Feature] `.untoldgs` v3: chunked, quantised splat payload | `UntoldGSFormat` moved from `RegistrationSystem` into `AssetFormat/UntoldGS*.swift`; v3 header, chunk index, tree; 16 B record packing; Morton order; per-chunk CRC; writer; range reader (`UntoldGSFile`); `read`/`readHeader` unchanged in shape; the bake writes v3 tiers. Unit tests plus the v2-pinned render tests moved to v3. | 1 |
| 3 | `feature/untold_gaussian_asset_chunk` | [Feature] `gaussianAsset` chunk in `.untold` | New core `UntoldChunkType` and `UntoldGaussianAssetRecordV1` (payload path, twin link, budgets, occluder shrink, exposure offset, swap distance); codable + reader decode + validation; tests. | — |
| 4 | `feature/cook_splats_cli` | [Feature] Cooking flags for `untoldengine export` | `UntoldGSCooker` (registration transform, crop, opacity floor, SH degree, chunk size) applied inside `bakeGaussianSplatProgressiveTiers`; `--splat-*` flags on `export`; CLI package identity pinned so it builds in worktrees. Tests on synthetic assets. | 2 |
| 5 | `feature/gaussian_usplat_runtime` | [Feature] Range-load `.untoldgs` v3 with a GPU decode pass | Load chunks by range (FileHandle, then Metal IO) into a page pool; decode compute kernel producing `EncodedGaussianSplat` into the existing buffers; the existing async, LOD and streaming paths unchanged; render test PLY vs v3 by PSNR. | 2, 3 |
| 6 | `feature/gaussian_shared_sort` | [Feature] Shared sort and single draw across splat entities | Shared key buffer (sized to the resident total, not yet a budget) with packed entity index; one radix sort; one draw with per-entity constants; indirect dispatch removes the CPU readback. Render tests with two overlapping entities. Shipped without the chunk-level cull, which moved to row 8. | 5 |
| 7 | `feature/gaussian_twin_swap`, `refactor/gaussian_twin_generic` | [Feature] Mesh occluder shell, mesh fade, per-entity splat blend and gaussianAsset link (the two fork PRs squash into this one upstream) | Engine mechanisms only: `MeshOccluderComponent` (depth-only shrunk shell pass), `MeshFadeComponent` (dither), per-entity splat opacity, exposure gain and XR tint, `GaussianAssetLinkComponent` from the `.untold` record, a URL splat loader for mesh entities; how-to guide update. Render tests. The swap policy (states, distance, hysteresis, fade clock) lives in the application-side `UntoldGaussianTwins` package. | 6 |
| 8 | `feature/gaussian_budgeted_working_set` | [Feature] Budgeted working set fed by chunk-level culling | Shipped in two stages. Stage 1: the `.untoldgs` chunk table is retained on the component; `gaussianChunkCull` tests each chunk's centre AABB padded by `kGaussianQuadSigma·exp(logScaleMax)` against the guard-banded frustum (either eye in stereo, both rebuilt with the current scene root) and the previous frame's HZB; `GaussianDebugOptions.disableChunkCull`. Stage 2: the 16-byte records stay resident and the 48-byte encoded buffer and per-slot index buffers are gone for chunked entities; one fused pass per visible chunk (`gaussianChunkDecodePreprocess`) decodes, tests (either eye), projects and compacts into the shared set; the set is sized to `GaussianRuntimeLimits.workingSetSplats` (1 M mobile, 6 M Mac, clamped by the memory budget and the resident total, `workingSetSplatsOverride`); per-chunk quotas `floor(scale × count)` from a persistent `GaussianBudgetState` with ±10 %/frame hysteresis and an opacity band over the last fifth of each truncated chunk; the shared set has its own `MemoryBudgetManager` entry; per-entity caps raised to 20 M / 40 M; `disableWorkingSetBudget`. `.ply` entities keep the whole-buffer path, unbudgeted. | 6 |

Phase 2 (tiers as chunk ranges in one file, merged coarse levels, object budgets, the window bake) and phase 3 (streamed environment) follow as their own series once PRs 1–7 are merged upstream.

## Appendix A — Test scenes

- **Object orbit:** one twin at 1 m, camera orbit 360° at 90 samples; assert zero splat-state changes outside LOD bands and PSNR against the PLY reference ≥ 33.5 dB (the CI threshold).
- **Two overlapping twins:** table in front of sofa; assert the composite matches a single merged asset within 0.5 dB (proves the shared sort).
- **World walk:** a world splat crossed at 1 m/s past a LOD boundary; assert per-frame changed-splat count stays under budget and no frame-to-frame difference spike above the static-path baseline.

## Appendix B — Sources

LOD and hierarchy: Virtualized 3D Gaussians (arXiv 2505.06523), NanoGS (github.com/TimChen1383/NanoGaussianSplatting), LODGE (arXiv 2505.23158), Hierarchical 3DGS (arXiv 2406.12080), A LoD of Gaussians (arXiv 2507.01110), FilterGS (arXiv 2603.23891), Octree-GS (arXiv 2403.17898), CityGaussian (arXiv 2404.01133), FLoD (arXiv 2408.12894), CLoD-GS (arXiv 2510.09997), LapisGS (arXiv 2408.14823), Voyager (arXiv 2506.02774), Taming 3DGS (arXiv 2406.15643).

Formats and I/O: PlayCanvas compressed PLY (blog.playcanvas.com/compressing-gaussian-splats), SOG and Streamed SOG (developer.playcanvas.com/user-manual/gaussian-splatting/formats), splat-transform (github.com/playcanvas/splat-transform), Spark 2.0 `.rad` (sparkjs.dev/docs/packed-splats), Niantic SPZ (github.com/nianticlabs/spz), KHR_gaussian_splatting (github.com/KhronosGroup/glTF), 3DGS compression survey (w-m.github.io/3dgs-compression-survey), Metal fast resource loading (WWDC22 10104; MTLIOCommandQueue, MTLIOCompressionContext), `makeBuffer(bytesNoCopy:)`, RealityKit `GaussianSplatResource`.

Visibility, pruning, proxies: Proxy-GS (arXiv 2509.24421), OccluGaussian (arXiv 2503.16177), RadSplat (arXiv 2403.13806), PAGS (arXiv 2510.12282), NVGS (arXiv 2511.19202), Mini-Splatting (arXiv 2403.14166), Speedy-Splat (arXiv 2412.00578), PUP 3D-GS (arXiv 2406.10219), LightGaussian (arXiv 2311.17245), StopThePop (arXiv 2402.00525), Mip-Splatting (arXiv 2311.16493), splat-transform collision meshes (developer.playcanvas.com/user-manual/splat-transform/collision), 2DGS (arXiv 2403.17888), PGSR (arXiv 2406.06521), MeshSplatting (meshsplatting.github.io).

Sorting and Apple GPUs: MetalSplatter (github.com/scier/MetalSplatter), Unity Gaussian Splatting (github.com/aras-p/UnityGaussianSplatting), Linebender GPU sorting notes (linebender.org/wiki/gpu/sorting), msplat (github.com/rayanht/msplat), Apple TBDR guidance (developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering), viewer ceilings on Apple devices (swyvl.io/blog/best-gaussian-splat-viewers).
