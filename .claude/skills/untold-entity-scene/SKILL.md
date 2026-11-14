---
name: untold-entity-scene
description: Use when adding or modifying scene content in an Untold Engine project — creating entities, loading/placing meshes, parenting, changing materials/colors, adding or tuning lights, or setting up/moving a camera. Triggers on requests like "add a cube to the scene", "make this object a child of that one", "change the material color", "add a point light", "set up a third-person camera". Not for engine-internal development, project scaffolding (see untold-new-project), or asset export (see untold-asset-pipeline).
version: 0.1.0
---

# Working with Entities and Scenes in Untold Engine

Untold Engine has **no entity class hierarchy**. Everything is a free function keyed by an `EntityID: Int64`. Never write `entity.setPosition(...)` or invent a method on a type — call the matching global function. If you're not sure a function exists, grep `Sources/UntoldEngine/Systems/` (especially `RegistrationSystem.swift`, `ScenegraphSystem.swift`, `CameraSystem.swift`, `LightingSystem.swift`) or the relevant `docs/API/*.md` file before using it. Treat `Sources/Demos/StarterDemo/GameScene.swift` as the canonical worked example — read it if anything below is ambiguous.

## 1. Clarify the ask

Most requests fall into one of these buckets. Identify which before writing code:

- New object in the scene (mesh, primitive, or loaded asset)
- Reparent / move / rotate an existing entity
- Change a material (color, roughness, metallic, texture)
- Add or tune a light
- Set up or drive a camera (fixed, orbit, follow, path)

## 2. Create and populate an entity

```swift
let entity = createEntity()                 // -> EntityID
setEntityName(entityId: entity, name: "Thing")
```

Attach geometry with exactly one of:

- `setEntityMesh(entityId:filename:withExtension:assetName:)` — sync load, `.untold` files only.
- `setEntityMeshAsync(entityId:filename:withExtension:assetName:completion:)` — async, other formats too; gate scene readiness in the completion handler.
- `setEntityMeshDirect(entityId:meshes:assetName:)` — in-memory geometry, e.g. `BasicPrimitives.createCube(extent:)` for a quick primitive.

Creating an entity auto-attaches transform + scenegraph components internally — do not attach those yourself.

When you are done setting up the initial scene state, call `setSceneReady(true)` (see `isSceneReady()` for the gate other systems check). To tear down: `destroyEntity(entityId:)`, or `destroyAllEntities(completion:)` for a full reset.

## 3. Transforms

```swift
translateTo(entityId:position:)       translateBy(entityId:delta:)
rotateTo(entityId:angle:axis:)        rotateTo(entityId:rotation:)
rotateBy(entityId:angle:axis:)
getPosition(entityId:) / getLocalPosition(entityId:)
getOrientation(entityId:) / getLocalOrientation(entityId:)
```

These are per-entity. Do **not** use them to move "the whole scene" — for that there's a separate scene-root-level API: `translateSceneTo/By`, `rotateSceneToYaw/ByYaw` (used by large streamed scenes, not typical per-object work).

## 4. Parenting (scene graph)

```swift
setParent(childId:parentId:offset:)   // simd_float3 offset defaults to .zero
removeParent(childId:)
getEntityChildren(parentId:) -> [EntityID]
getEntityParent(entityId:) -> EntityID?
```

Full reference: `docs/API/UsingScenegraph.md`.

## 5. Materials

`Material` (`Sources/UntoldEngine/Mesh/Mesh.swift`) has fixed PBR slots: `baseColor, roughness, metallic, normal, emissive, height`. Always go through the accessor functions — they refresh static batching, which direct field writes would skip:

```swift
updateMaterialColor(entityId:color:)        getMaterialBaseColor(entityId:meshIndex:submeshIndex:)
updateMaterialRoughness(entityId:...)       updateMaterialMetallic / Normal / Emissive / Height (...)
```

Full reference with every signature: `docs/API/UsingMaterials.md`.

## 6. Lighting

Exactly four light types — don't invent others:

```swift
createDirLight(...)    createPointLight(...)   createSpotLight(...)   createAreaLight(...)
```

Shared controls: `updateLightColor`/`getLightColor`, `updateLightIntensity`/`getLightIntensity`, `updateLightAttenuation`, `updateLightRadius`, `updateLightFalloff`. Spot lights add `getLightInnerCone`/`getLightOuterCone`. Shadow toggles are per-type: `updatePointLightCastsShadow`, `updateSpotLightCastsShadow`. Directional (sun) lights have `getSunElevationAzimuth`/`setSunElevationAzimuth`.

Light portals are a **separate** system for letting exterior light correctly reach interiors (`LightPortalSystem`, diagnostics via `getLightPortalRenderDiagnostics()`) — not a light type, don't reach for it unless the scene has an interior/exterior light-leak problem. Reference: `docs/API/UsingLightingSystem.md`, `docs/API/UsingLightPortals.md`.

## 7. Camera

```swift
createGameCamera(entityId:)        findGameCamera() -> EntityID
moveCameraTo(...) / moveCameraBy(...)
cameraMoveBy(entityId:delta:space:)
orbitAround(...) / orbitCameraAround(...) / setOrbitOffset(entityId:uTargetOffset:)
cameraLookAt(eye:target:up:)
cameraFollow(...) / cameraFollowLocal(...) / cameraFollowDeadZone(...) / cameraOrbitTarget(...)
startCameraPath(waypoints:mode:settings:) / updateCameraPath(...) / isCameraPathActive(...)
```

For input-driven camera movement, read `Sources/Demos/StarterDemo/GameScene.swift`'s `handleInput()` — it's the simplest working WASD + right-mouse-orbit example, driven off `InputSystem.shared.keyState` and `CameraSystem.shared.activeCamera`. Full reference: `docs/API/UsingCameraSystem.md`, `docs/API/UsingInputSystem.md`.

## 8. Verify

After making a change: `swift build` from the repo/project root. If you touched a demo in this engine repo, `swift run <DemoName>` to visually confirm (macOS only). Don't claim a scene change "works" without at least a successful build — ideally a run.
