---
layout: page
title: ECS-Registration
permalink: /registration/
nav_order: 6
---

#  Using the Registration System in Untold Engine

The Registration System in the Untold Engine is an integral part of its Entity-Component-System (ECS) architecture. It provides core functionalities to manage entities and components, such as:

- Creating and destroying entities.
- Registering components to entities.
- Setting up helper functions for other systems by configuring necessary components.

This guide will walk you through using the Registration System effectively.

## Why Use the Registration System?

The Registration System simplifies entity and component management, which is crucial for the ECS architecture. It ensures that entities have the appropriate components required for different systems like rendering, physics, and animation.

Key Benefits:
- Scalability: Easily create and manage thousands of entities and their components.
- Flexibility: Dynamically add or remove components as needed.
- System Integration: Automates setup for other systems by registering default or specialized components.

---

## How to Use the Registration System

### Step 1: Create an Entity

Entities represent objects in the scene. Use the createEntity() function to create a new entity.

```swift
let entity = createEntity()
```

---

### Step 2: Register Components

Components define the behavior or attributes of an entity. Use registerComponent to add a component to an entity.

```swift
registerComponent(entityId: entity, componentType: RenderComponent.self)
```
Example:

When you load a mesh for rendering, the system automatically registers the required components:

```swift
setEntityMesh(entityId: entity, filename: "model", withExtension: "usdc")
```

This function:

- Loads the mesh from the specified .usdc file.
- Associates the mesh with the entity.
- Registers default components like RenderComponent and TransformComponent.

---

### Step 3: Destroy an Entity

To remove an entity and its components from the scene, use destroyEntity.

```swift
destroyEntity(entityId: entity)
```

This ensures the entity is properly removed from all systems.

---

## What Happens Behind the Scenes?

1. Entity Management:
- createEntity generates a new entity ID and registers it in the scene graph.
- destroyEntity removes the entity and cleans up its associated components.
2. Component Registration:
- Components are registered dynamically based on system requirements.
- Default components like RenderComponent, TransformComponent, and ScenegraphComponent are added automatically for rendering.
3. System Setup:
- Specialized functions like setEntityMesh or setEntitySkeleton handle specific setups, ensuring the entity is ready for rendering or animation.


