# Adding light to your game

To add a **directional light** (such as the sun), follow these steps:

1. **Create an entity** to represent the light.
2. **Create a directional light instance**.
3. **Add both the entity and the directional light** to the lighting system.

Here’s how you can do it:

```swift
class GameScene{

    init(){

        // ... other initializations ...
        
        // Step 1: Create an entity for the directional light
        let sunEntity: EntityID = createEntity()

        // Step 2: Create the directional light instance
        let sun: DirectionalLight = DirectionalLight()

        // Step 3: Add the entity and the light to the lighting system
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)

    }

}
```

This setup ensures the directional light is registered in the lighting system, ready to illuminate your scene.

Next: [Detecting User Input](DetectingUserInputs.md)

Previous: [Creating a game entity](CreatingAnEntity.md)
