# Gaussian Splat Streaming: object twins, windows, and worlds

**Status:** Proposal — no code yet
**Scope:** Gaussian splat assets in UntoldEngine core: a cooked payload format, an offline cooker in the Swift CLI, and the runtime residency, culling, LOD and sort changes needed to render millions of splats inside a normal mesh scene. All Apple platforms; designed against Apple Vision Pro.
**Baseline:** `develop` as of 2026-09-04.
**Series tracker:** see §8 for the planned PR breakdown; the live status of each PR is kept in the tracking issue on the fork.

---

## 1. Purpose

Splats in UntoldEngine today are one `.ply` read whole into memory, expanded into one flat GPU buffer, culled per splat every frame, sorted per entity every frame, and drawn one entity at a time. That is fine for a viewer and wrong for the use the engine now needs:

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

| Stage | Today | Where |
|---|---|---|
| Load | PLY only. Whole file into `Data`, whole body into Swift arrays, synchronous, no cancellation. | `Utils/PLYReader.swift:80`, `Systems/RegistrationSystem.swift:3206` |
| GPU layout | 64 B `EncodedGaussianSplat` with covariance baked at load; rotation and scale not recoverable. SH as Float16, up to 90 B per splat. | `CShaderTypes/ShaderTypes.h:554`, `RegistrationSystem.swift:3376` |
| Resident bytes | ≈166 B per splat with SH3. Hard cap 5,242,880. Not registered with `MemoryBudgetManager`. | `Systems/GaussianSystem.swift:23` |
| Culling | Per-splat centre-point frustum test over all N splats of every entity, every frame. No entity bounds test, no occlusion, no LOD. Visible count read back on the CPU one frame late. | `Shaders/BitonicSort.metal:50`, `GaussianSystem.swift:167` |
| Sort | 4-pass 8-bit radix sort on 32-bit eye-depth keys, **per entity**, front-to-back. Two overlapping splat entities blend in entity order, not depth order. | `Shaders/DeviceRadixSort.metal`, `Utils/Globals.swift:62` |
| Draw | Tile-memory pass: imageblock cleared, instanced quad per splat, front-to-back over-compositing with a raster order group, post-process writes colour and alpha-weighted depth into the shared depth buffer. Depth attachment is loaded from the model pass, so meshes and splats already occlude each other. One draw per entity. | `Renderer/RenderPasses.swift:4315`, `Shaders/Gaussians.metal:278` |
| Colour | Captured colour is decoded sRGB→linear (`gaussianSRGBToLinear`) before the HDR target; composite in `precomp` runs before the look and output transform. | `Shaders/Gaussians.metal:106` |
| XR | Compositor Services; one render loop per eye, no vertex amplification. Culling, splat depth keys and the radix sort run once before the eye loop. Shadows on eye 0 only. Hi-Z built once after both eyes. | `UntoldEngineXR/UntoldEngineXR.swift:810`, `Systems/RenderingSystem.swift:152` |
| XR lighting | `XREnvironmentLightingSystem` exposes a smoothed real-world intensity scale and tint from ARKit probes. | `UntoldEngineXR/XREnvironmentLightingSystem.swift` |

**Ready to reuse:** the once-per-frame sort before the eye loop; the shared depth attachment in the splat pass; the `.untold` container and `TileManifest` LOD entries; `LODSystem` hysteresis and dithered cross-fade; `GeometryStreamingSystem` (`buildStreamingFrustum`, prefetch, eviction, velocity look-ahead); `MemoryBudgetManager`, `MeshResourceManager`, `ProgressiveAssetLoader`; `HZBCompute.metal`; the CLI package with `ExportTilesCommand` as a template.

**Blocking gaps, in order:** per-entity sort and draw; no asset subdivision, so no LOD; no async load path; `GaussianComponent` holds one buffer set with no residency or LOD state; rotation and scale destroyed at encode; sort buffers sized 8×N at load; no memory accounting; nothing links a splat entity to its mesh twin.

---

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

### 4.1 Container decision: new payload file, referenced from `.untold`

The `.untold` reader reads the whole file into memory (`Data(contentsOf:)`, payload access by `subdata`) and validates a SHA-256 over every chunk payload on open (`UntoldReader.swift:223`). That is right for meshes and wrong for a payload that must be read by 16 KB ranges and never be fully resident. Its header is mesh-shaped and its production writer is the Python exporter.

