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

```bash
git clone https://github.com/untoldengine/UntoldEngine

cd UntoldEngine
```

2. Open the Swift Package

```bash
open Package.swift
```
3. Xcode should open up. In the scheme settings, make sure to select "UntoldEngineTestApp" and "myMac" as your target.

![xcodescheme](images/xcodescheme.png)

4. Click on Run

You should see models being rendered.

![gamesceneimage](images/gamescene1.png)

To enter/exit "game mode" press 'L'. To move the car use the normal 'WASD' keys

If you want to get a feel for the API, head to main.swift file inside Sources->UntoldEngineTestApp

## Using the Untold Engine in your game

- [Getting Started](docs/GettingStarted.md)
- [Importing USDC Files](docs/Importing-USD-Files.md)
- [Creating a game entity](docs/CreatingAnEntity.md)
- [Adding Light to your game](docs/AddingLighttoyourgame.md)


## Current Version

Beta version v0.1.0. 

## License

The Untold Engine is licensed under the LGPL v2.1. This means that if you develop a game using the Untold Engine, you do not need to open source your game. However, if you create a derivative of the Untold Engine, then you must apply the rules stated in the LGPL v2.1. That is, you must open source the derivative work.


## Contributing to Untold Engine

Since this project has barely been released as an open-source, I am not taking Pull-Request yet. I want to complete the documentation and write more tutorials before allowing Pull-Request.

If you want to help out, I would appreciate if you could report back any bugs you encounter. Make sure to report them at our [Github issues](https://github.com/untoldengine/UntoldEngine/issues), so we all have access to them.

Thank you.

Once I feel that the documentation is ready, I will allow Pull-Request.


