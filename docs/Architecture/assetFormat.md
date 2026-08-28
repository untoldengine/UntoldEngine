# UntoldEngine Asset Format (`.untold`)

## Overview

`.untold` is the native runtime asset container for UntoldEngine tile streaming.

It is **not** an interchange format and it is **not** intended to preserve full USD
semantics. USD/USDZ remains the authoring/import format. The `.untold` container is the
runtime package consumed by the engine for:

- tile files
- per-tile LOD files
- HLOD files
- shared bucket files

V1 supports:

- static meshes (transforms, bounds, vertex/index buffers)
- basic PBR materials and texture references
- skeletal rigs (skeleton hierarchy, bind/rest poses)
- skinning (joint indices and weights per vertex)
- animation clips (translation and rotation keyframe channels)

Not yet supported:

- blend shapes / morph targets

The design goals are:

- fast runtime parse with no ModelIO dependency
- direct tile/HLOD/LOD streaming
- byte-range-friendly remote streaming (tiles are downloaded on demand from HTTP/HTTPS CDNs and cached locally before parsing; see [`asset_remote_streaming.md`](asset_remote_streaming.md))
- explicit binary versioning
- stable on-disk layout independent of Swift ABI

## Core Rules

- Endianness: little-endian for all integers and floats
- Float format: IEEE-754 `Float32`
- Chunk alignment: 16-byte aligned file offsets
- String encoding: UTF-8, null-terminated
- Invalid reference sentinel: `UInt32.max`
- Matrix encoding: 16 `Float32`s, column-major, matching `simd_float4x4`
- AABB encoding: `min.xyz` followed by `max.xyz`
- File offsets: absolute `UInt64` offsets from the start of the file
- Chunk-local offsets: `UInt64` offsets from the start of the uncompressed chunk payload
- Versioning: unsupported versions must be rejected by the loader

The Swift types in
`Sources/UntoldEngine/AssetFormat/UntoldFormat.swift`
are the **logical schema**. They are not the authoritative on-disk memory layout.
The exporter and loader must write/read fields explicitly.

## Physical File Layout

Each `.untold` file is laid out as:

1. `FileHeader`
2. `ChunkTable`
3. aligned chunk payloads

Recommended chunk payload order for **mesh files**:

1. `STRING_TABLE`
2. `ENTITY_TABLE`
3. `MESH_TABLE`
4. `MATERIAL_TABLE`
5. `TEXTURE_TABLE`
6. `VERTEX_DATA`
7. `INDEX_DATA`
8. `EDGE_INDEX_DATA` (optional architectural edge indices)

Optional additional chunks for **skeletal / animated files**:

9. `SKELETON_TABLE`
10. `SKELETON_JOINT_TABLE`
11. `SKIN_TABLE`
12. `SKIN_JOINT_MAPPING_TABLE`
13. `JOINT_INDEX_DATA`
14. `JOINT_WEIGHT_DATA`

Chunk payload order for **animation-only files** (`fileType = animation`):

1. `STRING_TABLE`
2. `ANIMATION_CLIP_TABLE`
3. `ANIMATION_CHANNEL_TABLE`
4. `TRANSLATION_KEYFRAME_TABLE`
5. `ROTATION_KEYFRAME_TABLE`

This order allows the runtime to read metadata first and defer heavy geometry reads.

Plugin-owned chunks may use chunk type IDs `>= 0x8000`. The engine preserves
those chunk IDs, validates the standard chunk table, and exposes plugin chunk
payloads through `UntoldDecodedAsset.pluginChunks`. Core engine loaders treat
the bytes as opaque.

## Header Encoding

The header is written field-by-field in this exact order:

```text
magic[8]                     UInt8 x 8
formatVersion                UInt32
fileType                     UInt32
flags                        UInt32
headerSize                   UInt32
chunkCount                   UInt32
meshCount                    UInt32
materialCount                UInt32
textureRefCount              UInt32
entityCount                  UInt32
vertexLayout                 UInt32
reserved0                    UInt32
worldBounds.min              Float32 x 3
worldBounds.max              Float32 x 3
rootTransform                Float32 x 16
contentHash                  UInt8 x 32
reserved1                    UInt8 x 32
```

Rules:

