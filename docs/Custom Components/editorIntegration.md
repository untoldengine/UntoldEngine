---
id: editor-integration-components
title: Editor Integration for Custom Components
sidebar_position: 3
---

# Editor Integration for Custom Components

Make your component discoverable and editable in the Editor’s **Inspector** by declaring a `ComponentOption_Editor` and registering it.  

Also register serialization so your component **saves/loads** with scenes.

---

## Define the Editor Option

A `ComponentOption_Editor` includes:

- **id**: `getComponentId(for:)`
- **name**: how it appears in the “Add Component” menu
- **type**: your component class type
- **view**: UI built with `makeEditorView(fields:)` (e.g., `.number`, `.vector3`)
- **onAdd**: code to attach the component when the user adds it

### Example (`DribblinComponent`)


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

In your init function, you add the component so that it shows up in the editor as follows:

```swift
addComponent_Editor(componentOption: DribblingComponent_Editor)
```

Finally, to allow your componen to be saved/loaded, you encode it as follows:

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
