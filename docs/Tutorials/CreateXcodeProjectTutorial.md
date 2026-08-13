# Create A New Xcode Project

This tutorial shows how to create a standalone Xcode project that uses Untold
Engine as a dependency. Use this when you are ready to leave the engine
repository demos and start your own app.

The project is generated with the `untoldengine` CLI.

## Install The CLI

From the Untold Engine repository root:

```bash
./scripts/install-untoldengine-create.sh
```

The installer builds the CLI and places `untoldengine` on your `PATH`.

Verify it is available:

```bash
untoldengine --help
```

If your shell cannot find the command, make sure `/usr/local/bin` is on your
`PATH`.

## Create A Project

Run the command from the parent directory where you want the project folder to
be created:

```bash
cd ~/Projects
untoldengine create VisionGame --platform visionos
open VisionGame/VisionGame.xcodeproj
```

The CLI creates a ready-to-run Xcode project with the correct Untold Engine
dependency for the selected platform.

## Platform Options

```bash
# visionOS / Apple Vision Pro
untoldengine create MyGame --platform visionos

# macOS
untoldengine create MyGame --platform macos

# iOS with ARKit
untoldengine create MyGame --platform ios-ar

# iOS
untoldengine create MyGame --platform ios

# macOS + iOS + visionOS
untoldengine create MyGame --platform multi --team-id ABCD1234EF
```

Dependency behavior:

| Platform | Engine Products |
| --- | --- |
| `visionos` | `UntoldEngineXR` + `UntoldEngineAR` |
| `ios-ar` | `UntoldEngineAR` |
| `ios` | `UntoldEngine` |
| `macos` | `UntoldEngine` |
| `multi` | platform-specific targets for macOS, iOS, and visionOS |

Use `--bundle-id` and `--team-id` when you need explicit signing settings:

```bash
untoldengine create VisionGame \
  --platform visionos \
  --bundle-id com.example.visiongame \
  --team-id ABCD1234EF
```

## Generated Structure

A generated project includes source files and a bundled `GameData` folder:

```text
MyGame/
  Package.swift
  README.md
  Sources/
    MyGame/
      AppDelegate.swift
      GameScene.swift
      GameData/
        Scenes/
        Scripts/
        Models/
        StreamModels/
        Animations/
        Gaussians/
        Textures/
        Shaders/
```

`GameScene.swift` is where your engine scene setup usually begins. `GameData` is
where runtime assets live. The generated project points the engine asset base
path at the bundled `GameData` directory.

## Install Starter Assets

After creating a project, install a starter asset pack:

```bash
cd ~/Projects/MyGame
untoldengine assets install starter-archviz
```

The CLI auto-detects the project's `GameData` folder and merges the asset pack
into it.

List available packs:

```bash
untoldengine assets list
```

Install into a specific `GameData` path:

```bash
untoldengine assets install starter-archviz \
  --output ~/Projects/MyGame/Sources/MyGame/GameData
```

## Load A Single Asset

Place always-resident models under:

```text
Sources/MyGame/GameData/Models/<AssetName>/<AssetName>.untold
```

Then load the asset from `GameScene.swift`:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: "Bedroom")

setEntityMeshAsync(entityId: entity, filename: "Bedroom", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    translateTo(entityId: entity, position: .zero)
    setSceneReady(true)
}
```

Use `setEntityMeshAsync(...)` for props, characters, and models that should stay
resident for the lifetime of the scene.

## Load Scene-Authored Data

If the exported asset includes Blender-authored lights, cameras, or baked color
management, load that data explicitly:

```swift
loadSceneAuthored(filename: "Bedroom", withExtension: "untold") { authoredLoaded in
    // Scene-authored lights/cameras and color LUT are now registered.
}
```

Normal mesh loading only loads geometry and materials. Scene-authored data is a
separate step.

## Load A Streamed Scene

Place streamed scene manifests and tile payloads under:

```text
Sources/MyGame/GameData/StreamModels/<SceneName>/
  <SceneName>.json
  tile_exports/
```

Then load the manifest:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "City")

setEntityStreamScene(entityId: sceneRoot, manifest: "City", withExtension: "json") { success in
    setSceneReady(success)
}
```

Use `setEntityStreamScene(...)` for large scenes that should load and unload
geometry based on camera distance.

## Related Documentation

- [Untold Engine CLI](../API/UsingUntoldEngineCLI.md)
- [Getting Started](../API/GettingStarted.md)
- [Async Loading](../API/UsingAsyncLoading.md)
- [Geometry Streaming](../API/UsingGeometryStreamingSystem.md)
- [Export Assets With The CLI](CLIExporterTutorial.md)