- `magic` must be exactly 8 bytes, recommended value: `"UNTOLD\0\0"`
- `headerSize` is the serialized byte size of the header, not `MemoryLayout`
- `contentHash` is exactly 32 bytes
- `reserved1` is exactly 32 bytes

## Chunk Table Encoding

Each chunk entry is written in this exact order:

```text
chunkType                    UInt32
compressionType              UInt32
fileOffset                   UInt64
compressedSize               UInt64
uncompressedSize             UInt64
elementCount                 UInt32
reserved0                    UInt32
```

Rules:

- `fileOffset` must be 16-byte aligned
- if compression is `none`, `compressedSize == uncompressedSize`
- `elementCount` is used for record-table chunks
- `chunkType >= 0x8000` is reserved for plugin extension chunks

## Plugin Extension Chunk Envelope

Plugin chunks are normal `.untold` chunks with a reserved chunk type
(`>= 0x8000`). Their payload starts with a small engine-defined envelope,
followed by plugin-owned opaque bytes:

```text
magic                        UInt32   // "UEXT"
formatVersion                UInt16   // 1
pluginIDLength               UInt16
chunkKind                    UInt32
chunkVersion                 UInt32
pluginID                     UInt8 x pluginIDLength, UTF-8, no terminator
payload                      UInt8 x remaining bytes
```

Rules:

- `pluginID` should use the same reverse-DNS namespace as the plugin package
- `chunkKind` is plugin-defined and stable within that plugin namespace
- `chunkVersion` is plugin-defined and should change when payload decoding
  changes
- cooked native data should include enough plugin-side versioning to reject
  incompatible payloads
- unknown plugin chunks are valid and must not make core loading fail unless
  their envelope is malformed

Examples of plugin chunk payloads include cooked physics shapes, particle
effect descriptors, fluid volume bricks, vegetation instance cells, and impostor
atlases. The core engine does not decode those payloads.

## String Table Encoding

The string table payload is a raw byte blob containing:

- concatenated UTF-8 strings
- one `0x00` terminator after each string

Rules:

- all string references are `UInt32` byte offsets into this chunk
- `UInt32.max` means “no string”
- the exporter should deduplicate strings
- the loader must verify that each referenced offset is within the chunk and reaches a null terminator before chunk end

## Entity Record Encoding

Each entity record is serialized in this exact order:

```text
entityId                     UInt32
parentEntityId               UInt32
nameOffset                   UInt32
firstMeshRecordIndex         UInt32
meshRecordCount              UInt32
flags                        UInt32
localBounds.min              Float32 x 3
localBounds.max              Float32 x 3
worldBounds.min              Float32 x 3
worldBounds.max              Float32 x 3
localTransform               Float32 x 16
```

Rules:

- `parentEntityId == UInt32.max` means no parent
- mesh records for one entity should be contiguous in the mesh table
- `firstMeshRecordIndex + meshRecordCount` must stay within mesh table bounds

## Mesh Record Encoding

Each mesh record is serialized in this exact order:

```text
entityId                     UInt32
meshNameOffset               UInt32
materialIndex                UInt32
indexType                    UInt32
vertexCount                  UInt32
indexCount                   UInt32
vertexStrideBytes            UInt32
flags                        UInt32
vertexDataOffset             UInt64
indexDataOffset              UInt64
vertexDataSizeBytes          UInt64
indexDataSizeBytes           UInt64
estimatedGPUBytes            UInt64
reserved0                    UInt64
localBounds.min              Float32 x 3
localBounds.max              Float32 x 3
```

For mesh files that include `EDGE_INDEX_DATA`, `reserved0` stores optional edge metadata:

- low 32 bits: byte offset into the uncompressed `EDGE_INDEX_DATA` chunk
- high 32 bits: architectural edge index count

The edge index type matches `indexType`. Edges are emitted as index pairs and are intended for clean wireframe/outline rendering; they contain boundary and hard-angle edges, not every triangle edge.

Rules:

- `vertexDataOffset` is relative to the start of `VERTEX_DATA`
- `indexDataOffset` is relative to the start of `INDEX_DATA`
- `vertexDataSizeBytes == vertexCount * vertexStrideBytes`
- `indexDataSizeBytes == indexCount * indexElementSize`
- `materialIndex == UInt32.max` means no material

