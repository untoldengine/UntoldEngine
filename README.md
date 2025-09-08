<h1 align="center">
  <a href="https://github.com/untoldengine/UntoldEngine">
    <!-- Please provide path to your logo here -->
    <img src="images/untoldenginewhite.png" alt="Logo" width="459" height="53">
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
- [Getting Started](#getting-started)
- [High-Level API Overview](#High-Level-API-Overview)
- [Using the Untold Engine](#Using-the-Untold-Engine)
- [Visuals](#visuals)
- [Roadmap](#roadmap)
- [Support](#support)
- [Project assistance](#project-assistance)
- [Contributing](#contributing)
- [License](#license)
- [Common Issues](#common-issues)


</details>

---

## About

> "A Swift-based 3D game engine designed for simplicity and creativity on macOS and iOS."

The Untold Engine is an open-source 3D game engine under active development, designed for macOS and iOS platforms. Written in Swift and powered by Metal, its goal is to simplify game creation with a clean, intuitive API. While the engine already supports many core systems like rendering, physics, and animation, there’s still much to build and improve.

Click on image to play video:

[![Watch the video](images/enginethumbnail.jpg)](https://vimeo.com/1116239409?share=copy#t=0)


### Current Features:

- Simple API: Focused on ease of use, even for those new to game development.
- Core Systems: Includes foundational systems for entity registration, rendering, physics, and more.
- Metal Integration: Leverages Apple’s graphics API for efficient rendering.

### The Journey Ahead:

The Untold Engine is a work in progress, with ambitious goals to:

- Expand physics capabilities with collision detection.
- Enhance PBR rendering for more realistic visuals.
- Add new features to make game development a breeze.

### Why Try the Untold Engine?

- For Learners: A great way to explore game development with an engine that prioritizes simplicity.
- For Game Developers: An opportunity to contribute to an open-source project and shape its future.
- For Apple Developers: A Swift and Metal-based engine that feels at home on macOS and iOS.

The engine is far from complete, but with every iteration, it gets closer to being an amazing tool for developers. By trying it out, contributing, or sharing your feedback, you can help make the Untold Engine better for everyone.

Author: [Harold Serrano](http://www.haroldserrano.com)

---

## Getting Started

The Untold Engine is a game engine designed to be integrated into your game projects. It is distributed as a Swift Package using Swift Package Manager (SPM) for easy integration and maintenance.

There are two primary ways to use the engine:

- **Running the Engine Standalone** – Ideal for contributors and developers who want to explore, modify, or contribute to the engine itself. This mode allows you to test the engine independently using its built-in demo assets and functionalities.
- **Integrating the Engine into Your Game Project** – Perfect for game developers who want to build a game using the engine. This requires adding the engine as a Swift Package Dependency in a game project.

### Prerequisites

To begin using the Untold Engine, you’ll need:

- An Apple computer.
- The latest version of Xcode, which you can download from the App Store.

### Installation
Follow the step-by-step guide to [clone and install the Untold Engine](docs/Installation.md)

### Assets Download 
To help you get started, download the [Demo Game Assets v1.0](https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1). It contains models and animations that you can use as you try out the engine. Unzip the folder and place it on your Desktop.

### Demo Game - Jump right in
Want to see the Untold Engine in action with zero setup? The **Demo Game** is for you! It’s a simple, ready-to-run soccer dribbling game — perfect for testing the engine and getting a feel for how it works. Follow the step-by-step guide to run the [small demo](docs/demogamesteps.md)

### Starter Game - Experiment and Learn
If you want to tinker and get hands-on, the **Starter Game** is your playground. It’s a minimal setup that gives you just enough to start experimenting, importing assets, and building your own mechanics. Follow the step-by-step guide to run the [starter game](docs/startergamesteps.md)

For an overview of how to reference entities, play animations, and create components and systems, check out the files in the DemoGame folder. More documentation is on the way, but these examples should be enough to help you get started.
If you run into any issues or have questions, please don’t hesitate to open an [issue](https://github.com/untoldengine/UntoldEngine/issues).

### Editor & Workflow

The Editor is now the primary way to initialize and manage entities.  

- [Editor Overview](docs/editoroverview.md): Walkthrough of Scene Graph, Inspector, Gizmos, Materials, Lighting, Post-Processing, Asset Browser, and Console.  
- [How to Import Assets](docs/importingassetseditor.md): Learn how to set asset paths and import models, materials, and animations.  
- [Adding a model using the Editor](docs/addModelUsingEditor.md): Learn how to add a model using the editor 
- [Adding an animation using the Editor](docs/addAnimationUsingEditor.md): Learn how to link an animation to the model using the editor (Coming Soon)

⚠️ **Important**: Entities should be created and configured in the Editor. Code is used for gameplay logic only.  

---

## High-Level API Overview

The Untold Engine offers an intuitive API for game development. Here's a quick look:

```swift
let stadium = createEntity()
setEntityMesh(entityId: stadium, filename: "stadium", withExtension: "usdc")
translateBy(entityId: stadium, position: simd_float3(0.0, 0.0, 0.0))

let player = createEntity()
setEntityMesh(entityId: player, filename: "redplayer", withExtension: "usdc", flip: false)
setEntityAnimations(entityId: player, filename: "running", withExtension: "usdc", name: "running")
changeAnimation(entityId: player, name: "running") // Start animation
setEntityKinetics(entityId: player) // Enable Physics System
```
---

## Using the Untold Engine

The Untold Engine is powered by modular systems that simplify game development. Click on the links to get started.

- [Registration-ECS System](docs/UsingRegistrationSystem.md): Handles the creation of entities and components
- [Rendering System](docs/UsingRenderingSystem.md): Render 3D models with support for PBR and custom shaders.
- [Transform System](docs/UsingTransformSystem.md): Manage entity positions, rotations, and scales.
- [Animation System](docs/UsingAnimationSystem.md): Add life to your models with skeletal animations.
- [Physics System](docs/UsingPhysicsSystem.md): Simulate gravity, forces, and movement.
- [Input System](docs/UsingInputSystem.md): Capture keyboard and mouse interactions.
- [Steering System](docs/UsingSteeringSystem.md): Implement intelligent behaviors like path-following.
- [Scenegraph](docs/UsingScenegraph.md): Enables parent-child relationships between entities
- [Shaders](docs/shaders.md): Add or modify shaders to fit your game's stye.

- [Importing Assets](docs/ImportingAssetFiles.md): Importing assets into your game project
---

## Visuals

Here are some examples of what the Untold Engine can do, showing its progress and current features in action.

![Alt text](images/camera.png)
![Alt text](images/f1car.png)
![Alt text](images/city.png)

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

See the [Contribution Guidelines](docs/ContributionGuidelines.md) for details.

---

## License

This project is licensed under the **LGPL v2.1**.

### What Does This Mean for You?
- **Developing a Game**: You can use the Untold Engine to build your game without needing to open source your game’s code.
- **Modifying the Engine**: If you make changes to the engine itself, those changes must be open-sourced under the LGPL v2.1.

For more details, see the full license text [here](https://www.gnu.org/licenses/lgpl-2.1.html).

---
 
