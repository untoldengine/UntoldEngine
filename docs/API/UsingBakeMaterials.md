# Baking Materials

Blender node-graph materials can do things the `.untold` exporter cannot
represent directly: `Mix`/`Add Shader` blending, `Math`/`Mix` node chains,
procedural textures (noise, gradients, voronoi), and other node combinations
feeding the Principled BSDF. Left as-is, the exporter can only read the
Principled BSDF's direct inputs (base color, roughness, metallic, normal,
emissive), so a divergent node graph would export looking wrong.

`--bake-materials` closes that gap at export time: Blender's Cycles renderer
bakes each divergent material's node graph into flat PBR textures (base
color, roughness, metallic, normal, emissive, with occlusion/roughness/
metallic packed into a single ORM texture), so the exported `.untold` asset
matches what you see in Blender's viewport. This happens once, during export
— there is no runtime node-graph evaluation in the engine, so baked materials
cost nothing extra at runtime and still participate in static batching.

## Exporting With Baked Materials

Add `--bake-materials` to either `untoldengine export` or
`untoldengine export-tiles`:

```bash
untoldengine export \
  --input GameData/Models/lamp/lamp.usdz \
  --output GameData/Models/lamp/lamp.untold \
  --bake-materials
```

```bash
untoldengine export-tiles \
  --input GameData/Models/city/city.usdz \
  --output-dir GameData/Models/city/tile_exports \
  --tile-size-x 25 --tile-size-y 10000 --tile-size-z 25 \
  --bake-materials
```

Only materials the exporter detects as divergent from a plain Principled BSDF
are baked; simple materials export through the normal fixed-channel path
unchanged.

### Options

- `--bake-materials`: bake node-graph materials the engine cannot evaluate
  into flat textures.
- `--bake-resolution <pixels>`: fallback square resolution for baked textures,
  defaults to `1024`. Each material's actual resolution is normally
  auto-detected from the largest source texture feeding it (rounded up to a
  power of two, never below this fallback) — the flag only matters when a
  material has no source texture to detect from (a procedural or solid-color
  material). Override one material explicitly with a
  `material["untold_bake_resolution"]` custom property in Blender.
- `--no-bake-cache`: disable the persistent bake cache and force every
  divergent material to be re-baked, even if nothing changed since the last
  export.

By default, bakes are cached and reused across exports as long as the source
material hasn't changed, so repeated exports during iteration stay fast.

### Baking Is Per Mesh Instance

If two objects share the same divergent material but have different UVs (or
different bake resolutions via the custom property), each is baked
separately. This produces more textures than baking once per material, but
avoids one object's bake silently overwriting another's under mismatched UVs.

## Loading The Result In The Engine

Baked materials are ordinary PBR materials once exported — nothing about
loading them is different. Load the asset the same way as any other:

```swift
setEntityMeshAsync(entityId: entity, filename: "lamp", withExtension: "untold")
```

There is no separate "baked material" runtime type or API. The baked textures
are referenced from the material the same way `updateMaterialTexture` and
`getMaterialTextureURL` describe in [Using Materials](UsingMaterials.md); you
can still read/override individual channels at runtime like any other
material.

## Notes

- Baking only affects material channels (base color, roughness, metallic,
  normal, emissive/ORM). It does not affect scene-wide color management —
  see [Using Color Management](UsingColorManagement.md) for baking the
  scene's View Transform/Look/Exposure/Gamma into a display LUT.
- Baking requires Blender's Cycles renderer and runs during export, so it
  adds to export time for scenes with many divergent materials. Use the bake
  cache (default on) to keep iteration fast.
- See [Using the Exporter](UsingTheExporter.md) for the full flag reference
  shared by `export` and `export-tiles`.
