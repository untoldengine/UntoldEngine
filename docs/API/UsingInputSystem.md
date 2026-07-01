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

On iOS, the engine registers UIKit gesture recognizers against your game view and writes all touch output into a dedicated `IOSTouchState` struct. This keeps iOS input separate from keyboard and mouse state and gives each gesture its own clearly named fields.

### Step 1: Register touch events

Pass your game view once during setup:

```swift
func gameInit(view: UIView) {
    registerTouchEvents(view: view)
}
```

Call `unregisterTouchEvents()` to remove the gesture recognizers when no longer needed (e.g. when leaving the game scene).

### Step 2: Read gesture state per frame

Call `getIOSTouchState()` each frame to get a snapshot of all active gestures:

| Gesture | Fields populated |
|---|---|
| Single-finger drag | `isDragging`, `dragX`, `dragY`, `dragDeltaX`, `dragDeltaY`, `dragGestureState` |
| Tap (single) | `tapped` (brief pulse), `tapX`, `tapY` |
| Double tap | `doubleTapped` (brief pulse), `doubleTapX`, `doubleTapY` |
| Two-finger pan | `twoFingerPanning`, `twoFingerDeltaX`, `twoFingerDeltaY` |
| Pinch | `isPinching`, `pinchScaleDelta` (change in scale per frame; positive = spreading) |

```swift
func handleInput() {
    if gameMode == false { return }

    let touch = getIOSTouchState()

    // Single-finger drag
    if touch.isDragging {
        Logger.log(message: "Dragging at (\(touch.dragX), \(touch.dragY))")
        Logger.log(message: "Delta: (\(touch.dragDeltaX), \(touch.dragDeltaY))")
    }

    // Tap
    if touch.tapped {
        Logger.log(message: "Tapped at (\(touch.tapX), \(touch.tapY))")
    }

    // Double tap
    if touch.doubleTapped {
        Logger.log(message: "Double-tapped at (\(touch.doubleTapX), \(touch.doubleTapY))")
    }

    // Two-finger pan
    if touch.twoFingerPanning {
        Logger.log(message: "Two-finger pan delta: (\(touch.twoFingerDeltaX), \(touch.twoFingerDeltaY))")
    }

    // Pinch to zoom
    if touch.isPinching {
        let zoom = touch.pinchScaleDelta
        // apply zoom...
    }
}
```

### Step 3: Using touch input to move entities

```swift
func handleInput() {
    if gameMode == false { return }

    let touch = getIOSTouchState()

    guard touch.isDragging else { return }

    var position = simd_float3(0, 0, 0)
    position.x += touch.dragDeltaX * 0.01
    position.z += touch.dragDeltaY * 0.01

    translateTo(entityId: myEntity, position: position)
}
```

### Available IOSTouchState fields

| Group | Fields |
|---|---|
| Single-finger drag | `isDragging`, `dragX`, `dragY`, `dragDeltaX`, `dragDeltaY`, `dragGestureState` |
| Tap | `tapped`, `tapX`, `tapY` |
| Double tap | `doubleTapped`, `doubleTapX`, `doubleTapY` |
| Two-finger pan | `twoFingerPanning`, `twoFingerDeltaX`, `twoFingerDeltaY` |
| Pinch | `isPinching`, `pinchScaleDelta` |

`tapped` and `doubleTapped` are brief pulses — they auto-clear after ~0.1 s so you don't need to reset them manually. `dragDeltaX/Y` and `twoFingerDeltaX/Y` are reset to zero at the end of each gesture, so no manual reset is needed there either.

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

## PlayStation VR2 Sense Controllers on Apple Vision Pro

PSVR2 spatial tracking requires Apple Vision Pro running visionOS 26 or later. The generated visionOS app declares both the `SpatialGamepad` controller profile and `NSAccessoryTrackingUsageDescription`; the system asks the user for accessory-tracking permission on first use.

