# Using the UntoldEngine CLI

The `untoldengine` CLI tool scaffolds ready-to-run Xcode projects with UntoldEngine pre-configured. Instead of setting up package dependencies and boilerplate by hand, you run one command and get a fully wired project for your target platform.

The install script (`scripts/install-untoldengine-create.sh`) builds the CLI from source and places it in `/usr/local/bin` so it is available globally in your shell.

---

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 6.0 or later

---

## Installation

Clone the repository and run the install script from the repo root:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
./scripts/install-untoldengine-create.sh
```

The script will:

1. Build `untoldengine` in release mode using Swift Package Manager.
2. Copy the binary to `/usr/local/bin` (prompts for admin privileges if needed).
3. Mark it executable.
4. Verify that the tool is reachable on your `PATH`.

If the final verification step warns that `untoldengine` is not found in `PATH`, add `/usr/local/bin` to your shell profile:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="/usr/local/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.zshrc
```

---

## Creating a New Project

Run from the parent directory — the CLI creates the project folder for you:

```bash
cd ~/Downloads
untoldengine create MyGame
```

### Platform Options

| Flag | Target |
|---|---|
| `--platform macos` | macOS (default) |
| `--platform ios` | iOS |
| `--platform ios-ar` | iOS with ARKit |
| `--platform visionos` | visionOS / Apple Vision Pro |
| `--platform multi` | macOS + iOS + visionOS |

```bash
# macOS project (default)
untoldengine create MyGame --platform macos

# iOS project
untoldengine create MyGame --platform ios --bundle-id com.company.mygame

# iOS with ARKit
untoldengine create ARGame --platform ios-ar --bundle-id com.company.argame

# visionOS / Apple Vision Pro
untoldengine create VisionGame --platform visionos

# Multi-platform (macOS, iOS, visionOS) — Team ID required for signing
untoldengine create CrossGame --platform multi --team-id ABCD1234EF
```

### All Options

| Option | Description | Default |
|---|---|---|
| `--platform` | Target platform | `macos` |
| `--bundle-id` | Bundle identifier | — |
| `--output` | Output directory | current directory |
| `--macos-version` | macOS deployment target (`13`, `14`, `15`) | `15` |
| `--ios-version` | iOS deployment target (`16`, `17`, `18`) | `17` |
| `--visionos-version` | visionOS deployment target (`1`, `2`, `26`) | `2` |
| `--team-id` | Apple Developer Team ID | — |
| `--optimization` | Optimization level (`none`, `speed`, `size`) | `none` |
| `--debug / --no-debug` | Include debug information | yes |

---

## Updating an Existing Project

The `update` command refreshes only the `GameData` folder in an existing project, leaving your custom code untouched:

```bash
untoldengine update MyGame --asset-path ~/GameAssets

# Or point to an absolute project path
untoldengine update ~/Projects/MyGame --asset-path ~/GameAssets
```

---

## Bootstrapping Dependencies

Some optimizations (ASTC texture compression) rely on external tools and
Python packages. Install them once with:

```bash
untoldengine bootstrap
```

This downloads and verifies a pinned `astcenc` into `~/.untoldengine/tools`
and installs the `Pillow`/`lz4` Python packages, so `untoldengine export
--optimize` and `untoldengine texbake` find everything automatically. See
[Optimizations](Optimizations.md) for details.

---

## Exporting Assets

Run the exporter from the game project or any other directory. Input can be a
USD/USDZ asset or a `.blend` file:

```bash
untoldengine export \
  --input /path/to/model.usdz \
  --output /path/to/model.untold \
  --convert-orientation \
  --optimize
```

`--optimize` compresses geometry and, if the asset has textures, bakes and
patches them to `.utex` — equivalent to running `--compress-geometry`
followed by `untoldengine texbake --dir` and `--patch-refs`. See
[Optimizations](Optimizations.md) for what each flag does.

Use `--blender /path/to/Blender` when Blender is not installed in its standard
macOS location and is not available on `PATH`.

