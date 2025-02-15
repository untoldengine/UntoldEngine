---
layout: page
title: Rendering
permalink: /rendering/
nav_order: 7
---

# Enabling Rendering System in Untold Engine

The Rendering System in the Untold Engine is responsible for displaying your models on the screen. It supports advanced features such as Physically Based Rendering (PBR) for realistic visuals and multiple types of lights to illuminate your scenes.

## Why Use the Rendering System?

The rendering system brings your models to life by handling:

- Loading and displaying 3D models.
- Adding lighting for illumination.
- Supporting PBR materials (if textures are provided).
- Rendering with multiple light types, including Directional Lights and Point Lights.

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

### Adding Lights to Your Scene

Lighting is essential for making objects visible. The Untold Engine supports two main types of lights:

1. Directional Lights

Directional lights mimic sunlight and illuminate everything in the scene from a specific direction.

Steps to Add a Directional Light:

```swift
// Step 1: Create an entity for the directional light
let sunEntity: EntityID = createEntity()

// Step 2: Create the directional light instance
let sun: DirectionalLight = DirectionalLight()

// Step 3: Add the entity and the light to the lighting system
lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
```

2. Point Lights

Point lights emit light in all directions from a single point, similar to a light bulb.

Steps to Add a Point Light:

```swift
// Step 1: Create an entity for the point light
let pointEntity: EntityID = createEntity()

// Step 2: Create the point light instance
var point = PointLight()

// Step 3: Set the position of the point light
point.position = simd_float3(1.0, 1.0, 0.0)

// Step 4: Add the entity and the light to the lighting system
lightingSystem.addPointLight(entityID: pointEntity, light: point)
```

> Tip: Use directional lights for large, outdoor scenes and point lights for localized lighting effects, such as lamps or torches.

---

## What Happens Behind the Scenes?

1. Mesh Loading: The .usdc file is parsed, and the model’s geometry and associated textures (if any) are loaded into the rendering pipeline.
2. Lighting System: Lights (directional and point) are added to the scene graph, affecting the illumination of objects.
3. PBR Support:
- If PBR textures are available, the rendering system uses shaders to calculate realistic reflections, shading, and material interactions.
4. Visibility: Objects in the scene become visible only when lit by at least one light source.
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

### Running the Rendering System

Once everything is set up:

1. Run the project.
2. Your model will appear in the game window, illuminated by the configured lights.
3. If the model is not visible or appears flat, revisit the lighting and texture setup to ensure everything is loaded correctly.

