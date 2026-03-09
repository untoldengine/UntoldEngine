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

# Octree Bounds Visualization

The Spatial Debugger renders **octree leaf bounds** as wireframe boxes.

Each leaf represents a spatial region managed by the engine's octree
system.

Leaf coloring can be configured to visualize:

-   plain structure
-   streaming/residency state
-   runtime culling state

------------------------------------------------------------------------

# Quick Start

``` swift
import UntoldEngine

// Optional: tighten world bounds to your scene for better visualization.
OctreeSystem.shared.worldBounds = AABB(
    min: simd_float3(-40, -5, -40),
    max: simd_float3(40, 25, 40)
)

// Enable octree debug rendering.
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,   // 0 = unlimited
    occupiedOnly: true,    // draw only leaves containing entries
    colorMode: .culling
)
```

Disable the spatial debugger:

``` swift
disableSpatialDebugVisualization()
```

------------------------------------------------------------------------

# Visualization Modes

## Plain (structure only)

Draws octree leaf bounds in a single color.

Useful for verifying:

-   octree subdivision
-   spatial partitioning accuracy
-   entity placement inside the tree

``` swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .plain
)
```

------------------------------------------------------------------------

## Residency (Streaming / LOD)

Colors leaves based on asset residency and streaming state.

Useful for diagnosing:

-   streaming radius problems
-   assets that remain loaded too long
-   streaming thrashing

``` swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .residency
)
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

## Culling

Colors leaves based on runtime visibility.

Useful for diagnosing:

-   frustum culling issues
-   objects unexpectedly culled
-   visibility system behavior

``` swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .culling
)
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

# Showing Empty Leaves

To visualize the full octree structure including empty regions:

``` swift
setOctreeLeafBoundsDebug(
    enabled: true,
    maxLeafNodeCount: 0,
    occupiedOnly: false,
    colorMode: .residency
)
```

This can help diagnose:

-   oversized nodes
-   uneven spatial subdivision
-   empty regions that remain allocated

------------------------------------------------------------------------

# API

## setOctreeLeafBoundsDebug

    setOctreeLeafBoundsDebug(
        enabled: Bool,
        maxLeafNodeCount: Int,
        occupiedOnly: Bool,
        colorMode: SpatialDebugColorMode
    )

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

## disableSpatialDebugVisualization

Disables all spatial debugging overlays.

``` swift
disableSpatialDebugVisualization()
```

------------------------------------------------------------------------

# Runtime Behavior

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

# Console Status Output

When enabled, the renderer periodically prints a status line:

This provides quick feedback that the system is active and indicates:

-   total octree leaf count
-   number of leaves currently drawn
-   whether the draw cap is limiting output

------------------------------------------------------------------------

# LOD Visualizer

The engine also provides an **LOD visualizer** to display which LOD
level each renderable is currently using.

Enable it with:

``` swift
setLODLevelDebug(enabled: true)
```

This mode colors renderables by their active LOD level to help diagnose:

-   incorrect LOD thresholds
-   objects stuck in high-detail LODs
-   aggressive LOD switching
-   spatial LOD distribution across the scene

------------------------------------------------------------------------

# Recommended Debug Workflow

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

