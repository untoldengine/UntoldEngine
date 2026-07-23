# Spatial Debugger

The **Spatial Debugger** provides visual overlays that help diagnose
spatial systems in the engine, including:

-   Octree spatial partitioning
-   Streaming / residency behavior
-   Frustum culling decisions
-   LOD selection

It renders **wireframe octree leaf bounds** and can color them based on
runtime state to help identify issues such as:

-   incorrect spatial partitioning
-   streaming thrashing
-   over-resident regions
-   unexpected culling
-   incorrect LOD selection

This tool is intended for debugging large scenes and spatial performance
issues.

------------------------------------------------------------------------

## Octree Bounds Visualization

The Spatial Debugger renders **octree leaf bounds** as wireframe boxes.

Each leaf represents a spatial region managed by the engine's octree
system.

Leaf coloring can be configured to visualize:

-   plain structure
-   streaming/residency state
-   runtime culling state

------------------------------------------------------------------------

## Quick Start

``` swift
import UntoldEngine

// Optional: tighten world bounds to your scene for better visualization.
OctreeSystem.shared.worldBounds = AABB(
    min: simd_float3(-40, -5, -40),
    max: simd_float3(40, 25, 40)
)

// Enable octree debug rendering.
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,   // 0 = unlimited
    occupiedOnly: true,    // draw only leaves containing entries
    colorMode: .culling
)))
```

Disable the spatial debugger:

``` swift
setSpatialDebug(.disabled)
```

------------------------------------------------------------------------

## Visualization Modes

### Plain (structure only)

Draws octree leaf bounds in a single color.

Useful for verifying:

-   octree subdivision
-   spatial partitioning accuracy
-   entity placement inside the tree

``` swift
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .plain
)))
```

------------------------------------------------------------------------

### Residency (Streaming / LOD)

Colors leaves based on asset residency and streaming state.

Useful for diagnosing:

-   streaming radius problems
-   assets that remain loaded too long
-   streaming thrashing

``` swift
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .residency
)))
```

Color meanings:

  Color    Meaning
  -------- ----------------------------------------
  Green    assets resident
  Yellow   loading/unloading
  Red      unloaded
  Orange   mixed residency states within the leaf
  White    no residency signal found

Residency information is derived from:

-   `StreamingComponent`
-   `LODComponent`

If these components are missing, the leaf falls back to **white**.

------------------------------------------------------------------------

### Culling

Colors leaves based on runtime visibility.

Useful for diagnosing:

-   frustum culling issues
-   objects unexpectedly culled
-   visibility system behavior

``` swift
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .culling
)))
```

Color meanings:

  Color    Meaning
  -------- ------------------------------------------------------
  Green    entity visible this frame
  Blue     entity culled this frame
  Gray     entity hidden (`RenderComponent.isVisible == false`)
  Orange   leaf contains mixed visibility states
  White    no culling signal found

Culling colors are evaluated **per leaf each frame**, using:

-   `visibleEntityIds`
-   `RenderComponent.isVisible`

Because visibility updates every frame, colors may change as the camera
moves.

------------------------------------------------------------------------

## Showing Empty Leaves

To visualize the full octree structure including empty regions:

``` swift
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: false,
    colorMode: .residency
)))
```

This can help diagnose:

-   oversized nodes
-   uneven spatial subdivision
-   empty regions that remain allocated

------------------------------------------------------------------------

## Tile Bounds

Draws wireframe boxes around streaming tiles (`TileComponent` entities),
using each tile's partition-cell bounds so the box matches what the Blender
tile overlay shows. The shared-bucket tile (a global asset, not a spatial
partition cell) is always skipped.

``` swift
setSpatialDebug(.tileBounds(enabled: true, maxTileNodeCount: 500))
```

Tile boxes follow the same color mode as octree leaves (`colorMode` from the
last `.octreeLeafBounds(.enabled(...))` call): `.residency` colors tiles by
load state, while `.plain` and `.culling` both draw a neutral wireframe since
tile stubs have no per-frame visibility signal of their own.

