# UntoldEngine Gaussian Splat Format (`.untoldgs`)

## Overview

`.untoldgs` is the engine-native container for Gaussian splat assets. It is a
regeneratable cache of a source capture (`.ply` or `.spz`, legacy gzip versions 2-3 only):
`untoldengine export` bakes it, and a version bump means "re-bake". It is **not** an
interchange format.

Versions 1 and 2 stored one flat array of GPU-encoded splats and were read whole.
**Version 3** stores quantised splats in page-aligned chunks so the runtime can read any
chunk by byte range, memory-map it, or load it with Metal fast resource loading straight
into a GPU page, without ever reading the whole file. Everything the scene needs to know
about a splat asset beyond its payload (mesh twin, budgets, portal bakes) lives in the
`.untold` asset that references it (see the `gaussianAsset` record in
[`assetFormat.md`](assetFormat.md)), the same way textures live in `.utex` files.

Design goals:

- any chunk loads on its own by byte range, with per-chunk integrity
- a chunk lands in a GPU page with no CPU transform
- the first read shows the whole asset coarsely (coarsest level first)
- rotation and scale survive quantisation so LOD merging and re-encoding stay possible
- spherical harmonics are optional per device tier and use the renderer's byte contract
- stable on-disk layout independent of Swift ABI

## Core rules

- Little-endian throughout. Magic `"UTGS"` at offset 0 and the version at offset 4 are
  unchanged since version 1, so older files are recognised and rejected with
  `.unsupportedVersion` (re-bake), never misread.
- Every section offset and every chunk payload offset is a multiple of **16 384 bytes**
  (`UntoldGSFormat.pageAlignment`), the VM page size on current Apple devices.
  `MTLDevice.makeBuffer(bytesNoCopy:)` requires page-aligned pointer and length, and
  Metal fast resource loading decompresses on 64 KB chunk boundaries.
- No whole-file hash. A streamed payload is never fully resident, so integrity is a
  CRC-32 per chunk over the unpadded payload.
- One LOD level per chunk. Chunks under a tree node are contiguous in the index, so a
  node maps to one byte range per level.
- An optional **coarse section** after the last chunk payload holds one or two merged
  levels of every chunk (`hasCoarseLevels`). It is advertised by a flag bit and header
  words carved from the reserved tail, so a reader that predates it parses the file
  unchanged and draws the fine records only.

## Layout

```
[0]                  UntoldGSHeaderV3       256 bytes, padded to 16 KB
[chunkIndexOffset]   UntoldGSChunkEntry[]   64 bytes each, padded to a 16 KB multiple
[nodeTreeOffset]     UntoldGSTreeNode[]     48 bytes each, padded
[paletteOffset]      reserved for an SH palette (0 when absent)
[payloadOffset]      chunk payloads, each padded to a 16 KB multiple:
                       core block  16 bytes × splatCount
                       SH block    higher-order SH bytes × splatCount (optional)
[coarseIndexOffset]  UntoldGSChunkEntry[]   optional (`hasCoarseLevels`): coarseLevelCount × chunkCount
                                            entries, level-major, padded to a 16 KB multiple
[coarsePayloadOffset] coarse records, coarsest level first, each level in chunk order:
                       16 bytes × splatCount per entry, 16-byte aligned; padded to 16 KB = fileSize
```

### Header (256 bytes)

