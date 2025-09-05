# Importing Assets into the Untold Engine

Before you can load models into your scene, you’ll need to set up the **Asset Browser** with a valid folder path. This folder will hold your models, textures, and animations.

---

## 1. Setting the Asset Path

1. Create a folder on your computer where you’ll store your game’s assets.  
   *(Example: `MyGreatGameAssets/`)*  
2. In the **Asset Browser**, click the **Set Path** button.  
3. Select the folder you created. This tells the engine where to look for models, textures, and animations.  

⚠️ You must create the folder beforehand — the engine will not generate it automatically.  

### Why Set Path?

When the engine is running, it cannot import new files directly into the application’s **bundle folder**. By pointing to an external folder, you can freely import new assets (models, animations, materials) while the editor is running. This makes iteration faster and avoids the need to rebuild the app each time you want to add a new file.

---

## 2. Importing 3D Models

Currently, the engine supports **USDC models** only. Each model should be organized with:  
- A `.usdc` file (the 3D mesh).  
- A corresponding `textures/` folder that contains the model’s materials.  

**Steps to import a model:**  
1. In the **Asset Browser**, click on **Models**.  
2. Navigate to the folder containing your `.usdc` file and its `textures/` folder.  
3. Select the `.usdc` file.  
4. The engine will automatically import the model and link its textures.  

---

## 3. Importing Animations

Animations are also stored in `.usdc` format.  

**Steps to import an animation:**  
1. In the **Asset Browser**, click on **Animations**.  
2. Navigate to your animation `.usdc` file.  
3. Select the file to import it.  

---

## 4. Importing Materials

Materials can be imported directly as a set of texture maps.  

**Steps to import materials:**  
1. In the **Asset Browser**, click on **Materials**.  
2. Navigate to the folder where you’ve stored your texture maps (e.g., Base Color, Roughness, Metallic).  
3. Select the folder to import all textures at once.  

Once imported, you can assign materials to entities in the **Inspector**.

---

With this workflow in place, you’ll use the **Set Path** to define your game’s asset library once, then freely add models, animations, and materials while building your scene.

