# Asset Paths

## Introduction

Every mesh, animation, texture, and scene a game loads by name — `setEntityMesh(filename: "redplayer", ...)`, `loadUntoldScene(named: "Level1")`, `loadTexture(textureName: "icon", ...)` — has to turn that short name into a real file on disk (or inside the shipped app bundle). That resolution goes through `assetBasePath` and a small, fixed set of conventional folders under it. Knowing that convention is what keeps "why didn't my asset load?" from becoming a debugging session.

## The `GameData` Folder

A project created with the CLI (`untoldengine create`) or Xcode template ships with a `GameData` folder alongside your source:

```
GameData/
├── Scenes/
├── Scripts/
├── Models/
├── StreamModels/
├── Animations/
├── Gaussians/
├── Textures/
└── Shaders/
```

These are the **canonical asset directories** the engine's resource resolver knows about. The project generator creates them for you, and Xcode adds `GameData` as a folder reference — meaning it's copied into the built app **verbatim**, subfolders and all, on macOS, iOS, and visionOS. You don't need to worry about your directory structure surviving into a shipped build.

Where each asset type belongs:

| Folder | What goes there |
|---|---|
| `Scenes/` | `.untoldscene` files |
| `Scripts/` | scripting-system script files |
| `Models/` | `.untold` meshes, one subfolder per asset (e.g. `Models/robot/robot.untold`) |
| `StreamModels/` | tile-streamed geometry (`export-untold-tiles` output) |
| `Animations/` | `.untold` animation clips |
| `Gaussians/` | Gaussian splat assets |
| `Textures/` | standalone textures loaded by name, outside of a material |
| `Shaders/` | custom shader source |

Materials are the one exception: they resolve under `Materials/<subName>/...`, keyed by the material name passed alongside the resource name, rather than a fixed top-level folder.

## `assetBasePath`

`assetBasePath` is the root the resolver searches under — everything in the table above is resolved as `<assetBasePath>/<Folder>/...`. A generated project sets it for you during startup:

```swift
setupAssetPaths()
// or, directly:
setEngine(.assetBasePath(Bundle.main.url(forResource: "GameData", withExtension: nil)!))
```

If you're not using the generated template — a custom host app, or a tool loading assets from a user-chosen folder — set it yourself before loading anything:

```swift
assetBasePath = myGameDataFolderURL
```

## How Resolution Works

Calling an API with a bare resource name (`"redplayer"`, `"icon"`, `"Level1"`) resolves in this order:

1. **Flat root.** `<assetBasePath>/<name>.<ext>` — a fast path for assets dropped directly at the root.
2. **Structured subdirectories.** Each canonical folder in turn: `Models/<name>/<name>.<ext>`, `Textures/<name>.<ext>`, `Scenes/<name>.<ext>`, and so on. This is the path most assets take.
3. **App bundle fallback.** `Bundle.main`, then the engine's own module bundle — covers assets bundled outside `GameData` or engine-internal content.

Scene files get one extra rule ahead of all of this: `loadUntoldScene(named:)` always checks `<assetBasePath>/Scenes/<name>.untoldscene` directly first, so a same-named file that happens to sit elsewhere can never shadow the canonical scene.

Inside a `.untoldscene` file, asset references are stored as **paths relative to `assetBasePath`** (e.g. `Models/ball/ball.untold`), not absolute paths — so a project (and its scenes) can move between machines and Xcode's DerivedData without breaking. The resolver also tolerates absolute paths baked by older tooling or another machine's build directory: if the literal path doesn't exist, it looks for a known folder name (`Models`, `Textures`, `Scenes`, ...) anywhere in that stale path and retries from there under the current `assetBasePath`.

## Tips and Best Practices

- **Put assets in their canonical folder.** The flat-root and bundle-fallback tiers exist as safety nets, not primary storage — an asset outside the structured layout is one refactor away from silently failing to load.
- **Standalone textures go in `Textures/`, not `Materials/`.** `loadTexture(textureName:withExtension:)` passes no material name, so it only ever searches the flat root and the top-level structured folders (including `Textures/`) — never a `Materials/<name>/` subfolder.
- **Materials still key off `subName`.** A texture referenced as part of a material (`subName` set) resolves under `Materials/<subName>/`, independent of the `Textures/` folder.
- **Don't hardcode absolute paths in code or scenes** if you can avoid it. They work as a fallback, but every relative reference is guaranteed to keep resolving after a project move; an absolute one is only guaranteed until the next one.
- If an asset fails to load and you don't see it logged as found, the first thing to check is which canonical folder it's actually sitting in versus where the resolver looks for its type.

## Running the Feature

1. Drop a texture into `GameData/Textures/icon.png`.
2. Call `loadTexture(device:, textureName: "icon", withExtension: "png")`.
3. It resolves without any extra configuration — no material, no `subResource`, just the folder convention.
