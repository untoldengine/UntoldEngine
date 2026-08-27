# Using Materials in Untold Engine

The engine uses a PBR (Physically Based Rendering) material model. Each entity's mesh can contain one or more submeshes, and each submesh holds its own `Material`. You can read and write individual material properties at runtime using the functions below.

All material functions accept optional `meshIndex` and `submeshIndex` parameters (both default to `0`) so you can target a specific submesh when an entity contains more than one.

> **Note:** Every update function automatically refreshes static batching for the affected entity, so you do not need to do this manually.

---

## Base Color

The base color is stored as a `simd_float4` (RGBA). The `.w` component doubles as the opacity channel.

### Get Base Color

```swift
let color = getMaterialBaseColor(entityId: entity)
// color.x = red, color.y = green, color.z = blue, color.w = alpha
```

### Set Base Color via SwiftUI Color

```swift
updateMaterialColor(entityId: entity, color: .red)
```

This converts the SwiftUI `Color` to RGBA internally. If the alpha is below `1.0`, the material automatically switches to `.blend` alpha mode.

---

## Roughness

Controls how rough or smooth a surface appears. A value of `0.0` is perfectly smooth (mirror-like reflections) and `1.0` is fully rough (diffuse).

### Get Roughness

```swift
let roughness = getMaterialRoughness(entityId: entity)
```

### Set Roughness

```swift
updateMaterialRoughness(entityId: entity, roughness: 0.3)
```

> When a roughness **texture** is present, the scalar value acts as a modulator (multiplied with the texture sample in the shader). If you remove the texture, the scalar value is used directly.

---

## Metallic

Controls how metallic a surface appears. `0.0` is fully dielectric (plastic, wood, etc.) and `1.0` is fully metallic.

### Get Metallic

```swift
let metallic = getMaterialMetallic(entityId: entity)
```

### Set Metallic

```swift
updateMaterialMetallic(entityId: entity, metallic: 1.0)
```

> Like roughness, the scalar value modulates the metallic texture when one is present.

---

## Emissive

Controls self-illumination. The value is a `simd_float3` (RGB) representing the emitted light color and intensity. A value of `.zero` means no emission.

### Get Emissive

```swift
let emissive = getMaterialEmmissive(entityId: entity)
```

### Set Emissive

```swift
updateMaterialEmmisive(entityId: entity, emmissive: simd_float3(1.0, 0.5, 0.0))
```

To apply the same emissive value to an entity and all of its scenegraph descendants:

```swift
updateMaterialEmmisive(entityId: rootEntity, emmissive: simd_float3(1.0, 0.5, 0.0), recursive: true)
```

> **Spelling note:** The API currently uses `getMaterialEmmissive` / `updateMaterialEmmisive` (with double-m). Use these exact names when calling the functions.

---

## Alpha Mode

Determines how the renderer handles transparency for this material.

### Available Modes (`MaterialAlphaMode`)

- **`.opaque`** — Fully opaque. Alpha channel is ignored.
- **`.mask`** — Binary transparency. Pixels with alpha below the cutoff are discarded; the rest are fully opaque. Useful for foliage, fences, etc.
- **`.blend`** — Smooth alpha blending. Pixels are composited based on their alpha value.

### Get Alpha Mode

```swift
let mode = getMaterialAlphaMode(entityId: entity) // returns MaterialAlphaMode
```

### Set Alpha Mode

```swift
updateMaterialAlphaMode(entityId: entity, mode: .blend)
```

---

## Alpha Cutoff

Used only when the alpha mode is `.mask`. Pixels with alpha below this threshold are discarded. The value is clamped to `0.0 ... 1.0`. Default is `0.5`.

### Get Alpha Cutoff

```swift
let cutoff = getMaterialAlphaCutoff(entityId: entity)
```

### Set Alpha Cutoff

```swift
updateMaterialAlphaCutoff(entityId: entity, cutoff: 0.3)
```

---

## Opacity

A convenience layer over the base color's alpha channel (`.w`). The value is clamped to `0.0 ... 1.0`. Setting opacity below `1.0` automatically switches the alpha mode to `.blend`.

