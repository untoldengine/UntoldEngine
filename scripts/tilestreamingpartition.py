# tilestreamingpartition.py
#
# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
Blender tile-export script for UntoldEngine geometry streaming.

Architecture overview
---------------------
The exporter uses a two-layer hybrid model:

  Layer 1 — Tile-local assignment
    Meshes whose world-space footprint fits within a small number of tiles are
    exported per-tile with bmesh clipping at tile boundaries.  These are streamed
    in/out by the engine as the camera moves.

  Layer 2 — Shared bucket
    Meshes that span too many tiles (large structural geometry, terrain slabs,
    building shells) are routed to a single shared USD file.  The engine loads
    this at startup via a very large streaming radius, providing a consistent
    backdrop without the overhead of per-tile clipping for geometry that would
    appear in dozens of tiles anyway.

Why overlap-first assignment?
  Assigning by object center produces large tiles when many object centers
  coincide.  Assigning by AABB overlap distributes geometry across all tiles it
  physically occupies, producing balanced tile sizes.

Why not split everything?
  Bisecting a high-poly mesh at every tile boundary is O(faces × tiles).
  For a 400-unit building on a 10-unit grid that is 40 tiles wide, this means
  running 40 bisect passes — which for a dense mesh takes minutes per object.
  The classification threshold catches these cases early and routes them to the
  shared bucket, keeping the local pipeline fast.

Why shared bucket instead of skip?
  Skipping spanning geometry creates obvious holes in the rendered scene.
  A shared bucket gives the engine something to display while fine-detail tiles
  load around the camera.
"""

import bpy
import os
import json
import math
import bmesh
import colorsys
import argparse
import sys
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from contextlib import contextmanager
from mathutils import Vector, Matrix

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from untoldexplorer import (
    ColorManagementBake,
    ProgressCallback,
    ProgressReporter,
    bake_color_management_lut,
    clear_scene,
    export_objects_to_untold,
    extract_scene_payload_from_objects,
    import_usd_asset,
    load_blend_scene,
    stage_hdr_assets_for_output,
    validate_bake_resolution,
    validate_lut_size,
)


def print_export_stage(stage, detail=""):
    suffix = f" - {detail}" if detail else ""
    print(f"[stage] {stage}{suffix}", flush=True)


def make_untold_progress_callback(label):
    def _callback(stage, done, total, detail):
        if total > 1:
            print(f"[progress] {label}: {stage} {done}/{total} - {detail}", flush=True)
        else:
            print(f"[progress] {label}: {stage} - {detail}", flush=True)
    return _callback


def _manifest_vec(values):
    return [float(value) for value in values]


def _manifest_matrix_rows(rows):
    return [[float(value) for value in row] for row in rows]


def _manifest_light_kind(light_type):
    return {
        1: "directional",
        2: "point",
        3: "spot",
        4: "area",
    }.get(int(light_type), "point")


def _manifest_light_payload(light):
    return {
        "entity_name": light.entity_name,
        "kind": _manifest_light_kind(light.light_type),
        "light_type": int(light.light_type),
        "color": _manifest_vec(light.color),
        "intensity": float(light.intensity),
        "position": _manifest_vec(light.position),
        "radius": float(light.radius),
        "range": float(getattr(light, "range", 0.0)),
        "direction": _manifest_vec(light.direction),
        "falloff": float(light.falloff),
        "right": _manifest_vec(light.right),
        "inner_cone": float(light.inner_cone),
        "up": _manifest_vec(light.up),
        "outer_cone": float(light.outer_cone),
        "area_size": _manifest_vec(light.area_size),
        "source_power": float(light.source_power),
        "source_exposure": float(light.source_exposure),
        "casts_shadow": bool(getattr(light, "casts_shadow", False)),
        "uses_radiometric_units": True,
        "local_transform_rows": _manifest_matrix_rows(light.local_transform_rows),
    }


def _manifest_camera_payload(camera):
    return {
        "entity_name": camera.entity_name,
        "position": _manifest_vec(camera.position),
        "forward": _manifest_vec(camera.forward),
        "up": _manifest_vec(camera.up),
        "right": _manifest_vec(camera.right),
        "fov_y_degrees": float(camera.fov_y_degrees),
        "near_clip": float(camera.near_clip),
        "far_clip": float(camera.far_clip),
        "aspect_ratio": float(camera.aspect_ratio),
        "local_transform_rows": _manifest_matrix_rows(camera.local_transform_rows),
    }


def _manifest_color_management_payload(bake, manifest_dir=None):
    if bake is None:
        return None
    lut_uri = bake.lut_texture.uri
    if manifest_dir is not None and bake.lut_texture.source_path is not None:
        lut_uri = os.path.relpath(
            bake.lut_texture.source_path,
            Path(manifest_dir),
        ).replace(os.sep, "/")
    return {
        "lutUri": lut_uri,
        "lutSize": bake.lut_size,
        "viewTransform": bake.view_transform,
        "look": bake.look,
        "displayDevice": bake.display_device,
        "exposure": float(bake.exposure),
        "gamma": float(bake.gamma),
        "shaperMinStops": float(bake.shaper_min_stops),
        "shaperMaxStops": float(bake.shaper_max_stops),
    }


def collect_manifest_scene_payload():
    lights, cameras = extract_scene_payload_from_objects(
        list(bpy.data.objects),
        convert_orientation=CONVERT_ORIENTATION,
        source_orientation=SOURCE_ORIENTATION,
        include_scene_payload=True,
    )
    return (
        [_manifest_light_payload(light) for light in lights],
        [_manifest_camera_payload(camera) for camera in cameras],
    )


def append_worker_progress(progress_file, event):
    if not progress_file:
        return
    try:
        with open(progress_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, sort_keys=True) + "\n")
            f.flush()
    except OSError:
        pass

# ============================================================
# CONFIG
# First knobs to tune for a new scene:
#   TILE_SIZE_X / TILE_SIZE_Z   — set to ~1–2× the typical object size
#   SPANNING_THRESHOLD_TILES    — raise if too much geometry goes to shared bucket
#   OVERLAP_THRESHOLD           — raise if objects with unusual shapes mis-classify
# ============================================================

OUTPUT_DIR = "//tile_exports"
EXPORT_FORMAT = "untold"        # Runtime payload format emitted for tiles.
CONVERT_ORIENTATION = True      # Convert Blender scene data into engine space (+Z forward, +Y up).
SOURCE_ORIENTATION = "blender-native"
COMPRESS_GEOMETRY = False       # Compress vertex/index chunks with LZ4 (requires: pip install lz4).
BAKE_MATERIALS = False          # Bake node-graph materials the engine can't evaluate (see --bake-materials).
BAKE_RESOLUTION = 1024          # Square resolution for baked material textures.
BAKE_CACHE = True                # Skip re-baking materials unchanged since the last export (see --no-bake-cache).
                                  # Cache location follows source_asset_path (shared across all tiles from one
                                  # --input source); falls back to being scoped per-tile-output when no --input
                                  # source path is known (e.g. addon exports operating on an already-open scene).
BAKE_COLOR_MANAGEMENT = False   # Bake the scene's View Transform/Look/Exposure/Gamma into a LUT (see --bake-color-management).
COLOR_LUT_SIZE = 32             # Grid size (N) for the NxNxN color-grading LUT.

# Tile footprint in Blender world units.
# Start at 10 and tune with DRY_RUN=True.  Rule of thumb: set to 2–3× the
# typical object size in your scene.  If the scene is 200 units wide and you
# want ~50 tiles in X, use TILE_SIZE_X = 4–5.  The dry-run header now prints
# the scene bounds and implied grid size so you can calibrate quickly.
TILE_SIZE_X = 25.0
TILE_SIZE_Z = 25.0
# Height bucket.  Keep very large (>> scene height) to avoid vertical splitting;
# vertical tiling is only useful for multi-floor indoor scenes.
TILE_SIZE_Y = 10000.0

# --- Spanning classification (OR logic) -----------------------
#
# A mesh is classified as SPANNING if either condition is true:
#
#   DIMENSION RULE
#     max(world_width, world_depth) > SPANNING_THRESHOLD_TILES * max(tile_x, tile_z)
#     Catches objects that are geometrically "room-scale" or larger.
#
#   OVERLAP RULE
#     XZ tile overlap count > effective_overlap_threshold
#     Safety net for unusual aspect ratios or dense tile grids.
#
# Spanning objects go to the shared bucket runtime payload and are never per-tile clipped.
#
# Tuning guide:
#   The spanning limit in world units = SPANNING_THRESHOLD_TILES × TILE_SIZE.
#   Set this to roughly the largest object you want to tile with clipping.
#   Objects wider than this go to the shared bucket (loaded at large radius).
#   Example: SPANNING=4, TILE_SIZE=25 → limit = 100 units.
SPANNING_THRESHOLD_TILES = 4    # dimension ratio threshold

# OVERLAP_THRESHOLD: maximum XZ tile-overlap count before an object is
# considered spanning.  Set to None to auto-derive as SPANNING_THRESHOLD_TILES²
# (recommended — keeps the threshold tile-size-independent).  Set to an explicit
# integer only if you need a different safety-net value.
OVERLAP_THRESHOLD = None        # None = auto (SPANNING_THRESHOLD_TILES²)

# Among spanning objects, those whose dimension ratio exceeds this value are
# additionally flagged as "future_split_candidate" in the manifest.  They
# SHOULD eventually be split across tiles but the split pipeline is not yet
# implemented.  For now they still export to the shared bucket.
FUTURE_SPLIT_TILE_THRESHOLD = 15

# --- Spanning-object splitting --------------------------------
# When True, spanning objects (shared_bucket + future_split_candidate) whose
# XZ tile overlap count is <= SPLIT_MAX_TILES are routed into the per-tile
# local system and clipped at tile boundaries, eliminating the shared bucket
# for building-scale geometry.  Objects that exceed SPLIT_MAX_TILES still go
# to the shared bucket to avoid thousands of clip+export iterations for truly
# scene-spanning meshes (ground planes, terrain slabs).
#
# This routing is only honored when CLIP_LOCAL_MESHES is also True (see below).
# Without clipping, "routed to tiles" means the *entire* spanning mesh is
# duplicated whole into every overlapping tile instead of being cut into
# per-tile pieces — for an object that already overlaps dozens of tiles, that
# is dozens of full-size coplanar copies at the same world position, which
# z-fights and pops in/out independently as each tile streams. With
# CLIP_LOCAL_MESHES == False, spanning objects always stay in the shared
# bucket regardless of SPLIT_MAX_TILES.
#
# Rule of thumb for SPLIT_MAX_TILES: (max_building_width / TILE_SIZE)²
# At TILE_SIZE=25, default 400 allows objects up to 500 m × 500 m to be split.
SPLIT_SPANNING_OBJECTS = True
SPLIT_MAX_TILES        = 400

# --- Shared bucket streaming ----------------------------------
# Used for objects that still end up in the shared bucket (SPLIT_SPANNING_OBJECTS=False,
# or objects exceeding SPLIT_MAX_TILES).  Streaming radius is a fraction of the
# scene's half-diagonal.  1.0 means it is visible from anywhere in the scene.
SHARED_STREAMING_RADIUS_FRACTION = 1.0
SHARED_UNLOAD_RADIUS_FRACTION    = 1.5   # must be > streaming fraction

# --- Local tile export ----------------------------------------
# When True, tile-local meshes are bmesh-clipped to exact tile boundaries.
# When False, the full mesh is duplicated into every overlapping tile (faster
# but produces duplicate geometry at tile edges — acceptable for prototyping).
CLIP_LOCAL_MESHES = False

# When True, objects sharing identical materials within a tile (or the shared
# bucket) are joined into a single mesh before USD export.  This dramatically
# reduces draw calls at runtime — the engine sees fewer distinct mesh prims per
# tile.  No visual effect.  Requires BAKE_WORLD_TRANSFORMS.
MERGE_BY_MATERIAL = True

# Objects whose original name starts with this prefix are never merged, even
# when MERGE_BY_MATERIAL is True.  They are exported as individual entities and
# retain their original name in the .untold file.  Set to "" to disable.
# Example: name an object "NM_Pipe_001" in Blender to keep it separate.
NO_MERGE_PREFIX = "NM_"

# The exporter always writes uv_layers[0] as a merged mesh's texture coordinates
# (see untoldexplorer.py).  Source assets combined into one scene often name their
# primary UV layer differently ("UVMap", "UVChannel_1", "UVW", ...).  When objects
# with different primary-layer names are joined by merge_objects_by_material(),
# bmesh unifies layers *by name*, so only the objects whose layer name landed at
# index 0 keep real UVs — everyone else's merged-in faces get all-zero UVs and
# render untextured.  Renaming every object's active layer to this canonical name
# before merging keeps the primary UV channel unified across the whole tile.
MERGE_CANONICAL_UV_LAYER_NAME = "UVMap"

# Clip tolerance at tile boundaries.
# for objects at large world coordinates (e.g. buildings at x=1500).
SPLIT_CLIP_EPSILON = 1e-4

# --- Baking ---------------------------------------------------
BAKE_WORLD_TRANSFORMS = True    # Bake world matrix into mesh vertices before export.

# --- HLOD -----------------------------------------------------
# Optional offline HLOD generation for tile-local exports.  Each configured
# level exports a simplified sibling payload next to the full tile asset and emits
# manifest metadata for the engine to switch to it at distance.
GENERATE_HLOD = False
HLOD_LEVELS = [
    {
        "suffix": "_hlod",
        "reduction_ratio": 0.10,
        "switch_distance": 1.00,   # normalized outer-band position from streaming_radius -> unload_radius
    },
]

# --- Tile LOD levels ------------------------------------------
# Per-tile discrete LOD generation.  Each entry is a (decimate_ratio,
# switch_distance) pair.  switch_distance accepts two forms:
#   • 0 < value <= 1.0  — normalised position in the [streaming_r, unload_r] band
#                         (legacy / script-default mode; mapped through a non-linear
#                         curve so bands are wider at distance)
#   • value > 1.0       — absolute metres; clamped to the valid range for the tile's
#                         tier (the mode used when the Blender addon or CLI sets values)
# Sorted ascending by switch_distance (finest first).  LOD0 = full geometry; entries
# here define LOD1, LOD2, etc.
GENERATE_LOD = False
TILE_LOD_LEVELS = [
    (0.5, 0.30),   # LOD1 — 50% poly, widened near/mid-band anchor
    (0.2, 0.78),   # LOD2 — 20% poly, shifted toward the far band
]

# Band shaping knobs.  These defaults produce a stable ladder:
#   full tile     -> near half of streaming band
#   tile LODs     -> spread across the mid band with eased spacing
#   HLOD          -> close to unload radius, not streaming radius
LOD_NEAR_BAND_START_FRACTION = 0.45
LOD_SWITCH_CURVE_EXPONENT    = 1.25
HLOD_SWITCH_CURVE_EXPONENT   = 2.0
SWITCH_DISTANCE_MIN_GAP      = 4.0
SWITCH_DISTANCE_OUTER_MARGIN = 4.0

# --- Quadtree / semantic-tier streaming radii -----------------
# Fractions of scene_half_diag — converted to world-space metres once at
# export time so radii scale automatically with any scene size.
#   indoor  — tight bands for room/building interiors
#   outdoor — wider bands for cities, open-world, and street scenes
# 'auto' (default) infers the profile from scene footprint and tier distribution.
TIER_STREAMING_FRACTIONS = {
    "indoor": {
        "ExteriorShell":      {"streaming": 0.80, "unload": 1.20, "priority": 15},
        "StructuralInterior": {"streaming": 0.30, "unload": 0.50, "priority": 10},
        "RoomContents":       {"streaming": 0.10, "unload": 0.18, "priority":  8},
        "FineProps":          {"streaming": 0.03, "unload": 0.06, "priority":  5},
    },
    "outdoor": {
        "ExteriorShell":      {"streaming": 0.35, "unload": 0.55, "priority": 15},
        "StructuralInterior": {"streaming": 0.25, "unload": 0.40, "priority": 12},
        "RoomContents":       {"streaming": 0.10, "unload": 0.18, "priority":  8},
        "FineProps":          {"streaming": 0.04, "unload": 0.08, "priority":  5},
    },
}
SCENE_STREAMING_PROFILE = "auto"  # auto | indoor | outdoor
TIER_RADIUS_OVERRIDES: dict = {}  # tier -> {"streaming": metres, "unload": metres, optional "priority": int}
_ACTIVE_TIER_RADII: dict = {}

# Tiers for which HLOD and LOD variants are generated during quadtree export.
# RoomContents (stream=5m) and FineProps (stream=2m) have radii too small for
# a meaningful HLOD band given SWITCH_DISTANCE_MIN_GAP=2.0, so they are skipped.
HLOD_LOD_TIERS = {"ExteriorShell", "StructuralInterior"}

# Short codes written into tile IDs and manifest tier fields.
TIER_SHORT_CODES = {
    "ExteriorShell":      "ES",
    "StructuralInterior": "SI",
    "RoomContents":       "RC",
    "FineProps":          "FP",
}

VALID_SEMANTIC_TIERS = set(TIER_SHORT_CODES.keys())

OBJECT_PRIORITY_HINTS = {
    "Low":      3,
    "Normal":   8,
    "High":    12,
    "Critical": 15,
}

# When semantic confidence (from the phase-1+2 script) is below this value,
# the object's tier is overridden to DEFAULT_TIER instead of being trusted.
TIER_CONFIDENCE_THRESHOLD = 0.50

# Tier assigned to objects with missing or low-confidence metadata.
# StructuralInterior is the safest default: loads at medium distance,
# never deferred as long as FineProps, never as wide-radius as ExteriorShell.
DEFAULT_SEMANTIC_TIER = "StructuralInterior"
UNTAGGED_SEMANTIC_TIER = "Auto"  # Auto | ExteriorShell | StructuralInterior | RoomContents | FineProps

# Fraction of objects that must carry Untold metadata before the quadtree
# export path is activated.  Below this threshold the grid path runs instead.
QUADTREE_METADATA_COVERAGE_THRESHOLD = 0.50

# When True, the quadtree path is always used even if the input has no
# pre-baked metadata.  The exporter runs the inline annotation pass instead.
# Set via the --quadtree CLI flag.
FORCE_QUADTREE = False

# --- Inline quadtree annotation (replaces the external Blender script) -------
# When --quadtree is passed and objects have no pre-baked metadata the exporter
# runs the annotation logic itself on the imported scene, eliminating the
# separate Blender annotation + re-export step.
#
# Mirror the same constants used by untold_phase12_suffix-Blender.py so that
# inline-annotated and pre-annotated scenes produce identical partitioning.

INLINE_QUADTREE_MAX_DEPTH            = 6
INLINE_SPANNING_CHILD_OVERLAP_THRESHOLD = 2

# KD-tree partitioning constants (used when --kdtree is passed).
INLINE_KDTREE_MAX_DEPTH   = 7    # One extra level vs quadtree; binary splits are shallower.
INLINE_KDTREE_MIN_LEAF    = 4    # Stop subdividing when a node holds <= this many objects.
# When True, the KD-tree path is always used (set via the --kdtree CLI flag).
FORCE_KDTREE = False

# Runtime tiles are emitted per (spatial node, semantic tier), so an apparently
# balanced spatial leaf can still become several singleton runtime tiles after
# semantic grouping.  Collapse underfilled leaf-tier groups upward until each
# group has at least this many objects or reaches the floor root.
INLINE_MIN_OBJECTS_PER_TILE_TIER = 4
INLINE_COLLAPSE_UNDERFILLED_TILE_TIERS = True

INLINE_AUTO_FLOOR_BAND_HEIGHT = None   # set to a float (metres) to override auto-detection
INLINE_MIN_FLOOR_BAND_HEIGHT  = 2.5
INLINE_MAX_FLOOR_BAND_HEIGHT  = 5.0
INLINE_FLOOR_COUNT_OVERRIDE   = None  # set to an int to pin floor count (skips Z-extent calc)
INLINE_FLOOR_BAND_HEIGHT_OVERRIDE = None  # set to a float to pin band height and derive floor count

INLINE_FINE_PROP_MAX_DIM    = 0.40
INLINE_FINE_PROP_MAX_VOLUME = 0.03
INLINE_ROOM_CONTENT_MAX_DIM    = 2.5
INLINE_ROOM_CONTENT_MAX_VOLUME = 3.0
INLINE_STRUCTURAL_MIN_DIM  = 2.5
INLINE_STRUCTURAL_MIN_AREA = 4.0

INLINE_EXTERIOR_NAME_HINTS = [
    "facade", "façade", "curtain", "cladding", "balcony", "roof", "exterior",
    "outer", "windowwall", "window_wall", "glazing", "glasswall", "glass_wall",
]
INLINE_STRUCTURAL_NAME_HINTS = [
    "wall", "floor", "ceiling", "slab", "beam", "column", "pillar", "stair",
    "stairs", "shaft", "elevator", "corridor", "hall", "partition", "railing",
    "core", "doorframe", "door_frame", "doorpanel", "door_panel", "door", "frame",
]
INLINE_ROOM_CONTENT_NAME_HINTS = [
    "chair", "table", "desk", "sofa", "couch", "bed", "cabinet", "shelf",
    "lamp", "appliance", "sink", "toilet", "bathtub", "monitor", "tv",
    "plant", "furniture", "airterminal", "airterminals",
]
INLINE_FINE_PROP_NAME_HINTS = [
    "pipefitting", "pipefittings", "pipe", "duct", "tube", "conduit",
    "sprinkler", "sensor", "switch", "outlet",
    "handle", "knob", "hinge", "fastener", "fixture", "smallprop", "small_prop",
]
INLINE_EXTERIOR_MATERIAL_HINTS = [
    "glass", "window", "facade", "façade", "roof", "metal", "concrete", "brick",
    "stone", "cladding", "aluminum", "steel",
]
INLINE_ROOM_CONTENT_MATERIAL_HINTS = [
    "wood", "fabric", "leather", "upholstery", "cabinet", "counter", "furniture",
]

# --- Scene ----------------------------------------------------
VISIBLE_ONLY = True
SOURCE_SCENE_PATH_OVERRIDE = ""
ERROR_IF_UNSAVED_SOURCE_NOT_FOUND = True

# Set by bridge.py for in-process (Blender add-on) exports so the overall
# "tile export" ProgressReporter can drive a UI progress bar.
PROGRESS_CALLBACK: ProgressCallback | None = None

# --- Auto tile sizing -----------------------------------------
AUTO_TILE_SIZE = False
AUTO_TILE_TARGET_MAX_TILES       = 2000
AUTO_TILE_TARGET_OBJECTS_PER_TILE = 32
AUTO_TILE_OBJECT_TARGET_TOLERANCE = 1.0
AUTO_TILE_MIN_SIZE               = 5.0
AUTO_TILE_MAX_SIZE               = 100000.0
AUTO_TILE_MAX_ITERATIONS         = 8
AUTO_TILE_SAFETY_SCALE           = 1.05

# --- Streaming radius defaults (for tile-local entries) -------
STREAMING_RADIUS_TILE_MULTIPLIER  = 2.0
UNLOAD_RADIUS_TILE_MULTIPLIER     = 3.0
STREAMING_RADIUS_SCENE_FRACTION   = 0.35
UNLOAD_RADIUS_SCENE_FRACTION      = 0.50
DEFAULT_STREAMING_PRIORITY        = 10

# --- Debug ----------------------------------------------------
DEBUG_AABB_ONLY      = False    # Export colored AABB cubes instead of real geometry.
DRY_RUN              = False    # Plan only — no payload files written.
DRY_RUN_WRITE_MANIFEST = False  # Write manifest JSON even in dry-run mode.

# --- Sample mode (TEMPORARY — for fast iteration only) --------
# When True, only a small rectangular patch of tiles closest to the world
# origin is exported.  Useful for quickly verifying the engine without
# waiting for a full 1000+ tile run.  Set back to False for production.
SAMPLE_MODE     = False   # Enable to keep only ~SAMPLE_FRACTION of tiles
SAMPLE_FRACTION = 0.10    # Fraction of total tiles to keep (approx)

# --- Perimeter mode (TEMPORARY — for fast iteration only) -----
# When True, only the outer shell of tiles is exported.  PERIMETER_DEPTH
# controls how many tiles inward from the boundary are kept (1 = strict
# single-ring perimeter, 2-3 captures thick walls whose mesh AABBs extend
# deeper into the building interior).
PERIMETER_MODE  = False
PERIMETER_DEPTH = 1       # tiles inward from the boundary to keep

# --- Parallel export ------------------------------------------
# Number of Blender worker processes to spawn for tile export.
#   0  = auto (half of os.cpu_count(), capped at 8, and at an estimated
#        memory-safe count -- see AUTO_WORKER_* below)
#   1  = disabled (sequential, same as before)
#   N  = exactly N workers (bypasses the memory-safe estimate entirely)
# Each worker gets an independent Blender process that loads the source
# scene and exports its assigned batch of tiles.  Has no effect during
# DRY_RUN (no files are written anyway).
PARALLEL_WORKERS = 0

# Auto mode (PARALLEL_WORKERS=0) also caps worker count by estimated memory
# footprint, so a large scene doesn't get multiplied across up to 8
# concurrent full-scene reloads (each worker independently imports/opens
# the whole source scene) and exhaust system RAM. This is a rough heuristic
# based on the source file's on-disk size -- actual in-memory footprint
# isn't knowable without loading the scene -- so it errs conservative.
# Explicit --parallel-workers N always bypasses it.
AUTO_WORKER_RAM_SAFETY_FRACTION = 0.6       # fraction of total RAM the auto cap may plan to use
AUTO_WORKER_SCENE_MEMORY_MULTIPLIER = 6.0   # estimated in-memory expansion vs on-disk file size
AUTO_WORKER_BAKE_MEMORY_MULTIPLIER = 1.5    # extra multiplier when --bake-materials is enabled
AUTO_WORKER_MIN_ESTIMATE_BYTES = 512 * 1024 * 1024  # floor per-worker estimate


# ============================================================
# DERIVED CONFIG
# ============================================================

def _effective_overlap_threshold():
    """Return the XZ tile-overlap threshold used for spanning classification.

    When OVERLAP_THRESHOLD is None (the default), derive it as
    SPANNING_THRESHOLD_TILES².  This keeps the threshold proportional to the
    dimension rule: an object that exactly hits SPANNING_THRESHOLD_TILES in
    both X and Z occupies SPANNING_THRESHOLD_TILES² tiles, so the overlap rule
    fires at the same physical object size regardless of TILE_SIZE.

    Example: SPANNING_THRESHOLD_TILES=3 → threshold=9.  An object spanning a
    3×3 tile footprint (~30 m × 30 m at TILE_SIZE=10, or ~150 m × 150 m at
    TILE_SIZE=50) triggers both rules simultaneously.
    """
    if OVERLAP_THRESHOLD is not None:
        return int(OVERLAP_THRESHOLD)
    return int(SPANNING_THRESHOLD_TILES) ** 2


# ============================================================
# SECTION 1: FILE / PATH UTILITIES
# ============================================================

def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def normalize_path(path: str) -> str:
    if not path:
        return ""
    if path.startswith("//"):
        return os.path.abspath(bpy.path.abspath(path))
    return os.path.abspath(path)


def is_usable_base_dir(path: str) -> bool:
    if not path:
        return False
    normalized = os.path.abspath(path)
    if normalized == os.path.sep:
        return False
    return os.path.isdir(normalized) and os.access(normalized, os.W_OK)


def is_usd_filepath(path: str) -> bool:
    if not path:
        return False
    ext = os.path.splitext(path)[1].lower()
    return ext in (".usd", ".usda", ".usdc", ".usdz")


def is_blend_filepath(path: str) -> bool:
    if not path:
        return False
    return os.path.splitext(path)[1].lower() == ".blend"


def extract_usd_filepath(value: str) -> str:
    if not value:
        return ""
    normalized = normalize_path(value)
    return normalized if is_usd_filepath(normalized) else ""


def extract_usd_path_from_operator(op) -> str:
    if op is None:
        return ""
    filepath = ""
    if hasattr(op, "filepath"):
        filepath = getattr(op, "filepath", "")
    if not filepath and hasattr(op, "properties") and hasattr(op.properties, "filepath"):
        filepath = getattr(op.properties, "filepath", "")
    return extract_usd_filepath(filepath)


def get_recent_usd_import_path() -> str:
    wm = bpy.context.window_manager
    if wm is None:
        return ""
    for operator_id in ("WM_OT_usd_import", "IMPORT_SCENE_OT_usd"):
        try:
            props = wm.operator_properties_last(operator_id)
        except Exception:
            props = None
        filepath = extract_usd_path_from_operator(props)
        if filepath:
            print(f"Using USD source path from {operator_id}: {filepath}")
            return filepath
    try:
        operators = list(wm.operators)
    except Exception:
        return ""
    for op in reversed(operators):
        bl_idname = str(getattr(op, "bl_idname", "")).lower()
        if "usd_import" not in bl_idname:
            continue
        filepath = extract_usd_path_from_operator(op)
        if filepath:
            print(f"Using USD source path from operator history: {filepath}")
            return filepath
    return ""


def resolve_source_scene_path() -> str:
    if bpy.data.filepath:
        return os.path.abspath(bpy.data.filepath)
    if SOURCE_SCENE_PATH_OVERRIDE:
        override = normalize_path(SOURCE_SCENE_PATH_OVERRIDE)
        if override:
            return override
    recent = get_recent_usd_import_path()
    if recent:
        return recent
    return ""


def resolve_output_dir(raw_path: str, source_scene_path: str = "") -> str:
    if raw_path.startswith("//"):
        if bpy.data.filepath:
            base_dir = os.path.dirname(os.path.abspath(bpy.data.filepath))
        elif source_scene_path:
            base_dir = os.path.dirname(os.path.abspath(source_scene_path))
        else:
            script_dir = ""
            try:
                script_dir = os.path.dirname(os.path.abspath(__file__))
            except NameError:
                script_dir = ""
            cwd_dir = os.getcwd()
            if is_usable_base_dir(script_dir):
                base_dir = script_dir
            elif is_usable_base_dir(cwd_dir):
                base_dir = cwd_dir
            else:
                base_dir = os.path.join(os.path.expanduser("~"), "UntoldTileExport")
                ensure_dir(base_dir)
            print(f"Warning: unsaved .blend — resolving '{raw_path}' relative to: {base_dir}")
        relative = raw_path[2:].lstrip("/\\")
        return os.path.abspath(os.path.join(base_dir, relative))
    if os.path.isabs(raw_path):
        return os.path.abspath(raw_path)
    return os.path.abspath(raw_path)


def sanitize_name(name: str) -> str:
    safe = "".join(c if c.isalnum() or c in ("_", "-") else "_" for c in name)
    return safe.strip("_") or "object"


def format_bytes(num_bytes):
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(max(num_bytes, 0))
    idx = 0
    while value >= 1024.0 and idx < len(units) - 1:
        value /= 1024.0
        idx += 1
    return f"{value:.2f} {units[idx]}"


def clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def lerp(a, b, t):
    return a + (b - a) * t


def validate_hlod_levels():
    """Return normalized HLOD level configs or raise on invalid settings."""
    normalized = []
    for idx, level in enumerate(HLOD_LEVELS):
        if not isinstance(level, dict):
            raise RuntimeError(f"HLOD_LEVELS[{idx}] must be a dict.")

        suffix = str(level.get("suffix", "")).strip()
        if not suffix:
            raise RuntimeError(f"HLOD_LEVELS[{idx}] is missing a non-empty 'suffix'.")

        try:
            reduction_ratio = float(level.get("reduction_ratio"))
        except (TypeError, ValueError):
            raise RuntimeError(
                f"HLOD_LEVELS[{idx}] has invalid 'reduction_ratio': {level.get('reduction_ratio')}"
            )
        if not (0.0 < reduction_ratio <= 1.0):
            raise RuntimeError(
                f"HLOD_LEVELS[{idx}] reduction_ratio must be in (0, 1], got {reduction_ratio}."
            )

        try:
            switch_distance = float(level.get("switch_distance"))
        except (TypeError, ValueError):
            raise RuntimeError(
                f"HLOD_LEVELS[{idx}] has invalid 'switch_distance': {level.get('switch_distance')}"
            )
        if switch_distance <= 0.0:
            raise RuntimeError(
                f"HLOD_LEVELS[{idx}] switch_distance must be > 0 (metres or 0–1 normalised), got {switch_distance}."
            )

        normalized.append({
            "suffix": suffix,
            "reduction_ratio": reduction_ratio,
            "switch_distance": switch_distance,
        })

    return normalized


def validate_lod_levels():
    """Return normalized LOD level configs or raise on invalid settings.

    Input format: list of (decimate_ratio, switch_distance) tuples.
    Output: list of dicts sorted ascending by switch_distance.
    """
    if not TILE_LOD_LEVELS:
        return []

    normalized = []
    for idx, entry in enumerate(TILE_LOD_LEVELS):
        if not isinstance(entry, (list, tuple)) or len(entry) != 2:
            raise RuntimeError(
                f"TILE_LOD_LEVELS[{idx}] must be a (ratio, distance) pair, got {entry!r}"
            )

        try:
            ratio = float(entry[0])
        except (TypeError, ValueError):
            raise RuntimeError(
                f"TILE_LOD_LEVELS[{idx}] has invalid decimate_ratio: {entry[0]!r}"
            )
        if not (0.0 < ratio <= 1.0):
            raise RuntimeError(
                f"TILE_LOD_LEVELS[{idx}] decimate_ratio must be in (0, 1], got {ratio}."
            )

        try:
            distance = float(entry[1])
        except (TypeError, ValueError):
            raise RuntimeError(
                f"TILE_LOD_LEVELS[{idx}] has invalid switch_distance: {entry[1]!r}"
            )
        if distance <= 0.0:
            raise RuntimeError(
                f"TILE_LOD_LEVELS[{idx}] switch_distance must be > 0 (metres or 0–1 normalised), got {distance}."
            )

        normalized.append({
            "ratio": ratio,
            "switch_distance": distance,
        })

    # Sort ascending by switch_distance (canonical contract).
    normalized.sort(key=lambda l: l["switch_distance"])
    return normalized


def compute_hlod_switch_distances(streaming_r, unload_r, levels):
    if not levels:
        return []

    gap = max(unload_r - streaming_r, SWITCH_DISTANCE_MIN_GAP * 2.0)
    min_switch = streaming_r + SWITCH_DISTANCE_MIN_GAP
    max_switch = max(
        min_switch,
        unload_r - min(SWITCH_DISTANCE_OUTER_MARGIN, gap * 0.25),
    )

    resolved = []
    prev = min_switch - SWITCH_DISTANCE_MIN_GAP
    for idx, level in enumerate(sorted(levels, key=lambda l: l["switch_distance"])):
        sd = level["switch_distance"]
        remaining = len(levels) - idx - 1
        upper_bound = max_switch - (remaining * SWITCH_DISTANCE_MIN_GAP)
        if sd > 1.0:
            # Absolute metres — clamp directly to the valid window.
            candidate = clamp(sd, prev + SWITCH_DISTANCE_MIN_GAP, upper_bound)
        else:
            # Normalised 0–1 — existing lerp/ease path.
            t = clamp(sd, 0.0, 1.0)
            eased_t = 1.0 - math.pow(1.0 - t, HLOD_SWITCH_CURVE_EXPONENT)
            candidate = lerp(min_switch, max_switch, eased_t)
            candidate = clamp(candidate, prev + SWITCH_DISTANCE_MIN_GAP, upper_bound)
        resolved.append({
            "suffix": level["suffix"],
            "reduction_ratio": level["reduction_ratio"],
            "switch_distance": round(candidate, 2),
        })
        prev = candidate

    return resolved


def compute_lod_switch_distances(streaming_r, unload_r, hlod_levels, lod_levels):
    if not lod_levels:
        return []

    far_limit = unload_r - SWITCH_DISTANCE_OUTER_MARGIN
    if hlod_levels:
        far_limit = min(level["switch_distance"] for level in hlod_levels) - SWITCH_DISTANCE_MIN_GAP

    near_limit = max(
        streaming_r + SWITCH_DISTANCE_MIN_GAP,
        streaming_r * LOD_NEAR_BAND_START_FRACTION,
        SWITCH_DISTANCE_MIN_GAP,
    )
    required_span = SWITCH_DISTANCE_MIN_GAP * max(0, len(lod_levels) - 1)
    if far_limit < near_limit + required_span:
        near_limit = max(SWITCH_DISTANCE_MIN_GAP, far_limit - required_span)
    far_limit = max(far_limit, near_limit + required_span)

    resolved = []
    prev = near_limit - SWITCH_DISTANCE_MIN_GAP
    sorted_levels = sorted(lod_levels, key=lambda l: l["switch_distance"])
    for idx, level in enumerate(sorted_levels):
        sd = level["switch_distance"]
        remaining = len(sorted_levels) - idx - 1
        upper_bound = far_limit - (remaining * SWITCH_DISTANCE_MIN_GAP)
        if sd > 1.0:
            # Absolute metres — clamp directly.
            candidate = clamp(sd, prev + SWITCH_DISTANCE_MIN_GAP, upper_bound)
        else:
            # Normalised 0–1 — existing ease path.
            t = clamp(sd, 0.0, 1.0)
            eased_t = math.pow(t, LOD_SWITCH_CURVE_EXPONENT)
            candidate = lerp(near_limit, far_limit, eased_t)
            candidate = clamp(candidate, prev + SWITCH_DISTANCE_MIN_GAP, upper_bound)
        resolved.append({
            "ratio": level["ratio"],
            "switch_distance": round(candidate, 2),
        })
        prev = candidate

    return resolved


def resolve_tile_representation_levels(streaming_r, unload_r, hlod_level_configs, lod_level_configs):
    """Resolve normalized LOD/HLOD configs into world-space bands for one tile.

    Tile streaming radii can vary by semantic tier, so a single global
    representation ladder is not valid for all tiles.  Keep the invariant:

        streaming_radius < LOD... < HLOD < unload_radius

    with SWITCH_DISTANCE_MIN_GAP between adjacent representation bands.
    """
    tile_hlod_levels = compute_hlod_switch_distances(
        streaming_r,
        unload_r,
        hlod_level_configs,
    )
    tile_lod_levels = compute_lod_switch_distances(
        streaming_r,
        unload_r,
        tile_hlod_levels,
        lod_level_configs,
    )
    return tile_hlod_levels, tile_lod_levels


def distance_to_aabb(point, aabb):
    """Return closest-point distance from point to an AABB.

    The engine's GeometryStreamingSystem uses closest-point-on-AABB distance for
    tile streaming decisions. Keep Python preview/export diagnostics on the same
    contract so large tiles near the camera are not misclassified as far away
    just because their centers are distant.
    """
    px, py, pz = point
    mn = aabb["min"]
    mx = aabb["max"]
    closest_x = min(max(px, mn[0]), mx[0])
    closest_y = min(max(py, mn[1]), mx[1])
    closest_z = min(max(pz, mn[2]), mx[2])
    return math.sqrt(
        (px - closest_x) ** 2 +
        (py - closest_y) ** 2 +
        (pz - closest_z) ** 2
    )


def object_union_aabb(objects, object_bounds):
    """Return the Blender-space union AABB for a group of objects."""
    if not objects:
        return None
    return {
        "min": (
            min(object_bounds[o.name]["min"][0] for o in objects),
            min(object_bounds[o.name]["min"][1] for o in objects),
            min(object_bounds[o.name]["min"][2] for o in objects),
        ),
        "max": (
            max(object_bounds[o.name]["max"][0] for o in objects),
            max(object_bounds[o.name]["max"][1] for o in objects),
            max(object_bounds[o.name]["max"][2] for o in objects),
        ),
    }


def classify_runtime_representation(distance, unload_r, hlod_levels=None, lod_levels=None):
    """Classify the active runtime representation for a tile distance.

    This mirrors GeometryStreamingSystem's representation order:
      HLOD covers far-field tiles after the HLOD switch distance.
      LOD covers mid-field tiles after the first LOD switch distance.
      Full geometry covers the near band.
      Unloaded only applies when no secondary representation is active.

    Note: in the engine, a loaded HLOD is only evicted once the tile leaves
    GeometryStreamingSystem.maxQueryRadius (500m default) — far beyond
    unload_radius, which only governs full-geometry eviction. So HLOD/LOD
    take precedence over unload_radius here.
    """
    hlod_levels = hlod_levels or []
    lod_levels = lod_levels or []

    if hlod_levels and distance >= min(level["switch_distance"] for level in hlod_levels):
        return "hlod"

    if lod_levels and distance >= min(level["switch_distance"] for level in lod_levels):
        return "lod"

    if distance >= unload_r:
        return "unloaded"

    return "full"


def classify_runtime_representation_detail(distance, unload_r, hlod_levels=None, lod_levels=None):
    """Return full, lod1/lod2/..., hlod, or unloaded for preview diagnostics.

    See classify_runtime_representation for why HLOD/LOD take precedence over
    unload_radius.
    """
    hlod_levels = hlod_levels or []
    lod_levels = sorted(lod_levels or [], key=lambda l: l["switch_distance"])

    if hlod_levels and distance >= min(level["switch_distance"] for level in hlod_levels):
        return "hlod"

    active_lod_index = None
    for idx, level in enumerate(lod_levels):
        if distance >= level["switch_distance"]:
            active_lod_index = idx
    if active_lod_index is not None:
        return f"lod{active_lod_index + 1}"

    if distance >= unload_r:
        return "unloaded"

    return "full"


def get_candidate_objects():
    # Exclude objects in the "Tile Preview" collection — those are the wireframe
    # tile-bound boxes created by create_tile_preview() for visual debugging.
    # They are real MESH objects in the scene and would be misclassified as
    # scene geometry if included.  The collection is cleaned up inside
    # create_tile_preview() (called later), so we must filter them here
    # before they are removed.
    preview_col = bpy.data.collections.get("Tile Preview")
    preview_objects = set(preview_col.objects) if preview_col else set()

    objs = []
    view_layer = bpy.context.view_layer
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if obj in preview_objects:
            continue
        if VISIBLE_ONLY:
            if obj.hide_viewport or obj.hide_get(view_layer=view_layer):
                continue
        # Tiled scenes are static-only; skip skinned meshes rather than
        # failing the whole export (see warn_skipped_animated_objects()).
        if _mesh_uses_armature(obj):
            continue
        objs.append(obj)
    return objs


def _is_visible_for_tiled_export(obj, view_layer):
    if not VISIBLE_ONLY:
        return True
    return not obj.hide_viewport and not obj.hide_get(view_layer=view_layer)


def _mesh_uses_armature(obj):
    if obj.type != "MESH":
        return False
    if getattr(obj, "parent", None) is not None and obj.parent.type == "ARMATURE":
        return True
    if hasattr(obj, "find_armature") and obj.find_armature() is not None:
        return True
    return any(getattr(mod, "type", None) == "ARMATURE" for mod in obj.modifiers)


def warn_skipped_animated_objects():
    """Tiled scenes are static-only. Armatures and any mesh they drive are
    excluded by get_candidate_objects(); this just reports what got skipped
    so a wind-animated tree or similar doesn't disappear from the export
    without a trace.
    """
    view_layer = bpy.context.view_layer
    armatures = []
    skinned_meshes = []
    for obj in bpy.context.scene.objects:
        if not _is_visible_for_tiled_export(obj, view_layer):
            continue
        if obj.type == "ARMATURE":
            armatures.append(obj.name)
        elif _mesh_uses_armature(obj):
            skinned_meshes.append(obj.name)

    if armatures or skinned_meshes:
        details = []
        if armatures:
            details.append(f"armatures: {', '.join(sorted(armatures)[:8])}")
        if skinned_meshes:
            details.append(f"skinned meshes: {', '.join(sorted(skinned_meshes)[:8])}")
        print(
            "Warning: tiled scene export is static-only; skipping "
            + "; ".join(details),
            flush=True,
        )


# ============================================================
# SECTION 2: WORLD BOUNDS
# All world-space bound queries use the evaluated depsgraph so
# that parent-chain transforms (including the +90° X rotation
# Blender's USD importer adds for Y-up → Z-up conversion) are
# always reflected in the returned matrices and bounds.
# Using obj.matrix_world directly returns stale values for
# objects in complex hierarchies and causes entire categories of
# objects to appear at wrong world positions, producing incorrect
# tile assignments.
# ============================================================

def world_bbox_corners(obj, depsgraph=None):
    if depsgraph is None:
        depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mw = eval_obj.matrix_world
    return [mw @ Vector(corner) for corner in eval_obj.bound_box]


def world_aabb(obj, depsgraph=None):
    corners = world_bbox_corners(obj, depsgraph=depsgraph)
    return {
        "min": (min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)),
        "max": (max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)),
    }


def aabb_center(aabb):
    mn, mx = aabb["min"], aabb["max"]
    return (0.5 * (mn[0] + mx[0]), 0.5 * (mn[1] + mx[1]), 0.5 * (mn[2] + mx[2]))


def scene_world_bounds(objects):
    if not objects:
        return None
    mins = [math.inf, math.inf, math.inf]
    maxs = [-math.inf, -math.inf, -math.inf]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        aabb = world_aabb(obj, depsgraph=depsgraph)
        for i in range(3):
            mins[i] = min(mins[i], aabb["min"][i])
            maxs[i] = max(maxs[i], aabb["max"][i])
    return {"min": tuple(mins), "max": tuple(maxs)}


def compute_object_bounds(objects):
    """Return {name: aabb} for all objects, using a single evaluated depsgraph."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    return {obj.name: world_aabb(obj, depsgraph=depsgraph) for obj in objects}


