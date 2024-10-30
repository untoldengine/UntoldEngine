# Untold Engine

## Introduction

Welcome to Untold Engine! 

The Untold Engine is a custom 3D game engine built with Swift and Metal, designed for ease of use. Originally, the engine was written in C++ following Object-Oriented Programming (OOP) principles. However, it was rewritten in Swift to adopt Data-Oriented Design (DOD) principles.

The engine now leverages the Entity Component System (ECS) architecture, which decouples data from behavior. This approach enables developers to build complex scenes and systems more effectively, while also making better use of modern CPU and GPU architectures.

Currently, this new version of the engine does not have a Physics or Animation system, but both features are actively being developed and will be included in future updates.

Author: [Harold Serrano](http://www.haroldserrano.com)

## Running the Untold Engine

To run the the Untold Engine, you need the following tools:

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

To enter/exit "game mode" press 'l'. To move the car use the normal 'WASD' keys


## Quick tutorial

### Creating a game entity 

Let's say you have a Blender scene as follows. First, you will export it as a "usdc" file.

![blender_scene1](images/blendercar.png)

In the scene above, note that the model is called "redcar". I will export the scene as "redcar.usdc" and will save it 
in the Resource folder. (Sources/UntoldEngine/Resource)

To load the scene in the engine, do the following:

```
loadScene(filename:"redcar", withExtension:"usdc")
```

The function above, loads the scene data. To add the mesh to an entity. You need to create an entiy and then link the mesh tothe entity, as shown below:

```
// create entity 
var carEntity:EntityID=createEntity()

// add mesh to entity 
addMeshToEntity(entityId: carEntity, name: "redcar")  // name refers to the name of the model 
```

### Translating a model 

To translate a model, you need to provide the entity ID and new position to the Translation System, as shown below:

`translateTo(entityId:redcar,position:simd_float3(2.5,0.75,20.0))`


### Loading models in bulk

Many times, you will have a scene with multiple models such as buildings, trees, etc. If you are not planing on manipulating these models (i.e. translating, rotating, etc), you can load them in bulk without the need to create an entity ID for each of them.

`loadBulkScene(filename: "racetrack", withExtension: "usdc") //racetrack refers to the name of the file`

### Creating a Sun (directional light)

To add a directional light, you must first create an entity. Next, you create an instance of the directional light. Finally, you add the entity and the directional light to the lighting system, as shown below.

```
// You can also set a directional light. Notice that you need to create an entity first. 
let sunEntity:EntityID=createEntity()

// Then you create a directional light 
let sun:DirectionalLight = DirectionalLight()

// and finally, you add the entity and the directional light to the ligthting system. 
lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
```

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