| Offset | Size | Field | Notes |
|---|---|---|---|
| 0 | 4 | `magic` | `"UTGS"` |
| 4 | 4 | `version` | 3 |
| 8 | 4 | `flags` | `UntoldGSFlags`: `hasSphericalHarmonics`, `sphericalHarmonicsPalette` (reserved), `antialiased`, `environment` |
| 12 | 1 | `shDegree` | 0…3 |
| 13 | 1 | `coordinateSystem` | `UntoldGSCoordinateSystem` (0 = right/up/back, the engine convention) |
| 14 | 1 | `colorSpace` | `UntoldGSColorSpace` (0 = sRGB display-referred) |
| 15 | 1 | `log2ChunkSplats` | 10 → 1024 splats per chunk (objects), 12 → 4096 (environments) |
| 16 | 4+4+4 | `splatCount`, `chunkCount`, `nodeCount` | |
| 28 | 1+3 | `lodLevels`, pad | |
| 32 | 12+12 | `boundsMin`, `boundsMax` | bounds of the splat centres |
| 56 | 12+12 | `boundingBoxMin`, `boundingBoxMax` | asset-level box expanded by splat extent, shared by every tier of a bake; what `readHeader` returns |
| 80 | 4 | `meanSquaredSplatExtent` | bake-time overdraw statistic (see `estimatedGaussianOverdraw`) |
| 84 | 4 | `captureExposureEV` | |
| 88 | 12 | `captureWhiteBalance` | |
| 100 | 64 | `splatToMesh` | registration onto the mesh twin; identity for worlds |
| 164 | 8×5 | `chunkIndexOffset`, `nodeTreeOffset`, `paletteOffset`, `payloadOffset`, `fileSize` | `fileSize` covers the coarse section |
| 204 | 8 | `coarseIndexOffset` | page multiple at or after the last chunk payload; 0 without `hasCoarseLevels` |
| 212 | 8 | `coarsePayloadOffset` | page multiple after the coarse index; the region runs to `fileSize`; 0 when absent |
| 220 | 4 | `coarseRecordCount` | records over every coarse entry (`splatCount` at 16 stays the fine count) |
| 224 | 1 | `coarseLevelCount` | 0, 1 or 2 (`UntoldGSFormat.maxCoarseLevels`) |
| 225 | 2 | `coarseRatioLog2` | level L holds `max(1, n >> coarseRatioLog2[L − 1])` records of a chunk of n; strictly increasing, unused slot 0; default 3, 6 |
| 227 | 1 | `coarseFlags` | zero; bit 0 reserved for coarse records that carry an SH block |
| 228 | 28 | reserved | zero |

With `hasCoarseLevels` clear every byte of 204…227 must be zero.

### Chunk index entry (64 bytes)

`payloadOffset`, `payloadBytes` (padded), `coreBytes` (= 16 × `splatCount`),
`splatCount`, `lodLevel` (0 = coarsest), `nodeId`, `aabbMin`/`aabbMax` (position decode
constants), `logScaleMin`/`logScaleMax` (scale decode constants), reserved, `crc32`.

Everything needed to serve and decode one chunk is in its entry; the reader never needs
another chunk.

### Coarse index entry (64 bytes, optional)

The coarse index reuses `UntoldGSChunkEntry`, **level-major**: entry `(L − 1) × chunkCount + c`
describes level L of fine chunk c. For a coarse entry `lodLevel` is the level (1 or 2),
`reserved0` the fine chunk index, `nodeId` the fine chunk's node, `splatCount` the merged record
count (**0 = the chunk has no level L**; a chunk of fewer than 16 fine splats has none, and a
chunk with level 2 always has level 1), `coreBytes = payloadBytes = 16 × splatCount` (unpadded,
no SH block), `payloadOffset` 16-byte aligned inside `[coarsePayloadOffset, fileSize)`,
`aabbMin`/`aabbMax` and `logScaleMin`/`logScaleMax` the level's **own** decode ranges (a merged
Gaussian's σ reaches the cluster's extent, far above the fine `logScaleMax`), and `crc32` the
CRC-32 of the level's records. A coarse entry is therefore self-contained exactly like a fine
one: `ChunkRanges(entry:)`, `UntoldGSDecoder.verify`/`decodeCore` and the cull-box padding serve
it with no new code.

The records of the coarsest level come first, then the next finer, each level one contiguous
range in chunk order (`UntoldGSIndex.coarseLevelRange(level:)`), so a runtime can fetch "level 2
of every chunk" as one sequential read before "level 1 of every chunk".

### Coarse records

