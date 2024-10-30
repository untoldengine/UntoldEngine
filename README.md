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

To enter "game mode" press 'l'. To move the car use the normal the 'wasd' keys

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


