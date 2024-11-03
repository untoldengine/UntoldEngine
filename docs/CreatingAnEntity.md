# Creating a game entity

The Untold Engine uses the concept of ECS, i,e Entity-Component-System. Thus, the first thing you must do is create an entity. An entity creation is done as follows:

Let's say that you loaded a redcar.usdc file which contains a model called 'redcar'. The function below loads the scene and makes the mesh available for use.

```swift
loadScene(filename: "redcar", withExtension: "usdc")
```

To create an entity, create a game entity and link the mesh to it as shown below:

```swift

init(){

    // Step 1. Assume redcar.usdc has a model named 'redcar'
    loadScene(filename: "redcar", withExtension: "usdc")
    
    // Step 2: Create an entity
    var carEntity: EntityID = createEntity()

    // Step 3: Attach the mesh to the entity
    addMeshToEntity(entityId: carEntity, name: "redcar")  // 'name' refers to the model name in the scene

}

```

With this setup, the redcar mesh is now associated with your game entity, ready for rendering and interaction.

With an entityID, you can use the TransformSystem to change the position/orientation of the model. Here is an example:

```swift
translateTo(entityId:redcar,position:simd_float3(2.5,0.75,20.0))
```

Take a look at TransformSystem.swift for similar operations such as rotation.

