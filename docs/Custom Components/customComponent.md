---
id: ecs-create-custom-component
title: Create a Custom Component
sidebar_position: 1
---

# Create a Custom Component  

In your game, you may want to **extend functionality to an entity**.  
You can do this by creating a **custom component**.  

Components in the Untold Engine are **data-only objects** that you attach to entities.  
They should hold **state, not behavior**. All game logic is handled in systems.  

Every custom component must conform to the `Component` protocol.  

By following this design, your game stays modular:  
- **Components** define what an entity *is capable of*.  
- **Systems** define *how that capability behaves*.  

---

## Minimal Template  

Here’s an example of a simple custom component for a soccer player’s dribbling behavior:  

```swift
public class DribblinComponent: Component {
    public required init() {}
    var maxSpeed: Float = 5.0
    var kickSpeed: Float = 15.0
    var direction: simd_float3 = .zero
}
```

> ⚠️ Note: Components should not include functions or game logic. Keep them as pure data containers.

## Attaching a Component to an Entity

Once you’ve defined a component, you attach it to an entity in your scene:

```swift
let player = createEntity(name: "player")

// Attach DribblinComponent to the entity
registerComponent(entityId: player, componentType: DribblinComponent.self)

// Access and modify component data
if let c = scene.get(component: DribblinComponent.self, for: player) {
    c.maxSpeed = 6.5
    c.kickSpeed = 18.0
}

```

This example creates a new entity called player, attaches a DribblinComponent, and updates its values.


On its own, the component just stores numbers — it doesn’t do anything yet.
To make the player actually dribble, you’ll need to implement a system that processes this component each frame.
