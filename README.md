
<h1 align="center">
  <a href="https://github.com/untoldengine/UntoldEngine">
    <img src="docs/images/untoldenginewhite.png" alt="Logo" width="600">
  </a>
</h1>

<div align="center">
  <br />
  <a href="https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=bug&template=01_BUG_REPORT.md&title=bug%3A+">Report a Bug</a>
  ·
  <a href="https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=enhancement&template=02_FEATURE_REQUEST.md&title=feat%3A+">Request a Feature</a>
  ·
  <a href="https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=question&template=04_SUPPORT_QUESTION.md&title=support%3A+">Ask a Question</a>
</div>

<div align="center">
<br />

![Build Status](https://github.com/untoldengine/UntoldEngine/actions/workflows/ci-build-test.yml/badge.svg?style=flat-square)
[![Project license](https://img.shields.io/github/license/untoldengine/UntoldEngine.svg?style=flat-square)](LICENSE)
[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/untoldengine/UntoldEngine/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)

</div>

---

# Untold Engine

Untold Engine is an **open-source 3D engine written in Swift and powered by Metal**, designed for Apple platforms including **macOS, iOS, and visionOS**.

The project focuses on building a clean and approachable architecture with modern rendering, an ECS-based gameplay model, and an extensible asset pipeline.

The engine is under active development and continues to evolve as new systems and workflows are added.

Creator & Lead Developer:  
http://www.haroldserrano.com

---

# 🚀 Try the Engine Right Now

The fastest way to experience Untold Engine is to run the demo project.

Clone the repository and run the demo:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
swift run DemoGame
```

This will:

- Build the engine using **Swift Package Manager**
- Compile the demo project
- Launch the demo so you can see the engine running immediately

No additional setup is required.

---

# Demo

Click the image below to watch the engine in action.

[![Watch the video](docs/images/enginethumbnail.jpg)](https://vimeo.com/1116239409?share=copy#t=0)

---

# Current Features

- Apple Platform Coverage: Unified Swift + Metal codebase for macOS, iOS, and visionOS
- Rendering Pipeline: Metal renderer with PBR/IBL workflows and post-processing across standard and XR paths
- AR and XR Runtime Support: Built-in AR workflows plus visionOS integration and spatial interaction support
- ECS + Scene Graph Core: Component-based architecture with hierarchical transforms and scene root transform controls
- Async Content Loading: Asynchronous loading pipeline for scenes and assets to improve responsiveness on large worlds
- LOD and Streaming: LOD support with geometry streaming, streaming regions, and memory budget management
- Static Batching and Culling: Static batching, octree acceleration, and occlusion culling for large-scene performance
- Advanced Picking: Scene, ground, and GPU ray picking with octree-backed intersection paths
- Spatial Input Features: XR spatial input helpers including anchored pinch drag, distance tracking, and two-hand rotation
- Scripting System (USC): Untold Script Core with multi-script support plus camera, math, and physics APIs (Experimental)
- Gameplay Systems: Physics, animation, camera waypoint, and input systems (keyboard, mouse, touch, and gamepad)
- Gaussian Splat Rendering: Native Metal support for rendering and compositing 3D Gaussian content
- Tooling Integration: Optional Untold Editor workflow and Swift Package Manager integration

---

# Project Ecosystem

The Untold Engine project includes several related components.

## Untold Engine Studio

Standalone application that includes:

- Visual editor
- Full engine integration
- Asset management tools

Download:

https://github.com/untoldengine/UntoldEditor/releases

Ideal for developers who want to **create games using the editor**.

---

## Untold Engine (this repository)

Contains the **core engine systems**:

- Rendering
- ECS architecture
- Physics and animation
- Scene graph
- Input systems

This repository is primarily for:

- Engine contributors
- Developers studying the engine architecture
- Users running demo projects

---

## Untold Editor

The visual editor used for managing assets, scenes, and workflows.

Repository:

https://github.com/untoldengine/UntoldEditor

---

# Documentation

For guides and API documentation visit:

https://untoldengine.github.io/UntoldEngine

You will find:

- Tutorials for using the engine
- Architecture documentation
- Setup instructions
- Guides for common tasks

---

# Command Line Tool (Optional)

If you prefer working from the terminal, you can use the project creation CLI.

Install it from the repository:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
./scripts/install-create.sh
```

Then create a new project:

```bash
mkdir MyGame
cd MyGame
untoldengine-create create MyGame
```

Features:

- Create macOS, iOS, and visionOS projects
- Multi-platform project templates
- Automated project structure generation

---

# Roadmap

See open issues for planned features and improvements.

Feature Requests  
https://github.com/untoldengine/UntoldEngine/issues?q=label%3Aenhancement

Bug Reports  
https://github.com/untoldengine/UntoldEngine/issues?q=label%3Abug

---

# Support

For help or questions use GitHub Issues.

https://github.com/untoldengine/UntoldEngine/issues

---

# Contributing

Contributions are welcome.

You can help by:

- Fixing bugs
- Improving systems such as rendering, physics, or ECS
- Writing documentation
- Proposing new ideas

Before submitting a pull request please read:

- CONTRIBUTING.md
- CONTRIBUTOR_LICENSE_AGREEMENT.md

All contributions are licensed under **MPL-2.0**.

---

# Contributor License Agreement

To ensure the long-term sustainability of the project, contributors must agree to the CLA.

By submitting a pull request you agree that your contributions may be distributed under the **Mozilla Public License 2.0**.

See:

CONTRIBUTOR_LICENSE_AGREEMENT.md

---

# GitHub Sponsors

A huge thanks to the people helping shape the Untold Engine.

<p align="center">
  <a href="https://github.com/miolabs">
    <img src="docs/images/top_contributors/MioLogo.png" alt="MioLabs" width="120"/>
  </a>
</p>

---

# License

Untold Engine is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

This allows developers to build commercial applications while ensuring improvements to the engine itself remain open.

| Use Case | Allowed | Obligation |
|----------|--------|-----------|
| Build games | Yes | Game code can remain proprietary |
| Commercial apps | Yes | No royalties |
| Modify engine | Yes | Modified engine files remain MPL |
| Create plugins | Yes | Any license allowed |

Full license text:

https://www.mozilla.org/MPL/2.0/

---

# Trademark

“Untold Engine” and the Untold Engine logo are trademarks of **Untold Engine Studios**.

Forks may not use the name in a way that implies official endorsement.

See:

TRADEMARKS.md

---

# Questions & Discussions

Use GitHub Discussions for ideas and questions:

https://github.com/untoldengine/UntoldEngine/discussions

Use GitHub Issues for bugs and tasks:

https://github.com/untoldengine/UntoldEngine/issues
