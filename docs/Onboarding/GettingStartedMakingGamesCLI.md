# Getting Started Making Games — CLI

This guide takes you from nothing installed to a running app with a cube you
can move in code, using the `untoldengine` command-line tool. Use this path
if you prefer the terminal over a GUI, or want to script/automate project
creation.

> Prefer a visual workflow? See
> [Getting Started Making Games — Editor](GettingStartedMakingGamesEditor.md)
> instead. Both paths produce the same kind of Xcode project; this one just
> uses the CLI to create it and the Editor only to place the cube (or you can
> skip the Editor entirely and add the cube in code).

## Requirements

- macOS 26 or newer
- Swift 6 / Xcode 26 or newer
- Apple Silicon Mac
- Supported platforms: macOS, iOS, and visionOS

## 1. Install the CLI

Clone the engine repository and run the installer script from its root:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
./scripts/install-untoldengine-create.sh
```

This builds `untoldengine` with Swift Package Manager and copies it to
`/usr/local/bin`. Verify it's on your `PATH`:

```bash
untoldengine --help
```

If it's not found, add `/usr/local/bin` to your shell profile:

```bash
# ~/.zshrc or ~/.bashrc
export PATH="/usr/local/bin:$PATH"
```

See [Using the Untold Engine CLI](../API/UsingUntoldEngineCLI.md) for
installer troubleshooting and the full flag reference.

## 2. Create a project

Run `create` from the parent directory where you want the project folder:

```bash
cd ~/Projects
untoldengine create MyGame --platform visionos
```

This scaffolds `MyGame/` with its own `Package.swift` depending on Untold
Engine, a `GameData/` asset folder, and a starter `Sources/MyGame/GameScene.swift`.
This guide uses `visionos` so it carries straight into
[Building Your First Vision Pro Scene](BuildingYourFirstVisionProScene.md) —
swap `--platform` for `macos`, `ios`, `ios-ar`, or `multi` if you're
targeting something else — see the platform table in the
[CLI reference](../API/UsingUntoldEngineCLI.md#platform-options).

## 3. Get a cube into the scene

You have two options here:

**Option A — add the cube in code.** Skip the Editor and create the cube
directly in `GameScene.swift` (see step 4).

**Option B — place the cube visually.** Download the
[Untold Editor](https://github.com/untoldengine/UntoldEditor/releases), open
your `MyGame` project folder, drag a **Cube** primitive from the Asset
Browser's Primitives shelf into the viewport, rename it to `Cube` in the
Inspector, and save the scene (**Cmd+S**) as `GameData/Scenes/MyScene.untoldscene`.

## 4. Reference the cube and move it in code

Open `MyGame.xcodeproj` and edit `Sources/MyGame/GameScene.swift`.

If you placed the cube with the Editor (Option B), load the scene and look
it up by name:

```swift
// In init(), after configureEngineSystems()
loadUntoldScene(named: "MyScene") { success in
    guard success else { return }
    if let cube = findEntity(name: "Cube") {
        // Move it 5 units out in front, once, at load time
        translateBy(entityId: cube, position: simd_float3(0, 0, 5))
    }
    setSceneReady(success)
}

// In your per-frame update
func update(deltaTime: Float) {
    guard isSceneReady(), let cube = findEntity(name: "Cube") else { return }
    // Spin it in place at 90°/sec
    rotateBy(entityId: cube, angle: 90 * deltaTime, axis: simd_float3(0, 1, 0))
}
```

If you're skipping the Editor (Option A), build the cube procedurally with
`BasicPrimitives` instead of loading an asset:

```swift
// In init(), after configureEngineSystems()
let cube = createEntity()
setEntityMeshDirect(entityId: cube, meshes: BasicPrimitives.createCube(), assetName: "Cube")
setEntityName(entityId: cube, name: "Cube")
translateBy(entityId: cube, position: simd_float3(0, 0, 5))
setSceneReady(true)

// In your per-frame update
func update(deltaTime: Float) {
    guard isSceneReady(), let cube = findEntity(name: "Cube") else { return }
    rotateBy(entityId: cube, angle: 90 * deltaTime, axis: simd_float3(0, 1, 0))
}
```

`findEntity(name:)` resolves a name back into an `EntityID` you can drive
with the [Transform System](../API/UsingTransformSystem.md) — `translateBy`,
`translateTo`, `rotateBy`, `rotateTo`, and so on.

## 5. Run it

Press **Run** in Xcode. You should see the cube sitting 5 units out in front,
spinning in place.

## Where to go next

- [Building Your First Vision Pro Scene](BuildingYourFirstVisionProScene.md) — loading your
  own `.untold` assets, streamed scenes, and remote manifests
- [Tutorials](https://untoldengine.github.io/UntoldEngine/Tutorials/) —
  lighting, rendering quality, exporter workflows, XR input
- [Using the Untold Engine CLI](../API/UsingUntoldEngineCLI.md) — exporting
  assets, asset packs, LOD baking, and more

If your team is evaluating Untold Engine and needs an engine capability that
is not currently available, see
[Commercial Use, Sponsored Features, and Support](../../COMMERCIAL.md).
