---
id: intro
title: Installation
sidebar_position: 1
---

# Getting Started
The Untold Engine is a game engine designed to be integrated into your game projects. It is distributed as a Swift Package using Swift Package Manager (SPM) for easy integration and maintenance.

There are two primary ways to use the engine:

- **Running the Engine Standalone** – Ideal for contributors and developers who want to explore, modify, or contribute to the engine itself. This mode allows you to test the engine independently using its built-in demo assets and functionalities.
- **Integrating the Engine into Your Game Project** – Perfect for game developers who want to build a game using the engine. This requires adding the engine as a Swift Package Dependency in a game project.

### Prerequisites

To begin using the Untold Engine, you’ll need:

- An Apple computer.
- The latest version of Xcode, which you can download from the App Store.

## Documentation & Quick Start

### How to install the Untold Engine

Follow these steps to set up and run the Untold Engine.

1. Clone the Repository

```bash
git clone https://github.com/untoldengine/UntoldEngine
cd UntoldEngine
open Package.swift
```

**How to Run**
1. Select the **DemoGame** scheme.  
2. Download the [Demo Game Assets v1.0](https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1) and place them in your Desktop folder.  
3. Set the Scheme to **Demo Game**. Then set **My Mac** as the target device and hit **Run**.  
4. Use **WASD** keys to move the player around.  


![DemoGame](../images/demogame-noeditor.png)


## Untold Editor

The **Untold Editor** is a companion tool for the Untold Engine.  
It provides a visual environment for managing assets, scenes, and entities in projects built with the engine.  

The editor is not required to use the engine, but it makes iteration faster by giving developers and designers a user-friendly interface. To launch the Untold Editor, set the scheme in xcode to **UntoldEngineEditor**.

![UntoldEditorScreenshot](../images/editorscreenshot.png)

---

## Preloaded Assets to Kickstart Development

To save time, the Untold Engine includes preloaded assets you can use right away:

- **Models**: Soccer stadium, player, ball, and more.  
- **Animations**: Prebuilt running, idle, and other character motions.  

You can download them [Demo Game Assets v1.0](https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1).

