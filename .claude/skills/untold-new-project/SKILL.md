---
name: untold-new-project
description: Use when the user wants to start a new Untold Engine project, scaffold a game/app, or asks "how do I create a new project with Untold Engine" for macOS, iOS, iOS AR, or visionOS. Covers installing the CLI, running `untoldengine create`, understanding the generated project layout and GameData folder, and wiring the first scene. Not for working inside this engine repo itself (see CLAUDE.md §0), and not for entity/scene editing in an existing project (see untold-entity-scene).
version: 0.1.0
---

# Starting a New Untold Engine Project

A new project is created by the `untoldengine` CLI, a separate tool packaged under `Tools/UntoldEngineCLI` in the engine repo (local path dependency, so it never adds dependencies to the apps it scaffolds). There is also a GUI editor (`untoldengine studio`) that does the same scaffolding visually — mention it exists, but default to the CLI path unless the user asks for the editor.

## 1. Make sure the CLI is installed

```bash
cd <path-to-UntoldEngine-repo>
./scripts/install-untoldengine-create.sh     # builds release, installs to /usr/local/bin/untoldengine
untoldengine --help                          # sanity check
```

**Gotcha**: the installed binary is a built snapshot, not a symlink to source. If the user has been editing `Tools/UntoldEngineCLI/Sources/...`, rerun the install script before testing `untoldengine` — otherwise you're testing stale behavior.

## 2. Determine the target platform

Ask if not already clear (don't guess): `macos`, `ios`, `ios-ar`, `visionos`, or `multi` (macOS + iOS + visionOS in one package). This materially changes the generated lifecycle code — see `CLAUDE.md` §5 Platform-Specific Considerations in the engine repo for what each implies at runtime.

## 3. Scaffold the project

```bash
mkdir MyGame && cd MyGame
untoldengine create MyGame --platform visionos \
  --bundle-id com.company.mygame \
  --team-id ABCD1234EF
```

Useful flags: `--output <path>` (default cwd), `--macos-version {13,14,15}`, `--ios-version {16,17,18}`, `--visionos-version {1,2}`, `--optimization {none,speed,size}`, `--debug/--no-debug`. Full reference: `docs/API/UsingUntoldEngineCLI.md` in the engine repo.

## 4. Know the generated layout

```
MyGame/
├── Package.swift
└── Sources/MyGame/
    ├── AppDelegate.swift      # app lifecycle (macOS/iOS) or ImmersiveSpace glue (visionOS)
    ├── GameScene.swift        # <- application code goes here
    ├── GameViewController.swift (iOS/ios-ar)
    └── GameData/              # bundled at build time, copied verbatim into the app
        ├── Scenes/            # .untoldscene files
        ├── Scripts/           # USC (.uscript) files
        ├── Models/            # .untold meshes, one subfolder per asset
        ├── StreamModels/      # tile-streamed geometry (large scenes)
        ├── Animations/        # .untoldanim clips
        ├── Gaussians/         # .untoldgs Gaussian-splat payloads
        ├── Textures/
        ├── Shaders/
        └── LUT/               # color-grading 3D LUTs
```

`GameData` lives at the project root today. If you encounter an older project with `GameData` nested under `Sources/<Project>/GameData`, run `untoldengine convert MyGame` to migrate it — don't manually move files. Full detail: `docs/API/UsingAssetPaths.md`.

Later, to refresh only the generated content (new assets, not your code):

```bash
untoldengine update MyGame --asset-path ~/GameAssets
```

## 5. Wire the first scene

Edit `Sources/MyGame/GameScene.swift` following the free-function idiom (not OOP). The canonical minimal example is `Sources/Demos/StarterDemo/GameScene.swift` in the engine repo:

- Set up a camera: `createGameCamera(entityId:)` or the demo's `makeDemoCamera`-style wrapper, pointed with `cameraLookAt(eye:target:up:)`.
- Add a light: `createDirLight(...)` for a key/sun light at minimum.
- Add content: `createEntity()` + `setEntityMeshDirect`/`setEntityMeshAsync` + `translateTo`.
- Call `setSceneReady(true)` once the initial state is in place — other systems gate on `isSceneReady()`.

See the `untold-entity-scene` skill for the full per-entity API surface once the project shell exists.

**Platform divergence to flag explicitly:**
- macOS/iOS: `AppDelegate` hosts an engine-owned `UntoldRenderer`/`SceneView` (MTKView-backed). You never write your own render loop.
- visionOS: there's no `MTKView`. The app drives an `ImmersiveSpace`/`CompositorLayer` and hands the `LayerRenderer` to `UntoldEngineXR`, which runs its own frame loop. See `docs/Onboarding/BuildingYourFirstVisionProScene.md` and `docs/API/UsingXRImmersionMode.md` before writing visionOS lifecycle code — don't port macOS AppDelegate patterns over.

## 6. Verify

```bash
cd MyGame
swift build
swift run MyGame          # macOS only; iOS/visionOS need Xcode + a simulator or device
```

Don't report project creation as "done" without a successful build.
