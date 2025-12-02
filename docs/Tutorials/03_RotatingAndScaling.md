# Tutorial 3: Rotating and Scaling Objects

**What you'll learn:**
- Accessing and modifying entity rotation
- Rotating objects continuously over time
- Scaling objects dynamically
- Combining multiple transformations
- Using `getProperty()` and `setProperty()`

**Time:** ~15 minutes

---

## What We're Building

Three scripts that demonstrate different transform operations:
1. **RotatingCube** - Spins continuously around the Y-axis
2. **PulsingObject** - Grows and shrinks over time
3. **TransformCombo** - Combines rotation, scaling, and movement

---

## Tutorial 3A: Rotating Cube

### Create the Script

1. In **Untold Engine Studio**, click **Scripts: New**
2. Name it: `RotatingCube`
3. Click OK

### Wire It Up

In `GenerateScripts.swift`:
```swift
generateRotatingCube(to: outputDir)
```

### Write the Script

In `RotatingCube.swift`:

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateRotatingCube(to dir: URL) {
        let script = buildScript(name: "RotatingCube") { s in
            // Initialize rotation speed
            s.onStart()
                .setVariable("rotationSpeed", to: 5.0)  // Degrees per frame
                .setVariable("currentAngle", to: 0.0)
                .log("Rotation initialized")
            
            // Rotate every frame
            s.onUpdate()
                // Add rotation speed to current angle
                .addFloat("currentAngle", "rotationSpeed", as: "newAngle")
                
                // Keep angle between 0-360 (optional, prevents overflow)
                .ifGreater("newAngle", than: 360.0) { n in
                    n.setVariable("newAngle", to: 0.0)
                }
                
                // Store the new angle
                .setVariable("currentAngle", to: .variableRef("newAngle"))
                
                // Apply rotation around Y-axis
                .rotateTo(
                    degrees: .variableRef("newAngle"),
                    axis: Vec3(x: 0, y: 1, z: 0)
                )
        }
        
        let outputPath = dir.appendingPathComponent("RotatingCube.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ RotatingCube.uscript")
    }
}
```

### Understanding the Code

**`setVariable()`** - Store values in script variables
- Variables persist between frames
- Store state like `currentAngle`
- Variables are referenced directly by name in operations

**`addFloat()`** - Add two float values
- `addFloat("a", "b", as: "sum")` computes `sum = a + b`
- Can also add literals: `addFloat("a", literal: 1.0, as: "result")`

**`rotateTo()`** - Set absolute rotation
- Takes degrees and an axis vector
- Y-axis rotation: `Vec3(x: 0, y: 1, z: 0)`
- X-axis rotation: `Vec3(x: 1, y: 0, z: 0)`
- Z-axis rotation: `Vec3(x: 0, y: 0, z: 1)`

**Alternative - Relative Rotation:**
```swift
s.rotateBy(degrees: 1.0, axis: Vec3(x: 0, y: 1, z: 0))
```
- Rotates relative to current rotation
- Simpler but accumulates small errors over time

### Test It

1. Build in Xcode (Cmd+R)
2. Attach to a cube in the editor
3. Click Play - watch it spin!

---

## Tutorial 3B: Pulsing Object

### Create the Script

1. Click **Scripts: New**
2. Name it: `PulsingObject`

### Wire It Up

```swift
generatePulsingObject(to: outputDir)
```

### Write the Script

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generatePulsingObject(to dir: URL) {
        let script = buildScript(name: "PulsingObject") { s in
            s.onStart()
                .setVariable("time", to: 0.0)
                .setVariable("minScale", to: 0.5)
                .setVariable("maxScale", to: 2.0)
                .log("Pulse effect initialized")
            
            s.onUpdate()
                // Increment time (simulating sine wave)
                .addFloat("time", literal: 0.05, as: "newTime")
                
                // Reset time after full cycle
                .ifGreater("newTime", than: 6.28) { n in  // ~2π
                    n.setVariable("newTime", to: 0.0)
                }
                .setVariable("time", to: .variableRef("newTime"))
                
                // Calculate scale using oscillation
                .mulFloat("time", literal: 0.5, as: "scaleFactor")  // Oscillation factor
                
                // Create uniform scale vector
                .setVariable("scaleValue", to: 1.0)
                .addFloat("scaleValue", "scaleFactor", as: "finalScale")
                .setVariable("scaleVec", to: Vec3(x: .variableRef("finalScale"), 
                                                   y: .variableRef("finalScale"), 
                                                   z: .variableRef("finalScale")))
                
                // Apply scale
                .setProperty(.scale, toVariable: "scaleVec")
        }
        
        let outputPath = dir.appendingPathComponent("PulsingObject.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ PulsingObject.uscript")
    }
}
```

### Understanding Scale

**Scale Property:**
- Scale is a Vec3: `(x, y, z)`
- `(1, 1, 1)` = original size
- `(2, 2, 2)` = double size
- `(0.5, 1, 0.5)` = half width/depth, normal height

