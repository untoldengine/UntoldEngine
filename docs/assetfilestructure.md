## Asset Folder Structure

When setting your **Asset Path**, it’s recommended to organize your folder using the following structure:

```text
Assets/
├── Animations/        # Store .usdc animation files here
│   ├── walk/
│   │   └── walk.usdc
│   └── jump/
│       └── jump.usdc
│
├── HDR/               # Environment lighting maps (.hdr)
│   ├── studio.hdr
│   ├── desert.hdr
│   └── forest.hdr
│
├── Materials/         # Materials with textures
│   └── Wood-Material/
│       ├── Wood_BaseColor.png
│       ├── Wood_Normal.png
│       ├── Wood_Roughness.png
│       ├── Wood_Metalness.png
│
└── Models/            # 3D models (.usdc) with a textures folder
    ├── tree/
    │   ├── tree.usdc
    │   └── textures/
    │       ├── Tree_Color.png
    │       ├── Tree_Normal.png
    │       └── Tree_Roughness.png
    └── character/
        ├── character.usdc
        └── textures/
            ├── Character_Color.png
            ├── Character_Normal.png
            └── Character_Roughness.png
```

### Key Points

* Animations: Place each animation .usdc in its own folder for clarity.
* HDR: Keep environment maps together for easy IBL (Image-Based Lighting) setup.
* Materials: Each material gets its own folder with all required textures.
* Models: Each model gets its own folder with a .usdc file and a textures/ subfolder containing its textures.

For reference, download the [Demo Game Asset v1.0](https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1) folder. 

⚠️ Tip: The engine expects this structure. Keeping a clean hierarchy will make asset importing smoother in the Editor.
