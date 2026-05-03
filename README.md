
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
![Version](https://img.shields.io/github/v/release/untoldengine/UntoldEngine?style=flat-square&label=version)
![Commits](https://img.shields.io/github/commit-activity/t/untoldengine/UntoldEngine?style=flat-square&label=commits)
![Last Commit](https://img.shields.io/github/last-commit/untoldengine/UntoldEngine?style=flat-square&label=last+commit)

</div>

---

# Untold Engine

Untold Engine is a **Swift + Metal 3D engine for macOS, iOS, and visionOS** — with native Apple Vision Pro support and a growing focus on spatial computing — built for developers who:

- Want **full control over rendering and systems**
- Prefer working directly with **Swift + Metal**
- Are building **XR, 3D, or visualization applications**
- Need to handle **large scenes, streaming data, or custom pipelines**

If you've hit the ceiling of what existing engines allow on Apple platforms, this is for you.

![untoldengine-image](/docs/images/engine-highlight-1.png)

---

## Watch It in Action — Apple Vision Pro Demos

<table>
  <tr>
    <td><a href="https://vimeo.com/1186637984?share=copy&fl=sv&fe=ci"><img src="https://vumbnail.com/1186637984.jpg" width="280"></a></td>
    <td><a href="https://vimeo.com/1186592834?share=copy&fl=sv&fe=ci"><img src="https://vumbnail.com/1186592834.jpg" width="280"></a></td>
    <td><a href="https://vimeo.com/1176823067?share=copy&fl=sv&fe=ci"><img src="https://vumbnail.com/1176823067.jpg" width="280"></a></td>
  </tr>
  <tr>
    <td><a href="https://vimeo.com/1176823994?share=copy&fl=sv&fe=ci"><img src="https://vumbnail.com/1176823994.jpg" width="280"></a></td>
    <td><a href="https://vimeo.com/1176995991?fl=ip&fe=ec"><img src="https://vumbnail.com/1176995991.jpg" width="280"></a></td>
    <td></td>
  </tr>
</table>

Creator & Lead Developer:  
http://www.haroldserrano.com

---

## 🚀 Try the Engine Right Now

The fastest way to experience Untold Engine is to run the demo project.

Clone the repository and launch the demo:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
swift run untolddemo
```

The demo UI lets you see the engine in action right away. Using the `Remote Scene` drop-down menu, you can choose a scene to stream directly into the demo through the engine's **Asset Remote Streaming** support.

### I want to try my own USDZ

Untold Engine uses its own native asset format: `.untold`.

To try your own `USDZ` file, first convert it to `.untold` using the `Tools` section in the demo UI.

After the export is complete, open the Local Scene `Browse` drop-down menu, choose `.untold`, then browse for and select your exported `.untold` file.

---

![untoldengine-image-2](/docs/images/engine-highlight-2.png)

## Get a Feel for the API

A small code sample to inspect and experiment with is available at `Sources/Sandbox/GameScene.swift`. Along with the [Usage Example](docs/API/UsageExamples.md), it shows how the Untold Engine API works in practice.

The Sandbox target lets you test engine APIs — creating an entity, attaching a mesh, trying animations, and other scene setup.

To run it from the CLI:

```bash
swift run sandbox
```

To run it in Xcode, select the `sandbox` scheme and press Run.

---

![untoldengine-image-3](/docs/images/engine-highlight-3.png)

## Set Up an Xcode Project with Untold Engine

Use `untoldengine-create` to generate a ready-to-run Xcode project with Untold Engine wired in.

Install it from the repository:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
./scripts/install-untoldengine-create.sh
```

### Vision Pro Example

```bash
mkdir VisionGame
cd VisionGame
untoldengine-create create VisionGame --platform visionos
open VisionGame.xcodeproj
```

### What this creates for you

- Xcode project + platform-specific app template files
- `GameData` folder structure (`Scenes`, `Scripts`, `Models`, `Textures`, etc.)
- Engine package dependencies configured for the selected platform
- Starter `GameScene` code showing how to:
  - Load a mesh (`city.usdz`)
  - Enable geometry streaming
  - Enable static batching

Note: `city.usdz` should be placed in `GameData/model` (generated folder name is `GameData/Models`).

### Platform options

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

## Visual Editor

To make using the Untold Engine easier, you can use the **Untold Engine Studio** — a standalone editor for preparing assets, composing scenes, and generating scene files used inside your game. [Download Untold Engine Studio](https://github.com/untoldengine/UntoldEditor/releases)

![untoldeditor-image-1](/docs/images/editor-highlight-1.png)

Note, you still need the engine as a dependency in your project. The editor is only used for composing scenes.

---

## 🧱 Core Direction

Untold Engine is built around three focused goals:

- **Spatial Engine First** — Designed for spatial computing applications. LOD, geometry streaming, and static batching exist to support large, real-world-scale environments where presence and performance both matter.

- **XR / visionOS Support** — Spatial input, AR workflows, and Vision Pro support are functional today and expanding with each release.

- **Metal-First Architecture** — The rendering layer stays close to Metal to maintain performance and control, without abstraction layers getting in the way.

---

## 🖼 Example Use Cases

Untold Engine is well-suited for:

- XR applications (Vision Pro, ARKit-based apps)
- Large-scale scene visualization (cities, archviz, datasets)
- Custom rendering pipelines and experiments
- Simulation tools and interactive 3D systems

---

# Current Features

- **Apple Platform Coverage** — Unified Swift + Metal codebase for macOS, iOS, and visionOS
- **Rendering Pipeline** — Metal renderer with PBR/IBL workflows and post-processing across standard and XR paths
- **AR and XR Runtime Support** — Built-in AR workflows plus visionOS integration and spatial interaction support
- **ECS + Scene Graph Core** — Component-based architecture with hierarchical transforms and scene root transform controls
- **Async Content Loading** — Asynchronous loading pipeline for scenes and assets to improve responsiveness on large worlds
- **LOD and Streaming** — LOD support with geometry streaming, streaming regions, and memory budget management
- **Static Batching and Culling** — Static batching, octree acceleration, and occlusion culling for large-scene performance
- **Advanced Picking** — Scene, ground, and GPU ray picking with octree-backed intersection paths
- **Spatial Input Features** — XR spatial input helpers including anchored pinch drag, distance tracking, and two-hand rotation
- **Scripting System (USC)** — Untold Script Core with multi-script support plus camera, math, and physics APIs (Experimental)
- **Gameplay Systems** — Physics, animation, camera waypoint, and input systems (keyboard, mouse, touch, and gamepad)
- **Gaussian Splat Rendering** — Native Metal support for rendering and compositing 3D Gaussian content
- **Tooling Integration** — Optional Untold Editor workflow and Swift Package Manager integration

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
- [Spatial Debugger](docs/API/SpatialDebugger.md)
- [Profiler](docs/API/UsingProfiler.md)
- [Asset Exporter](docs/API/UsingTheExporter.md)
- [Optimizations](docs/API/Optimizations.md)
- [Create Project with CLI](docs/API/UsingUntoldEngineCLI.md)
- [Post FX](docs/API/UsingPostFX.md)

---

# Engine Architecture

- [Rendering System](docs/Architecture/renderingSystem.md)
- [XR Rendering System](docs/Architecture/xrRenderingSystem.md)
- [Static Batching System](docs/Architecture/batchingSystem.md)
- [Geometry Streaming System](docs/Architecture/geometryStreamingSystem.md)
- [LOD System](docs/Architecture/lodSystem.md)
- [Progressive Asset Loader](docs/Architecture/progressiveAssetLoader.md)
- [Streaming Cache Lifecycle](docs/Architecture/streamingCacheLifecycle.md)
- [Texture Streaming System](docs/Architecture/textureStreamingSystem.md)
- [Out of Core](docs/Architecture/outOfCore.md)
- [Asset Remote Streaming](docs/Architecture/asset_remote_streaming.md)

---

# Roadmap

See open issues for planned features and known improvements.

- [Feature Requests](https://github.com/untoldengine/UntoldEngine/issues?q=label%3Aenhancement)
- [Bug Reports](https://github.com/untoldengine/UntoldEngine/issues?q=label%3Abug)

---

# Support

For help or questions, open a [GitHub Issue](https://github.com/untoldengine/UntoldEngine/issues).

---

# Contributing

Contributions are welcome — whether that's fixing bugs, improving systems, writing documentation, or proposing ideas.

Before submitting a pull request, please review the [Contributing Guidelines](docs/Contributor/ContributionGuidelines.md).

All contributions are licensed under **MPL-2.0**.

---

# Contributor License Agreement

By submitting a pull request you agree that your contributions may be distributed under the **Mozilla Public License 2.0**. See [CONTRIBUTOR_LICENSE_AGREEMENT.md](CONTRIBUTOR_LICENSE_AGREEMENT.md) for details.

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
|----------|---------|-----------|
| Build games | Yes | Game code can remain proprietary |
| Commercial apps | Yes | No royalties |
| Modify engine | Yes | Modified engine files remain MPL |
| Create plugins | Yes | Any license allowed |

Full license: https://www.mozilla.org/MPL/2.0/

**Need to keep engine modifications private?** A commercial license is available for teams that require it. See [COMMERCIAL.md](COMMERCIAL.md) for details.

---

# Trademark

"Untold Engine" and the Untold Engine logo are trademarks of **Untold Engine Studios**. Forks may not use the name in a way that implies official endorsement. See [TRADEMARKS.md](TRADEMARKS.md).

---

# Questions & Discussions

- [GitHub Discussions](https://github.com/untoldengine/UntoldEngine/discussions) — ideas and questions
- [GitHub Issues](https://github.com/untoldengine/UntoldEngine/issues) — bugs and tasks