def aabb_to_usd_space(aabb):
    """Convert a Blender-space AABB (X, Y_depth, Z_height) to USD space (X, Y_up, -Z).

    USD mapping:
      USD X =  Blender X
      USD Y =  Blender Z (height)
      USD Z = -Blender Y (depth)   ← sign flip; min/max swap accordingly
    """
    mn, mx = aabb["min"], aabb["max"]
    return {
        "min": (mn[0],  mn[2], -mx[1]),
        "max": (mx[0],  mx[2], -mn[1]),
    }


# ============================================================
# SECTION 3: TILE GEOMETRY
# Tile coordinate system:
#   Tile X  ← Blender X  (lateral)
#   Tile Y  ← Blender Z  (height — large bucket, usually ty=0 for everything)
#   Tile Z  ← Blender Y  (depth)
# ============================================================

def tile_coord_from_point(cx, cy, cz, origin_x, origin_y, origin_z,
                          tile_size_x, tile_size_y, tile_size_z):
    # cx, cy, cz are Blender X, Y(depth), Z(height).
    tx = int(math.floor((cx - origin_x) / tile_size_x))
    ty = int(math.floor((cz - origin_y) / tile_size_y))   # Blender Z = height → tile Y
    tz = int(math.floor((cy - origin_z) / tile_size_z))   # Blender Y = depth  → tile Z
    return tx, ty, tz


def overlapping_tile_coords(aabb, origin_x, origin_y, origin_z,
                            tile_size_x, tile_size_y, tile_size_z, tolerance):
    """Return all tile (tx, ty, tz) coordinates whose bounds overlap the AABB."""
    mn, mx = aabb["min"], aabb["max"]
    # Map Blender axes to tile axes.
    #
    # Use an inward tolerance instead of outward expansion so meshes that lie
    # exactly on the scene-min boundary do not spuriously overlap a negative
    # tile index.  This keeps assignment stable while still suppressing
    # boundary-only contact caused by floating-point noise.
    min_x  = mn[0] + tolerance;  max_x  = mx[0] - tolerance  # Blender X  → tile X
    min_ty = mn[2] + tolerance;  max_ty = mx[2] - tolerance  # Blender Z  → tile Y
    min_tz = mn[1] + tolerance;  max_tz = mx[1] - tolerance  # Blender Y  → tile Z

    if min_x > max_x:
        center_x = (mn[0] + mx[0]) * 0.5
        min_x = center_x
        max_x = center_x
    if min_ty > max_ty:
        center_ty = (mn[2] + mx[2]) * 0.5
        min_ty = center_ty
        max_ty = center_ty
    if min_tz > max_tz:
        center_tz = (mn[1] + mx[1]) * 0.5
        min_tz = center_tz
        max_tz = center_tz

    tx0 = int(math.floor((min_x  - origin_x) / tile_size_x))
    tx1 = int(math.floor((max_x  - origin_x) / tile_size_x))
    ty0 = int(math.floor((min_ty - origin_y) / tile_size_y))
    ty1 = int(math.floor((max_ty - origin_y) / tile_size_y))
    tz0 = int(math.floor((min_tz - origin_z) / tile_size_z))
    tz1 = int(math.floor((max_tz - origin_z) / tile_size_z))

    return [(tx, ty, tz)
            for tx in range(tx0, tx1 + 1)
            for ty in range(ty0, ty1 + 1)
            for tz in range(tz0, tz1 + 1)]


def xz_tile_overlap_count(aabb, origin_x, origin_z, tile_size_x, tile_size_z, tolerance):
    """Return the number of tiles overlapped in the XZ plane only.

    Classification uses XZ overlap count because the Y (height) dimension is
    inflated by TILE_SIZE_Y = 10000 — using 3D overlap count would undercount
    for small TILE_SIZE_Y values or overcount for very tall objects.
    """
    mn, mx = aabb["min"], aabb["max"]
    min_x  = mn[0] + tolerance;  max_x  = mx[0] - tolerance
    min_tz = mn[1] + tolerance;  max_tz = mx[1] - tolerance  # Blender Y → tile Z

    if min_x > max_x:
        center_x = (mn[0] + mx[0]) * 0.5
        min_x = center_x
        max_x = center_x
    if min_tz > max_tz:
        center_tz = (mn[1] + mx[1]) * 0.5
        min_tz = center_tz
        max_tz = center_tz

    tx0 = int(math.floor((min_x  - origin_x) / tile_size_x))
    tx1 = int(math.floor((max_x  - origin_x) / tile_size_x))
    tz0 = int(math.floor((min_tz - origin_z) / tile_size_z))
    tz1 = int(math.floor((max_tz - origin_z) / tile_size_z))

    return (tx1 - tx0 + 1) * (tz1 - tz0 + 1)


def tile_bounds_from_coord(tx, ty, tz, origin_x, origin_y, origin_z,
                           tile_size_x, tile_size_y, tile_size_z):
    """Return tile bounds in internal Blender-space axis naming.

    Keys use tile-space names (x/y/z) where:
      tile X  = Blender X    (min_x/max_x)
      tile Y  = Blender Z    (min_y/max_y) — height
      tile Z  = Blender Y    (min_z/max_z) — depth
    """
    min_x = origin_x + tx * tile_size_x
    min_y = origin_y + ty * tile_size_y
    min_z = origin_z + tz * tile_size_z
    return {
        "min_x": min_x, "max_x": min_x + tile_size_x,
        "min_y": min_y, "max_y": min_y + tile_size_y,
        "min_z": min_z, "max_z": min_z + tile_size_z,
    }


def tile_bounds_aabb_usd(tile_bounds):
    """Convert tile_bounds dict to a USD-space AABB dict suitable for the manifest."""
    return aabb_to_usd_space({
        "min": (tile_bounds["min_x"], tile_bounds["min_z"], tile_bounds["min_y"]),
        "max": (tile_bounds["max_x"], tile_bounds["max_z"], tile_bounds["max_y"]),
    })


def node_cell_bounds_aabb_usd(node_bounds_xy, objects, object_bounds):
    """Return a USD-space AABB from a tree node's XY cell and object Z extent."""
    if not node_bounds_xy or not objects:
        return None
    z_min = min(object_bounds[o.name]["min"][2] for o in objects)
    z_max = max(object_bounds[o.name]["max"][2] for o in objects)
    return aabb_to_usd_space({
        "min": (node_bounds_xy["min_x"], node_bounds_xy["min_y"], z_min),
        "max": (node_bounds_xy["max_x"], node_bounds_xy["max_y"], z_max),
    })


def compute_objects_aabb_usd(objects, object_bounds):
    """Compute the union AABB of a set of objects, returned in USD space.

    Used by the quadtree export path where tile bounds are derived from the
    objects themselves rather than from a uniform grid cell.
    """
    if not objects:
        return None
    min_x = min(object_bounds[o.name]["min"][0] for o in objects)
    min_y = min(object_bounds[o.name]["min"][1] for o in objects)
    min_z = min(object_bounds[o.name]["min"][2] for o in objects)
    max_x = max(object_bounds[o.name]["max"][0] for o in objects)
    max_y = max(object_bounds[o.name]["max"][1] for o in objects)
    max_z = max(object_bounds[o.name]["max"][2] for o in objects)
    return aabb_to_usd_space({
        "min": (min_x, min_y, min_z),
        "max": (max_x, max_y, max_z),
    })


# ============================================================
# SECTION 4: CLASSIFICATION
# Each mesh object receives exactly one export_policy:
#
#   local_overlap         — AABB fits within SPANNING_THRESHOLD_TILES × tile_size
#                           AND XZ overlap <= OVERLAP_THRESHOLD.
#                           Exported per-tile with bmesh clipping.
#
#   shared_bucket         — Exceeds one or both spanning thresholds.
#                           Exported once to a shared USD, loaded at large radius.
#
#   future_split_candidate — Also spanning, but dimension ratio is extreme
#                           (> FUTURE_SPLIT_TILE_THRESHOLD).  Exported to shared
#                           bucket for now; marked for future splitting pass.
#
# The classification is explicit and logged in the manifest so you can audit
# decisions without re-running the script.
# ============================================================

def classify_mesh(aabb, tile_size_x, tile_size_z, xz_overlap_count, overlap_threshold):
    """Classify a mesh given its world AABB and XZ tile overlap count.

    Args:
      overlap_threshold: effective XZ-tile overlap limit (use _effective_overlap_threshold()).

    Returns a dict with:
      policy          : "local_overlap" | "shared_bucket" | "future_split_candidate"
      xz_overlap_count: int
      dimensions      : [width_x, depth_y, height_z]  (Blender units, rounded)
      dim_ratio       : max(width, depth) / max(tile_x, tile_z)
      reasons         : list of classification reason strings
    """
    mn, mx = aabb["min"], aabb["max"]
    width  = mx[0] - mn[0]   # Blender X
    depth  = mx[1] - mn[1]   # Blender Y (ground-plane depth)
    height = mx[2] - mn[2]   # Blender Z (height)

    base_tile  = max(tile_size_x, tile_size_z, 1e-9)
    ratio_w    = width  / base_tile
    ratio_d    = depth  / base_tile
    dim_ratio  = max(ratio_w, ratio_d)

    reasons = []
    if ratio_w > SPANNING_THRESHOLD_TILES:
        reasons.append("width_threshold")
    if ratio_d > SPANNING_THRESHOLD_TILES:
        reasons.append("depth_threshold")
    if xz_overlap_count > overlap_threshold:
        reasons.append("overlap_threshold")

    is_spanning = bool(reasons)

    if not is_spanning:
        policy = "local_overlap"
    elif dim_ratio > FUTURE_SPLIT_TILE_THRESHOLD:
        policy = "future_split_candidate"
    else:
        policy = "shared_bucket"

    return {
        "policy":           policy,
        "xz_overlap_count": xz_overlap_count,
        "dimensions":       [round(width, 3), round(depth, 3), round(height, 3)],
        "dim_ratio":        round(dim_ratio, 2),
        "reasons":          reasons,
    }


# ============================================================
# SECTION 4.5: QUADTREE METADATA
# Functions for reading per-object metadata written by the Untold phase-1+2
# Blender preprocessing script (untold_phase12_suffix-Blender.py).
#
# Each annotated object carries:
#   Custom properties  — untold_quadtree_node_id, untold_semantic_guess, etc.
#   Name suffix        — __UT_<node>_<spatial>_<semantic>  (always present)
#
# The exporter prefers custom properties; the name suffix is the fallback
# because it survives USD export/import even when custom properties are lost.
# ============================================================

def _tier_reverse_map():
    return {v: k for k, v in TIER_SHORT_CODES.items()}


def _obj_prop(obj, key, default=None):
    """Get a custom property by bare key or with the 'userProperties:' USD namespace prefix."""
    if key in obj:
        return obj[key]
    usd_key = "userProperties:" + key
    if usd_key in obj:
        return obj[usd_key]
    return default


def _semantic_override(obj):
    value = _obj_prop(obj, "untold_semantic_override")
    if value is None:
        return None
    value = str(value)
    if value in ("", "Auto"):
        return None
    if value not in VALID_SEMANTIC_TIERS:
        print(f"  Warning: {obj.name} has unsupported untold_semantic_override={value!r}; using inferred tier.")
        return None
    return value


def _untagged_semantic_default():
    return UNTAGGED_SEMANTIC_TIER if UNTAGGED_SEMANTIC_TIER in VALID_SEMANTIC_TIERS else None


def object_priority_hint(obj):
    value = _obj_prop(obj, "untold_streaming_priority_hint")
    if value is None:
        return None
    value = str(value)
    if value in ("", "Auto"):
        return None
    priority = OBJECT_PRIORITY_HINTS.get(value)
    if priority is None:
        print(f"  Warning: {obj.name} has unsupported untold_streaming_priority_hint={value!r}; using tier default.")
    return priority


def aggregate_priority_hint(objects, default_priority):
    priorities = [object_priority_hint(obj) for obj in objects]
    priorities = [p for p in priorities if p is not None]
    if not priorities:
        return default_priority
    return max(default_priority, max(priorities))


def read_untold_metadata(obj):
    """Read quadtree/semantic metadata from a Blender object.

    Tries custom properties first (bare keys and USD-namespaced
    'userProperties:' keys written by Blender's USD importer), then falls
    back to parsing the name suffix and finally the Xform prim name stored
    in 'userProperties:blender:object_name'.
    Returns a dict or None if no source yields valid metadata.
    """
    # --- Primary: Blender custom properties (bare or USD-namespaced) ---
    override = _semantic_override(obj)
    untagged_default = _untagged_semantic_default()
    node_id = _obj_prop(obj, "untold_quadtree_node_id")
    if node_id is not None:
        semantic = override or untagged_default or str(_obj_prop(obj, "untold_semantic_guess", DEFAULT_SEMANTIC_TIER))
        return {
            "floor_id":      int(_obj_prop(obj, "untold_floor_id", 0)),
            "node_id":       str(node_id),
            "depth":         int(_obj_prop(obj, "untold_quadtree_depth", 0)),
            "spatial_class": str(_obj_prop(obj, "untold_spatial_class", "local")),
            "semantic":      semantic,
            "confidence":    1.0 if (override or untagged_default) else float(_obj_prop(obj, "untold_semantic_confidence", 0.0)),
            "source":        "custom_property_override" if override else ("custom_property_untagged_default" if untagged_default else "custom_property"),
        }
    # --- Secondary: parse suffix from the Xform prim name stored by Blender's USD importer ---
    xform_name = _obj_prop(obj, "blender:object_name")
    if xform_name:
        meta = _parse_name_suffix(str(xform_name))
        if meta:
            if override:
                meta["semantic"] = override
                meta["confidence"] = 1.0
                meta["source"] = "name_suffix_override"
            elif untagged_default:
                meta["semantic"] = untagged_default
                meta["confidence"] = 1.0
                meta["source"] = "name_suffix_untagged_default"
            return meta
    # --- Fallback: name suffix on the Blender object name itself ---
    meta = _parse_name_suffix(obj.name)
    if meta and override:
        meta["semantic"] = override
        meta["confidence"] = 1.0
        meta["source"] = "name_suffix_override"
    elif meta and untagged_default:
        meta["semantic"] = untagged_default
        meta["confidence"] = 1.0
        meta["source"] = "name_suffix_untagged_default"
    return meta


def _parse_name_suffix(name):
    """Parse the __UT_<node>_<spatial>_<semantic> suffix embedded in an object name.

    Example:
      SM_Env_Ceiling_Stone_01__UT_F02Q100_L_SI
      → floor_id=2, node_id="F02Q100", spatial_class="local", semantic="StructuralInterior"

    Returns a dict or None if no valid suffix is found.
    """
    marker = "__UT_"
    idx = name.find(marker)
    if idx < 0:
        return None
    suffix = name[idx + len(marker):]
    parts  = suffix.split("_")
    # Minimum: [node_compressed, spatial_code, semantic_code]
    if len(parts) < 3:
        return None

    node_compressed = parts[0]
    spatial_code    = parts[1]
    semantic_code   = parts[2]

    spatial_class = "local" if spatial_code == "L" else "spanning"
    semantic      = _tier_reverse_map().get(semantic_code, DEFAULT_SEMANTIC_TIER)

    # Parse floor index from compressed node id: F02Q100 → floor_id=2
    floor_id = 0
    if node_compressed.startswith("F") and "Q" in node_compressed:
        q_pos = node_compressed.index("Q")
        try:
            floor_id = int(node_compressed[1:q_pos])
        except ValueError:
            pass

    return {
        "floor_id":      floor_id,
        "node_id":       node_compressed,
        "depth":         -1,   # not recoverable from suffix alone
        "spatial_class": spatial_class,
        "semantic":      semantic,
        # Suffix is explicit author intent; assign reliable confidence.
        "confidence":    0.75,
        "source":        "name_suffix",
    }


def _resolve_tier(meta):
    """Return the effective semantic tier, applying the confidence fallback."""
    if meta is None:
        return DEFAULT_SEMANTIC_TIER
    if meta["confidence"] < TIER_CONFIDENCE_THRESHOLD:
        return DEFAULT_SEMANTIC_TIER
    return meta["semantic"]


def has_quadtree_metadata(objects):
    """Return True when enough objects carry Untold metadata to use the quadtree path."""
    if not objects:
        return False
    annotated = sum(1 for obj in objects if read_untold_metadata(obj) is not None)
    return (annotated / len(objects)) >= QUADTREE_METADATA_COVERAGE_THRESHOLD