A coarse record is the fine 16-byte packing against the coarse entry's own ranges. Its colour is
the display-referred DC colour of the merged Gaussian and its opacity the merged coverage; there
is no SH block (`coarseFlags` bit 0 reserves that variant). Each level is ordered by importance
descending like a fine chunk, so every prefix rule holds inside a level.

The levels are produced at bake time by `UntoldGSCoarsener`, per fine chunk, from the chunk's
exact rotations and scales: a weighted Lloyd clustering over the chunk's Morton order (weights
`opacity × (σxσy + σyσz + σzσx)`, a colour term in linear space so clusters do not straddle a
colour edge), then one moment-matched Gaussian per cluster — the mixture's mean and second
moment (within plus between) as the covariance, eigendecomposed by a deterministic Jacobi sweep
back to a rotation and a scale, the colour averaged in linear space, and the opacity
`1 − exp(−Σ αᵢ sᵢ / s_M)` (the members' coverage composited over the merged footprint, so an
opaque wall saturates and a sparse cluster stays linear). Level 2 is built the same way over
level 1. The arithmetic runs in a fixed order per chunk, so a bake is bit-reproducible whatever
the thread count. Two levels at the default ratios add about 14 % to the core bytes of a
1024-splat-chunk file (128 + 16 merged records per chunk); `UntoldGSCookOptions.coarseLevels`
is `.automatic` — the levels for tiers of at least 64 chunks (the ratios clamped to the chunk
size), none below, so small assets bake byte-identically to a file without the section — with
`.off` and `.levels(options)` to force either way (`--splat-coarse-levels`, `--splat-coarse-ratio-log2` on the CLI).

### Tree node (48 bytes)

A binary tree over the chunk array built by range halving, stored in preorder.
`aabbMin`/`aabbMax`, `child0`/`child1` (`0xFFFFFFFF` on leaves), `firstChunk`,
`chunkCount`, `geometricError` (zero for single-level files), `visibilityMaskOffset`
(environments only). Leaves stamp their index into `nodeId` of their chunks.

## The 16-byte core record

The bit layout is the one PlayCanvas ships in `compressed.ply`: proven in production and
about twenty ALU operations to decode.

| Word | Bits | Meaning | Decode |
|---|---|---|---|
| `position` | 11 · 10 · 11 | x, y, z normalised inside the chunk AABB | `mix(aabbMin, aabbMax, t)` |
| `rotation` | 2 + 3 × 10 | smallest-three quaternion; top two bits index the dropped (largest) component, sign chosen so it is positive; the rest in `[-1/√2, 1/√2]` | three masks, one sqrt |
| `scale` | 11 · 10 · 11 | per-axis log-scale normalised inside the chunk's `[logScaleMin, logScaleMax]` | `exp(mix(lo, hi, t))` |
| `rgba` | 8 × 4 | SH DC colour (`0.5 + 0.2821 × f_dc`, display-referred) and post-sigmoid opacity | `/ 255` |

Because chunks are cut from a Morton-ordered array, a chunk of 1024 splats on an
arm's-length object spans a few centimetres and 11-bit positions land well under a
millimetre. Rotation and scale are stored rather than a baked covariance, so the baker
can re-read a file to build coarser levels and the loader can still produce the
`EncodedGaussianSplat` covariance the shaders expect (`UntoldGSSplat.encodedForTBDR`).

Within a chunk, splats are ordered by importance (opacity × area) descending, so a
partial read of a chunk yields its most important splats first.

## Spherical harmonics block

Optional, structure-of-arrays after the core block, so a device tier that skips SH does
not read those bytes. Bytes use the renderer's existing contract
(`quantizeGaussianSHCoefficient`: fixed `[-1, 1]`, dequantised in `Gaussians.metal` as
`(byte - 128) / 128`), channel-major, higher orders only: 9, 24 or 45 bytes per splat for
degree 1, 2, 3. The block can therefore be bound to the GPU as-is. A 16-bit palette
encoding is reserved by the `sphericalHarmonicsPalette` flag and rejected by the reader.

## Swift API

