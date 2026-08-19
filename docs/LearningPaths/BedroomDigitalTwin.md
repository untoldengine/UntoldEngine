# Bedroom Digital Twin

This learning path turns a structured bedroom model into an interactive Vision Pro digital twin.

The purpose is to show how Untold Engine can give different runtime behavior to different parts of the same room:

- Window geometry can act as a light portal.
- Window geometry can use passthrough ghost rendering.
- Context geometry can be rendered normally, hidden, or shown as wireframe.
- Named objects can remain selectable and show mock digital-twin state.
- The whole room can be moved and rotated with spatial gestures.

By the end of the path, you will have a Vision Pro scene where the bedroom is not just rendered as a model. It behaves like a structured spatial twin.

## What You Will Build

The example scene is a bedroom with:

- floor, ceiling, and walls
- a window with glass
- selectable furniture and devices
- mock status data for selected objects
- Vision Pro spatial manipulation

The main engine systems are:

- `setEntityMeshAsync` for loading the room
- `loadSceneAuthored` for Blender-authored color management (see the note in [Replace The Starter Asset With Your Own Bedroom Scene](#replace-the-starter-asset-with-your-own-bedroom-scene) about lights and cameras)
- `SceneChannel` for geometry categories
- a light portal for window lighting
- passthrough ghost render mode for mixed reality
- XR spatial input for selection and room manipulation

This path uses the starter digital-twin asset pack so you can focus on the engine workflow first. After this is working, you can replace the starter asset with your own Blender export.

## Create The Vision Pro Project

Create a standalone visionOS project:

```bash
cd ~/Projects
untoldengine create BedroomTwin --platform visionos
open BedroomTwin/BedroomTwin.xcodeproj
```

Open:

```text
Sources/BedroomTwin/GameScene.swift
```

## Install The Starter Digital Twin Asset

From the generated project folder, install the starter digital-twin asset pack:

```bash
cd ~/Projects/BedroomTwin
untoldengine assets install starter-digital-twin
```

The CLI finds the project's `GameData` folder and merges the asset files into it.

The important file for this path is the `DigitalTwin.untold` model, installed under:

```text
Sources/BedroomTwin/GameData/Models/DigitalTwin/
  DigitalTwin.untold
  Textures/
  ...
```

## Room Naming Reference

The starter pack's `DigitalTwin.untold` model is already structured for this path:

- Ordinary names for the room shell and static furniture (`Floor`, `Ceiling`, `Walls`, `Bed`, `Chair`, and similar) — these fall into the default `.contextGeometry` channel.
- A `WIN_` prefix on the window and its glass: `WIN_Window`, `WIN_Window_Glass`.
- An `NM_` prefix on the objects that stay selectable and carry mock digital-twin state.

| Name | Role |
| --- | --- |
| `NM_Table_Lamp` | Light fixture — on/off, brightness |
| `NM_CeilingLamp_Left` / `NM_CeilingLamp_Right` | Light fixtures — on/off, brightness |
| `NM_Door` | Smart lock — open/closed, locked/unlocked |
| `NM_Curtains` | Smart blinds — position, automation |
| `NM_Laptop` | General smart device |

This naming gives the engine enough structure to treat the room shell, the window, and operational objects differently. If you want to build this scene from your own source model instead of the starter pack, see [Replace The Starter Asset With Your Own Bedroom Scene](#replace-the-starter-asset-with-your-own-bedroom-scene).

## Define Room Channels

In your game scene code, define a custom scene channel for the window:

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 0)
}
```

Then register the `WIN_` prefix before loading the room:

```swift
registerSceneChannelPrefix("WIN_", channels: .windowGeometry)
```

When the exported entities are registered, objects named `WIN_Window` and `WIN_Window_Glass` will be assigned to `.windowGeometry`.

Objects with the `NM_` prefix already use the engine's selectable-object convention. They default to `.selectableGeometry` and `.preserveIdentity`, which keeps them pickable and prevents them from being merged into context batches.

## Configure Channel Behavior

Set up the room behavior before or immediately after loading the asset:

```swift
setSceneChannel(.contextGeometry, .pickParticipation(false))
setSceneChannel(.contextGeometry, .renderMode(.normal))

setSceneChannel(
    .windowGeometry,
    .renderMode(.passthroughGhost(opacity: 0.0))
)

setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 0.5,
        range: 4.0,
        useRealWorldTint: true,
        maxActivePortals: 4,
        activationDistance: 10.0
    ))
)
```

This setup does three things:

- Context geometry such as walls, floor, and ceiling is not pickable.
- Window geometry becomes a passthrough ghost surface in mixed reality.
- Window geometry also acts as a light-portal source.

For a more diagnostic look, switch context geometry to wireframe:

```swift
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
```

For a cutaway view, hide context geometry:

```swift
setSceneChannel(.contextGeometry, .renderMode(.hidden))
```

Selectable `NM_` objects remain visible and pickable while the room shell changes render modes.

## Load The Bedroom

In `init()`, configure the engine systems, register the prefix, configure channels, then load the asset:

```swift
configureEngineSystems()