def build_quadtree_assignments(objects, object_bounds, inline_metadata=None):
    """Group objects by (quadtree_node_id, semantic_tier).

    Metadata priority (highest → lowest):
      1. Pre-baked metadata from read_untold_metadata() — custom properties or
         name suffix written by the external annotation script.
      2. inline_metadata dict — produced by compute_inline_quadtree_metadata()
         when --quadtree is used without pre-annotated input.

    Objects that are root-spanning (depth == 0, spatial_class == "spanning")
    or carry no metadata go to shared_objects.  All others land in
    node_tier_groups keyed by (node_id, tier).

    Returns:
        node_tier_groups : {(node_id, tier): [obj, ...]}
        shared_objects   : [obj, ...]
        metadata_map     : {obj.name: meta_dict or None}
    """
    node_tier_groups = {}
    shared_objects   = []
    metadata_map     = {}

    for obj in objects:
        # Try pre-baked metadata first, then inline fallback.
        meta = read_untold_metadata(obj)
        if meta is None and inline_metadata:
            meta = inline_metadata.get(obj.name)
        metadata_map[obj.name] = meta

        if meta is None:
            shared_objects.append(obj)
            continue

        # Root-spanning objects (depth == 0, spanning) span the full XZ footprint
        # of their floor's quadtree root and cannot be assigned to a single node.
        #
        # Split by semantic tier:
        # - ExteriorShell: genuinely building-wide geometry (facades, shells, roofs).
        #   These belong in the global shared bucket — they have no per-floor
        #   affinity and must be resident whenever the building is visible.
        # - Interior tiers (SI, RC, FP): floor-spanning ceilings, corridor railings,
        #   merged prop groups, etc.  Routing these to the global shared bucket makes
        #   them always-resident, inflating shared bucket memory by 10–20× relative
        #   to their actual floor-level streaming need.  Instead, assign them to a
        #   per-floor root tile (node_id = floor root, same tier) so they load and
        #   unload with the floor's streaming radii and interior-zone gate.
        if meta["spatial_class"] == "spanning" and meta["depth"] == 0:
            tier = _resolve_tier(meta)
            force_local = (_obj_prop(obj, "untold_tile_policy") == "force_local")
            if tier == "ExteriorShell" and not force_local:
                shared_objects.append(obj)
            else:
                # Use the node_id already stored in metadata — it is the floor root
                # whether the annotation pass used quadtree ("F02_Q") or KD-tree ("F02_K").
                floor_root_node = meta["node_id"]
                floor_root_key  = (floor_root_node, tier)
                node_tier_groups.setdefault(floor_root_key, []).append(obj)
            continue

        tier = _resolve_tier(meta)
        key  = (meta["node_id"], tier)
        node_tier_groups.setdefault(key, []).append(obj)

    return node_tier_groups, shared_objects, metadata_map


def quadtree_tile_id(node_id, tier):
    """Return a stable, filesystem-safe tile ID for a (node_id, tier) pair.

    Example: node_id="F02Q100", tier="StructuralInterior" → "F02Q100_SI"
    """
    code = TIER_SHORT_CODES.get(tier, "UK")
    return sanitize_name(f"{node_id}_{code}")


def group_metadata(tile_objs, metadata_map):
    return [metadata_map.get(obj.name) for obj in tile_objs if metadata_map.get(obj.name) is not None]


def group_has_spanning_metadata(tile_objs, metadata_map):
    return any(meta.get("spatial_class") == "spanning" for meta in group_metadata(tile_objs, metadata_map))


def group_cell_bounds_xy(tile_objs, metadata_map):
    if group_has_spanning_metadata(tile_objs, metadata_map):
        return None
    for meta in group_metadata(tile_objs, metadata_map):
        cell = meta.get("cell_bounds_xy")
        if cell:
            return cell
    return None


# ============================================================
# SECTION 4.6: INLINE QUADTREE ANNOTATION
# Reproduces the logic from untold_phase12_suffix-Blender.py entirely inside
# the exporter so that unannotated USD/USDZ files can be partitioned in one
# step without a separate Blender preprocessing pass.
# ============================================================

class _QuadNode:
    """Axis-aligned quadtree node over the XY (Blender XY) plane."""
    __slots__ = ("min_x", "min_y", "max_x", "max_y", "depth", "node_id", "children")

    def __init__(self, min_x, min_y, max_x, max_y, depth, node_id):
        self.min_x   = min_x
        self.min_y   = min_y
        self.max_x   = max_x
        self.max_y   = max_y
        self.depth   = depth
        self.node_id = node_id
        self.children = []

    def bounds(self):
        return (self.min_x, self.min_y, self.max_x, self.max_y)

    def subdivide(self):
        mx = (self.min_x + self.max_x) * 0.5
        my = (self.min_y + self.max_y) * 0.5
        d  = self.depth + 1
        self.children = [
            _QuadNode(self.min_x, self.min_y, mx,           my,           d, f"{self.node_id}_0"),
            _QuadNode(mx,         self.min_y, self.max_x,   my,           d, f"{self.node_id}_1"),
            _QuadNode(self.min_x, my,         mx,           self.max_y,   d, f"{self.node_id}_2"),
            _QuadNode(mx,         my,         self.max_x,   self.max_y,   d, f"{self.node_id}_3"),
        ]


def _qt_rect_intersects(a, b):
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    return not (ax1 < bx0 or ax0 > bx1 or ay1 < by0 or ay0 > by1)


def _qt_child_overlap_count(node, rect):
    if not node.children:
        return 1
    return sum(1 for c in node.children if _qt_rect_intersects(c.bounds(), rect))


def _qt_descend(node, rect, max_depth):
    """Return (best_node, overlap_count) for rect in the quadtree."""
    if node.depth >= max_depth:
        return node, _qt_child_overlap_count(node, rect)
    if not node.children:
        node.subdivide()
    overlapping = [c for c in node.children if _qt_rect_intersects(c.bounds(), rect)]
    if len(overlapping) != 1:
        return node, len(overlapping)
    return _qt_descend(overlapping[0], rect, max_depth)


def _partition_parent_node_id(node_id):
    if "_" not in node_id:
        return None
    parent = node_id.rsplit("_", 1)[0]
    if parent == node_id:
        return None
    return parent


def _qt_find_or_create_node(root, node_id):
    if root.node_id == node_id:
        return root
    suffix = node_id[len(root.node_id):]
    if not suffix.startswith("_"):
        return None
    node = root
    for part in suffix[1:].split("_"):
        if not part:
            continue
        try:
            child_index = int(part)
        except ValueError:
            return None
        if child_index < 0 or child_index > 3:
            return None
        if not node.children:
            node.subdivide()
        node = node.children[child_index]
    return node


def _update_meta_node(meta, node, source_suffix):
    meta["node_id"] = node.node_id
    meta["depth"] = node.depth
    meta["cell_bounds_xy"] = {
        "min_x": node.min_x,
        "min_y": node.min_y,
        "max_x": node.max_x,
        "max_y": node.max_y,
    }
    source = str(meta.get("source", ""))
    if source_suffix not in source:
        meta["source"] = f"{source}{source_suffix}" if source else source_suffix.lstrip("_")


def _print_tile_tier_quality(label, metadata_dict):
    groups = {}
    depth_hist = {}
    for meta in metadata_dict.values():
        key = (meta.get("node_id"), meta.get("semantic"))
        groups[key] = groups.get(key, 0) + 1
        depth = int(meta.get("depth", 0))
        depth_hist[depth] = depth_hist.get(depth, 0) + 1

    if not groups:
        return

    counts = sorted(groups.values())
    total_groups = len(counts)
    singleton_groups = sum(1 for c in counts if c == 1)
    under_min_groups = sum(1 for c in counts if c < INLINE_MIN_OBJECTS_PER_TILE_TIER)

    def percentile(sorted_values, p):
        if not sorted_values:
            return 0
        idx = int(math.ceil((p / 100.0) * len(sorted_values))) - 1
        idx = max(0, min(idx, len(sorted_values) - 1))
        return sorted_values[idx]

    print(f"  [{label}] tile-tier quality:")
    print(
        f"    groups={total_groups}  singleton={singleton_groups}  "
        f"under_min<{INLINE_MIN_OBJECTS_PER_TILE_TIER}={under_min_groups}"
    )
    print(
        f"    objects/group min={counts[0]}  p50={percentile(counts, 50)}  "
        f"p95={percentile(counts, 95)}  max={counts[-1]}  "
        f"avg={sum(counts) / len(counts):.1f}"
    )
    depth_parts = [f"d{depth}:{count}" for depth, count in sorted(depth_hist.items())]
    print(f"    object depth histogram: {' '.join(depth_parts)}")


def print_node_tier_group_quality(label, node_tier_groups):
    if not node_tier_groups:
        return
    counts = sorted(len(objs) for objs in node_tier_groups.values())
    if not counts:
        return
    singleton_groups = sum(1 for c in counts if c == 1)
    under_min_groups = sum(1 for c in counts if c < INLINE_MIN_OBJECTS_PER_TILE_TIER)
    by_tier = {}
    by_depth = {}
    for (node_id, tier), objs in node_tier_groups.items():
        by_tier[tier] = by_tier.get(tier, 0) + 1
        depth = max(0, node_id.count("_") - 1)
        by_depth[depth] = by_depth.get(depth, 0) + 1

    def percentile(sorted_values, p):
        idx = int(math.ceil((p / 100.0) * len(sorted_values))) - 1
        idx = max(0, min(idx, len(sorted_values) - 1))
        return sorted_values[idx]

    print(f"\n  {label} tile-tier quality:")
    print(
        f"    groups={len(counts)}  singleton={singleton_groups}  "
        f"under_min<{INLINE_MIN_OBJECTS_PER_TILE_TIER}={under_min_groups}"
    )
    print(
        f"    objects/group min={counts[0]}  p50={percentile(counts, 50)}  "
        f"p95={percentile(counts, 95)}  max={counts[-1]}  "
        f"avg={sum(counts) / len(counts):.1f}"
    )
    tier_parts = [f"{tier}:{count}" for tier, count in sorted(by_tier.items())]
    depth_parts = [f"d{depth}:{count}" for depth, count in sorted(by_depth.items())]
    print(f"    groups by tier : {' '.join(tier_parts)}")
    print(f"    groups by depth: {' '.join(depth_parts)}")


def _collapse_underfilled_tile_tiers(metadata_dict, root_for_floor, find_node, label):
    if not INLINE_COLLAPSE_UNDERFILLED_TILE_TIERS or INLINE_MIN_OBJECTS_PER_TILE_TIER <= 1:
        _print_tile_tier_quality(label, metadata_dict)
        return

    groups = {}
    for obj_name, meta in metadata_dict.items():
        key = (meta.get("node_id"), meta.get("semantic"))
        groups.setdefault(key, set()).add(obj_name)

    moved = 0
    changed = True
    while changed:
        changed = False
        for obj_name in sorted(metadata_dict.keys()):
            meta = metadata_dict[obj_name]
            if meta.get("spatial_class") != "local":
                continue
            node_id = meta.get("node_id")
            tier = meta.get("semantic")
            key = (node_id, tier)
            if len(groups.get(key, ())) >= INLINE_MIN_OBJECTS_PER_TILE_TIER:
                continue

            parent_id = _partition_parent_node_id(node_id)
            if parent_id is None:
                continue

            root = root_for_floor(meta.get("floor_id"))
            parent = find_node(root, parent_id) if root is not None else None
            if parent is None:
                continue

            groups[key].discard(obj_name)
            if not groups[key]:
                groups.pop(key, None)
            parent_key = (parent.node_id, tier)
            groups.setdefault(parent_key, set()).add(obj_name)
            _update_meta_node(meta, parent, "_collapsed")
            moved += 1
            changed = True

    if moved:
        print(
            f"  [{label}] collapsed {moved} object assignment(s) from underfilled "
            f"tile-tier groups (<{INLINE_MIN_OBJECTS_PER_TILE_TIER} objects)"
        )
    _print_tile_tier_quality(label, metadata_dict)


# ============================================================
# SECTION 4.65: KD-TREE SPATIAL PARTITIONING
# Alternative to the quadtree: at each node, splits on the
# longer spatial axis at the median of object centers.
# Produces more balanced tiles than the quadtree in scenes
# where objects cluster in one region of the floor.
#
# Node IDs use the same underscore scheme as the quadtree
# ("F02_K_0_1_0") so the engine's prefix-based hierarchy
# gate works without modification.
# ============================================================

class _KDNode:
    """Axis-aligned KD-tree node over the XY (Blender XY) plane."""
    __slots__ = ("min_x", "min_y", "max_x", "max_y", "depth", "node_id",
                 "split_axis", "split_pos", "left", "right")

    def __init__(self, min_x, min_y, max_x, max_y, depth, node_id):
        self.min_x      = min_x
        self.min_y      = min_y
        self.max_x      = max_x
        self.max_y      = max_y
        self.depth      = depth
        self.node_id    = node_id
        self.split_axis = None   # 0=X  1=Y  None=leaf
        self.split_pos  = None
        self.left       = None   # objects with center[axis] <= split_pos
        self.right      = None   # objects with center[axis] >  split_pos


def _kd_build(entries, min_x, min_y, max_x, max_y, depth, node_id, max_depth, min_leaf):
    """Build a KD-tree top-down from a list of object-center entries.

    Splits on the longer spatial axis at the median object center so the
    resulting tiles reflect actual geometry density rather than equal-area
    subdivisions.

    Args:
        entries   : list of dicts, each with a "center" key (x, y, z)
        min/max_x/y : spatial bounds of this node in Blender XY
        depth     : current recursion depth
        node_id   : string prefix for child IDs ("F02_K", "F02_K_0", …)
        max_depth : deepest allowed level
        min_leaf  : stop subdividing when len(entries) <= this value

    Returns a _KDNode with left/right populated if not a leaf.
    """
    node = _KDNode(min_x, min_y, max_x, max_y, depth, node_id)

    if depth >= max_depth or len(entries) <= min_leaf:
        return node

    # Split on the longer axis so tiles stay roughly square.
    x_span = max_x - min_x
    y_span = max_y - min_y
    axis   = 0 if x_span >= y_span else 1

    sorted_entries = sorted(entries, key=lambda e: e["center"][axis])
    mid            = len(sorted_entries) // 2
    split_pos      = sorted_entries[mid]["center"][axis]

    left_entries  = [e for e in sorted_entries if e["center"][axis] <= split_pos]
    right_entries = [e for e in sorted_entries if e["center"][axis] >  split_pos]

    # Guard: all centers identical on this axis — declare leaf to avoid
    # infinite recursion.
    if not left_entries or not right_entries:
        return node

    node.split_axis = axis
    node.split_pos  = split_pos

    if axis == 0:
        node.left  = _kd_build(left_entries,  min_x,     min_y, split_pos, max_y,
                                depth + 1, f"{node_id}_0", max_depth, min_leaf)
        node.right = _kd_build(right_entries, split_pos, min_y, max_x,     max_y,
                                depth + 1, f"{node_id}_1", max_depth, min_leaf)
    else:
        node.left  = _kd_build(left_entries,  min_x, min_y,     max_x, split_pos,
                                depth + 1, f"{node_id}_0", max_depth, min_leaf)
        node.right = _kd_build(right_entries, min_x, split_pos, max_x, max_y,
                                depth + 1, f"{node_id}_1", max_depth, min_leaf)

    return node


def _kd_assign(node, cx, cy):
    """Descend the pre-built KD-tree and return the leaf node for point (cx, cy)."""
    if node.split_axis is None:   # leaf
        return node
    if node.split_axis == 0:
        child = node.left if cx <= node.split_pos else node.right
    else:
        child = node.left if cy <= node.split_pos else node.right
    return _kd_assign(child, cx, cy)


def _kd_assign_rect(node, rect_min_x, rect_min_y, rect_max_x, rect_max_y, cx, cy):
    """Assign an AABB rect to a KD node, detecting spanning objects.

    Returns (node, spatial_class) where spatial_class is "local" or "spanning".

    An object is "spanning" at the current level when its AABB crosses the node's
    split plane — it belongs to both children and cannot be cleanly routed to one.
    At depth 0 this mirrors the quadtree path's spanning → shared-bucket routing.
    At deeper levels the object lands in the intermediate node's tile, which has a
    wider spatial coverage and handles the extra geometry naturally.
    """
    if node.split_axis is None:   # leaf — fully fits here
        return node, "local"

    if node.split_axis == 0:
        crosses = rect_min_x < node.split_pos < rect_max_x
        child   = node.left if cx <= node.split_pos else node.right
    else:
        crosses = rect_min_y < node.split_pos < rect_max_y
        child   = node.left if cy <= node.split_pos else node.right

    if crosses:
        return node, "spanning"

    return _kd_assign_rect(child, rect_min_x, rect_min_y, rect_max_x, rect_max_y, cx, cy)


def _kd_collect_nodes(node, out):
    if node is None:
        return
    out[node.node_id] = node
    _kd_collect_nodes(node.left, out)
    _kd_collect_nodes(node.right, out)


def compute_inline_kdtree_metadata(objects, object_bounds):
    """Run floor + KD-tree + semantic annotation inline on imported objects.

    Builds one KD-tree per floor from all of that floor's object centers,
    then assigns each object to the deepest node whose region contains its
    center.  Compared to the quadtree, this places split planes where
    objects actually are, producing more balanced tiles in clustered scenes.

    Returns:
        metadata_dict : {obj.name: meta_dict}  — same schema as read_untold_metadata()
    """
    import math as _math

    if not objects:
        return {}

    # --- Pass 1: build object cache ---
    object_cache = []
    global_min   = [float("inf")]  * 3
    global_max   = [float("-inf")] * 3

    for obj in objects:
        bounds = object_bounds.get(obj.name)
        if bounds is None:
            continue
        mn     = bounds["min"]
        mx     = bounds["max"]
        dims   = (mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2])
        center = ((mn[0] + mx[0]) * 0.5,
                  (mn[1] + mx[1]) * 0.5,
                  (mn[2] + mx[2]) * 0.5)
        for i in range(3):
            global_min[i] = min(global_min[i], mn[i])
            global_max[i] = max(global_max[i], mx[i])
        object_cache.append({"obj": obj, "mn": mn, "mx": mx,
                              "dims": dims, "center": center})

    if not object_cache:
        return {}

    # --- Resolve floor count and band height (identical logic to quadtree path) ---
    scene_min_z  = global_min[2]
    scene_max_z  = global_max[2]
    scene_z_span = max(scene_max_z - scene_min_z, 0.001)

    floor_count, band_height = _resolve_inline_floor_layout(object_cache, scene_z_span)

    print(f"  [inline kd-tree] floor band height: {band_height:.2f}m, floors: {floor_count}")

    # --- Group objects by floor ---
    floor_entries = {fid: [] for fid in range(floor_count)}
    for entry in object_cache:
        fid = _inline_assign_floor_id(entry["center"][2], scene_min_z, band_height)
        fid = max(0, min(fid, floor_count - 1))
        entry["floor_id"] = fid
        floor_entries[fid].append(entry)

    # --- Build one KD-tree per floor from that floor's object centers ---
    floor_roots = {}
    for fid, entries in floor_entries.items():
        root_id = f"F{fid + 1:02d}_K"
        floor_roots[fid] = _kd_build(
            entries,
            global_min[0], global_min[1],
            global_max[0], global_max[1],
            depth=0, node_id=root_id,
            max_depth=INLINE_KDTREE_MAX_DEPTH,
            min_leaf=INLINE_KDTREE_MIN_LEAF,
        )
    floor_node_maps = {}
    for fid, root in floor_roots.items():
        node_map = {}
        _kd_collect_nodes(root, node_map)
        floor_node_maps[fid + 1] = node_map

    # --- Pass 2: assign each object to its KD-tree node + semantic tier ---
    # Spanning detection: if an object's AABB crosses a KD split plane, it is
    # assigned to the node at that level (not a deeper leaf).  At depth=0 this
    # mirrors the quadtree's shared-bucket / floor-root routing in
    # build_quadtree_assignments; at deeper depths the object lands in the
    # intermediate tile whose spatial coverage is wide enough to hold it.
    metadata_dict = {}
    leaf_object_counts = {}   # node_id → object count (for heavy-leaf diagnostics)

    for entry in object_cache:
        obj    = entry["obj"]
        mn     = entry["mn"]
        mx     = entry["mx"]
        dims   = entry["dims"]
        center = entry["center"]
        fid    = entry["floor_id"]

        node, spatial_class = _kd_assign_rect(
            floor_roots[fid],
            mn[0], mn[1], mx[0], mx[1],
            center[0], center[1],
        )

        volume    = max(dims[0], 0.0) * max(dims[1], 0.0) * max(dims[2], 0.0)
        materials = _inline_get_material_names(obj)
        semantic, confidence = _inline_semantic_guess(obj.name, materials, dims, volume)
        override = _semantic_override(obj)
        if override:
            semantic, confidence = override, 1.0
        elif _untagged_semantic_default():
            semantic, confidence = _untagged_semantic_default(), 1.0

        metadata_dict[obj.name] = {
            "floor_id":      fid + 1,
            "node_id":       node.node_id,
            "depth":         node.depth,
            "cell_bounds_xy": {
                "min_x": node.min_x,
                "min_y": node.min_y,
                "max_x": node.max_x,
                "max_y": node.max_y,
            },
            "spatial_class": spatial_class,
            "semantic":      semantic,
            "confidence":    confidence,
            "source":        "inline_kdtree_override" if override else ("inline_kdtree_untagged_default" if _untagged_semantic_default() else "inline_kdtree"),
        }
        leaf_object_counts[node.node_id] = leaf_object_counts.get(node.node_id, 0) + 1

    annotated   = len(metadata_dict)
    span_count  = sum(1 for m in metadata_dict.values() if m["spatial_class"] == "spanning")
    print(f"  [inline kd-tree] annotated {annotated}/{len(objects)} objects "
          f"({span_count} spanning → shared/floor-root routing)")

    _collapse_underfilled_tile_tiers(
        metadata_dict,
        lambda floor_id: floor_roots.get(int(floor_id) - 1) if floor_id else None,
        lambda root, node_id: floor_node_maps.get(int(root.node_id[1:3]), {}).get(node_id) if root is not None else None,
        "inline kd-tree",
    )

    # --- Heavy-leaf diagnostics ---
    if leaf_object_counts:
        max_objs   = max(leaf_object_counts.values())
        avg_objs   = sum(leaf_object_counts.values()) / len(leaf_object_counts)
        top_leaves = sorted(leaf_object_counts.items(), key=lambda x: -x[1])[:5]
        print(f"  [inline kd-tree] leaves: {len(leaf_object_counts)}  "
              f"max_objects={max_objs}  avg_objects={avg_objs:.1f}")
        print(f"  [inline kd-tree] top-5 heaviest leaves (by object count):")
        for nid, cnt in top_leaves:
            print(f"    {nid}: {cnt} objects")

    return metadata_dict


def _inline_estimate_floor_band_height(object_cache):
    candidates = [e["dims"][2] for e in object_cache if 1.8 <= e["dims"][2] <= 5.0]
    if not candidates:
        return 3.5
    candidates.sort()
    mid = candidates[len(candidates) // 2]
    return max(INLINE_MIN_FLOOR_BAND_HEIGHT, min(INLINE_MAX_FLOOR_BAND_HEIGHT, mid))


def _inline_assign_floor_id(center_z, scene_min_z, band_height):
    import math as _math
    return int(_math.floor((center_z - scene_min_z) / max(band_height, 0.001)))


def _resolve_inline_floor_layout(object_cache, scene_z_span):
    """Resolve floor bands for inline tree annotation.

    Outdoor scenes usually represent one exterior ground-plane layer, even when
    buildings have large vertical extents. Auto floor slicing remains available
    for indoor/auto profiles and for explicit user overrides.
    """
    import math as _math

    if INLINE_FLOOR_COUNT_OVERRIDE and INLINE_FLOOR_BAND_HEIGHT_OVERRIDE:
        floor_count = max(1, int(INLINE_FLOOR_COUNT_OVERRIDE))
        band_height = float(INLINE_FLOOR_BAND_HEIGHT_OVERRIDE)
    elif INLINE_FLOOR_COUNT_OVERRIDE:
        floor_count = max(1, int(INLINE_FLOOR_COUNT_OVERRIDE))
        band_height = scene_z_span / floor_count
    elif INLINE_FLOOR_BAND_HEIGHT_OVERRIDE:
        band_height = float(INLINE_FLOOR_BAND_HEIGHT_OVERRIDE)
        floor_count = max(1, int(_math.ceil(scene_z_span / band_height)))
    elif (SCENE_STREAMING_PROFILE or "auto").lower() == "outdoor":
        floor_count = 1
        band_height = scene_z_span
    else:
        band_height = INLINE_AUTO_FLOOR_BAND_HEIGHT or _inline_estimate_floor_band_height(object_cache)
        floor_count = max(1, int(_math.ceil(scene_z_span / band_height)))

    return floor_count, max(float(band_height), 0.001)


def _inline_get_material_names(obj):
    out = []
    if obj.data and hasattr(obj.data, "materials"):
        for mat in obj.data.materials:
            if mat:
                out.append(mat.name)
    return out


def _inline_has_hint(text, hints):
    t = text.lower() if isinstance(text, str) else ""
    return any(h in t for h in hints)


def _inline_hint_count(text, hints):
    t = text.lower() if isinstance(text, str) else ""
    return sum(1 for h in hints if h in t)


def _inline_semantic_guess(name, materials, dims, volume):
    """Classify one object into a semantic tier. Mirrors semantic_guess() in the annotation script."""
    lname = name.lower() if isinstance(name, str) else ""
    joined_mats = " ".join((m.lower() if isinstance(m, str) else "") for m in materials)
    max_dim = max(dims[0], dims[1], dims[2])
    area_xy = max(dims[0], 0.0) * max(dims[1], 0.0)

    if _inline_has_hint(lname, INLINE_FINE_PROP_NAME_HINTS):
        return "FineProps", 0.90
    if _inline_has_hint(lname, INLINE_ROOM_CONTENT_NAME_HINTS):
        return "RoomContents", 0.80
    if _inline_has_hint(lname, INLINE_EXTERIOR_NAME_HINTS):
        return "ExteriorShell", 0.80
    if _inline_has_hint(lname, INLINE_STRUCTURAL_NAME_HINTS):
        return "StructuralInterior", 0.80

    ext_score  = _inline_hint_count(joined_mats, INLINE_EXTERIOR_MATERIAL_HINTS)
    room_score = _inline_hint_count(joined_mats, INLINE_ROOM_CONTENT_MATERIAL_HINTS)
    if ext_score > room_score and ext_score > 0:
        return "ExteriorShell", 0.65
    if room_score > ext_score and room_score > 0:
        return "RoomContents", 0.60

    if max_dim <= INLINE_FINE_PROP_MAX_DIM and volume <= INLINE_FINE_PROP_MAX_VOLUME:
        return "FineProps", 0.55
    if max_dim <= INLINE_ROOM_CONTENT_MAX_DIM and volume <= INLINE_ROOM_CONTENT_MAX_VOLUME:
        return "RoomContents", 0.45
    if max_dim >= INLINE_STRUCTURAL_MIN_DIM or area_xy >= INLINE_STRUCTURAL_MIN_AREA:
        return "StructuralInterior", 0.50

    return "StructuralInterior", 0.30


def compute_inline_quadtree_metadata(objects, object_bounds):
    """Run the full floor+quadtree+semantic annotation inline on imported objects.

    This is equivalent to running untold_phase12_suffix-Blender.py on the scene
    but happens inside the exporter process with no Blender UI or re-export needed.

    Returns:
        metadata_dict : {obj.name: meta_dict}  — same schema as read_untold_metadata()
    """
    import math as _math

    if not objects:
        return {}

    # --- Pass 1: build object cache with bounds ---
    object_cache = []
    global_min = [float("inf")] * 3
    global_max = [float("-inf")] * 3

    for obj in objects:
        bounds = object_bounds.get(obj.name)
        if bounds is None:
            continue
        mn = bounds["min"]   # (x, y, z) in Blender space
        mx = bounds["max"]
        dims = (mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2])
        center = ((mn[0] + mx[0]) * 0.5, (mn[1] + mx[1]) * 0.5, (mn[2] + mx[2]) * 0.5)
        for i in range(3):
            global_min[i] = min(global_min[i], mn[i])
            global_max[i] = max(global_max[i], mx[i])
        object_cache.append({"obj": obj, "mn": mn, "mx": mx, "dims": dims, "center": center})

    if not object_cache:
        return {}

    # --- Resolve floor count and band height ---
    # Priority: explicit overrides > auto-detection from object Z dimensions.
    scene_min_z  = global_min[2]
    scene_max_z  = global_max[2]
    scene_z_span = max(scene_max_z - scene_min_z, 0.001)

    floor_count, band_height = _resolve_inline_floor_layout(object_cache, scene_z_span)

    print(f"  [inline annotation] floor band height: {band_height:.2f}m, floors: {floor_count}")

    # --- Build one quadtree root per floor (XY plane, Blender coords) ---
    floor_roots = {
        fid: _QuadNode(global_min[0], global_min[1], global_max[0], global_max[1], 0, f"F{fid+1:02d}_Q")
        for fid in range(floor_count)
    }

    # --- Pass 2: assign each object to floor + quadtree node + semantic tier ---
    metadata_dict = {}
    for entry in object_cache:
        obj    = entry["obj"]
        mn     = entry["mn"]
        mx     = entry["mx"]
        dims   = entry["dims"]
        center = entry["center"]

        volume   = max(dims[0], 0.0) * max(dims[1], 0.0) * max(dims[2], 0.0)
        floor_id = _inline_assign_floor_id(center[2], scene_min_z, band_height)
        floor_id = max(0, min(floor_id, floor_count - 1))

        rect = (mn[0], mn[1], mx[0], mx[1])
        root = floor_roots[floor_id]
        node, overlap_count = _qt_descend(root, rect, INLINE_QUADTREE_MAX_DEPTH)

        spatial_class = "spanning" if overlap_count >= INLINE_SPANNING_CHILD_OVERLAP_THRESHOLD else "local"

        materials = _inline_get_material_names(obj)
        semantic, confidence = _inline_semantic_guess(obj.name, materials, dims, volume)
        override = _semantic_override(obj)
        if override:
            semantic, confidence = override, 1.0
        elif _untagged_semantic_default():
            semantic, confidence = _untagged_semantic_default(), 1.0

        metadata_dict[obj.name] = {
            "floor_id":      floor_id + 1,   # 1-based to match annotation script
            "node_id":       node.node_id,
            "depth":         node.depth,
            "cell_bounds_xy": {
                "min_x": node.min_x,
                "min_y": node.min_y,
                "max_x": node.max_x,
                "max_y": node.max_y,
            },
            "spatial_class": spatial_class,
            "semantic":      semantic,
            "confidence":    confidence,
            "source":        "inline_override" if override else ("inline_untagged_default" if _untagged_semantic_default() else "inline"),
        }

    annotated = len(metadata_dict)
    print(f"  [inline annotation] annotated {annotated}/{len(objects)} objects")
    _collapse_underfilled_tile_tiers(
        metadata_dict,
        lambda floor_id: floor_roots.get(int(floor_id) - 1) if floor_id else None,
        _qt_find_or_create_node,
        "inline quadtree",
    )
    return metadata_dict


