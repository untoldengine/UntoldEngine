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
| `--visionos-version` | visionOS deployment target (`1`, `2`) | `2` |
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
