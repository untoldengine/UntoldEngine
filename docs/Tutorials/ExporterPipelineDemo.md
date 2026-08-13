# Exporter Pipeline Demo

The Exporter Pipeline Demo shows how exported `.untold` assets are loaded,
validated, and animated at runtime. It focuses on the handoff between the asset
pipeline and the engine API.

Run it from the repository root:

```bash
swift run ExporterPipelineDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/ExporterPipelineDemo/AppDelegate.swift` | Presents asset, animation, reset, and validation UI. |
| `Sources/Demos/ExporterPipelineDemo/GameScene.swift` | Loads exported assets, applies transforms, loads animation clips, and reports pipeline status. |
| `Sources/Demos/DemoUtils/DemoUtils.swift` | Provides shared resource, camera, light, and input helpers. |

## What This Demo Teaches

The main runtime asset API is:

```swift
setEntityMeshAsync(entityId: entity, filename: "redplayer", withExtension: "untold") { success in
    setSceneReady(success)
}
```

Use it for always-resident assets such as characters, props, vehicles, or small
environment pieces. The completion handler runs after the mesh has been parsed
and registered with the engine.

## Asset Options

The demo presents three exported assets:

```swift
enum ExportedAssetOption: String, CaseIterable, Identifiable {
    case stadium
    case redplayer
    case ball
}
```

The enum keeps UI labels, default scale, and animation support close to the
asset selection:

```swift
var supportsAnimation: Bool {
    self == .redplayer
}

var defaultScale: simd_float3 {
    switch self {
    case .ball: simd_float3(repeating: 0.8)
    default: simd_float3(repeating: 1.0)
    }
}
```

This is demo-side organization. The engine only needs an entity ID, a filename,
an extension, and a completion handler.

## Loading An Exported Asset

Before loading a new asset, the demo marks the scene not ready and destroys the
previous entity:

```swift
setSceneReady(false)

if let loadedEntity {
    destroyEntity(entityId: loadedEntity)
    self.loadedEntity = nil
}
```

Then it creates a new entity and loads the selected `.untold` file:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: option.title)
setEntityMeshAsync(entityId: entity, filename: option.rawValue, withExtension: "untold") { success in
    if success {
        loadedEntity = entity
        translateTo(entityId: entity, position: .zero)
        scaleTo(entityId: entity, scale: option.defaultScale)
    }

    setSceneReady(success)
}
```

For assets that need import-orientation correction, apply transforms after the
mesh load succeeds:

```swift
if option == .stadium {
    rotateTo(entityId: entity, angle: -90.0, axis: simd_float3(1.0, 0.0, 0.0))
}
```

## Runtime Animation Loading

The demo has two animation clips:

```swift
enum ExportedAnimationOption: String, CaseIterable, Identifiable {
    case idle
    case running
}
```

Animation is loaded onto the already-loaded entity:

```swift
setEntityAnimations(
    entityId: loadedEntity,
    filename: option.rawValue,
    withExtension: "untold",
    name: option.rawValue
)
changeAnimation(entityId: loadedEntity, name: option.rawValue)
```

`setEntityAnimations(...)` registers the clip under a name. `changeAnimation(...)`
starts playback of that named clip.

The demo only applies these clips when the selected asset supports them:

```swift
guard let loadedEntity, loadedAsset?.supportsAnimation == true else {
    status.message = "Selected asset does not support the demo animations."
    return
}
```

In your own project, use the same kind of guard when a UI can select assets with
different capabilities.

## Querying Loaded Clips

After loading an animation, the demo queries the entity for available clips:

```swift
let clips = getAllAnimationClips(entityId: loadedEntity).sorted()
status.animationClips = clips.isEmpty ? "None" : clips.joined(separator: ", ")
```

This is useful for debugging imported animation assets. It also gives tooling a
simple way to show what clips are available on an entity.

## Validation Metadata

When exported with validation enabled, assets can have a sidecar
`<asset>.validation.json` file. The demo reads that file with standard Swift
file APIs:

```swift
let data = try? Data(contentsOf: url)
let decoded = try? JSONDecoder().decode(ValidationFile.self, from: data)
```

This is not an engine runtime requirement. It is a pipeline diagnostic that helps
confirm what the exporter produced:

- asset name
- mesh count
- total vertices
- total indices

## API Pattern To Remember

For a normal exported model:

```swift
setSceneReady(false)

let entity = createEntity()
setEntityName(entityId: entity, name: "Red Player")
setEntityMeshAsync(entityId: entity, filename: "redplayer", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    translateTo(entityId: entity, position: .zero)
    setSceneReady(true)
}
```

For an animated exported model:

```swift
setEntityAnimations(entityId: entity, filename: "idle", withExtension: "untold", name: "idle")
setEntityAnimations(entityId: entity, filename: "running", withExtension: "untold", name: "running")
changeAnimation(entityId: entity, name: "idle")
```

## What To Change First

Try these changes in `Sources/Demos/ExporterPipelineDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Load a different default asset | Change the `loadAsset(...)` call in `init()`. |
| Add another asset option | Add a case to `ExportedAssetOption` and provide a matching `.untold` file. |
| Change default placement | Edit `translateTo(...)`, `scaleTo(...)`, or `rotateTo(...)` after load success. |
| Add an animation clip | Add a case to `ExportedAnimationOption`, call `setEntityAnimations(...)`, then `changeAnimation(...)`. |
| Show more validation data | Extend `ValidationSummary` and decode more fields from the validation JSON. |

## Related Documentation

- [Exporter](../API/UsingTheExporter.md)
- [Animation System](../API/UsingAnimationSystem.md)
- [Registration System](../API/UsingRegistrationSystem.md)
- [Async Loading](../API/UsingAsyncLoading.md)
- [Optimizations](../API/Optimizations.md)

