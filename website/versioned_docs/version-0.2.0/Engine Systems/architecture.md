---
id: architecture
title: Architecture 
sidebar_position: 1
---

# Untold Engine Architecture — Summary  

Untold Engine is built on a **data-oriented Entity–Component–System (ECS)** architecture designed for clarity, performance, and extensibility.  

- **Entities**  
  Entities are lightweight IDs. They have no behavior or state on their own.  

- **Components**  
  Components are plain data containers attached to entities. They describe an entity’s properties or capabilities (e.g., `Transform`, `Mesh`, `Light`, `Dribbling`).  
  - Components are the **primary way to add new behavior** in Untold Engine.  
  - All components are serializable and editor-friendly, so they can be saved, loaded, and modified at runtime.  

- **Systems**  
  Systems are stateless functions that run each frame. They query entities with specific components, read and update their data, and drive the simulation.  
  - Example: a **DribblingSystem** looks for entities with a `DribblingComponent`, updates their animations and movement based on input, and interacts with the ball.  

- **Editor Integration**  
  Because components are declarative and Codable, they are automatically exposed to the Editor. Developers and designers can attach/remove components, tweak fields in the Inspector, and see changes take effect instantly when switching to Play Mode.  

This separation of entities, components, and systems keeps the codebase modular, testable, and cache-friendly. New features are added by creating **a new component (data) + a system (logic)**, without modifying the engine core.  

