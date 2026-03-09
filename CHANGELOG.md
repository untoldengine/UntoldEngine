# Changelog
## v0.10.15 - 2026-03-09
### 🐞 Fixes
- [Patch] Updated Build Template (934ede5…)
- [Patch] Added Spatial debugger improvements (fccf860…)
- [Patch] Implemented LOD Visualizer (431bf8c…)
- [Patch] Improved spatial picking control (12d3c1d…)
## v0.10.14 - 2026-03-06
### 🐞 Fixes
- [Patch] Real surface AR detection (86ef26a…)
### 📚 Docs
- [Docs] Updated logo in readme (eae2296…)
## v0.10.13 - 2026-03-05
### 🐞 Fixes
- [Patch] Added debug stats to engine (6e7c8df…)
- [Patch] Removed static batch warning when loading scene (83dba21…)
- [Patch] Fix destroy all entities function (5da30b2…)
- [Patch] Fixed octree update bounds when dirty (a8b29a4…)
- [Patch] Fixed octree update bounds when dirty corner cases (624b348…)
- [Patch] fixed loading crash with xr (a00ebbe…)
- [Patch] added component clean up (5e0c974…)
- [Patch] XR shutdown implementation (f1effe4…)
- [Patch] guarded scenes to avoid crashes (2f2714a…)
- [Patch] Added completion locks (74551bf…)
- [Patch] added function to remove usc scripts (31a9814…)
- [Patch] Fixed Geometry Streaming System crash (d810d4c…)
## v0.10.12 - 2026-03-03
### 🐞 Fixes
- [Patch] Ray picking ignores light entities when gameMode is true (e1e07c9…)
- [Patch] Directional-light nil safety in renderer - removed unsafe force unwrap path (eeec26e…)
## v0.10.11 - 2026-03-02
### 🐞 Fixes
- [Patch] Fixed transparency (56547cb…)
- [Patch] Post process shaders reserve alpha (2ca49c3…)
- [Patch] Incorrect premultiplied alpha compositing over a black (or undefined) background (9ce5a42…)
- [Patch] Fix issue with transparency and vision pro (9b86723…)
## v0.10.10 - 2026-03-01
### 🐞 Fixes
- [Patch] Added SceneRootTransform system and tests (be46bad…)
- [Patch] Implemented Octree-GPU ray picking (5b6e7c3…)
- [Patch] Add ground picking system and update spatial input docs (44b1886…)
## v0.10.9 - 2026-02-27
### 🐞 Fixes
- [Patch] Added occlusion culling (ccbd522…)
- [Patch] Fixed static batching texture bug (443be64…)
- [Patch] fixed ray-intersect compute (187a714…)
- [Patch] Fix XR drifting (7165fba…)
- [Patch] GPU ray picking (e61a1b9…)
- [Patch] Added option to keep child entity as non-static batch (d07810b…)
- [Patch] Fix Stereo ghosting (0cf4968…)
- [Patch] Fixed Ray Picking During Dragging (d5e41df…)
- [Patch] Implemented Octree-Based Ray Picking (9be0642…)
- [Patch] Optimized GPU Acceleration Structures (f4a03a0…)
- [Patch] Added Distance Tracking to Spatial Input State (4f2f43e…)
- [Patch] Added Anchored Pinch Drag Helper (f02d578…)
- [Patch] added function to set preferred ray intersection (9cee7ea…)
- [Patch] added option to ignore ray intersect with transparent objects (4725abc…)
## v0.10.7 - 2026-02-23
### 🐞 Fixes
- [Patch] fix transparency mesh pass (56e22a2…)
## v0.10.6 - 2026-02-21
### 🐞 Fixes
- [Patch] replace usdz files with procedural generated meshes (11c881d…)
- [Patch] Added scene picking system (d179cec…)
- [Patch] Gated static batch remove entity (56f9b51…)
- [Patch] Added spatial input for XR (b19e413…)
- [Patch] fix children transforms from usdz file (17f8449…)
- [Patch] Added vision spatial input support (6475991…)
- [Patch] Improved vision input system (cb07dd8…)
### 📚 Docs
- [Docs] added using spatial input documentation (6a14e46…)
## v0.10.5 - 2026-02-17
### 🐞 Fixes
- [Patch] address rendering init delay during large scenes (b1cea8f…)
- [Patch] added guards to vision xr code (52dec24…)
- [Patch] improve loading speed (689ce4a…)
- [Patch] Cleaned up demo game (28441fd…)
## v0.10.4 - 2026-02-14
### 🐞 Fixes
- [Patch] decouple internal color from drawable. Fixed render graph (0b28be7…)
## v0.10.3 - 2026-02-13
### 🐞 Fixes
- [Patch] Fixed async xr crash with large scenes (0783d1a…)
- [Patch] Fixed static batching texture scramble (f111115…)
- [Patch] Fixed usdz transform loading (83b4188…)
- [Patch] Fix light transform regression (cbe85e3…)
- [Patch] formated files (2eedb14…)
- [Patch] Removed unused logs (ad329f4…)
## v0.10.2 - 2026-02-12
### 🐞 Fixes
- [Patch] Increase default MAX_ENTITIES to 20000 (e1b2bc9…)
## v0.10.1 - 2026-02-11
### 🐞 Fixes
- [Patch] Fixed static batch material issues (ae1f0c3…)
## v0.10.0 - 2026-02-10
### 🐞 Fixes
- [Patch] Added Octree system (9fe2680…)
- [Patch] Implement Memory Budget Manager (e98dcda…)
- [Patch] implemented streaming region system (da25c60…)
- [Patch] Improved streaming region (70d681c…)
- [Patch]: Implement Geometry Streaming System (c650cb5…)
- [Patch] Fixed Geometry streaming with lod and batching (e5e155c…)
- [Patch] Updated octreetree when entities are destroyed (9f43778…)
- [patch] fixed issue with lod system dissapearing entity (61854bc…)
- [Patch] Added geometry streaming to serializer/deserializer (4794537…)
- [Patch] Fixed flickering issue (85e09dc…)
- [Patch] Updated playSceneAt with completion handler (33145dd…)
### 📚 Docs
- [Docs] Updated docs related to lod and static batching (d17a1f5…)
- [Docs] Added docs to geometry system (6f331e2…)
### 🚀 Features
- [Feature] Implemented Geometry streaming (36a94f8…)
## v0.10.0 - 2026-02-10
### 🐞 Fixes
- [Patch] Added Octree system (9fe2680…)
- [Patch] Implement Memory Budget Manager (e98dcda…)
- [Patch] implemented streaming region system (da25c60…)
- [Patch] Improved streaming region (70d681c…)
- [Patch]: Implement Geometry Streaming System (c650cb5…)
- [Patch] Fixed Geometry streaming with lod and batching (e5e155c…)
- [Patch] Updated octreetree when entities are destroyed (9f43778…)
- [patch] fixed issue with lod system dissapearing entity (61854bc…)
- [Patch] Added geometry streaming to serializer/deserializer (4794537…)
- [Patch] Fixed flickering issue (85e09dc…)
### 📚 Docs
- [Docs] Updated docs related to lod and static batching (d17a1f5…)
- [Docs] Added docs to geometry system (6f331e2…)
### 🚀 Features
- [Feature] Implemented Geometry streaming (36a94f8…)
## v0.9.0 - 2026-02-04
### 🚀 Features
- [Feature] Added LOD support (bdae196…)
- [Feature] Added static batching support (1930fa6…)
## v0.8.2 - 2026-02-01
### 🐞 Fixes
- [Patch] fixed crash when loading large number of models (c812695…)
- [Patch] Load absolute path models (ac06ff9…)
## v0.8.1 - 2026-01-26
### 🐞 Fixes
- [Patch]consolidated the camera transform api (9914211…)
- [Patch] Added helper util functions for postFX and SSAO (b19c2b2…)
- [Patch] Fix find entity name (fb579f9…)
- [Patch] Fixed the serialization of primitives (80f2ea7…)
## v0.8.0 - 2026-01-19
### 🐞 Fixes
- [Patch] Fixed demo game (d1db248…)
- [Patch] added flag to bypass post-procesing (edecb29…)
- [Patch] Updated the demo game to bypass post-fx (fcea465…)
- [Patch] Formatted game demo main (2afb46d…)
- [Patch] set animation playback speed (181b81e…)
- [Patch] added j and k keys to input system (c42ee76…)
- [Patch] Improve steering pursuit (b431051…)
- [Patch] Improve steering pursuit to have an offset (6ed6595…)
- [Patch] added a camera dead zone behavior (5c898e8…)
- [Patch] remove animation playback from sereializer (c51b7d2…)
- [Patch] fixed crash with loading scene with async (407ba24…)
- [Patch] added support for gamepad for more keys (c6882a6…)
### 📚 Docs
- [docs] added game controller input docs (3e63c82…)
### 🚀 Features
- [Feature] Added camera waypoint system (9cec140…)
## v0.7.1 - 2026-01-10
### 🐞 Fixes
- [Patch] Added a profiler to the engine (6be0955…)
- [Patch] added multi-platform support build system (d6642d1…)
- [Patch]fixed the space in the Build system path (31497f0…)
- [Patch]Added apply transform to parents in deserializer (907cde3…)
- [Patch]Fixed async loading not setting skeleton component (ea52f24…)
### 📚 Docs
- [Docs]Added docs explaining how to start a project (2496315…)
## v0.7.0 - 2026-01-06
### 🐞 Fixes
- [Patch] re-enabled renderer tests in pre-commit (fd67537…)
- [Patch] Enable build system to only update game data (f2706bb…)
- [Patch] Added overload create function (981cb0a…)
- [Patch] Modified the buil templates for mac os (4f03509…)
- [Patch] Added tests for build system macOS (4b0d1aa…)
- [Patch] added build templates for ios and ios ar (31ca404…)
- [Patch] Divided iosAR template into gamescene (27fa9f3…)
- [Patch] Commented xr-input temporarily (5ac456c…)
- [Patch] fix input XR errors (80061c7…)
- [Patch] Added a new pre-commit prefix (281f405…)
- [Patch] fixed texture issues with visionPro (b51d2b7…)
- [Patch] Fixed dispatch threads computations (b88cb85…)
- [Patch]Added semaphores to control work flow (0a2f748…)
- [Patch] Reuse render pass descriptors (bbf2f4a…)
- [Patch] pre-allocate arrays to avoid memory churn (7b4bb09…)
- [Patch] moved frustum calculation to the top of code flow (8f51845…)
- [Patch] Added an autoreleasepool to release memory (653b130…)
- [Patch] Optimized SSAO shaders (78c06b5…)
- [Patch] Fixed async loading issue with vision pro (362b544…)
- [Patch] Added version deployment for vision pro (177da19…)
- [Patch] Fixed issue with transform to getting properly serialized during async loading (84a1dd8…)
- [Patch] remove depth state from ssao execution (aed2e06…)
- [Patch] split the build template into game scene and view controller for macos-ios (1f51b4f…)
- [Patch] Updated docs with new workflow (0fe30e5…)
- [Patch] moved cli tool out of engine package (7f44798…)
### 📚 Docs
- [Docs] Added engine systems documentation (94451c2…)
- [Docs] Updated docs with new tutorials (b3673c8…)
- [Docs] Updated the docs (c05415e…)
- [Docs] Updated Readme (1a56657…)
### 🚀 Features
- [Feature] Made loading system async (0763b60…)
- [Feature] Added cli command to create project (2c75232…)
## v0.6.1 - 2025-12-17
### 🐞 Fixes
- [Patch] Fixed rotate scripting API (bb514cc…)
- [Patch] Added physics scripted API (17a7231…)
- [Patch] Added bool operations to scripting system (6148bc3…)
- [Patch] Removed the flip coord variable (d326d7e…)
- [Patch] Added Value type to physics scripted (d0fb63b…)
- [Patch] Added string comparison to if script (66bf0ed…)
- [Patch] Added scripting tutorials (9b73fdd…)
- [Patch] Added missing scripting else block (97ca22f…)
- [Patch] Added subFloat and divFloat to scripting (0c4449d…)
- [Patch] Added deltatime script property (0f89e34…)
- [Patch] Added basic primitives to the engine (6797657…)
- [Patch] Fixed retrieval of usdz embedded textures (81d4e20…)
- [Patch] Fixed parent-child relationship for usdz (472a46f…)
- [Patch] Fixed usdz loading matrices from blender (7219d70…)
- [Patch] fixed usd_blender coordinate system (b278eca…)
- [Patch] Fixed render component warning error for camera (16f7e8a…)
- [Patch] Added additional camera scripts (6e41cb0…)
- [Patch] Execute physics, anim and scripting only if game mode is true (e65cd68…)
- [Patch] Add physics scripting (2983590…)
- [Patch] Added angular physics functions (0ba066a…)
- [Patch] Fixed physics script API (8622315…)
- [Patch] Removed scripted actions (eeab897…)
- [Patch] Removed Vec3 data type for scripting (f9636e9…)
- [Patch] Added additional loggers parameters to script log (359b5cc…)
- [Patch] Improved if-conditionals in script (580aede…)
- [Patch] Improved math script usage (9657c82…)
- [Patch] Added useful function to math USC (faee8d1…)
- [Patch] Added lookAt function to the engine API and USC (9691af5…)
- [Patch] Added additional math operations to USC (5c0ad9b…)
- [Patch] Added additional USC steering behaviors (35826d1…)
- [Patch] Fixed USC alignment script (ecf5d3e…)
- [Patch] Fixed if conditional warning (2e5468c…)
- [Patch] Added guard to prevent processing of destroy-marked entities (168f03a…)
- [Patch] Made mask function public (7b51bcd…)
- [Patch] Fixed next-version script (9de12ca…)
### 📚 Docs
- [Docs] Update readme with new ecosystem (1227bed…)
- [Docs] Updated USC documentation (22bdf2e…)
- [Docs] Updated USC scripting docs (62f2979…)
- [Docs] USC API reviewed and updated (5127085…)
- [Docs] Added USC top api (84083bb…)
## v0.6.0 - 2025-11-29
### 🐞 Fixes
- [Patch] Set game scene callbacks (f72571d…)
- [Patch] Added input system extensions (b3d0f8c…)
- [Patch] Implemented Builder DSL (c57162f…)
- [Patch] Modified the DSL (7883912…)
- [Patch] Added onStart event (1f43692…)
- [Patch] Added DSL for input key (d8a3e38…)
- [Patch] Added basic math operations to DSL (3c0d931…)
- [Patch] Implemented DSL custom Actions (9bfd422…)
- [Patch] Added usc examples for reference (b0eaef8…)
- [Patch] Cleaning up dsl (2006b4e…)
- [Patch] added support for onStart to the scripting system (feaf6a8…)
- [Patch] Added steering funcs to script (b8250fc…)
- [Patch] Added scenes and scripts to loading system (81a6ff7…)
- [Patch] Implemented function to load scripts (41311a7…)
- [Patch] Made scripts codable so they can be serialized (f8a07e9…)
- [Patch] Added helper function to usc (fbdc7d1…)
- [Patch] Initialized systems in build templates (e015832…)
- [Patch] Improved scripting system. added tests (8ad8e82…)
- [Patch] formatted the engine (887747f…)
- [Patch] commented out wait and loop in the USC (d017b32…)
- [Patch] Added script api for camera and unit tests (0e47c7e…)
- [Patch] added clear function to log console (14c5396…)
### 📚 Docs
- [Docs] Updated docs with scripting instruction (e26a9f1…)
- [Docs] Add collision system not yet implemented message (ae545d5…)
### 🚀 Features
- [Feature] Implemented Untold Script Core (4c1b891…)
- [Feature] Initial implementation of building system (bc0335b…)
- [Feature] Supports multiple scripts (dcb9fbc…)
## v0.5.0 - 2025-11-18
## v0.5.0 - 2025-11-18
### 🐞 Fixes
- [Patch] Fix the play scene and load game function (686baf6…)
- [Patch] set the vision pro viewport size dynamically (9e5b3b7…)
- [Patch] using a centralized frustum culling function (c85d129…)
- [Patch] made performFrustumCulling public (81aea66…)
- [Patch] removed the assignedment to the post-processing color attachment (45bed7b…)
- [Patch] improved pre-composite pass and pre-composite shader (d8a3dc3…)
- [Patch] set the render pass descriptor properties depending on immersion mode (72313d7…)
- [Patch] fix the psnr threshold (4af7e88…)
- [Patch] Improved the gameModeRenderGraph (ddc0e6d…)
- [Patch] changed name to UntoldImmersionMode (39867d6…)
- [Patch] added safe guards when shaders are not found (bd06f97…)
- [Patch] Added safe guards to the culling system (c7c0e6a…)
- [Patch] Created intermediate texture for environment-grid pass (c023755…)
- [Patch] Fixed metal validation issues (3ef584b…)
- [Patch] Removed redundant composite shader (af3a2f6…)
- [Patch] set the correct depth format for env map (f6cd093…)
- [Patch] Fixed render descriptor for AR (d4cb812…)
- [Patch] Updated untold xr class name for consistency (068ae4e…)
- [Patch] Added public function to create an iOS and AR (c4036c4…)
- [Patch] blended 3D models and Gaussians into the render graph (25eb10b…)
### 🚀 Features
- [Feature] Added AR support (3cd059f…)
- [Feature] Added Gaussian support (45333df…)
## v0.4.0 - 2025-10-20
### 🐞 Fixes
- [Patch] fixed the projection convention. (9ce27e9…)
- [Patch] force the retina scale to be 1x (84dc30f…)
- [Patch] removed dispatch main queue from culling compute (aaa2cd2…)
### 🚀 Features
- [Feature] Added support for VisionOS. (tested on simulator only) (8059e54…)
## v0.3.2 - 2025-10-12
## v0.3.2 - 2025-10-12
### 🐞 Fixes
- [Patch]: Made the renderer Tests headless (43e9fdb…)
- [Patch] Saved reference imaged with linear sRGB profile (b63605a…)
## v0.3.1 - 2025-10-06
### 🐞 Fixes
- [Patch] fix removing node3D and adding convenience init method to the node to support empty scene builder content (bdc56ff5…)
- [Patch] fix remove init in Node3D to avoid the duplicate calls to register transform or scenegraph components (a17e3154…)
- [Patch] Fix removing coma in MeshNode function declaration (37573c1f…)
- [Patch] fix adding support to update a render pipeline in the pipeline manager (5e0be583…)
- [Patch] fix removing scene camera from culling tests (8e40d357…)
- [Patch] fix removing scene camera in the tests (60c378cc…)
- [Patch] fix replace in test inputSystem for InputSystem.shared (99856ee3…)
- [Patch] fix replacing get main camera function to findGameCamera as is the default one right now (1dd82230…)
- [Patch] Refactor: fix InputSystem issued and make it the demos work again (sort of) (8dd1ea51…)
- [Patch] Make entities spatial upon creation (105a9bed…)
- [Patch] Fixed directional light crash upon selection (378f0c22…)
- [Patch] Fixed Rendering test (01f156c9…)
### 📚 Docs
- [Docs] Added section for top contributors (85784ac…)
- [Docs] Fixed link to images for top contributors (5871c57…)
- [Docs] Fixed link to images folder for top contributors (9328745…)
- [Docs] Added quick reference guide (e3594db…)
- [Docs] Changed copyright on all files to untold engine (e474286…)
- [docs] add copilot instructions (4f5724c…)
- [Docs] Removed old contributing page (c29673b…)
- [Docs] Added code of conduct (de9d76c…)
- [Docs] Added swiftformat lint workflow with fix (f184d89…)
- [Docs] Improved game demo tutorial (c20ef7d…)
- [Docs] Added quick start section to untold arcade (53b4914…)
- [Docs] Updated readme with Untold Editor docs (9e73799…)
- [Docs] added images for the Untold Editor (e029f6b…)
- [Docs] fixed minor typo in readme (6e5dd65…)
## v0.3.0 - 2025-09-28
### 🐞 Fixes
- [Patch] Improved the build frustum and kernel to avoid false negatives (705f6f4…)
- [Patch] Padded the frustum to reduce whipping camera pops (6d33bba…)
- [Patch] set maxObjects to MAX_Entities (d75113f…)
- [Patch] Updated metallib kernel (6696002…)
- [Patch] updated optimized function to match recent changes (b17773d…)
- [Patch] Use reduce scan frustum culling (27772d5…)
- [Patch] fixed issue where camera was not responding when editor was disabled (f0194d1…)
- [Patch] Removed unused variables (d0f0551…)
- [Patch] fixed issue where shadows were not linked to animation (f2203ef…)
- [Patch] Separated kernels according to target (d6b0260…)
- [Patch] Set an abstraction to the input system (463c1ed…)
- [Patch] reverted metal shaders - pipeline will be ignored in game mode (8c70a8f…)
- [Patch] Wrapped the demo games in swift compilation code (2b23421…)
- [Patch] Updated the package to fix link issues. (1453ddf…)
- [Patch] Wrapped the editor in Swift compilation code. (651cc99…)
- [Patch] wrapped the logger in swift compilation code (169863c…)
- [Patch] On iOS game mode should be set to true automatically. (8a8fbcd…)
- [Patch] Wrapped handleSceneInput and Logger in Swift conditional (3ca7bc5…)
- [Patch] Wrapped systems in Swift conditionals (eaf84ec…)
- [PATCH] Removing the macro to compile only if is a macOS target. (384f982…)
- [PATCH] Move initRTXAccumulationBuffer to initSizeableResources to avoid creating the RTXAccumulationBuffer with size 0 (68dacdb…)
- [PATCH] Move metallibNotFound error from LoadError struct to the ErrorHandlingSystem (812b047…)
- [Patch] fixed projection calculation (3d791f4…)
- [Patch] Revert to original culling (6bfe4c5…)
- [Patch] Removed setting basepath from deserializer routine (edb3281…)
### 📚 Docs
- [Docs] Updated documentation (83dc195…)
- [Docs] Added Docusourus website (8b35185…)
- [Docs] Fixed docusaurus urls in config file (61c3fc3…)
- [Docs] fixed docs in contributor folder (02ef1e0…)
- [Docs] Updated game demo docs (3fc7e0c…)
- [Docs] Added documentation for custom components (fff8132…)
- [Docs] Added documentation for custom components (9bda27f…)
- [Docs]updated the readme pointing to new docs (b4f9479…)
### 🚀 Features
- [Feature] Reduce Scan Frustum culling (d8495c5…)
