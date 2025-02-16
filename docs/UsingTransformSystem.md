# Using the Transform System in Untold Engine

The Transform System is a core part of the Untold Engine, responsible for managing the position, rotation, and scale of entities. It provides both local transformations (relative to a parent entity) and world transformations (absolute in the scene).

## Why Use the Transform System?

The Transform System is essential for positioning and orienting entities in your scene. It ensures entities move, rotate, and scale correctly while maintaining hierarchical relationships in a scene graph.

## Key Features:
- Retrieve Transform Data: Access local or world positions, orientations, and axis vectors.
- Update Transform Data: Modify an entity’s position or rotation with ease.
- Hierarchical Transformations: Manage transformations relative to parent entities for complex object hierarchies.

---

## How to Use the Transform System

### Step 1: Retrieve Transform Data
You can retrieve an entity’s position, orientation, or axis vectors using the provided functions.

#### Get Local Position

Retrieves the entity’s position relative to its parent.

```swift
let localPosition = getLocalPosition(entityId: entity)
```

#### Get World Position

Retrieves the entity’s absolute position in the scene.

```swift
let worldPosition = getPosition(entityId: entity)
```

#### Get Local Orientation

Retrieves the entity’s orientation matrix relative to its parent.

```swift
let localOrientation = getLocalOrientation(entityId: entity)
```

#### Get World Orientation

Retrieves the entity’s absolute orientation matrix.

```swift
let worldOrientation = getOrientation(entityId: entity)
```

#### Get Axis Vectors

Retrieve the entity’s forward, right, or up axis:

```swift
let forward = getForwardAxisVector(entityId: entity)
let right = getRightAxisVector(entityId: entity)
let up = getUpAxisVector(entityId: entity)
```

---

### Step 2: Update Transform Data

Modify an entity’s transform by translating or rotating it.

#### Translate the Entity

Move the entity to a new position:

```swift
translateTo(entityId: entity, position: simd_float3(5.0, 0.0, 3.0))
```

Move the entity by an offset relative to its current position:

```swift
translateBy(entityId: entity, position: simd_float3(1.0, 0.0, 0.0))
```

#### Rotate the Entity

Rotate the entity to a specific angle around an axis:

```swift
rotateTo(entityId: entity, angle: 45.0, axis: simd_float3(0.0, 1.0, 0.0))
```

Apply an incremental rotation to the entity:

```swift
rotateBy(entityId: entity, angle: 15.0, axis: simd_float3(0.0, 1.0, 0.0))
```

Directly set the entity’s rotation matrix:

```swift
rotateTo(entityId: entity, rotation: simd_float4x4( /* matrix values */ ))
```

---

## What Happens Behind the Scenes?

1. Local and World Transform Components:
- Each entity has a LocalTransformComponent for transformations relative to its parent.
- The WorldTransformComponent calculates the absolute transform by combining the local transform with the parent’s world transform.
2. Transform Matrices:
- Transformations are stored in 4x4 matrices that include position, rotation, and scale.
- These matrices are updated whenever you translate or rotate an entity.
3. Scene Graph Integration:
- Changes to a parent entity automatically propagate to its children through the scene graph.

---

## Tips and Best Practices
- Use Local Transformations for Hierarchies:
    - For example, a car’s wheels (children) should use local transforms relative to the car body (parent).
- Combine Translations and Rotations:
    - Use translateTo or rotateTo to set an entity’s absolute position or rotation.
    - Use translateBy or rotateBy for incremental adjustments.
