# Importing USDC files for your game

The Untold Engine supports .usdc files, making it easy to import 3D models and scenes into your game. This tutorial will guide you through the correct export settings in Blender, adding files to your project, and loading them into your game.

---

## Requirements

If exporting the files yourself, make sure to use Blender 4.2.3 or later

## How to export a file to USDC

The Untold Engine requires all files to be of type usdc. To export your model or scene from Blender, click on File->Export->USD

![howtoexport](../images/howtoexport.png)

## Exporting models 

To ensure proper export of .usdc files from Blender:

1. Check the "Relative Paths" Option during export. This ensures that all referenced assets, such as textures, are correctly linked relative to the .usdc file.

![usdcfileproperties](../images/modelexportblender.png)

2. Save the exported .usdc files into your project and ensure they are added to the main bundle, as shown below:

![addfilestomainbundle](../images/addfilestomainbundle.png)

---

## Exporting models for Animation

Exporting models with animations require that you also export its rig/armature. During exporting, make sure to have "Rigging" selected.

![modelsrigged](../images/modelsriggedexportblender.png)

---

## Exporting Animations

Similarly, to export an animation, make sure Animation is selected.

![animation](../images/animationexportblender.png)

Next: [Creating a game entity](CreatingAnEntity.md)
Previous: [Getting Started](GettingStarted.md)