------------------------------------------------------------------------

## Static Batch Cell Bounds

Draws wireframe boxes around static-batching grid cells (`BatchCellID`
regions), useful for diagnosing batch-cell sizing and rebuild boundaries.

``` swift
setSpatialDebug(.staticBatchCellBounds(
    enabled: true,
    maxCellCount: 2000,
    colorMode: .lod
))
```

`colorMode` (`SpatialDebugBatchCellColorMode`) controls per-cell coloring:

  Mode        Meaning
  ----------- ---------------------------------------------------------
  `.plain`    Single neutral color for every cell
  `.culling`  Green = all entities visible, blue = all culled, orange = mixed
  `.lod`      Colors by the LOD level(s) present in the cell; a mixed-LOD cell gets a distinct "mixed" color
  `.cell`     Stable per-cell pseudo-random hue, useful for visually distinguishing neighboring cells

------------------------------------------------------------------------

## Texture Streaming Tiers

Colors renderable entities by their current texture streaming tier, instead
of drawing wireframe bounds:

``` swift
setSpatialDebug(.textureStreamingTiers(true))
```

Color meanings: Blue = full resolution, Orange = medium (capped), Red =
minimum, Yellow = texture load in-flight. Useful for spotting entities stuck
at a reduced texture tier or thrashing between tiers near the streaming
budget limit.

------------------------------------------------------------------------

## API

### setSpatialDebug

    setSpatialDebug(.octreeLeafBounds(.enabled(
        maxLeafNodeCount: Int,
        occupiedOnly: Bool,
        colorMode: SpatialDebugLeafColorMode
    )))

    setSpatialDebug(.tileBounds(enabled: Bool, maxTileNodeCount: Int = 500))
    setSpatialDebug(.staticBatchCellBounds(enabled: Bool, maxCellCount: Int = 2000, colorMode: SpatialDebugBatchCellColorMode = .plain))
    setSpatialDebug(.lodLevels(Bool))
    setSpatialDebug(.textureStreamingTiers(Bool))
    setSpatialDebug(.disabled)

Parameters:

  Parameter          Description
  ------------------ -----------------------------------------------------
  enabled            Master toggle for octree visualization
  maxLeafNodeCount   Maximum leaves drawn per frame (`0` = unlimited)
  occupiedOnly       When true, only leaves containing entries are drawn
  colorMode          Controls how leaf bounds are colored

Available color modes:

    .plain
    .residency
    .culling

------------------------------------------------------------------------

### Disable All

Disables all spatial debugging overlays.

``` swift
setSpatialDebug(.disabled)
```

------------------------------------------------------------------------

## Runtime Behavior

The spatial debugger:

-   runs in a dedicated **spatial debug render pass**
-   renders **after transparency**
-   uses **depth testing**
-   **does not write depth**

This ensures the visualization remains readable without interfering with
scene rendering.

Default behavior:

-   leaves only
-   occupied leaves only
-   white wireframe bounds

------------------------------------------------------------------------

## Console Status Output

When enabled, the renderer periodically prints a status line:

This provides quick feedback that the system is active and indicates:

-   total octree leaf count
-   number of leaves currently drawn
-   whether the draw cap is limiting output

------------------------------------------------------------------------

## LOD Visualizer

The engine also provides an **LOD visualizer** to display which LOD
level each renderable is currently using.

Enable it with:

``` swift
setSpatialDebug(.lodLevels(true))
```

This mode colors renderables by their active LOD level to help diagnose:

-   incorrect LOD thresholds
-   objects stuck in high-detail LODs
-   aggressive LOD switching
-   spatial LOD distribution across the scene

------------------------------------------------------------------------

## Recommended Debug Workflow

When diagnosing spatial performance issues, a typical workflow is:

1.  **Plain mode**
    -   Verify octree subdivision
2.  **Residency mode**
    -   Confirm streaming behavior
3.  **Culling mode**
    -   Validate visibility decisions
4.  **LOD visualizer**
    -   Check LOD distribution

Together these tools provide a full picture of how the engine is
managing spatial data.
