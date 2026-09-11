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

## Layout

```
[0]                  UntoldGSHeaderV3       256 bytes, padded to 16 KB
[chunkIndexOffset]   UntoldGSChunkEntry[]   64 bytes each, padded to a 16 KB multiple
[nodeTreeOffset]     UntoldGSTreeNode[]     48 bytes each, padded
[paletteOffset]      reserved for an SH palette (0 when absent)
[payloadOffset]      chunk payloads, each padded to a 16 KB multiple:
                       core block  16 bytes × splatCount
                       SH block    higher-order SH bytes × splatCount (optional)
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
| 164 | 8×5 | `chunkIndexOffset`, `nodeTreeOffset`, `paletteOffset`, `payloadOffset`, `fileSize` | |
| 204 | 52 | reserved | zero |

### Chunk index entry (64 bytes)

`payloadOffset`, `payloadBytes` (padded), `coreBytes` (= 16 × `splatCount`),
`splatCount`, `lodLevel` (0 = coarsest), `nodeId`, `aabbMin`/`aabbMax` (position decode
constants), `logScaleMin`/`logScaleMax` (scale decode constants), reserved, `crc32`.

Everything needed to serve and decode one chunk is in its entry; the reader never needs
another chunk.

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

- `UntoldGSFormat.write(splats:options:)` / `write(splats:options:to:)` encode `[UntoldGSSplat]`: Morton order, chunking, per-chunk ranges, tree, page-aligned sections, CRCs. `UntoldGSWriteOptions` carries chunk size, SH degree, the asset-level bounding box and `meanSquaredSplatExtent` of the tier.
- `UntoldGSFormat.read(from:)` returns `UntoldGSAsset` in the layout the renderer consumes (every chunk decoded on the CPU). `readHeader(from:)` returns the baked bounding box through a bounded `FileHandle` read; `readHeaderV3` and `readIndex` expose the full header, chunk index and tree.
- `UntoldGSFile(url:)` opens a file, parses only the prefix, and serves `chunkPayload(at:)` by byte range with CRC verification; `decodeChunk(at:)` and `decodeAll()` decode on the CPU.
- `UntoldGSPacking` holds the pure pack/unpack functions for the record and the Morton key; `UntoldGSCRC32` the checksum; `UntoldGSSplat` converts from the importer's `GaussianSplat` and to `EncodedGaussianSplat`.

`bakeGaussianSplatProgressiveTiers` writes every progressive tier as a version-3 file.

## Runtime load

`GaussianChunkLoader.load(url:)` reads every chunk by byte range (CRC-verified) into one
packed staging buffer, binds the SH bytes as stored, and runs the `gaussianDecodeChunks`
kernel (one threadgroup per chunk, `GaussianChunkDecodeConstants` per chunk) to expand the
16-byte records into `EncodedGaussianSplat` for the existing cull, sort and draw passes.
`setEntityGaussian` with the `untoldgs` extension, the progressive tiers and the streaming
path all go through it; when the kernel is unavailable the loader falls back to
`UntoldGSFormat.read`, which decodes on the CPU. Metal fast resource loading and a resident
page pool arrive with the shared-sort work.

## Validation

The reader rejects: wrong magic; any version other than 3; SH degree over 3; chunk size
outside 2…16384; the reserved palette flag; empty assets; any misaligned section or chunk
offset; header counts whose byte sizes overflow; sections or chunks outside `fileSize`;
chunk counts and splat totals that disagree with the header; a chunk whose padded size
cannot hold its core and SH blocks; tree nodes that span outside the index or reference
children behind them; a root that does not cover every chunk. `chunkPayload(at:)`
additionally rejects a chunk whose CRC does not match.

Tests: `Tests/UntoldEngineTests/UntoldGSFormatTests.swift` and the format cases in
`Tests/UntoldEngineRenderTests/GaussianProgressiveLODTest.swift`.
