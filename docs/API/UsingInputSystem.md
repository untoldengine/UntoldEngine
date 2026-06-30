# Using the Input System in Untold Engine

The Input System in the Untold Engine allows you to detect user inputs, such as keystrokes and mouse movements, to control entities and interact with the game. This guide will explain how to use the Input System effectively.


## How to Use the Input System (Keyboard)

### Step 1: Detect Keystrokes

To detect if a specific key is pressed, use the keyState object from the Input System.

Example: Detecting the 'W' Key

```swift
func init(){
    // Register keyboard events once in your init function
    registerKeyboardEvents()
}

// Then in the handleInput callback, you can do this:

func handleInput() {
    // Skip logic if not in game mode
    if gameMode == false { return }

    let keyState = getKeyboardState()

    if keyState.wPressed {
        Logger.log(message: "w pressed")
    }
}
```
You can use the same logic for other keys like A, S, and D:

```swift
let keyState = getKeyboardState()

if keyState.aPressed {
    // Move left
}

if keyState.sPressed {
    // Move backward
}

if keyState.dPressed {
    // Move right
}
```

### Available Key State Fields

`KeyState` currently exposes:

| Group | Fields |
|---|---|
| Movement/common letters | `wPressed`, `aPressed`, `sPressed`, `dPressed`, `qPressed`, `ePressed`, `fPressed`, `hPressed`, `jPressed`, `kPressed`, `lPressed` |
| Function keys | `f1Pressed` through `f12Pressed` |
| Navigation/modifier keys | `tabPressed`, `spacePressed`, `shiftPressed`, `ctrlPressed`, `altPressed` |
| Mouse buttons | `leftMousePressed`, `rightMousePressed`, `middleMousePressed` |

On macOS, keyboard events are ignored while an `NSText` field is focused, so typing into editor text controls does not leak into game input. Modifier flags update from system flag-change events.

### Step 2: Using Input to Control Entities

Here's an example function that moves a car entity based on keyboard inputs:

```swift
func moveCar(entityId: EntityID, dt: Float) {
    if gameMode == false { return }

    let keyState = getKeyboardState()
    var position = simd_float3(0.0, 0.0, 0.0)

    if keyState.wPressed { position.z += 1.0 * dt }
    if keyState.sPressed { position.z -= 1.0 * dt }
    if keyState.aPressed { position.x -= 1.0 * dt }
    if keyState.dPressed { position.x += 1.0 * dt }

    translateTo(entityId: entityId, position: position)
}
```

## How to Use the Input System with a Game Controller

Game controller detection is automatic — no registration call is needed.

Example: Detecting the 'A' button

```swift
func handleInput() {
    if gameMode == false { return }

    let controller = getGameControllerState()

    if controller.aPressed {
        Logger.log(message: "Pressed A button")
    }
}
```

---

## Input Registration (macOS)

Register keyboard and mouse event handling once in your init function:

```swift
func gameInit() {
    registerKeyboardEvents()
    registerMouseEvents()
}
```

Call `unregisterKeyboardEvents()` to stop receiving keyboard events (e.g. when leaving game mode).

---

## How to Use the Input System (iOS)

On iOS, the engine maps standard UIKit gesture recognizers to the same shared input state used on other platforms, so your `handleInput` code stays familiar regardless of target.

### Step 1: Register touch events

Pass in your game view once during setup:

```swift
func gameInit(view: UIView) {
    registerTouchEvents(view: view)
}
```

Call `unregisterTouchEvents()` to remove the gesture recognizers when no longer needed.

### Step 2: Read gesture state per frame

The engine registers five gesture recognizers and writes their output into shared input fields:

| Gesture | What it maps to |
|---|---|
| Single-finger drag | `mouseX`, `mouseY`, `mouseDeltaX`, `mouseDeltaY`, `mouseActive` |
| Tap | `keyState.leftMousePressed` (brief pulse) |
| Two-finger pan | `panDelta.x / .y`, `cameraControlMode` (`.orbiting` while active) |
| Pinch | `pinchDelta.z` (scale delta per frame), `currentPinchGestureState` |
| Double tap | position updated in `mouseX` / `mouseY` — add custom logic as needed |

```swift
func handleInput() {
    if gameMode == false { return }

    let input = InputSystem.shared

    // Single-finger drag — equivalent to a mouse drag on macOS
    if input.mouseActive {
        Logger.log(message: "Touch dragging at (\(input.mouseX), \(input.mouseY))")
        Logger.log(message: "Delta: (\(input.mouseDeltaX), \(input.mouseDeltaY))")
    }

    // Pinch to zoom
    if input.currentPinchGestureState == .changed {
        let zoomDelta = input.pinchDelta.z
        // apply zoom using zoomDelta...
    }

    // Two-finger pan — camera orbit
    if input.cameraControlMode == .orbiting {
        let delta = input.panDelta
        // apply orbit using delta.x / delta.y...
    }

    // Tap — brief leftMousePressed pulse, same as a mouse click
    let keys = getKeyboardState()
    if keys.leftMousePressed {
        Logger.log(message: "Tapped at (\(input.mouseX), \(input.mouseY))")
    }
}
```

### Step 3: Using touch input to move entities