# ============================================================
# SECTION 5: ASSIGNMENT
# ============================================================

def _intersect_aabb(a, b):
    """Return the AABB intersection of a and b, or None if they don't overlap.

    Used to clamp a spanning object's routing AABB to the local-geometry bounds
    so that tile assignments are only created where building geometry actually is.
    """
    mn = (max(a["min"][0], b["min"][0]),
          max(a["min"][1], b["min"][1]),
          max(a["min"][2], b["min"][2]))
    mx = (min(a["max"][0], b["max"][0]),
          min(a["max"][1], b["max"][1]),
          min(a["max"][2], b["max"][2]))
    if mn[0] >= mx[0] or mn[1] >= mx[1] or mn[2] >= mx[2]:
        return None
    return {"min": mn, "max": mx}


def build_assignments(objects, object_bounds, origin_x, origin_y, origin_z,
                      tile_size_x, tile_size_y, tile_size_z):
    """Classify all objects and partition them into tile assignments and shared bucket.

    Two-pass design:
      Pass 1 — classify every object; collect the bounding box of local-only geometry.
      Pass 2 — route objects to tiles, clamping spanning objects' routing AABB to
               the local-geometry bounds.  This prevents spanning objects from
               creating tiles in the empty space between the scene origin (which is
               set by the overall AABB including spanning meshes) and where the
               actual building geometry is.

    Returns:
      tile_assignments  : {(tx,ty,tz): [obj, ...]}
      shared_objects    : [obj, ...]           — spanning / future-split
      classification_map: {name: classify_result}
    """
    classification_map = {}
    eff_overlap_thr    = _effective_overlap_threshold()

    # --- Pass 1: classify ---
    for obj in objects:
        aabb     = object_bounds[obj.name]
        xz_count = xz_tile_overlap_count(
            aabb, origin_x, origin_z, tile_size_x, tile_size_z, SPLIT_CLIP_EPSILON
        )
        result = classify_mesh(aabb, tile_size_x, tile_size_z, xz_count, eff_overlap_thr)
        if (_obj_prop(obj, "untold_tile_policy") == "force_local"
                and result["policy"] in ("shared_bucket", "future_split_candidate")):
            result = dict(result)
            result["policy"] = "local_overlap"
        classification_map[obj.name] = result

    # Build the bounding box of local-only objects.  Spanning objects are
    # clamped to this box so their tile assignments stay within the populated
    # region of the scene rather than spreading across the empty margins
    # introduced by large-AABB spanning geometry.
    local_aabbs = [object_bounds[n] for n, r in classification_map.items()
                   if r["policy"] == "local_overlap"]
    if local_aabbs:
        local_bounds = {
            "min": (min(a["min"][0] for a in local_aabbs),
                    min(a["min"][1] for a in local_aabbs),
                    min(a["min"][2] for a in local_aabbs)),
            "max": (max(a["max"][0] for a in local_aabbs),
                    max(a["max"][1] for a in local_aabbs),
                    max(a["max"][2] for a in local_aabbs)),
        }
    else:
        local_bounds = None

    # --- Pass 2: route ---
    tile_assignments = {}
    shared_objects   = []

    for obj in objects:
        aabb   = object_bounds[obj.name]
        result = classification_map[obj.name]

        route_to_tiles = (
            result["policy"] == "local_overlap"
            or (
                SPLIT_SPANNING_OBJECTS
                and CLIP_LOCAL_MESHES
                and result["policy"] in ("shared_bucket", "future_split_candidate")
                and result["xz_overlap_count"] <= SPLIT_MAX_TILES
            )
        )

        if route_to_tiles:
            # Clamp spanning objects to local-geometry bounds.
            if result["policy"] != "local_overlap" and local_bounds is not None:
                routing_aabb = _intersect_aabb(aabb, local_bounds)
                if routing_aabb is None:
                    # Spanning object has no overlap with local geometry — treat
                    # as shared bucket even if it passed the tile-count gate.
                    shared_objects.append(obj)
                    continue
            else:
                routing_aabb = aabb

            coords = overlapping_tile_coords(
                routing_aabb, origin_x, origin_y, origin_z,
                tile_size_x, tile_size_y, tile_size_z,
                SPLIT_CLIP_EPSILON,
            )
            for coord in coords:
                tile_assignments.setdefault(coord, []).append(obj)
        else:
            shared_objects.append(obj)

    return tile_assignments, shared_objects, classification_map


# ============================================================
# SECTION 6: BLENDER SCENE HELPERS
# ============================================================

@contextmanager
def scene_context(scene):
    view_layer = scene.view_layers[0]
    window = bpy.context.window

    # bpy.context.temp_override(scene=..., view_layer=...) redirects
    # bpy.context.scene/view_layer for plain data access, but NOT
    # bpy.context.window.scene -- and some operators (notably
    # object.bake) validate selected objects against the window's scene
    # internally rather than the overridden context attribute. Without
    # window.scene also pointing at the right scene, baking inside this
    # context fails with "Object '<unrelated object from the real window
    # scene>' is not in view layer" even though nothing from that scene
    # is selected.
    #
    # Set window.scene/view_layer BEFORE entering temp_override and
    # restore AFTER leaving it -- not nested inside the `with` block
    # during an active operator call. Mutating window.scene while a
    # temp_override is already active on the context stack crashes
    # Blender (verified empirically); doing it as plain setup/teardown
    # around the override does not.
    original_scene = window.scene if window is not None else None
    original_vl    = window.view_layer if window is not None else None
    if window is not None:
        window.scene      = scene
        window.view_layer = view_layer
    try:
        if hasattr(bpy.context, "temp_override"):
            with bpy.context.temp_override(scene=scene, view_layer=view_layer):
                yield
        elif window is not None:
            yield
        else:
            raise RuntimeError("No active Blender window for operator context.")
    finally:
        if window is not None:
            window.scene      = original_scene
            window.view_layer = original_vl


def remove_scene(scene):
    bpy.data.scenes.remove(scene)


def set_scene_selection(scene, objects):
    view_layer = scene.view_layers[0]
    for obj in scene.objects:
        try:
            obj.select_set(False, view_layer=view_layer)
        except TypeError:
            obj.select_set(False)
    for obj in objects:
        try:
            obj.select_set(True, view_layer=view_layer)
        except TypeError:
            obj.select_set(True)
    view_layer.objects.active = objects[0] if objects else None


def bake_object_world_transform_to_mesh_data(obj, world_matrix=None):
    """Apply world_matrix to mesh vertices and reset the object to the origin.

    Pass world_matrix explicitly (captured via the evaluated depsgraph) so the
    function never needs to re-read obj.matrix_world — which can be stale in a
    freshly-created temp scene before the depsgraph is updated.
    """
    if obj.type != "MESH" or obj.data is None:
        return
    mesh = obj.data
    if world_matrix is None:
        world_matrix = obj.matrix_world.copy()

    mesh.transform(world_matrix)

    # A matrix with negative determinant encodes a reflection (mirror modifier,
    # scale=-1 on one axis).  mesh.transform() moves vertices but does NOT flip
    # triangle winding — without this correction the mesh is inside-out.
    if world_matrix.determinant() < 0:
        mesh.flip_normals()

    obj.matrix_world          = Matrix.Identity(4)
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.parent                = None
    mesh.update()


def duplicate_objects_to_scene(source_objects, temp_scene, bake_world=True):
    """Copy objects into a temporary scene, baking world transforms if requested.

    Uses the evaluated depsgraph to capture matrix_world so that parent-chain
    transforms (including USD import axis-correction empties) are fully resolved.
    Passing the captured matrix directly to bake_object_world_transform avoids a
    set/read race where setting obj.matrix_world schedules a deferred depsgraph
    update that has not yet fired when we read it back.
    """
    new_objects = []
    src_collection = temp_scene.collection
    depsgraph = bpy.context.evaluated_depsgraph_get() if bake_world else None

    for src_obj in source_objects:
        if bake_world:
            world_mat = src_obj.evaluated_get(depsgraph).matrix_world.copy()
        else:
            world_mat = None

        new_obj = src_obj.copy()
        if src_obj.data:
            new_obj.data = src_obj.data.copy()
        new_obj["mesh_original_name"] = src_obj.name
        src_collection.objects.link(new_obj)

        if bake_world:
            new_obj.parent                = None
            new_obj.matrix_parent_inverse = Matrix.Identity(4)
            bake_object_world_transform_to_mesh_data(new_obj, world_matrix=world_mat)

        new_objects.append(new_obj)

    return new_objects


def bisect_mesh_with_plane(bm, plane_co, plane_no):
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    if not geom:
        return
    bmesh.ops.bisect_plane(
        bm, geom=geom,
        plane_co=plane_co, plane_no=plane_no,
        clear_inner=False, clear_outer=False,
    )


def is_point_outside_tile(point, min_x, max_x, min_y, max_y, min_z, max_z):
    return (point.x < min_x or point.x > max_x or
            point.z < min_y or point.z > max_y or   # Blender Z vs tile Y
            point.y < min_z or point.y > max_z)     # Blender Y vs tile Z


def clip_bmesh_to_tile(bm, tile_bounds, epsilon):
    """Bisect bm at all six tile planes and delete faces outside the bounds."""
    e = epsilon
    min_x = tile_bounds["min_x"] - e;  max_x = tile_bounds["max_x"] + e
    min_y = tile_bounds["min_y"] - e;  max_y = tile_bounds["max_y"] + e   # height
    min_z = tile_bounds["min_z"] - e;  max_z = tile_bounds["max_z"] + e   # depth

    # Compute the mesh's own bounding box to skip bisects on planes the mesh
    # does not actually cross.  When an object fits within a single tile its
    # boundary coincides with a tile plane; bisecting there creates new seam
    # edges that get marked sharp and clears custom split normals, corrupting
    # smooth PBR shading even though no faces are removed.
    vx = [v.co.x for v in bm.verts]
    vy = [v.co.y for v in bm.verts]   # Blender Y = depth  → tile Z
    vz = [v.co.z for v in bm.verts]   # Blender Z = height → tile Y
    if not vx:
        return
    mesh_min_x, mesh_max_x = min(vx), max(vx)
    mesh_min_z, mesh_max_z = min(vy), max(vy)   # tile Z uses Blender Y
    mesh_min_y, mesh_max_y = min(vz), max(vz)   # tile Y uses Blender Z

    if mesh_min_x < tile_bounds["min_x"]:
        bisect_mesh_with_plane(bm, (tile_bounds["min_x"], 0, 0), ( 1, 0, 0))
    if mesh_max_x > tile_bounds["max_x"]:
        bisect_mesh_with_plane(bm, (tile_bounds["max_x"], 0, 0), (-1, 0, 0))
    if mesh_min_z < tile_bounds["min_z"]:
        bisect_mesh_with_plane(bm, (0, tile_bounds["min_z"], 0), (0,  1, 0))
    if mesh_max_z > tile_bounds["max_z"]:
        bisect_mesh_with_plane(bm, (0, tile_bounds["max_z"], 0), (0, -1, 0))
    if mesh_min_y < tile_bounds["min_y"]:
        bisect_mesh_with_plane(bm, (0, 0, tile_bounds["min_y"]), (0, 0,  1))
    if mesh_max_y > tile_bounds["max_y"]:
        bisect_mesh_with_plane(bm, (0, 0, tile_bounds["max_y"]), (0, 0, -1))

    outside = [f for f in bm.faces
               if is_point_outside_tile(f.calc_center_median(),
                                        min_x, max_x, min_y, max_y, min_z, max_z)]
    if outside:
        bmesh.ops.delete(bm, geom=outside, context="FACES")

    # Remove geometry left over from the bisect that has no faces.
    loose_edges = [e for e in bm.edges if not e.link_faces]
    if loose_edges:
        bmesh.ops.delete(bm, geom=loose_edges, context="EDGES")
    loose_verts = [v for v in bm.verts if not v.link_faces and not v.link_edges]
    if loose_verts:
        bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")

    # Mark open boundary edges (the cut created by bisect_plane) as sharp so
    # smooth normals are not blended across the cut.  Without this, interpolated
    # normals from the deleted half of the mesh remain on the new boundary
    # vertices and cause visible surface warping at tile edges.
    for edge in bm.edges:
        if len(edge.link_faces) == 1:
            edge.smooth = False

    bm.normal_update()


def clip_objects_to_tile(objects, tile_bounds, epsilon):
    """Clip a list of (already-baked) mesh objects to tile_bounds in place.

    Returns (kept_objects, removed_count).
    Objects that are completely outside the bounds after clipping are deleted.
    """
    kept    = []
    removed = 0

    for obj in objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        mesh = obj.data
        bm   = bmesh.new()
        try:
            bm.from_mesh(mesh)
            if not bm.verts:
                bpy.data.objects.remove(obj, do_unlink=True)
                if mesh.users == 0:
                    bpy.data.meshes.remove(mesh)
                removed += 1
                continue

            clip_bmesh_to_tile(bm, tile_bounds, epsilon)
            bm.to_mesh(mesh)
            # Discard custom split normals carried from the original USD import.
            # Cut-boundary vertices inherit stale interpolated normals; clearing
            # them forces Blender to recompute from the actual post-clip geometry.
            if getattr(mesh, "has_custom_normals", False) and hasattr(mesh, "free_normals_split"):
                mesh.free_normals_split()
            try:
                mesh.validate(clean_customdata=False)
            except TypeError:
                mesh.validate()
            if hasattr(mesh, "calc_normals"):
                mesh.calc_normals()
            mesh.update()
        finally:
            bm.free()

        if len(mesh.vertices) == 0 or len(mesh.polygons) == 0:
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
            removed += 1
            continue

        kept.append(obj)

    return kept, removed


# ============================================================
# SECTION 7: USD EXPORT HELPERS
# ============================================================

def get_operator_properties(operator):
    try:
        rna = operator.get_rna_type()
    except Exception:
        return {}
    return {prop.identifier: prop for prop in rna.properties}


def set_supported_kwarg(kwargs, props, names, value):
    for name in names:
        if name in props:
            kwargs[name] = value
            return name
    return None


def choose_enum_identifier(prop, preferred_identifiers, fallback_substrings=None):
    if getattr(prop, "type", None) != "ENUM":
        return preferred_identifiers[0] if preferred_identifiers else None
    enum_items = [item.identifier for item in prop.enum_items]
    enum_set   = set(enum_items)
    for candidate in preferred_identifiers:
        if candidate in enum_set:
            return candidate
    if fallback_substrings:
        lowered = [(item, item.upper()) for item in enum_items]
        for substring in fallback_substrings:
            needle = substring.upper()
            for original, upper in lowered:
                if needle in upper:
                    return original
    return None


def choose_file_format_identifier(prop, desired_format):
    normalized = desired_format.lower().lstrip(".")
    preferred = {
        "usdc": ["USDC", "usdc", "Binary"],
        "usda": ["USDA", "usda", "ASCII"],
        "usdz": ["USDZ", "usdz"],
    }.get(normalized, [normalized.upper(), normalized])
    return choose_enum_identifier(prop, preferred, fallback_substrings=[normalized.upper()])


def build_usd_export_kwargs(filepath):
    props  = get_operator_properties(bpy.ops.wm.usd_export)
    kwargs = {"filepath": filepath}
    used   = []

    if set_supported_kwarg(kwargs, props, ("selected_objects_only", "selected_objects"), True):
        used.append("selected_objects_only")
    if set_supported_kwarg(kwargs, props, ("visible_objects_only", "visible_objects"), False):
        used.append("visible_objects_only")

    for names, value, label in (
        (("export_animation",),          False, "export_animation"),
        (("export_uvmaps",),             True,  "export_uvmaps"),
        (("export_normals",),            True,  "export_normals"),
        (("export_materials",),          True,  "export_materials"),
        (("export_textures",),           True,  "export_textures"),
        (("generate_preview_surface",),  True,  "generate_preview_surface"),
        (("overwrite_textures",),        True,  "overwrite_textures"),
        (("root_prim_path",),            "/Root", "root_prim_path"),
    ):
        if set_supported_kwarg(kwargs, props, names, value):
            used.append(label)

    format_prop_name = next(
        (c for c in ("file_format", "export_format") if c in props), None
    )
    if format_prop_name:
        fmt = choose_file_format_identifier(props[format_prop_name], EXPORT_FORMAT.lower())
        if fmt is not None:
            kwargs[format_prop_name] = fmt
            used.append(format_prop_name)

    if set_supported_kwarg(kwargs, props, ("convert_orientation",), True):
        used.append("convert_orientation")

    for candidates, preferred, fallback, label in (
        (
            ("export_global_forward_selection", "forward_axis"),
            ("-Z", "NEGATIVE_Z", "Z_NEGATIVE"), ("NEG", "Z"),
            "forward_axis",
        ),
        (
            ("export_global_up_selection", "up_axis"),
            ("Y", "+Y", "POSITIVE_Y", "Y_POSITIVE"), ("POS", "Y"),
            "up_axis",
        ),
    ):
        prop_name = next((c for c in candidates if c in props), None)
        if prop_name:
            val = choose_enum_identifier(props[prop_name], preferred, fallback)
            if val is not None:
                kwargs[prop_name] = val
                used.append(label)

    print(f"USD export args: {sorted(used)}")
    return kwargs


# ============================================================
# MESH MERGING (material-based)
# Objects sharing identical materials are joined into a single
# mesh before USD export, reducing per-tile draw calls.
# ============================================================

def _principled_bsdf_node(mat):
    """Find the first Principled BSDF node in a material's node tree."""
    node_tree = getattr(mat, "node_tree", None) if mat is not None else None
    if not mat or node_tree is None:
        return None
    for node in node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            return node
    return None


def _input_image_path(bsdf, input_name):
    """Extract the resolved image filepath connected to a BSDF input.

    Follows one level of indirection for Normal Map and Bump nodes.
    Returns the filepath string, or None if no image is connected.
    """
    inp = bsdf.inputs.get(input_name)
    if inp is None or not inp.is_linked:
        return None
    node = inp.links[0].from_node
    # Direct image texture connection.
    if node.type == 'TEX_IMAGE' and node.image:
        return node.image.filepath_from_user()
    # Normal Map → Color → Image Texture
    if node.type == 'NORMAL_MAP':
        color_inp = node.inputs.get('Color')
        if color_inp and color_inp.is_linked:
            inner = color_inp.links[0].from_node
            if inner.type == 'TEX_IMAGE' and inner.image:
                return inner.image.filepath_from_user()
    # Bump → Height → Image Texture
    if node.type == 'BUMP':
        height_inp = node.inputs.get('Height')
        if height_inp and height_inp.is_linked:
            inner = height_inp.links[0].from_node
            if inner.type == 'TEX_IMAGE' and inner.image:
                return inner.image.filepath_from_user()
    return None


def _input_scalar_key(bsdf, input_name):
    """Return a rounded scalar or colour tuple for a non-linked BSDF input."""
    inp = bsdf.inputs.get(input_name)
    if inp is None or inp.is_linked:
        return None
    val = getattr(inp, 'default_value', None)
    if val is None:
        return None
    if hasattr(val, '__iter__'):
        return tuple(round(float(v), 4) for v in val)
    return round(float(val), 4)


def _single_material_key(mat):
    """Hashable identity for one Blender material.

    Two materials with identical keys produce identical visual output after
    USD export and can safely share a merged mesh.
    """
    if mat is None:
        return "__none__"
    bsdf = _principled_bsdf_node(mat)
    if bsdf is None:
        # Non-node material or no Principled BSDF: fall back to datablock name.
        return f"name:{mat.name_full}"
    parts = []
    for channel in ('Base Color', 'Metallic', 'Roughness', 'Normal',
                    'Emission Color', 'Alpha'):
        img = _input_image_path(bsdf, channel)
        if img is not None:
            parts.append(f"{channel}:img:{img}")
        else:
            scalar = _input_scalar_key(bsdf, channel)
            if scalar is not None:
                parts.append(f"{channel}:val:{scalar}")
            else:
                parts.append(f"{channel}:empty")
    return "|".join(parts)


def material_merge_key(obj):
    """Hashable key for the full material configuration of a mesh object.

    Objects with identical keys can be joined without visual change.
    Multi-material objects are keyed by the ordered tuple of per-slot keys.
    """
    if not obj.material_slots:
        return ("__no_material__",)
    return tuple(_single_material_key(slot.material) for slot in obj.material_slots)


def _merge_objects_in_scene(group, temp_scene):
    """Merge already-baked meshes without bpy.ops.object.join().

    The temp export pipeline bakes evaluated world transforms into mesh vertices
    and resets each duplicate object to identity.  Calling join() afterwards can
    still re-read stale C-side object transforms and apply the USD import
    axis-correction a second time.  A pure data-level merge avoids that class of
    bug entirely.
    """
    base_obj = group[0]
    merged_bm = bmesh.new()
    material_slots = [slot.material for slot in base_obj.material_slots]
    old_mesh = None

    try:
        for obj in group:
            if obj.type != "MESH" or obj.data is None:
                continue
            mesh = obj.data
            if len(mesh.materials) != len(material_slots):
                raise RuntimeError(
                    f"Material slot count mismatch while merging {obj.name}: "
                    f"{len(mesh.materials)} != {len(material_slots)}"
                )

            # Objects are expected to be baked to identity before merge, but apply
            # the matrix defensively in case a future call path violates that.
            if obj.matrix_world != Matrix.Identity(4):
                raise RuntimeError(f"Object {obj.name} was not baked to identity before merge")
            merged_bm.from_mesh(mesh)

        merged_mesh = bpy.data.meshes.new(f"{base_obj.data.name}_merged")
        merged_bm.to_mesh(merged_mesh)
        merged_mesh.update()

        for mat in material_slots:
            merged_mesh.materials.append(mat)

        old_mesh = base_obj.data
        base_obj.data = merged_mesh
    finally:
        merged_bm.free()

    # Remove merged-away objects and their temporary mesh datablocks from the temp scene.
    for obj in group[1:]:
        mesh = obj.data
        if temp_scene.objects.get(obj.name) is obj:
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.users == 0:
            bpy.data.objects.remove(obj)
        if mesh and mesh.users == 0:
            bpy.data.meshes.remove(mesh)

    if old_mesh and old_mesh.users == 0:
        bpy.data.meshes.remove(old_mesh)

    base_obj.matrix_world = Matrix.Identity(4)
    base_obj.matrix_parent_inverse = Matrix.Identity(4)
    base_obj.parent = None
    return base_obj


def split_objects_by_material(objects, temp_scene):
    """Split any mesh using multiple material slots into one mesh per material.

    The V1 exporter requires each mesh to have exactly one material assignment.
    Running this before merge_objects_by_material lets the resulting
    single-material pieces be re-joined with other objects sharing the same
    material.  Objects that already use a single material pass through unchanged.
    """
    result = []
    for obj in objects:
        if obj.type != "MESH" or obj.data is None:
            result.append(obj)
            continue

        mesh = obj.data
        used_indices = {p.material_index for p in mesh.polygons}

        if len(used_indices) <= 1:
            result.append(obj)
            continue

        # Split into one object per used material index.
        for mat_idx in sorted(used_indices):
            bm = bmesh.new()
            try:
                bm.from_mesh(mesh)
                to_delete = [f for f in bm.faces if f.material_index != mat_idx]
                if to_delete:
                    bmesh.ops.delete(bm, geom=to_delete, context="FACES")
                loose_edges = [e for e in bm.edges if not e.link_faces]
                if loose_edges:
                    bmesh.ops.delete(bm, geom=loose_edges, context="EDGES")
                loose_verts = [v for v in bm.verts if not v.link_faces and not v.link_edges]
                if loose_verts:
                    bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")

                if not bm.faces:
                    continue

                new_mesh = bpy.data.meshes.new(f"{mesh.name}_mat{mat_idx}")
                bm.to_mesh(new_mesh)
                new_mesh.update()

                mat = mesh.materials[mat_idx] if mat_idx < len(mesh.materials) else None
                if mat:
                    new_mesh.materials.append(mat)
                    for p in new_mesh.polygons:
                        p.material_index = 0

                new_obj = bpy.data.objects.new(f"{obj.name}_mat{mat_idx}", new_mesh)
                new_obj["mesh_original_name"] = obj.get("mesh_original_name", obj.name)
                new_obj.matrix_world = obj.matrix_world.copy()
                temp_scene.collection.objects.link(new_obj)
                result.append(new_obj)
            finally:
                bm.free()

        # Remove the original multi-material object.
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)

    return result


def normalize_primary_uv_layer(obj):
    """Rename obj's active UV layer to MERGE_CANONICAL_UV_LAYER_NAME and move it to index 0.

    See the comment on MERGE_CANONICAL_UV_LAYER_NAME for why this matters: bmesh
    merges UV layers by name, and the exporter always reads index 0, so every
    object about to be joined with others must agree on the primary layer's name.
    Other (secondary) UV layers are preserved under their original names.
    No-op if the mesh has no UV layers, or already satisfies both conditions.
    """
    mesh = obj.data
    uv_layers = getattr(mesh, "uv_layers", None)
    if not uv_layers or len(uv_layers) == 0:
        return

    # Compare by name, not identity: each attribute access on uv_layers.active /
    # uv_layers[i] returns a fresh RNA wrapper, so `is` can be False even when
    # both refer to the same underlying layer.
    active_name = (uv_layers.active or uv_layers[0]).name
    if uv_layers[0].name == active_name and active_name == MERGE_CANONICAL_UV_LAYER_NAME:
        return

    loop_count = len(mesh.loops)
    saved = []
    for layer in uv_layers:
        data = [0.0] * (loop_count * 2)
        layer.data.foreach_get("uv", data)
        saved.append((layer.name, data, layer.name == active_name))

    for layer in list(uv_layers):
        uv_layers.remove(layer)

    active_entry = next(entry for entry in saved if entry[2])
    new_active = uv_layers.new(name=MERGE_CANONICAL_UV_LAYER_NAME)
    new_active.data.foreach_set("uv", active_entry[1])

    for name, data, was_active in saved:
        if was_active:
            continue
        # Avoid a name collision with the canonical layer we just created
        # (e.g. a mesh that already had a secondary layer literally named "UVMap").
        restored_name = name if name != MERGE_CANONICAL_UV_LAYER_NAME else f"{name}.orig"
        layer = uv_layers.new(name=restored_name)
        layer.data.foreach_set("uv", data)

    uv_layers.active = new_active


def merge_objects_by_material(objects, temp_scene):
    """Join objects that share identical material(s) into single meshes.

    Objects must already have baked world transforms (identity matrix).  Merge
    is performed at the mesh-data level instead of via bpy.ops.object.join() so
    stale object transform caches cannot double-apply importer axis corrections.

    Objects whose original name starts with NO_MERGE_PREFIX are passed through
    untouched so they keep their own entity name in the exported file.

    Returns the reduced object list.
    """
    if len(objects) <= 1:
        return objects

    groups = {}
    non_mesh = []
    protected = []
    for obj in objects:
        if obj.type != 'MESH' or obj.data is None:
            non_mesh.append(obj)
            continue
        if NO_MERGE_PREFIX:
            original_name = obj.get("mesh_original_name", obj.name)
            if original_name.startswith(NO_MERGE_PREFIX):
                protected.append(obj)
                continue
        key = material_merge_key(obj)
        groups.setdefault(key, []).append(obj)

    result = list(non_mesh) + protected
    total_mesh_input = sum(len(g) for g in groups.values())
    total_merged_away = 0
    for key, group in groups.items():
        if len(group) == 1:
            result.append(group[0])
            continue

        try:
            for obj in group:
                normalize_primary_uv_layer(obj)
            merged = _merge_objects_in_scene(group, temp_scene)
            total_merged_away += len(group) - 1
            result.append(merged)
        except Exception as ex:
            print(f"  Warning: mesh merge failed ({len(group)} objects): {ex}")
            result.extend(group)

    if protected:
        print(f"  Mesh merge: {len(protected)} protected object(s) skipped (prefix '{NO_MERGE_PREFIX}')")
    if total_merged_away > 0:
        print(f"  Mesh merge: {total_mesh_input} → {total_mesh_input - total_merged_away} "
              f"objects ({total_merged_away} eliminated)")

    return result


# ============================================================
# HLOD SIMPLIFICATION
# ============================================================

def simplify_objects_for_hlod(objects, temp_scene, reduction_ratio):
    """Apply a Decimate modifier to each mesh object and commit the result.

    The depsgraph must be evaluated inside the temp scene context — otherwise
    bpy.context.evaluated_depsgraph_get() returns the *main* scene's graph,
    which knows nothing about the temp scene's objects or their modifiers,
    causing the Decimate to silently produce an unmodified mesh.
    """
    simplified = []
    removed = 0

    for obj in objects:
        if obj.type != "MESH" or obj.data is None:
            continue

        mesh = obj.data
        if len(mesh.polygons) == 0:
            if obj in temp_scene.objects:
                bpy.data.objects.remove(obj, do_unlink=True)
            elif obj.users == 0:
                bpy.data.objects.remove(obj)
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
            removed += 1
            continue

        modifier = obj.modifiers.new(name="__hlod_decimate__", type='DECIMATE')
        modifier.ratio = reduction_ratio
        modifier.use_collapse_triangulate = True

        with scene_context(temp_scene):
            depsgraph = bpy.context.evaluated_depsgraph_get()
            eval_obj = obj.evaluated_get(depsgraph)
            try:
                simplified_mesh = bpy.data.meshes.new_from_object(
                    eval_obj,
                    preserve_all_data_layers=True,
                    depsgraph=depsgraph,
                )
            except TypeError:
                try:
                    simplified_mesh = bpy.data.meshes.new_from_object(
                        eval_obj,
                        preserve_all_data_layers=True,
                    )
                except TypeError:
                    simplified_mesh = bpy.data.meshes.new_from_object(eval_obj)
        if simplified_mesh is None:
            raise RuntimeError(f"Failed to evaluate HLOD decimation for {obj.name}")

        old_mesh = obj.data
        obj.modifiers.remove(modifier)
        obj.data = simplified_mesh

        if old_mesh and old_mesh.users == 0:
            bpy.data.meshes.remove(old_mesh)

        if len(simplified_mesh.vertices) == 0 or len(simplified_mesh.polygons) == 0:
            bpy.data.objects.remove(obj, do_unlink=True)
            if simplified_mesh.users == 0:
                bpy.data.meshes.remove(simplified_mesh)
            removed += 1
            continue

        simplified.append(obj)

    return simplified, removed


# ============================================================
# SECTION 8: TILE AND SHARED EXPORT
# ============================================================