## Material Record Encoding

Each material record is serialized in this exact order:

```text
nameOffset                        UInt32
flags                             UInt32
baseColorFactor                   Float32 x 4
emissiveFactor                    Float32 x 3
normalScale                       Float32
metallicFactor                    Float32
roughnessFactor                   Float32
occlusionStrength                 Float32
alphaCutoff                       Float32
baseColorTextureIndex             UInt32
normalTextureIndex                UInt32
metallicTextureIndex              UInt32
roughnessTextureIndex             UInt32
emissiveTextureIndex              UInt32
occlusionTextureIndex             UInt32
heightTextureIndex                UInt32
heightScale                       Float32
heightMidlevel                    Float32
heightRemapMin                    Float32
heightRemapMax                    Float32
reserved0                         UInt32 x 2
```

`heightTextureIndex`/`heightScale`/`heightMidlevel` were added at `formatVersion = 3`
(`UntoldFormat.minHeightMapVersion`) and drive Parallax Occlusion Mapping — see
[HeightMapParallaxOcclusionMapping.md](../proposals/HeightMapParallaxOcclusionMapping.md).
`heightRemapMin`/`heightRemapMax` were added at `formatVersion = 4`
(`UntoldFormat.minHeightRemapVersion`) — a contrast-stretch applied to the raw height sample
before `heightMidlevel`, needed because many real-world displacement maps only use a narrow slice
of `[0,1]`. Files older than `minHeightMapVersion` have none of these bytes on disk; files
between `minHeightMapVersion` and `minHeightRemapVersion` have the height fields but not the
remap fields. The reader picks one of three version-gated decode paths accordingly
(`UntoldMaterialRecordV1.decode` / `.decodeLegacyWithHeightNoRemap` /
`.decodeLegacyWithoutHeight`) so older files still load correctly, defaulting
`heightRemapMin/Max` to the identity `(0.0, 1.0)` when absent.

Rules:

- texture indices point into `TEXTURE_TABLE`
- any texture index may be `UInt32.max`
- `flags` holds alpha mode, double-sided, transparent, and similar runtime bits — not yet
  populated by the exporter as of this writing; the whole 32-bit field is currently `0`
- of the two `reserved0` words, the first packs the roughness/metallic texture-channel
  selector (`UntoldMaterialRecordV1.packTextureChannels`); only the second is genuinely spare

## Texture Reference Encoding

Each texture record is serialized in this exact order:

```text
nameOffset                    UInt32
uriOffset                     UInt32
textureFormat                 UInt32
flags                         UInt32
width                         UInt32
height                        UInt32
mipCount                      UInt32
reserved0                     UInt32
```

Rules:

- `uriOffset` points into the string table
- the URI should reference a cooked texture asset or runtime-resolvable texture path
- `textureFormat` describes the cooked/runtime texture format

## Vertex Layout V1

V1 supports one layout only:

- `UNT_VERTEX_LAYOUT_PBR_STATIC_V1`

Serialized layout:

```text
position.x                    Float32
position.y                    Float32
position.z                    Float32
normalPacked                  UInt32
tangentPacked                 UInt32
uv0.u                         UInt16
uv0.v                         UInt16
uv1.u                         UInt16
uv1.v                         UInt16
color0.r                      UInt8
color0.g                      UInt8
color0.b                      UInt8
color0.a                      UInt8
```

Total size: 32 bytes

Rules:

- `uv0` is required
- `uv1` may be zeroed if unused
- `color0` defaults to `255,255,255,255` if unused

## Packed Normal and Tangent Encoding

`normalPacked` and `tangentPacked` use signed normalized `10:10:10:2` packing.

For `normalPacked`:

- X: signed normalized 10-bit
- Y: signed normalized 10-bit
- Z: signed normalized 10-bit
- W: unused, stored as 0

For `tangentPacked`:

- X: signed normalized 10-bit tangent x
- Y: signed normalized 10-bit tangent y
- Z: signed normalized 10-bit tangent z
- W: handedness sign encoded in signed normalized 2-bit space

Recommended tangent handedness mapping:

- `+1` for non-negative handedness
- `-1` for negative handedness

Exporter rules:

