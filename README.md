<h1 align="center">
  <a href="https://github.com/untoldengine/UntoldEngine">
    <!-- Please provide path to your logo here -->
    <img src="docs/images/untoldenginewhite.png" alt="Logo" width="459" height="53">
  </a>
</h1>

<div align="center">
  <br />
  <a href="https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=bug&template=01_BUG_REPORT.md&title=bug%3A+">Report a Bug</a>
  ·
  <a href="https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=enhancement&template=02_FEATURE_REQUEST.md&title=feat%3A+">Request a Feature</a>
  .
  <a href="https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=question&template=04_SUPPORT_QUESTION.md&title=support%3A+">Ask a Question</a>
</div>

<div align="center">
<br />

![Build Status](https://github.com/untoldengine/UntoldEngine/actions/workflows/ci-build-test.yml/badge.svg?style=flat-square)
[![Project license](https://img.shields.io/github/license/untoldengine/UntoldEngine.svg?style=flat-square)](LICENSE)

[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/untoldengine/UntoldEngine/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![code with love by untoldengine](https://img.shields.io/badge/%3C%2F%3E%20with%20%E2%99%A5%20by-untoldengine-ff1414.svg?style=flat-square)](https://github.com/untoldengine)

</div>

<details open="open">
<summary>Table of Contents</summary>

- [About](#about)
- [Understanding the Ecosystem](#understanding-the-ecosystem)
- [Documentation](#documentation)
- [Getting Started](#getting-started)
  - [For Game Developers](#-for-game-developers)
  - [Command-Line Tool](#%EF%B8%8F-command-line-tool-for-terminal-users)
  - [For Engine Contributors](#%EF%B8%8F-for-engine-contributors)
- [Roadmap](#roadmap)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)


</details>

---

## About

The Untold Engine strives to be a **stable, performant, and developer-friendly** 3D engine that empowers creativity, removes friction, and makes game development feel effortless for Apple developers

The Untold Engine is an open-source 3D game engine under active development, designed for macOS and iOS platforms. Written in Swift and powered by Metal, its goal is to simplify game creation with a clean, intuitive API. While the engine already supports many core systems like rendering, physics, and animation, there’s still much to build and improve.

Creator & Lead Developer: [Harold Serrano](http://www.haroldserrano.com)

Click on image to play video:

[![Watch the video](docs/images/enginethumbnail.jpg)](https://vimeo.com/1116239409?share=copy#t=0)

## Current Features:
- Cross-Platform Support: Runs on macOS, iOS, and visionOS using a unified Swift + Metal codebase.
- Modern Renderer: Built on Metal with support for PBR materials, IBL, post-processing effects, and efficient GPU resource management.
- Entity–Component–System (ECS): Lightweight ECS architecture for organizing game logic and behaviors cleanly.
- Scene Graph: Hierarchical transformation system for managing parent–child relationships between entities.
- Physics System: Includes Euler integration, motion systems, and component-based extensibility for collisions and constraints.
- Animation System: Supports skeletal animations and reusable animation clips.
- Input System: Unified keyboard, mouse, and touch input handling (with controller support planned).
- Gaussian Splat Rendering: Native support for rendering 3D Gaussian Splats with Metal, enabling photorealistic scene reconstruction and novel view synthesis.
- Untold Editor Integration: Optional visual editor for managing assets, entities, and scenes.
- Swift Package Manager (SPM): Fully modular — integrate it easily into your own Xcode or Swift projects.
- Open Source & Extensible: Licensed under LGPL-3.0, encouraging collaboration and custom extensions.

## The Journey Ahead:

The Untold Engine is a work in progress, with ambitious goals to:

- Extend the physics and collision system.
- Add advanced lighting and reflections.
- Expand XR and input support for visionOS.
- Improve workflow between the engine, editor, and asset pipeline.

---

## Understanding the Ecosystem

The Untold Engine project consists of multiple components designed for different audiences:

### 🎮 **Untold Engine Studio** (For Game Developers)
- **What it is**: Standalone application (DMG download)
- **Includes**: Visual editor + scripting + full engine + all dependencies
- **Target audience**: Game developers who want to create games
- **Get it**: [Download releases](https://github.com/untoldengine/UntoldEditor/releases)
- **No coding/building required** — just install and start creating

### 🛠️ **Untold Engine** (For Engine Contributors)
- **What it is**: Core engine repository (this repo)
- **Contains**: Rendering, physics, ECS, animation, input systems
- **Target audience**: Developers contributing to the engine core
- **Get it**: Clone [UntoldEngine](https://github.com/untoldengine/UntoldEngine)
- **Purpose**: Improve or extend the engine's fundamental systems

### 📝 **Untold Editor** (For Editor Contributors)  
- **What it is**: Editor interface repository
- **Contains**: Visual editing tools, UI, asset management
- **Target audience**: Developers contributing to the editor
- **Get it**: Clone [UntoldEditor](https://github.com/untoldengine/UntoldEditor)
- **Purpose**: Improve the editor interface and workflows

**Quick guide:**
- **Making games?** → Download Untold Engine Studio
- **Contributing to engine core?** → Clone Untold Engine
- **Contributing to editor?** → Clone Untold Editor

---

## Documentation

For comprehensive guides and API documentation, visit:  
👉 [Untold Engine Docs](https://untoldengine.github.io/UntoldEngine)

You'll find:
- **Game developers**: Tutorials on using Untold Engine Studio
- **Contributors**: Architecture guides and API references
- **Installation & setup** for both users and developers
- **How-to guides** for common tasks

⚡ **New to game development with Untold Engine?** Download [Untold Engine Studio](https://github.com/untoldengine/UntoldEditor/releases) and check out the Getting Started guide.

---

## Getting Started

### 🎮 For Game Developers

**Want to make games?** Download **[Untold Engine Studio](https://github.com/untoldengine/UntoldEditor/releases)** — a complete standalone application that includes:

- ✅ Visual editor with scripting support
- ✅ Full Untold Engine integration
- ✅ Asset management and scene editing
- ✅ Everything you need to create games
- ✅ No build tools or GitHub required

👉 **[Download Untold Engine Studio](https://github.com/untoldengine/UntoldEditor/releases)**

Just download the DMG, install, and start creating your game!

![UntoldEditorScreenshot](docs/images/editorscreenshot.png)

### ⌨️ Command-Line Tool (For Terminal Users)

**Prefer the command line?** Use **`untoldengine-create`** — a CLI tool for creating game projects without the editor:

```bash
# Install the CLI tool
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
./Scripts/install-create.sh

# Create a game project
mkdir MyGame && cd MyGame
untoldengine-create create MyGame
```

**Features:**
- ✅ Create projects for macOS, iOS, iOS AR, and visionOS
- ✅ Automated asset folder structure creation
- ✅ Perfect for CI/CD pipelines and scripting
- ✅ Update existing projects without touching custom code

👉 **[Full CLI Documentation](docs/CLI.md)**

### 🛠️ For Engine Contributors

**Want to contribute to the engine core?** This repository contains the engine's fundamental systems:

- Rendering (Metal-based)
- Physics and collision detection
- Entity-Component-System (ECS)
- Animation and scene graph
- Input handling

Clone this repository if you want to improve or extend the engine itself.

---

## Roadmap

See the [open issues](https://github.com/untoldengine/UntoldEngine/issues) for a list of proposed features (and known issues).

- [Top Feature Requests](https://github.com/untoldengine/UntoldEngine/issues?q=label%3Aenhancement+is%3Aopen+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Top Bugs](https://github.com/untoldengine/UntoldEngine/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Newest Bugs](https://github.com/untoldengine/UntoldEngine/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

---

## Support

Reach out to the maintainer at one of the following places:

- [GitHub issues](https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=question&template=04_SUPPORT_QUESTION.md&title=support%3A+)

---

## Project assistance

If you want to say **thank you** or/and support active development of Untold Engine:

- Add a [GitHub Star](https://github.com/untoldengine/UntoldEngine) to the project.
- Tweet about the Untold Engine.
- Write interesting articles about the project on [Dev.to](https://dev.to/), [Medium](https://medium.com/) or your personal blog.

Together, we can make Untold Engine **better**!

---

## Contributing

We welcome contributions to the Untold Engine! Here’s how you can help:

1. **Fix Bugs**: Review open issues labeled [help wanted](https://github.com/untoldengine/UntoldEngine/issues?q=label%3Ahelp+wanted).
2. **Improve Features**: Enhance existing systems, such as adding collision detection to the physics system.
3. **Create Tutorials**: Write how-to guides or share examples to help other developers.
4. **Expand the Engine**: Suggest and implement new features like AI systems or advanced shaders.

See the [Contribution Guidelines](https://untoldengine.github.io/UntoldEngine) for details.

---


## Top Github Sponsors

A huge thanks to the people helping shape the Untold Engine. Your support and contributions make the project better every day.

<p align="center">
  <a href="https://github.com/miolabs">
    <img src="docs/images/top_contributors/MioLogo.png" alt="MioLabs" width="120"/>
  </a>
</p>


## License  

This project is licensed under the **LGPL v3.0**.  

### What Does This Mean for You?  
- **Developing a Game**: You can use the Untold Engine to build your game without needing to open source your game’s code.  
- **Modifying the Engine**: If you make changes to the engine itself, those changes must be open-sourced under the LGPL v3.0.  
- **Stronger Protections**: LGPL v3.0 adds explicit patent protection and compatibility with modern licenses like Apache-2.0 (used by OpenUSD).  

### License in Plain Terms  

| You want to…                                 | Allowed? | Obligations                                      |
|----------------------------------------------|----------|--------------------------------------------------|
| Build a game with Untold Engine              | ✅ Yes   | No need to open source your game’s code          |
| Modify Untold Engine internals               | ✅ Yes   | Must share modifications under LGPL v3.0         |
| Distribute the Untold Engine                 | ✅ Yes   | Keep the LGPL license intact                     |
| Use for commercial projects                  | ✅ Yes   | No royalties or fees                             |
| Combine with Apache-2.0 libs (e.g. OpenUSD)  | ✅ Yes   | Fully compatible under LGPL v3.0                 |

For more details, see the full license text [here](https://www.gnu.org/licenses/lgpl-3.0.html).  

> 💡 Our philosophy: You’re free to build with Untold Engine however you like — but if you improve the engine itself, those improvements should be shared back so the whole community benefits.  

---

## Questions & Discussions

To keep communication clear and accessible for everyone:

- 💡 Use **[GitHub Discussions](https://github.com/untoldengine/UntoldEngine/discussions)** for feature proposals, ideas, or general questions.  
- 🐞 Use **[GitHub Issues](https://github.com/untoldengine/UntoldEngine/issues)** for bugs or concrete tasks that need tracking.  

This way, conversations stay organized, visible to the community, and future contributors can benefit from past discussions.
 
