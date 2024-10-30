# Untold Engine

## Introduction

Welcome to Untold Engine! 

The Untold Engine is a custom 3D game engine built with Swift and Metal, designed for ease of use. Originally, the engine was written in C++ following Object-Oriented Programming (OOP) principles. However, it was rewritten in Swift to adopt Data-Oriented Design (DOD) principles.

The engine now leverages the Entity Component System (ECS) architecture, which decouples data from behavior. This approach enables developers to build complex scenes and systems more effectively, while also making better use of modern CPU and GPU architectures.

Currently, this new version of the engine does not have a Physics or Animation system, but both features are actively being developed and will be included in future updates.

Author: [Harold Serrano](http://www.haroldserrano.com)

## Running the Untold Engine

To run the the Untold Engine, do the following:

1. Clone the Repository

`git clone https://github.com/untoldengine/UntoldEngine`

`cd UntoldEngine`

2. Build the engine using the provided Makefile

`make`

3. Alternatively, you can also run a clean on the build 

`make clean`

4. Run the engine 

`swift run UntoldEngineTestApp`

You should see models being rendered.

![gamesceneimage](images/gamescene1.png)

To enter/exit "game mode" press 'L'. To move the car use the normal 'WASD' keys


## Creating a game entity 

Let’s say you have a **Blender scene** with a model named `"redcar"`. Follow these steps to integrate it into your game using the engine.

![blendercar](images/blendercar.png)

### 1. Export the Blender Scene

- Export the scene as a **`usdc` file**. (Make sure that Reference Paths is unchecked in Blender)
- Save it with the name `"redcar.usdc"` in the **Resource folder**:  
  `Sources/UntoldEngine/Resource/Models`.

### 2. Load the Scene in the Engine

Use the following function to load the scene data into the engine:  

```swift
loadScene(filename: "redcar", withExtension: "usdc")
```

This function loads the scene and makes the mesh available for use.

### 3. Create an Entity and Attach the Mesh

To use the "redcar" model, create a game entity and link the mesh to it as shown below:

```swift
// Step 1: Create an entity
var carEntity: EntityID = createEntity()

// Step 2: Attach the mesh to the entity
addMeshToEntity(entityId: carEntity, name: "redcar")  // 'name' refers to the model name in the scene
```

With this setup, the redcar mesh is now associated with your game entity, ready for rendering and interaction.

### Translating a model 

To translate a model, you need to provide the entity ID and new position to the Translation System, as shown below:


```swift
translateTo(entityId:redcar,position:simd_float3(2.5,0.75,20.0))
```

Take a look at TransformSystem.swift for similar operations such as rotation.

### Loading Multiple Models at Once

Often, your scene will contain several models, such as buildings, trees, or other static objects. If you **don’t need to manipulate these models individually** (e.g., translate, rotate, or scale them), you can load the entire scene at once. This approach saves time since you won’t need to create an `EntityID` for each individual model.

Use the following function to load the scene:

```swift
loadBulkScene(filename: "racetrack", withExtension: "usdc") 
```

In this example, "racetrack" refers to the name of the file (e.g., racetrack.usdc). All models within the scene will be loaded and rendered together without requiring separate entity IDs for each one.


### Creating a Sun (Directional Light)

To add a **directional light** (such as the sun), follow these steps:

1. **Create an entity** to represent the light.
2. **Create a directional light instance**.
3. **Add both the entity and the directional light** to the lighting system.

Here’s how you can do it:

```swift
// Step 1: Create an entity for the directional light
let sunEntity: EntityID = createEntity()

// Step 2: Create the directional light instance
let sun: DirectionalLight = DirectionalLight()

// Step 3: Add the entity and the light to the lighting system
lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
```

This setup ensures the directional light is registered in the lighting system, ready to illuminate your scene.


## Including the Untold Engine in an Xcode Project 

### Step 1. Add the engine as a Package Dependency

1. Open your Xcode project 

2. Go to File-> Add Packages...

3. In the search field, enter the URL of the Untold Engine repository:

https://github.com/untoldengine/UntoldEngine.git 

4. Xcodw will fetch the package. Select the appropriate version or branc( i.e. Master)

5. Choose the target where you want to add the engine, then click Add Package 

### Step 2. Import the Untold Engine in your code 

Once the package is added, you can import the Untold Engine in your Swift files:

`import UntoldEngine`

### Step 3. Build and Run your project 

1. Select your project scheme in Xcode.

2. Choose a Metal-capable device (if testing on a real device).

3. Build and run your project to ensure everything works correctly.

## Current Version

Beta version v0.1.0. 

## License

The Untold Engine is licensed under the LGPL v2.1. This means that if you develop a game using the Untold Engine, you do not need to open source your game. However, if you create a derivative of the Untold Engine, then you must apply the rules stated in the LGPL v2.1. That is, you must open source the derivative work.


## Contributing to Untold Engine

Since this project has barely been released as an open-source, I am not taking Pull-Request yet. I want to complete the documentation and write more tutorials before allowing Pull-Request.

If you want to help out, I would appreciate if you could report back any bugs you encounter. Make sure to report them at our [Github issues](https://github.com/untoldengine/UntoldEngine/issues), so we all have access to them.

Thank you.

Once I feel that the documentation is ready, I will allow Pull-Request.


