---
id: editor-integration-components
title: Editor Integration for Custom Components
sidebar_position: 3
---

# Editor Integration for Custom Components

> You can build your game **with or without the Editor**.  
> If you want your **custom component** to appear in the Editor’s **Inspector**, it must:
> 1) conform to `Component`, and  
> 2) **also conform to `Codable`** (so it can be displayed and saved/loaded).

In addition, you’ll define a `ComponentOption_Editor` so the Editor knows how to show its fields, and register serialization so your component persists with scenes.

---

## 1) Make Your Component Codable

```swift
import simd

public class DribblinComponent: Component, Codable {
    public required init() {}

    // Public stored properties are discoverable & serializable
    public var maxSpeed: Float = 5.0
    public var kickSpeed: Float = 15.0
    public var direction: simd_float3 = .zero
}
```


## Define the Editor Option

A `ComponentOption_Editor` describes how your component appears in the Add Component menu and how its fields are edited.

- **id**: `getComponentId(for:)`
- **name**: how it appears in the “Add Component” menu
- **type**: your component class type
- **view**: UI built with `makeEditorView(fields:)` (e.g., `.number`, `.vector3`)
- **onAdd**: code to attach the component when the user adds it


```swift

var DribblingComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: DribblinComponent.self),
    name: "Dribbling Component",
    type: DribblinComponent.self,
    view: makeEditorView(fields: [
        .number(
            label: "Max Speed",
            get: { eid in getMaxSpeed(entityId: eid) },
            set: { eid, v in setMaxSpeed(entityId: eid, maxSpeed: v) }
        ),
        .number(
            label: "Kick Speed",
            get: { eid in getKickSpeed(entityId: eid) },
            set: { eid, v in setKickSpeed(entityId: eid, maxSpeed: v) }
        ),
        .vector3(
            label: "Direction",
            get: { eid in getPlayerDirection(entityId: eid) },
            set: { eid, vec in setPlayerDirection(entityId: eid, direction: vec) }
        ),
    ]),
    onAdd: { eid in
        registerComponent(entityId: eid, componentType: DribblinComponent.self)
    }
)
```

Register it at startup (so it shows in the Editor’s Add Components menu):

```swift
addComponent_Editor(componentOption: DribblingComponent_Editor)
```

## Register Serialization (Save/Load)

Register how the engine merges decoded data into the live component during scene load:

```swift
encodeCustomComponent(
            type: DribblinComponent.self,
            merge: { current, decoded in
                current.maxSpeed = decoded.maxSpeed
                current.kickSpeed = decoded.kickSpeed
                current.direction = decoded.direction
            }
        )
```
