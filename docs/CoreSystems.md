# Core Systems of the Untold Engine

The Untold Engine is built on a modular design, allowing you to utilize powerful systems for game development. Here’s an overview of each system:

1. Registration System
    - Handles the creation of entities and components.
    - Provides helper functions to set up components required by other systems.
    - Learn more: [Registration System](../docs/UsingRegistrationSystem.md)
2. Rendering System
    - Displays 3D models and supports Physically Based Rendering (PBR) for realistic visuals.
    - Works with lighting and shading to bring scenes to life.
    - Learn more: [Rendering System](../docs/UsingRenderingSystem.md)
3. Transform System
    - Manages entity positions, rotations, and scales.
    - Supports local and world transformations for hierarchical relationships.
    - Learn more: [Transform System](../docs/UsingTransformSystem.md)
4. Physics System
    - Simulates realistic movement with support for forces and gravity.
    - Prepares entities for collision detection.
    - Learn more: [Physics System](../docs/UsingPhysicsSystem.md)
5. Steering System
    - Provides intelligent movement behaviors, such as seeking, fleeing, and path-following.
    - Works seamlessly with the Physics System for smooth motion.
    - Learn more: [Steering System](../docs/UsingSteeringSystem.md)
6. Input System
    - Captures keyboard and mouse inputs to control entities or trigger actions.
    - Learn more: [Input System](../docs/UsingInputSystem.md)
7. Animation System
    - Animates rigged models using skeletal animations and blend trees.
    - Learn more: [Animation System](../docs/UsingAnimationSystem.md)
