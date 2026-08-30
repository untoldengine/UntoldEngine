# Changelog
## v0.18.0 - 2026-08-30
### 🐞 Fixes
- [Patch] Address review: octree ray query broad phase and real maxDistance cap (e8d0866…)
- [Patch] Address review: examine inside-origin candidates despite sort order (c5e6916…)
- [Patch] Fix octree raycast fallback dropping inside-origin hits under tight maxDistance (bb6ee36…)
- [Patch] Fixed duplicate export bug (71f5495…)
- [Patch] Fixed loading path (05c961c…)
- [Patch] Fixed the normal wrap mode (1764f29…)
- [Patch] Fix out-of-bound texture uv scale (ff5db1c…)
- [Patch] Fix TBN calculation (b15d04e…)
- [Patch] Fixed precision bug in exporter (8d9d731…)
- [Patch] Fixed batching system ignoring displacement material (d8fbefb…)
- [Patch] [Patch] Derive height remap ceiling from Blender's Displacement Midlevel (33a5ec2…)
### 📚 Docs
- [Docs] Fixed the docs for the Parallax Occlussion parameters (712c36c…)
- [Docs] Fix documentation url (be13964…)
### 🚀 Features
- [Feature] Add PhysicsQuery raycast facade with octree fallback (d4a7162…)
- [Feature] Add foot IK with analytic two-bone solver (32561b4…)
- [Feature] Add motion matching (20f5cee…)
- [Feature] Add height-map material channel with Parallax Occlusion Mapping (ab63759…)
- [Feature] Exporter support for height-map/POM materials (e8404e8…)
## v0.17.0 - 2026-08-24
### 🐞 Fixes
- [Patch] Fixed tile-streamer texture exporter (42c3fbf…)
- [Patch] Added lod debug for splats (0f57d0a…)
- [Patch] Implemented spatial bucketing for progressive Gaussian tier generation (b9f6373…)
- [Patch] Implemented new API for gaussian system (820424c…)
- [Patch] Progressive Gaussian loading is now tile-independent (fd9b2b8…)
- [Patch] Fix Gaussian LOD memory leak, stale-task race, and code-review findings (cee64e1…)
### 📚 Docs
- [Docs] Add tutorials for demos (cb0c6c0…)
- [Docs] Add more tutorials (a43537b…)
- [Docs] Add even more tutorials (d9158e3…)
- [Docs] added architecture docs (cfb9122…)
- [Docs] fix image url (09dd132…)
- [Docs] Added additional tutorials (e5e3b37…)
- [Docs] Updated url paths to demos (fca1fbd…)
- [Docs] Updated readme with gifs (85c6a1d…)
### 🚀 Features
- [Feature] Deliver physics backend events to subscribers and USC scripts (75917cf…)
- [Feature] Progressive loading for splats (f4d3148…)
- [Feature] Overdraw-aware Gaussian LOD selection (dc2ca60…)
## v0.16.0 - 2026-08-12
### 🐞 Fixes
- [Patch] fixed gaussian not rendering (74d821b…)
- [Patch] Reduce Gaussian splat fragment-shading overdraw (ed716ab…)
- [Patch] Cull negligible-opacity Gaussian splats at load time (6ca0713…)
- [Patch] Address review: clamp non-repeating channels, test pitch/roll (7d54789…)
- [Patch] Precompute Gaussian splat conic/color; cap blends per pixel (40fa5e3…)
- [Patch] Added triple buffer to gaussian system (9ce1713…)
- [Patch] HZB occlusion culling for Gaussian splats (0763066…)
- [Patch] Fixed standard export blender-addon (e5087e7…)
- [Patch] Updated blender-add on (a495546…)
### 📚 Docs
- [Docs] Updated getting started (78111d1…)
### 🚀 Features
- [Feature] Version-gate emissive trust so existing .untold assets don't need re-export (f7fe446…)
- [Feature] Add UntoldViewOptions for runtime view settings in SwiftUI (1720ba4…)
- [Feature] Add root motion extraction and application (dc21a5a…)
### 🧰 Maintenance
- [Refactor] Share per-mesh vertex-stream binding across render passes (a5b9844…)
## v0.15.0 - 2026-08-06
### 🐞 Fixes
- [Patch] Added material fidelity report to the exporter (a36166f…)
- [Patch] Added untoldengine export-tiles CLI command with RAM-aware parallel export (50221e3…)
- [Patch] Fix HDR IBL energy calibration (fcda745…)
- [Patch] Fix iOS simulator Metal kernel build output (2ccc688…)
- [Patch] fixed abs path in serializer (7f8dd45…)
- [Patch] Improve directional shadow softness for XR (ac5a1ff…)
- [Patch] Default quaternion rotations to identity instead of zero (06651fa…)
- [Patch] Improve Blender-style light units, attenuation, and shadow behavior (a08fded…)
- [Patch] Added debug views for hdr (95a9c6f…)
- [Patch] Stage world/studio-light HDR environments and transcode EXR to ZIP for engine compatibility (b782fd4…)
- [Patch] Re-encode all file-backed material textures through Blender instead of raw-copying (6332c8f…)
- [Patch] Stage world/studio-light HDR environments in export-tiles too (2e351f2…)
- [Patch] Fixed bake resolution (ee582e4…)
- [Patch] Added new variable to setRendering (990520d…)
- [Patch] Fix joint transforms buffer CPU/GPU race with per-frame ring (f07c0fd…)
- [Patch] Restore encoder safety net with a closed flag (e8f9607…)
- [Patch] Persist scene-authored color management and environment state (8980058…)
- [Patch] Aggregate getAnimationPolicy over descendants (bee8546…)
- [Patch] Fix MPS -destination must be writable- crash on sRGB texture resample (7924e4a…)
- [Patch] Create the camera component in CameraNode when missing (aeefa4c…)
- [Patch] Address review: redundant changeAnimation is a no-op (5f61789…)
### 📚 Docs
- [Docs] Reorder topics in docs (30cf39e…)
- [Docs] Updated usage example (5c1bc45…)
- [Docs] Updated engine documentation (f9a88b0…)
- [Docs] Documented bake-materials and bake-color-management (a2696cf…)
- [Docs] Updated IBL usage documentation (845039d…)
- [Docs] Update the readme docs (96d0340…)
- [Docs] Updated xr images (6ac8f82…)
- [Docs] Added scene authored documentation (f9f0ea9…)
- [Docs] add plugin architecture and authoring guidelines (e363a83…)
- [Docs] Added community links (140edc0…)
### 🚀 Features
- [Feature] Add compiled animation clip sampling and pose layer foundation (8e3892b…)
- [Feature] Add per-frame update event with UntoldView onUpdate modifier (6c3dd20…)
- [Feature] Add simulator fallback for the TBDR deferred renderer (d78c8c1…)
- [Feature] Add per-entity animation policy (inherit/forceOn/forceOff) (24e9ad8…)
- [Feature] Add primitive, light, and camera nodes to the scene builder DSL (3b8bc92…)
- [Feature] Add physics backend plugin interface (260b23f…)
- [Feature] Add inertialized animation transitions to changeAnimation (08be3a6…)
- [Feature] Drive external physics backends via an EngineExtension coordinator (c3b8b0e…)
- [Feature] Mesh and Gaussian share streaming path (0e088a9…)
## v0.14.3 - 2026-07-17
### 🐞 Fixes
- [Patch] Added the new public debug view - position (3dccbad…)
### 📚 Docs
- [Docs] Updated the docs (7ba1598…)
## v0.14.2 - 2026-07-16
### 🐞 Fixes
- [Patch] Implemented soft CSM-shadows (a47d9b8…)
- [Patch] fixed env rendering in full immersion mode (5cc6571…)
- [Patch] Smooth XR light portal transitions (5107fc0…)
- [Patch] Expose GPU mesh pick surface normals for XR (134e7b2…)
## v0.14.1 - 2026-07-12
### 🐞 Fixes
- [Patch] Add global asset export and texture baking commands (137c102…)
- [Patch] Remove the luminance fallback from the opaque model shader (63a2147…)
- [Patch] Export script now accepts blend file (9227a1b…)
- [Patch] Added a optimize flag to export script (55a2627…)
- [Patch] added bootstrap command to script (beec2ee…)
- [Patch] Added bootstrap script (0c65ee1…)
- [Patch]Added script to update blender addon (8cb1ea4…)
- [Patch] Added blender error message (699e804…)
- [Patch] Fixed Gaussian splats color (6ecd93b…)
- [Patch] Added gaussian profiling (779a033…)
- [Patch] Added xr surface normal detection (7f3d133…)
### 📚 Docs
- [Docs] Added documentation for the script (5c8a69f…)
## v0.14.0 - 2026-07-01
### 🐞 Fixes
- [Patch] Implemented rendering extensions v1 (84465de…)
- [Patch] Implemented argument buffers for rendering extensions (884bf2c…)
- [Patch] Complete rendering extension graph and plugin architecture (1dafc3b…)
- [Patch] Updated the create project cli (45fa19b…)
- [Patch] Added helper functions to input system (3001cb2…)
- [Patch] Fixed ios input system (cd0acce…)
- [Patch] Fixed Rendering Extensions (2f0531c…)
- [Patch] Fixed PSVR2 API (7772952…)
- [Patch] Modified the CLI create command (86a6a3b…)
### 📚 Docs
- [Docs] Updated architecture documentation (7699900…)
- [Docs] Cleaning up the docs (9fdddb0…)
### 🚀 Features
- [Feature] Added psvr2 support (69d927e…)
## v0.13.3 - 2026-06-25
### 🐞 Fixes
- [Patch] Add vision light probes (b2d1ff9…)
- [Patch] Added xr light probe contribution factor (708c22d…)
- [Patch] Add virtual light (c1cf311…)
- [Patch] Updated Engine API v2 (d9c6e57…)
- [Patch] processAnchoredPinchDragLifecycle now supports dragPlane (be493f2…)
- [Patch] Implemented the recursive material opacicty fix (adea187…)
- [Patch] Added support for drag-snapping (f4f4647…)
- [Patch] Route XR lighting through rendering settings (9bfe031…)
- [Patch] Serialize XR ARKit provider runs (7b5f115…)
- [Patch] Added light portal diagnostics (c0176bc…)
- [Patch] Harden recursive material updates and clarify drag constraints (76d4ecc…)
- [Patch] Fixed animations linkage with multiple meshes (cf4ce4a…)
- [Patch] Added support for additional input keys (cc8cf09…)
## v0.13.2 - 2026-06-18
### 🐞 Fixes
- [Patch] Added tile preview overlay for blender (4a31132…)
- [Patch] Add Blender tiled-scene metadata and LOD preview tools (2c1878a…)
- [Patch] Fix lod/hlod distances (1a77470…)
- [Patch] Improved lod overlay for uniform grid (e56c488…)
- [Patch] Fix LOD/HLOD gen for spanning tiles and add force_local override (0d3d544…)
- [Patch] Use manifest cell_bounds for tile debug overlay (31a9340…)
- [Patch] Updated the default values in the overlay (5097b7f…)
- [Patch] Tile Floor Fill visibility toggle (9092aea…)
- [Patch] Added progress bar to tile exporter (278b3f8…)
- [Patch] Improve tiled LOD0 handoff diagnostics and fallback coverage (02ff6da…)
- [Patch] Fix tiled LOD fallback retention during visibility handoff (8469998…)
- [Patch] Add tile streaming log category coverage (0dc402b…)
- [Patch] Added Lod cross fade dithering (47d392f…)
- [Patch] Fixed popping after cross fade implementation (d3361da…)
- [Patch] Update Engine API documentation and settings (22a5980…)
- [Patch] Updated additional APIs (9b956e0…)
- [Patch] Improved API (83d5a60…)
- [Patch] Engine HLOD replacement fix + test (58ae514…)
- [Patch] Add tile representation render diagnostics (9d5e793…)
- [Patch]Collapse underfilled quadtree tile-tier groups (5ca53d7…)
- [Patch] Fixed area light math (3b78333…)
- [Patch] Clamped spotlight parameters (dcd6d08…)
- [Patch] Clamped point lights parameters (e5cb8f0…)
- [Patch] Fixed cascade shadows (2447cb5…)
- [Patch] Import-export light from Blender (f2f8f81…)
- [Patch] New API for directional light (e51928f…)
- [Patch] Color correction fix (aee1c1a…)
- [Patch] Fixed issue with dir light not getting set (f6a97ec…)
- [Patch] Added scene author lights and camera to tiles (251c3b7…)
- [Patch] make runtime camera lookup deterministic when multiple CameraComponents exist (4d65ba3…)
- [Patch] Include lights and cameras in Blender add-on exports (17ddc04…)
- [Patch] added function to load authored scene (57858f9…)
- [Patch] Fixed area light import math (a557094…)
- [Patch] Fixed area light direction (2f10a3d…)
- [Patch] Fixed roughness and metallic export (86032bb…)
- [Patch] Add user custom scene channels and prefix mapping (bfc57e0…)
### 📚 Docs
- [Docs] Updated add-on script documentation (fa46413…)
- [Docs] Updated docs with example (b4db01e…)
- [Docs] Updated documentation (5ada000…)
## v0.13.1 - 2026-06-10
### 🐞 Fixes
- [Patch] Implemented MSAA (ec63a6c…)
- [Patch] Fixed no entity found error messages (c07c3bc…)
- [Patch] Fixed streaming swap warning messages (60676fe…)
- [Patch] Implemented splats TBDR (ecec3b9…)
- [Patch] Removed legacy gaussian splat architecture (29c74b7…)
- [Patch] Added pick participation channel (5ca25d5…)
## v0.13.0 - 2026-06-02
### 🐞 Fixes
- [Patch] Derive batch cell size from actual tile extents in quadtree/KD-tree manifests (86c00bf…)
- [Patch] Fix shadows for non-streaming models (777f203…)
- [Patch] Implemented depth-only SSAO (531b573…)
- [Patch] Updated tests for TBDR (9958ca2…)
- [Patch] Add ghost mode channel (f73c5df…)
- [Patch] plane detection for XR (1411624…)
- [Patch] fixed render debug targets (4ea1251…)
### 📚 Docs
- [Docs] Updated documentation (c382a09…)
### 🚀 Features
- [Feature] Implemented TBDR into the engine. (ad52436…)
## v0.12.18 - 2026-06-01
### 🐞 Fixes
- [Patch] Added occlusion debug viewer (36160da…)
- [Patch] Hierarchy-aware tile culling (5a47bb2…)
- [Patch] Added ancestor walk to hierarchy occlusion (49fd65b…)
- [Patch] Use a closest-point to parent AABB (43a84b6…)
- [Patch] Implemented kd-tree partitioning (06fcc75…)
- [Patch] Improved per-cascade shadow distance (0645690…)
- [Patch] [Patch] Fix hierarchy culling ID format and replace hard-skip with penalty (dcd21ba…)
### 📚 Docs
- [Docs] Updated the docs (07c55ed…)
## v0.12.17 - 2026-05-30
### 🐞 Fixes
- [Patch] Fixed stream profiler (abd8e4b…)
- [Patch] Fixe active count in profiler (bd52558…)
- [Patch] Spread tile stub registration across frames to eliminate stall (9ff304f…)
- [Patch] Skip transform recomp for static entities using a dirty flag (6bb82f4…)
- [Patch] Skip traverseSceneGraph entirely when no transforms are dirty (a5b4d5b…)
- [Patch] Updated scene channel funcion api (0b2abbf…)
### 📚 Docs
- [Docs] Update profiler documentation (087575c…)
## v0.12.16 - 2026-05-29
### 🐞 Fixes
- [Patch] Fix tile streaming fallback coverage for LOD/HLOD scenes (275ee1d…)
- [Patch] Added dedicated log categories (1cc3ffb…)
- [Patch] Fix shadow caster selection (5c0abad…)
- [Patch] Added a static batching logger (e141c63…)
- [Patch] Improve XR static batching performance and diagnostics (7dde7e0…)
- [Patch] Implemented wireframe render mode (5094934…)
- [Patch] Apply platform-appropriate batching tuning preset automatically at engine init (04b3b49…)
## v0.12.15 - 2026-05-26
### 🐞 Fixes
- [Patch] Add scene channels for selectable and context geometry visibility (2c9217d…)
### 📚 Docs
- [Docs] Updated documentation (cbade44…)
## v0.12.14 - 2026-05-22
### 🐞 Fixes
- [Patch] Fix transparency bug (6a51e40…)
- [Patch] Exposed mesh properties as public (f9dc13e…)
- [Patch] LOD Throttle Fix (b9d35ba…)
- [Patch] Add camera-distance culling for shadow casters (80ea02c…)
- [Patch] Move Metal buffer creation outside world mutation gate in loadMeshAsync (da82f34…)
- [Patch] Skip redundant batch removal and dirty for unbatched LOD entities (b133eea…)
- [Patch] initial plugin export (ea700d3…)
- [Patch] Added animation blender pluging (20d1b15…)
- [Patch] Texture compression in add-on plugin enabled (0b080b9…)
- [Patch] Added tile scene export to plugin (ecc13f2…)
### 📚 Docs
- [Docs] Added blender plugin documenation (828c932…)
## v0.12.13 - 2026-05-21
### 🐞 Fixes
- [Patch] Added AA parameters to serializer (3d81b55…)
- [Patch] Set ambient default value to 0.4 (c5a72a2…)
- [Patch] Use recursive traversal for derived asset node ids in serialization (41acc07…)
- [Patch] Route native OCC stubs through child entities (e1b2935…)
- [Patch] Reimplented setEntityMesh (6250f0a…)
- [Patch] Added radii to structured content to stream system (5392935…)
- [Patch] Stabilize tiled streaming world mutations (e3436fd…)
- [Patch] Guard floor-proximity gate on interior tiles only (ec4a36c…)
- [Patch] Enforce minimum residency for parsed tiles before unload or eviction (224d528…)
- [Patch] [Feature] Replace radius/distance importance with tile view importance (291a626…)
- [Patch] Add screen-space AABB occlusion factor to tile importance sort (96f1b39…)
- [Patch] Spread tile parse-completion batching work across frames (c5f3c50…)
- [Patch] Skip near-plane-clipping tiles as occluders in screen-space occlusion sort (751398b…)
- [Patch] Disable occlusion sort when no active camera is available (c378cb1…)
- [Patch] Replace additive occlusion coverage with 8×8 grid union bitmask (9d3bfac…)
- [Patch] Use closest AABB point for view alignment instead of tile center (d72106a…)
- [Patch] Floor occlusionScore at occlusionMinWeight to prevent hard load suppression (abd3dbd…)
- [Patch] Harden tile-resident drain queue in BatchingSystem (2b5713c…)
- [Patch] Guard rectToScreenMask against zero-area rects (ecc8d46…)
- [Patch] Route tile-resident drain entities through quiescence to prevent repeated cell rebuilds (aec4112…)
### 📚 Docs
- [Docs] Updated streaming docs (ed14520…)
## v0.12.12 - 2026-05-18
### 🐞 Fixes
- [Patch] Replace FXAA toggle with anti-aliasing mode selector (0111454…)
- [Patch] Added a FXAA debug texture view (00dd9f5…)
- [Patch] Added MSAA anti-aliasing - WIP (50d4733…)
- [Patch] Improve SMAA diagonal and corner handling (552884b…)
- [Patch] Exposed setSceneScale API (37fed13…)
- [Patch] Refresh scene-root transform in rendering loop (cc87a41…)
- [Patch] added function to force unload all parsed tiles (43e27fa…)
- [Patch] Fixed horizontal plane detection (5e2c088…)
### 📚 Docs
- [Docs] Updated streaming system docs (cbc9648…)
- [Docs] Updated rendering docs (a521557…)
- [Docs] Updated exported documentation (ccc4dc4…)
## v0.12.11 - 2026-05-13
### 🐞 Fixes
- [Patch] Fix SSAO floating in XR (9a0fba5…)
- [Patch] Fix DoF depth linearization for reverse-Z (Vision Pro) (79512a3…)
- [Patch] Bloom threshold samples full HDR scene, not emissive-only (0652749…)
- [Patch] Fix DoF bokeh aspect ratio — radius now in pixel space (ebd36b0…)
- [Patch] Replace DoF ring sampling with Vogel disc pattern (16 samples) (947fe23…)
- [Patch] Fix chromatic aberration aspect ratio and redundant samples (e9f35bb…)
- [Patch] Fix vignette shape — circular not elliptical on wide screens (1559ede…)
- [Patch] Wider bloom blur — 9-tap Gaussian kernel, 4 passes, radius 6 (6af62db…)
- [Patch] Eliminate redundant texture sample in LookShader (9ca27f0…)
- [Patch] SSAO bilateral blur: linearize depth and thread reverseZ flag (d211b62…)
- [Patch] Rename BloomCompositeShader textures to match their actual slots (8ec208f…)
- [Patch] Fix ColorCorrectionShader parameter mismatch (d72a8db…)
- [Patch] Remove dead commented-out code block from LookShader (39926ac…)
- [Patch] Update RenderGraphBuilderTest for removed geometryPassId param (8e11d5c…)
- [Patch] Fix SSAO intensity and retune preset values (84ddb59…)
- [Patch] Add progress/percentage to exporter cli (e6741a8…)
- [Patch] Fixed demo camera orbit (ea2c571…)
- [Patch] Fix occlusion for transparency meshes in xr (ce811e0…)
- [Patch] Added cache to the native texture loader (f4470d5…)
- [Patch] Implemented cascade shadow mapping (4856e59…)
- [Patch] Updated the build templates (6c49df0…)
- [Patch] Implemented Temporal Anti-Aliasing (dd3abd3…)
- [Patch] Moved loadUntoldScene from build templates (403320f…)
- [Patch] Added a factor to the tile gen script to use area as input (884e051…)
- [Patch] Fix XR mixed-mode HZB culling behind transparent surfaces (8c63977…)
- [Patch] Fix HZB false culling near transparent surfaces (0c0b0df…)
- [Patch] Generate mip map for untold files (3dda8bc…)
- [Patch] Fix z-figthing issues (b3b6535…)
- [Patch] fixed reversed z for depth debug (848800d…)
- [Patch] Fixed grid after doing reversed-z (225b9c1…)
- [Patch] Preserve original mesh names add selective merge via NM_ prefix (361a299…)
### 📚 Docs
- [Docs] Updated static batching docs (4471b07…)
- [Docs] Updated readme (476056e…)
- [Docs] Updated licenses (9dc3f6d…)
- [Docs] Updated documents (136d8a1…)
- [Docs] Updated readme (434274c…)
- [Docs] Moved documentation to use mkdocs (811d032…)
- [Docs] point to stable release (89c56b7…)
- [Docs] Added load scene docs (cd0a8eb…)
- [Docs] Update spatial docs (9885d85…)
## v0.12.10 - 2026-04-29
### 🐞 Fixes
- [Patch] Made fxaa pass public (736ec7b…)
## v0.12.9 - 2026-04-29
### 🐞 Fixes
- [Patch] Add pre-upload tile size/budget diagnostic,  device mem profile (81b78dc…)
- [Patch] Dump memory budget snapshot on OS memory pressure warning (55995c3…)
- [Patch] implemented FXAA (39d81f8…)
- [Patch] Improved FXAA (ef04700…)
## v0.12.8 - 2026-04-28
### 🐞 Fixes
- [Patch] Fix FrameMetricsCollector data race; expand signpost coverage (e59e1b1…)
- [Patch] Add screen-space importance sort to GeometryStreamingSystem (b543024…)
- [Patch] Guard LOD array bounds & component registration tile LOD loading (4622256…)
- [Patch] Eliminate race window on pendingPressureRelief throttle bypass (3ff04dc…)
- [Patch] Initialize TextureStreamingSystem Metal resources at startup (7db5b7f…)
- [Patch] Distinguish cold rehydration failure modes with separate err msg (0b00ce2…)
- [Patch] Guard TileLODTagComponent registration in H/LOD load completion (6ef2523…)
- [Patch] Route streaming error logs through ErrorHandlingSystem. (91aa8ad…)
- [Patch] Route all Logger.logError calls through ErrorHandlingSystem (a1e428f…)
### 📚 Docs
- [Docs] Updated read me with editor links (37d3b01…)
- [Docs] Added new xr video to readme (ac49e2f…)
- [Docs] Updated architecture and API docs (4e35fe6…)
## v0.12.7 - 2026-04-25
### 🐞 Fixes
- [Patch] Improved ECS query (7d79114…)
- [Patch] Fixed per mesh uniform buffer (31bdcf3…)
- [Patch] Enabled optimized frustum (ce44b86…)
- [Patch] Fix fps profiler (7a46cce…)
- [Patch] Added load scene func in Build System (fee5a6a…)
- [Patch] Added Post FX helper functions (fc00d10…)
- [Patch] Fix transform for armature in exporter (b5051aa…)
- [Patch] Added function to get asset url (7ef9e4f…)
### 📚 Docs
- [Docs] Added documentation for the Logger system (45be832…)
## v0.12.6 - 2026-04-23
## v0.12.4 - 2026-04-23
### 🐞 Fixes
- [Patch] Updated build templates to use recent api for streaming (7221b11…)
- [Patch] Added additional profiles to TextureStreamingSystem (58a4b07…)
- [Patch] Multi-node scene no longer hijacks caller entityId (b9f5f5b…)
- [Patch] Updated the build system template (c744685…)
- [Patch] Fixed serializer to use new asset format (6041fbd…)
- [Patch] fixed project cli script (97ee35d…)
- [Patch] Fix project script create (b58690b…)
### 📚 Docs
- [Docs] Updated docs API and Architecture (b2295fe…)
- [Docs] Updated exporter docs to include new flags (47b6aa8…)
## v0.12.3 - 2026-04-21
### 🐞 Fixes
- [Patch] added entity to loadTileScene (ef8ecb3…)
- [Patch] Renamed loadTileScene as setEntityStreamScene (c88cbe3…)
## v0.12.2 - 2026-04-18
### 🐞 Fixes
- [Patch] Fix path traversal in remote texture disk cache (e4773fb…)
- [Patch] Enforce HTTPS for remote manifest and tile downloads (091560e…)
- [Patch] Fixed animation to use new asset format (47d14c8…)
- [Patch] Fixed unconditional bisect partition (1e5ca18…)
- [Patch] Fixed mip-map selection for small models (b094b45…)
- [Patch] Added options to partition and export fractions of a scene (9d69282…)
- [Patch] Fixed frustum culling count report for XR (9052ddd…)
- [Patch] Fixed HZB occlusion in XR (736e7f7…)
- [Patch] Implemented quad-tree parsing (eeacd87…)
- [Patch] Modified code to annotate quadtree tag (eb932d9…)
- [Patch] Added floor count to quad tree partitioning (76df3fc…)
- [Patch] Improved quad tree performance (2cda410…)
- [Patch] Tile-local mesh batching. Tighten interior tier streaming radii (13a39e7…)
- [Patch] Add interior/exterior separation for quadtree tile streaming (13ff027…)
- [Patch] Wire HLOD/LOD generation into the quadtree export path (e0ccd0b…)
- [Patch] Extend name hints & fix interior_zone for spanning ExteriorShell (e6a5122…)
## v0.12.1 - 2026-04-09
### 🐞 Fixes
- [Patch] Fixed exporter UV issues (4e5da7f…)
- [Patch] Fixed texture encoding in exporter (5313ee7…)
- [Patch] Improved the exporting speed. (7f14373…)
- [Patch] Fixed grayscale textures rendering red in engine (a0c0f00…)
- [Patch] Fixed 16-bit sRGB textures saving with wrong view transform (fe33c36…)
- [Patch] Ignore exr textures during export (e9981ac…)
- [Patch] Implemented LZ4 compression (7095b8d…)
- [Patch] Added ASTC texture pipeline to engine. (6cd4dda…)
### 📚 Docs
- [Docs] Updated logo image (d4a5faf…)
- [Docs] Added LZ4 documentation (bf231ab…)
## v0.12.0 - 2026-04-06
### 🐞 Fixes
- [Patch] improved the tile-streaming system (c09bb2c…)
- [Patch] Cluster-level frustum culling and tile-local batch promotion (5495691…)
- [Patch] Add HZB occlusion culling for batch groups (9df345f…)
- [Patch] Implemented HLOD support (937647b…)
- [Patch] Resolve render-loop freeze from hung ModelIO loadTextures() call (232b3c2…)
- [Patch] Implemented per tile LOD (c61e4de…)
- [Patch] Force-release AssetLoadingGate when HLOD/LOD entity is torn down (4abd9a8…)
- [Patch] Cap concurrent LOD loads and prevent render stall on LOD assets (3c9db7d…)
- [Patch] Added hysteresis to LOD system (0b8079a…)
- [Patch] Updated and documented tile based streaming (db7fa2c…)
- [Patch] Stabilize tile streaming transitions and harden geometry streaming progress (644926b…)
- [Patch] Integrated texture streaming into tile streaming (68b1cab…)
- [Patch] Unified load scenes path (c68d8af…)
- [Patch] Implementing initial untold format for asset loading (d8acae5…)
- [Patch] Implemented initial parent-hierarchy import (6f82c19…)
- [Patch] Added tests to engine-asset-format (315b8f5…)
- [Patch] Added scripts to export from usdz to untold (95a1497…)
- [Patch] Fixed exporter script (08516f9…)
- [Patch] Updated tests for engine format hierarchy (103a221…)
- [Patch] Fix double file read and consolidate .untold load paths (ce5dfd2…)
- [Patch] Implement contentHash validation in UntoldReader (3923b9e…)
- [Patch] Renamed files to reflect native format changes (781ad22…)
- [Patch] Implemented native format in the engine (732869e…)
### 📚 Docs
- [Docs] Updated docs related to streaming (ced07ab…)
### 🚀 Features
- [Feature] Implement v1 remote asset streaming over HTTP (799b803…)
## v0.11.4 - 2026-03-26
### 🐞 Fixes
- [Patch] Modify build system with new functions (2ef3bf6…)
- [Patch] Fixed concurrency swift 6 issue (f431f47…)
- [Patch] Added guard to avoid creation of zero dim texture (972c139…)
- [Patch] Consolidate loadScene as the primary scene entry point (8befb7b…)
- [Patch] fixed xr ooc crash issues with large models. (a3e42a3…)
- [Patch]Added xrCamera logging message (832c72f…)
### 📚 Docs
- [Docs] Updated documents (446dcd9…)
- [Docs] Updated readme (291c8f6…)
- [Docs] added link to showcase (5791988…)
## v0.11.3 - 2026-03-24
### 🐞 Fixes
- [Patch] Request world sensing authorization before starting ARKit session (31eac96…)
- [Patch] fix camera orbit function (0099534…)
- [Patch] Fixed issues with texture streaming and batch system (ff3856b…)
- [Patch] Added stream texture debugger (1a0638e…)
- [Patch] Implemented progressive asset loader (123f5ac…)
- [Patch] Modified the min and max for texture streaming (a36344e…)
- [Patch] Fixed issue with progressive loading in XR (45ba06c…)
- [Patch] First implementation of out-of-core (2e5e01e…)
- [Patch] Improve out-of-core loading and eviction logic (0f0ebd3…)
- [Patch] Improved performance of OOC (3496d13…)
- [Patch]Stabilize asset streaming (bcb4c73…)
- [Patch]Release MDLAsset CPU residency, add disk-backed cold re-streaming (07455b7…)
- [Patch] Refine admission gate: add soft zone and fallback mesh on reject (9517e64…)
- [Patch] Fix wrong initial textures by correcting TextureLoader cache key (db87e46…)
- [Patch] Fix wrong batch textures by using object-identity. (65abf1d…)
- [Patch] Complete three-tier texture streaming and add scene profiles (b8d7b66…)
- [Patch] fixed lod system to work with OOC (180b650…)
- [Patch] Formatted files (43a7f59…)
- [Patch] Improved OOC performance (41c96df…)
- [Patch] Added profiling documentation (58961cf…)
- [Patch] Fixed Out-of-Core texture crash (0c3e5cf…)
- [Patch] Added g-buffer debugger (12b60d2…)
- [Patch] Fixed camera position for OOC system for XR (828cac7…)
- [Patch] Fixed memory budget manager for XR (fdf9d61…)
- [Patch] Fixed closest point used for OOC (659c795…)
### 📚 Docs
- [Docs] Added system architecture docs (e52dc7a…)
- [Docs] Update progressive asset loading docs (85428b7…)
- [Docs] Updated documentation (5ef25bb…)
- [Docs] Updated Out of core docs (e225123…)
## v0.11.2 - 2026-03-18
### 🐞 Fixes
- [Patch] fixed texture streaming (f676f75…)
## v0.11.1 - 2026-03-17
### 🐞 Fixes
- [Patch] initial cell-based static batch system (7574378…)
- [Patch] Cell-based static batch visualizer (2159ff1…)
- [Patch] Implemented cell based static batching (6fee69a…)
- [Patch] Fixed end submission warning visionpro (575d382…)
- [Patch] Reduced render target memory (4cc7e42…)
- [Patch] Implemented mip-map texture streamming (9e77006…)
- [Patch] set lower resolution mip-map for visionpro (dfeb928…)
- [Patch] Fix aabb-world calcuation (12f51f4…)
- [Patch] Improved occlusion testing (b342cba…)
- [Patch] Improved HZB for elongated meshes. (7fb1915…)
- [Patch] Fixed segment-level occlusion popping (d3b8980…)
## v0.11.0 - 2026-03-13
### 🐞 Fixes
- [Patch] Fix easy Sendable/static-value issues (4b3e497…)
- [Patch] Initial migration to swift 6.0 (8f1e6e9…)
- [Patch] Phase 2 for migration to swift 6.0 (e32e826…)
- [Patch] Phase 3 for migration to swift 6.0 (344cae3…)
### 📚 Docs
- [docs] Updated readme (3ea1d09…)
### 🚀 Features
- [Feature] Migrated engine to swift 6.0 (d7c6fb9…)
## v0.10.17 - 2026-03-11
### 🐞 Fixes
- [Patch] Added support to load lods from usd file (2410d67…)
- [Patch] Added rotate functions to scene root transform (47c2518…)
- [Patch] use anchorFromExtentTransform for accurate plane bounds check (3ef400f…)
- [Patch] Expose picked entity world hit position (90a3d26…)
## v0.10.16 - 2026-03-10
### 🐞 Fixes
- [Patch] Added two-hands spatial rotate (d46bbea…)
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