**Uniform vs Non-Uniform:**
```swift
// Uniform scale (all axes same)
.setProperty(.scale, to: Vec3(x: 2, y: 2, z: 2))

// Non-uniform scale (different per axis)
.setProperty(.scale, to: Vec3(x: 1, y: 2, z: 1))  // Tall and thin
```

---

## Tutorial 3C: Transform Combo

Let's combine rotation, scaling, and position changes!

### Create the Script

1. Click **Scripts: New**
2. Name it: `TransformCombo`

### Write the Script

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateTransformCombo(to dir: URL) {
        let script = buildScript(name: "TransformCombo") { s in
            s.onStart()
                .setVariable("time", to: 0.0)
                .setVariable("orbitRadius", to: 5.0)
                .setVariable("orbitSpeed", to: 0.05)
                .log("Combo transform initialized")
            
            s.onUpdate()
                // Increment time
                .addFloat("time", "orbitSpeed", as: "newTime")
                .setVariable("time", to: .variableRef("newTime"))
                
                // Calculate circular orbit position
                // Simplified: just oscillate X position
                .mulFloat("orbitRadius", "time", as: "xPos")
                .setVariable("circlePos", to: Vec3(
                    x: .variableRef("xPos"),
                    y: 2.0,  // Height
                    z: 0.0
                ))
                
                // Apply position
                .setProperty(.position, toVariable: "circlePos")
                
                // Rotate while orbiting
                .mulFloat("time", literal: 50.0, as: "rotDegrees")
                .rotateTo(
                    degrees: .variableRef("rotDegrees"),
                    axis: Vec3(x: 0, y: 1, z: 0)
                )
                
                // Scale while rotating
                .mulFloat("time", literal: 0.3, as: "scaleVal")
                .addFloat("scaleVal", literal: 1.0, as: "finalScale")
                .setVariable("scaleVec", to: Vec3(
                    x: .variableRef("finalScale"),
                    y: .variableRef("finalScale"),
                    z: .variableRef("finalScale")
                ))
                .setProperty(.scale, toVariable: "scaleVec")
        }
        
        let outputPath = dir.appendingPathComponent("TransformCombo.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ TransformCombo.uscript")
    }
}
```

### What This Does

1. **Orbits** around a center point
2. **Rotates** around its own Y-axis
3. **Scales** up and down as it moves

This creates a hypnotic, complex motion from simple components!

---

## Working with Rotation

### Reading Current Rotation

```swift
s.onUpdate()
    .getProperty(.rotation, as: "currentRot")
    .log("Current rotation")
```

### Rotation Axes

**Y-axis (most common):**
```swift
Vec3(x: 0, y: 1, z: 0)  // Spin like a top
```

**X-axis:**
```swift
Vec3(x: 1, y: 0, z: 0)  // Flip forward/backward
```

**Z-axis:**
```swift
Vec3(x: 0, y: 0, z: 1)  // Roll left/right
```

**Diagonal:**
```swift
Vec3(x: 1, y: 1, z: 0)  // Custom axis
```

---

## Working with Scale

### Reading Current Scale

```swift
s.onUpdate()
    .getProperty(.scale, as: "currentScale")
```

### Common Scale Patterns

**Grow over time:**
```swift
s.onUpdate()
    .getProperty(.scale, as: "scale")
    .setVariable("growth", to: Vec3(x: 0.01, y: 0.01, z: 0.01))
    .addVec3("scale", "growth", as: "newScale")
    .setProperty(.scale, toVariable: "newScale")
```

**Shrink over time:**
```swift
.setVariable("shrink", to: Vec3(x: -0.01, y: -0.01, z: -0.01))
.addVec3("scale", "shrink", as: "newScale")
```

---

## Experiment: Interactive Rotation

Make an object rotate faster when you hold a key:

```swift
s.onUpdate()
    .setVariable("rotSpeed", to: 1.0)  // Default
    
    .ifKeyPressed("R") { n in
        n.setVariable("rotSpeed", to: 5.0)  // Fast rotation
    }
    
    // Add rotation speed to current angle
    .addFloat("currentAngle", "rotSpeed", as: "newAngle")
    .setVariable("currentAngle", to: .variableRef("newAngle"))
    
    .rotateTo(
        degrees: .variableRef("newAngle"),
        axis: Vec3(x: 0, y: 1, z: 0)
    )
```

---

## What You Learned

✅ Reading and writing transform properties  
✅ Rotating objects with `rotateTo()` and `rotateBy()`  
✅ Scaling objects with `setProperty(.scale)`  
✅ Using variables to track state over time  
✅ Combining multiple transformations  
✅ Creating oscillating/pulsing effects  

---

## Next Steps

**[Tutorial 4: Simple Player Controller](./04_PlayerController.md)** - Combine everything into a complete character controller

**Challenges:**
- Make an object rotate on multiple axes at once
- Create a "wobble" effect (rotate back and forth)
- Make objects face the camera (billboard effect)
- Create a spinning collectible that also bobs up and down

**Need Help?**
- [USC Scripting API - Transform](../Scripting/USC_Scripting_API.md#9-transform--physics-helpers)
- [USC Scripting API - Math Operations](../Scripting/USC_Scripting_API.md#7-math-operations)
