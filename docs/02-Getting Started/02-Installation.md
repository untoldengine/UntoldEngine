---
id: intro
title: Installation
sidebar_position: 1
---

# Installation

This page explains how to install **Untold Engine Studio**, the recommended way to get started with Untold Engine.

Untold Engine Studio is a downloadable app that includes:
- The **Untold Engine** runtime
- The **Untold Editor** for building and editing games

![editorbottomshot](../images/Editor/EditorBottomShot.png)

If your goal is to **make games**, this is the only installation you need.

---

## Recommended Installation (Untold Engine Studio)

### 1. Download

Download the latest version of **Untold Engine Studio** from the official website:

[Download Releases](https://github.com/untoldengine/UntoldEditor/releases)

The download is provided as a `.dmg` file for macOS.

---

### 2. Install

1. Open the downloaded `.dmg` file  
2. Drag **Untold Engine Studio** into your `Applications` folder  
3. Launch the app from `Applications`

No additional setup is required.

---

### 3. First Launch

On first launch, Untold Engine Studio will:
- Initialize the engine runtime
- Set up the editor environment
- Prompt you to create or open a project

From here, you can immediately:
- Create scenes
- Import assets
- Write USC scripts
- Run and test your game

---

## System Requirements

- macOS (Apple Silicon recommended)
- Metal-capable GPU
- Keyboard and mouse

---

## What You Get

By installing Untold Engine Studio, you get:

- A complete **game development environment**
- The **USC scripting API** for gameplay logic
- An integrated editor for scenes, assets, and scripts
- Build and run support for supported platforms

You do **not** need to install the engine or editor separately.

---

## Alternative Installation: CLI Workflow

For **advanced users** or those who prefer a **command-line workflow** without the visual editor, you can install the CLI tools.

### When to Use CLI

- You prefer working entirely in Xcode without a visual editor
- You want to script project creation and automation
- You're building tools or integrations on top of UntoldEngine

### CLI Installation

**1. Clone the repository:**

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
```

**2. Install the CLI tool:**

```bash
./Scripts/install-create.sh
```

This will build and install the `untoldengine-create` command to `/usr/local/bin`.

**3. Verify installation:**

```bash
untoldengine-create --version
untoldengine-create --help
```

### CLI Quick Start

Create a project in three commands:

```bash
# 1. Create project directory
mkdir MyGame && cd MyGame

# 2. Create the project
untoldengine-create create MyGame

# 3. Open in Xcode
open MyGame/MyGame.xcodeproj
```

For complete CLI documentation, see: **[CLI.md](../../CLI.md)**

---

### What You Get

The CLI creates a complete, ready-to-run project:

- **Xcode project** - Configured and ready to build
- **GameScene.swift** - Your game logic goes here
- **GameViewController.swift** - Renderer and view setup
- **GameData/** directory - All game assets location
- **Platform-specific** files (AppDelegate, Info.plist, etc.)

### Project Structure

```
MyGame/                          # Your working directory
└── MyGame/                      # Generated project
    ├── MyGame.xcodeproj         # Open this in Xcode
    ├── project.yml              # XcodeGen configuration
    └── Sources/
        └── MyGame/
            ├── GameData/        # ← Put your assets here
            │   ├── Models/      # 3D models
            │   ├── Scenes/      # Scene files
            │   ├── Scripts/     # USC scripts
            │   ├── Textures/    # Images
            │   └── ...
            ├── GameScene.swift          # Your game logic
            ├── GameViewController.swift # View controller
            └── AppDelegate.swift        # App entry point
```

### Platform Support

The CLI supports multiple platforms:

```bash
# macOS (default)
untoldengine-create create MyGame --platform macos

# iOS
untoldengine-create create MyGame --platform ios

# iOS with ARKit
untoldengine-create create MyGame --platform iosar

# visionOS (Apple Vision Pro)
untoldengine-create create MyGame --platform visionos
```

### Development Workflow

1. **Write code** in GameScene.swift (game logic)
2. **Add assets** to the GameData/ directory
3. **Build & run** in Xcode (Cmd+R)
4. **Iterate** - make changes and rebuild

For complete CLI documentation, see: **[CLI.md](../../CLI.md)**

---

## Optional: Visual Scene Composition

If you want a **visual tool for scene composition and asset management**, you can use the **Untold Engine Studio**.

![editorbottomshot](../images/Editor/EditorBottomShot.png)

### What is Untold Engine Studio?

Untold Engine Studio is a **visual editor** that provides:
- Visual scene composition
- Asset browser and management
- USC script editor
- Real-time preview

### When to Use It

- You want to **visually compose scenes** instead of coding layouts
- You prefer a **GUI** for asset management
- You need to **preview scenes** without building
- You're **prototyping** and want quick visual feedback

### Installation

**1. Download:**

Get the latest `.dmg` from:
[Download Untold Engine Studio](https://github.com/untoldengine/UntoldEditor/releases)

**2. Install:**

- Open the `.dmg` file
- Drag **Untold Engine Studio** to `Applications`
- Launch from `Applications`

### Workflow Integration

Combine both tools for maximum productivity:

1. **Create project** with CLI (`untoldengine-create`)
2. **Write game logic** in Xcode (GameScene.swift)
3. **Compose scenes visually** in Untold Engine Studio
4. **Build and run** from Xcode

Both tools work with the same project structure and GameData directory.

---

## Preloaded Assets

To kickstart development, download prebuilt demo assets:

- **Models**: Soccer stadium, player, ball, and more
- **Animations**: Running, idle, and other character motions
- **Textures**: Sample materials

[Download Demo Assets v1.0](https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1)

Extract and copy into your project's `GameData/` directory.

---

## Preloaded Assets

To kickstart development, download prebuilt demo assets:

- **Models**: Soccer stadium, player, ball, and more
- **Animations**: Running, idle, and other character motions
- **Textures**: Sample materials

[Download Demo Assets v1.0](https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1)

Extract and copy into your project's `GameData/` directory.

---
