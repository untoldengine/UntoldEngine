# Enabling Gaussian System in Untold Engine

The Gaussian System in the Untold Engine is responsible for rendering Gaussian Splatting models. It enables you to visualize high-quality 3D reconstructions created from photogrammetry or neural rendering techniques, providing a modern approach to displaying complex 3D scenes.

## How to Enable the Gaussian System

### Step 1: Create an Entity

Start by creating an entity that represents your Gaussian Splat object.

```swift
let myEntity = createEntity()
```

---

### Step 2: Link a Gaussian Splat to the Entity

To display a Gaussian Splat model, load its .ply file and link it to the entity using setEntityGaussian.

```swift
setEntityGaussian(entityId: myEntity, filename: "splat", withExtension: "ply")
```

You can also use the source-based API:

```swift
setEntityGaussian(
    entityId: myEntity,
    source: .single(filename: "splat", withExtension: "ply")
)
```

Parameters:

- entityId: The ID of the entity created earlier.
- filename: The name of the .ply file (without the extension).
- withExtension: The file extension, typically "ply".

> Note: The Gaussian System renders point cloud data stored in the .ply format. Ensure your Gaussian Splat file is properly formatted and contains the necessary attributes (position, color, opacity, scale, rotation).

A baked `.untoldgs` file (see [Exporting Assets](UsingUntoldEngineCLI.md#gaussian-splat-captures))
loads the same way and is the faster path: its chunks are read by byte range and decoded on the
GPU, so nothing is parsed on the CPU.

```swift
setEntityGaussian(entityId: myEntity, filename: "splat", withExtension: "untoldgs")
```

Both forms load synchronously and keep the splat resident for the entity's lifetime, and both
compute the entity's `LocalTransformComponent.boundingBox` automatically from the loaded splat
positions — no bounding box parameter is needed for this path.

---

### Step 3: Loading Without Blocking the Main Thread

`setEntityGaussianAsync` does the same immediate/resident load as `setEntityGaussian`, but
parsing, per-splat encoding, and spherical-harmonics packing all run off the main thread —
only the final component registration touches the world. Use it for a one-off splat load
where you don't want a frame hitch but don't need distance-based streaming.

```swift
Task {
    let ok = await setEntityGaussianAsync(
        entityId: myEntity,
        filename: "splat",
        withExtension: "ply"
    )
    if !ok {
        print("Failed to load splat")
    }
}
```

`completion` is an optional alternative to checking the returned `Bool`:

```swift
await setEntityGaussianAsync(
    entityId: myEntity,
    filename: "splat",
    withExtension: "ply"
) { success in
    print(success ? "Loaded" : "Failed to load splat")
}
```

---

### Running the Gaussian System

Once everything is set up:

1. Run the project.
2. Your Gaussian Splat model will appear in the game window.
3. If the model is not visible or appears incorrect, revisit the file path and format to ensure everything is loaded correctly.

---

## Several splat entities in one scene

Every frame the engine compacts the visible splats of all Gaussian entities into one shared working set, sorts it once by depth and draws it with one instanced draw. Two captures that overlap on screen — a chair partly in front of a table, a prop on a splat floor — therefore blend in true depth order; the order the entities were created in does not matter. The shared set is sized to a **working-set budget** (below), not to what is loaded; `.untoldgs` entities are fitted to it chunk by chunk, so a scene that asks for more than the budget draws the most important splats of every visible chunk. A `.ply` is not budgeted: it always fits (the set is never smaller than the whole-buffer entities' resident total) and its visible count is reserved out of the budget before the `.untoldgs` entities are fitted to the rest. Should the entities nonetheless append more than the set holds, the excess is dropped for that frame and reported through `handleError` and the Gaussian profile line as overflow — a defect, not a mode of operation. Up to 256 splat entities can be drawn in one frame.

## Chunk-level culling and the working-set budget of `.untoldgs` assets

A baked `.untoldgs` asset keeps its chunk table after the load: the per-chunk decode constants
(`GaussianChunkDecodeConstants`, 48 bytes per chunk — the chunk's centre bounding box, its
log-scale range, its first splat and count) stay on the GPU, and the file's index stays on the
CPU (`GaussianComponent.chunkTable`). Its splats stay resident as the file's own 16-byte
records (`GaussianComponent.packedSplatData`) — or, above the **paging threshold**, live in a
bounded **page pool** of 256-rank tiers that the frames fill from disk on demand (below) — and
are decoded every frame, only for the chunks in view: the engine first tests whole chunks — the centre box padded by the largest splat the
chunk holds, against the camera frustum and, when available, the previous frame's depth
pyramid — then fits the survivors to the working-set budget, and only then runs one fused pass
per visible chunk that decodes, tests, projects and compacts its splats (see
[renderingSystem.md §3b–3c](../Architecture/renderingSystem.md#3b-gaussian-frustum-culling--executegaussianfrustumcullingcommandbuffer)).
In a stereo frame a chunk, and a splat, is kept when either eye sees it; the depth pyramid,
built from the last eye drawn, is consulted only for that eye. With the budget unlimited the
picture is the same as the whole-buffer path's; what changes is how many splats the frame reads
when part of the asset is off screen or behind an occluder.

### Paging above the threshold

An asset whose unpadded records (16 B plus SH per splat) exceed the paging threshold —
64 MiB on Apple Vision Pro, iPhone, iPad and Apple TV, 512 MiB on the Mac
(`GaussianPagingPolicy.pagingThresholdBytes…`, never above the residency budget) — is not
read at load. What stays resident is the chunk table (48 B per chunk on the GPU, the file's
index on the CPU) plus, per in-flight frame, a residency table, a page table and a demand
table (about 4 MB for 20 M splats); the records go into a **page pool**: fixed slots, each
holding one **tier** of one chunk — 256 ranks, 4 KiB of core records, plus the matching
harmonics in a sibling pool. A chunk is resident as a prefix of tiers, and because the bake
orders every chunk by importance, a chunk's first tier is what the budget draws of it in most
views: the heads of a whole 20 M-splat asset (76 MiB) fit a 256 MiB pool with room for the
near chunks' deeper tiers. The pool takes what a quarter of `MemoryBudgetManager.geometryBudget`
leaves after the pools already allocated, capped at the asset and at 256 MiB (1 GiB on the
Mac); it is fixed for the life of the entity and carried by the entity's `MemoryBudgetManager`
entry in place of the file's bytes, so streaming eviction weighs and frees the pool.

Every frame the chunk cull writes each chunk's seen screen area into the frame's demand
table; the pager (`GaussianPageManager`) reads it back three frames later, wants for each
demanded chunk the ranks the budget would grant it with a 25 % headroom (the density cap
rule, or — when the frame fits — the cap the budget solve would settle at with every demanded
chunk resident whole, solved on the CPU over a histogram of the demanded set, so an empty
pool never asks for the whole asset and a fresh view fills to the state a whole-resident
entity settles at), and reads the missing tiers from disk — near and large chunks first,
empty chunks before top-ups, the chunk the camera stands in first of all — straight into
free pool slots on a background queue. The tick's work is proportional to what changed, not
to the chunk count: the demand words are diffed against the last ingest, a chunk's want is
re-evaluated only when its own inputs (area, residency, landed levels) or the frame-wide ones
(the cap, the fill) moved, and the candidate, resident and fade sets are kept as chunks
change state; a still camera over a 10 k-chunk asset costs the tick a few block compares. A chunk with nothing resident is not listed and asks nothing of the
budget; a partially resident one is listed with its resident ranks, so the budget sees only
what can be drawn (a file cooked with per-chunk coarse levels changes both — see the next
section). Arriving tiers fade in over 16 frames. A tier is given up when its chunk
has not been seen for 30 ticks, when it sits above what the frame wants for 45 ticks, or when
a candidate is worth 1.5× more and the tier is past its 30-tick minimum residency; an
evicted tier is not asked for again for 15 ticks, so glancing away and back reloads nothing
and equal chunks at the pool's boundary never ping-pong. A chunk is CRC-checked the moment
it becomes fully resident; a read that fails backs off (8, 32, 128 ticks) and faults the
chunk on the third failure; a file that changes under the entity faults the asset — its
resident pages keep drawing — until a periodic reopen (every 300 ticks) finds a file with the
same index again and adopts its identity. Cook assets meant for
Apple Vision Pro at spherical-harmonics degree 2 or below: at degree 3 a slot is 15 KiB and
a 256 MiB pool holds only most of a 20 M asset's heads.

Read the state through `gaussianPagingStats(entityId:)` (`GaussianPagingStats`: the pool,
the resident slots and chunks, the reads pending and in flight, what the last tick issued,
mapped and evicted, the candidates that found no slot, the faulted and corrupt chunks, the
pager's state) or the `[Gaussian][FrustumCull]` profile line (`paged=… pool=… pages=…
pending=… issued=… committed=… evicted=… saturated=… faults=…`).

The paging is exercised from the file itself by `GaussianPagingTest.testLargeSyntheticAssetPagesWithinItsPool`
(`Tests/UntoldEngineRenderTests`): a 300 k-splat synthetic slab against a 1 MiB pool over 120
real frames. `UNTOLD_PERF_GAUSSIAN_PAGING=1` adds 4 M- and 20 M-splat runs against a 64 MiB
residency budget — baked the first time from a synthetic slab built in memory and written
straight through the writer (no source file, so nothing is streamed: the 20 M bake holds the
1.6 GB array beside its 1.1 GB store and peaks at 3.3 GB, in about 80 s under `swift test`'s
debug build and 1.3 s in a release one), cached in the temporary directory — and `UNTOLD_PERF_GAUSSIAN_PAGING_SPLAT_COUNT=<n>` keeps
only the sizes up to `n` (`4000000` for the 4 M run alone). Each run checks the pool is what
the policy sizes it (the budget, or the whole asset when that is smaller: a 4 M asset without
harmonics is 64,000,000 B and fits every tier, so nothing saturates and nothing is evicted; a
20 M asset saturates the pool on purpose) and prints the resident bytes, the frame at which
80 % of the slots had been committed and the worst frame time, with the run's wall time beside
the time spent in `renderer.draw` (the rest is each frame's GPU wait, which grows with the
resident set — a faster fill makes the wall time longer, not shorter).

### Per-chunk coarse levels

A `.untoldgs` cooked with per-chunk coarse levels (the default for assets of at least 64
chunks: `--splat-coarse-levels auto`, see [untoldgsFormat.md](../Architecture/untoldgsFormat.md)
and the CLI doc) carries, beside every chunk's fine records, one or two importance-sorted
**merged** levels of it — level 1 about n/8 splats, level 2 about n/64 at the default ratios
`3, 6` — in a section a reader that predates it never sees. The runtime draws them where a
prefix of fine splats would leave holes:

- A **far chunk** — one whose fine density `n / A` (splats per unit of screen area) lies far
  above the frame's density cap — draws a coarse level instead of a thin prefix of its fine
  ranks: level 1 from two octaves (four half-octave tiers) under its own density, level 2 from
  five. The level is chosen in the quota pass from the same cap the quotas apply, with integer
  tier arithmetic, and the density solve charges every candidate cap with the same rule
  (`R(d)`), so the cap and the levels share one fixed point and nothing oscillates. Moving to a
  finer level needs one more tier than moving coarser (hysteresis), and a chunk draws the level
  it has: a level not resident steps to the next coarser one that is, else to the next finer.
- A fitting frame (cap `+inf`) still draws the far field coarse when it would exceed
  `GaussianRuntimeLimits.maxSplatsPerPixel` (default 1) fine splats per pixel of the viewport:
  the **density floor** lowers the cap the level rule sees, never the quota.
- A **paged chunk with nothing resident** is listed for its finest landed level and draws the
  level the rule picks with fine unavailable — the next coarser landed one, so level 1 for a
  chunk that would draw fine once its level-1 piece has landed, level 2 while only that has (or
  for a chunk far enough to want it) — from the frame after it is first listed: the first listed
  frame detects the switch from the initial fine state and draws nothing, the next commits it,
  and the level fades in over `fadeFrames` frames (a level-1 piece landing later switches with a
  fade). The pager streams the section through its read queue coarsest level first, in pieces
  of half the in-flight cap issued ahead of the tick's tier reads — as many as the cap holds
  while the coarsest level lands, one a tick after that; a piece whose read fails is retried on
  the tier reads' schedule, per piece, and the levels fault when one piece exhausts it — and the
  chunk's fine head fades in on top when it arrives, the coarse level fading out on the same
  clock. A chunk the rule draws coarse wants **no** fine rank, so its tiers leave the pool as
  surplus and the pool holds fine ranks only for chunks that draw them.
- Every switch cross-fades over `GaussianPagingPolicy.fadeFrames` (16) frames with the
  coverage-preserving weights `1 − (1 − α)^w` in and `1 − (1 − α)^(1 − w)` out, so the
  transmittance of a surface both levels cover stays `1 − α` throughout; the outgoing window is
  listed as a second visible-chunk entry, reserved in the budget one frame ahead
  (`transitionSplats`), and its fine tiers are no eviction victim while it fades.
- Coarse splats count against the working set like fine ones; charging far chunks their level
  count instead of a fine prefix lowers the request, so the solved cap rises and the freed
  budget flows to the near field.

The coarse records live **outside the page pool**, in a per-entity buffer charged to the
entity's `MemoryBudgetManager` entry beside the pool, and stay resident for the life of the
entity. Together they are given `GaussianPagingPolicy.coarseBudgetFraction` (20 %) of the
residency budget — one share for every levelled entity, claimed on
`GaussianPagePoolRegistry.coarseBytes` under the registry's lock and released with the entity's
table, so a later entity fits its levels against what the earlier ones hold: both levels when
they fit what is left of it, else the coarsest level alone (the runtime then switches fine ↔
level 2 directly, a larger but still faded step), else none — logged once per load, the entity
then draws its fine records only as before the levels existed. At the default 300 MiB
geometry budget (75 MiB residency budget) a 20 M-splat asset at ratios `3, 6` (45 MB of coarse
records) keeps its level 2 alone (5 MB); ratios `4, 7` halve the bytes, and a geometry budget of
900 MiB keeps both. A coarse payload that fails its CRC — at load for a whole-resident entity
(the load fails, as for a fine chunk), as its piece lands for a paged one — faults the entity's
levels: the frame binds `hasCoarse = 0` and draws fine only, reported once.

Residuals: the frame a down-switch is detected cuts the fine prefix to the new level's count one
frame before the fade begins (band-softened, at a few pixels of screen); a coarse level carries
the DC colour only, beside fine ranks with harmonics during a near fade; the chunk's cull box is
the fine box, so a merged splat's tail beyond it at the very edge of the frustum can be culled
with the chunk for the frames of a fade (the 0.25 guard band covers realistic clusters); the
level-1 pieces of a paged entity land over its first ≈ 20 ticks on mobile, during which chunks
that would draw level 1 draw level 2 and then switch with a fade; and the pager's eviction
shield for a switching chunk (`.levelFade`) follows its CPU mirror of the rule, which reads the
cap one to three frames after the GPU used it, so under pool contention a chunk that just went
coarse can lose its fine tail in the first frames of the fade — the outgoing fine window then
draws nothing and the chunk ramps up from its coarse level alone, recovering within the fade.

Cook guidance: leave `--splat-coarse-levels auto` (`UntoldGSCookOptions.coarseLevels =
.automatic`) — every tier of at least 64 chunks gets two levels at ratios `3, 6`, a smaller
asset bakes byte-identically to a file without the section, and each `_lodN` tier of a
progressive bake resolves on its own; `0` / `.off` never bakes them, `1`, `2` /
`.levels(options)` always (`UntoldGSCoarseLevelOptions`: `levelCount`, `ratioLog2`, the
16-splat `minimumChunkSplats` under which a chunk has no level, `refinementPasses`,
`colourWeightScale`). Ratios `4, 7` halve the section (n/16 and n/128) at a coarser far level;
a single level at ratio `6` bakes the coarsest level alone. A level that does not fit its
share of the residency budget is neither allocated nor read — a 20 M asset at `3, 6` on the
default budget streams its level 2 (5 MB) and leaves level 1 in the file.

Read the state through `gaussianPagingStats(entityId:)` (`coarseLevels`, `coarseBytes`,
`coarseBytesLanded`, `coarseChunkLevelsAvailable`, `coarseReadsIssued`, `coarseFaulted`) or the
`[Gaussian][Preprocess]` profile line, which gains `coarseChunks=… coarseSplats=… transition=…`
(the entries drawn coarse, their quota sum and the outgoing windows reserved on the last
read-back frame) and, once an entity has levels, `coarseEntities=… coarseBytes=…
coarseLanded=… coarseLevelsAvailable=… coarseReads=… coarseFaulted=…` summed over the entities.

The levels are exercised by `GaussianChunkLevelTest` (`Tests/UntoldEngineRenderTests`: the
fine-only and coarse-only twins, the CPU mirror of every level tag over a pull-back, the
budget bound through transitions, the coverage fade, coarse-first paging, a fine head arriving
over a coarse level, determinism, stereo, the fit check, a corrupt payload, the analytic
cluster fixture), by `GaussianPagingTest.testLargeSyntheticAssetWithLevelsStopsWantingFineTiersFromAfar`
from the file itself, by the CPU-only `GaussianChunkCullMathTests` and `UntoldGSCoarsenerTests`
(`Tests/UntoldEngineTests`), and by the opt-in rows of `GaussianChunkCullBenchmark`
(`UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1`: the levels on and off at a quarter budget, and paged at a
quarter pool).

### The budget

The shared working set holds at most `GaussianRuntimeLimits.workingSetSplats` records:
1,000,000 on Apple Vision Pro, iPhone, iPad and Apple TV, 6,000,000 on the Mac, clamped so its
3 × 72 bytes per record stay within a quarter of `MemoryBudgetManager.geometryBudget`, never
more than the resident splat total and never less than the whole-buffer (`.ply`) entities'
resident total. `GaussianRuntimeLimits.workingSetSplatsOverride` replaces the figure for an
application that knows its scene (or a test); `nil` restores the default.

When the chunks in view hold more splats than the budget leaves after the whole-buffer
entities' visible counts are reserved, every visible chunk is granted a quota **weighted by
its screen area**: the frame picks one density cap `d` — splats per unit of screen area, a
chunk filling the view having area 1 — and grants each chunk `min(count, floor(d × area))`,
with `d` solved on the GPU so that the quotas stay within the room the reservation leaves
(`0.98 × budget − reserved`). A chunk sparser than the cap — near, large on screen — keeps all
of its splats; a denser one — far, a few pixels holding thousands of splats — is cut to the
cap, where the cut is least visible. The fused pass reads only the first `quota` records of the
chunk, and the bake orders each chunk by importance (opacity × size), so a quota is a
continuous level of detail: the splats that matter least go first. For example, with a budget
of 100 and two visible chunks of 80 splats, a near one covering half the view and a far one
covering half a percent of it, the cap lands at 3,600 splats per view: the near chunk keeps
all 80 and the far one 18 — where the same fraction for every chunk would have kept 49 and 49.
Two things keep the cut from popping as the camera moves:

- **Hysteresis.** A fall of the cap — a smaller budget, a turn that brings a dense region into
  view — is taken at once: the set is already at its capacity, and a cap lagging above its
  target would grant more than the set holds and drop splats by arrival order. A rise — a
  larger budget, a turn to a sparser view — climbs by at most max(10 % of the cap, 5 % of its
  target) per frame, so the chunks fade back in over several frames (at most about twenty)
  instead of flipping the visible set. A frame that fits is whole at once and stays whole even
  when a denser chunk enters; a truncated frame that comes to fit climbs toward the density
  below which all but the densest 5 % of the requested splats are whole and is whole from
  there — the densest chunks are the smallest on screen (a sliver of a chunk just entering the
  guard band can be denser than every other chunk by orders of magnitude), so they do not set
  the step, and become whole with the cap. A chunked entity that got nothing (a `.ply` that
  filled the set) fades in the same way when room appears. A frame with no splat entity (a
  scene unload) resets the climb, so the next scene starts at its own target.
- **The opacity band.** In a truncated chunk the last fifth of the kept ranks fade linearly
  toward zero opacity, so the splats a shrinking quota drops next are already nearly invisible.

A `.ply` is not budgeted: its whole-buffer cull appends everything it keeps into the same set,
the set is never smaller than its resident total, and its visible count is reserved before the
`.untoldgs` entities are fitted, so neither loses a splat by arrival order (a `.ply` that fills
the budget on its own leaves the `.untoldgs` entities nothing). Read the state through
`GaussianSharedWorkingSet.shared` (`capacity`, `lastVisibleCount`, `lastOverflowCount`,
`lastBudgetState` — the request, the reservation, the grant, the density cap `densityCap`
(`+inf` when every chunk is whole) and the uniform rule's scale and its target of the last
completed frame; `lastDensityHistogram` — the 64 density tiers the cap was solved from, the
target and full densities, the grant and the visible chunk count) or the
`[Gaussian][Preprocess]` profile line (`budget=… requested=… reserved=… quota=… scale=…
targetScale=… density=… targetDensity=… visibleChunks=… fill=…`, `LogCategory.gaussian`;
`fill` is the quota sum over the grant).

### Cost and switches

| Resident per splat | `.untoldgs` (chunked) | `.ply` / CPU-decoded (whole buffer) |
|---|---|---|
| Splat record | 16 B packed; above the paging threshold a pool of 256-rank tiers (4 KiB + SH per slot), not the file | 48 B encoded |
| Visible index, per frame in flight | — (visible-chunk lists: 16 B per chunk per slot) | 4 B |
| Spherical harmonics | 0 / 9 / 24 / 45 B (degree 0–3) | same |
| Chunk table | 48 B per chunk | — |
| Coarse levels (when cooked and fitting) | 16 B per coarse record (≈ 14 % of the core bytes at ratios `3, 6`, 1.6 % for level 2 alone), outside the pool, plus 48 B per level per chunk and 8 B of level state per chunk; visible-chunk lists 32 B per chunk per slot | — |

The shared working set costs 3 × 72 B × budget once, whatever is loaded (216 MB for a million
splats), plus about 9 KB of fixed state (the budget state and the 2064-byte density histogram
with their per-slot readbacks), carried by its own `MemoryBudgetManager` entry
(`setGaussianWorkingSetBytes`), not by the entities. A million-splat `.untoldgs` at degree 3
therefore keeps about 61 MB resident (16 B + 45 B per splat, plus about 70 KB of chunk table
and visible-chunk lists at 1024 splats per chunk) where the same asset used to cost about
320 MB. A 20 M-splat asset without harmonics (320 MB of records) pages on Apple Vision Pro:
a 256 MiB pool of 65,536 tiers, plus about 4 MB of chunk table and per-slot tables, is what
it keeps resident, and every head of the asset fits it.

- `GaussianDebugOptions.shared.disableChunkCull` keeps every chunk, so the fused pass walks
  the whole asset as the whole-buffer cull does for a `.ply` — for bisecting, and for A/B timing
  of the chunk stage. `disableHZBOcclusionCull` turns the depth-pyramid part off for both stages.
- `GaussianDebugOptions.shared.disableWorkingSetBudget` sizes the set to the resident total and
  grants every chunk its whole count — the pre-budget behaviour, for an A/B of what the budget
  cuts and what it saves.
- `GaussianDebugOptions.shared.disableScreenWeightedQuotas` grants every visible chunk the same
  fraction of its splats, `floor(scale × count)` with `scale = (0.98 × budget − reserved) /
  requested`, instead of weighting the quotas by screen area — the pre-weighting rule, byte
  for byte, for an A/B of what the weighting moves. (With `disableChunkCull` and this off, the
  chunks no view keeps carry the minimum screen area and are cut first on a truncated frame.)
- `GaussianDebugOptions.shared.disablePaging` loads every `.untoldgs` whole-resident whatever
  its size (at the next load); `freezePaging` holds every paged entity's resident set — no
  read, no eviction — so the image is a function of the camera alone, for bisecting;
  `disablePageFade` shows an arriving tier at once; `residencyDebugTint` colours each splat of
  a paged entity by its chunk's resident fraction (green whole, red head-only). The knobs live
  on `GaussianPagingPolicy`: `pagingThresholdBytesOverride` (0 pages every chunked asset — the
  editor's "simulate paging"), `residencyBudgetBytesOverride`, the hold-off, surplus,
  minimum-residency and reload-cooldown ticks, the per-tick read and byte caps, the commit
  cap and budget (`maxCommitsPerTick`, 4096 tiers, is the ceiling; `commitBudget`, 0.5 ms,
  is how long a tick keeps mapping landed tiers past the first — a fill is bounded by the
  clock, thousands of tiers a frame while the pool has room and the reads keep up; the tiers
  a tick maps therefore depend on the machine and are not reproducible run to run, and
  `commitBudget = .infinity` restores the count-only bound — the test fixtures and the
  benchmarks pin it so; `GaussianPagingStats.deferredTiers` counts the landed tiers a tick
  left for the next one),
  `fadeFrames`, `verifyPagedChunkCRC`. On a paged entity `disableChunkCull` forces only the
  resident ranks (a chunk no view keeps is never demanded, so its ranks never load),
  `disableWorkingSetBudget` wants every rank of every demanded chunk and sizes the set to the
  pool (a debug A/B, not a shipping mode: 65,536 tiers of 256 ranks is a 16.7 M-splat set),
  `disableScreenWeightedQuotas` wants the uniform rule's ranks at the fill scale over the
  demanded counts (not at the read-back cap, which scales the resident ranks and would have
  the wants chase residency) while the demand keeps the real area, and
  `disableHZBOcclusionCull` demands and loads occluded chunks.
- `GaussianDebugOptions.shared.gaussianLevelMode` chooses how an entity with per-chunk coarse
  levels draws: `.auto` (the level rule), `.fineOnly` (the fine records only — byte for byte the
  frame of a file without a coarse section, the A/B of what the levels change) or `.coarseOnly`
  (every chunk at its coarsest available level, the twin comparison); `disableLevelCrossFade`
  switches levels at once instead of over 16 frames; `levelDebugTint` colours every splat by its
  chunk's level (white fine, yellow level 1, red level 2, over the residency tint).
  `GaussianRuntimeLimits.maxSplatsPerPixelOverride` moves the density floor (0 or a non-finite
  value switches it off; nil restores 1), `GaussianPagingPolicy.coarseBudgetFractionOverride` the
  share of the residency budget the coarse records may take. Under `disableScreenWeightedQuotas`
  the levels are off (every chunk fine, no tag bits); under `disableWorkingSetBudget` the frame
  fits, so only the density floor can still pick a coarse level, and the pager wants every rank
  of every demanded chunk whatever its level.
- A `.ply` asset, or a `.untoldgs` decoded on the CPU because the decode kernel is unavailable
  (or expanded once at load because the per-chunk kernels are), has no chunk table and keeps
  the per-splat cull over its whole encoded buffer.

## Per-entity splat limit

A `.untoldgs` splat keeps 16 bytes plus its spherical harmonics resident (see the table above)
up to the paging threshold, and above it only what fits the page pool — so the runtime caps
one entity at `GaussianRuntimeLimits.maxSplatsPerEntity`, 20,000,000 splats on Apple Vision
Pro, iPhone, iPad and Apple TV (a 256 MiB pool holds every head of such an asset without
harmonics; with degree-3 harmonics a slot is 15 KiB and the pool holds most of the heads, so
cook Apple Vision Pro assets at degree 2 or below), 40,000,000 on the Mac (where a 20 M asset
without harmonics stays whole-resident below the 512 MiB threshold and pages with harmonics). The whole-buffer path — a `.ply`, or a `.untoldgs` decoded
whole because the per-chunk kernels are unavailable — keeps about 60 bytes per splat (the
48-byte record and three 4-byte visible indices) plus harmonics, so it keeps the lower cap,
`GaussianRuntimeLimits.maxWholeBufferSplatsPerEntity`: 5,242,880 splats on Apple Vision Pro,
iPhone, iPad and Apple TV (315 MB, 550 MB with degree-3 harmonics), 16,777,216 on the Mac. An
asset above its path's cap fails to load with an "exceeds maximum" error. Cook large captures
with a splat budget (`UntoldGSCookOptions.maxSplatCount`, `untoldengine export
--splat-max-count`) that fits every platform the asset ships on, or split the scene into
streamed tiles. What the frame can draw is bounded separately by the working-set budget above.

### Cooking from code

An editor or a tool cooks a capture with
`bakeGaussianSplatProgressiveTiers(plyURL:outputBaseURL:levelCount:cookOptions:control:)`
(see [untoldgsFormat.md](../Architecture/untoldgsFormat.md#cooking-a-capture)). The source is
streamed in windows and cooked in parallel into one compact store, so a 10 M-splat degree-3
capture cooks in about two seconds with about 1.4 GB of memory in a release build (1.37 GB with
a 5 M-splat budget, which compacts the store in place; about seven seconds for three tiers; and in
about a minute in a debug build, where it used to take seven), and every tier is written to a
temporary file, the set renamed into place once the last tier is complete. `UntoldGSCookControl` takes a progress callback —
`UntoldGSCookProgress` with the phase (`read`, `cook`, `chunk`, `coarsen`, `write`), the
fraction within it, the overall fraction and the tier — and an `isCancelled` closure polled
between windows, through the progressive ranking and between chunk batches (`Task.isCancelled`
is honoured too); cancelling throws `UntoldGSCookError.cancelled` and leaves no file of the
bake's, not even a tier already finished, while the tiers of a previous bake stay as they were. The
result's `centerBoundsMin`/`Max` are the bounds of the cooked splats; for the bounds of a source
before it is cooked, `PLYReader.readGaussianCenterBounds(from:)` makes one streamed pass with
nothing resident, and `PLYReader.readGaussianSplatCount(from:)` reads the header alone.

## A splat standing in for a mesh: shells, fades and scene links

A captured object looks best as a splat up close and costs least as a mesh far away. The engine
gives an application the pieces to swap between the two on one entity without popping; the
policy that drives them (when to load, from what distance, how fast to fade) belongs to an
application-side system built on these pieces (see the proposal's §4.5).

- **A splat on a mesh entity.** `setEntityGaussianAsync(entityId:url:opacityScale:)` attaches a
  `.untoldgs` (or `.ply`) to an entity that already draws a mesh. The load is two phases a
  caller can also drive itself: `loadGaussianSplatPayload(url:)` reads and encodes off the main
  thread, `setEntityGaussian(entityId:payload:opacityScale:)` attaches the result under the
  world-mutation gate, so a system can check under its own gate whether the load is still
  wanted before applying it. The mesh stays the primary representation: the splat's bytes ride
  beside the mesh's `MemoryBudgetManager` entry (`auxiliaryMeshBytes`, so mesh streaming in and
  out leaves them intact) and the entity keeps the mesh's bounding box, with the splat's own box
  on `GaussianComponent.localBoundingBox`. `removeEntityGaussian` drops the splat (and a
  progressive splat's tiers) and only its share of the ledger. Starting with `opacityScale: 0`
  keeps it resident but hidden.
- **`GaussianComponent.opacityScale`** weighs every splat's opacity: 0 hides the entity and skips
  its cull, values between cross-fade.
- **`MeshFadeComponent`** dithers the mesh's colour with the LOD screen-door: `.fadeOut` discards
  more pixels as `progress` rises, `.fadeIn` keeps more. Applied after the LOD and tile fades.
- **`MeshOccluderComponent`** draws the mesh a second time depth-only, pushed `shrinkMeters` along
  its normals away from the camera (the `meshOccluderShell` render pass, after the opaque colour
  and before the HZB copy and the splat pass). The splat then passes the depth test on and just
  outside the surface, and is hidden behind the object's far side. With `drawsColor` off the
  mesh contributes nothing but that depth: shadows, physics and picking keep using it because
  `RenderComponent.isVisible` is untouched. Soft objects differ from their mesh by centimetres,
  so raise the margin until the front of the capture stops clipping. Blend-mode submeshes are
  left out of the shell and stop drawing with the colour.
- **`GaussianAssetLinkComponent`** carries a `.untold` scene's `gaussianAsset` record
  (`UntoldGaussianAssetRecordV1`: payload path resolved next to the scene file, flags such as
  `meshTwin`, occluder margin, exposure offset, swap distance, alignment) onto the entity as
  data. `setEntityMesh`/`setEntityMeshAsync` attach it; nothing is loaded.
- A mesh carrying a `MeshOccluderComponent` or `MeshFadeComponent` is excluded from static
  batching when the batcher next evaluates it, and re-admitted once they are gone. The system
  that adds or removes them tells the batcher with
  `BatchingSystem.shared.notifyEntityMaterialChanged(entityId:)`; the group is rebuilt over a
  few frames, during which the batch still draws the mesh.
- `GaussianDebugOptions.shared.disableOccluderShell` turns the shells off for bisecting.

**Writing the link.** No whole-file `.untold` writer exists in Swift, and none is needed to
author a link after the export: `UntoldAssetPatcher` (Sources/UntoldEngine/AssetFormat) rewrites
just the gaussianAsset table. `settingGaussianAsset(_:onEntity:in:)` takes the file's bytes and a
`GaussianAssetLink` (payload path relative to the `.untold` file's directory, flags, LOD table,
occluder shrink, exposure offset, swap distance, alignment) and returns the patched bytes with every other
chunk copied unchanged, the path appended to the string table (or an identical string reused),
offsets re-laid out on 16-byte alignment and the content hash recomputed;
`removingGaussianAsset(onEntity:in:)` drops a record (and the chunk when empty);
`gaussianAssets(in:)` lists them. The result is read back through `UntoldReader` before it is
returned. The same operation from the shell is `untoldengine gaussian-link --untold chair.untold
--entity 0 --payload chair.untoldgs [--swap-distance m] [--occluder-shrink m] [--exposure-offset ev]
--in-place | --output file`, with `--remove` and `--list`; the CLI reads the `.untoldgs` header to
fill one LOD level with the payload's splat count.

A typical swap: load the payload with `opacityScale: 0` when the camera is near; add a
`MeshOccluderComponent`; add a `MeshFadeComponent` with `direction = .fadeOut` and raise its
`progress` and the splat's `opacityScale` together to 1 over 250 ms; then set `drawsColor =
false` and remove the fade. Reverse the steps when the camera leaves.

### Aligning a twin

A capture never shares its mesh's frame: the scanner picks the origin, the up axis and the
scale. Registering the two used to mean baking a transform at cook time
(`UntoldGSCookOptions.transform`, recorded in the `.untoldgs` header's `splatToMesh`), and that
is still possible — but an alignment can also be edited after the cook and saved with the
link:

- **`GaussianComponent.splatToEntity`** (`simd_float4x4`, identity by default) is where the
  splat sits in its entity's local space. The splat is drawn with `entityWorld × splatToEntity`
  by the cull, the preprocess, the chunk cull and the draw alike, so setting it — through
  `setGaussianSplatToEntity(entityId:_:)` — moves, turns or scales the splat exactly as moving
  the entity would, while the mesh the twin stands in for stays put. It belongs to the entity,
  not the payload: tier swaps, reloads of the same entity and a streaming eviction and reload
  keep it (`StreamingComponent` holds it while the splat is out). A splat-only entity's
  bounding box is the splat's box carried through it, kept in step by the setter as well as by
  every load; a twin entity keeps the mesh's box, and a progressive entity whose box the caller
  supplied keeps that one.
- **`GaussianSplatAlignment`** (`translation`, `yawDegrees`, `scale`; `matrix` = `T · R_y · S`,
  yaw about +Y, right-handed, uniform scale) is the authored form: the `gaussianAsset` record
  stores it in its last five words under `UntoldGaussianAssetFlags.alignment`, the loader hands
  it over as `GaussianAssetLinkComponent.alignment` (`RuntimeGaussianAssetLink.alignment`), and
  whoever loads the payload applies `alignment.matrix` through `setGaussianSplatToEntity` — a
  twin policy such as `GaussianTwinOptions.alignment` in UntoldGaussianTwins does this every
  tick (an unchanged matrix costs nothing), so an editor can change the value live. Files written before the flag existed read as no alignment.
- The `.untoldgs` header's `splatToMesh` stays the record of the cook transform; the
  alignment composes on top of whatever the cook baked. A full three-axis rotation is left to
  a later extension: captures are up-axis corrected at cook time.

`UntoldAssetPatcher.GaussianAssetLink.alignment` writes it (the flag follows the optional; a
non-finite value or a scale of zero is rejected), and `untoldengine gaussian-link` takes
`--align-translate x,y,z`, `--align-yaw-degrees`, `--align-scale` (each defaulting to what the
entity's link already stores) and `--clear-alignment`; `--list` prints it.

### Calibrating the capture

Splats are unlit emissive surfaces composited in linear light before the look and output
transforms, so a splat is tone-mapped once, like an emissive mesh next to it. The preprocess
applies one linear gain per entity, `GaussianComponent.colorGain`: the capture white balance
from the `.untoldgs` header, times `2^(exposureOffsetEV − captureExposureEV)`. A capture
recorded at +1 EV therefore comes back to the scene's neutral exposure by itself, and the
per-asset offset (the editor slider, `exposureOffsetEV` in the scene record) pushes it either
way. With `useRealWorldTint` the colour is also multiplied by the XR lighting estimate's tint
whenever `RuntimeEnvironmentLightingStore` is in `.realWorldEstimate` mode with a valid
estimate, so a capture made under neutral light takes on the colour of the room.

## Progressive Gaussian Splats

Progressive Gaussian loading is available without a tile-streamed scene. Use it when you
want a Gaussian to appear quickly at a coarse tier, then refine toward full resolution as
the camera gets closer.

Progressive assets use `.untoldgs` tier files:

```text
<baseFilename>_lod0.untoldgs
<baseFilename>_lod1.untoldgs
<baseFilename>_lod2.untoldgs
...
```

`lod0` is the finest/full-resolution tier. Higher LOD numbers are progressively coarser.
The engine loads the coarsest tier first, then `GaussianLODSystem` requests finer tiers
based on camera distance. A tier above the paging threshold pages with its own pool; before
the LOD system switches to it, the tier **warms**: the frame culls its demand beside the
current tier's and its pager fills it, and the switch waits until 80 % of the ranks the frame
wants are resident (or 90 ticks have passed) so a paged tier never comes in empty (see [Overdraw-aware LOD selection](#overdraw-aware-lod-selection)
below for a second, distance-independent signal that can also hold an entity on a coarser
tier). A paged tier is released the moment the selection leaves it — its pager shuts down,
its pool leaves the page-pool ledger at once and its buffers go with the in-flight frames —
whether the switch to another tier commits or the selection retreats from a tier that was
still warming (the hysteresis, the overdraw clamp, a camera that stopped short). So an
entity holds at most two pools, the current tier's and the warming tier's, and one again as
soon as the warming tier switches in or is abandoned, however often the camera crosses its
thresholds; when the selection returns to a released tier, the engine loads it again and it
warms into a fresh pool before the switch, as the first time. A whole-resident tier (below
the threshold) stays cached after the switch instead, so the switch back is instant and
reads nothing. The whole-file tiers and the [per-chunk coarse levels](#per-chunk-coarse-levels) are
different mechanisms that compose: under `--splat-coarse-levels auto` every tier file of at
least 64 chunks carries its own coarse section, so within the tier the LOD system holds
resident, far chunks draw merged levels and near chunks their fine ranks.

Generate tiers from a `.ply` source with the exporter:

```bash
untoldengine export --input "chair.ply" --output "chair.untoldgs" --lod-levels 4
```

The exporter prints a diagnostic `meanSquaredSplatExtent` per tier and a `boundingBoxHalfExtent`
line computed from the full source asset:

```text
✅ Exported: chair_lod0.untoldgs (meanSquaredSplatExtent: 0.0021)
✅ Exported: chair_lod1.untoldgs (meanSquaredSplatExtent: 0.0087)
✅ Exported: chair_lod2.untoldgs (meanSquaredSplatExtent: 0.0341)
✅ Exported: chair_lod3.untoldgs (meanSquaredSplatExtent: 0.1250)
ℹ️ boundingBoxHalfExtent: (0.42, 0.55, 0.38)
```

Both values are baked directly into each tier's `.untoldgs` file (its header carries the
asset-level bounding box alongside `meanSquaredSplatExtent`) and read back automatically when
the engine loads it — nothing here needs to be copied into your code. The console lines are
diagnostics only (e.g. to sanity-check density/size across source captures).

Then register the entity with the source-based API:

```swift
let chair = createEntity()
translateTo(entityId: chair, position: simd_float3(0.0, 0.0, -3.0))

setEntityGaussian(
    entityId: chair,
    source: .progressive(
        baseFilename: "chair",
        levelCount: 4,
        maxDistances: [5.0, 15.0, 25.0, .greatestFiniteMagnitude]
    )
)
```

`maxDistances` must have one entry per LOD. Each value is the farthest camera distance at
which that LOD is allowed to be selected:

- `lod0` can be used inside `5.0` units.
- `lod1` can be used from `5.0` to `15.0` units.
- `lod2` can be used from `15.0` to `25.0` units.
- `lod3` is used beyond `25.0` units, or while finer tiers are still loading.

The system always falls back to the best tier already resident in memory, so the entity can
become visible quickly with the coarsest tier and refine toward `lod0`.

There's no bounding-box parameter to pass here: the engine reads the box baked into the
coarsest tier's header synchronously at registration time, so the entity has a correct,
exact bounding box from frame one.

### Overdraw-aware LOD selection

Distance alone is a proxy for how expensive a Gaussian entity is to render — two assets at
the same distance can have very different overdraw depending on splat density. On top of the
distance/`maxDistances` selection above, `GaussianLODSystem` also estimates the entity's mean
overdraw (blended fragments per pixel across its screen footprint) each LOD update, using
`meanSquaredSplatExtent` values baked into each `.untoldgs` tier by the exporter. If a
distance-selected tier would exceed `LODConfig.shared.gaussianOverdrawBudget` (default `12.0`,
see `LODConfig.swift`), the system walks to a coarser tier instead — it never picks a finer
tier than distance already allows.

This is fully automatic for any asset baked with the current exporter — there is nothing to
wire up. It only has an effect on tiers that carry a real `meanSquaredSplatExtent`; `.untoldgs`
files baked before this feature existed fall back to pure distance-based selection.

Tune `LODConfig.shared.gaussianOverdrawBudget` on-device by watching GPU frame time while
varying it — the default is a starting guess, not a derived constant.

### Debugging progressive LOD

Gaussian progressive LODs participate in the same LOD debug visualization used by mesh
LODs:

```swift
setSpatialDebug(.lodLevels(true))
```

When enabled, the renderer tints Gaussian splats by their currently selected progressive
LOD. This is useful for confirming that the engine is switching tiers as the camera moves,
including tiers the overdraw budget forces early.

---

## Streaming Gaussian Splats in Large Scenes

`setEntityGaussian` loads a splat immediately and keeps it resident for the lifetime of the
entity — fine for a small number of always-visible splats, but not what you want for props
scattered across a large tile-streamed scene (chairs, tables, decor inside a streamed
building). Loading every one of those up front defeats the point of streaming, and the
engine has no way to unload them again on its own.

For that case, register the entity with `GeometryStreamingSystem` instead, via
`setEntityGaussianStreaming`, which loads and unloads it automatically based on camera
distance — the same way it already handles the surrounding streamed tile geometry. It can
stream either one whole Gaussian file or a progressive `.untoldgs` tier set. A splat above the
paging threshold registers its page pool and tables with `MemoryBudgetManager`, not the file,
and the pool goes with the entity when it is unloaded; under OS memory pressure every pool
takes a soft target (half its slots on a warning, a quarter on critical) for a while and
stops reading above it (see [geometryStreamingSystem.md](../Architecture/geometryStreamingSystem.md)).

### API overview

```swift
setEntityGaussianStreaming(
    entityId: EntityID,
    source: GaussianSource,
    options: GaussianStreamingOptions
)
```

`GaussianSource` selects what kind of Gaussian asset the streaming system should load:

```swift
.single(filename: String, withExtension: String)

.progressive(
    baseFilename: String,
    withExtension: String = "untoldgs",
    levelCount: Int,
    maxDistances: [Float]
)
```

`GaussianStreamingOptions` controls the entity's streaming behavior:

```swift
GaussianStreamingOptions(
    streamingRadius: Float = 100.0,
    unloadRadius: Float = 150.0,
    boundingBoxHalfExtent: simd_float3? = nil,
    priority: Int = 0
)
```

### Prerequisites

This only makes sense in a scene that is already using tile-based streaming — i.e. one
loaded with `setEntityStreamScene` (see [Using the Geometry Streaming System](UsingGeometryStreamingSystem.md)).
`setEntityGaussianStreaming` attaches the splat to whichever tile stub's bounds contain
the entity's position, so it needs those tile stubs to already exist. Call it **after**
`setEntityStreamScene`'s completion handler has fired — tile stubs are guaranteed to be
registered by then.

### Step 1: Create and position the entity

Position and orient the entity *before* registering it for streaming — the position at the
time you call `setEntityGaussianStreaming` is what determines which tile it gets attached
to.

```swift
let streamSplat = createEntity()
translateTo(entityId: streamSplat, position: simd_float3(2.0, 0.0, -4.0))
rotateTo(entityId: streamSplat, angle: 180.0, axis: simd_float3(1.0, 0.0, 0.0))
```

### Step 2: Register it for streaming

```swift
setEntityGaussianStreaming(
    entityId: streamSplat,
    source: .single(filename: "chair", withExtension: "untoldgs"),
    options: GaussianStreamingOptions(
        streamingRadius: 30.0,
        unloadRadius: 45.0
    )
)
```

Parameters:

- `entityId`: The entity created and positioned in Step 1.
- `source`: Use `.single(filename:withExtension:)` for a whole `.ply`/`.untoldgs` asset, or
  `.progressive(baseFilename:levelCount:maxDistances:)` for progressive tiers named
  `<baseFilename>_lod0.untoldgs`, `<baseFilename>_lod1.untoldgs`, etc.
- `streamingRadius`: Distance from the camera at which the splat starts loading.
- `unloadRadius`: Distance beyond which the splat unloads. Should be larger than
  `streamingRadius` to avoid load/unload thrashing at the boundary.
- `boundingBoxHalfExtent`: Optional local-space half-extent for the entity, roughly matching
  the splat's real-world size. `GeometryStreamingSystem`'s frustum gate needs a real
  local-space volume on the entity *before* it ever loads, so a `.untoldgs` source's box is
  read from its baked header synchronously at registration time when this is left `nil` — no
  value needed for that case. **A raw `.ply` source has no baked header, so this must be
  supplied explicitly there** — omitting it leaves the entity non-streaming (logged as a
  warning) rather than registering a zero-size placeholder, which would collapse the frustum
  gate to a single exact point and make re-streaming unreliable once the camera moves away
  and back. When you do need one, the exporter's printed `boundingBoxHalfExtent` diagnostic
  (see above) is a good starting value.
- `priority`: Optional. Higher-priority entities load first when multiple candidates are
  in range at once. Defaults to `0`.

> Note: If no tile is found containing the entity's position, `setEntityGaussianStreaming`
> logs a warning and leaves the entity as a plain, non-streaming entity (no `StreamingComponent`
> is attached) — it will not crash, but it also will not load. Double-check the position
> against the streamed scene's tile bounds if this happens.

### Progressive Gaussian splat streaming

Use `.progressive(...)` with `setEntityGaussianStreaming` when you want tile-driven
load/unload behavior plus the same coarse-to-fine refinement (including the
[overdraw-aware LOD clamp](#overdraw-aware-lod-selection) and the warmth gate of a paged
tier) described above.

Progressive tier filenames must follow this pattern:

```text
<baseFilename>_lod0.untoldgs
<baseFilename>_lod1.untoldgs
<baseFilename>_lod2.untoldgs
...
```

For example, if `baseFilename` is `"chair"` and `levelCount` is `4`, the engine expects:

```text
chair_lod0.untoldgs
chair_lod1.untoldgs
chair_lod2.untoldgs
chair_lod3.untoldgs
```

```swift
setEntityGaussianStreaming(
    entityId: streamSplat,
    source: .progressive(
        baseFilename: "chair",
        levelCount: 4,
        maxDistances: [5.0, 15.0, 25.0, .greatestFiniteMagnitude]
    ),
    options: GaussianStreamingOptions(
        streamingRadius: 30.0,
        unloadRadius: 45.0
    )
)
```

`.untoldgs` progressive tiers always have a baked header, so `boundingBoxHalfExtent` can be
omitted here the same way it can for `.single(...)` with a `.untoldgs` file.

### Putting it together: stream scene + streaming splat

`setEntityGaussianStreaming` needs the tile stubs `setEntityStreamScene` creates (see
[Prerequisites](#prerequisites) above), so the natural place to register streaming splat props
is inside the same completion handler that loads the streamed tile scene:

```swift
let sceneRoot = createEntity()
setEntityStreamScene(entityId: sceneRoot, manifest: "dungeon", withExtension: "json") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    let splat = createEntity()
    translateTo(entityId: splat, position: simd_float3(2.0, 0.0, -4.0))
    rotateBy(entityId: splat, angle: 180.0, axis: simd_float3(1.0, 0.0, 0.0))

    setEntityGaussianStreaming(
        entityId: splat,
        source: .progressive(
            baseFilename: "pooltable",
            levelCount: 4,
            maxDistances: [15.0, 25.0, 35.0, .greatestFiniteMagnitude]
        ),
        options: GaussianStreamingOptions(
            streamingRadius: 100.0,
            unloadRadius: 140.0
        )
    )

    setSceneReady(true)
}
```

`boundingBoxHalfExtent` is omitted from `GaussianStreamingOptions` here since `pooltable` is a
`.untoldgs` progressive asset — its box comes from the baked header automatically (see
[API overview](#api-overview) above). Guarding on `success` before registering the splat and
calling `setSceneReady` matters: without it, a failed scene load would still try to attach a
streaming prop to tile stubs that were never created, and would report the scene ready when it
isn't.

---

## Which function should I use?

| Function | Resident/Streamed | LOD | Use when |
|---|---|---|---|
| `setEntityGaussian(entityId:filename:withExtension:)` | Resident, loads immediately (blocks) | None | A small number of splats that should always be visible (a hero object, a standalone demo scene). |
| `setEntityGaussian(entityId:source:)` | Resident | None (`.single`) or progressive (`.progressive`) | Same as above, plus a single call site that can also take `.progressive(...)` for coarse-to-fine refinement without a tile-streamed scene. |
| `setEntityGaussianAsync` | Resident, loads off-thread | None | Same as `setEntityGaussian`, but avoids a frame hitch on a large `.ply`. |
| `setEntityGaussianStreaming(source:options:)` | Streamed via `GeometryStreamingSystem` | None (`.single`) or progressive (`.progressive`) | Props scattered across a tile-streamed scene that should load/unload with camera distance. |

All progressive paths (`setEntityGaussian(source: .progressive(...))` and
`setEntityGaussianStreaming(source: .progressive(...), options:)`) share the same
[overdraw-aware LOD selection](#overdraw-aware-lod-selection) behavior automatically.
