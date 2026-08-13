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

## Bake Complex Blender Materials

If a Blender material uses node graphs the runtime cannot evaluate directly,
export with material baking. The exporter flattens complex material behavior into
textures the engine can load.

CLI example:

```bash
untoldengine export \
  --input GameData/Models/office/office.usdz \
  --output GameData/Models/office/office.untold \
  --bake-materials
```

Use this when Blender and the engine disagree because the source material uses
procedural nodes, Mix, Math, or other complex graph behavior.

## Bake Color Management

Blender's View Transform, Look, Exposure, and Gamma are scene-wide display
settings. They are not part of a normal mesh import.

Export a color LUT with:

```bash
untoldengine export \
  --input GameData/Models/office/office.usdz \
  --output GameData/Models/office/office.untold \
  --bake-color-management
```

Then load scene-authored data:

```swift
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras and the baked color LUT are registered.
}
```

For tiled scenes:

```swift
loadSceneAuthored(url: manifestURL) { success in
    // Reads scene-authored data from the manifest.
}
```

Toggle the baked LUT for comparison:

```swift
setPostFX(.colorLUT(.enabled(false)))
setPostFX(.colorLUT(.enabled(true)))
```

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
3. If Blender node graphs are involved, try `--bake-materials`.
4. If the whole image tone differs from Blender, try `--bake-color-management`.
5. If runtime memory or package size is high, apply texture baking/optimization.

## Related Documentation

- [Materials](../API/UsingMaterials.md)
- [Bake Materials](../API/UsingBakeMaterials.md)
- [Color Management](../API/UsingColorManagement.md)
- [Post Effects](../API/UsingPostFX.md)
- [Optimizations](../API/Optimizations.md)