### Get Opacity

```swift
let opacity = getMaterialOpacity(entityId: entity)
```

### Set Opacity (all submeshes)

```swift
updateMaterialOpacity(entityId: entity, opacity: 0.5)
```

By default this applies to **every submesh** on the entity. To target a single submesh instead:

```swift
updateMaterialOpacity(entityId: entity, opacity: 0.5, applyToAllSubmeshes: false)
```

To apply opacity to an entity and all of its scenegraph descendants:

```swift
updateMaterialOpacity(entityId: rootEntity, opacity: 0.5, recursive: true)
```

Or specify exact indices:

```swift
updateMaterialOpacity(entityId: entity, opacity: 0.5, meshIndex: 0, submeshIndex: 1)
```

---

## Textures

Each material slot (`.baseColor`, `.roughness`, `.metallic`, `.normal`, `.height` — the `TextureType` enum) can carry an image texture in addition to its scalar/color value. When a texture is present it modulates or replaces the scalar value in the shader, as noted above for roughness and metallic.

### Set a Texture

```swift
updateMaterialTexture(
    entityId: entity,
    textureType: .baseColor,
    path: URL(fileURLWithPath: "/path/to/GameData/Textures/brick_basecolor.png")
)
```

The filename, extension, and containing folder are extracted from `path` and resolved the same way other engine assets are (relative to the game's resource bundle).

### Remove a Texture

```swift
removeMaterialTexture(entityId: entity, textureType: .roughness)
```

Clears the texture and reverts the slot to its scalar value (roughness resets to `1.0`, metallic resets to `0.0`). The original embedded texture, if any, is retained internally so it can be restored later.

### Query a Texture

```swift
let url = getMaterialTextureURL(entityId: entity, type: .baseColor)     // URL? — nil if no texture is set
let mdlTexture = getMaterialMDLTexture(entityId: entity, type: .baseColor) // MDLTexture? — used for embedded USDZ textures
```

### UV Tiling (ST Scale)

`stScale` controls texture-coordinate tiling/repetition across the surface:

```swift
let scale = getMaterialSTScale(entityId: entity)
updateMaterialSTScale(entityId: entity, stScale: 4.0)
```

### Texture Wrap Mode

`WrapMode` is `.clampToEdge` or `.repeat`. Only `.baseColor` currently reports a wrap mode via the getter; `updateTextureSampler` applies the wrap mode to any texture slot's sampler:

```swift
let wrapMode = getTextureWrapMode(entityId: entity, textureType: .baseColor) // WrapMode?
updateTextureSampler(entityId: entity, textureType: .baseColor, wrapMode: .repeat)
```

---

## Height / Parallax Occlusion Mapping

A material's `.height` texture drives Parallax Occlusion Mapping (POM) — a shading-time
technique that displaces the sampled UV based on a height field to make surfaces like brick
or stone read as having real depth, without adding any geometry. See
[docs/proposals/HeightMapParallaxOcclusionMapping.md](../proposals/HeightMapParallaxOcclusionMapping.md)
for the full design rationale.

```swift
updateMaterialTexture(
    entityId: entity,
    textureType: .height,
    path: URL(fileURLWithPath: "/path/to/GameData/Textures/brick_height.png")
)
```

Height textures are treated as linear data (like normal/roughness/metallic), not sRGB.

### Height Scale and Bias

- `heightScale` — total ray-march depth, in UV-normalized units. Interacts with `stScale`:
  retuning a material's UV tiling requires retuning `heightScale` too.
- `heightBias` — mirrors Blender's Displacement node "Midlevel" convention (default `0.5` = no
  shift). Values above `0.5` raise the reference plane (less apparent depth); values below
  lower it.

```swift
updateMaterialHeightScale(entityId: entity, heightScale: 0.08)
updateMaterialHeightBias(entityId: entity, heightBias: 0.5)
```

POM only runs when a material actually has a height texture, and can be disabled without
discarding the texture assignment:

```swift
updateMaterialHeightEnabled(entityId: entity, heightEnabled: false)
```

### Height Remap