registerSceneChannelPrefix("WIN_", channels: .windowGeometry)

setSceneChannel(.contextGeometry, .pickParticipation(false))
setSceneChannel(.contextGeometry, .renderMode(.normal))

setSceneChannel(
    .windowGeometry,
    .renderMode(.passthroughGhost(opacity: 0.0))
)

setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 0.5,
        range: 4.0,
        useRealWorldTint: true,
        maxActivePortals: 4,
        activationDistance: 10.0
    ))
)

let room = createEntity()
setEntityName(entityId: room, name: "DigitalTwin")

setEntityMeshAsync(entityId: room, filename: "DigitalTwin", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    loadSceneAuthored(filename: "DigitalTwin", withExtension: "untold")
    setSceneReady(true)
}
```

`setEntityMeshAsync` looks for the asset by name in `GameData`, so the filename is `"DigitalTwin"` and the extension is `"untold"`.

## Configure XR Input And Rendering

Use the same Vision Pro setup pattern as the archviz path:

```swift
private func configureEngineSystems() {
    gameMode = true

    registerXREvents()
    setInput(.xr(.pickingBackend(.octreeGPUPreferred)))
    setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))
    setInput(.xr(.sceneReady(true)))

    setRendering(.postProcessing(.enabled))
    setRendering(.antiAliasing(.msaa))
    setPostFX(.ssao(.enabled(false)))

    setRendering(.environment(.lightingMode(.realWorldEstimate)))
    setRendering(.environment(.realWorldLightingContribution(1.0)))

    TextureStreamingSystem.shared.apply(.superdetailed)
}
```

The real-world lighting calls are useful when `useRealWorldTint` is enabled for the light portal.

## Add Mock Digital-Twin State

For the first version, keep the data local and simple. The tutorial is about the engine workflow, not live IoT infrastructure.

```swift
struct TwinObjectInfo {
    let title: String
    let status: String
    let detail: String
}

let twinInfoByName: [String: TwinObjectInfo] = [
    "NM_Table_Lamp": TwinObjectInfo(
        title: "Table Lamp",
        status: "On",
        detail: "Brightness: 80%"
    ),
    "NM_CeilingLamp_Left": TwinObjectInfo(
        title: "Ceiling Lamp (Left)",
        status: "On",
        detail: "Brightness: 60%"
    ),
    "NM_CeilingLamp_Right": TwinObjectInfo(
        title: "Ceiling Lamp (Right)",
        status: "Off",
        detail: "Brightness: 0%"
    ),
    "NM_Door": TwinObjectInfo(
        title: "Bedroom Door",
        status: "Closed",
        detail: "Lock: Engaged"
    ),
    "NM_Curtains": TwinObjectInfo(
        title: "Curtains",
        status: "Online",
        detail: "Position: 30% | Automation: Enabled"
    ),
    "NM_Laptop": TwinObjectInfo(
        title: "Laptop",
        status: "Sleep",
        detail: "Battery: 62%"
    )
]
```

In a real app, this data could come from a building system, smart-home API, database, or web service. In this learning path, mocked state keeps the focus on selection and runtime behavior.

## Select Room Objects

A multi-material object exports as one entity per material — `NM_Table_Lamp` becomes `NM_Table_Lamp_mat0`, `NM_Table_Lamp_mat1`, and so on, each a top-level entity with no parent wrapper. Only single-material objects (`NM_Curtains`, `NM_Laptop` in this pack) export with their bare name intact. Strip a trailing `_mat<N>` before looking up `twinInfoByName` so picking any submesh of a multi-material object still resolves:

```swift
func twinLookupName(for entityId: EntityID) -> String {
    var name = getEntityName(entityId: entityId)
    if let range = name.range(of: #"_mat\d+$"#, options: .regularExpression) {
        name.removeSubrange(range)
    }
    return name
}
```

Use spatial tap state to select `NM_` objects:

```swift
private var selectedTwinObject: TwinObjectInfo?

func handleInput() {
    guard gameMode, isSceneReady() else { return }

    var state = getXRSpatialInputState()

    if state.spatialTapActive, let picked = state.pickedEntityId {
        selectedTwinObject = twinInfoByName[twinLookupName(for: picked)]

        if let info = selectedTwinObject {
            Logger.log(message: "\(info.title): \(info.status) - \(info.detail)")
        }
    }

    SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle(
        from: state,
        dragSensitivity: 10.0,
        rotateSensitivity: 1.0
    )
}
```

Because `.contextGeometry` picking is disabled, taps should ignore the room shell and return selectable `NM_` objects instead.

In a full app, `selectedTwinObject` would drive a SwiftUI overlay, inspector panel, or floating label. For this path, logging the selected object is enough to confirm that the selection model works.

## Add Runtime View Modes

A digital twin viewer often needs more than one view of the same model. Use scene-channel render modes to expose simple modes:

```swift
enum BedroomViewMode {
    case normal
    case wireframeShell
    case hiddenShell
    case passthroughWindow
}