- normalize input normal/tangent before packing
- clamp components to `[-1, 1]`
- write `normalPacked.w = 0`
- write `tangentPacked.w = +1` or `-1`

Runtime rule:

- reconstruct bitangent as `cross(normal, tangent.xyz) * tangentSign`

## Index Data Rules

- `indexType = uint16` means 2 bytes per index
- `indexType = uint32` means 4 bytes per index
- all indices in one mesh must use one type
- exporter should prefer `uint16` when `vertexCount <= 65535`

## Skeleton Record Encoding

Each skeleton record is serialized in this exact order:

```text
entityId                     UInt32
nameOffset                   UInt32
firstJointIndex              UInt32
jointCount                   UInt32
```

## Skeleton Joint Record Encoding

Each joint record is serialized in this exact order:

```text
parentJointIndex             UInt32    (UInt32.max = root joint)
jointPathOffset              UInt32    (string table offset for the joint's hierarchy path)
flags                        UInt32
bindTransform                Float32 x 16   (column-major 4×4)
restTransform                Float32 x 16   (column-major 4×4)
```

## Skin Record Encoding

Each skin record is serialized in this exact order:

```text
entityId                     UInt32
meshRecordIndex              UInt32
skeletonEntityId             UInt32
jointCount                   UInt32
firstJointMappingIndex       UInt32
jointMappingCount            UInt32
jointIndexDataOffset         UInt64
jointWeightDataOffset        UInt64
vertexCount                  UInt32
reserved0                    UInt32
```

Rules:

- `JOINT_INDEX_DATA` stores 4 packed `UInt8` joint indices per vertex (4 bytes × vertexCount)
- `JOINT_WEIGHT_DATA` stores 4 packed `UInt8` weights per vertex, normalized to 255 (4 bytes × vertexCount)
- up to 4 joints per vertex; unused slots are zero-padded

## Skin Joint Mapping Record Encoding

```text
skeletonJointIndex           UInt32
```

## Animation Clip Record Encoding

```text
nameOffset                   UInt32
reserved0                    UInt32
duration                     Float32 (seconds)
reserved1                    UInt32
firstChannelIndex            UInt32
channelCount                 UInt32
```

## Animation Channel Record Encoding

```text
jointPathOffset              UInt32
firstTranslationIndex        UInt32
translationCount             UInt32
firstRotationIndex           UInt32
rotationCount                UInt32
reserved0                    UInt32
```

## Translation Keyframe Record Encoding

```text
time                         Float32 (seconds)
value.x                      Float32
value.y                      Float32
value.z                      Float32
```

## Rotation Keyframe Record Encoding

```text
time                         Float32 (seconds)
value.x                      Float32   (quaternion, XYZW)
value.y                      Float32
value.z                      Float32
value.w                      Float32
```

## Compression Rules

Supported compression types:

- `none`
- `lz4`

> `zstd` is listed in some early spec revisions but is **not currently implemented** by the exporter or runtime. Loaders must reject files with `compressionType = zstd`.

Rules:

- compression is applied per chunk, not whole-file
- offsets stored in metadata reference the **uncompressed** chunk payload layout
- metadata chunks may remain uncompressed for simpler startup
- geometry chunks (`VERTEX_DATA`, `INDEX_DATA`) may be compressed; pass `--compress-geometry` to the exporter to enable LZ4
- `EDGE_INDEX_DATA` is optional and currently stored uncompressed

## Validation Rules

The loader must reject files when:

- magic is invalid
- version is unsupported
- required chunks are missing
- chunk offsets exceed file length
- chunk offsets are not 16-byte aligned
- string offsets fall outside the string table
- mesh/entity/material/texture indices are out of range
- vertex, index, or edge-index ranges exceed their chunk bounds
- `vertexStrideBytes` does not match the declared vertex layout
- `indexDataSizeBytes` does not match `indexCount * indexElementSize`

## Implementation Notes

Do not serialize `.untold` files using `MemoryLayout<T>` or direct struct dumps.

Both the exporter and the loader must use explicit field-by-field helpers:

- `writeUInt32LE`
- `writeUInt64LE`
- `writeFloat32LE`
- `writeBytes`
- `readUInt32LE`
- `readUInt64LE`
- `readFloat32LE`
- `readBytes`

This keeps the binary stable even if the Swift type layout changes.
