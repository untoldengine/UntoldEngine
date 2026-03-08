# Spatial Debugger (Octree Bounds)

Use Spatial Debugger to visualize octree bounds as wire boxes for spatial debugging.

Current scope:
- Octree leaf bounds visualization.
- Runtime toggles for enable/disable, cap, and occupied-only filtering.
- Optional residency/culling-based leaf coloring.
- Console status line for quick verification.

## Quick Start

```swift
import UntoldEngine

// Optional: tighten world bounds to your scene for better visibility.
OctreeSystem.shared.worldBounds = AABB(
    min: simd_float3(-40, -5, -40),
    max: simd_float3(40, 25, 40)
)

// Enable octree debug rendering.
// maxLeafNodeCount: 0 = unlimited
// occupiedOnly: true = leaves containing entries only
// colorMode: .plain | .residency | .culling
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .culling
)
```

Disable:

```swift
disableSpatialDebugVisualization()
```

## Phase 3 Usage (Color Modes)

Baseline leaf bounds (single white color):

```swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .plain
)
```

Leaf bounds colored by streaming/LOD residency:

```swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .residency
)
```

Leaf bounds colored by culling/visibility state:

```swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .culling
)
```

Show all leaves (including empty leaves) with residency colors:

```swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: false,
    colorMode: .residency
)
```

## API

`setOctreeLeafBoundsDebug(enabled:maxLeafNodeCount:occupiedOnly:colorMode:)`
- `enabled`: master toggle for octree leaf bounds drawing.
- `maxLeafNodeCount`: maximum leaves drawn each frame (`0` means no cap).
- `occupiedOnly`: when `true`, draw only occupied leaves. When `false`, draw all leaves.
- `colorMode`:
  - `.plain`: white wireframe
  - `.residency`: color by residency states from `StreamingComponent`/`LODComponent`
  - `.culling`: color by runtime visibility/culling state

`disableSpatialDebugVisualization()`
- Disables all spatial debug visualization.

## Runtime Behavior

- Draws in the spatial debug render pass after transparency.
- Uses depth testing and does not write depth.
- Default draw color is white wireframe.
- Default filter behavior is leaves-only and occupied-only.

Residency color mode (`colorMode = .residency`):
- Green: loaded/resident.
- Yellow: loading/unloading in progress.
- Red: unloaded/not resident.
- Orange: mixed resident + non-resident state inside the same leaf.
- White: no residency signal found.

Culling color mode (`colorMode = .culling`):
- Green: entity is present in `visibleEntityIds` this frame.
- Blue: entity is not in `visibleEntityIds` (culled this frame).
- Gray: entity has `RenderComponent.isVisible == false` (explicitly hidden).
- Orange: leaf contains a mix of two or more of the states above (visible/culled/hidden).
- White: no culling signal found in the leaf (for example: no `RenderComponent` entities).

Culling color evaluation is leaf-level and frame-based:
- Colors are computed from all entities in each leaf, then a single leaf color is chosen.
- `visibleEntityIds` is sampled for the current frame, so colors can change frame-to-frame with camera/culling updates.

Requirements for color modes:
- Ensure entities use `StreamingComponent` and/or `LODComponent`; otherwise the fallback color is white.

## Console Status Line

When enabled, the renderer prints a throttled status line:

`[SpatialDebug] enabled=true leaves=<total> drawn=<drawn> cap=<cap>`

This helps confirm:
- The feature is enabled.
- How many leaves exist.
- Whether draw cap is limiting output.