```swift
func handleInput() {
    if gameMode == false { return }

    let input = InputSystem.shared

    guard input.mouseActive else { return }

    var position = simd_float3(0, 0, 0)
    position.x += input.mouseDeltaX * 0.01
    position.z += input.mouseDeltaY * 0.01

    translateTo(entityId: myEntity, position: position)
}
```

---

## XR Input Configuration (visionOS)

When developing for visionOS, use the `setInput` facade and free functions to configure XR input without touching the shared singleton directly.

### Registering XR events

Before any spatial input is received, register the XR event pipeline in your init:

```swift
func gameInit() {
    registerXREvents()
}
```

Call `unregisterXREvents()` to stop receiving spatial events when leaving XR mode.

### Configuring XR behaviour

```swift
// Choose the spatial picking backend
setInput(.xr(.pickingBackend(.octreeGPUPreferred)))

// Set how the two-hand rotate axis is derived
setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))

// Signal that the XR scene is ready to receive input
setInput(.xr(.sceneReady(true)))
```

Available two-hand rotate axis modes:

- `.cameraForward` — rotates around the camera-forward axis (screen-style twist)
- `.dynamic` — derives the axis from actual two-hand motion
- `.dynamicSnapped` — dynamic axis snapped to the dominant world axis (`x`, `y`, or `z`)

### Reading XR input state

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    if state.spatialTapActive, let entityId = state.pickedEntityId {
        Logger.log(message: "Tapped entity: \(entityId)")
    }
}
```

### Querying scene readiness

```swift
let ready = isXRSceneReady()
```

---

## How to Use the Input System (PlayStation VR2 Sense Controller)

The PSVR2 Sense controller is detected automatically — no registration call is needed. The moment `InputSystem.shared` is first accessed, the engine begins listening for controller connect and disconnect events. When a PSVR2 Sense controller pairs, it is configured automatically.

### Step 1: Read controller state per frame

```swift
func handleInput() {
    let state = getPSVR2SenseState()

    // Buttons unique to the PSVR2 Sense
    if state.createButtonPressed {
        Logger.log(message: "Create button pressed")
    }

    if state.touchpadButtonPressed {
        Logger.log(message: "Touchpad clicked")
    }

    // Touchpad surface position (−1…1 per axis)
    if state.touchpadTouched {
        Logger.log(message: "Finger at (\(state.touchpadX), \(state.touchpadY))")
    }

    // Adaptive trigger pull depth (0…1)
    if state.leftAdaptiveTriggerValue > 0.5 {
        Logger.log(message: "Left trigger more than half pulled")
    }
}
```

### Step 2: Check connection status

```swift
if isPSVR2SenseConnected() {
    Logger.log(message: "PSVR2 Sense is connected")
}
```

### Step 3: Apply adaptive trigger effects

Trigger effects can be set at any time. Calls are silently ignored when no controller is paired.

```swift
// Simulate weapon resistance — builds from 20% to 80% of travel, then releases
setInput(.psvr2(.leftTriggerEffect(.weapon(startPosition: 0.2, endPosition: 0.8, strength: 1.0))))

// Constant resistance from 30% travel onwards
setInput(.psvr2(.rightTriggerEffect(.feedback(startPosition: 0.3, strength: 0.7))))

// Repeating vibration strike
setInput(.psvr2(.leftTriggerEffect(.vibration(startPosition: 0.0, amplitude: 0.5, frequency: 15.0))))

// Linearly interpolated resistance between two positions
setInput(.psvr2(.leftTriggerEffect(.slopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.2, endStrength: 1.0))))

// Clear all effects
setInput(.psvr2(.leftTriggerEffect(.off)))
setInput(.psvr2(.rightTriggerEffect(.off)))
```

All position and strength values are normalized to `[0, 1]`. For `.weapon` and `.slopeFeedback`, `endPosition` must be greater than `startPosition`.

### Step 4: Enable motion sensing (optional)

Motion is disabled by default to avoid unnecessary sensor activation. Enable it when your game needs gravity or rotation rate data:

```swift
// Enable once (e.g. in gameInit)
setInput(.psvr2(.motionEnabled(true)))

// Then read per frame
func handleInput() {
    let state = getPSVR2SenseState()
    let gravity = simd_float3(state.motionGravityX, state.motionGravityY, state.motionGravityZ)
    let rotationRate = simd_float3(state.motionRotationRateX, state.motionRotationRateY, state.motionRotationRateZ)
}
```

You can toggle motion off again at any time with `setInput(.psvr2(.motionEnabled(false)))`.

### Available PSVR2SenseControllerState fields

| Group | Fields |
|---|---|
| Connection | `isConnected` |
| Buttons | `createButtonPressed`, `homeButtonPressed`, `touchpadButtonPressed` |
| Touchpad surface | `touchpadX`, `touchpadY`, `touchpadTouched` |
| Adaptive triggers | `leftAdaptiveTriggerValue`, `rightAdaptiveTriggerValue` |
| Motion (gravity) | `motionGravityX`, `motionGravityY`, `motionGravityZ` |
| Motion (rotation rate) | `motionRotationRateX`, `motionRotationRateY`, `motionRotationRateZ` |

---

## Tips and Best Practices
- Debouncing: If you want to execute an action only once per key press, track the key's previous state to avoid repeated triggers.
- Game Mode Check: Always ensure the game is in the appropriate mode (e.g., Game Mode) before processing inputs.
- Smooth Movement: Use dt (delta time) to ensure frame-rate-independent movement.
