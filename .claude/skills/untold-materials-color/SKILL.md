---
name: untold-materials-color
description: Use when a loaded scene's surfaces or final image don't match what was authored — editing runtime PBR material properties (color, roughness, metallic, opacity, textures), diagnosing Blender materials the exporter can't evaluate directly, applying color grading/tonemap operators and .cube LUTs, or running the texture baker for shipping builds. Triggers on "change this material's color/roughness", "the material doesn't match Blender", "the image looks too flat/wrong tone", "apply a color grade", "optimize/bake textures". Not for export-time conversion of a new asset (see untold-asset-pipeline) or scene-channel-driven visibility/opacity for a whole class of objects (see untold-scene-channels).
version: 0.1.0
---

# Materials, Textures, and Color Management in Untold Engine

Use this when a scene already loads, but a surface or the overall image doesn't match what was authored in Blender. It connects the runtime material API to exporter-side material fidelity and color-management workflows.

## 1. Runtime material editing

Every renderable entity has one or more meshes/submeshes, each owning a `Material` with fixed PBR slots (`baseColor, roughness, metallic, normal, emissive, height`). Always go through accessor functions — they refresh static batching, which a direct field write would skip:

```swift
updateMaterialColor(entityId: entity, color: .red)
updateMaterialRoughness(entityId: entity, roughness: 0.35)
updateMaterialMetallic(entityId: entity, metallic: 1.0)
updateMaterialOpacity(entityId: entity, opacity: 0.5)   // opacity < 1.0 auto-switches to blend mode
```

For scene-wide visibility (hide/wireframe/ghost a whole class of objects), prefer scene channels instead of opacity — see `untold-scene-channels`.

Target a specific submesh when a model has multiple material slots and only one surface needs to change:

```swift
updateMaterialRoughness(entityId: entity, roughness: 0.2, meshIndex: 0, submeshIndex: 1)
```

## 2. Runtime textures

```swift
updateMaterialTexture(
    entityId: entity,
    textureType: .baseColor,
    path: URL(fileURLWithPath: "/path/to/GameData/Textures/brick_basecolor.png")
)
removeMaterialTexture(entityId: entity, textureType: .roughness)
updateMaterialSTScale(entityId: entity, stScale: 4.0)
updateTextureSampler(entityId: entity, textureType: .baseColor, wrapMode: .repeat)
```

## 3. Complex Blender materials the exporter can't bake

The exporter only reads a fixed set of material inputs (base color, roughness, metallic, normal, emissive). Procedural-node inputs with no image behind them get baked automatically during export. If a Blender material uses other node graphs the runtime can't evaluate directly — images blended by `Mix`, adjusted by `Math`, or other complex graph behavior — bake it to flat textures with a third-party tool before export so the import matches Blender.

Check what diverged with the Blender addon's `Untold Materials` panel → `Scan Materials` (`docs/API/UsingBlenderAddon.md#material-fidelity`), or read the material fidelity report printed at the end of the export log (`docs/API/UsingTheExporter.md#procedural-materials`).

## 4. Color grading

Blender's View Transform, Look, Exposure, and Gamma are scene-wide display settings — not part of a normal mesh import. The engine approximates them with a native tonemap operator (ACES Filmic by default, AgX also available) and an optional externally-authored `.cube` creative grade composed on top:

```bash
untoldengine export \
  --input GameData/Models/office/office.usdz \
  --output GameData/Models/office/office.untold \
  --color-grade-lut GameData/LUTs/warm_grade.cube
```

```swift
setPostFX(.tonemapOperator(.aces))   // or .agx
```

Load scene-authored data (lights/cameras/the `.cube` grade baked into the `.untold`, not just geometry):

```swift
loadSceneAuthored(filename: "office", withExtension: "untold") { success in }
loadSceneAuthored(url: manifestURL) { success in }   // tiled scenes, reads from manifest
```

Toggle the grade for A/B comparison:

```swift
setPostFX(.colorGradeLUT(.enabled(false)))
setPostFX(.colorGradeLUT(.enabled(true)))
```

A standalone `setColorGradeLUT` API also exists outside the scene-authored path — see `docs/API/UsingColorManagement.md`.

## 5. Texture optimization (shipping builds)

```bash
untoldengine texbake --dir GameData/Models/robot/Textures
untoldengine texbake --patch-refs GameData/Models/robot/robot.untold
```

Use this as a production optimization step, not a first debugging move — confirm the unoptimized asset looks correct first, then bake.

## 6. Practical debug order when a material looks wrong

1. Confirm the `.untold` asset actually loaded successfully.
2. Check base color, roughness, metallic, normal, and opacity via the accessor getters.
3. If Blender node graphs are involved, read the material fidelity report at the end of the export log — it says what was baked and what still diverges. Bake those with a third-party tool and re-export.
4. If the whole image's tone differs from Blender, try switching the tonemap operator (`.aces`/`.agx`) or applying a `--color-grade-lut`.
5. Only then, if runtime memory or package size is high, apply `texbake` optimization.

Full reference: `docs/API/UsingMaterials.md`, `docs/API/UsingColorManagement.md`, `docs/API/UsingPostFX.md`, `docs/API/Optimizations.md`.
