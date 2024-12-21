# High-Level API Overview

The Untold Engine simplifies game development with a clean and intuitive API. Below is an example of how to use its core systems to create a basic game scene:

```swift
class GameScene {

    init() {

        // Step 1: Configure the Camera
        camera.lookAt(
            eye: simd_float3(0.0, 7.0, 15.0), // Camera position
            target: simd_float3(0.0, 0.0, 0.0), // Look-at target
            up: simd_float3(0.0, 1.0, 0.0) // Up direction
        )

        // Step 2: Create a Stadium Entity
        let stadium = createEntity()
        setEntityMesh(entityId: stadium, filename: "stadium", withExtension: "usdc")

        // Step 3: Create a Blue Player Entity
        let bluePlayer = createEntity()
        setEntityMesh(entityId: bluePlayer, filename: "blueplayer", withExtension: "usdc")
        translateBy(entityId: bluePlayer, position: simd_float3(3.0, 0.0, 0.0)) // Adjust position

        // Step 4: Create a Red Player Entity with Animation
        let redPlayer = createEntity()
        setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "usdc", flip: false)
        setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "usdc", name: "running")
        changeAnimation(entityId: redPlayer, name: "running") // Start animation

        // Step 5: Enable Physics on the Red Player
        setEntityKinetics(entityId: redPlayer)
        
        // Step 6: Create an Entity for the Sun
        let sunEntity: EntityID = createEntity()

        // Step 7: Create a Directional Light Instance
        let sun: DirectionalLight = DirectionalLight()

        // Step 8: Add the Light to the Lighting System
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
    }
}
```

### High-Level Breakdown

This example demonstrates the following key features of the Untold Engine:

1. Camera Setup:
    - Use the lookAt method to position and orient the camera, specifying the eye position, the target to look at, and the up direction.
2. Creating and Managing Entities:
    - Create entities for objects in your scene, such as a stadium, players, and lights, using the createEntity() function.
3. Loading and Assigning Meshes:
    - Load .usdc model files using setEntityMesh() and link them to entities for rendering.
4. Transformations:
    - Move entities in the scene using translateBy() to adjust their positions.
5. Animations:
    - Assign animations to entities using setEntityAnimations() and control them by name with changeAnimation().
6. Physics:
    - Enable physics behaviors like movement and collisions for entities with setEntityKinetics().
7. Lighting:
    - Create a directional light (e.g., sunlight) and add it to the lighting system using addDirectionalLight().
    
### What You’ll See
When you run this code:

- A camera is set up to view the scene.
- A stadium and two players (one animated) appear in the game window.
- Sunlight illuminates the scene, creating realistic lighting effects.
