---
id: architecture
title: Architecture 
sidebar_position: 1
---

# Untold Engine Architecture

The Untold Engine is built on a **data-oriented Entity–Component–System (ECS)** architecture. This design keeps the engine simple, performant, and easy to extend as your game grows.  

## Entities  
Entities are nothing more than lightweight IDs. They don’t hold behavior or state themselves—think of them as labels that tie everything together.  

## Components  
Components are plain data structures that describe what an entity can do. They hold no logic, only data. For example:  

- `LocalTransformComponent` → position, rotation, scale  
- `RenderComponent` → what model to render  
- `PhysicsComponent` → mass, velocity, collision data  
- `AnimationComponent` → animation clips or state  

These default components give you rendering, physics, and animation support out of the box.  

## Systems  
Systems are the logic layer. Each system runs every frame, looks for entities with specific components, and updates them. For example:  

- The **PhysicsSystem** finds all entities with a `PhysicsComponent` and updates their motion.  
- The **AnimationSystem** updates entities with an `AnimationComponent`.  
- You can also create custom systems, like a `DribblingSystem` that updates a player’s dribbling behavior using a `DribblingComponent`.  

## Extending the Engine  
During game development, you’ll often want to extend a character or object with new abilities. You can do this by:  

1. Creating a **new component** that defines the data you need.  
2. Creating a **system** that processes that component and applies the logic.  

---

This separation of entities, components, and systems keeps the code modular and flexible. To add new features, you don’t need to modify the engine core—you just add new components (data) and systems (logic).  

Take a few moments to familiarize yourself with the Untold Engine's default systems and how to extend functionality by implementing custom components and systems.

You can develop your game **with or without the Untold Engine's editor**. The default components are visible through the editor. However, custom components won’t be available by default. To make them available, please see the section on **Custom Components & Systems**.  

