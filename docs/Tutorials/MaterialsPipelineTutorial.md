# Materials, Textures, And Color Management

This tutorial connects the runtime material API with exporter-side material and
color-management workflows. Use it when a scene loads correctly but its surfaces
or final image do not match what you authored.

## Runtime Material Editing

Untold Engine uses PBR materials. Each renderable entity can have one or more
meshes and submeshes, and each submesh owns a material.

Set base color:

```swift
updateMaterialColor(entityId: entity, color: .red)
```

Set roughness and metallic:

```swift
updateMaterialRoughness(entityId: entity, roughness: 0.35)
updateMaterialMetallic(entityId: entity, metallic: 1.0)
```

Set opacity:

```swift
updateMaterialOpacity(entityId: entity, opacity: 0.5)
```

Setting opacity below `1.0` automatically switches the material to blend mode.
For scene-wide visibility modes, prefer scene channels instead of opacity.

## Target A Specific Submesh

Material APIs accept optional `meshIndex` and `submeshIndex` values:

```swift
updateMaterialRoughness(
    entityId: entity,
    roughness: 0.2,
    meshIndex: 0,
    submeshIndex: 1
)
```

Use this when a model has multiple material slots and only one surface needs to
change.

## Runtime Textures

Set a texture:

```swift
updateMaterialTexture(
    entityId: entity,
    textureType: .baseColor,
    path: URL(fileURLWithPath: "/path/to/GameData/Textures/brick_basecolor.png")
)
```

Remove a texture:

```swift
removeMaterialTexture(entityId: entity, textureType: .roughness)
```

Adjust UV tiling:

```swift
updateMaterialSTScale(entityId: entity, stScale: 4.0)
updateTextureSampler(entityId: entity, textureType: .baseColor, wrapMode: .repeat)
```

Material changes automatically notify static batching when needed.

## Complex Blender Materials

The exporter only reads a fixed set of material inputs (base color,
roughness, metallic, normal, emissive). If a Blender material uses node
graphs the runtime cannot evaluate directly — procedural nodes, `Mix`,
`Math`, or other complex graph behavior — bake it to flat textures with a
third-party tool before export so the imported result matches Blender. The
Blender addon's `Untold Materials` panel (`Scan Materials`) tells you which
materials diverge and why; see [Using The Blender
Plugin](../API/UsingBlenderAddon.md#material-fidelity).

## Color Grading

Blender's View Transform, Look, Exposure, and Gamma are scene-wide display
settings, not part of a normal mesh import. The engine approximates them
with a native tonemap operator (`setPostFX(.tonemapOperator(_))`, ACES
Filmic by default, AgX also available) and composes an optional
externally-authored `.cube` creative grade on top:

```bash
untoldengine export \
  --input GameData/Models/office/office.usdz \
  --output GameData/Models/office/office.untold \
  --color-grade-lut GameData/LUTs/warm_grade.cube
```

Then load scene-authored data:

```swift
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras and the .cube grade are registered.
}
```

For tiled scenes:

```swift
loadSceneAuthored(url: manifestURL) { success in
    // Reads scene-authored data from the manifest.
}
```

Toggle the grade for comparison:

```swift
setPostFX(.colorGradeLUT(.enabled(false)))
setPostFX(.colorGradeLUT(.enabled(true)))
```

See [Using Color Management](../API/UsingColorManagement.md) for the full
picture, including the standalone `setColorGradeLUT` API.

## Texture Optimization

After export, use the texture baker when you need optimized runtime textures:

```bash
untoldengine texbake --dir GameData/Models/robot/Textures
untoldengine texbake --patch-refs GameData/Models/robot/robot.untold
```

Use this as part of production optimization, not as a first debugging step.
First confirm the unoptimized asset looks correct.

## Practical Debug Order

When a material does not look right:

1. Confirm the `.untold` asset loads successfully.
2. Check base color, roughness, metallic, normal, and opacity.
3. If Blender node graphs are involved, scan materials in the Blender addon
   and bake divergent ones with a third-party tool before re-exporting.
4. If the whole image tone differs from Blender, try switching the tonemap
   operator (`.aces`/`.agx`) or applying a `--color-grade-lut`.
5. If runtime memory or package size is high, apply texture baking/optimization.

## Related Documentation

- [Materials](../API/UsingMaterials.md)
- [Color Management](../API/UsingColorManagement.md)
- [Post Effects](../API/UsingPostFX.md)
- [Optimizations](../API/Optimizations.md)