So: the bulk splat data goes in its own file, **`.usplat`**, written by the Swift cooker and read by range through Metal fast resource loading or mmap, with per-chunk integrity instead of a whole-file hash. Everything the scene needs to know about a splat is small and stays in `.untold` as a new **core** chunk type, `gaussianAsset`: path to the payload, registration transform, mesh-twin link, budget table, window view cell and portal bake, skybox reference. `TileManifest` references it like a LOD level. This mirrors how textures live in `.utex` and are referenced. One payload format for all four modes, never embedded, so there is one load path.

### 4.2 The `.usplat` payload

Goals in priority order: any chunk loads on its own by byte range; a chunk lands in a GPU page with no CPU transform; the first read shows the whole asset coarsely; rotation and scale survive for LOD and re-encoding; SH is optional per device tier; an object file carries its registration and capture lighting.

```
[0]        FileHeader          128 B, padded to 16 KB
[16 KB]    ChunkIndex          chunkCount × 64 B, padded to 16 KB multiple
[…]        NodeTree            nodeCount × 48 B, padded
[…]        Palettes            optional SH palette, 16 KB aligned
[…]        Chunk payloads      each 16 KB aligned: core block, then optional SH block
```

Every payload offset is a multiple of 16 384 bytes, the page size on all current Apple devices: `makeBuffer(bytesNoCopy:)` over an mmap needs page-aligned pointer and length, and Metal fast resource loading decompresses on 64 KB chunk boundaries.

