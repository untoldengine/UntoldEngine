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

[![Project license](https://img.shields.io/github/license/untoldengine/UntoldEngine.svg?style=flat-square)](LICENSE)

[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/untoldengine/UntoldEngine/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![code with love by untoldengine](https://img.shields.io/badge/%3C%2F%3E%20with%20%E2%99%A5%20by-untoldengine-ff1414.svg?style=flat-square)](https://github.com/untoldengine)

</div>

<details open="open">
<summary>Table of Contents</summary>

- [About](#about)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Controls](#controls)
- [Core API Functions](#Core-API-Functions)
- [Creating a quick game](#Creating-a-quick-game)
- [Deep Dive into the engine](#Deep-dive-into-the-engine)
- [Roadmap](#roadmap)
- [Support](#support)
- [Project assistance](#project-assistance)
- [Contributing](#contributing)
- [License](#license)
- [Common Issues](#common-issues)


</details>

---

## About

The Untold Engine is a 3D game engine for macOS/iOS devices, written in Swift and powered by Metal as its graphics library. Its primary goal is to simplify game development by providing an intuitive, easy-to-use API.

Author: [Harold Serrano](http://www.haroldserrano.com)

---

## Getting Started

### Prerequisites

To begin using the Untold Engine, you’ll need:

- An Apple computer.
- The latest version of Xcode, which you can download from the App Store.

### Installation

Follow these steps to set up and run the Untold Engine:

1. Clone the Repository

```bash
git clone https://github.com/untoldengine/UntoldEngine

cd UntoldEngine
```

2. Open the Swift Package

```bash
open Package.swift
```
3. Configure the Scheme in Xcode

- In Xcode, select the "UntoldEngineTestApp" scheme.
- Set "My Mac" as the target device.

![xcodescheme](images/selectingscheme.gif)

4. Click on Run

You should see models being rendered.

![gamesceneimage](images/gamescene1.png)

### Controls

The Untold Engine provides two distinct modes for interaction: **Edit Mode** and **Play Mode**. You can switch between these modes at any time by pressing the **P** key.

#### **Edit Mode**
In **Edit Mode**, you can navigate the scene and adjust the environment with ease using the following controls:

- **Orbit**: Click and drag to rotate the view around the scene.
- **Move**: 
  - Use the **W**, **A**, **S**, and **D** keys to move forward, backward, left, and right.
  - Use the **Q** and **E** keys to move vertically (up and down).
- **Zoom**: Pinch to zoom in or out for a closer or wider view.



#### **Play Mode**
In **Play Mode**, the scene comes to life! You will experience:

- Animated characters performing actions.
- Physics simulations running dynamically.

Toggle between Edit Mode and Play Mode with the **P** key to seamlessly explore or interact with the scene.

---

## Create your first game with the Untold Engine

To create a game with the Untold Engine, follow the steps outined here: [Create a MacOS Game](docs/CreateMacOSGame.md)

---

## Core API Functions

The Untold Engine API is designed to make game development straightforward and efficient. Its key strength lies in its clear and consistent naming conventions, enabling developers to focus on building their game logic without worrying about complex engine details.

At its core, the API revolves around the Entity-Component-System (ECS) architecture, where you create entities and enhance them with components like meshes, physics, collisions, and animations. Let's break down the most commonly used API functions.

1. createEntity()

This function generates a new entity.
Think of it as creating a "placeholder" object in your game world.

```swift
let myEntity = createEntity()
```

2. setEntityMesh()

Attach a visual representation (a model) to your entity.
This is where your 3D model comes to life.

```swift
setEntityMesh(entityId: myEntity, filename: "myModel", withExtension: "usdc")
```

3. setEntityKinetics()

Enable physics for your entity, allowing it to move, fall, or be affected by forces.

```swift
setEntityKinetics(entityId: myEntity)
```

4. setEntityAnimation()

Add animations to your entity.
You provide an animation file and name it for easy reference.

```swift
setEntityAnimations(entityId: myEntity, filename: "walkAnimation", withExtension: "usdc", name: "walking")
```

5. setParent()

Assign a parent entity to a child entity

```swift
setParent(childId: myChildEntity, parentId: myParentEntity) 
```

### An Example: Creating a Player Character

Here’s how the API comes together to build a fully interactive player character:

```swift
// Step 1: Create the entity
let player = createEntity()

// Step 2: Attach a mesh to represent the player visually
setEntityMesh(entityId: player, filename: "playerModel", withExtension: "usdc")

// Step 3: Enable physics for movement and gravity
setEntityKinetics(entityId: player)

// Step 4: Add collision detection for interacting with the world
setEntityCollision(entityId: player)

// Step 5: Add animations for walking and running
setEntityAnimations(entityId: player, filename: "walkingAnimation", withExtension: "usdc", name: "walking")
setEntityAnimations(entityId: player, filename: "runningAnimation", withExtension: "usdc", name: "running")

// Step 6: Play an animation
changeAnimation(entityId: player, name: "walking")
```

## Core Systems of the Untold Engine

The Untold Engine is built on a modular design, allowing you to utilize powerful systems for game development. Here’s an overview of each system:

1. Registration System
    - Handles the creation of entities and components.
    - Provides helper functions to set up components required by other systems.
    - Learn more: [Registration System](/docs/UsingRegistrationSystem.md)
2. Rendering System
    - Displays 3D models and supports Physically Based Rendering (PBR) for realistic visuals.
    - Works with lighting and shading to bring scenes to life.
    - Learn more: [Rendering System](/docs/UsingRenderingSystem.md)
3. Transform System
    - Manages entity positions, rotations, and scales.
    - Supports local and world transformations for hierarchical relationships.
    - Learn more: [Transform System](/docs/UsingTransformSystem.md)
4. Physics System
    - Simulates realistic movement with support for forces and gravity.
    - Prepares entities for collision detection.
    - Learn more: [Physics System](/docs/UsingPhysicsSystem.md)
5. Steering System
    - Provides intelligent movement behaviors, such as seeking, fleeing, and path-following.
    - Works seamlessly with the Physics System for smooth motion.
    - Learn more: [Steering System](/docs/UsingSteeringSystem.md)
6. Input System
    - Captures keyboard and mouse inputs to control entities or trigger actions.
    - Learn more: [Input System](/docs/UsingInputSystem.md)
7. Animation System
    - Animates rigged models using skeletal animations and blend trees.
    - Learn more: [Animation System](/docs/UsingAnimationSystem.md)

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

## Contributing Guidelines

I'm excited to have you contribute to the Untold Engine! To maintain consistency and quality, please follow these guidelines when submitting a pull request (PR). Submissions that do not adhere to these guidelines will not be approved.

### Required Contributions for New System Support

When adding new features or systems to the Untold Engine, your PR must include the following:

1. Unit Tests
- Requirement: All new systems must include XCTests to validate their functionality.
- Why: Tests ensure stability and prevent regressions when making future changes.
- Example: Provide unit tests that cover edge cases, typical use cases, and failure scenarios.

2. How-To Guide
- Requirement: Every new system must include a how-to guide explaining its usage.
- Why: This helps users understand how to integrate and utilize the feature effectively.
- Format: Use the structure outlined below to ensure consistency and clarity.

---

### How-To Guide Format

Your guide must follow this structure:

1. Introduction

- Briefly explain the feature and its purpose.
- Describe what problem it solves or what value it adds.

2. Why Use It

- Provide real-world examples or scenarios where the feature is useful.
- Explain the benefits of using the feature in these contexts.

3. Step-by-Step Implementation

- Break down the setup process into clear, actionable steps.
- Include well-commented code snippets for each step.

4. What Happens Behind the Scenes

- Provide technical insights into how the system works internally (if relevant).
- Explain any significant impacts on performance or functionality.

5. Tips and Best Practices

- Share advice for effective usage.
- Highlight common pitfalls and how to avoid them.

6. Running the Feature

- Explain how to test or interact with the feature after setup.

---

### Additional Notes

- Use concise and user-friendly language.
- Ensure all code examples are complete, tested, and follow the engine’s coding conventions.
- PRs must be documented in the /Documentation folder, with guides in markdown format.

---
Thank you for contributing to the Untold Engine! Following these guidelines will ensure that your work aligns with the project's goals and provides value to users.

## License

This project is licensed under the **LGPL v2.1**.

This means that if you develop a game using the Untold Engine, you do not need to open source your game. However, if you create a derivative of the Untold Engine, then you must apply the rules stated in the LGPL v2.1. That is, you must open source the derivative work.

---

## Common Issues

### ShaderType.h not found

Xcode may fail stating that it can't find a ShaderType.h file. If that is the case, simply go to your build settings, search for "bridging". Head over to 'Objective-C Bridging Header' and make sure to remove the path as shown in the image below

![bridgeheader](images/bridgingheader.png)

### Linker issues

Xcode may fail stating linker issues. If that is so, make sure to add the "Untold Engine" framework to **Link Binary With Libraries** under the **Build Phases** section.

![linkerissue](images/linkerissue.png)