Many real-world displacement maps (Substance Designer / Poliigon exports especially) only use
a narrow slice of the full `[0,1]` range — e.g. raw values clustered around `0.51`–`0.54` —
even though `heightScale` is set reasonably. POM has almost no local (brick-to-brick) contrast
to work with in that case, since `heightScale` controls the *maximum* offset, not the
underlying data's dynamic range. `heightRemapMin`/`heightRemapMax` contrast-stretch the raw
sample back to `[0,1]` before `heightBias` is applied. Identity is `(0.0, 1.0)`.

```swift
// A displacement map whose raw values only span roughly 0.50-0.56
updateMaterialHeightRemapMin(entityId: entity, heightRemapMin: 0.50)
updateMaterialHeightRemapMax(entityId: entity, heightRemapMax: 0.56)
```

You can find a reasonable min/max by sampling the raw texture's histogram (e.g. via
`sips -g all` on the source file's decoded range, or a pixel readback), but trial-and-error
in the Inspector while watching the `pomOffsetDebug` render debug view works too.

### Known limitations

- Shadows are computed from the true (flat) geometry, so a height-mapped surface's shadow
  won't reflect its perceived depth (e.g. no shadow inside a mortar recess). POM
  self-shadowing is not implemented.
- Picking hits the true low-poly geometry, not the perceived POM surface.
- Height-mapped materials must be opaque — POM does not run in the forward transparency pass.

## Quick Reference

- `getMaterialBaseColor(entityId:meshIndex:submeshIndex:)` → `simd_float4`
- `updateMaterialColor(entityId:color:meshIndex:submeshIndex:)` — sets base color from SwiftUI `Color`
- `getMaterialRoughness(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialRoughness(entityId:roughness:meshIndex:submeshIndex:)`
- `getMaterialMetallic(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialMetallic(entityId:metallic:meshIndex:submeshIndex:)`
- `getMaterialEmmissive(entityId:meshIndex:submeshIndex:)` → `simd_float3`
- `updateMaterialEmmisive(entityId:emmissive:recursive:meshIndex:submeshIndex:)`
- `getMaterialAlphaMode(entityId:meshIndex:submeshIndex:)` → `MaterialAlphaMode`
- `updateMaterialAlphaMode(entityId:mode:meshIndex:submeshIndex:)`
- `getMaterialAlphaCutoff(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialAlphaCutoff(entityId:cutoff:meshIndex:submeshIndex:)`
- `getMaterialOpacity(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialOpacity(entityId:opacity:applyToAllSubmeshes:recursive:)`
- `updateMaterialOpacity(entityId:opacity:meshIndex:submeshIndex:)`
- `updateMaterialTexture(entityId:textureType:path:meshIndex:submeshIndex:)`
- `removeMaterialTexture(entityId:textureType:meshIndex:submeshIndex:)`
- `getMaterialTextureURL(entityId:type:meshIndex:submeshIndex:)` → `URL?`
- `getMaterialMDLTexture(entityId:type:meshIndex:submeshIndex:)` → `MDLTexture?`
- `getMaterialSTScale(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialSTScale(entityId:stScale:meshIndex:submeshIndex:)`
- `getTextureWrapMode(entityId:textureType:meshIndex:submeshIndex:)` → `WrapMode?`
- `updateTextureSampler(entityId:textureType:wrapMode:meshIndex:submeshIndex:)`
- `getMaterialHeightScale(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialHeightScale(entityId:heightScale:meshIndex:submeshIndex:)`
- `getMaterialHeightBias(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialHeightBias(entityId:heightBias:meshIndex:submeshIndex:)`
- `getMaterialHeightEnabled(entityId:meshIndex:submeshIndex:)` → `Bool`
- `updateMaterialHeightEnabled(entityId:heightEnabled:meshIndex:submeshIndex:)`
- `getMaterialHeightRemapMin(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialHeightRemapMin(entityId:heightRemapMin:meshIndex:submeshIndex:)`
- `getMaterialHeightRemapMax(entityId:meshIndex:submeshIndex:)` → `Float`
- `updateMaterialHeightRemapMax(entityId:heightRemapMax:meshIndex:submeshIndex:)`
