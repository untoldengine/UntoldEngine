---
layout: page
title: Scenegraph
permalink: /scenegraph/
nav_order: 12
---

#  Adding Parent-Child Relationships in Untold Engine

The Untold Engine includes a Scene Graph data structure, designed to manage hierarchical transformations efficiently. This enables parent-child relationships between entities, where a child's transformation (position, rotation, scale) is relative to its parent. For example, a car's wheels (children) move and rotate relative to the car body (parent).

## Why Use Parent-Child Relationships?

Parent-child relationships are useful when you want multiple entities to move or transform together. When a parent entity changes its position, rotation, or scale, its child entities inherit those changes automatically. This is ideal for scenarios like:

- A car (parent) and its wheels (children)
- A robot (parent) with movable arms and legs (children)
- A group of objects that should remain in a fixed configuration relative to each other

## Assigning Parent-Child Relationships

To assign a parent to an entity, use the setParent function. This function establishes a hierarchical relationship between the specified entities.

```swift
// Create child and parent entities
let childEntity = createEntity()
let parentEntity = createEntity()

// Set parent-child relationship
setParent(childId: childEntity, parentId: parentEntity)
```

## What Happens Behind the Scenes?

1. Transformation Inheritance:
- Once the relationship is established, any transformation applied to the parent entity (e.g., movement, rotation) will automatically affect the child entity.
- The child’s transformation is expressed relative to the parent.

2. Independent Local Transformations:
- While the child inherits the parent's transformations, it can also have its own independent local transformations, such as offset positions or rotations relative to the parent.


