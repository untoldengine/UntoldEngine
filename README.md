
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

The project focuses on building a **clean, system-driven architecture** with modern rendering, an ECS-based gameplay model, and an extensible asset pipeline.

The engine is under active development and continues to evolve as new systems and workflows are added.

![untoldengine-image](/docs/images/engine-highlight-1.png)

---

## 🎯 Who is this for?

Untold Engine is designed for developers who:

- Want **full control over rendering and systems**
- Prefer working directly with **Swift + Metal**
- Are building **XR, 3D, or visualization applications**
- Need to handle **large scenes, streaming data, or custom pipelines**

This is not a drag-and-drop editor-first engine — it is a **code-driven engine for developers who want to understand and shape the system**.


Creator & Lead Developer:  
http://www.haroldserrano.com

---

# 🚀 Try the Engine Right Now

The fastest way to experience Untold Engine is to run the demo project.

Clone the repository, run the engine and load a USDZ file:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
swift run untoldsandbox
```

Legacy alias (prints deprecation warning):

```bash
swift run DemoGame
```

This will:

- Build the engine using **Swift Package Manager**
- Compile the demo project
- Launch the demo so you can see the engine running immediately

No additional setup is required.

---

## 🧱 Core Direction

Untold Engine is being developed with the following goals:

- **Large Scene Rendering**  
  Striving to support LOD, geometry streaming, batching, and memory-aware systems for large datasets

- **XR / visionOS Support**  
  Expanding support for spatial input, AR workflows, and Vision Pro experiences

- **Metal-First Architecture**  
  Keeping the rendering layer close to Metal to maintain performance and control

---

## 🖼 Example Use Cases

Untold Engine aims to support applications such as:

- XR applications (Vision Pro, ARKit-based apps)
- Large-scale scene visualization (cities, archviz, datasets)
- Custom rendering pipelines and experiments
- Simulation tools and interactive 3D systems

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

# Engine API

- [Getting Started](docs/API/GettingStarted.md)
- [Registration System](docs/API/UsingRegistrationSystem.md)
- [Scenegraph](docs/API/UsingScenegraph.md)
- [Transform System](docs/API/UsingTransformSystem.md)
- [Camera System](docs/API/UsingCameraSystem.md)
- [Rendering System](docs/API/UsingRenderingSystem.md)
- [Lighting System](docs/API/UsingLightingSystem.md)
- [Materials](docs/API/UsingMaterials.md)
- [Input System](docs/API/UsingInputSystem.md)
- [Physics System](docs/API/UsingPhysicsSystem.md)
- [Steering System](docs/API/UsingSteeringSystem.md)
- [Animation System](docs/API/UsingAnimationSystem.md)
- [Async Loading](docs/API/UsingAsyncLoading.md)
- [LOD System](docs/API/UsingLODSystem.md)
- [Static Batching System](docs/API/UsingStaticBatchingSystem.md)
- [Geometry Streaming System](docs/API/UsingGeometryStreamingSystem.md)
- [LOD-Batching-Streaming](docs/API/UsingLOD-Batching-Streaming.md)
- [Spatial Input](docs/API/UsingSpatialInput.md)
- [Gaussian System](docs/API/UsingGaussianSystem.md)
- [Spatical Debugger](docs/API/SpatialDebugger.md)
- [Profiler](/docs/API/UsingProfiler.md)


# Engine Architecture:

- [Rendering System](docs/Architecture/renderingSystem.md)
- [XR Rendering System](docs/Architecture/xrRenderingSystem.md)
- [Static Batching System](docs/Architecture/batchingSystem.md)
- [Geometry Streaming System](docs/Architecture/geometryStreamingSystem.md)
- [LOD System](docs/Architecture/lodSystem.md)
- [Progressive Asset Loader](docs/Architecture/progressiveAssetLoader.md)
- [Streaming Cache Lifecycle](docs/Architecture/streamingCacheLifecycle.md)
- [Texture Streaming System](docs/Architecture/textureStreamingSystem.md)
- [Out of Core](docs/Architecture/outOfCore.md)

---

# Set Up an Xcode Project with Untold Engine

Use `untoldengine-create` to generate a ready-to-run Xcode project with Untold Engine wired in.

Install it from the repository:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
./scripts/install-untoldengine-create.sh
```

## Vision Pro Example

```bash
mkdir VisionGame
cd VisionGame
untoldengine-create create VisionGame --platform visionos
open VisionGame.xcodeproj
```

## What this creates for you

- Xcode project + platform-specific app template files
- `GameData` folder structure (`Scenes`, `Scripts`, `Models`, `Textures`, etc.)
- Engine package dependencies configured for the selected platform
- Starter `GameScene` code showing how to:
  - Load a mesh (`city.usdz`)
  - Enable geometry streaming
  - Enable static batching

Note: `city.usdz` should be placed in `GameData/model` (generated folder name is `GameData/Models`).

## Platform options

```bash
# visionOS (Apple Vision Pro)
untoldengine-create create MyGame --platform visionos

# macOS (default)
untoldengine-create create MyGame --platform macos

# iOS with ARKit
untoldengine-create create MyGame --platform iosar

# iOS
untoldengine-create create MyGame --platform ios

```

Dependency behavior by platform:

- `visionos`: `UntoldEngineXR` + `UntoldEngineAR`
- `iosar`: `UntoldEngineAR`
- `ios` and `macos`: `UntoldEngine`

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
- [Contributing Guidelines](docs/Contributor/ContributionGuidelines.md)
- [Formatting](docs/Contributor/Formatting.md)
- [Versioning](docs/Contributor/versioning.md)

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
