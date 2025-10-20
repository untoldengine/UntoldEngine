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
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [Support](#support)
- [Project assistance](#project-assistance)
- [Contributing](#contributing)
- [Top Contributors](#top-contributors)
- [License](#license)


</details>

---

## About

The Untold Engine strives to be a **stable, performant, and developer-friendly** 3D engine that empowers creativity, removes friction, and makes game development feel effortless for Apple developers

The Untold Engine is an open-source 3D game engine under active development, designed for macOS and iOS platforms. Written in Swift and powered by Metal, its goal is to simplify game creation with a clean, intuitive API. While the engine already supports many core systems like rendering, physics, and animation, there’s still much to build and improve.

Creator & Lead Developer: [Harold Serrano](http://www.haroldserrano.com)

Click on image to play video:

[![Watch the video](images/enginethumbnail.jpg)](https://vimeo.com/1116239409?share=copy#t=0)

## Current Features:
- Cross-Platform Support: Runs on macOS, iOS, and visionOS using a unified Swift + Metal codebase.
- Modern Renderer: Built on Metal with support for PBR materials, IBL, post-processing effects, and efficient GPU resource management.
- Entity–Component–System (ECS): Lightweight ECS architecture for organizing game logic and behaviors cleanly.
- Scene Graph: Hierarchical transformation system for managing parent–child relationships between entities.
- Physics System: Includes Euler integration, motion systems, and component-based extensibility for collisions and constraints.
- Animation System: Supports skeletal animations and reusable animation clips.
- Input System: Unified keyboard, mouse, and touch input handling (with controller support planned).
- Untold Editor Integration: Optional visual editor for managing assets, entities, and scenes.
- Swift Package Manager (SPM): Fully modular — integrate it easily into your own Xcode or Swift projects.
- Open Source & Extensible: Licensed under LGPL-3.0, encouraging collaboration and custom extensions.

## The Journey Ahead:

The Untold Engine is a work in progress, with ambitious goals to:

- Extend the physics and collision system.
- Add advanced lighting and reflections.
- Expand XR and input support for visionOS.
- Improve workflow between the engine, editor, and asset pipeline.

## Documentation & Quick Start

### Quick Start
If you just want to **try the engine right away**, check out the demo games in our companion repo:  
👉 [UntoldArcade](https://github.com/untoldengine/UntoldArcade)  

Clone it, open the Xcode workspace, and you’ll be able to run a demo game (like **SoccerArcade**) immediately.

### Full Documentation

If you’re interested in learning more about the engine itself — how it works, how to build with it, and the full API — head over to our official documentation site:  
👉 [Untold Engine Docs](https://untoldengine.github.io/UntoldEngine)

There you’ll find:
- Installation & setup
- Editor overview
- How-to guides (import assets, add models, use systems)
- API references & examples

⚡ New to the engine? Start with the **Getting Started** guide in the docs.

---

## Untold Editor

The **Untold Editor** is a companion tool for the Untold Engine.  
It provides a visual environment for managing assets, scenes, and entities in projects built with the engine.  

The editor is not required to use the engine, but it makes iteration faster by giving developers and designers a user-friendly interface. [Untold Editor](https://github.com/untoldengine/UntoldEditor)

![UntoldEditorScreenshot](images/editorscreenshot.png)

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
    <img src="images/top_contributors/MioLogo.png" alt="MioLabs" width="120"/>
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
 
