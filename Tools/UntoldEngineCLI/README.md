# UntoldEngine CLI

Command-line tool for creating UntoldEngine game projects.

## Overview

The `untoldengine-create` CLI tool allows you to scaffold new game projects using UntoldEngine from the terminal. This is an optional tool - you can also create projects using the Untold Editor GUI.

## Requirements

- macOS 14.0 or later
- Swift 6.0 or later
- Xcode 15.0 or later (for building)

## Installation

### Recommended: Use the Install Script

From the repository root:

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine

# Run the install script
./scripts/install-create.sh
```

This will build the CLI in release mode and install it to `/usr/local/bin`, making it available globally.

### Alternative: Manual Build

If you prefer to build manually from this directory (`Tools/UntoldEngineCLI`):

```bash
# Debug build
swift build

# Release build
swift build -c release
```

## Usage

### After Installation

Once installed using the script, you can use `untoldengine-create` from anywhere:

```bash
# Show help
untoldengine-create --help

# Create a macOS project
cd ~/anywhere
mkdir MyGame && cd MyGame
untoldengine-create create MyGame

# Create an iOS project
mkdir MobileGame && cd MobileGame
untoldengine-create create MobileGame --platform ios --bundle-id com.company.game

# Create a visionOS project
untoldengine-create create VRGame --platform visionos

# Create a multi-platform project (macOS, iOS, visionOS)
mkdir CrossPlatformGame && cd CrossPlatformGame
untoldengine-create create CrossPlatformGame --platform multi --team-id YOUR_TEAM_ID
```

## Commands

### `create` - Create a new project

Creates a new UntoldEngine game project with the specified configuration.

**Arguments:**
- `projectName` - Name of the project to create

**Options:**
- `--platform <platform>` - Target platform: `macos`, `ios`, `ios-ar`, `visionos`, `multi` (default: `macos`)
- `--bundle-id <id>` - Bundle identifier (e.g., `com.company.game`)
- `--output <path>` - Output directory (default: current directory)
- `--macos-version <version>` - macOS deployment version: `13`, `14`, `15` (default: `15`)
- `--ios-version <version>` - iOS deployment version: `16`, `17`, `18` (default: `17`)
- `--visionos-version <version>` - visionOS deployment version: `1`, `2` (default: `2`)
- `--team-id <id>` - Apple Developer Team ID for code signing
- `--optimization <level>` - Optimization level: `none`, `speed`, `size` (default: `none`)
- `--debug / --no-debug` - Include debug information (default: yes)

**Examples:**

```bash
# Create macOS project in current directory
mkdir MyGame && cd MyGame
untoldengine-create create MyGame

# Create iOS AR project
mkdir ARGame && cd ARGame
untoldengine-create create ARGame --platform ios-ar --bundle-id com.company.argame

# Create visionOS project with custom output
untoldengine-create create VRGame --platform visionos --output ~/Projects

# Create multi-platform project
mkdir MultiGame && cd MultiGame
untoldengine-create create MultiGame --platform multi --team-id ABCD1234EF
```

### `update` - Update an existing project

Updates only the GameData folder in an existing project, preserving custom code changes.

**Arguments:**
- `project` - Project name or path to the project directory

**Options:**
- `--asset-path <path>` - Path to game assets directory

**Examples:**

```bash
# Update project in default location
untoldengine-create update MyGame --asset-path ~/GameAssets

# Update project at specific path
untoldengine-create update ~/Projects/MyGame --asset-path ~/GameAssets
```

## Project Structure

Generated projects have the following structure:

```
MyGame/
├── Package.swift              # Swift Package configuration
├── README.md
└── Sources/
    └── MyGame/
        ├── AppDelegate.swift      # macOS: App lifecycle
        ├── GameScene.swift        # Game initialization and loop
        ├── GameViewController.swift # View controller
        ├── Base.lproj/
        │   └── Main.storyboard
        ├── Info.plist
        └── GameData/              # Bundled game content
            ├── Scenes/            # Scene files (.json)
            ├── Scripts/           # USC scripts (.uscript)
            ├── Models/            # 3D models
            ├── Textures/          # Texture files
            └── Shaders/           # Compiled Metal shaders
```

## Development

This CLI tool is part of the UntoldEngine repository but is packaged separately to avoid adding unnecessary dependencies to projects that use UntoldEngine.

### Architecture

- **Standalone Package**: The CLI is its own Swift Package under `Tools/UntoldEngineCLI`
- **Local Dependency**: It depends on the main UntoldEngine package via a local path reference
- **No Impact**: When users add UntoldEngine to their projects, they don't get the CLI or its dependencies (like swift-argument-parser)

### Contributing

When making changes to the CLI:

1. Make your changes in `Tools/UntoldEngineCLI/Sources/UntoldEngineCLI/`
2. Test by running `swift build` from this directory
3. Verify the CLI works: `swift run untoldengine-create --help`
4. Ensure the main engine package still builds without the CLI

## License

Copyright (C) Untold Engine Studios  
Licensed under the GNU LGPL v3.0 or later.
