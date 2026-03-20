---
id: transformsystem
title: Transform System
sidebar_position: 3
---

# Using the Transform System in Untold Engine

The Transform System is a core part of the Untold Engine, responsible for managing the position, rotation, and scale of entities. It provides both local transformations (relative to a parent entity) and world transformations (absolute in the scene).

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

### Step 3: Translate the Entire Scene

These functions move the **scene root** without modifying individual entity transforms. Because per-entity transforms stay untouched, static batches remain intact and no rebatching is needed.

#### Move Scene to an Absolute Position

```swift
translateSceneTo(position: simd_float3(10.0, 0.0, 5.0))
```

#### Move Scene by a Relative Offset

```swift
translateSceneBy(delta: simd_float3(1.0, 0.0, 0.0))
```

Use these when you need to pan or reposition the entire world — for example, sliding a map or architectural model during a spatial drag gesture.

---

### Step 4: Rotate the Entire Scene (Yaw)

These functions rotate the **scene root** around world up (`+Y`) without modifying individual entity transforms. Static batches remain intact and no rebatching is required.

#### Rotate Scene to an Absolute Yaw

```swift
rotateSceneToYaw(.pi / 2.0)
```

#### Rotate Scene by a Relative Yaw Delta

```swift
rotateSceneByYaw(.pi / 18.0) // +10 degrees
```

Use these when you need to align or calibrate a large loaded scene in-place (for example, Vision Pro room alignment) while keeping batching and culling efficient.

---

### Step 5: Scene-Root Space Conversion and Reset Helpers

Use these helpers when converting between scene-local/entity space and visual world space:

```swift
let visual = sceneLocalToVisualWorld(simd_float3(1, 0, 0))
let local = visualWorldToSceneLocal(visual)
```

To get an entity's visual world position (with scene-root transform applied):

```swift
let visualPosition = getVisualPosition(entityId: myEntity)
```

To return scene root to identity quickly:

```swift
resetSceneRootTransform()
```

This resets position/rotation/scale and refreshes root matrices immediately.

---

## Tips and Best Practices
- Use Local Transformations for Hierarchies:
    - For example, a car’s wheels (children) should use local transforms relative to the car body (parent).
- Combine Translations and Rotations:
    - Use translateTo to set an entity's absolute position or rotation.
    - Use translateBy for incremental adjustments.
- Use Scene-Level Translation for Batch-Safe Movement:
    - Use `translateSceneTo` / `translateSceneBy` instead of moving every entity individually.
    - This avoids breaking static batches and is ideal for spatial drag gestures on the whole scene.
- Use Scene-Level Yaw Rotation for Batch-Safe Alignment:
    - Use `rotateSceneToYaw` / `rotateSceneByYaw` to rotate large scenes around world up.
    - This is ideal for scene alignment and calibration flows where static batching must stay active.