```c
struct FileHeader {                 // 128 B
  char     magic[4];                // "USPL"
  uint16_t versionMajor, versionMinor;
  uint32_t flags;                   // hasSH, shPalette, antialiased, mtlioCompressed, isEnvironment
  uint8_t  shDegree;                // 0..3
  uint8_t  coordSys;                // SPZ-style enum, RUB default
  uint8_t  colorSpace;              // sRGB display-referred or linear scene-referred
  uint8_t  log2ChunkSplats;         // 10 → 1024 (objects), 12 → 4096 (environments)
  uint32_t splatCount;              // across all LOD levels
  uint32_t chunkCount, nodeCount;
  uint8_t  lodLevels;               // ≤ 8
  uint8_t  reserved[3];
  float    boundsMin[3], boundsMax[3];
  float    splatToMesh[16];         // rigid + uniform scale; identity for worlds
  float    captureExposureEV;
  float    captureWhiteBalance[3];
  uint64_t chunkIndexOffset, nodeTreeOffset, paletteOffset, payloadOffset;
};

struct ChunkIndexEntry {            // 64 B — everything needed to serve one byte range
  uint64_t payloadOffset;           // multiple of 16384
  uint32_t payloadBytes;            // padded core + SH
  uint32_t coreBytes;               // 16 × splatCount
  uint32_t splatCount;
  uint16_t lodLevel;                // 0 = coarsest root level
  uint16_t nodeId;
  float    aabbMin[3], aabbMax[3];  // decode constants for 11/10/11 positions
  float    logScaleMin, logScaleMax;
  uint16_t shMin, shMax;            // fp16 range, or 0 when a palette is used
  uint32_t crc32;                   // per-chunk integrity
};

struct TreeNode {                   // 48 B — k-d tree over the Morton-sorted array
  float    aabbMin[3], aabbMax[3];
  uint32_t child[2];                // 0xFFFFFFFF on leaves
  uint32_t firstChunk, chunkCount;  // chunks contiguous per (node, lod)
  float    geometricError;
  uint32_t pvsCellMaskOffset;       // environments only
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

**Optional SH block**, SoA after the core block: direct u8 per coefficient in the chunk's own range (9 / 24 / 45 B), or a 16-bit index into a per-file palette of up to 65 536 SH vectors (2 B per splat, one dependent read). Objects viewed close ship degree 2 or 3.

**Within-chunk order** is importance descending, so a partial read of a chunk yields its most important splats first.

### 4.3 The cooker: `untoldengine cook-splats`

A subcommand in `Tools/UntoldEngineCLI`; the logic lives in the engine as a testable library (`GaussianSplatCooker`) and the command is a thin wrapper. For an object it takes the capture (PLY first; SPZ and SOG later) and the mesh twin, and writes one `.usplat` plus a `gaussianAsset` record.

1. **Import, register, crop.** Parse (reuse `PLYReader`). Align the splat to the mesh twin: coarse fit by bounds and principal axes, then ICP of splat centres against the mesh surface; store as `splatToMesh`; editor override. Crop to the mesh bounds plus margin (floaters, captured floor). Drop opacity < 0.005.
2. **Prune, order, chunk.** Render from a few hundred cameras around the object with a headless Metal pass; accumulate per-splat max α·T (RadSplat score) and hit × opacity × volume (LightGaussian score); prune to the object's budget — for objects at arm's length a 50–70 % cut, not 90. Morton-sort; cut into runs of 1024; compute per-chunk AABB, log-scale and SH ranges; build the k-d tree over the sorted array. Estimate capture exposure and white balance from the SH DC of neutral regions.
3. **LOD and shells.** Two coarser levels by merging Morton neighbours (opacity × area weights, moment-matched covariance); optionally re-fit each cluster against renderings of the original (V3DG). Root level ≤ 32 K splats. Emit the twin's simplified shell for the depth-only occluder pass. Write the budget table: splat count per level and the screen-height in pixels at which the next level is preferred.

For a **window** the cooker additionally takes the view cell (room volume) and the portal rectangle and bakes portal visibility, per-chunk finest LOD, importance from the room, and a splat skybox (§4.6).

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

- `setEntityGaussian(entityId:filename:withExtension:)` keeps its signature and behaviour for `.ply`. Internally it cooks to `.usplat` on first load (cached next to the asset or in `AssetDiskCache`) and takes the new path with the twin link empty and every chunk resident.
- Existing `GaussianRenderingTest` targets keep passing; the PLY and `.usplat` paths are compared by PSNR in a new render test.
- No new package dependencies. `Package.swift` keeps `dependencies: []`.
- The `.untold` format version does not change; `gaussianAsset` is a new core chunk type that older runtimes ignore (guarded by the existing unknown-chunk test).

---

## 7. Decisions locked before PR 2

| Decision | Choice |
|---|---|
| Container | `.usplat` payload file referenced from a `gaussianAsset` chunk in `.untold` (§4.1). |
| Cooker location | Swift CLI (`Tools/UntoldEngineCLI`), logic in the engine as a testable library. |
| First test asset | One captured object with its mesh twin. |
| Colour pipeline | Linear, pre-tone-map, as the shader already does; add per-asset gain, XR tint, editor offset. |
| Chunk size | 1024 splats (16 KB core) for objects; 4096 (64 KB) for environments; header field. |
| Core record | 16 B, PlayCanvas `compressed.ply` bit layout. |
| Sort | Existing radix sort over one shared, budget-sized key buffer; every frame; 24-bit keys. |
| Occluder for twins | The mesh itself, depth-only, shrunk by a per-object margin (default 2 cm). |

---

## 8. Delivery plan — PR breakdown

Each PR is one reviewable unit, lands on the fork first, and is replayed to `untoldengine/UntoldEngine` unchanged once the series is verified end to end. PR N+1 is based on PR N's branch when it depends on it.

| # | Branch | Title | Contents | Depends on |
|---|---|---|---|---|
| 1 | `docs/gaussian_splat_streaming_proposal` | [Docs] Gaussian splat streaming proposal | This document. | — |
| 2 | `feature/usplat_format` | [Feature] `.usplat` cooked splat payload format | Header, chunk index, tree node structs; pack/unpack of the 16 B record (11/10/11 position, smallest-three rotation, log-scale, RGBA8); Morton ordering; chunking with per-chunk ranges; writer; range-based reader (FileHandle and mmap); CRC32 per chunk. Unit tests: roundtrip, 16 KB alignment, quantisation error bounds, CRC rejection. | 1 |
| 3 | `feature/untold_gaussian_asset_chunk` | [Feature] `gaussianAsset` chunk in `.untold` | New core `UntoldChunkType` and `UntoldGaussianAssetRecordV1` (payload path, registration, twin link, exposure, margin, budget table); codable + reader decode; tests incl. unknown-chunk forward compatibility. | — |
| 4 | `feature/cook_splats_cli` | [Feature] `cook-splats` cooker and CLI command | `GaussianSplatCooker` library: PLY import, crop, opacity prune, optional registration matrix, Morton, chunk, write `.usplat` + `gaussianAsset`. CLI subcommand. Tests on a synthetic PLY. Importance pruning, ICP and LOD levels are follow-ups. | 2, 3 |
| 5 | `feature/gaussian_usplat_runtime` | [Feature] Load `.usplat` at runtime with a per-frame decode pass | `setEntityGaussianAsync` for `.usplat`; `GaussianComponent` page table; decode compute kernel producing `EncodedGaussianSplat` into the existing buffers; `MemoryBudgetManager` registration; `.ply` path cooks on first load. Render test: PLY vs `.usplat` PSNR. | 2, 3 |
| 6 | `feature/gaussian_shared_sort` | [Feature] Shared sort and single draw across splat entities | Chunk-level frustum cull with extent; shared budget-sized key buffer with packed entity index; one radix sort; one draw with per-entity constants; indirect dispatch removes the CPU readback. Render tests with two overlapping entities. | 5 |
| 7 | `feature/gaussian_twin_swap` | [Feature] Mesh-to-splat twin swap with occluder shell and cross-fade | `GaussianTwinComponent`; depth-only shrunk shell pipeline; depth test in the splat pipeline; cross-fade; per-asset gain and XR tint uniform; how-to guide update. Render tests. | 6 |

Phase 2 (object LOD, budgets, the window bake) and phase 3 (streamed environment) follow as their own series once PRs 1–7 are merged upstream.

---

## Appendix A — Test scenes

- **Object orbit:** one twin at 1 m, camera orbit 360° at 90 samples; assert zero splat-state changes outside LOD bands and PSNR against the PLY reference ≥ 33.5 dB (the CI threshold).
- **Two overlapping twins:** table in front of sofa; assert the composite matches a single merged asset within 0.5 dB (proves the shared sort).
- **World walk:** a world splat crossed at 1 m/s past a LOD boundary; assert per-frame changed-splat count stays under budget and no frame-to-frame difference spike above the static-path baseline.

## Appendix B — Sources

LOD and hierarchy: Virtualized 3D Gaussians (arXiv 2505.06523), NanoGS (github.com/TimChen1383/NanoGaussianSplatting), LODGE (arXiv 2505.23158), Hierarchical 3DGS (arXiv 2406.12080), A LoD of Gaussians (arXiv 2507.01110), FilterGS (arXiv 2603.23891), Octree-GS (arXiv 2403.17898), CityGaussian (arXiv 2404.01133), FLoD (arXiv 2408.12894), CLoD-GS (arXiv 2510.09997), LapisGS (arXiv 2408.14823), Voyager (arXiv 2506.02774), Taming 3DGS (arXiv 2406.15643).

Formats and I/O: PlayCanvas compressed PLY (blog.playcanvas.com/compressing-gaussian-splats), SOG and Streamed SOG (developer.playcanvas.com/user-manual/gaussian-splatting/formats), splat-transform (github.com/playcanvas/splat-transform), Spark 2.0 `.rad` (sparkjs.dev/docs/packed-splats), Niantic SPZ (github.com/nianticlabs/spz), KHR_gaussian_splatting (github.com/KhronosGroup/glTF), 3DGS compression survey (w-m.github.io/3dgs-compression-survey), Metal fast resource loading (WWDC22 10104; MTLIOCommandQueue, MTLIOCompressionContext), `makeBuffer(bytesNoCopy:)`, RealityKit `GaussianSplatResource`.

Visibility, pruning, proxies: Proxy-GS (arXiv 2509.24421), OccluGaussian (arXiv 2503.16177), RadSplat (arXiv 2403.13806), PAGS (arXiv 2510.12282), NVGS (arXiv 2511.19202), Mini-Splatting (arXiv 2403.14166), Speedy-Splat (arXiv 2412.00578), PUP 3D-GS (arXiv 2406.10219), LightGaussian (arXiv 2311.17245), StopThePop (arXiv 2402.00525), Mip-Splatting (arXiv 2311.16493), splat-transform collision meshes (developer.playcanvas.com/user-manual/splat-transform/collision), 2DGS (arXiv 2403.17888), PGSR (arXiv 2406.06521), MeshSplatting (meshsplatting.github.io).

Sorting and Apple GPUs: MetalSplatter (github.com/scier/MetalSplatter), Unity Gaussian Splatting (github.com/aras-p/UnityGaussianSplatting), Linebender GPU sorting notes (linebender.org/wiki/gpu/sorting), msplat (github.com/rayanht/msplat), Apple TBDR guidance (developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering), viewer ceilings on Apple devices (swyvl.io/blog/best-gaussian-splat-viewers).