---

## Partitioning Scenes into Streaming Tiles

For large outdoor scenes, `export-tiles` partitions a USD/USDZ/`.blend` scene into
per-tile `.untold` payloads plus a manifest, for use with the [geometry
streaming system](UsingGeometryStreamingSystem.md):

```bash
untoldengine export-tiles \
  --input scene.usdz \
  --output-dir tile_exports \
  --tile-size-x 25 --tile-size-z 25 \
  --optimize
```

`--optimize` compresses geometry and, if the export produced a shared
`Textures` directory, bakes those textures to `.utex` and patches every
tile's `.untold` references. Grid, quadtree, and KD-tree partitioning modes
are available (`--quadtree`, `--kdtree`); run `untoldengine export-tiles
--help` for the full flag list, including color management
(`--bake-color-management`, `--color-lut-size` — only applied via an explicit
`loadSceneAuthored(url:)` call, see [Using the Registration
System](UsingRegistrationSystem.md#loading-scene-authored-data)), tiering
(`--min-objects-per-tile-tier`,
`--untagged-semantic-tier`), LOD/HLOD (`--lod-level`, `--hlod-level`), and
sampling (`--sample`, `--sample-fraction`, `--perimeter`, `--perimeter-depth`)
options.

---

## Managing Asset Packs

```bash
# List available asset packs
untoldengine assets list

# Install a pack into the current project's GameData folder
untoldengine assets install starter

# Install into a specific GameData path, overwriting existing files
untoldengine assets install soccer --output ~/Projects/MyGame/Sources/MyGame/GameData --force
```

`assets install` auto-detects the `GameData` folder from the current
directory, or use `--output` to point at it explicitly.

---

## Untold Engine Studio (Visual Editor)

```bash
# Launch the editor, installing it first if missing
untoldengine studio

# Install the latest release explicitly
untoldengine studio install

# Install a specific version
untoldengine studio install --version 0.13.0

# Update an existing install to the latest release
untoldengine studio update
```

`studio install` downloads the editor from GitHub releases into
`/Applications` (or `~/Applications` if `/Applications` isn't writable).

---

## Packaging the Blender Add-on

```bash
untoldengine blender-addon
```

Run from the UntoldEngine repository root. This bundles the add-on source
with fresh vendored copies of the exporter scripts (`untoldexplorer.py`,
`texbake.py`, `tilestreamingpartition.py`) into
`scripts/untold-blender-addon/build/untold_exporter.zip`. This is an
engine-repo maintenance tool, not something a game project needs to run.

---

## Generated Project Structure

```
MyGame/
├── Package.swift
├── README.md
└── Sources/
    └── MyGame/
        ├── AppDelegate.swift
        ├── GameScene.swift
        ├── GameViewController.swift
        ├── Base.lproj/
        │   └── Main.storyboard
        ├── Info.plist
        └── GameData/
            ├── Scenes/
            ├── Scripts/
            ├── Models/
            ├── Textures/
            └── Shaders/
```

The starter `GameScene.swift` shows how to load `.untold` runtime assets, use `setEntityStreamScene(...)` for streamed scenes, and enable static batching.

> **Note:** Runtime examples expect `.untold` assets. Convert USD/USDZ authoring files with the exporter before placing them in `GameData/Models/`.

---

## Engine Dependencies by Platform

The generated `Package.swift` pulls in only the engine modules needed for your platform:

| Platform | Engine modules |
|---|---|
| `macos` / `ios` | `UntoldEngine` |
| `ios-ar` | `UntoldEngineAR` |
| `visionos` | `UntoldEngineXR` + `UntoldEngineAR` |
| `multi` | `UntoldEngine` + `UntoldEngineXR` + `UntoldEngineAR` |

---

## Opening the Project

After `create` finishes, open the generated Xcode project:

```bash
open MyGame.xcodeproj
```

Select your scheme and press **Run**.
