# Using the Input System in Untold Engine

The Input System in the Untold Engine allows you to detect user inputs, such as keystrokes and mouse movements, to control entities and interact with the game. This guide will explain how to use the Input System effectively.

## Why Use the Input System?

The Input System is essential for capturing player interactions and translating them into game mechanics. For example:

- Moving a character based on keyboard inputs.
- Rotating a camera with mouse movements.
- Creating immersive and responsive gameplay.

---

## How to Use the Input System

### Step 1: Detect Keystrokes
To detect if a specific key is pressed, use the keyState object from the Input System.

Example: Detecting the 'W' Key

```swift
if inputSystem.keyState.wPressed == true {
    // Your code here
}
```
You can use the same logic for other keys like A, S, and D:

```swift
if inputSystem.keyState.aPressed == true {
    // Move left
}

if inputSystem.keyState.sPressed == true {
    // Move backward
}

if inputSystem.keyState.dPressed == true {
    // Move right
}
```

###Step 2: Using Input to Control Entities

Here’s an example function that moves a car entity based on keyboard inputs:

```swift
func moveCar(entityId: EntityID, dt: Float) {
    // Ensure we are in game mode
    if gameMode == false {
        return
    }

    var position = simd_float3(0.0, 0.0, 0.0)

    // Move forward
    if inputSystem.keyState.wPressed == true {
        position.z += 1.0 * dt
    }

    // Move backward
    if inputSystem.keyState.sPressed == true {
        position.z -= 1.0 * dt
    }

    // Move left
    if inputSystem.keyState.aPressed == true {
        position.x -= 1.0 * dt
    }

    // Move right
    if inputSystem.keyState.dPressed == true {
        position.x += 1.0 * dt
    }

    // Apply the translation to the entity
    translateTo(entityId: entityId, position: position)
}
```

---

## What Happens Behind the Scenes?

1. Input Polling:
- The Input System continuously checks for key and mouse states during the game loop.
- It updates the keyState object with the current state of each key.
2. Key States:
- Each key has a boolean state (true if pressed, false if not).
- This allows real-time detection and response to user inputs.

---

## Tips and Best Practices
- Debouncing: If you want to execute an action only once per key press, track the key's previous state to avoid repeated triggers.
- Game Mode Check: Always ensure the game is in the appropriate mode (e.g., Game Mode) before processing inputs.
- Smooth Movement: Use dt (delta time) to ensure frame-rate-independent movement.

