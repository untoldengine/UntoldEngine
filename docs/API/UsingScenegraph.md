# Scene Graph

The scene graph manages parent-child relationships between entities. A child keeps its own local transform, and the engine composes it with the parent's world transform during scene-graph updates.

Use parent-child relationships when entities should move as a group:

- A vehicle body with wheel children.
- A hand-held tool attached to a character hand.
- A marker, label, or interaction proxy attached to a loaded model.
- A group of objects that should keep a fixed relative layout.

## Create A Parent Relationship

```swift
let parent = createEntity()
let child = createEntity()

setEntityMeshAsync(entityId: parent, filename: "vehicle", withExtension: "untold")
setEntityMeshAsync(entityId: child, filename: "wheel", withExtension: "untold")

setParent(childId: child, parentId: parent)
```

After this call, transforms applied to `parent` affect `child`.

```swift
translateTo(entityId: parent, position: simd_float3(0.0, 0.0, -2.0))
rotateBy(entityId: parent, angle: 45.0, axis: simd_float3(0.0, 1.0, 0.0))
```

The child's transform remains local to the parent.

```swift
translateTo(entityId: child, position: simd_float3(0.6, -0.4, 0.8))
```

## Parent With An Offset

`setParent` accepts an optional local offset. This is useful when you want to attach an entity and place it relative to the parent in one call.

```swift
setParent(
    childId: child,
    parentId: parent,
    offset: simd_float3(0.6, -0.4, 0.8)
)
```

## Remove A Parent

Use `removeParent` when an entity should stop inheriting from its parent.

```swift
removeParent(childId: child)
```

The entity remains alive; only the scene-graph relationship is removed.

## Query Relationships

Use the query helpers when gameplay code needs to inspect the hierarchy.

```swift
let children = getEntityChildren(parentId: parent)
let currentParent = getEntityParent(entityId: child)
```

`getEntityParent` returns `nil` when the entity is not parented.

## Loaded Assets

`.untold` assets can create multiple entities when they preserve hierarchy. You can still parent the root entity to another gameplay entity:

```swift
let roomAnchor = createEntity()
let room = createEntity()

setEntityMeshAsync(entityId: room, filename: "room", withExtension: "untold") { success in
    guard success else { return }
    setParent(childId: room, parentId: roomAnchor)
}
```

If you need to find a named child exported from Blender, use entity names:

```swift
if let door = findEntity(name: "Door_Main") {
    setParent(childId: door, parentId: roomAnchor)
}
```

## Scene Builder

`UntoldView` and `SceneBuilder` create parent relationships automatically for nested nodes:

```swift
MeshNode(resource: "vehicle.untold", name: "Vehicle") {
    CubeNode(size: 0.25, name: "Marker")
        .translateTo(x: 0.0, y: 1.25, z: 0.0)
}
```

See [Scene Builder / UntoldView](UsingSceneBuilder.md) for the declarative scene setup workflow.
