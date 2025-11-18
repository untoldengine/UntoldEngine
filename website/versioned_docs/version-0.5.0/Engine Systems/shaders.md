---
id: shaders
title: Shaders
sidebar_position: 9
---

# Working with Shaders

Untold Engine's shaders are now open source and can be modified to suit your needs. All Metal shader files are compiled into a single ".metallib" file, which is then used by the Untold Engine. Here's how to work with shaders in the Untold Engine:

## Modifying Existing Shaders

1. Locate the shader file you wish to modify in the UntoldEngine/Shaders folder.
2. Make your changes to the .metal file.
3. Run the following command to recompile the shaders into the .metallib file:

```bash 
make compile-shaders
```

4. Build the engine to incorporate your changes:

```bash 
swift build
```

Alternatively, you can call "make" to compile the shaders and build the engine 

```bash
make
```

## Adding New Shaders

If you want to add a new shader:

1. Create a new .metal file in the UntoldEngine/Shaders folder.
2. Open the UntoldEngineKernels.metal file located in the UntoldEngineKernels folder.
3. Add an #include directive for your new shader file in UntoldEngineKernels.metal. For example:

```
#include "YourNewShaderFile.metal"
```

4. Compile the shaders:

```bash
make compile-shaders
```

5. Build the engine 

```bash
swift build
```

Alternatively, you can call "make" to compile the shaders and build the engine 

```bash
make
```

## Cleaning Build Artifacts

If you encounter issues or want to reset the build, you can clean the build artifacts using:

```bash 
make clean
```
