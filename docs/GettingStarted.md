# Getting Started with Untold Engine

Welcome to the Untold Engine! This guide will introduce you to the core systems of the engine and provide links to detailed tutorials for each. If you’re ready to set up your first macOS project, follow the link at the end to the Creating a macOS Game guide.

---

## Core Systems of the Untold Engine

The Untold Engine is built on a modular design, allowing you to utilize powerful systems for game development. Here’s an overview of each system:

1. Registration System
    - Handles the creation of entities and components.
    - Provides helper functions to set up components required by other systems.
    - Learn more: [Registration System](UsingRegistrationSystem.md)
2. Rendering System
    - Displays 3D models and supports Physically Based Rendering (PBR) for realistic visuals.
    - Works with lighting and shading to bring scenes to life.
    - Learn more: [Rendering System](UsingRenderingSystem.md)
3. Transform System
    - Manages entity positions, rotations, and scales.
    - Supports local and world transformations for hierarchical relationships.
    - Learn more: [Transform System](UsingTransformSystem.md)
4. Physics System
    - Simulates realistic movement with support for forces and gravity.
    - Prepares entities for collision detection.
    - Learn more: [Physics System](UsingPhysicsSystem.md)
5. Steering System
    - Provides intelligent movement behaviors, such as seeking, fleeing, and path-following.
    - Works seamlessly with the Physics System for smooth motion.
    - Learn more: [Steering System](UsingSteeringSystem.md)
6. Input System
    - Captures keyboard and mouse inputs to control entities or trigger actions.
    - Learn more: [Input System](UsingInputSystem.md)
7. Animation System
    - Animates rigged models using skeletal animations and blend trees.
    - Learn more: [Animation System](UsingAnimationSystem.md)

---

## Next Steps: Setting Up a macOS Project

To start building games with the Untold Engine on macOS, you’ll need to set up a new project in Xcode and integrate the engine.

### Follow the detailed guide here: [Create a macOS Game in Xcode](creategamemacos.md)
This guide includes:

- Creating a new macOS game project in Xcode.
- Integrating the Untold Engine package.
- Setting up the boilerplate code for your game.

---

## Frequently Asked Questions (FAQ)

What programming language does the engine use?
The Untold Engine is written in Swift, and you will use Swift for game development.

Is the engine cross-platform?
Currently, the engine is optimized for macOS but has plans for cross-platform support.

Can I contribute to the engine?
Yes! Contributions are welcome. Check out the Contribution Guidelines for more details.

---
## Ready to Start?

Explore the individual system tutorials above or jump straight into creating your first game:

[Create a macOS Game in Xcode](creategamemacos)

Let us know if you encounter any issues—happy game developing!