func applyViewMode(_ mode: BedroomViewMode) {
    switch mode {
    case .normal:
        setSceneChannel(.contextGeometry, .renderMode(.normal))
        setSceneChannel(.windowGeometry, .renderMode(.normal))

    case .wireframeShell:
        setSceneChannel(.contextGeometry, .renderMode(.wireframe))
        setSceneChannel(.windowGeometry, .renderMode(.normal))

    case .hiddenShell:
        setSceneChannel(.contextGeometry, .renderMode(.hidden))
        setSceneChannel(.windowGeometry, .renderMode(.normal))

    case .passthroughWindow:
        setSceneChannel(.contextGeometry, .renderMode(.normal))
        setSceneChannel(.windowGeometry, .renderMode(.passthroughGhost(opacity: 0.0)))
    }
}
```

This is the core digital-twin idea in the tutorial: the model is structured, so each category can have a different runtime behavior.

## Verify Light Portals

Use diagnostics when setting up the scene:

```swift
let candidates = discoverSceneLightPortalCandidates()
let discovery = getLightPortalDiscoveryDiagnostics()
print(candidates)
print(discovery)
```

If no candidates are found, check:

- window objects use the `WIN_` prefix
- `registerSceneChannelPrefix("WIN_", channels: .windowGeometry)` runs before loading
- window geometry has renderable bounds
- the channel has `.lightPortal(.enabled(...))`

## What This Learning Path Demonstrates

The bedroom scene behaves as a digital twin because the exported model has runtime structure:

- The shell is context geometry.
- The window has a project-specific channel.
- Named room objects stay selectable.
- The light portal uses the window channel.
- Passthrough ghost rendering uses the same window channel.
- Spatial input lets the user inspect and manipulate the room.
- Mock metadata gives selections meaning beyond rendering.

This is the foundation you would extend with live device data, building-management APIs, object-specific controls, annotations, or persistence.

## Replace The Starter Asset With Your Own Bedroom Scene

Once the starter pack works, the next step is exporting your own bedroom (or similar room) model.

This path's starter pack was built from a stock archviz bedroom asset whose objects were not pre-named for the engine's conventions. Getting from a similar stock asset to something like `DigitalTwin.untold` means:

1. Rename context geometry normally — the room shell and static furniture keep ordinary names.
2. Add a `WIN_` prefix to window/glass geometry only. Curtains, blinds, and other window dressing are not glazing — leave them as context geometry or a selectable twin object instead, since the light portal expects a transparent surface.
3. Add an `NM_` prefix to whatever should stay selectable and carry mock state — lamps, a door, blinds, small devices.

Three cleanup steps mattered when preparing this pack's source model, and are worth checking on any similar stock asset:

- **Drop baking-helper geometry.** The source file had a `Light_Blocking_Volume` mesh — an EEVEE baking helper sized to enclose the room, not meant to render at runtime. Exclude anything like it, or mark it hidden/non-pickable context geometry.
- **Parent light-fixture glow meshes to their fixture.** Small emissive "bulb" meshes are sometimes separate top-level objects rather than children of the fixture they belong to. Parent them before renaming, the same way glass should be parented under its window frame — otherwise selecting the fixture only picks up the shell, not its glow.
- **Check for Blender light and camera objects.** Stock EEVEE archviz assets sometimes bake all lighting into emissive materials and ship with zero `LIGHT`/`CAMERA` datablocks. `loadSceneAuthored` will still import color management, but there's nothing for it to bring in on the lighting/camera side. If you want real light contribution — especially relevant once `useRealWorldTint` is enabled for the light portal — add actual Blender light objects before exporting.

Export the result to `.untold` with the Blender add-on or CLI exporter, place it under the project's `GameData` folder, and update the filename passed to `setEntityMeshAsync` and `loadSceneAuthored`.

For example, if your exported model is `MyBedroom.untold`:

```swift
setEntityMeshAsync(entityId: room, filename: "MyBedroom", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    loadSceneAuthored(filename: "MyBedroom", withExtension: "untold")
    setSceneReady(true)
}
```

## Where To Go Next

- [Scene Channels And Passthrough Rendering](../Tutorials/SceneChannelsTutorial.md)
- [Light Portals](../Tutorials/LightPortalsTutorial.md)
- [Spatial Input And Manipulation](../Tutorials/SpatialInputTutorial.md)
- [XR App Basics](../Tutorials/XRTutorial.md)
- [Blender Add-On Workflow](../Tutorials/BlenderAddonTutorial.md)
- [Export Assets With The CLI](../Tutorials/CLIExporterTutorial.md)
