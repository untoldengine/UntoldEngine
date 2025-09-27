---
id: ecs-create-custom-component
title: Create a Custom Component
sidebar_position: 1
---

# Create a Custom Component

Components are **data-only** objects you attach to entities. They should hold state, not behavior.  
They must conform to `Component` and `Codable` (if you want to use them through the editor), and include a `public required init()`.

---

## Minimal Template

```swift

public class DribblinComponent: Component, Codable {
    public required init() {}
    var maxSpeed: Float = 5.0
    var kickSpeed: Float = 15.0
    var direction: simd_float3 = .zero
}

```

### Attach component to entity

```
let player = createEntity(name: "player")
registerComponent(entityId: player, componentType: DribblinComponent.self)

if let c = scene.get(component: DribblinComponent.self, for: player) {
    c.maxSpeed = 6.5
    c.kickSpeed = 18.0
}

```
