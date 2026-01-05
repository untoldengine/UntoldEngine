---
id: intro
title: Installation
sidebar_position: 1
---

# Installation

This guide covers how to install and set up the **UntoldEngine** for game development.

There are two ways to work with the Untold Engine:
1. **CLI Workflow** (Recommended) - Command-line tool for creating projects
2. **Visual Scene Composition** (Optional) - Untold Engine Studio for visual editing

---

## Recommended: CLI Workflow

The **command-line workflow** is the primary way to create and develop UntoldEngine games. It provides full control and works seamlessly with Xcode.

### System Requirements

- **macOS** (Apple Silicon recommended)
- **Xcode 15.0+** 
- **Swift 5.9+**
- **Metal-capable GPU**
- **Git**

### Installation

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

### Quick Start

Create your first game in three commands:

```bash
# 1. Create project directory
mkdir MyGame && cd MyGame

# 2. Create the project
untoldengine-create create MyGame

# 3. Open in Xcode
open MyGame/MyGame.xcodeproj
```

**That's it!** Your project is ready to build and run.

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
