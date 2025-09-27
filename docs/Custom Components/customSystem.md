---
id: ecs-create-custom-system
title: Create a Custom System
sidebar_position: 2
---

# Create a Custom System

A **System** is a function the engine calls every frame. It:
1) Resolves the component IDs it cares about  
2) Queries matching entities  
3) Updates state (transforms, physics, animation, etc.)

---

## Minimal Template

```swift

public func dribblingSystemUpdate(deltaTime: Float) {

    let customId = getComponentId(for: DribblinComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    for entity in entities {
        guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entity) else {
            continue

        // your code
    }

```

You must register the system during init by calling the following function:

```swift
registerCustomSystem(dribblingSystemUpdate)
```

