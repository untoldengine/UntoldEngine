---
id: gaussiansystem
title: Gaussian System
sidebar_position: 3
---

# Enabling Gaussian System in Untold Engine

The Gaussian System in the Untold Engine is responsible for rendering Gaussian Splatting models. It enables you to visualize high-quality 3D reconstructions created from photogrammetry or neural rendering techniques, providing a modern approach to displaying complex 3D scenes.

## How to Enable the Gaussian System

### Step 1: Create an Entity

Start by creating an entity that represents your Gaussian Splat object.

```swift
let myEntity = createEntity()
```
---

### Step 2: Link a Gaussian Splat to the Entity

To display a Gaussian Splat model, load its .ply file and link it to the entity using setEntityGaussian.

```swift
setEntityGaussian(entityId: myEntity, filename: "splat", withExtension: "ply")
```

Parameters:

- entityId: The ID of the entity created earlier.
- filename: The name of the .ply file (without the extension).
- withExtension: The file extension, typically "ply".

> Note: The Gaussian System renders point cloud data stored in the .ply format. Ensure your Gaussian Splat file is properly formatted and contains the necessary attributes (position, color, opacity, scale, rotation).

---

### Running the Gaussian System

Once everything is set up:

1. Run the project.
2. Your Gaussian Splat model will appear in the game window.
3. If the model is not visible or appears incorrect, revisit the file path and format to ensure everything is loaded correctly.

