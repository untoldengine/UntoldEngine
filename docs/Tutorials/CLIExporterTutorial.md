# Export Assets With The CLI

This tutorial shows how to export your own assets with the `untoldengine` CLI
and where to place the resulting files inside a generated Xcode project.

Use the CLI when you want a repeatable terminal workflow. Use the Blender add-on
when you want a visual Blender export workflow.

## Project Asset Layout

Generated projects bundle runtime assets from:

```text
Sources/<ProjectName>/GameData/
  Models/
  StreamModels/
  Animations/
  Gaussians/
  Textures/
  HDR/
  Shaders/
```

The common runtime paths are:

| Asset Type | Recommended Location |
| --- | --- |
| Single models | `GameData/Models/<AssetName>/<AssetName>.untold` |
| Animation clips | `GameData/Animations/<ClipName>/<ClipName>.untold` |
| Streamed scenes | `GameData/StreamModels/<SceneName>/<SceneName>.json` plus `tile_exports/` |
| Shared textures | beside the exported `.untold` asset or under `GameData/Textures/` |
| HDR environments | `GameData/HDR/<Environment>.hdr` |

The engine resolves filenames through the project's configured `GameData`
directory, so examples usually pass only the filename stem:

```swift
setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold")
```

## Install Export Dependencies

Install the CLI first:

```bash
./scripts/install-untoldengine-create.sh
```

If you plan to optimize textures or geometry, bootstrap the external tools once:

```bash
untoldengine bootstrap
```

This installs the pinned `astcenc` texture compressor and required Python
packages used by optimization workflows.

## Export A Single Model

From any directory:

```bash
untoldengine export \
  --input /path/to/robot.usdz \
  --output ~/Projects/MyGame/Sources/MyGame/GameData/Models/robot/robot.untold \
  --convert-orientation
```

`.blend` input works too:

```bash
untoldengine export \
  --input /path/to/robot.blend \
  --output ~/Projects/MyGame/Sources/MyGame/GameData/Models/robot/robot.untold \
  --convert-orientation
```

Load it in `GameScene.swift`:

```swift
let robot = createEntity()
setEntityName(entityId: robot, name: "Robot")

setEntityMeshAsync(entityId: robot, filename: "robot", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    translateTo(entityId: robot, position: .zero)
    setSceneReady(true)
}
```

## Add Validation

Use `--validate` while building an asset pipeline:

```bash
untoldengine export \
  --input /path/to/robot.usdz \
  --output ~/Projects/MyGame/Sources/MyGame/GameData/Models/robot/robot.untold \
  --convert-orientation \
  --validate
```

This writes a sidecar validation JSON file next to the exported asset. It is not
required at runtime, but it is useful for checking mesh counts, vertex counts,
and export results.

## Optimize The Export

Run bootstrap once:

```bash
untoldengine bootstrap
```

Then export with optimization:

```bash
untoldengine export \
  --input /path/to/robot.usdz \
  --output ~/Projects/MyGame/Sources/MyGame/GameData/Models/robot/robot.untold \
  --convert-orientation \
  --optimize
```

`--optimize` compresses geometry and, when textures are present, bakes and
patches textures to `.utex`.

The exporter only reads a fixed set of material inputs (base color,
roughness, metallic, normal, emissive). If a Blender material uses node
graphs the runtime cannot evaluate directly (`Mix`, `Math`, procedural
textures, ...), bake it to flat textures with a third-party tool before
export so the imported result matches what you see in Blender.

## Export Animation Clips

Export animation-only `.untold` files with `--animation`:

```bash
untoldengine export \
  --input /path/to/running.usdz \
  --output ~/Projects/MyGame/Sources/MyGame/GameData/Animations/running/running.untold \
  --convert-orientation \
  --animation
```

Register clips on the loaded character:

```swift
setEntityAnimations(entityId: character, filename: "idle", withExtension: "untold", name: "idle")
setEntityAnimations(entityId: character, filename: "running", withExtension: "untold", name: "running")
changeAnimation(entityId: character, name: "idle")
```

Keep clip names simple and consistent. The `name` argument is the runtime handle
used by `changeAnimation(...)`.

## Export Color Management

If the scene should match Blender's View Transform, Look, Exposure, and Gamma,
export a baked color LUT:

```bash
untoldengine export \
  --input /path/to/office.blend \
  --output ~/Projects/MyGame/Sources/MyGame/GameData/Models/office/office.untold \
  --convert-orientation \
  --bake-color-management
```

Load scene-authored data after the mesh:

```swift
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Baked color management and authored scene data are registered.
}
```

`setEntityMeshAsync(...)` does not load the baked LUT by itself.

## Export A Streamed Scene

For large scenes, export a manifest and tile payloads into `GameData/StreamModels`:

```bash
untoldengine export-tiles \
  --input /path/to/city.usdz \
  --output-dir ~/Projects/MyGame/Sources/MyGame/GameData/StreamModels/City/tile_exports \
  --tile-size-x 25 \
  --tile-size-z 25 \
  --generate-hlod \
  --generate-lod \
  --optimize
```

Expected layout:

```text
GameData/
  StreamModels/
    City/
      City.json
      tile_exports/
        tile_0_0_0.untold
        tile_0_0_1.untold
        Textures/
```

Load the manifest:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "City")

setEntityStreamScene(entityId: sceneRoot, manifest: "City", withExtension: "json") { success in
    setSceneReady(success)
}
```

For remote hosting, upload the manifest folder and pass a URL:

```swift
setEntityStreamScene(entityId: sceneRoot, url: manifestURL) { success in
    setSceneReady(success)
}
```

## Choose Partitioning

Use a uniform grid for simple outdoor scenes:

```bash
untoldengine export-tiles \
  --input /path/to/site.usdz \
  --output-dir ~/Projects/MyGame/Sources/MyGame/GameData/StreamModels/Site/tile_exports \
  --tile-size-x 25 \
  --tile-size-z 25
```

Use quadtree for multi-floor buildings:

```bash
untoldengine export-tiles \
  --input /path/to/building.usdz \
  --output-dir ~/Projects/MyGame/Sources/MyGame/GameData/StreamModels/Building/tile_exports \
  --quadtree \
  --scene-profile indoor
```

Use KD-tree when geometry is clustered unevenly:

```bash
untoldengine export-tiles \
  --input /path/to/building.usdz \
  --output-dir ~/Projects/MyGame/Sources/MyGame/GameData/StreamModels/Building/tile_exports \
  --kdtree \
  --scene-profile indoor
```

## Common Mistakes

| Problem | Fix |
| --- | --- |
| Asset does not load | Confirm the `.untold` file is under `Sources/<ProjectName>/GameData/Models/<name>/`. |
| Animation does not play | Confirm the clip was exported with `--animation` and registered with `setEntityAnimations(...)`. |
| Blender look does not match | Export with `--bake-color-management` and call `loadSceneAuthored(...)`. |
| Tiled scene does not stream | Confirm the manifest is under `GameData/StreamModels/<SceneName>/` and tile paths are relative to it. |
| Optimized export fails | Run `untoldengine bootstrap`, then rerun the export. |

## Related Documentation

- [Exporter](../API/UsingTheExporter.md)
- [Untold Engine CLI](../API/UsingUntoldEngineCLI.md)
- [Create A New Xcode Project](CreateXcodeProjectTutorial.md)
- [Blender Add-On Workflow](BlenderAddonTutorial.md)
- [Materials, Textures, And Color Management](MaterialsPipelineTutorial.md)
- [Geometry Streaming](../API/UsingGeometryStreamingSystem.md)

