# Top APIs in the Untold Engine

## Quick Reference


| Category     | Common APIs |
|--------------|-------------|
| **Entities** | [createEntity](#create-an-entity), [destroyEntity](#destroy-an-entity), [setParent](#parent-child-relationships), [findEntity](#find-entity) |
| **Transforms** | [getLocalPosition](#get-local-position), [getPosition](#get-world-position), [getLocalOrientation](#get-local-orientation), [getOrientation](#get-world-orientation), [getForwardAxisVector](#get-axis-vectors), [translateTo](#translate-the-entity), [translateBy](#translate-the-entity), [rotateTo](#rotate-the-entity), [rotateBy](#rotate-the-entity) |
| **Assets** | [assetBasePath](#base-path-to-assets) |
| **Rendering** | [setEntityMesh](#link-a-mesh-to-the-entity), [createDirLight](#directional-light), [createPointLight](#point-light), [createSpotLight](#spot-light), [createAreaLight](#area-light) |
| **Animation** | [setEntityAnimations](#load-an-animation), [changeAnimation](#set-the-animation-to-play), [pauseAnimationComponent](#pause-the-animation-optional) |
| **Physics** | [setEntityKinetics](#enable-physics-on-the-entity), [setMass](#configure-physics-properties), [setGravityScale](#configure-physics-properties), [applyForce](#apply-forces-optional), [steerTo](#use-the-steering-system), [steerAway](#additional-steering-functions), [steerPursuit](#additional-steering-functions), [followPath](#additional-steering-functions) |
| **Components** | [registerComponent](#register-components), [create-custom-component](#create-custom-component), [attach-component](#attaching-a-component-to-an-entity) |
| **Systems** | [create-custom-system](#create-custom-system), [registerCustomSystem](#registering-the-custom-system) |


# Entities

### Create an Entity

Entities represent objects in the scene. Use the createEntity() function to create a new entity.

```swift
let entity = createEntity()
```

### Destroy an Entity

To remove an entity and its components from the scene, use destroyEntity.

```swift
destroyEntity(entityId: entity)
```

This ensures the entity is properly removed from all systems.

---

### Parent-Child Relationships

To assign a parent to an entity, use the setParent function. This function establishes a hierarchical relationship between the specified entities.

```swift
// Create child and parent entities
let childEntity = createEntity()
let parentEntity = createEntity()

// Set parent-child relationship
setParent(childId: childEntity, parentId: parentEntity)
```

### Find Entity 

You can find an entity by name using the following function: 

```swift
let ball = findEntity(name: "ball")
```
---

# Transforms

### Get Local Position

Retrieves the entity’s position relative to its parent.

```swift
let localPosition = getLocalPosition(entityId: entity)
```

### Get World Position

Retrieves the entity’s absolute position in the scene.

```swift
let worldPosition = getPosition(entityId: entity)
```

### Get Local Orientation

Retrieves the entity’s orientation matrix relative to its parent.

```swift
let localOrientation = getLocalOrientation(entityId: entity)
```

### Get World Orientation

Retrieves the entity’s absolute orientation matrix.

```swift
let worldOrientation = getOrientation(entityId: entity)
```

### Get Axis Vectors

Retrieve the entity’s forward, right, or up axis:

```swift
let forward = getForwardAxisVector(entityId: entity)
let right = getRightAxisVector(entityId: entity)
let up = getUpAxisVector(entityId: entity)
```

---

### Translate the Entity

Move the entity to a new position:

```swift
translateTo(entityId: entity, position: simd_float3(5.0, 0.0, 3.0))
```

Move the entity by an offset relative to its current position:

```swift
translateBy(entityId: entity, position: simd_float3(1.0, 0.0, 0.0))
```

### Rotate the Entity

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

# Base path to assets

Define the asset directory the engine will use to load content (Assuming you are using an external folder during development). Please see Import-Export section for more details.

```swift 
// Here we point it to a folder named "DemoGameAssets/Assets" on the Desktop.
// You can change this to any folder where you keep your own assets.
if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
    assetBasePath = desktopURL.appendingPathComponent("DemoGameAssets/Assets")
}
```

# Rendering

### Link a Mesh to the Entity

To display a model, load its .usdc file and link it to the entity using setEntityMesh.

```swift
setEntityMesh(entityId: entity, filename: "entity", withExtension: "usdc")
```

Parameters:

- entityId: The ID of the entity created earlier.
- filename: The name of the .usdc file (without the extension).
- withExtension: The file extension, typically "usdc".

> Note: If PBR textures (e.g., albedo, normal, roughness, metallic maps) are included, the rendering system will automatically use the appropriate PBR shader to render the model with realistic lighting and material properties.


### Directional Light

Use for sunlight or distant key lights. Orientation (rotation) defines its direction.

```swift
let sun = createEntity()
createDirLight(entityId: sun)
```
### Point Light

Omni light that radiates equally in all directions from a position.

```swift 
let bulb = createEntity()
createPointLight(entityId: bulb)
```

### Spot Light

Cone-shaped light with a position and direction.

```swift
let spot = createEntity()
createSpotLight(entityId: spot)
```

### Area Light

Rect/area emitter used to mimic panels/windows; position and orientation matter.

```swift
let panel = createEntity()
createAreaLight(entityId: panel)
```

---

# Animation 

### Load an Animation
Load the animation data for your model by providing the animation .usdc file and a name to reference the animation later.

```swift
setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "usdc", name: "running")
```

### Set the Animation to play

Trigger the animation by referencing its name. This will set the animation to play on the entity.

```swift
changeAnimation(entityId: redPlayer, name: "running")
```

### Pause the animation (Optional)

To pause the current animation, simply call the following function. The animation component will be paused for the current entity.

```swift
pauseAnimationComponent(entityId: redPlayer, isPaused: true)
```

--- 

# Physics
 
### Enable Physics on the Entity

Activate the physics simulation for your entity using the setEntityKinetics function. This function prepares the entity for movement and dynamic interaction.

```swift
setEntityKinetics(entityId: redPlayer)
```
---

### Configure Physics Properties
You can customize the entity’s physics behavior by defining its mass and gravity scale:

- Mass: Determines the force needed to move the object. Heavier objects require more force.
- Gravity Scale: Controls how strongly gravity affects the entity (default is 0.0).

```swift
setMass(entityId: redPlayer, mass: 0.5)
setGravityScale(entityId: redPlayer, gravityScale: 1.0)
```

### Apply Forces (Optional)
You can apply a custom force to the entity for dynamic movement. This is useful for simulating actions like jumps or pushes.

```swift
applyForce(entityId: redPlayer, force: simd_float3(0.0, 0.0, 5.0))
```

> Note: Forces are applied per frame. To avoid unintended behavior, only apply forces when necessary.

### Use the Steering System
For advanced movement behaviors, leverage the Steering System to steer entities toward or away from targets. This system automatically calculates the required forces.

Example: Steering Toward a Position

```swift
steerTo(entityId: redPlayer, targetPosition: simd_float3(0.0, 0.0, 5.0), maxSpeed: 2.0, deltaTime: deltaTime)
```

### Additional Steering Functions

The Steering System includes other useful behaviors, such as:

- steerAway()
- steerPursuit()
- followPath()

These functions simplify complex movement patterns, making them easy to implement.

---

# Components 

### Register Components

Components define the behavior or attributes of an entity. Use registerComponent to add a component to an entity.

```swift
let entity = createEntity()

registerComponent(entityId: entity, componentType: RenderComponent.self)
```

### Create Custom Component 

Here’s an example of a simple custom component for a soccer player’s dribbling behavior:  

```swift
public class DribblinComponent: Component {
    public required init() {}
    var maxSpeed: Float = 5.0
    var kickSpeed: Float = 15.0
    var direction: simd_float3 = .zero
}
```

> ⚠️ Note: Components should not include functions or game logic. Keep them as pure data containers.

### Attaching a Component to an Entity

Once you’ve defined a component, you attach it to an entity in your scene:

```swift
let player = createEntity(name: "player")

// Attach DribblinComponent to the entity
registerComponent(entityId: player, componentType: DribblinComponent.self)
```

# Systems 

### Create Custom System 

If you’ve created a **custom component**, you’ll usually also want to create a **custom system** to make it do something.  
Components store the data, but systems are where the behavior lives.  

The engine automatically calls systems every frame.  

Here’s a simple system that works with the `DribblinComponent` we defined earlier:  

```swift
public func dribblingSystemUpdate(deltaTime: Float) {
    // 1. Get the ID of the DribblinComponent
    let customId = getComponentId(for: DribblinComponent.self)

    // 2. Query all entities that have this component
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    // 3. Loop through each entity and update its data
    for entity in entities {
        guard let dribblingComponent = scene.get(component: DribblinComponent.self, for: entity) else {
            continue
        }

        // Example logic: move player in the dribbling direction
        dribblingComponent.direction = simd_normalize(dribblingComponent.direction)
        let displacement = dribblingComponent.direction * dribblingComponent.maxSpeed * deltaTime

        if let transform = scene.get(component: LocalTransformComponent.self, for: entity) {
            transform.position += displacement
        }
    }
}
```

### Registering the Custom System
All custom systems must be registered during initialization so the engine knows to run them every frame:

```swift
registerCustomSystem(dribblingSystemUpdate)
```
