---
id: ecs-create-custom-system
title: Create a Custom System
sidebar_position: 2
---

# Create a Custom System  

If you’ve created a **custom component**, you’ll usually also want to create a **custom system** to make it do something.  
Components store the data, but systems are where the behavior lives.  

The engine automatically calls systems every frame. A system typically:  

1. Resolves the component IDs it cares about  
2. Queries entities that have those components  
3. Reads and updates their state (transforms, physics, animation, etc.)  

This separation ensures components remain pure data containers, while systems drive the simulation.  

---

## Minimal Template  

Here’s a simple system that works with the `DribblinComponent` we defined earlier:  

```swift
public func dribblingSystemUpdate(deltaTime: Float) {
    // 1. Get the ID of the DribblinComponent
    let customId = getComponentId(for: DribblinComponent.self)

    // 2. Query all entities that have this component
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    // 3. Loop through each entity and update its data
    for entity in entities {
        guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entity) else {
            continue
        }

        // Example logic: move player in the dribbling direction
        dribblingComponent.direction = simd_normalize(dribblingComponent.direction)
        let displacement = dribblingComponent.direction * dribblingComponent.maxSpeed * deltaTime

        if let transform = scene.get(component: LocalTransformComponent.self, for: entity) {
            transform.position += displacement
        }
    }
}
```

## Registering the System
All custom systems must be registered during initialization so the engine knows to run them every frame:

```swift
registerCustomSystem(dribblingSystemUpdate)
```

