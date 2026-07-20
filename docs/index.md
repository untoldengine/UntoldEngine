# Untold Engine

![Build Status](https://github.com/untoldengine/UntoldEngine/actions/workflows/ci-build-test.yml/badge.svg?style=flat-square)
[![Project license](https://img.shields.io/github/license/untoldengine/UntoldEngine.svg?style=flat-square)](https://github.com/untoldengine/UntoldEngine/blob/main/LICENSE)
[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/untoldengine/UntoldEngine/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
![Version](https://img.shields.io/github/v/release/untoldengine/UntoldEngine?style=flat-square&label=version)
![Commits](https://img.shields.io/github/commit-activity/t/untoldengine/UntoldEngine?style=flat-square&label=commits)
![Last Commit](https://img.shields.io/github/last-commit/untoldengine/UntoldEngine?style=flat-square&label=last+commit)

---

Untold Engine is a **Swift + Metal 3D engine for macOS, iOS, and visionOS** — with native Apple Vision Pro support and a growing focus on spatial computing — built for developers who:

- Want **full control over rendering and systems**
- Prefer working directly with **Swift + Metal**
- Are building **XR, 3D, or visualization applications**
- Need to handle **large scenes, streaming data, or custom pipelines**

If you've hit the ceiling of what existing engines allow on Apple platforms, this is for you.

![untoldengine-image](images/engine-highlight-5.png)

Creator & Lead Developer:  
[Harold Serrano](http://www.haroldserrano.com)

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

---

## 🚀 Try the Engine Right Now

The best first step is to run the Starter Demo. It is intentionally small and
shows the basic shape of an Untold Engine app without the extra systems used by
the larger showcase.

> **Recommendation:** Use the latest stable release instead of the `develop`
> branch. The `develop` branch is the bleeding-edge version of Untold Engine and
> is updated frequently, so it may contain unstable changes or regressions.

Clone the repository and launch the Starter Demo:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
git checkout v0.14.2
swift run StarterDemo
```

After that, run the focused demos based on what you want to learn:

| Demo | Command | Start here when you want to learn |
| --- | --- | --- |
| Starter Demo | `swift run StarterDemo` | The minimal app structure: renderer setup, camera, light, input, and a simple scene. |
| Interaction / Gameplay Demo | `swift run InteractionGameplayDemo` | Gameplay-style movement, input handling, animation switching, physics pause/resume, and parented entities. |
| Lighting Demo | `swift run LightingDemo` | All four light types — directional, point, spot, and area — with live intensity and cone-angle controls. |
| Rendering Quality Demo | `swift run RenderingQualityDemo` | Post-processing controls such as color grading, SSAO, bloom, vignette, depth of field, anti-aliasing, and debug views. |
| Large Scene Streaming Demo | `swift run LargeSceneStreamingDemo` | Manifest-driven tiled scene streaming, LOD, batching, streaming stats, and large-world traversal. |
| Exporter Pipeline Demo | `swift run ExporterPipelineDemo` | Loading exported `.untold` assets, applying exported animation clips, and checking validation metadata. |
| Showcase Demo | `swift run ShowcaseDemo` | A broader engine showcase that combines many systems in one app. Use this after the focused demos. |

The demos live under `Sources/Demos`. They are runnable when working inside the
engine repository, but are not exposed as products to apps that add Untold
Engine as a package dependency.

![untoldengine-image-2](images/engine-highlight-2.png)

---

![untoldengine-image-3](images/engine-highlight-4.png)

## Getting Started

To create your own project/game using the Untold Engine, see [Getting Started](API/GettingStarted.md).

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

## Current Features

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

## Roadmap

See open issues for planned features and known improvements.

- [Feature Requests](https://github.com/untoldengine/UntoldEngine/issues?q=label%3Aenhancement)
- [Bug Reports](https://github.com/untoldengine/UntoldEngine/issues?q=label%3Abug)

---

## Support

For help or questions, open a [GitHub Issue](https://github.com/untoldengine/UntoldEngine/issues).

---

## Contributing

Contributions are welcome — whether that's fixing bugs, improving systems, writing documentation, or proposing ideas.

Before submitting a pull request, please review the [Contributing Guidelines](Contributor/ContributionGuidelines.md).

All contributions are licensed under **MPL-2.0**.

---

## Contributor License Agreement

By submitting a pull request you agree that your contributions may be distributed under the **Mozilla Public License 2.0**. See [CONTRIBUTOR_LICENSE_AGREEMENT.md](https://github.com/untoldengine/UntoldEngine/blob/main/CONTRIBUTOR_LICENSE_AGREEMENT.md) for details.

---

## GitHub Sponsors

A huge thanks to the people helping shape the Untold Engine.

<p align="center">
  <a href="https://github.com/miolabs">
    <img src="images/top_contributors/MioLogo.png" alt="MioLabs" width="120"/>
  </a>
</p>

---

## License

Untold Engine is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

This allows developers to build commercial applications while ensuring improvements to the engine itself remain open.

| Use Case | Allowed | Obligation |
|----------|---------|-----------|
| Build games | Yes | Game code can remain proprietary |
| Commercial apps | Yes | No royalties |
| Modify engine | Yes | Modified engine files remain MPL |
| Create plugins | Yes | Any license allowed |

Full license: https://www.mozilla.org/MPL/2.0/

**Need to keep engine modifications private?** A commercial license is available for teams that require it. See [COMMERCIAL.md](https://github.com/untoldengine/UntoldEngine/blob/main/COMMERCIAL.md) for details.

---

## Trademark

"Untold Engine" and the Untold Engine logo are trademarks of **Untold Engine Studios**. Forks may not use the name in a way that implies official endorsement. See [TRADEMARKS.md](https://github.com/untoldengine/UntoldEngine/blob/main/TRADEMARKS.md).

---

## Questions & Discussions

- [GitHub Discussions](https://github.com/untoldengine/UntoldEngine/discussions) — ideas and questions
- [GitHub Issues](https://github.com/untoldengine/UntoldEngine/issues) — bugs and tasks
- [Ask a Question](https://github.com/untoldengine/UntoldEngine/issues/new?assignees=&labels=question&template=04_SUPPORT_QUESTION.md&title=support%3A+)
