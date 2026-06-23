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
