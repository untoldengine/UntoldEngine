---
id: inputsystem
title: Input System
sidebar_position: 6
---

# Using the Input System in Untold Engine

The Input System in the Untold Engine allows you to detect user inputs, such as keystrokes and mouse movements, to control entities and interact with the game. This guide will explain how to use the Input System effectively.


## How to Use the Input System (Keyboard)

### Step 1: Detect Keystrokes

To detect if a specific key is pressed, use the keyState object from the Input System.

Example: Detecting the 'W' Key

```swift
func init(){
// Make sure that you have enabled keyevents in your init function:
InputSystem.shared.registerKeyboardEvents()
}

// Then in the handleInput callback, you can do this:

func handleInput() {
    // Skip logic if not in game mode
    if gameMode == false { return }
    
    let inputSystem = InputSystem.shared

    // Handle input here
    if inputSystem.keyState.wPressed{
        Logger.log(message: "w pressed")
    }
}
```
You can use the same logic for other keys like A, S, and D:

```swift
let inputSystem = InputSystem.shared
    
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
    
    let inputSystem = InputSystem.shared
        
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

## How to Use the Input System with a Game Controller

To detect if a specific button is pressed, use the gameControllerState object from the Input System.

Example: Detecting the 'A' button

```swift
func init(){
// Make sure that you have enabled game controller events in your init function:
    InputSystem.shared.registerGameControllerEvents()
}

// Then in the handleInput callback, you can do this:

func handleInput() {
    // Skip logic if not in game mode
    if gameMode == false { return }
    let inputSystem = InputSystem.shared

    // Handle input here
    if inputSystem.gameControllerState.aPressed {
        Logger.log(message: "Pressed A key")
    }
}
```

---

## Tips and Best Practices
- Debouncing: If you want to execute an action only once per key press, track the key's previous state to avoid repeated triggers.
- Game Mode Check: Always ensure the game is in the appropriate mode (e.g., Game Mode) before processing inputs.
- Smooth Movement: Use dt (delta time) to ensure frame-rate-independent movement.