def export_local_tile(filepath, objects, tile_bounds, source_scene_path):
    """Export clipped geometry for one tile-local entry.

    No quick_has_geometry pre-check is performed.  The bmesh clip step
    determines emptiness directly — this correctly handles edges that cross
    tile boundaries without landing any vertex inside the tile, a case that
    a vertex-only pre-check would wrongly skip.
    """
    if not objects:
        return False, "No objects assigned to tile"
    if not BAKE_WORLD_TRANSFORMS:
        return False, "BAKE_WORLD_TRANSFORMS must be True for clipped export"
    source_asset_path = resolve_runtime_source_asset_path(source_scene_path, filepath)

    temp_scene = bpy.data.scenes.new("TEMP_TILE_EXPORT")
    try:
        temp_objs = duplicate_objects_to_scene(objects, temp_scene, bake_world=True)

        if CLIP_LOCAL_MESHES:
            temp_objs, removed = clip_objects_to_tile(temp_objs, tile_bounds, SPLIT_CLIP_EPSILON)
            if not temp_objs:
                return False, "No geometry after clipping"
            if removed:
                print(f"  Clipped away {removed} empty object(s)")

        temp_objs = split_objects_by_material(temp_objs, temp_scene)
        if MERGE_BY_MATERIAL and len(temp_objs) > 1:
            temp_objs = merge_objects_by_material(temp_objs, temp_scene)
            if not temp_objs:
                return False, "No geometry after merge"

        with scene_context(temp_scene):
            export_objects_to_untold(
                temp_objs,
                source_asset_path=source_asset_path,
                output_path=Path(filepath).resolve(),
                file_type_name="tile",
                convert_orientation=CONVERT_ORIENTATION,
                source_orientation=SOURCE_ORIENTATION,
                compress_geometry=COMPRESS_GEOMETRY,
                bake_materials=BAKE_MATERIALS,
                bake_resolution=BAKE_RESOLUTION,
                bake_cache=BAKE_CACHE,
                progress_callback=make_untold_progress_callback(os.path.basename(filepath)),
            )
    finally:
        remove_scene(temp_scene)

    return True, None


def export_shared_bucket(filepath, objects, source_scene_path):
    """Export all spanning objects to a single shared USD file.

    Spanning objects are NOT clipped.  The shared bucket is a monolithic asset
    loaded at a large streaming radius (effectively always visible), providing
    a continuous backdrop while the tile-local detail system streams around it.

    Keeping this as a separate export function creates a natural extension point:
    future passes can pre-process these objects (simplify, split, LOD-generate)
    before handing them to this function.
    """
    if not objects:
        return False, "No spanning objects"
    source_asset_path = resolve_runtime_source_asset_path(source_scene_path, filepath)

    if BAKE_WORLD_TRANSFORMS:
        temp_scene = bpy.data.scenes.new("TEMP_SHARED_EXPORT")
        try:
            temp_objs = duplicate_objects_to_scene(objects, temp_scene, bake_world=True)
            temp_objs = split_objects_by_material(temp_objs, temp_scene)
            if MERGE_BY_MATERIAL and len(temp_objs) > 1:
                temp_objs = merge_objects_by_material(temp_objs, temp_scene)
            with scene_context(temp_scene):
                export_objects_to_untold(
                    temp_objs,
                    source_asset_path=source_asset_path,
                    output_path=Path(filepath).resolve(),
                    file_type_name="shared",
                    convert_orientation=CONVERT_ORIENTATION,
                    source_orientation=SOURCE_ORIENTATION,
                    compress_geometry=COMPRESS_GEOMETRY,
                    bake_materials=BAKE_MATERIALS,
                    bake_resolution=BAKE_RESOLUTION,
                    bake_cache=BAKE_CACHE,
                    progress_callback=make_untold_progress_callback(os.path.basename(filepath)),
                )
        finally:
            remove_scene(temp_scene)
    else:
        source_scene = bpy.context.scene
        with scene_context(source_scene):
            export_objects_to_untold(
                objects,
                source_asset_path=source_asset_path,
                output_path=Path(filepath).resolve(),
                file_type_name="shared",
                convert_orientation=CONVERT_ORIENTATION,
                source_orientation=SOURCE_ORIENTATION,
                compress_geometry=COMPRESS_GEOMETRY,
                bake_materials=BAKE_MATERIALS,
                bake_resolution=BAKE_RESOLUTION,
                bake_cache=BAKE_CACHE,
                progress_callback=make_untold_progress_callback(os.path.basename(filepath)),
            )

    return True, None


def export_hlod_tile(filepath, objects, tile_bounds, reduction_ratio, source_scene_path, file_type_name):
    """Export one simplified HLOD asset for a tile-local geometry set.

    Deliberately does not pass BAKE_MATERIALS/BAKE_RESOLUTION through to
    export_objects_to_untold(): HLOD/LOD tiles are decimated stand-ins for
    geometry already exported (and, if requested, baked) at full detail in
    export_local_tile()/export_shared_bucket(). Baking them again would
    duplicate work and risk a different-looking bake, since decimation
    changes UV layout/topology.
    """
    if not objects:
        return False, "No objects assigned to tile"
    if not BAKE_WORLD_TRANSFORMS:
        return False, "BAKE_WORLD_TRANSFORMS must be True for HLOD export"
    source_asset_path = resolve_runtime_source_asset_path(source_scene_path, filepath)

    temp_scene = bpy.data.scenes.new("TEMP_HLOD_EXPORT")
    try:
        temp_objs = duplicate_objects_to_scene(objects, temp_scene, bake_world=True)

        if CLIP_LOCAL_MESHES:
            temp_objs, removed = clip_objects_to_tile(temp_objs, tile_bounds, SPLIT_CLIP_EPSILON)
            if not temp_objs:
                return False, "No geometry after clipping"
            if removed:
                print(f"  HLOD clip removed {removed} empty object(s)")

        temp_objs = split_objects_by_material(temp_objs, temp_scene)
        if MERGE_BY_MATERIAL and len(temp_objs) > 1:
            temp_objs = merge_objects_by_material(temp_objs, temp_scene)
            if not temp_objs:
                return False, "No geometry after merge"

        temp_objs, removed = simplify_objects_for_hlod(temp_objs, temp_scene, reduction_ratio)
        if not temp_objs:
            return False, "No geometry after HLOD simplification"
        if removed:
            print(f"  HLOD simplification removed {removed} empty object(s)")

        with scene_context(temp_scene):
            export_objects_to_untold(
                temp_objs,
                source_asset_path=source_asset_path,
                output_path=Path(filepath).resolve(),
                file_type_name=file_type_name,
                convert_orientation=CONVERT_ORIENTATION,
                source_orientation=SOURCE_ORIENTATION,
                compress_geometry=COMPRESS_GEOMETRY,
                progress_callback=make_untold_progress_callback(os.path.basename(filepath)),
            )
    finally:
        remove_scene(temp_scene)

    return True, None


# ============================================================
# SECTION 9: DEBUG AABB EXPORT
# ============================================================

def tile_debug_color(tx, ty, tz):
    hue = ((tx * 73 + ty * 31 + tz * 113) % 360) / 360.0
    r, g, b = colorsys.hsv_to_rgb(hue, 0.85, 0.95)
    return (r, g, b, 1.0)


def export_debug_aabb(filepath, tile_bounds, color):
    """Export a solid-color cube matching tile_bounds — no real geometry needed.

    Built via bpy.data (not bpy.ops.mesh.primitive_cube_add) so it works in
    non-interactive / background script contexts where operators require an
    active 3-D viewport.
    """
    x0, x1 = tile_bounds["min_x"], tile_bounds["max_x"]
    y0, y1 = tile_bounds["min_z"], tile_bounds["max_z"]   # Blender Y (depth)
    z0, z1 = tile_bounds["min_y"], tile_bounds["max_y"]   # Blender Z (height)

    verts = [
        (x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
        (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1),
    ]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]

    mesh_data = bpy.data.meshes.new("__debug_aabb_mesh__")
    mesh_data.from_pydata(verts, [], faces)
    mesh_data.update()

    mat = bpy.data.materials.new("__debug_tile_mat__")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
    mesh_data.materials.append(mat)

    cube = bpy.data.objects.new("__debug_aabb_cube__", mesh_data)
    temp_scene = bpy.data.scenes.new("__debug_aabb_export__")
    try:
        temp_scene.collection.objects.link(cube)
        with scene_context(temp_scene):
            export_objects_to_untold(
                [cube],
                source_asset_path=resolve_runtime_source_asset_path(bpy.data.filepath, filepath),
                output_path=Path(filepath).resolve(),
                file_type_name="tile",
                convert_orientation=CONVERT_ORIENTATION,
                source_orientation=SOURCE_ORIENTATION,
                compress_geometry=COMPRESS_GEOMETRY,
            )
    finally:
        remove_scene(temp_scene)
        if cube.users == 0:
            bpy.data.objects.remove(cube)
        if mesh_data.users == 0:
            bpy.data.meshes.remove(mesh_data)
        if mat.users == 0:
            bpy.data.materials.remove(mat)

    return True, None


def resolve_runtime_source_asset_path(source_scene_path, fallback_output_path):
    if source_scene_path:
        return Path(source_scene_path).expanduser().resolve()
    return Path(fallback_output_path).expanduser().resolve()


def relative_metadata_path(path, base_dir):
    if not path:
        return None
    try:
        return os.path.relpath(path, base_dir)
    except Exception:
        return os.path.basename(path)


# ============================================================
# SECTION 10: STREAMING DEFAULTS
# ============================================================

def compute_streaming_defaults(base_tile_size, scene_half_diag):
    streaming = min(
        base_tile_size * STREAMING_RADIUS_TILE_MULTIPLIER,
        scene_half_diag * STREAMING_RADIUS_SCENE_FRACTION,
    )
    unload = min(
        base_tile_size * UNLOAD_RADIUS_TILE_MULTIPLIER,
        scene_half_diag * UNLOAD_RADIUS_SCENE_FRACTION,
    )
    unload = max(unload, streaming * 1.5)   # guarantee hysteresis
    return streaming, unload


def compute_shared_streaming_radii(scene_half_diag):
    r  = scene_half_diag * SHARED_STREAMING_RADIUS_FRACTION
    ur = scene_half_diag * SHARED_UNLOAD_RADIUS_FRACTION
    ur = max(ur, r * 1.5)
    return r, ur


def infer_streaming_profile(use_quadtree, node_tier_groups, scene_half_diag, base_tile_size):
    """Return 'indoor' or 'outdoor' for this export.

    Explicit CLI choice wins.  Auto falls back to 'indoor' unless the scene
    looks like a large outdoor/city layout: broad footprint, few ExteriorShell
    objects, and most quadtree groups classified as StructuralInterior.
    """
    requested = (SCENE_STREAMING_PROFILE or "auto").lower()
    if requested in TIER_STREAMING_FRACTIONS:
        return requested

    if not use_quadtree or not node_tier_groups:
        return "indoor"

    tier_counts: dict = {}
    for (_, tier), objs in node_tier_groups.items():
        tier_counts[tier] = tier_counts.get(tier, 0) + len(objs)

    total = sum(tier_counts.values())
    if total == 0:
        return "indoor"

    exterior_fraction  = tier_counts.get("ExteriorShell", 0) / total
    structural_fraction = tier_counts.get("StructuralInterior", 0) / total
    large_footprint = scene_half_diag >= max(150.0, base_tile_size * 8.0)

    if large_footprint and exterior_fraction < 0.10 and structural_fraction >= 0.65:
        return "outdoor"

    return "indoor"


def compute_tier_radii(scene_half_diag, profile):
    """Convert fraction table for *profile* to world-space metres."""
    fractions = TIER_STREAMING_FRACTIONS.get(profile, TIER_STREAMING_FRACTIONS["indoor"])
    radii = {
        tier: {
            "streaming": max(1.0, scene_half_diag * v["streaming"]),
            "unload":    max(2.0, scene_half_diag * v["unload"]),
            "priority":  v["priority"],
        }
        for tier, v in fractions.items()
    }
    for tier, override in TIER_RADIUS_OVERRIDES.items():
        fallback_fraction = fractions.get(DEFAULT_SEMANTIC_TIER, {"streaming": 0.1, "unload": 0.18})
        existing = radii.get(tier, {
            "streaming": max(1.0, scene_half_diag * fallback_fraction["streaming"]),
            "unload": max(2.0, scene_half_diag * fallback_fraction["unload"]),
            "priority": DEFAULT_STREAMING_PRIORITY,
        })
        streaming = float(override["streaming"])
        unload = float(override["unload"])
        priority = int(override.get("priority", existing.get("priority", DEFAULT_STREAMING_PRIORITY)))
        radii[tier] = {
            "streaming": max(1.0, streaming),
            "unload": max(max(2.0, unload), max(1.0, streaming) + 0.1),
            "priority": priority,
        }
    return radii


def init_tier_radii(scene_half_diag, profile):
    global _ACTIVE_TIER_RADII
    _ACTIVE_TIER_RADII = compute_tier_radii(scene_half_diag, profile)


def tier_streaming_radii(tier):
    return _ACTIVE_TIER_RADII.get(tier, {})


def parse_tier_radius_override(raw_value):
    """Parse Tier=stream,unload[,priority] from the CLI."""
    if "=" not in raw_value:
        raise argparse.ArgumentTypeError(
            f"Invalid --tier-radius '{raw_value}'. Expected Tier=stream,unload[,priority]."
        )
    tier, values = raw_value.split("=", 1)
    tier = tier.strip()
    if not tier:
        raise argparse.ArgumentTypeError("Invalid --tier-radius: tier name is empty.")
    parts = [p.strip() for p in values.split(",") if p.strip()]
    if len(parts) not in (2, 3):
        raise argparse.ArgumentTypeError(
            f"Invalid --tier-radius '{raw_value}'. Expected Tier=stream,unload[,priority]."
        )
    try:
        streaming = float(parts[0])
        unload = float(parts[1])
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"Invalid --tier-radius '{raw_value}'. Stream and unload must be numbers."
        ) from exc
    if streaming <= 0 or unload <= 0:
        raise argparse.ArgumentTypeError(
            f"Invalid --tier-radius '{raw_value}'. Stream and unload must be positive metres."
        )
    if unload <= streaming:
        raise argparse.ArgumentTypeError(
            f"Invalid --tier-radius '{raw_value}'. Unload radius must be greater than streaming radius."
        )
    override = {"streaming": streaming, "unload": unload}
    if len(parts) == 3:
        try:
            override["priority"] = int(parts[2])
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                f"Invalid --tier-radius '{raw_value}'. Priority must be an integer."
            ) from exc
    return tier, override


def log_streaming_profile(scene_bounds, scene_half_diag, resolved_profile):
    """Print a human-readable summary of the resolved tier streaming radii."""
    bx = scene_bounds["max"][0] - scene_bounds["min"][0]
    by = scene_bounds["max"][1] - scene_bounds["min"][1]
    bz = scene_bounds["max"][2] - scene_bounds["min"][2]
    profile_label = resolved_profile
    if SCENE_STREAMING_PROFILE == "auto":
        profile_label = f"auto → {resolved_profile}"
    print(
        f"Streaming profile : {profile_label}\n"
        f"  Scene dimensions    : {bx:.1f}m (W) × {by:.1f}m (D) × {bz:.1f}m (H)\n"
        f"  Footprint half-diag : {scene_half_diag:.1f}m  ← multiplier base"
    )
    for tier, radii in _ACTIVE_TIER_RADII.items():
        override_suffix = "  (override)" if tier in TIER_RADIUS_OVERRIDES else ""
        print(
            f"  {tier:25s}: "
            f"{radii['streaming']:7.1f}m stream  |  "
            f"{radii['unload']:7.1f}m unload  |  "
            f"priority={radii.get('priority', DEFAULT_STREAMING_PRIORITY)}{override_suffix}"
        )


# ============================================================
# SECTION 11: MEMORY ESTIMATION
# ============================================================

def estimate_mesh_memory_bytes(mesh):
    v = len(mesh.vertices);  e = len(mesh.edges)
    l = len(mesh.loops);     p = len(mesh.polygons)
    est = v*56 + e*32 + l*24 + p*32
    if hasattr(mesh, "uv_layers"):
        for layer in mesh.uv_layers:
            est += len(layer.data) * 8
    if hasattr(mesh, "color_attributes"):
        for attr in mesh.color_attributes:
            bpe = 16 if getattr(attr, "data_type", "") in (
                "FLOAT_COLOR","FLOAT_VECTOR","FLOAT4X4","FLOAT2","FLOAT") else 4
            est += len(attr.data) * bpe
    return max(est, 0)


def estimate_object_memory_bytes(obj, mesh_size_cache):
    if obj.type != "MESH" or obj.data is None:
        return 1024
    key = obj.data.name_full
    if key not in mesh_size_cache:
        mesh_size_cache[key] = estimate_mesh_memory_bytes(obj.data)
    return mesh_size_cache[key] + 1024


def estimate_tile_memory(tile_objects, tile_coverage_counts, mesh_size_cache):
    """Estimate tile memory, prorating shared objects by how many tiles they cover."""
    total = 0.0
    for obj in tile_objects:
        base     = estimate_object_memory_bytes(obj, mesh_size_cache)
        coverage = max(1, tile_coverage_counts.get(obj.name, 1))
        total   += base / coverage
    return int(round(total))


def build_tile_coverage_counts(tile_assignments):
    counts = {}
    for tile_objs in tile_assignments.values():
        seen = set()
        for obj in tile_objs:
            if obj.name not in seen:
                counts[obj.name] = counts.get(obj.name, 0) + 1
                seen.add(obj.name)
    return counts


# ============================================================
# SECTION 12: TILE PREVIEW (Blender viewport visualization)
# ============================================================

def create_tile_preview(tile_assignments, shared_objects, origin_x, origin_y, origin_z,
                        tile_size_x, tile_size_y, tile_size_z):
    """Create wireframe boxes in a 'Tile Preview' collection.

    Green = sparse local tile, red = busy local tile, blue = shared-bucket objects.
    Set Viewport Shading > Color > Object to see the coloring.
    """
    COLLECTION_NAME = "Tile Preview"
    if COLLECTION_NAME in bpy.data.collections:
        old_col = bpy.data.collections[COLLECTION_NAME]
        for obj in list(old_col.objects):
            md = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if md and md.users == 0:
                bpy.data.meshes.remove(md)
        bpy.data.collections.remove(old_col)

    col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(col)

    non_empty = [(coord, objs) for coord, objs in tile_assignments.items() if objs]
    max_count = max((len(o) for _, o in non_empty), default=1)

    for (tx, ty, tz), tile_objs in non_empty:
        tb = tile_bounds_from_coord(tx, ty, tz, origin_x, origin_y, origin_z,
                                    tile_size_x, tile_size_y, tile_size_z)
        cx = (tb["min_x"] + tb["max_x"]) * 0.5
        cy = (tb["min_z"] + tb["max_z"]) * 0.5   # Blender Y
        cz = (tb["min_y"] + tb["max_y"]) * 0.5   # Blender Z
        sx = tb["max_x"] - tb["min_x"]
        sy = tb["max_z"] - tb["min_z"]
        sz = tb["max_y"] - tb["min_y"]

        md = bpy.data.meshes.new(f"tile_{tx}_{ty}_{tz}_preview")
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bm.to_mesh(md); bm.free()
        obj = bpy.data.objects.new(f"tile_{tx}_{ty}_{tz}", md)
        obj.location = (cx, cy, cz)
        obj.scale    = (sx, sy, sz)
        obj.display_type = "WIRE"
        obj.hide_select  = True
        t = len(tile_objs) / max(max_count, 1)
        obj.color = (min(1.0, t*2.0), min(1.0, (1-t)*2.0), 0.0, 1.0)
        col.objects.link(obj)

    print(f"Tile Preview: {len(col.objects)} local-tile boxes + "
          f"{len(shared_objects)} shared-bucket objects (not visualised as boxes).")
    print("  Viewport Shading > Color > Object  →  green=sparse / red=busy")


# ============================================================
# SECTION 13: AUTO TILE SIZING
# Uses centroid-only assignment (fast) to find a tile size that
# keeps tile count and objects-per-tile within targets, then the
# real overlap-based assignment is run at that size.
# ============================================================

def centroid_assignments_for_sizing(objects, object_bounds,
                                    origin_x, origin_y, origin_z,
                                    tile_size_x, tile_size_y, tile_size_z):
    assignments = {}
    for obj in objects:
        aabb = object_bounds[obj.name]
        cx, cy, cz = aabb_center(aabb)
        coord = tile_coord_from_point(cx, cy, cz,
                                      origin_x, origin_y, origin_z,
                                      tile_size_x, tile_size_y, tile_size_z)
        assignments.setdefault(coord, []).append(obj)
    return assignments


def choose_auto_tile_size(objects, object_bounds, scene_bounds, origin_y, tile_size_y):
    extent_x   = max(scene_bounds["max"][0] - scene_bounds["min"][0], 1e-9)
    extent_z   = max(scene_bounds["max"][1] - scene_bounds["min"][1], 1e-9)
    scene_area = extent_x * extent_z

    target_obj    = max(1, int(AUTO_TILE_TARGET_OBJECTS_PER_TILE))
    target_w_tol  = max(1.0, target_obj * max(AUTO_TILE_OBJECT_TARGET_TOLERANCE, 0.01))
    max_tiles     = max(1, int(AUTO_TILE_TARGET_MAX_TILES))
    desired_count = min(max_tiles, max(1, int(math.ceil(len(objects) / target_obj))))
    tile_size     = clamp(math.sqrt(scene_area / max(desired_count, 1)),
                          AUTO_TILE_MIN_SIZE, AUTO_TILE_MAX_SIZE)

    best = {}; best_count = 0; best_max_obj = 0; best_avg = 0.0; iters = 0
    met_tiles = False; met_obj = False

    for it in range(1, max(1, int(AUTO_TILE_MAX_ITERATIONS)) + 1):
        origin_x    = math.floor(scene_bounds["min"][0] / tile_size) * tile_size
        origin_z    = math.floor(scene_bounds["min"][1] / tile_size) * tile_size
        asgn        = centroid_assignments_for_sizing(objects, object_bounds,
                                                      origin_x, origin_y, origin_z,
                                                      tile_size, tile_size_y, tile_size)
        tc          = len(asgn)
        max_obj_t   = max((len(o) for o in asgn.values()), default=0)
        avg_obj_t   = (sum(len(o) for o in asgn.values()) / tc) if tc else 0.0
        best        = asgn; best_count = tc; best_max_obj = max_obj_t
        best_avg    = avg_obj_t; iters = it

        tiles_ok    = tc <= max_tiles
        objs_ok     = max_obj_t <= target_w_tol
        if tiles_ok and objs_ok:
            met_tiles = True; met_obj = True; break

        tile_v  = (tc / max_tiles)            if max_tiles else 1.0
        obj_v   = (max_obj_t / target_w_tol)
        if (not objs_ok) and (tiles_ok or obj_v >= tile_v):
            scale = math.sqrt(max(obj_v, 1.0001)) * max(AUTO_TILE_SAFETY_SCALE, 1.0)
            next_size = clamp(tile_size / scale, AUTO_TILE_MIN_SIZE, AUTO_TILE_MAX_SIZE)
        else:
            scale = math.sqrt(max(tile_v, 1.0001)) * max(AUTO_TILE_SAFETY_SCALE, 1.0)
            next_size = clamp(tile_size * scale, AUTO_TILE_MIN_SIZE, AUTO_TILE_MAX_SIZE)

        if abs(next_size - tile_size) <= 1e-6:
            break
        tile_size = next_size

    if best_count <= max_tiles:
        met_tiles = True
    if best_max_obj <= target_w_tol:
        met_obj = True

    return tile_size, tile_size, {
        "enabled": True,
        "selected_tile_size": tile_size, "estimated_tile_count": best_count,
        "max_objects_in_tile": best_max_obj, "avg_objects_in_tile": best_avg,
        "iterations_used": iters,
        "met_target_max_tiles": met_tiles, "met_target_objects_per_tile": met_obj,
    }


# ============================================================
# SECTION 14: DRY-RUN DIAGNOSTICS
# ============================================================

def print_dry_run_report(tile_assignments, shared_objects, classification_map,
                         object_bounds, tile_size_x, tile_size_z,
                         mesh_size_cache, tile_coverage_counts,
                         scene_bounds=None):
    local_names   = [n for n, r in classification_map.items()
                     if r["policy"] == "local_overlap"]
    shared_names  = [n for n, r in classification_map.items()
                     if r["policy"] == "shared_bucket"]
    split_names   = [n for n, r in classification_map.items()
                     if r["policy"] == "future_split_candidate"]

    eff_thr = _effective_overlap_threshold()

    # Scene-bounds / tile-grid diagnostics
    print("\n=== SCENE DIAGNOSTICS ===")
    if scene_bounds:
        bx0, bx1 = scene_bounds["min"][0], scene_bounds["max"][0]
        bz0, bz1 = scene_bounds["min"][1], scene_bounds["max"][1]
        span_x = bx1 - bx0
        span_z = bz1 - bz0
        tiles_x = math.ceil(span_x / tile_size_x) if tile_size_x > 0 else 0
        tiles_z = math.ceil(span_z / tile_size_z) if tile_size_z > 0 else 0
        print(f"  Scene XZ footprint  : X [{bx0:.1f}, {bx1:.1f}] = {span_x:.1f} units")
        print(f"                        Z [{bz0:.1f}, {bz1:.1f}] = {span_z:.1f} units")
        print(f"  Tile size           : {tile_size_x} × {tile_size_z}")
        print(f"  Implied grid        : ~{tiles_x} × {tiles_z} = {tiles_x*tiles_z} tiles")
        print(f"  Spanning dim limit  : {SPANNING_THRESHOLD_TILES} × {tile_size_x} = "
              f"{SPANNING_THRESHOLD_TILES * tile_size_x:.0f} units  (objects wider than this → shared)")
        print(f"  Overlap threshold   : {eff_thr} tiles  "
              f"({'auto: ' + str(SPANNING_THRESHOLD_TILES) + '²' if OVERLAP_THRESHOLD is None else 'manual'})")
    else:
        print(f"  (scene_bounds not available)")
        print(f"  Tile size           : {tile_size_x} × {tile_size_z}")
        print(f"  Overlap threshold   : {eff_thr}")

    # Per-object detail
    print("\n=== OBJECT CLASSIFICATION ===")
    for name, result in sorted(classification_map.items(),
                               key=lambda kv: kv[1]["xz_overlap_count"], reverse=True):
        aabb = object_bounds[name]
        print(
            f"  {name}\n"
            f"    AABB min={tuple(round(v,2) for v in aabb['min'])} "
            f"max={tuple(round(v,2) for v in aabb['max'])}\n"
            f"    dims={result['dimensions']}  dim_ratio={result['dim_ratio']}  "
            f"xz_overlaps={result['xz_overlap_count']}\n"
            f"    policy={result['policy']}  reasons={result['reasons']}"
        )

    # Tile summary
    if tile_assignments:
        counts = [(coord, len(objs)) for coord, objs in tile_assignments.items() if objs]
        counts.sort(key=lambda x: x[1], reverse=True)
        busiest = counts[:5]
        max_count = counts[0][1] if counts else 0
        tile_mems = []
        for coord, tile_objs in tile_assignments.items():
            if tile_objs:
                m = estimate_tile_memory(tile_objs, tile_coverage_counts, mesh_size_cache)
                tile_mems.append(m)

        print(f"\n=== TILE SUMMARY ===")
        print(f"  Local tiles planned : {len(counts)}")
        print(f"  Max objects/tile    : {max_count}")
        print(f"  Busiest tiles       : {[f'tile_{c[0][0]}_{c[0][1]}_{c[0][2]}({c[1]})' for c in busiest]}")
        if tile_mems:
            print(f"  Total est. memory   : {format_bytes(sum(tile_mems))}")
            print(f"  Peak tile est. mem  : {format_bytes(max(tile_mems))}")

        # Object-count distribution
        bucket_labels = [1, 5, 10, 25, 50, 100, 250, 500]
        print("  Object-count distribution across tiles:")
        prev = 0
        all_counts = [c for _, c in counts]
        max_c = max(all_counts)
        for b in bucket_labels + [max_c + 1]:
            bucket = [c for c in all_counts if prev < c <= b]
            if bucket or b <= max_c:
                label = f"  {prev+1:>4}-{b:>4}" if b <= max_c else f"  {prev+1:>4}+    "
                bar = "#" * min(len(bucket), 40)
                print(f"{label} objs: {len(bucket):>4} tiles  {bar}")
            prev = b

    # Merge potential (material-based)
    if MERGE_BY_MATERIAL and tile_assignments:
        merge_before, merge_after = 0, 0
        best_reduction_tile = None
        best_reduction_count = 0
        for coord, tile_objs in tile_assignments.items():
            if not tile_objs:
                continue
            groups = {}
            for obj in tile_objs:
                if obj.type != 'MESH' or obj.data is None:
                    continue
                key = material_merge_key(obj)
                groups.setdefault(key, []).append(obj)
            n_before = sum(len(g) for g in groups.values())
            n_after = len(groups)
            merge_before += n_before
            merge_after += n_after
            tile_reduction = n_before - n_after
            if tile_reduction > best_reduction_count:
                best_reduction_count = tile_reduction
                best_reduction_tile = coord
        reduction = merge_before - merge_after
        pct = (100 * reduction // max(merge_before, 1)) if merge_before > 0 else 0
        print(f"\n=== MERGE POTENTIAL (MERGE_BY_MATERIAL=True) ===")
        print(f"  Tile-local meshes    : {merge_before}")
        print(f"  After material merge : {merge_after}")
        print(f"  Draw call reduction  : {reduction} ({pct}%)")
        unique_keys = set()
        for coord, tile_objs in tile_assignments.items():
            for obj in tile_objs:
                if obj.type == 'MESH' and obj.data is not None:
                    unique_keys.add(material_merge_key(obj))
        print(f"  Unique material keys : {len(unique_keys)}")
        if best_reduction_tile:
            tx, ty, tz = best_reduction_tile
            print(f"  Best tile            : tile_{tx}_{ty}_{tz} "
                  f"({best_reduction_count} objects merged away)")

    # Shared bucket summary
    print(f"\n=== SHARED BUCKET SUMMARY ===")
    print(f"  Shared objects      : {len(shared_names)}")
    print(f"  Future-split flagged: {len(split_names)}")
    if shared_objects:
        shared_total = sum(
            estimate_object_memory_bytes(obj, mesh_size_cache)
            for obj in shared_objects
        )
        print(f"  Shared est. memory  : {format_bytes(shared_total)}")
        by_ratio = sorted(shared_names + split_names,
                          key=lambda n: classification_map[n]["dim_ratio"], reverse=True)
        print(f"  Largest by dim_ratio: {by_ratio[:10]}")

    print(f"\n=== OVERALL SUMMARY ===")
    total = len(classification_map)
    print(f"  Total objects       : {total}")
    print(f"  Local               : {len(local_names)} ({100*len(local_names)//max(total,1)}%)")
    print(f"  Shared bucket       : {len(shared_names)}")
    print(f"  Future-split        : {len(split_names)}")
    if classification_map:
        overlaps = [r["xz_overlap_count"] for r in classification_map.values()]
        print(f"  Avg XZ overlap      : {sum(overlaps)/len(overlaps):.1f}")
        print(f"  Max XZ overlap      : {max(overlaps)}")


# ============================================================
# SECTION 15: PARALLEL TILE EXPORT
# ============================================================

def _total_system_memory_bytes() -> int:
    """Best-effort total physical RAM in bytes, used only to cap auto worker
    count. Falls back to a conservative 8 GiB estimate if it can't be
    determined, which just means the auto cap picks fewer workers.
    """
    try:
        output = subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True)
        return int(output.strip())
    except (OSError, ValueError, subprocess.CalledProcessError):
        pass
    try:
        return os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
    except (ValueError, OSError, AttributeError):
        return 8 * 1024 ** 3


