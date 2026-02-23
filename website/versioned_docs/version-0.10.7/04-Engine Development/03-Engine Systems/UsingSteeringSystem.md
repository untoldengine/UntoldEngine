---
id: steeringsystem
title: Steering System
sidebar_position: 7
---

# Using the Steering System in Untold Engine

The Steering System in the Untold Engine enables entities to move dynamically and intelligently within the scene. It provides both low-level steering behaviors (e.g., seek, flee, arrive) for granular control and high-level behaviors (e.g., steerTo, steerAway, followPath) that integrate seamlessly with the Physics System.

## Why Use the Steering System?

The Steering System is essential for creating dynamic and realistic movement for entities, such as:

- A character chasing a target.
- An enemy avoiding obstacles.
- A vehicle following a predefined path.

The high-level behaviors are recommended because they are designed to work closely with the Physics System, simplifying implementation while maintaining smooth motion.

---

## How to Use the Steering System

Examples:

1. Steer Toward a Target Position:

```swift
steerSeek(entityId: entity, targetPosition: targetPosition, maxSpeed: 5.0, deltaTime: 0.016)
```
2. Steer Away from a Threat:

```swift
steerFlee(entityId: entity, threatPosition: threatPosition, maxSpeed: 5.0, deltaTime: 0.016)
```

3. Follow a Path: Guide an entity along a series of waypoints.

```swift
steerFollowPath(entityId: entity, path: waypoints, maxSpeed: 5.0, deltaTime: 0.016)
```
4. Pursue a Moving Target:

```swift
steerPursuit(entityId: chaserEntity, targetEntity: targetEntity, maxSpeed: 5.0, deltaTime: 0.016)
```

5. Avoid Obstacles:

```swift
steerAvoidObstacles(entityId: entity, obstacles: obstacleEntities, avoidanceRadius: 2.0, maxSpeed: 5.0, deltaTime: 0.016)
```

6. Steer Toward a Target Position (with Arrive):

```swift
steerArrive(entityId: entity, targetPosition: targetPosition, maxSpeed: 5.0, deltaTime: 0.016)
```

7. Steer using WASD keys

```swift
steerWithWASD(entityId: entity, maxSpeed: 5.0, deltaTime: 0.016)
```

---

## What Happens Behind the Scenes?

1. Low-Level Behaviors:
- Calculate desired velocity based on the target or threat position.
- Generate steering forces by comparing desired velocity with current velocity.
2. High-Level Behaviors:
- Use low-level behaviors to calculate steering adjustments.
- Apply these forces to the entity’s physics system for smooth, realistic motion.
- Align the entity’s orientation to face its movement direction.
3. Physics Integration:
- Forces are applied through the Physics System, ensuring that movement respects mass, velocity, and acceleration.

---

## Tips and Best Practices
- Prefer High-Level Behaviors: They simplify complex movement patterns and automatically handle integration with the Physics System.
- Use Low-Level Behaviors for Custom Logic: When precise control is required, combine low-level behaviors for unique movement styles.
- Smooth Orientation: Use alignOrientation or integrate orientation alignment directly into high-level functions.
- Tune Parameters: Adjust maxSpeed, turnSpeed, and slowingRadius for different entity types (e.g., fast-moving cars vs. slow-moving enemies).

---

## Common Issues and Fixes

### Issue: Entity Doesn’t Move

- Cause: The Physics Component is missing or paused.
- Solution: Ensure the entity has a PhysicsComponents and it’s not paused.

### Issue: Jittery Movement

- Cause: Conflicting forces or large delta times.
- Solution: Tune maxSpeed and ensure deltaTime is passed correctly.

### Issue: Entity Ignores Obstacles

- Cause: Avoidance radius is too small or obstacles are not registered.
- Solution: Increase the avoidanceRadius and verify obstacle entities.

