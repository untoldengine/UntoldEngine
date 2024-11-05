# Importing USDC files for your game

The Untold Engine supports usdc files. To ensure that you are exporting files correctly from Blender, 
make sure to check "Relative Paths" as shown below.

![usdcfileproperties](../images/usdcexportproperties.png)

Furthermore, all usdc files should be saved into your project and loaded into the main bundle, as shown below.

![addfilestomainbundle](../images/addfilestomainbundle.png)

Once a scene has been exported, you can load the scene in your game as follows:

```swift
init() {
    
    // Load individual assets. bluecar is the name of the usdc file
    loadScene(filename: "bluecar", withExtension: "usdc")

}

```

Often, your scene will contain several models, such as buildings, trees, or other static objects. If you **don’t need to manipulate these models individually** (e.g., translate, rotate, or scale them), you can load the entire scene at once. This approach saves time since you won’t need to create an `EntityID` for each individual model.

Use the following function to load the scene:

```swift
loadBulkScene(filename: "racetrack", withExtension: "usdc") 
```

In this example, "racetrack" refers to the name of the file (e.g., racetrack.usdc). All models within the scene will be loaded and rendered together without requiring separate entity IDs for each one.

Next: [Creating a game entity](CreatingAnEntity.md)
Previous: [Getting Started](GettingStarted.md)