The engine uses two coordinated APIs:

- GameController provides face buttons, sticks, shoulders, and analog triggers through `getGameControllerState()`.
- ARKit's `AccessoryTrackingProvider` provides independent world-space 6-DoF poses for the left and right controllers through `getPSVR2SenseState()`.

### Required visionOS project configuration

Set the visionOS deployment target to `26.0` or later. The application target's `Info.plist` must declare controller interaction, both controller profiles, and why the app tracks accessories:

```xml
<key>GCSupportsControllerUserInteraction</key>
<true/>

<key>GCSupportedGameControllers</key>
<array>
    <dict>
        <key>ProfileName</key>
        <string>SpatialGamepad</string>
    </dict>
    <dict>
        <key>ProfileName</key>
        <string>ExtendedGamepad</string>
    </dict>
</array>

<key>NSAccessoryTrackingUsageDescription</key>
<string>This app tracks PSVR2 Sense controller movement for gameplay.</string>
```

`SpatialGamepad` enables visionOS to expose the left and right PSVR2 Sense controllers as spatial devices. `ExtendedGamepad` declares support for conventional game controllers and their standard controls. `NSAccessoryTrackingUsageDescription` is required before ARKit can provide controller poses.

Add these settings to the executable application's plist, not the UntoldEngine package. After adding or changing the tracking usage description, uninstall and reinstall the app on Apple Vision Pro if the permission prompt does not appear. The user must allow accessory tracking for `left.isTracked` and `right.isTracked` to become true.

### Read buttons and triggers

```swift
let buttons = getGameControllerState()

if buttons.aPressed { Logger.log(message: "Cross pressed") }
if buttons.bPressed { Logger.log(message: "Circle pressed") }
if buttons.xPressed { Logger.log(message: "Square pressed") }
if buttons.yPressed { Logger.log(message: "Triangle pressed") }

if buttons.leftTriggerValue > 0.5 {
    Logger.log(message: "Left trigger more than half pulled")
}
```

PlayStation face-button mapping uses A = Cross, B = Circle, X = Square, and Y = Triangle.

### Read spatial poses

```swift
func handleInput() {
    let state = getPSVR2SenseState()
    guard state.isConnected else { return }

    if state.left.isTracked {
        let leftPosition = state.left.position
        let leftOrientation = state.left.orientation
        let leftTransform = state.left.originFromControllerTransform
        // Update the left-hand entity.
    }

    if state.right.isTracked {
        let rightPosition = state.right.position
        let rightOrientation = state.right.orientation
        // Update the right-hand entity.
    }
}
```

Each `PSVR2ControllerPose` contains:

| Field | Meaning |
|---|---|
| `isTracked` | Whether ARKit currently tracks this controller |
| `trackingState` | `.unavailable`, `.orientationOnly`, `.positionAndOrientation`, or `.positionAndOrientationLowAccuracy` |
| `originFromControllerTransform` | Controller transform in the ARKit world coordinate system |
| `position` | Translation extracted from the transform |
| `orientation` | Rotation extracted from the transform |
| `velocity` | Linear velocity in meters per second |
| `angularVelocity` | Angular velocity in radians per second |

`isConnected` means the spatial controller is connected. It does not guarantee that both controllers are currently visible or position-tracked; check each pose's `isTracked` and `trackingState`.

The old DualSense-specific touchpad, Create/Home button, adaptive-trigger effect, and `GCMotion` APIs are intentionally not part of this visionOS integration. They are not exposed by the PSVR2 `SpatialGamepad` profile. Spatial movement comes from ARKit accessory anchors instead.

---

## Tips and Best Practices
- Debouncing: If you want to execute an action only once per key press, track the key's previous state to avoid repeated triggers.
- Game Mode Check: Always ensure the game is in the appropriate mode (e.g., Game Mode) before processing inputs.
- Smooth Movement: Use dt (delta time) to ensure frame-rate-independent movement.
