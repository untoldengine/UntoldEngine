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
USD/USDZ asset, a `.blend` file, or a Gaussian `.ply` splat capture:

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

### Multi-model `.blend` scenes → `.untoldpack`

If the source `.blend` scene contains more than one independent model (more
than one object with no parent among the exported objects), the exporter
writes a `<name>.untoldpack` manifest next to `--output` instead of a single
`.untold` file, plus one self-contained `.untold` per model under its own
subfolder:

```bash
untoldengine export \
  --input warehouse.blend \
  --output warehouse.untold \
  --convert-orientation --optimize
# → warehouse.untoldpack, Shelf/Shelf.untold, Forklift/Forklift.untold, ...
```

`--optimize` bakes textures for every model in the pack. Load the result with
`setEntityMeshAsync(entityId:filename:withExtension:)` using `"untoldpack"` —
the engine loads a pack the same way it loads a single `.untold`, placing
each model as a child entity. See [Using the Registration
System](UsingRegistrationSystem.md).

Re-exporting the same `--output` path after the scene's model count changes
(single ↔ multiple) automatically removes the previous run's now-stale
`.untold`/`.untoldpack` output, and any model subfolders a shrunk pack no
longer references, so a caller never picks up a leftover file from an older
export by accident.

### Animation-only exports → `.untoldanim`

`--animation` exports clip data only (no mesh geometry) and requires a
`.untoldanim` `--output` path:

```bash
untoldengine export \
  --input running.usdz \
  --output running.untoldanim \
  --convert-orientation --animation
```

`.untoldanim` is a plain `.untold` container under the hood, named distinctly
so it's never mistaken for a mesh — `setEntityMeshAsync` rejects it; load it
with `setEntityAnimations(entityId:filename:withExtension:name:)` instead.

### Gaussian splats → `.untoldgs`

Gaussian `.ply` inputs skip Blender entirely and export straight to
`.untoldgs`:

```bash
# Single tier
untoldengine export --input splats.ply --output splats.untoldgs

# Progressive LOD tiers (splats_lod0.untoldgs, splats_lod1.untoldgs, ...)
untoldengine export --input splats.ply --output splats.untoldgs --lod-levels 4
```

### Other export flags

| Flag | Description |
|---|---|
| `--mesh-name <name>` | Export only one mesh from a multi-mesh asset |
| `--file-type <tile\|lod\|hlod\|shared\|animation>` | Untold file type (default `tile`) |
| `--source-orientation <blender-native\|engine-oriented>` | Input orientation |
| `--compress-geometry` | LZ4-compress vertex/index chunks |
| `--validate` | Write a companion validation JSON file |
| `--color-grade-lut <path>` | Stage an externally-authored `.cube` 3D LUT and apply it as a post-tonemap creative grade (no Blender render, no conversion) — see [Using Color Management](UsingColorManagement.md) |

Run `untoldengine export --help` for the full, current flag list.

---

### Gaussian splat captures

A Gaussian splat `.ply` exports directly to `.untoldgs` (see [Gaussian Splat
Format](../Architecture/untoldgsFormat.md)); `--lod-levels N` writes progressive tiers.
The `--splat-*` flags cook the capture on the way: register it onto its mesh twin, crop
away floaters and the captured floor, drop near-transparent splats, and choose the
spherical-harmonics degree and chunk size.

```bash
untoldengine export --input sofa.ply --output Gaussians/sofa.untoldgs \
  --splat-up-axis z --splat-scale 0.5 --splat-yaw-degrees 90 --splat-translate 0,0.4,0 \
  --splat-crop=-1,0,-1,1,1.2,1 --splat-crop-margin 0.05 --splat-sh-degree 2
```

`--splat-up-axis` names the capture's up axis (`y` is the engine convention and the default,
`z` for scanner and CAD exports, `-y` for the 3DGS training convention); the rotation to
Y-up is applied before scale, yaw and translation, and the whole transform is baked into
every splat and recorded in the file header.
`--splat-min-opacity` (default 0.005) drops near-transparent splats; `--splat-chunk-splats`
sets the chunk size (1024 for objects, 4096 with `--splat-environment` for rooms and
larger). Values that start with a minus sign must use the `--option=value` form. The
command prints how many splats were kept and pruned per reason.

`--splat-max-count N` keeps at most N splats, dropping the least important first (opacity
times the geometric mean of the scales). The runtime refuses to load an entity above its
per-platform cap — 20,000,000 splats on Apple Vision Pro, iPhone, iPad and Apple TV,
40,000,000 on the Mac (`GaussianRuntimeLimits`; a `.untoldgs` splat keeps 16 bytes plus its
harmonics resident) — so a large capture that has to load everywhere is cooked with
`--splat-max-count 20000000`; one that only has to run on a Mac can go up to the Mac figure.
What the frame draws is bounded separately by the working-set budget
(`GaussianRuntimeLimits.workingSetSplats`), which fits the visible chunks by quota. Captures
beyond the cap belong to the streamed environment path (part 6 of the series).

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
(`--color-grade-lut` — only applied via an explicit `loadSceneAuthored(url:)`
call, see [Using the
Registration System](UsingRegistrationSystem.md#loading-scene-authored-data)),
tiering
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