- `UntoldGSFormat.write(splats:options:)` / `write(splats:options:to:)` encode `[UntoldGSSplat]`: Morton order, chunking, per-chunk ranges, tree, page-aligned sections, CRCs, and the coarse section when `UntoldGSWriteOptions.coarseLevels` asks or `coarseLevelsAutomatic` resolves to it. `UntoldGSWriteOptions` carries chunk size, SH degree, the asset-level bounding box and `meanSquaredSplatExtent` of the tier. `writeReporting(…)` returns a `UntoldGSWriteReport` with the chunk count and the `UntoldGSCoarseLevelReport` of the section (levels, ratios, records per level, bytes, chunks too small for a level); `GaussianLODTier.coarseReport` carries it out of a bake.
- `UntoldGSFormat.read(from:)` returns `UntoldGSAsset` in the layout the renderer consumes (every chunk decoded on the CPU). `readHeader(from:)` returns the baked bounding box through a bounded `FileHandle` read; `readHeaderV3` and `readIndex` expose the full header, chunk index and tree.
- `UntoldGSFile(url:)` opens a file, parses only the prefix (and the coarse index, a second bounded read, when flagged), and serves `chunkPayload(at:)` by byte range with CRC verification; `decodeChunk(at:)` and `decodeAll()` decode on the CPU; `coarsePayload(level:chunk:)` and `decodeCoarseLevel(level:chunk:)` do the same for a coarse level. `UntoldGSIndex.coarse`, `coarseEntry(level:chunk:)`, `coarseLevelRange(level:)` and `coarseRecordIndex(level:chunk:)` expose the section; `readIndex(from data:)` needs data that covers the coarse index when flagged (a prefix throws `.truncated`), `readIndex(from url:)` reads both ranges itself.
- `GaussianPageSource` is the byte source of a paged asset (`GaussianPageManager`): the index, the file identity (size, inode, modification time), a synchronous thread-safe range read, a reopen after a fault and a close. `UntoldGSFilePageSource(url:)` implements it over `pread` on a descriptor kept for the life of the entity (validated at open exactly as `UntoldGSFile` validates, no read-ahead); `GaussianPageSourceFactory.override` lets tests inject one.
- `UntoldGSPacking` holds the pure pack/unpack functions for the record and the Morton key; `UntoldGSCRC32` the checksum (the system zlib's `crc32`, whole through `checksum(_:)` or streamed through `initialValue` / `update` / `finalize`); `UntoldGSSplat` converts from the importer's `GaussianSplat` and to `EncodedGaussianSplat`; `UntoldGSColor` mirrors the shaders' sRGB curve for the coarsener's linear-space colour averages.
- `UntoldGSCoarsener.coarsen(_:options:)` merges one chunk's splats into its `UntoldGSCoarseLevels` (`UntoldGSCoarseLevelOptions`: level count, ratios, the 16-splat floor, refinement passes, colour weight).

`bakeGaussianSplatProgressiveTiers` writes every progressive tier as a version-3 file.

## Cooking a capture

`bakeGaussianSplatProgressiveTiers(plyURL:outputBaseURL:levelCount:cookOptions:control:)` (and
the `lodFractions:` and `spzURL:` overloads; the signatures without `control:` are thin
wrappers) cooks a source into one file or a set of `_lodN` tiers in two passes that never hold
a copy of the source or of the splat set beyond one compact store:

- **Pass A — read and cook.** `PLYGaussianSource` opens the `.ply` once, parses the header,
  resolves the vertex properties into a typed layout (byte offset and scalar kind per needed
  property, defaults for the optional ones), and serves the body as windows of about 2 MB read
  with `pread` and parsed in parallel — ASCII bodies are cut at line boundaries and parsed per
  window with the same rules as before. Inside each window's work item `UntoldGSCooker.Kernel`
  applies the cook (the opacity floor, the degenerate check, the similarity transform, the crop)
  and the higher-order harmonics are reduced to the target degree and quantised to the file's
  bytes; the windows are committed in source order into `UntoldGSSplatStore`, a structure of
  arrays of about 56 bytes per splat plus the SH bytes (about 1 GB for 10 M splats at degree 3).
  The budget (`maxSplatCount`), the centre bounds, the asset box and the progressive ranking
  run over the store afterwards. A `.spz` is decoded whole by `SPZReader` and cooked as one
  window.
- **Pass B — write.** For each tier (the store, or a ranked prefix of it) the writer computes
  the Morton keys in parallel and sorts them with a stable radix sort — the same `(key, index)`
  permutation the closure sort produced, the order being total — fixes the layout (the tree's
  node count follows from the chunk count, a chunk's padded payload from its splat count) and
  then, in parallel batches, sorts every chunk by importance, encodes its records and SH bytes
  into a buffer of its own, checksums them, writes them with `pwrite` at the chunk's offset and
  coarsens the chunk in Morton order in the same work item. The coarse section, the header, the
  chunk index and the tree follow at their offsets. Each tier is written to
  `.<name>.untoldgs.tmp-<uuid>` in the output directory and renamed over the destination when
  complete.

Every byte is a function of the cooked splats and the options: the window size, the batch size,
the thread count and the sink (file or memory) never change one, and the output of a given
source with given options is the file the whole-array cook produced before this pipeline
existed. `UntoldGSFormat.write(splats:options:)` and `writeReporting` feed an in-memory list
through the same writer core (a memory sink), so the format tests' CRC pins verify it directly;
`Tests/UntoldEngineTests/UntoldGSCookerEquivalenceTests.swift` keeps the pre-change path
verbatim on the test side and compares the two byte for byte.

`UntoldGSCookControl` carries a progress callback and a cancellation hook. Progress arrives as
`UntoldGSCookProgress` — the phase (`read`, `cook`, then per tier `chunk`, `coarsen` when the
tier bakes coarse levels, `write`), the fraction within the phase, an overall fraction that
reaches 1 with the last tier's `write`, and the tier — from the cooking thread, between window
batches, across the progressive ranking and between chunk batches; the same points poll
`isCancelled` and `Task.isCancelled`. Every tier is written to a temporary file beside its
destination and the set is renamed into place only once the last tier is complete, so a
cancelled bake (`UntoldGSCookError.cancelled`) or a failed one discards its temporaries and
leaves the output directory as it found it — a previous bake's tiers included — with nothing
partial in it. `GaussianProgressiveBakeResult` reports the cook
(`cookReport`), the asset box and the centre bounds of the cooked splats; an editor that needs
the bounds of a source before cooking calls `PLYReader.readGaussianCenterBounds(from:)`, one
streamed pass with nothing resident but the running box, in place of a second full parse.

## Runtime load

`GaussianChunkLoader.load(url:allowPaging:)` keeps the chunk table resident (the 48-byte
`GaussianChunkDecodeConstants` per chunk on the GPU, the `UntoldGSIndex` on the CPU) and
binds the SH bytes as stored; the fused per-chunk pass (`gaussianChunkDecodePreprocess`)
decodes the 16-byte records every frame, for the chunks in view only. Where the records live
depends on the asset's size (`GaussianPagingPolicy`):

- Below the paging threshold — 64 MiB of unpadded records (16 B plus SH per splat) on Apple
  Vision Pro, iPhone, iPad and Apple TV, 512 MiB on the Mac, never above the residency
  budget — every chunk is read by byte range (CRC-verified) into one resident packed buffer,
  as before.
- Above it the records live in a **page pool** of fixed slots, each holding one **tier** of
  one chunk: 256 ranks (4 KiB of core records) plus the matching SH bytes in a sibling pool
  with the same slot layout. A chunk is resident as a prefix of tiers, filled from the chunk
  cull's demand frame by frame (`GaussianPageManager`); nothing is read at load. The pool is
  sized from what a quarter of `MemoryBudgetManager.geometryBudget` leaves after the pools
  already allocated, capped at the asset and at 256 MiB (1 GiB on the Mac). The chunk table
  then also carries, per in-flight slot, a residency table, a page table and a demand table.
  Because each chunk is sorted by importance and its decode constants are per chunk, a tier
  reproduces the file's records bit for bit wherever its slot lands.

`setEntityGaussian` with the `untoldgs` extension, the progressive tiers and the streaming
path all go through the loader; when the per-chunk kernels are unavailable the records are
expanded once into `EncodedGaussianSplat` for the whole-buffer path (a paged load cannot be
expanded, so paging needs the kernels), and without the decode kernel the loader falls back
to `UntoldGSFormat.read`, which decodes on the CPU. Metal fast resource loading would be
another `GaussianPageSource` behind the same protocol.

## Validation

The reader rejects: wrong magic; any version other than 3; SH degree over 3; chunk size
outside 2…16384; the reserved palette flag; empty assets; any misaligned section or chunk
offset; header counts whose byte sizes overflow; sections or chunks outside `fileSize`;
chunk counts and splat totals that disagree with the header; a chunk whose padded size
cannot hold its core and SH blocks; tree nodes that span outside the index or reference
children behind them; a root that does not cover every chunk. `chunkPayload(at:)`
additionally rejects a chunk whose CRC does not match.

With `hasCoarseLevels` set the reader further rejects: a level count outside 1…2; ratios that are
zero, not strictly increasing, above `log2ChunkSplats`, or set in an unused slot; non-zero
`coarseFlags` (`.unsupported`, the reserved SH variant); misaligned coarse offsets; a coarse
index before the payload or overlapping any section; a fine chunk that runs into the coarse
index; a coarse index whose entry count is not `coarseLevelCount × chunkCount`; an entry whose
`lodLevel`, `reserved0` or `nodeId` does not name its level, chunk and node; a record count above
`max(1, splatsPerChunk >> ratio)`; a level 2 without a level 1; an empty entry with bytes, or a
non-empty one whose `coreBytes`/`payloadBytes` are not `16 × splatCount`; a record-misaligned,
overlapping or out-of-file payload; non-finite or inverted ranges; a record total that disagrees
with `coarseRecordCount`. With the flag clear, any non-zero byte in 204…227 is `.corrupt`. There
is no silent fine-only fallback for a malformed section; `coarsePayload(level:chunk:)` rejects a
level whose CRC does not match. A reader that predates the section (or one handed the file with
the flag cleared and the words zeroed) sees only unclaimed bytes inside `[payloadOffset, fileSize)`
and draws the fine records — `UntoldGSFormatTests.testOldReaderSeesFineOnly` emulates it byte
for byte.

A paged asset is verified as it fills: the CRC covers the whole unpadded payload, so a chunk
is checked the moment it becomes fully resident (over its tiers in file order, on the read's
worker thread) and dropped and faulted if it fails; a chunk resident only as a head cannot be
verified — `UntoldGSChunkEntry.reserved0` is the slot for a head CRC in a later revision.
The page source keeps the file's identity (size, inode, modification time) and re-checks it
when a read fails: a changed file faults the asset — its resident pages keep drawing and
nothing new is read — until a periodic reopen (every `GaussianPagingPolicy.faultReopenTicks`,
300 ticks) finds a file whose index equals the one the entity was loaded from; the file's
identity is then adopted, so a byte-identical re-cook (a new inode or modification time, the
same index and chunk CRCs) resumes the paging. A reopen attempted while a straggling read still
holds the old descriptor is refused and tried again a period later.

Tests: `Tests/UntoldEngineTests/UntoldGSFormatTests.swift` and the format cases in
`Tests/UntoldEngineRenderTests/GaussianProgressiveLODTest.swift`; the coarsener's oracles in
`Tests/UntoldEngineTests/UntoldGSCoarsenerTests.swift`; the paging in
`Tests/UntoldEngineTests/GaussianPagingPolicyTests.swift` and
`Tests/UntoldEngineRenderTests/GaussianPagingTest.swift`.