def _ram_based_worker_cap(source_scene_path: str) -> int:
    """Cap auto worker count so N concurrent full-scene reloads don't exceed
    a safe fraction of system RAM.

    Pure heuristic: estimates per-worker memory as a multiple of the source
    file's on-disk size (larger multiple when material baking is enabled,
    since Cycles holds full-resolution image buffers per worker), then
    divides the RAM budget by that estimate. Always returns at least 1.
    """
    try:
        file_size = os.path.getsize(source_scene_path) if source_scene_path else 0
    except OSError:
        file_size = 0

    per_worker_estimate = max(
        file_size * AUTO_WORKER_SCENE_MEMORY_MULTIPLIER,
        AUTO_WORKER_MIN_ESTIMATE_BYTES,
    )
    if BAKE_MATERIALS:
        per_worker_estimate *= AUTO_WORKER_BAKE_MEMORY_MULTIPLIER

    budget = _total_system_memory_bytes() * AUTO_WORKER_RAM_SAFETY_FRACTION
    return max(1, int(budget // per_worker_estimate))


def _effective_worker_count(n_tiles: int, source_scene_path: str = "") -> int:
    """Return the number of Blender worker processes to use.

    PARALLEL_WORKERS=0 → auto (half of cpu_count, capped at 8, at n_tiles,
        and at a memory-safe estimate derived from source_scene_path -- see
        _ram_based_worker_cap).
    PARALLEL_WORKERS=1 → sequential (no subprocesses).
    PARALLEL_WORKERS=N → exactly N workers (capped to n_tiles only --
        bypasses the memory-safe estimate since it was requested explicitly).
    Always returns at least 1.
    """
    if PARALLEL_WORKERS == 1 or n_tiles <= 1:
        return 1
    if PARALLEL_WORKERS > 1:
        return min(PARALLEL_WORKERS, n_tiles)
    # Auto: cap at 8 workers and at n_tiles so we never spawn more workers
    # than there are tiles to export.
    cpu = os.cpu_count() or 2
    cpu_cap = min(max(cpu // 2, 1), 8, n_tiles)
    ram_cap = _ram_based_worker_cap(source_scene_path)
    workers = max(1, min(cpu_cap, ram_cap))
    if ram_cap < cpu_cap:
        print(
            f"  Auto parallel export: capping to {workers} worker(s) based on "
            f"estimated memory usage (cpu-based cap was {cpu_cap}). "
            f"Override with --parallel-workers N.",
            flush=True,
        )
    return workers


def _config_snapshot() -> dict:
    """Capture all export-relevant config globals into a serialisable dict."""
    return {
        "EXPORT_FORMAT":       EXPORT_FORMAT,
        "CONVERT_ORIENTATION": CONVERT_ORIENTATION,
        "SOURCE_ORIENTATION":  SOURCE_ORIENTATION,
        "CLIP_LOCAL_MESHES":   CLIP_LOCAL_MESHES,
        "MERGE_BY_MATERIAL":   MERGE_BY_MATERIAL,
        "NO_MERGE_PREFIX":     NO_MERGE_PREFIX,
        "BAKE_WORLD_TRANSFORMS": BAKE_WORLD_TRANSFORMS,
        "SPLIT_CLIP_EPSILON":  SPLIT_CLIP_EPSILON,
        "DEBUG_AABB_ONLY":     DEBUG_AABB_ONLY,
        "COMPRESS_GEOMETRY":   COMPRESS_GEOMETRY,
        "BAKE_MATERIALS":      BAKE_MATERIALS,
        "BAKE_RESOLUTION":     BAKE_RESOLUTION,
        "BAKE_CACHE":          BAKE_CACHE,
    }


def _apply_bundle_config(cfg: dict) -> None:
    """Restore config globals in a worker process from a bundle dict."""
    global EXPORT_FORMAT, CONVERT_ORIENTATION, SOURCE_ORIENTATION
    global CLIP_LOCAL_MESHES, MERGE_BY_MATERIAL, NO_MERGE_PREFIX, BAKE_WORLD_TRANSFORMS
    global SPLIT_CLIP_EPSILON, DEBUG_AABB_ONLY, COMPRESS_GEOMETRY
    global BAKE_MATERIALS, BAKE_RESOLUTION, BAKE_CACHE
    EXPORT_FORMAT         = cfg.get("EXPORT_FORMAT",         EXPORT_FORMAT)
    CONVERT_ORIENTATION   = cfg.get("CONVERT_ORIENTATION",   CONVERT_ORIENTATION)
    SOURCE_ORIENTATION    = cfg.get("SOURCE_ORIENTATION",    SOURCE_ORIENTATION)
    CLIP_LOCAL_MESHES     = cfg.get("CLIP_LOCAL_MESHES",     CLIP_LOCAL_MESHES)
    MERGE_BY_MATERIAL     = cfg.get("MERGE_BY_MATERIAL",     MERGE_BY_MATERIAL)
    NO_MERGE_PREFIX       = cfg.get("NO_MERGE_PREFIX",       NO_MERGE_PREFIX)
    BAKE_WORLD_TRANSFORMS = cfg.get("BAKE_WORLD_TRANSFORMS", BAKE_WORLD_TRANSFORMS)
    SPLIT_CLIP_EPSILON    = cfg.get("SPLIT_CLIP_EPSILON",    SPLIT_CLIP_EPSILON)
    DEBUG_AABB_ONLY       = cfg.get("DEBUG_AABB_ONLY",       DEBUG_AABB_ONLY)
    COMPRESS_GEOMETRY     = cfg.get("COMPRESS_GEOMETRY",     COMPRESS_GEOMETRY)
    BAKE_MATERIALS        = cfg.get("BAKE_MATERIALS",        BAKE_MATERIALS)
    BAKE_RESOLUTION       = cfg.get("BAKE_RESOLUTION",       BAKE_RESOLUTION)
    BAKE_CACHE            = cfg.get("BAKE_CACHE",            BAKE_CACHE)


def _run_worker_mode(work_bundle_path: str, result_file_path: str) -> None:
    """Worker entry point.  Called inside a Blender subprocess.

    Loads the work bundle, imports the source scene, then exports each
    assigned tile, writing a result JSON when done.
    """
    with open(work_bundle_path, "r", encoding="utf-8") as f:
        bundle = json.load(f)

    source_scene_path = bundle.get("source_scene_path", "")
    if source_scene_path and is_usd_filepath(source_scene_path):
        clear_scene()
        import_usd_asset(Path(source_scene_path))
    elif source_scene_path and is_blend_filepath(source_scene_path):
        # Worker subprocesses always start from a fresh --factory-startup
        # scene, so there is no already-open .blend to guard against here
        # (unlike the same branch in run()).
        load_blend_scene(Path(source_scene_path))

    _apply_bundle_config(bundle.get("config", {}))

    active_hlod_levels = bundle.get("active_hlod_levels", [])
    active_lod_levels  = bundle.get("active_lod_levels",  [])
    progress_file = bundle.get("progress_file")
    ext = EXPORT_FORMAT.lower().lstrip(".")

    tile_results = []
    tile_specs = bundle.get("tiles", [])
    total_assets = sum(
        1
        + len(tile_spec.get("active_hlod_levels", active_hlod_levels))
        + len(tile_spec.get("active_lod_levels", active_lod_levels))
        for tile_spec in tile_specs
    )
    completed_assets = 0
    append_worker_progress(progress_file, {
        "event": "start",
        "total_assets": total_assets,
        "completed_assets": completed_assets,
    })
    for tile_spec in tile_specs:
        tile_id     = tile_spec["tile_id"]
        tx          = tile_spec["tx"]
        ty          = tile_spec["ty"]
        tz          = tile_spec["tz"]
        filepath    = tile_spec["filepath"]
        tile_bounds = tile_spec["tile_bounds"]
        obj_names   = tile_spec["object_names"]
        tile_hlod_levels = tile_spec.get("active_hlod_levels", active_hlod_levels)
        tile_lod_levels = tile_spec.get("active_lod_levels", active_lod_levels)

        objects = [bpy.data.objects.get(n) for n in obj_names]
        objects = [o for o in objects if o is not None]
        missing = len(obj_names) - len(objects)
        if missing:
            print(f"  Warning: {missing} object(s) not found in scene for {tile_id}", flush=True)

        if DEBUG_AABB_ONLY:
            color = tile_debug_color(tx, ty, tz)
            print(f"[DEBUG_AABB] {tile_id} → {filepath}", flush=True)
            try:
                ok, error = export_debug_aabb(filepath, tile_bounds, color)
            except Exception as ex:
                ok, error = False, str(ex)
        else:
            print(f"Exporting {tile_id} ({len(objects)} objects) → {filepath}", flush=True)
            try:
                ok, error = export_local_tile(filepath, objects, tile_bounds, source_scene_path)
            except Exception as ex:
                ok, error = False, str(ex)

        if not ok:
            print(f"  FAILED: {error}", flush=True)

        file_sz = os.path.getsize(filepath) if ok and os.path.isfile(filepath) else 0
        completed_assets += 1
        append_worker_progress(progress_file, {
            "event": "asset_done",
            "asset": tile_id,
            "ok": ok,
            "completed_assets": completed_assets,
            "total_assets": total_assets,
        })

        hlod_results = []
        if ok and not DEBUG_AABB_ONLY:
            for level in tile_hlod_levels:
                hlod_filepath = os.path.join(
                    os.path.dirname(filepath),
                    f"{tile_id}{level['suffix']}.{ext}",
                )
                print(
                    f"  Exporting HLOD {os.path.basename(hlod_filepath)} "
                    f"(ratio={level['reduction_ratio']:.3f}, switch={level['switch_distance']:.1f})",
                    flush=True,
                )
                try:
                    hlod_ok, hlod_error = export_hlod_tile(
                        hlod_filepath, objects, tile_bounds,
                        level["reduction_ratio"], source_scene_path, "hlod",
                    )
                except Exception as ex:
                    hlod_ok, hlod_error = False, str(ex)
                if not hlod_ok:
                    print(f"    HLOD FAILED: {hlod_error}", flush=True)
                completed_assets += 1
                append_worker_progress(progress_file, {
                    "event": "asset_done",
                    "asset": os.path.basename(hlod_filepath),
                    "ok": hlod_ok,
                    "completed_assets": completed_assets,
                    "total_assets": total_assets,
                })
                hlod_results.append({
                    "ok":              hlod_ok,
                    "error":           hlod_error,
                    "filepath":        hlod_filepath,
                    "switch_distance": level["switch_distance"],
                })

        lod_results = []
        if ok and not DEBUG_AABB_ONLY:
            for lod_idx, lod in enumerate(tile_lod_levels):
                lod_n        = lod_idx + 1
                lod_filepath = os.path.join(
                    os.path.dirname(filepath),
                    f"{tile_id}_lod{lod_n}.{ext}",
                )
                print(
                    f"  Exporting LOD{lod_n} {os.path.basename(lod_filepath)} "
                    f"(ratio={lod['ratio']:.3f}, switch={lod['switch_distance']:.1f})",
                    flush=True,
                )
                try:
                    lod_ok, lod_error = export_hlod_tile(
                        lod_filepath, objects, tile_bounds,
                        lod["ratio"], source_scene_path, "lod",
                    )
                except Exception as ex:
                    lod_ok, lod_error = False, str(ex)
                if not lod_ok:
                    print(f"    LOD{lod_n} FAILED: {lod_error}", flush=True)
                completed_assets += 1
                append_worker_progress(progress_file, {
                    "event": "asset_done",
                    "asset": os.path.basename(lod_filepath),
                    "ok": lod_ok,
                    "completed_assets": completed_assets,
                    "total_assets": total_assets,
                })
                lod_results.append({
                    "ok":              lod_ok,
                    "error":           lod_error,
                    "filepath":        lod_filepath,
                    "switch_distance": lod["switch_distance"],
                })

        tile_results.append({
            "tile_id":        tile_id,
            "ok":             ok,
            "error":          error,
            "file_size_bytes": file_sz,
            "hlod_results":   hlod_results,
            "lod_results":    lod_results,
        })

    with open(result_file_path, "w", encoding="utf-8") as f:
        json.dump({"tile_results": tile_results}, f, indent=2)
    append_worker_progress(progress_file, {
        "event": "complete",
        "completed_assets": total_assets,
        "total_assets": total_assets,
    })


def _poll_worker_progress(worker_info, progress_offsets, progress_seen, reporter):
    for worker_index, _proc, _log_path, _result_path, progress_path in worker_info:
        if not progress_path or not os.path.isfile(progress_path):
            continue
        offset = progress_offsets.get(progress_path, 0)
        try:
            with open(progress_path, "r", encoding="utf-8") as f:
                f.seek(offset)
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    completed = int(event.get("completed_assets", 0))
                    previous = progress_seen.get(worker_index, 0)
                    if completed > previous:
                        delta = completed - previous
                        progress_seen[worker_index] = completed
                        detail = event.get("asset", f"worker {worker_index:02d}")
                        reporter.advance("Export assets", f"worker {worker_index:02d}: {detail}", delta)
                progress_offsets[progress_path] = f.tell()
        except OSError:
            continue


def _export_tiles_parallel(
    sorted_tiles,
    source_scene_path,
    output_dir,
    active_hlod_levels,
    active_lod_levels,
    origin_x, origin_y, origin_z,
    tile_size_x, tile_size_y, tile_size_z,
):
    """Spawn Blender worker subprocesses to export tiles in parallel.

    Returns a dict {tile_id: result_dict} on success, or None if parallel
    export is not applicable (too few tiles, PARALLEL_WORKERS=1, etc.).
    """
    non_empty = [(coord, objs) for coord, objs in sorted_tiles if objs]
    n_workers = _effective_worker_count(len(non_empty), source_scene_path)
    if n_workers <= 1:
        return None  # caller falls back to sequential

    print(f"\nParallel tile export: {len(non_empty)} tiles across {n_workers} workers")

    ext = EXPORT_FORMAT.lower().lstrip(".")

    # Build per-tile specs, sort by object count descending for load balancing.
    tile_specs = []
    for (tx, ty, tz), tile_objs in non_empty:
        tile_id     = f"tile_{tx}_{ty}_{tz}"
        filepath    = os.path.join(output_dir, f"{tile_id}.{ext}")
        tile_bounds = tile_bounds_from_coord(
            tx, ty, tz, origin_x, origin_y, origin_z,
            tile_size_x, tile_size_y, tile_size_z,
        )
        tile_specs.append({
            "tile_id":      tile_id,
            "tx": tx, "ty": ty, "tz": tz,
            "filepath":     filepath,
            "tile_bounds":  tile_bounds,
            "object_names": [o.name for o in tile_objs],
        })
    tile_specs.sort(key=lambda s: len(s["object_names"]), reverse=True)

    # Distribute round-robin so large tiles are spread across workers.
    batches: list[list] = [[] for _ in range(n_workers)]
    for i, spec in enumerate(tile_specs):
        batches[i % n_workers].append(spec)

    cfg          = _config_snapshot()
    tmpdir       = tempfile.mkdtemp(prefix="untold_tile_parallel_")
    blender_bin  = getattr(bpy.app, "binary_path", sys.executable)
    script_path  = os.path.abspath(__file__)

    total_assets = sum(1 + len(active_hlod_levels) + len(active_lod_levels) for _ in tile_specs)
    progress = ProgressReporter("parallel tile export", total_assets)

    # (worker_index, proc, log_path, result_path, progress_path)
    worker_info: list[tuple] = []

    try:
        for i, batch in enumerate(batches):
            if not batch:
                continue
            bundle = {
                "source_scene_path": source_scene_path,
                "config":            cfg,
                "active_hlod_levels": active_hlod_levels,
                "active_lod_levels":  active_lod_levels,
                "tiles":             batch,
            }
            bundle_path = os.path.join(tmpdir, f"worker_{i:02d}_bundle.json")
            result_path = os.path.join(tmpdir, f"worker_{i:02d}_result.json")
            log_path    = os.path.join(tmpdir, f"worker_{i:02d}.log")
            progress_path = os.path.join(tmpdir, f"worker_{i:02d}_progress.jsonl")
            with open(bundle_path, "w", encoding="utf-8") as f:
                bundle["progress_file"] = progress_path
                json.dump(bundle, f)

            cmd = [
                blender_bin, "--background", "--factory-startup",
                "--python", script_path,
                "--", "--worker-mode",
                "--work-bundle", bundle_path,
                "--result-file",  result_path,
            ]
            # Write worker output to a log file instead of a pipe.  With a pipe,
            # workers printing thousands of per-object lines fill the OS pipe
            # buffer (~64 KB) and block until the parent drains it — which only
            # happens after each preceding worker finishes.  That serializes all
            # workers and eliminates the speedup.  Log files have no such limit.
            log_fh = open(log_path, "w", encoding="utf-8")
            proc = subprocess.Popen(
                cmd,
                stdout=log_fh,
                stderr=subprocess.STDOUT,
            )
            log_fh.close()   # Parent's fd is no longer needed; child has its own copy.
            worker_info.append((i, proc, log_path, result_path, progress_path))
            print(f"  Launched worker {i:02d} ({len(batch)} tiles, pid={proc.pid})")

        # Wait for all workers to finish (true parallel: all stdout goes to files,
        # so no process ever blocks on a full pipe buffer).
        progress_offsets: dict[str, int] = {}
        progress_seen: dict[int, int] = {}
        while any(proc.poll() is None for _i, proc, _log_path, _result_path, _progress_path in worker_info):
            _poll_worker_progress(worker_info, progress_offsets, progress_seen, progress)
            time.sleep(0.5)
        _poll_worker_progress(worker_info, progress_offsets, progress_seen, progress)

        all_results: dict[str, dict] = {}
        for i, proc, log_path, result_path, _progress_path in worker_info:
            proc.wait()
            prefix = f"[worker {i:02d}] "
            try:
                with open(log_path, "r", encoding="utf-8") as f:
                    for line in f:
                        print(f"{prefix}{line.rstrip()}", flush=True)
            except OSError:
                pass

            if os.path.isfile(result_path):
                with open(result_path, "r", encoding="utf-8") as f:
                    result = json.load(f)
                for tr in result.get("tile_results", []):
                    all_results[tr["tile_id"]] = tr
            else:
                print(
                    f"  Warning: worker {i:02d} produced no result file "
                    f"(exit={proc.returncode}). Its tiles will be marked failed."
                )

        return all_results

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _export_quadtree_tiles_parallel(
    sorted_groups,
    source_scene_path,
    output_dir,
    ext,
    active_hlod_levels=None,
    active_lod_levels=None,
):
    """Spawn Blender worker subprocesses to export quadtree tile-tier pairs in parallel.

    Reuses the same bundle/worker protocol as _export_tiles_parallel.
    tile_bounds is set to None for all quadtree tiles; the worker passes it
    straight through to export_local_tile which skips clipping when
    CLIP_LOCAL_MESHES=False (the quadtree default).

    active_hlod_levels / active_lod_levels are forwarded to each worker so that
    HLOD and LOD variants are generated for tiles whose tier warrants it.

    Returns a dict {tile_id: result_dict} on success, or None when parallel
    export is not applicable (PARALLEL_WORKERS=1 or too few tiles).
    """
    non_empty = [(key, objs) for key, objs in sorted_groups if objs]
    n_workers = _effective_worker_count(len(non_empty), source_scene_path)
    if n_workers <= 1:
        return None  # caller falls back to sequential

    print(f"\nParallel quadtree export: {len(non_empty)} tile-tier pairs across {n_workers} workers")

    # Build one spec per quadtree tile. tx/ty/tz are dummies (only used by
    # tile_debug_color in DEBUG_AABB_ONLY mode, which is never active in
    # quadtree runs). tile_bounds=None tells the worker not to clip.
    tile_specs = []
    for (node_id, tier), tile_objs in non_empty:
        tile_id  = quadtree_tile_id(node_id, tier)
        filepath = os.path.join(output_dir, f"{tile_id}.{ext}")
        tile_specs.append({
            "tile_id":      tile_id,
            "tx": 0, "ty": 0, "tz": 0,
            "filepath":     filepath,
            "tile_bounds":  None,
            "object_names": [o.name for o in tile_objs],
        })
    # Sort largest tiles first for better load-balance across workers.
    tile_specs.sort(key=lambda s: len(s["object_names"]), reverse=True)

    # Distribute round-robin so large tiles are spread across workers.
    batches: list[list] = [[] for _ in range(n_workers)]
    for i, spec in enumerate(tile_specs):
        batches[i % n_workers].append(spec)

    cfg         = _config_snapshot()
    tmpdir      = tempfile.mkdtemp(prefix="untold_qt_parallel_")
    blender_bin = getattr(bpy.app, "binary_path", sys.executable)
    script_path = os.path.abspath(__file__)

    total_assets = sum(1 + len(active_hlod_levels or []) + len(active_lod_levels or []) for _ in tile_specs)
    progress = ProgressReporter("parallel quadtree export", total_assets)

    # (worker_index, proc, log_path, result_path, progress_path)
    worker_info: list[tuple] = []

    try:
        for i, batch in enumerate(batches):
            if not batch:
                continue
            bundle = {
                "source_scene_path": source_scene_path,
                "config":            cfg,
                "active_hlod_levels": active_hlod_levels or [],
                "active_lod_levels":  active_lod_levels or [],
                "tiles":             batch,
            }
            bundle_path = os.path.join(tmpdir, f"worker_{i:02d}_bundle.json")
            result_path = os.path.join(tmpdir, f"worker_{i:02d}_result.json")
            log_path    = os.path.join(tmpdir, f"worker_{i:02d}.log")
            progress_path = os.path.join(tmpdir, f"worker_{i:02d}_progress.jsonl")
            with open(bundle_path, "w", encoding="utf-8") as f:
                bundle["progress_file"] = progress_path
                json.dump(bundle, f)

            cmd = [
                blender_bin, "--background", "--factory-startup",
                "--python", script_path,
                "--", "--worker-mode",
                "--work-bundle", bundle_path,
                "--result-file",  result_path,
            ]
            # Write worker output to a log file instead of a pipe.  Quadtree
            # tiles can contain thousands of objects; the exporter prints one
            # line per mesh, which quickly overflows the OS pipe buffer (~64 KB)
            # and blocks every worker that isn't actively being read by the
            # parent.  Log files remove this bottleneck entirely.
            log_fh = open(log_path, "w", encoding="utf-8")
            proc = subprocess.Popen(
                cmd,
                stdout=log_fh,
                stderr=subprocess.STDOUT,
            )
            log_fh.close()   # Parent's fd is no longer needed; child has its own copy.
            worker_info.append((i, proc, log_path, result_path, progress_path))
            print(f"  Launched worker {i:02d} ({len(batch)} tiles, pid={proc.pid})")

        # Wait for all workers to finish (true parallel: stdout goes to files,
        # so no process ever blocks on a full pipe buffer).
        progress_offsets: dict[str, int] = {}
        progress_seen: dict[int, int] = {}
        while any(proc.poll() is None for _i, proc, _log_path, _result_path, _progress_path in worker_info):
            _poll_worker_progress(worker_info, progress_offsets, progress_seen, progress)
            time.sleep(0.5)
        _poll_worker_progress(worker_info, progress_offsets, progress_seen, progress)

        all_results: dict[str, dict] = {}
        for i, proc, log_path, result_path, _progress_path in worker_info:
            proc.wait()
            prefix = f"[worker {i:02d}] "
            try:
                with open(log_path, "r", encoding="utf-8") as f:
                    for line in f:
                        print(f"{prefix}{line.rstrip()}", flush=True)
            except OSError:
                pass

            if os.path.isfile(result_path):
                with open(result_path, "r", encoding="utf-8") as f:
                    result = json.load(f)
                for tr in result.get("tile_results", []):
                    all_results[tr["tile_id"]] = tr
            else:
                print(
                    f"  Warning: worker {i:02d} produced no result file "
                    f"(exit={proc.returncode}). Its tiles will be marked failed."
                )

        return all_results

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


# ============================================================
# SECTION 16: SAMPLE FILTER (TEMPORARY)
# ============================================================

def filter_tile_assignments_sample(tile_assignments, origin_x, origin_z,
                                    tile_size_x, tile_size_z, sample_fraction):
    """Keep a contiguous rectangular patch of tiles closest to the world origin.

    Finds the tile coordinate that contains world point (0, 0) in XZ, then
    expands a square window outward until the tile count reaches approximately
    sample_fraction of the full set.  All ty (height) values are included so
    multi-floor scenes are not accidentally truncated.

    Returns a filtered copy of tile_assignments.
    """
    if not tile_assignments:
        return tile_assignments

    target_count = max(1, int(math.ceil(len(tile_assignments) * sample_fraction)))

    # Tile coordinate that contains the world origin in XZ.
    cx_tile = int(math.floor((0.0 - origin_x) / tile_size_x))
    cz_tile = int(math.floor((0.0 - origin_z) / tile_size_z))

    # Clamp to the coordinate range that actually exists.
    all_coords = list(tile_assignments.keys())
    min_tx = min(c[0] for c in all_coords)
    max_tx = max(c[0] for c in all_coords)
    min_tz = min(c[2] for c in all_coords)
    max_tz = max(c[2] for c in all_coords)
    cx_tile = max(min_tx, min(max_tx, cx_tile))
    cz_tile = max(min_tz, min(max_tz, cz_tile))

    # Expand the square window until we reach the target tile count.
    half = 0
    max_half = max(max_tx - min_tx, max_tz - min_tz) + 1
    while True:
        candidates = {
            coord: objs for coord, objs in tile_assignments.items()
            if (cx_tile - half) <= coord[0] <= (cx_tile + half)
            and (cz_tile - half) <= coord[2] <= (cz_tile + half)
        }
        if len(candidates) >= target_count or half >= max_half:
            break
        half += 1

    print(
        f"\nSAMPLE_MODE: keeping {len(candidates)}/{len(tile_assignments)} tiles "
        f"({100 * len(candidates) // max(len(tile_assignments), 1)}%) in a "
        f"{2*half+1}×{2*half+1} XZ patch centred on tile ({cx_tile},*,{cz_tile}) "
        f"[nearest to world origin (0,0,0)]"
    )
    return candidates


def filter_node_tier_groups_sample(node_tier_groups, metadata_map, sample_fraction):
    """Keep only a fraction of quadtree node-tier groups for fast iteration.

    Nodes are sorted shallowest-first (fewest '_' separators in the node_id),
    then alphabetically within the same depth.  Keeping the shallowest nodes
    first produces a low-resolution sample that covers the whole scene rather
    than a deep sub-tree of one corner — better for visual validation.

    All tiers belonging to a kept node are included so the tile set remains
    internally consistent.

    Returns a filtered copy of node_tier_groups.
    """
    if not node_tier_groups:
        return node_tier_groups

    unique_nodes = sorted(
        {node_id for node_id, _tier in node_tier_groups},
        key=lambda nid: (nid.count("_"), nid),
    )
    target = max(1, int(math.ceil(len(unique_nodes) * sample_fraction)))
    kept_nodes = set(unique_nodes[:target])

    filtered = {
        key: objs
        for key, objs in node_tier_groups.items()
        if key[0] in kept_nodes
    }
    dropped = len(node_tier_groups) - len(filtered)
    print(
        f"\nSAMPLE_MODE (quadtree): keeping {len(kept_nodes)}/{len(unique_nodes)} nodes "
        f"({100 * len(kept_nodes) // max(len(unique_nodes), 1)}%) → "
        f"{len(filtered)} tile-tier pairs ({dropped} dropped)"
    )
    return filtered


def filter_tile_assignments_perimeter(tile_assignments, depth=1):
    """Keep only the outer shell of tiles up to `depth` tiles inward from the boundary.

    Pass 1 — identify the strict perimeter: tiles with at least one absent
    cardinal XZ neighbour.  Pass 2..depth — grow the shell inward by one ring
    per iteration, keeping any occupied tile that neighbours the current shell.
    All ty (height) values for a kept (tx, tz) are preserved so multi-floor
    buildings are not truncated.

    depth=1  strict single-ring perimeter (original behaviour)
    depth=2+ also keeps tiles up to N rings inward, capturing thick walls
             whose mesh AABBs extend deeper into the building interior.
    """
    if not tile_assignments:
        return tile_assignments

    depth = max(1, depth)
    occupied_xz = {(coord[0], coord[2]) for coord in tile_assignments}

    # Pass 1: strict perimeter — tiles with at least one empty cardinal neighbour.
    shell = set()
    for (tx, tz) in occupied_xz:
        neighbours = [(tx + 1, tz), (tx - 1, tz), (tx, tz + 1), (tx, tz - 1)]
        if any(n not in occupied_xz for n in neighbours):
            shell.add((tx, tz))

    # Pass 2..depth: grow inward one ring at a time.
    kept_xz = set(shell)
    for _ in range(depth - 1):
        next_ring = set()
        for (tx, tz) in occupied_xz - kept_xz:
            neighbours = [(tx + 1, tz), (tx - 1, tz), (tx, tz + 1), (tx, tz - 1)]
            if any(n in kept_xz for n in neighbours):
                next_ring.add((tx, tz))
        if not next_ring:
            break
        kept_xz |= next_ring

    filtered = {
        coord: objs for coord, objs in tile_assignments.items()
        if (coord[0], coord[2]) in kept_xz
    }

    interior_dropped = len(occupied_xz) - len(kept_xz)
    print(
        f"\nPERIMETER_MODE: keeping {len(filtered)}/{len(tile_assignments)} tiles "
        f"({100 * len(filtered) // max(len(tile_assignments), 1)}%) — "
        f"depth={depth}, {interior_dropped} interior XZ positions dropped"
    )
    return filtered


# ============================================================
# SECTION 17: MAIN
# ============================================================

def run():
    print_export_stage("Resolve input")
    source_scene_path = resolve_source_scene_path()
    if ERROR_IF_UNSAVED_SOURCE_NOT_FOUND and not bpy.data.filepath and not source_scene_path:
        raise RuntimeError(
            "Unsaved .blend and no USD source path found. "
            "Set SOURCE_SCENE_PATH_OVERRIDE to your .usd/.usdz path."
        )

    # When an explicit USD/USDZ/.blend input is provided, use that asset as the
    # source scene content for partitioning. This makes the CLI behave like the
    # single-asset exporter instead of operating on Blender's current scene
    # contents (for example the default startup cube under --factory-startup).
    if source_scene_path and is_usd_filepath(source_scene_path):
        print_export_stage("Import source scene", os.path.basename(source_scene_path))
        clear_scene()
        import_usd_asset(Path(source_scene_path))
    elif source_scene_path and is_blend_filepath(source_scene_path) and not bpy.data.filepath:
        # bpy.data.filepath is only empty here when this .blend came from the
        # --input override rather than already being the open file (see
        # resolve_source_scene_path), so this never redundantly reopens the
        # scene the addon is already running inside of.
        print_export_stage("Open source scene", os.path.basename(source_scene_path))
        load_blend_scene(Path(source_scene_path))

    print_export_stage("Prepare output")
    output_dir = resolve_output_dir(OUTPUT_DIR, source_scene_path)
    model_dir  = os.path.dirname(os.path.normpath(output_dir)) or output_dir
    hlod_levels_config = validate_hlod_levels() if GENERATE_HLOD else []
    active_hlod_levels = [] if DEBUG_AABB_ONLY else hlod_levels_config
    lod_levels_config  = validate_lod_levels() if GENERATE_LOD else []
    active_lod_levels  = [] if DEBUG_AABB_ONLY else lod_levels_config

    if DEBUG_AABB_ONLY and (GENERATE_HLOD or GENERATE_LOD):
        print("DEBUG_AABB_ONLY=True: HLOD/LOD export disabled for this run.")

    if not DRY_RUN or DRY_RUN_WRITE_MANIFEST:
        ensure_dir(output_dir)
        ensure_dir(model_dir)
    else:
        print("DRY_RUN enabled: no files will be written.")

    # Color management is scene-wide (one View Transform per Blender scene), so
    # bake it once here rather than per-tile.
    color_management_bake = None
    if BAKE_COLOR_MANAGEMENT and (not DRY_RUN or DRY_RUN_WRITE_MANIFEST):
        print_export_stage("Bake color management")
        color_management_bake = bake_color_management_lut(COLOR_LUT_SIZE, Path(output_dir) / "Textures")

    # The world/studio-light HDR environment is scene-wide too, so stage it
    # once here rather than per-tile -- same reasoning as color management.
    staged_hdr_assets: list[Path] = []
    if not DRY_RUN or DRY_RUN_WRITE_MANIFEST:
        print_export_stage("Stage HDR environment")
        if source_scene_path:
            hdr_asset_path = Path(source_scene_path)
        elif bpy.data.filepath:
            # The add-on forces source_scene_path to "" to skip re-importing
            # the already-open scene, but the .blend may still be saved --
            # use its real path so relative ("//") HDR image references
            # resolve correctly, same as the single-asset export flow.
            hdr_asset_path = Path(bpy.data.filepath)
        else:
            hdr_asset_path = Path(output_dir)
        staged_hdr_assets = stage_hdr_assets_for_output(Path(output_dir), hdr_asset_path)

    # ------------------------------------------------------------------
    # Gather objects and compute world bounds
    # ------------------------------------------------------------------
    print_export_stage("Analyze scene")
    warn_skipped_animated_objects()
    objects = get_candidate_objects()
    if not objects:
        print("No mesh objects found.")
        return

    object_bounds = compute_object_bounds(objects)
    scene_bounds  = scene_world_bounds(objects)   # Blender (X, Y_depth, Z_height)

    # Origins for tile coordinate mapping.
    # Snap to the nearest world-aligned tile boundary so grid cells are always
    # multiples of tile_size from the world origin.  Without this, the grid
    # anchors at scene_min and objects near the origin end up in the corner of
    # their tile rather than inside a stable, predictable cell.
    origin_y = scene_bounds["min"][2]  # Blender Z height → tile Y

    # ------------------------------------------------------------------
    # Tile sizing (manual or auto)
    # ------------------------------------------------------------------
    print_export_stage("Plan tile sizes")
    if AUTO_TILE_SIZE:
        tile_size_x, tile_size_z, auto_info = choose_auto_tile_size(
            objects, object_bounds, scene_bounds, origin_y, TILE_SIZE_Y
        )[:3]
        tile_size_y = TILE_SIZE_Y
        print(
            f"Auto tile size: {tile_size_x:.2f} × {tile_size_z:.2f}  "
            f"(tiles≈{auto_info['estimated_tile_count']}, "
            f"max_obj/tile={auto_info['max_objects_in_tile']}, "
            f"iters={auto_info['iterations_used']})"
        )
        if not auto_info["met_target_max_tiles"]:
            print("Warning: auto sizing could not reach target tile count.")
        if not auto_info["met_target_objects_per_tile"]:
            print("Warning: auto sizing could not reach objects-per-tile target.")
    else:
        tile_size_x, tile_size_y, tile_size_z = TILE_SIZE_X, TILE_SIZE_Y, TILE_SIZE_Z
        auto_info = None

    origin_x = math.floor(scene_bounds["min"][0] / tile_size_x) * tile_size_x  # Blender X
    origin_z = math.floor(scene_bounds["min"][1] / tile_size_z) * tile_size_z  # Blender Y depth → tile Z

    base_tile = max(tile_size_x, tile_size_z)

    # ------------------------------------------------------------------
    # Streaming defaults (tile-local)
    # ------------------------------------------------------------------
    scene_half_diag = 0.5 * math.sqrt(
        (scene_bounds["max"][0] - scene_bounds["min"][0]) ** 2 +
        (scene_bounds["max"][1] - scene_bounds["min"][1]) ** 2
    )
    streaming_r, unload_r = compute_streaming_defaults(base_tile, scene_half_diag)
    # When the user has explicitly configured tier radii, honour them for the
    # uniform-grid representation ladder too.  Without this, LOD/HLOD switch
    # distances are computed against the narrow auto-computed defaults
    # (e.g. 38/57 m for a 22 m tile) even though the user set 80/150 m, which
    # produces ~4 m bands that are visually instantaneous.  ExteriorShell is the
    # dominant tier for outdoor/city scenes; fall back to StructuralInterior if
    # only that override is present.
    _grid_override = (
        TIER_RADIUS_OVERRIDES.get("ExteriorShell")
        or TIER_RADIUS_OVERRIDES.get("StructuralInterior")
    )
    if _grid_override:
        _ov_s = _grid_override.get("streaming", 0.0)
        _ov_u = _grid_override.get("unload", 0.0)
        if _ov_s > 0.0 and _ov_u > _ov_s:
            streaming_r, unload_r = _ov_s, _ov_u
    shared_r, shared_ur   = compute_shared_streaming_radii(scene_half_diag)

    # Resolve a default representation ladder for progress accounting and logs.
    # Manifest tile entries are resolved again using each tile's tier-specific
    # streaming/unload radii.
    default_hlod_levels = compute_hlod_switch_distances(
        streaming_r,
        unload_r,
        active_hlod_levels,
    )
    default_lod_levels = compute_lod_switch_distances(
        streaming_r,
        unload_r,
        default_hlod_levels,
        active_lod_levels,
    )
    if default_hlod_levels or default_lod_levels:
        print(
            "Resolved default streaming ladder: "
            f"stream={streaming_r:.2f}, unload={unload_r:.2f}, "
            f"HLOD={[l['switch_distance'] for l in default_hlod_levels]}, "
            f"LOD={[l['switch_distance'] for l in default_lod_levels]}"
        )

    # ------------------------------------------------------------------
    # Classify and assign
    # ------------------------------------------------------------------
    print_export_stage("Classify objects")
    pre_annotated    = has_quadtree_metadata(objects)
    use_kdtree       = FORCE_KDTREE and not pre_annotated
    use_quadtree     = pre_annotated or FORCE_QUADTREE or FORCE_KDTREE
    node_tier_groups = None  # populated only in quadtree/kdtree path
    metadata_map     = {}
    inline_metadata  = {}

    if use_quadtree:
        if pre_annotated:
            print("Quadtree metadata detected — using floor+quadtree partitioning.")
            if FORCE_KDTREE:
                print("  WARNING: --kdtree was passed but pre-annotated quadtree metadata "
                      "takes precedence. The manifest will contain partitioning_mode='quadtree_floor'. "
                      "Re-export without pre-annotated metadata to use KD-tree partitioning.")
        elif use_kdtree:
            print("--kdtree flag set — running inline KD-tree annotation pass...")
            inline_metadata = compute_inline_kdtree_metadata(objects, object_bounds)
        else:
            print("--quadtree flag set — running inline quadtree annotation pass...")
            inline_metadata = compute_inline_quadtree_metadata(objects, object_bounds)

        node_tier_groups, shared_objects, metadata_map = build_quadtree_assignments(
            objects, object_bounds, inline_metadata=inline_metadata
        )
        if SAMPLE_MODE:
            node_tier_groups = filter_node_tier_groups_sample(
                node_tier_groups, metadata_map, SAMPLE_FRACTION
            )
        # Build a dummy tile_assignments so PERIMETER filters and
        # dry-run diagnostics do not crash.  The real export uses node_tier_groups.
        tile_assignments  = {}
        classification_map = {}
        mode_str = "KD-tree" if use_kdtree else "Quadtree"
        print(
            f"{mode_str} groups: {len(node_tier_groups)} tile-tier pairs, "
            f"{len(shared_objects)} shared-bucket objects"
        )
        print_node_tier_group_quality("Final partition", node_tier_groups)
    else:
        print("No quadtree metadata detected — using uniform grid partitioning.")
        tile_assignments, shared_objects, classification_map = build_assignments(
            objects, object_bounds,
            origin_x, origin_y, origin_z,
            tile_size_x, tile_size_y, tile_size_z,
        )

    if SAMPLE_MODE:
        tile_assignments = filter_tile_assignments_sample(
            tile_assignments, origin_x, origin_z,
            tile_size_x, tile_size_z, SAMPLE_FRACTION,
        )
    if PERIMETER_MODE:
        tile_assignments = filter_tile_assignments_perimeter(tile_assignments, depth=PERIMETER_DEPTH)

    # Spanning objects are only ever routed to per-tile local export when
    # CLIP_LOCAL_MESHES is also on — see the comment on SPLIT_SPANNING_OBJECTS.
    split_spanning_active = SPLIT_SPANNING_OBJECTS and CLIP_LOCAL_MESHES
    local_count   = sum(1 for r in classification_map.values() if r["policy"] == "local_overlap")
    spanning_routed = sum(
        1 for r in classification_map.values()
        if split_spanning_active
        and r["policy"] in ("shared_bucket", "future_split_candidate")
        and r["xz_overlap_count"] <= SPLIT_MAX_TILES
    )
    capped_count = sum(
        1 for r in classification_map.values()
        if r["policy"] in ("shared_bucket", "future_split_candidate")
        and (not split_spanning_active or r["xz_overlap_count"] > SPLIT_MAX_TILES)
    )
    if SPLIT_SPANNING_OBJECTS and not CLIP_LOCAL_MESHES and capped_count:
        print(
            "  Note: SPLIT_SPANNING_OBJECTS is on but CLIP_LOCAL_MESHES is off — "
            "spanning objects stay in the shared bucket rather than being "
            "duplicated whole into every overlapping tile."
        )
    print(
        f"Classification: {len(objects)} objects → "
        f"{local_count} local"
        + (f", {spanning_routed} spanning→tiles, {capped_count} spanning→shared bucket"
           f" (SPLIT_MAX_TILES={SPLIT_MAX_TILES})"
           if split_spanning_active else f", {capped_count} spanning→shared bucket")
    )

    # ------------------------------------------------------------------
    # Resolve streaming profile and build per-tier radius table
    # ------------------------------------------------------------------
    resolved_profile = infer_streaming_profile(
        use_quadtree, node_tier_groups, scene_half_diag, base_tile
    )
    init_tier_radii(scene_half_diag, resolved_profile)
    log_streaming_profile(scene_bounds, scene_half_diag, resolved_profile)

    # ------------------------------------------------------------------
    # Scene name and manifest path
    # ------------------------------------------------------------------
    scene_name = sanitize_name(
        os.path.splitext(os.path.basename(source_scene_path))[0]
        if source_scene_path else os.path.basename(model_dir)
    )
    manifest_path      = os.path.join(model_dir, f"{scene_name}.json")
    shared_bucket_name = f"{scene_name}_shared"
    ext                = EXPORT_FORMAT.lower().lstrip(".")
    shared_filepath    = os.path.join(output_dir, f"{shared_bucket_name}.{ext}")

    # ------------------------------------------------------------------
    # Derive tile_size from actual tile extents (quadtree / KD-tree only)
    # ------------------------------------------------------------------
    # For quadtree and KD-tree exports the config constants TILE_SIZE_X/Z are
    # only used for spanning classification — they are not the footprint of the
    # produced tiles.  Actual tile sizes are determined by spatial partitioning
    # and can be far smaller (often 1–10 m vs the 25 m constant).
    #
    # The engine reads tile_size to calibrate the static batch cell size.  A
    # 25 m cell derived from the constant would contain hundreds of tiny tiles,
    # routinely exceeding the per-cell complexity guard and leaving large regions
    # permanently unbatched.
    #
    # Fix: measure the 90th-percentile XZ extent of the tiles that were actually
    # produced and write that as tile_size.  The p90 excludes the top 10% of
    # large coarse tiles (root-level ExteriorShell stubs that span whole floors)
    # while still sizing the cell large enough to contain most leaf tiles fully.
    # Uniform-grid tile_size_x/z are correct as-is and are left unchanged.
    if use_quadtree and node_tier_groups:
        extents = []
        for tile_objs in node_tier_groups.values():
            if not tile_objs:
                continue
            aabb = compute_objects_aabb_usd(tile_objs, object_bounds)
            if aabb is None:
                continue
            # USD space: X=Blender X, Y=height, Z=depth.  Footprint = XZ.
            dx = abs(aabb["max"][0] - aabb["min"][0])
            dz = abs(aabb["max"][2] - aabb["min"][2])
            extents.append(max(dx, dz))
        if extents:
            extents.sort()
            p90_idx = min(int(len(extents) * 0.90), len(extents) - 1)
            derived = max(extents[p90_idx], 1.0)   # floor at 1 m
            tile_size_x = derived
            tile_size_z = derived
            print(
                f"  [tile_size] Derived from {len(extents)} tiles: "
                f"median={extents[len(extents)//2]:.1f}m  "
                f"p90={derived:.1f}m  → tile_size={derived:.1f}m "
                f"(was {TILE_SIZE_X:.1f}m)"
            )

    # ------------------------------------------------------------------
    # Build manifest skeleton
    # ------------------------------------------------------------------
    # scene_bounds stored in USD space (X, Y_up, -Z)
    sb_usd = aabb_to_usd_space({
        "min": (scene_bounds["min"][0], scene_bounds["min"][1], scene_bounds["min"][2]),
        "max": (scene_bounds["max"][0], scene_bounds["max"][1], scene_bounds["max"][2]),
    })
    scene_lights, scene_cameras = collect_manifest_scene_payload()

    manifest = {
        "version": 4 if use_quadtree else 3,
        "partitioning_mode": "kdtree_floor" if use_kdtree else ("quadtree_floor" if use_quadtree else "uniform_grid"),
        "dry_run": DRY_RUN,
        "debug_aabb_only": DEBUG_AABB_ONLY,
        "source_scene_name": os.path.basename(source_scene_path) if source_scene_path else None,
        "payload_dir_relative_to_manifest": os.path.relpath(output_dir, model_dir),
        "axis_convention": {"up": "+Y", "forward": "+Z", "tile_plane": "XZ"},
        "tile_size_mode": "auto" if AUTO_TILE_SIZE else "manual",
        "tile_size": {"x": tile_size_x, "y": tile_size_y, "z": tile_size_z},
        "scene_bounds": {"min": list(sb_usd["min"]), "max": list(sb_usd["max"])},
        "scene_lights": scene_lights,
        "scene_cameras": scene_cameras,
        "colorLUT": _manifest_color_management_payload(color_management_bake, model_dir),
        "streaming_profile": {
            "requested": SCENE_STREAMING_PROFILE,
            "resolved": resolved_profile,
            "scene_half_diag": round(scene_half_diag, 3),
            "tier_radius_overrides": TIER_RADIUS_OVERRIDES,
            "tier_radii": _ACTIVE_TIER_RADII,
        },
        "streaming_defaults": {
            "streaming_radius": streaming_r,
            "unload_radius": unload_r,
            "priority": DEFAULT_STREAMING_PRIORITY,
        },
        "classification_config": {
            "spanning_threshold_tiles": SPANNING_THRESHOLD_TILES,
            "overlap_threshold": OVERLAP_THRESHOLD,
            "future_split_tile_threshold": FUTURE_SPLIT_TILE_THRESHOLD,
        },
        "partition_quality_config": {
            "collapse_underfilled_tile_tiers": (
                bool(INLINE_COLLAPSE_UNDERFILLED_TILE_TIERS)
                if use_quadtree and not pre_annotated else False
            ),
            "min_objects_per_tile_tier": INLINE_MIN_OBJECTS_PER_TILE_TIER,
            "applies_to_preannotated_metadata": False,
        },
        "hlod_generation": {
            "enabled": bool(active_hlod_levels),
            "levels": active_hlod_levels,
            "default_resolved_levels": default_hlod_levels,
        },
        "lod_generation": {
            "enabled": bool(active_lod_levels),
            "levels": [
                {"decimate_ratio": l["ratio"], "switch_distance": l["switch_distance"]}
                for l in active_lod_levels
            ],
            "default_resolved_levels": [
                {"decimate_ratio": l["ratio"], "switch_distance": l["switch_distance"]}
                for l in default_lod_levels
            ],
        },
        "object_classification": {
            name: {
                "export_policy":    r["policy"],
                "xz_overlap_count": r["xz_overlap_count"],
                "dimensions":       r["dimensions"],
                "dim_ratio":        r["dim_ratio"],
                "reasons":          r["reasons"],
            }
            for name, r in classification_map.items()
        },
        "shared_bucket": None,
        "failed_tiles": [],
        "tiles": [],
    }

    # ------------------------------------------------------------------
    # Memory estimation helpers
    # ------------------------------------------------------------------
    mesh_size_cache    = {}
    tile_coverage_counts = build_tile_coverage_counts(tile_assignments)

    # ------------------------------------------------------------------
    # DRY RUN: report and optionally write manifest
    # ------------------------------------------------------------------
    if DRY_RUN:
        if use_quadtree and node_tier_groups is not None:
            # Quadtree dry-run: summarise groups and build manifest without exporting.
            mode_label = "kdtree_floor" if use_kdtree else "quadtree_floor"
            print(f"\n=== {mode_label.upper()} DRY-RUN SUMMARY ===")
            print(f"  Partitioning mode : {mode_label}")
            print(f"  Tile-tier pairs   : {len(node_tier_groups)}")
            print(f"  Shared-bucket objs: {len(shared_objects)}")
            by_tier = {}
            for (node_id, tier), objs in node_tier_groups.items():
                by_tier.setdefault(tier, 0)
                by_tier[tier] += len(objs)
            for tier, count in sorted(by_tier.items()):
                radii = tier_streaming_radii(tier)
                print(f"    {tier:25s}: {count:5d} objects  "
                      f"stream={radii.get('streaming','?')}m  "
                      f"unload={radii.get('unload','?')}m")
            spanning_secondary_count = sum(
                1
                for (_node_id, tier), objs in node_tier_groups.items()
                if objs and tier in HLOD_LOD_TIERS and group_has_spanning_metadata(objs, metadata_map)
            )
            if spanning_secondary_count:
                print(
                    f"  Secondary reps    : {spanning_secondary_count} spanning tile-tier pair(s) "
                    "will receive LOD/HLOD (same ladder as leaf tiles)"
                )

            if use_kdtree:
                # KD-tree leaf balance report — shows whether the tree is producing
                # evenly-sized tiles or whether a few leaves are disproportionately large.
                leaf_sizes = {}   # node_id → (object_count, est_memory_bytes)
                for (node_id, tier), tile_objs in node_tier_groups.items():
                    est = sum(estimate_object_memory_bytes(o, mesh_size_cache)
                              for o in tile_objs)
                    prev = leaf_sizes.get(node_id, (0, 0))
                    leaf_sizes[node_id] = (prev[0] + len(tile_objs), prev[1] + est)
                if leaf_sizes:
                    counts = [v[0] for v in leaf_sizes.values()]
                    mems   = [v[1] for v in leaf_sizes.values()]
                    print(f"\n  KD-tree leaf balance ({len(leaf_sizes)} leaves):")
                    print(f"    objects/leaf  — max={max(counts)}  "
                          f"avg={sum(counts)/len(counts):.1f}  min={min(counts)}")
                    print(f"    memory/leaf   — max={max(mems)//1024//1024}mb  "
                          f"avg={sum(mems)/len(mems)/1024/1024:.1f}mb")
                    top = sorted(leaf_sizes.items(), key=lambda x: -x[1][0])[:5]
                    print(f"  Top-5 heaviest leaves (by object count):")
                    for nid, (cnt, mem) in top:
                        print(f"    {nid}: {cnt} objects, "
                              f"~{mem//1024//1024}mb")
            for (node_id, tier), tile_objs in sorted(node_tier_groups.items()):
                if not tile_objs:
                    continue
                tile_id   = quadtree_tile_id(node_id, tier)
                filepath  = os.path.join(output_dir, f"{tile_id}.{ext}")
                aabb_usd  = compute_objects_aabb_usd(tile_objs, object_bounds)
                cell_aabb_usd = node_cell_bounds_aabb_usd(
                    group_cell_bounds_xy(tile_objs, metadata_map),
                    tile_objs,
                    object_bounds,
                )
                center    = aabb_center(aabb_usd) if aabb_usd else [0,0,0]
                est_mem   = sum(estimate_object_memory_bytes(o, mesh_size_cache)
                                for o in tile_objs)
                tier_radii   = tier_streaming_radii(tier)
                tile_stream  = tier_radii.get("streaming", streaming_r)
                tile_unload  = tier_radii.get("unload",    unload_r)
                tile_priority = aggregate_priority_hint(
                    tile_objs,
                    tier_radii.get("priority", DEFAULT_STREAMING_PRIORITY),
                )
                is_spanning_group = group_has_spanning_metadata(tile_objs, metadata_map)
                tier_wants_hlod_lod = tier in HLOD_LOD_TIERS
                tile_hlod_levels, tile_lod_levels = resolve_tile_representation_levels(
                    tile_stream,
                    tile_unload,
                    active_hlod_levels if tier_wants_hlod_lod else [],
                    active_lod_levels if tier_wants_hlod_lod else [],
                )
                floor_id = 0
                for obj in tile_objs:
                    m = metadata_map.get(obj.name)
                    if m:
                        floor_id = m["floor_id"]
                        break
                manifest["tiles"].append({
                    "tile_id":   tile_id,
                    "floor_id":  floor_id,
                    "quadtree_node_id": node_id,
                    "semantic_tier":    tier,
                    "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
                    "streaming_radius": tile_stream,
                    "unload_radius":    tile_unload,
                    "priority":         tile_priority,
                    "hlod_levels": [
                        {
                            "path": os.path.relpath(
                                os.path.join(output_dir, f"{tile_id}{level['suffix']}.{ext}"),
                                model_dir,
                            ),
                            "switch_distance": level["switch_distance"],
                        }
                        for level in tile_hlod_levels
                    ],
                    "lod_levels": [
                        {
                            "path": os.path.relpath(
                                os.path.join(output_dir, f"{tile_id}_lod{lod_idx + 1}.{ext}"),
                                model_dir,
                            ),
                            "switch_distance": lod["switch_distance"],
                        }
                        for lod_idx, lod in enumerate(tile_lod_levels)
                    ],
                    "interior": tier != "ExteriorShell",
                    "file_size_bytes": 0,
                    "estimated_memory_bytes": est_mem,
                    "bounds": {"min": list(aabb_usd["min"]), "max": list(aabb_usd["max"])}
                              if aabb_usd else {"min": [0,0,0], "max": [0,0,0]},
                    "cell_bounds": {"min": list(cell_aabb_usd["min"]), "max": list(cell_aabb_usd["max"])}
                                   if cell_aabb_usd else (
                                       {"min": list(aabb_usd["min"]), "max": list(aabb_usd["max"])}
                                       if aabb_usd else {"min": [0,0,0], "max": [0,0,0]}
                                   ),
                    "secondary_representation_policy": "none_spanning_group" if is_spanning_group else "normal",
                    "center": list(center),
                    "object_count": len(tile_objs),
                })
            if DRY_RUN_WRITE_MANIFEST:
                with open(manifest_path, "w", encoding="utf-8") as f:
                    json.dump(manifest, f, indent=2)
                print(f"Dry-run manifest written to: {manifest_path}")
            else:
                print("DRY_RUN_WRITE_MANIFEST=False: manifest not written.")
            return

        print_dry_run_report(
            tile_assignments, shared_objects, classification_map,
            object_bounds, tile_size_x, tile_size_z,
            mesh_size_cache, tile_coverage_counts,
            scene_bounds=scene_bounds,
        )

        # Populate manifest tiles for dry-run output
        for (tx, ty, tz), tile_objs in sorted(tile_assignments.items()):
            if not tile_objs:
                continue
            tile_bounds = tile_bounds_from_coord(
                tx, ty, tz, origin_x, origin_y, origin_z,
                tile_size_x, tile_size_y, tile_size_z,
            )
            tile_id  = f"tile_{tx}_{ty}_{tz}"
            filepath = os.path.join(output_dir, f"{tile_id}.{ext}")
            aabb_usd = tile_bounds_aabb_usd(tile_bounds)
            center   = aabb_center(aabb_usd)
            est_mem  = estimate_tile_memory(tile_objs, tile_coverage_counts, mesh_size_cache)
            tile_priority = aggregate_priority_hint(tile_objs, DEFAULT_STREAMING_PRIORITY)
            tile_entry = {
                "tile_id": tile_id,
                "grid_coord": [tx, ty, tz],
                "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
                "priority": tile_priority,
                "hlod_levels": [
                    {
                        "path": os.path.relpath(
                            os.path.join(output_dir, f"{tile_id}{level['suffix']}.{ext}"),
                            model_dir,
                        ),
                        "switch_distance": level["switch_distance"],
                    }
                    for level in default_hlod_levels
                ],
                "file_size_bytes": 0,
                "estimated_memory_bytes": est_mem,
                "bounds": {"min": list(aabb_usd["min"]), "max": list(aabb_usd["max"])},
                "center": list(center),
                "object_count": len(tile_objs),
                "objects": [o.name for o in tile_objs],
            }
            if default_lod_levels:
                tile_entry["lod_levels"] = [
                    {
                        "path": os.path.relpath(
                            os.path.join(output_dir, f"{tile_id}_lod{lod_idx + 1}.{ext}"),
                            model_dir,
                        ),
                        "switch_distance": lod["switch_distance"],
                    }
                    for lod_idx, lod in enumerate(default_lod_levels)
                ]
            manifest["tiles"].append(tile_entry)

        if shared_objects:
            shared_aabb     = scene_world_bounds(shared_objects)
            shared_aabb_usd = aabb_to_usd_space(shared_aabb) if shared_aabb else None
            shared_center   = aabb_center(shared_aabb_usd) if shared_aabb_usd else [0,0,0]
            shared_est_mem  = sum(estimate_object_memory_bytes(o, mesh_size_cache)
                                  for o in shared_objects)
            shared_priority = aggregate_priority_hint(shared_objects, DEFAULT_STREAMING_PRIORITY)
            manifest["shared_bucket"] = {
                "tile_id": "shared",
                "path_relative_to_manifest": os.path.relpath(shared_filepath, model_dir),
                "export_policy": "shared_bucket",
                "streaming_radius": shared_r,
                "unload_radius": shared_ur,
                "priority": shared_priority,
                "file_size_bytes": 0,
                "estimated_memory_bytes": shared_est_mem,
                "bounds": ({"min": list(shared_aabb_usd["min"]),
                            "max": list(shared_aabb_usd["max"])}
                           if shared_aabb_usd else None),
                "center": list(shared_center),
                "object_count": len(shared_objects),
                "objects": [
                    {
                        "name": obj.name,
                        "export_policy": classification_map[obj.name]["policy"],
                        "xz_overlap_count": classification_map[obj.name]["xz_overlap_count"],
                        "dimensions": classification_map[obj.name]["dimensions"],
                        "reasons": classification_map[obj.name]["reasons"],
                    }
                    for obj in shared_objects
                ],
            }

        create_tile_preview(tile_assignments, shared_objects,
                            origin_x, origin_y, origin_z,
                            tile_size_x, tile_size_y, tile_size_z)

        if DRY_RUN_WRITE_MANIFEST:
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=2)
            print(f"Dry-run manifest written to: {manifest_path}")
        else:
            print("DRY_RUN_WRITE_MANIFEST=False: manifest not written.")
        return

    # ------------------------------------------------------------------
    # FULL EXPORT
    # ------------------------------------------------------------------
    planned_local_assets = 0
    if use_quadtree and node_tier_groups is not None:
        non_empty_groups = sum(1 for _key, tile_objs in node_tier_groups.items() if tile_objs)
        quadtree_parallel = _effective_worker_count(non_empty_groups, source_scene_path) > 1
        for (_node_id, tier), tile_objs in node_tier_groups.items():
            if not tile_objs:
                continue
            planned_local_assets += 1
            if tier in HLOD_LOD_TIERS:
                planned_local_assets += len(active_hlod_levels) + len(active_lod_levels)
    else:
        non_empty_tiles = sum(1 for _coord, tile_objs in tile_assignments.items() if tile_objs)
        planned_local_assets = non_empty_tiles * (1 + len(active_hlod_levels) + len(active_lod_levels))
    export_progress = ProgressReporter(
        "tile export",
        (1 if shared_objects else 0) + planned_local_assets + 1,
        on_progress=PROGRESS_CALLBACK,
    )
    export_progress.stage("Start", f"{planned_local_assets} tile asset(s), {len(shared_objects)} shared object(s)")

    # --- Export shared bucket ---
    if shared_objects:
        print(f"\nExporting shared bucket ({len(shared_objects)} objects) → {shared_filepath}")
        try:
            ok, error = export_shared_bucket(shared_filepath, shared_objects, source_scene_path)
        except Exception as ex:
            ok, error = False, str(ex)

        if not ok:
            print(f"  FAILED: {error}")
            export_progress.advance("Shared bucket failed", str(error))
        else:
            shared_aabb     = scene_world_bounds(shared_objects)
            shared_aabb_usd = aabb_to_usd_space(shared_aabb) if shared_aabb else None
            shared_center   = aabb_center(shared_aabb_usd) if shared_aabb_usd else [0,0,0]
            shared_file_sz  = os.path.getsize(shared_filepath) if os.path.isfile(shared_filepath) else 0
            shared_est_mem  = sum(estimate_object_memory_bytes(o, mesh_size_cache)
                                  for o in shared_objects)
            shared_priority = aggregate_priority_hint(shared_objects, DEFAULT_STREAMING_PRIORITY)
            manifest["shared_bucket"] = {
                "tile_id": "shared",
                "path_relative_to_manifest": os.path.relpath(shared_filepath, model_dir),
                "export_policy": "shared_bucket",
                "streaming_radius": shared_r,
                "unload_radius": shared_ur,
                "priority": shared_priority,
                "file_size_bytes": shared_file_sz,
                "estimated_memory_bytes": shared_est_mem,
                "bounds": ({"min": list(shared_aabb_usd["min"]),
                            "max": list(shared_aabb_usd["max"])}
                           if shared_aabb_usd else None),
                "center": list(shared_center),
                "object_count": len(shared_objects),
                "objects": [
                    (
                        {
                            "name": obj.name,
                            "export_policy": classification_map[obj.name]["policy"],
                            "xz_overlap_count": classification_map[obj.name]["xz_overlap_count"],
                            "dimensions": classification_map[obj.name]["dimensions"],
                            "reasons": classification_map[obj.name]["reasons"],
                        }
                        if obj.name in classification_map
                        else {"name": obj.name}
                    )
                    for obj in shared_objects
                ],
            }
            export_progress.advance("Shared bucket", os.path.basename(shared_filepath))

    # ------------------------------------------------------------------
    # QUADTREE EXPORT PATH
    # ------------------------------------------------------------------
    if use_quadtree and node_tier_groups is not None:
        qt_exported = 0
        # Sort groups for deterministic output: floor first, then node, then tier.
        sorted_groups = sorted(node_tier_groups.items(), key=lambda kv: kv[0])

        # Attempt parallel export; falls back to None when PARALLEL_WORKERS=1
        # or there are too few tiles to justify subprocesses.
        qt_parallel_results = None
        if not active_hlod_levels and not active_lod_levels:
            qt_parallel_results = _export_quadtree_tiles_parallel(
                sorted_groups,
                source_scene_path,
                output_dir,
                ext,
                active_hlod_levels=[],
                active_lod_levels=[],
            )

        for (node_id, tier), tile_objs in sorted_groups:
            if not tile_objs:
                continue

            tile_id   = quadtree_tile_id(node_id, tier)
            filepath  = os.path.join(output_dir, f"{tile_id}.{ext}")
            aabb_usd  = compute_objects_aabb_usd(tile_objs, object_bounds)
            cell_aabb_usd = node_cell_bounds_aabb_usd(
                group_cell_bounds_xy(tile_objs, metadata_map),
                tile_objs,
                object_bounds,
            )
            center    = aabb_center(aabb_usd) if aabb_usd else [0.0, 0.0, 0.0]
            est_mem   = sum(estimate_object_memory_bytes(o, mesh_size_cache)
                            for o in tile_objs)

            # Fetch per-tier streaming radii; fall back to scene defaults.
            tier_radii   = tier_streaming_radii(tier)
            tile_stream  = tier_radii.get("streaming", streaming_r)
            tile_unload  = tier_radii.get("unload",    unload_r)
            tile_priority = aggregate_priority_hint(
                tile_objs,
                tier_radii.get("priority", DEFAULT_STREAMING_PRIORITY),
            )

            # Derive a representative floor_id from the objects in this group.
            floor_id = 0
            for obj in tile_objs:
                m = metadata_map.get(obj.name)
                if m is not None:
                    floor_id = m["floor_id"]
                    break

            # HLOD/LOD is only useful for tiers with radii large enough to form a
            # meaningful switch band (ExteriorShell, StructuralInterior).
            is_spanning_group = group_has_spanning_metadata(tile_objs, metadata_map)
            tier_wants_hlod_lod = tier in HLOD_LOD_TIERS
            tile_hlod_levels, tile_lod_levels = resolve_tile_representation_levels(
                tile_stream,
                tile_unload,
                active_hlod_levels if tier_wants_hlod_lod else [],
                active_lod_levels if tier_wants_hlod_lod else [],
            )

            if qt_parallel_results is not None:
                # --- Parallel path: tile was exported by a worker subprocess ---
                result  = qt_parallel_results.get(tile_id)
                ok      = bool(result and result.get("ok"))
                error   = result.get("error") if result else "Worker did not report a result"
                file_sz = result.get("file_size_bytes", 0) if result else 0
                hlod_entries = [
                    {
                        "path": os.path.relpath(r["filepath"], model_dir),
                        "switch_distance": tile_hlod_levels[idx]["switch_distance"],
                    }
                    for idx, r in enumerate(result.get("hlod_results", []) if result else [])
                    if r.get("ok")
                    and idx < len(tile_hlod_levels)
                ]
                lod_entries = [
                    {
                        "path": os.path.relpath(r["filepath"], model_dir),
                        "switch_distance": tile_lod_levels[idx]["switch_distance"],
                    }
                    for idx, r in enumerate(result.get("lod_results", []) if result else [])
                    if r.get("ok")
                    and idx < len(tile_lod_levels)
                ]
            else:
                # --- Sequential path ---
                print(
                    f"[QT] Exporting {tile_id}  floor={floor_id}  tier={tier} "
                    f"({len(tile_objs)} objects)  stream={tile_stream:.1f}m → {filepath}"
                )
                # tile_bounds is None (CLIP_LOCAL_MESHES is False for quadtree mode).
                try:
                    ok, error = export_local_tile(filepath, tile_objs, None, source_scene_path)
                except Exception as ex:
                    ok, error = False, str(ex)
                file_sz = os.path.getsize(filepath) if ok and os.path.isfile(filepath) else 0

                hlod_entries = []
                lod_entries  = []
                if ok and tier_wants_hlod_lod:
                    for level in tile_hlod_levels:
                        hlod_filename = f"{tile_id}{level['suffix']}.{ext}"
                        hlod_filepath = os.path.join(output_dir, hlod_filename)
                        print(
                            f"  [QT] HLOD {hlod_filename} "
                            f"(ratio={level['reduction_ratio']:.3f}, switch={level['switch_distance']:.1f}m)"
                        )
                        try:
                            hlod_ok, hlod_err = export_hlod_tile(
                                hlod_filepath, tile_objs, None,
                                level["reduction_ratio"], source_scene_path, "hlod",
                            )
                        except Exception as ex:
                            hlod_ok, hlod_err = False, str(ex)
                        if not hlod_ok:
                            print(f"    HLOD FAILED: {hlod_err}")
                            continue
                        hlod_entries.append({
                            "path": os.path.relpath(hlod_filepath, model_dir),
                            "switch_distance": level["switch_distance"],
                        })

                    for lod_idx, lod in enumerate(tile_lod_levels):
                        lod_n        = lod_idx + 1
                        lod_filename = f"{tile_id}_lod{lod_n}.{ext}"
                        lod_filepath = os.path.join(output_dir, lod_filename)
                        print(
                            f"  [QT] LOD{lod_n} {lod_filename} "
                            f"(ratio={lod['ratio']:.3f}, switch={lod['switch_distance']:.1f}m)"
                        )
                        try:
                            lod_ok, lod_err = export_hlod_tile(
                                lod_filepath, tile_objs, None,
                                lod["ratio"], source_scene_path, "lod",
                            )
                        except Exception as ex:
                            lod_ok, lod_err = False, str(ex)
                        if not lod_ok:
                            print(f"    LOD{lod_n} FAILED: {lod_err}")
                            continue
                        lod_entries.append({
                            "path": os.path.relpath(lod_filepath, model_dir),
                            "switch_distance": lod["switch_distance"],
                        })

            if not ok:
                print(f"  FAILED ({tile_id}): {error}")
                manifest["failed_tiles"].append({
                    "tile_id":  tile_id,
                    "quadtree_node_id": node_id,
                    "semantic_tier":    tier,
                    "floor_id":         floor_id,
                    "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
                    "error": error,
                    "candidate_object_count": len(tile_objs),
                })
                export_progress.advance("Tile failed", tile_id)
                continue

            tile_entry = {
                "tile_id":   tile_id,
                "floor_id":  floor_id,
                "quadtree_node_id": node_id,
                "semantic_tier":    tier,
                "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
                "streaming_radius": tile_stream,
                "unload_radius":    tile_unload,
                "priority":         tile_priority,
                "hlod_levels": hlod_entries,
                "lod_levels":  lod_entries,
                "interior": tier != "ExteriorShell",
                "file_size_bytes":       file_sz,
                "estimated_memory_bytes": est_mem,
                "bounds": {"min": list(aabb_usd["min"]), "max": list(aabb_usd["max"])}
                          if aabb_usd else {"min": [0,0,0], "max": [0,0,0]},
                "cell_bounds": {"min": list(cell_aabb_usd["min"]), "max": list(cell_aabb_usd["max"])}
                               if cell_aabb_usd else (
                                   {"min": list(aabb_usd["min"]), "max": list(aabb_usd["max"])}
                                   if aabb_usd else {"min": [0,0,0], "max": [0,0,0]}
                               ),
                "secondary_representation_policy": "none_spanning_group" if is_spanning_group else "normal",
                "center": list(center),
                "object_count": len(tile_objs),
            }
            manifest["tiles"].append(tile_entry)
            qt_exported += 1
            export_progress.advance("Tile assets", tile_id, 1 + len(hlod_entries) + len(lod_entries))

        # --- Compute interior_zone: union AABB of all ExteriorShell tiles.
        # Falls back to ExteriorShell objects in the shared bucket when no
        # ExteriorShell tiles were created (e.g. the exterior shell spans the
        # full scene footprint and was routed to shared_objects).
        # The engine uses this to gate interior tile loading: tiles tagged
        # interior=True only stream in when the camera is inside this volume.
        exterior_tiles = [t for t in manifest["tiles"] if not t.get("interior", True)]
        if exterior_tiles:
            iz_min = [min(t["bounds"]["min"][i] for t in exterior_tiles) for i in range(3)]
            iz_max = [max(t["bounds"]["max"][i] for t in exterior_tiles) for i in range(3)]
            manifest["interior_zone"] = {"min": iz_min, "max": iz_max}
        else:
            # No ExteriorShell tiles — look for ExteriorShell objects in the
            # shared bucket (they span the scene so they weren't tiled).
            es_bounds = []
            for obj in shared_objects:
                meta = metadata_map.get(obj.name)
                if meta and _resolve_tier(meta) == "ExteriorShell":
                    b = object_bounds.get(obj.name)
                    if b:
                        es_bounds.append(b)
            if es_bounds:
                bl_min = (
                    min(b["min"][0] for b in es_bounds),
                    min(b["min"][1] for b in es_bounds),
                    min(b["min"][2] for b in es_bounds),
                )
                bl_max = (
                    max(b["max"][0] for b in es_bounds),
                    max(b["max"][1] for b in es_bounds),
                    max(b["max"][2] for b in es_bounds),
                )
                iz_aabb = aabb_to_usd_space({"min": bl_min, "max": bl_max})
                manifest["interior_zone"] = {
                    "min": list(iz_aabb["min"]),
                    "max": list(iz_aabb["max"]),
                }
                print(
                    f"[interior_zone] Derived from {len(es_bounds)} shared-bucket "
                    f"ExteriorShell object(s): "
                    f"{iz_aabb['min']} → {iz_aabb['max']}"
                )
            else:
                manifest["interior_zone"] = None

        # --- Write manifest for quadtree path ---
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
        export_progress.advance("Write manifest", os.path.basename(manifest_path))

        print(f"\nQuadtree export done. {qt_exported} tile-tier pairs exported.")
        if manifest["failed_tiles"]:
            print(f"Failed: {len(manifest['failed_tiles'])}")
        if manifest["shared_bucket"]:
            print(f"Shared bucket: {manifest['shared_bucket']['object_count']} objects.")
        print(f"Manifest written to: {manifest_path}")
        return  # done — do not fall through to the grid export path

    # --- Export local tiles ---
    exported_count = 0
    sorted_tiles   = sorted(tile_assignments.items(),
                            key=lambda item: (item[0][2], item[0][1], item[0][0]))

    # Attempt parallel export; falls back to None when PARALLEL_WORKERS=1
    # or there are too few tiles to justify subprocesses.
    parallel_results = _export_tiles_parallel(
        sorted_tiles,
        source_scene_path,
        output_dir,
        default_hlod_levels,
        default_lod_levels,
        origin_x, origin_y, origin_z,
        tile_size_x, tile_size_y, tile_size_z,
    )

    for (tx, ty, tz), tile_objs in sorted_tiles:
        if not tile_objs:
            continue

        tile_id     = f"tile_{tx}_{ty}_{tz}"
        filepath    = os.path.join(output_dir, f"{tile_id}.{ext}")
        tile_bounds = tile_bounds_from_coord(
            tx, ty, tz, origin_x, origin_y, origin_z,
            tile_size_x, tile_size_y, tile_size_z,
        )
        aabb_usd  = tile_bounds_aabb_usd(tile_bounds)
        center    = aabb_center(aabb_usd)
        est_mem   = estimate_tile_memory(tile_objs, tile_coverage_counts, mesh_size_cache)
        tile_priority = aggregate_priority_hint(tile_objs, DEFAULT_STREAMING_PRIORITY)

        if parallel_results is not None:
            # --- Parallel path: tile was exported by a worker subprocess ---
            result = parallel_results.get(tile_id)
            if result is None or not result["ok"]:
                error = result["error"] if result else "Worker did not report a result"
                print(f"  FAILED ({tile_id}): {error}")
                manifest["failed_tiles"].append({
                    "tile_id": tile_id,
                    "grid_coord": [tx, ty, tz],
                    "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
                    "error": error,
                    "candidate_object_count": len(tile_objs),
                })
                export_progress.advance("Tile failed", tile_id)
                continue

            hlod_entries = [
                {
                    "path": os.path.relpath(r["filepath"], model_dir),
                    "switch_distance": r["switch_distance"],
                }
                for r in result.get("hlod_results", []) if r["ok"]
            ]
            lod_entries = [
                {
                    "path": os.path.relpath(r["filepath"], model_dir),
                    "switch_distance": r["switch_distance"],
                }
                for r in result.get("lod_results", []) if r["ok"]
            ]
            file_sz = result.get("file_size_bytes", 0)

        else:
            # --- Sequential path ---
            if DEBUG_AABB_ONLY:
                color = tile_debug_color(tx, ty, tz)
                print(f"[DEBUG_AABB] {tile_id} → {filepath}")
                try:
                    ok, error = export_debug_aabb(filepath, tile_bounds, color)
                except Exception as ex:
                    ok, error = False, str(ex)
            else:
                print(f"Exporting {tile_id} ({len(tile_objs)} objects) → {filepath}")
                try:
                    ok, error = export_local_tile(filepath, tile_objs, tile_bounds, source_scene_path)
                except Exception as ex:
                    ok, error = False, str(ex)

            if not ok:
                print(f"  FAILED: {error}")
                manifest["failed_tiles"].append({
                    "tile_id": tile_id,
                    "grid_coord": [tx, ty, tz],
                    "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
                    "error": error,
                    "candidate_object_count": len(tile_objs),
                })
                export_progress.advance("Tile failed", tile_id)
                continue

            hlod_entries = []
            for level in default_hlod_levels:
                hlod_filename = f"{tile_id}{level['suffix']}.{ext}"
                hlod_filepath = os.path.join(output_dir, hlod_filename)
                print(
                    f"  Exporting HLOD {hlod_filename} "
                    f"(ratio={level['reduction_ratio']:.3f}, switch={level['switch_distance']:.1f})"
                )
                try:
                    hlod_ok, hlod_error = export_hlod_tile(
                        hlod_filepath, tile_objs, tile_bounds,
                        level["reduction_ratio"], source_scene_path, "hlod",
                    )
                except Exception as ex:
                    hlod_ok, hlod_error = False, str(ex)
                if not hlod_ok:
                    print(f"    HLOD FAILED: {hlod_error}")
                    continue
                hlod_entries.append({
                    "path": os.path.relpath(hlod_filepath, model_dir),
                    "switch_distance": level["switch_distance"],
                })

            lod_entries = []
            for lod_idx, lod in enumerate(default_lod_levels):
                lod_n        = lod_idx + 1
                lod_filename = f"{tile_id}_lod{lod_n}.{ext}"
                lod_filepath = os.path.join(output_dir, lod_filename)
                print(
                    f"  Exporting LOD{lod_n} {lod_filename} "
                    f"(ratio={lod['ratio']:.3f}, switch={lod['switch_distance']:.1f})"
                )
                try:
                    lod_ok, lod_error = export_hlod_tile(
                        lod_filepath, tile_objs, tile_bounds,
                        lod["ratio"], source_scene_path, "lod",
                    )
                except Exception as ex:
                    lod_ok, lod_error = False, str(ex)
                if not lod_ok:
                    print(f"    LOD{lod_n} FAILED: {lod_error}")
                    continue
                lod_entries.append({
                    "path": os.path.relpath(lod_filepath, model_dir),
                    "switch_distance": lod["switch_distance"],
                })

            file_sz = os.path.getsize(filepath) if os.path.isfile(filepath) else 0

        tile_entry = {
            "tile_id": tile_id,
            "grid_coord": [tx, ty, tz],
            "path_relative_to_manifest": os.path.relpath(filepath, model_dir),
            "priority": tile_priority,
            "hlod_levels": hlod_entries,
            "file_size_bytes": file_sz,
            "estimated_memory_bytes": est_mem,
            "bounds": {"min": list(aabb_usd["min"]), "max": list(aabb_usd["max"])},
            "center": list(center),
            "object_count": len(tile_objs),
            "objects": [o.name for o in tile_objs],
        }
        if lod_entries:
            tile_entry["lod_levels"] = lod_entries
        manifest["tiles"].append(tile_entry)
        exported_count += 1
        export_progress.advance("Tile assets", tile_id, 1 + len(hlod_entries) + len(lod_entries))

    # --- Write manifest ---
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    export_progress.advance("Write manifest", os.path.basename(manifest_path))

    print(f"\nDone. {exported_count} local tiles exported.")
    if manifest["failed_tiles"]:
        print(f"Failed tiles: {len(manifest['failed_tiles'])}")
    if manifest["shared_bucket"]:
        print(f"Shared bucket: {manifest['shared_bucket']['object_count']} objects.")
    print(f"Manifest written to: {manifest_path}")


def parse_args(argv):
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]

    parser = argparse.ArgumentParser(
        description="Partition a Blender scene into UntoldEngine streaming tiles and export .untold payloads plus a manifest."
    )
    parser.add_argument("--input", default=None, help="Optional source .usd/.usdz path used for naming and texture/source resolution when the .blend is unsaved.")
    parser.add_argument("--output-dir", default=None, help="Directory for exported tile payloads. Defaults to the script's OUTPUT_DIR config.")
    parser.add_argument("--tile-size-x", type=float, default=None, help="Override TILE_SIZE_X.")
    parser.add_argument("--tile-size-y", type=float, default=10000.0, help="Override TILE_SIZE_Y. Defaults to 10000.")
    parser.add_argument("--tile-size-z", type=float, default=None, help="Override TILE_SIZE_Z.")
    parser.add_argument("--dry-run", action="store_true", help="Plan the partition without writing payload files.")
    parser.add_argument("--write-manifest-in-dry-run", action="store_true", help="Write the manifest JSON even when --dry-run is enabled.")
    parser.add_argument("--generate-hlod", action="store_true", help="Enable HLOD export regardless of the script default.")
    parser.add_argument("--generate-lod", action="store_true", help="Enable per-tile LOD export regardless of the script default.")
    parser.add_argument(
        "--lod-level",
        action="append",
        default=[],
        metavar="DISTANCE:RATIO",
        help="Override per-tile LOD levels. Repeat for LOD1, LOD2, etc. Distance in metres. Example: --lod-level 90:0.5",
    )
    parser.add_argument(
        "--hlod-level",
        action="append",
        default=[],
        metavar="SUFFIX:DISTANCE:RATIO",
        help="Override HLOD levels. Distance in metres. Example: --hlod-level _hlod:250:0.1",
    )
    parser.add_argument("--visible-only", action="store_true", help="Export only visible mesh objects.")
    parser.add_argument("--all-meshes", action="store_true", help="Export all mesh objects, including hidden ones.")
    parser.add_argument("--debug-aabb-only", action="store_true", help="Export debug AABB payloads instead of real geometry.")
    parser.add_argument("--auto-tile-size", action="store_true", help="Enable automatic tile-size selection.")
    parser.add_argument("--parallel-workers", type=int, default=None, help="Number of parallel Blender worker processes (0=auto, 1=sequential).")
    parser.add_argument("--sample", action="store_true", help="Export only a small tile patch near the world origin (fast iteration mode).")
    parser.add_argument("--sample-fraction", type=float, default=None, help="Fraction of total tiles to keep in sample mode (default: 0.10).")
    parser.add_argument("--perimeter", action="store_true", help="Export only the outer shell of tiles. Skips interior tiles.")
    parser.add_argument("--perimeter-depth", type=int, default=None, help="How many tiles inward from the boundary to keep (default: 1).")
    parser.add_argument(
        "--compress-geometry",
        action="store_true",
        help="Compress vertex and index chunks with LZ4 in every exported tile payload (requires: pip install lz4).",
    )
    parser.add_argument(
        "--bake-materials",
        action="store_true",
        help=(
            "Bake node-graph materials the engine can't evaluate (Mix, Math, procedural textures, ...) "
            "into flat textures via Cycles. Applies to full-detail tile and shared-bucket exports only — "
            "HLOD/LOD tiles are decimated stand-ins and are not separately baked."
        ),
    )
    parser.add_argument(
        "--bake-resolution",
        type=int,
        default=None,
        help="Square resolution for baked material textures (default: 1024). "
             "Override per material via a material['untold_bake_resolution'] custom property.",
    )
    parser.add_argument(
        "--no-bake-cache",
        action="store_true",
        help="Disable the persistent bake cache and force every divergent material to be re-baked.",
    )
    parser.add_argument(
        "--bake-color-management",
        action="store_true",
        help=(
            "Bake the scene's active View Transform/Look/Exposure/Gamma into a scene-wide "
            "RGBA16Float LUT referenced from the manifest's colorLUT key so Untold can "
            "closely reproduce Blender's canonical sRGB display transform."
        ),
    )
    parser.add_argument(
        "--color-lut-size",
        type=int,
        default=None,
        help="Grid size (N) for the NxNxN color-grading LUT (default: 32).",
    )
    parser.add_argument(
        "--quadtree",
        action="store_true",
        help=(
            "Use floor+quadtree partitioning. "
            "If the input was pre-annotated with untold_phase12_suffix-Blender.py the baked metadata is used. "
            "Otherwise the exporter runs the annotation pass inline — no separate Blender step needed."
        ),
    )
    parser.add_argument(
        "--kdtree",
        action="store_true",
        help=(
            "Use floor+KD-tree partitioning (inline annotation only). "
            "Splits each floor's XY plane on the longer axis at the median object center, "
            "producing more balanced tiles in scenes where objects cluster in one region. "
            "Ignored when the input is pre-annotated (quadtree metadata takes precedence). "
            "Produces partitioning_mode='kdtree_floor' in the manifest."
        ),
    )
    parser.add_argument(
        "--min-objects-per-tile-tier",
        type=int,
        default=None,
        help=(
            "For inline quadtree/KD-tree exports, collapse underfilled "
            "(node, semantic tier) groups upward until each emitted tile-tier "
            "has at least this many objects or reaches the floor root. "
            "Default: 4. Use 1 to preserve the old singleton-leaf behavior."
        ),
    )
    parser.add_argument(
        "--scene-profile",
        choices=("auto", "indoor", "outdoor"),
        default="auto",
        help=(
            "Streaming radius profile for semantic tiers. "
            "'auto' infers the profile from scene size and tier distribution. "
            "'outdoor' forces city/open-world bands; 'indoor' forces tight room-scale bands. "
            "Radii are always proportional to scene_half_diag — no hardcoded distances."
        ),
    )
    parser.add_argument(
        "--tier-radius",
        action="append",
        type=parse_tier_radius_override,
        default=[],
        metavar="TIER=STREAM,UNLOAD[,PRIORITY]",
        help=(
            "Override one semantic tier's stream/unload radii in metres. "
            "May be repeated. Example: "
            "--tier-radius StructuralInterior=10,16 --tier-radius RoomContents=5,9,8"
        ),
    )
    parser.add_argument(
        "--untagged-semantic-tier",
        choices=("Auto", "ExteriorShell", "StructuralInterior", "RoomContents", "FineProps"),
        default="Auto",
        help=(
            "Semantic tier assigned to meshes without an explicit untold_semantic_override. "
            "Auto keeps the name/material/size classifier and falls back to StructuralInterior."
        ),
    )
    parser.add_argument(
        "--floor-count",
        type=int,
        default=None,
        help=(
            "Pin the number of floors for inline quadtree annotation. "
            "Overrides auto-detection from the scene Z extent. "
            "Use this when the auto-detected floor count is wrong (e.g. outlier objects inflating the Z range). "
            "If --floor-band-height is also given, both are used as-is. "
            "If only --floor-count is given, the band height is derived from the scene Z span."
        ),
    )
    parser.add_argument(
        "--floor-band-height",
        type=float,
        default=None,
        help=(
            "Pin the per-floor band height in metres for inline quadtree annotation. "
            "The floor count is then ceil(scene_Z_span / band_height). "
            "If --floor-count is also given, both values are used as-is and the scene Z span is ignored."
        ),
    )
    # Internal: used by worker subprocesses spawned by the parallel export system.
    parser.add_argument("--worker-mode", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--work-bundle", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--result-file", default=None, help=argparse.SUPPRESS)
    return parser.parse_args(argv)


def apply_cli_overrides(args):
    global SOURCE_SCENE_PATH_OVERRIDE
    global OUTPUT_DIR
    global TILE_SIZE_X
    global TILE_SIZE_Y
    global TILE_SIZE_Z
    global DRY_RUN
    global DRY_RUN_WRITE_MANIFEST
    global GENERATE_HLOD
    global GENERATE_LOD
    global HLOD_LEVELS
    global TILE_LOD_LEVELS
    global VISIBLE_ONLY
    global DEBUG_AABB_ONLY
    global AUTO_TILE_SIZE
    global PARALLEL_WORKERS
    global COMPRESS_GEOMETRY
    global BAKE_MATERIALS
    global BAKE_RESOLUTION
    global BAKE_CACHE
    global BAKE_COLOR_MANAGEMENT
    global COLOR_LUT_SIZE
    global SAMPLE_MODE
    global SAMPLE_FRACTION
    global PERIMETER_MODE
    global PERIMETER_DEPTH
    global FORCE_QUADTREE
    global FORCE_KDTREE
    global SCENE_STREAMING_PROFILE
    global TIER_RADIUS_OVERRIDES
    global UNTAGGED_SEMANTIC_TIER
    global INLINE_FLOOR_COUNT_OVERRIDE
    global INLINE_FLOOR_BAND_HEIGHT_OVERRIDE
    global INLINE_MIN_OBJECTS_PER_TILE_TIER
    global INLINE_COLLAPSE_UNDERFILLED_TILE_TIERS

    if args.input:
        SOURCE_SCENE_PATH_OVERRIDE = args.input
    if args.output_dir:
        OUTPUT_DIR = args.output_dir
    if args.tile_size_x is not None:
        TILE_SIZE_X = args.tile_size_x
    if args.tile_size_y is not None:
        TILE_SIZE_Y = args.tile_size_y
    if args.tile_size_z is not None:
        TILE_SIZE_Z = args.tile_size_z
    if args.dry_run:
        DRY_RUN = True
    if args.write_manifest_in_dry_run:
        DRY_RUN_WRITE_MANIFEST = True
    if args.generate_hlod:
        GENERATE_HLOD = True
    if args.generate_lod:
        GENERATE_LOD = True
    if getattr(args, "lod_level", None):
        parsed_lods = []
        for value in args.lod_level:
            parts = str(value).split(":")
            if len(parts) != 2:
                raise RuntimeError(f"--lod-level must be DISTANCE:RATIO, got {value!r}")
            parsed_lods.append((float(parts[1]), float(parts[0])))  # (ratio, distance_metres)
        TILE_LOD_LEVELS = parsed_lods
    if getattr(args, "hlod_level", None):
        parsed_hlods = []
        for value in args.hlod_level:
            parts = str(value).split(":")
            if len(parts) != 3:
                raise RuntimeError(f"--hlod-level must be SUFFIX:DISTANCE:RATIO, got {value!r}")
            parsed_hlods.append({
                "suffix": parts[0],
                "reduction_ratio": float(parts[2]),
                "switch_distance": float(parts[1]),  # metres
            })
        HLOD_LEVELS = parsed_hlods
    if args.visible_only:
        VISIBLE_ONLY = True
    if args.all_meshes:
        VISIBLE_ONLY = False
    if args.debug_aabb_only:
        DEBUG_AABB_ONLY = True
    if args.auto_tile_size:
        AUTO_TILE_SIZE = True
    if args.parallel_workers is not None:
        PARALLEL_WORKERS = args.parallel_workers
    if getattr(args, "compress_geometry", False):
        COMPRESS_GEOMETRY = True
    if getattr(args, "bake_materials", False):
        BAKE_MATERIALS = True
    if getattr(args, "bake_resolution", None) is not None:
        BAKE_RESOLUTION = validate_bake_resolution(args.bake_resolution)
    if getattr(args, "no_bake_cache", False):
        BAKE_CACHE = False
    if getattr(args, "bake_color_management", False):
        BAKE_COLOR_MANAGEMENT = True
    if getattr(args, "color_lut_size", None) is not None:
        COLOR_LUT_SIZE = validate_lut_size(args.color_lut_size)
    if getattr(args, "sample", False):
        SAMPLE_MODE = True
    if getattr(args, "sample_fraction", None) is not None:
        SAMPLE_FRACTION = args.sample_fraction
    if getattr(args, "perimeter", False):
        PERIMETER_MODE = True
    if getattr(args, "perimeter_depth", None) is not None:
        PERIMETER_DEPTH = args.perimeter_depth
    if getattr(args, "quadtree", False):
        FORCE_QUADTREE = True
    if getattr(args, "kdtree", False):
        FORCE_KDTREE   = True
        FORCE_QUADTREE = True   # KD-tree uses the same quadtree export pipeline
    if getattr(args, "min_objects_per_tile_tier", None) is not None:
        INLINE_MIN_OBJECTS_PER_TILE_TIER = max(1, int(args.min_objects_per_tile_tier))
        INLINE_COLLAPSE_UNDERFILLED_TILE_TIERS = INLINE_MIN_OBJECTS_PER_TILE_TIER > 1
    if getattr(args, "scene_profile", None):
        SCENE_STREAMING_PROFILE = args.scene_profile
    if getattr(args, "tier_radius", None):
        for tier, override in args.tier_radius:
            TIER_RADIUS_OVERRIDES[tier] = override
    if getattr(args, "untagged_semantic_tier", None):
        UNTAGGED_SEMANTIC_TIER = args.untagged_semantic_tier
    if getattr(args, "floor_count", None) is not None:
        INLINE_FLOOR_COUNT_OVERRIDE = args.floor_count
    if getattr(args, "floor_band_height", None) is not None:
        INLINE_FLOOR_BAND_HEIGHT_OVERRIDE = args.floor_band_height


def main(argv=None):
    argv = sys.argv if argv is None else argv
    args = parse_args(argv)
    apply_cli_overrides(args)
    if getattr(args, "worker_mode", False):
        if not args.work_bundle or not args.result_file:
            print("Error: --worker-mode requires --work-bundle and --result-file", flush=True)
            return 1
        _run_worker_mode(args.work_bundle, args.result_file)
        return 0
    run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
