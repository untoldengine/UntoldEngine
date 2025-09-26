---
id: renderingsystem
title: Rendering System
sidebar_position: 2
---

# Enabling Rendering System in Untold Engine

The Rendering System in the Untold Engine is responsible for displaying your models on the screen. It supports advanced features such as Physically Based Rendering (PBR) for realistic visuals and multiple types of lights to illuminate your scenes.

## How to Enable the Rendering System

### Step 1: Create an Entity

Start by creating an entity that represents your 3D object.

```swift
let entity = createEntity()
```
---

### Step 2: Link a Mesh to the Entity

To display a model, load its .usdc file and link it to the entity using setEntityMesh.

```swift
setEntityMesh(entityId: entity, filename: "entity", withExtension: "usdc")
```

Parameters:

- entityId: The ID of the entity created earlier.
- filename: The name of the .usdc file (without the extension).
- withExtension: The file extension, typically "usdc".

> Note: If PBR textures (e.g., albedo, normal, roughness, metallic maps) are included, the rendering system will automatically use the appropriate PBR shader to render the model with realistic lighting and material properties.

---

### Running the Rendering System

Once everything is set up:

1. Run the project.
2. Your model will appear in the game window, illuminated by the configured lights.
3. If the model is not visible or appears flat, revisit the lighting and texture setup to ensure everything is loaded correctly.

---

## Common Issues and Fixes

#### Issue: My Model Isn’t Visible!

- Cause: The scene lacks a light source.
- Solution: Add a directional or point light as shown above. Lighting is required to render objects visibly.

#### Issue: Model Appears Flat or Dull

- Cause: PBR textures are missing or not linked properly.
- Solution: Ensure the .usdc file includes the correct PBR textures, and verify their paths during the loading process.

#### Debugging Tip:

- Log the addition of lights and entities to verify the scene setup.
- Ensure the position of the point light is within the visible range of the camera and the objects it is meant to illuminate.

---

### Tips and Best Practices

- Combine Light Types: Use directional lights for overall scene lighting and point lights for localized effects.
- Use PBR Materials: Provide high-quality PBR textures for realistic rendering.
- Position Lights Intelligently: Place point lights strategically to highlight key areas without excessive overlap.

---


