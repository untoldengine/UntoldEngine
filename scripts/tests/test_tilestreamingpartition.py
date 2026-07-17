# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Tests for Blender-free helpers in scripts/tilestreamingpartition.py.

tilestreamingpartition.py imports bpy at module level, so this test file
mocks bpy (and its companions bmesh, mathutils, colorsys) in sys.modules
before importing the script. Only pure-Python helpers are tested here.
Blender-dependent paths (USD export, object duplication, LOD generation,
parallel worker spawning) are intentionally excluded — see README.md.
"""

import sys
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock
from pathlib import Path

# ---------------------------------------------------------------------------
# Stub out Blender modules before the first import of tilestreamingpartition.
# The stubs must be present *before* the import so the module-level
# `import bpy` / `from mathutils import Vector, Matrix` lines resolve cleanly.
# ---------------------------------------------------------------------------
for _mod in ("bpy", "bmesh", "mathutils", "colorsys"):
    if _mod not in sys.modules:
        sys.modules[_mod] = MagicMock()

# mathutils.Vector and Matrix are accessed as class constructors; make sure
# they return something iterable so any module-level usage doesn't crash.
sys.modules["mathutils"].Vector = MagicMock(return_value=(0.0, 0.0, 0.0))
sys.modules["mathutils"].Matrix = MagicMock(return_value=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]])

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import tilestreamingpartition as t  # noqa: E402


class FakeObject(dict):
    def __init__(self, name: str, **props) -> None:
        super().__init__(props)
        self.name = name


class TileStreamingPartitionTests(unittest.TestCase):

    # ------------------------------------------------------------------
    # Math helpers
    # ------------------------------------------------------------------

    def test_clamp_and_lerp(self) -> None:
        self.assertEqual(t.clamp(0.5, 0.0, 1.0), 0.5)
        self.assertEqual(t.clamp(-1.0, 0.0, 1.0), 0.0)
        self.assertEqual(t.clamp(2.0, 0.0, 1.0), 1.0)

        self.assertAlmostEqual(t.lerp(0.0, 10.0, 0.0), 0.0)
        self.assertAlmostEqual(t.lerp(0.0, 10.0, 1.0), 10.0)
        self.assertAlmostEqual(t.lerp(0.0, 10.0, 0.5), 5.0)

    # ------------------------------------------------------------------
    # Tile coordinate math
    # ------------------------------------------------------------------

    def test_tile_coord_from_point_origin(self) -> None:
        # Point at origin lands in tile (0, 0, 0)
        coord = t.tile_coord_from_point(
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            10.0, 100.0, 10.0,
        )
        self.assertEqual(coord, (0, 0, 0))

    def test_tile_coord_from_point_offset(self) -> None:
        # Blender axis mapping: cx→tx (tile_x), cz→ty (tile_y), cy→tz (tile_z)
        # Point (cx=12, cy=5, cz=17) with tile sizes (10, 100, 10):
        #   tx = floor(12/10) = 1
        #   ty = floor(17/100) = 0   (Blender Z = height maps to tile Y)
        #   tz = floor(5/10) = 0     (Blender Y = depth maps to tile Z)
        coord = t.tile_coord_from_point(
            12.0, 5.0, 17.0,
            0.0, 0.0, 0.0,
            10.0, 100.0, 10.0,
        )
        self.assertEqual(coord, (1, 0, 0))

    def test_tile_coord_negative_quadrant(self) -> None:
        # Negative X tile; cy=0 so tz=0; cz=-5 with tile_size_y=100 →
        # ty = floor(-5/100) = floor(-0.05) = -1  (Python floor toward -inf)
        coord = t.tile_coord_from_point(
            -5.0, 0.0, -5.0,
            0.0, 0.0, 0.0,
            10.0, 100.0, 10.0,
        )
        self.assertEqual(coord, (-1, -1, 0))

    # ------------------------------------------------------------------
    # Tile overlap queries
    # ------------------------------------------------------------------

    def test_overlapping_tile_coords_single_tile(self) -> None:
        # Object fully inside one tile
        tiles = t.overlapping_tile_coords(
            {"min": (1.0, 0.0, 1.0), "max": (4.0, 3.0, 4.0)},
            0.0, 0.0, 0.0, 10.0, 100.0, 10.0, 1e-4,
        )
        self.assertEqual(sorted(tiles), [(0, 0, 0)])

    def test_overlapping_tile_coords_spans_three_tiles(self) -> None:
        # Object from x=8 to x=22 straddles tiles (0,0,0), (1,0,0), (2,0,0)
        tiles = t.overlapping_tile_coords(
            {"min": (8.0, 0.0, 1.0), "max": (22.0, 3.0, 4.0)},
            0.0, 0.0, 0.0, 10.0, 100.0, 10.0, 1e-4,
        )
        self.assertEqual(sorted(tiles), [(0, 0, 0), (1, 0, 0), (2, 0, 0)])

    def test_xz_tile_overlap_count(self) -> None:
        # Same object as above: 3 XZ tiles covered
        count = t.xz_tile_overlap_count(
            {"min": (8.0, 0.0, 1.0), "max": (22.0, 3.0, 4.0)},
            0.0, 0.0, 10.0, 10.0, 1e-4,
        )
        self.assertEqual(count, 3)

    def test_xz_tile_overlap_count_single(self) -> None:
        count = t.xz_tile_overlap_count(
            {"min": (1.0, 0.0, 1.0), "max": (8.0, 3.0, 8.0)},
            0.0, 0.0, 10.0, 10.0, 1e-4,
        )
        self.assertEqual(count, 1)

    # ------------------------------------------------------------------
    # Tile bounds
    # ------------------------------------------------------------------

    def test_tile_bounds_from_coord(self) -> None:
        bounds = t.tile_bounds_from_coord(
            1, 0, 1,
            0.0, 0.0, 0.0,
            10.0, 100.0, 10.0,
        )
        self.assertAlmostEqual(bounds["min_x"], 10.0)
        self.assertAlmostEqual(bounds["max_x"], 20.0)
        self.assertAlmostEqual(bounds["min_y"], 0.0)
        self.assertAlmostEqual(bounds["max_y"], 100.0)
        self.assertAlmostEqual(bounds["min_z"], 10.0)
        self.assertAlmostEqual(bounds["max_z"], 20.0)

    def test_tile_bounds_from_coord_origin_tile(self) -> None:
        bounds = t.tile_bounds_from_coord(
            0, 0, 0,
            0.0, 0.0, 0.0,
            25.0, 10000.0, 25.0,
        )
        self.assertAlmostEqual(bounds["min_x"], 0.0)
        self.assertAlmostEqual(bounds["max_x"], 25.0)

    # ------------------------------------------------------------------
    # Coordinate space conversion
    # ------------------------------------------------------------------

    def test_aabb_to_usd_space_swaps_y_and_z(self) -> None:
        # Blender: X→X, Y→Z(negated), Z→Y
        usd = t.aabb_to_usd_space({"min": (1.0, 2.0, 3.0), "max": (4.0, 5.0, 6.0)})
        self.assertAlmostEqual(usd["min"][0], 1.0)   # X unchanged
        self.assertAlmostEqual(usd["min"][1], 3.0)   # Z → Y
        self.assertAlmostEqual(usd["min"][2], -5.0)  # -Y → Z

    # ------------------------------------------------------------------
    # Runtime representation helpers
    # ------------------------------------------------------------------

    def test_distance_to_aabb_is_zero_inside_large_bounds(self) -> None:
        bounds = {"min": (-100.0, -10.0, -20.0), "max": (100.0, 10.0, 20.0)}

        self.assertAlmostEqual(t.distance_to_aabb((50.0, 0.0, 0.0), bounds), 0.0)

    def test_distance_to_aabb_uses_closest_point(self) -> None:
        bounds = {"min": (0.0, 0.0, 0.0), "max": (10.0, 10.0, 10.0)}

        self.assertAlmostEqual(t.distance_to_aabb((13.0, 14.0, 10.0), bounds), 5.0)

    def test_collect_manifest_scene_payload_serializes_lights_and_cameras(self) -> None:
        original_extract = t.extract_scene_payload_from_objects
        original_objects = t.bpy.data.objects
        t.bpy.data.objects = [FakeObject("Sun"), FakeObject("Camera")]
        t.extract_scene_payload_from_objects = MagicMock(return_value=(
            [
                SimpleNamespace(
                    entity_name="Sun",
                    light_type=1,
                    color=(1.0, 0.9, 0.8),
                    intensity=3.0,
                    position=(1.0, 2.0, 3.0),
                    radius=0.001,
                    direction=(0.0, -1.0, 0.0),
                    falloff=0.5,
                    right=(1.0, 0.0, 0.0),
                    inner_cone=10.0,
                    up=(0.0, 1.0, 0.0),
                    outer_cone=25.0,
                    area_size=(1.0, 1.0),
                    source_power=3.0,
                    source_exposure=0.0,
                    local_transform_rows=[
                        [1.0, 0.0, 0.0, 1.0],
                        [0.0, 1.0, 0.0, 2.0],
                        [0.0, 0.0, 1.0, 3.0],
                        [0.0, 0.0, 0.0, 1.0],
                    ],
                )
            ],
            [
                SimpleNamespace(
                    entity_name="Camera",
                    position=(0.0, 1.0, 6.0),
                    forward=(0.0, 0.0, 1.0),
                    up=(0.0, 1.0, 0.0),
                    right=(1.0, 0.0, 0.0),
                    fov_y_degrees=55.0,
                    near_clip=0.05,
                    far_clip=750.0,
                    aspect_ratio=1.6,
                    local_transform_rows=[
                        [1.0, 0.0, 0.0, 0.0],
                        [0.0, 1.0, 0.0, 1.0],
                        [0.0, 0.0, 1.0, 6.0],
                        [0.0, 0.0, 0.0, 1.0],
                    ],
                )
            ],
        ))
        try:
            lights, cameras = t.collect_manifest_scene_payload()
        finally:
            t.extract_scene_payload_from_objects = original_extract
            t.bpy.data.objects = original_objects

        self.assertEqual(lights[0]["entity_name"], "Sun")
        self.assertEqual(lights[0]["kind"], "directional")
        self.assertEqual(lights[0]["light_type"], 1)
        self.assertEqual(lights[0]["local_transform_rows"][0][3], 1.0)
        self.assertEqual(cameras[0]["entity_name"], "Camera")
        self.assertEqual(cameras[0]["fov_y_degrees"], 55.0)
        self.assertEqual(cameras[0]["near_clip"], 0.05)
        self.assertEqual(cameras[0]["far_clip"], 750.0)

    def test_object_union_aabb(self) -> None:
        objs = [FakeObject("A"), FakeObject("B")]
        bounds = {
            "A": {"min": (0.0, 1.0, 2.0), "max": (3.0, 4.0, 5.0)},
            "B": {"min": (-2.0, 3.0, 1.0), "max": (8.0, 9.0, 7.0)},
        }

        self.assertEqual(t.object_union_aabb(objs, bounds), {
            "min": (-2.0, 1.0, 1.0),
            "max": (8.0, 9.0, 7.0),
        })

    def test_runtime_representation_hlod_takes_far_field_precedence(self) -> None:
        state = t.classify_runtime_representation(
            distance=80.0,
            unload_r=60.0,
            hlod_levels=[{"switch_distance": 57.0}],
            lod_levels=[{"switch_distance": 25.0}],
        )

        self.assertEqual(state, "hlod")

    def test_runtime_representation_lod_precedes_unloaded_without_hlod(self) -> None:
        state = t.classify_runtime_representation(
            distance=80.0,
            unload_r=60.0,
            hlod_levels=[],
            lod_levels=[{"switch_distance": 25.0}],
        )

        self.assertEqual(state, "lod")

    def test_runtime_representation_unloaded_when_no_secondary_asset(self) -> None:
        state = t.classify_runtime_representation(
            distance=80.0,
            unload_r=60.0,
            hlod_levels=[],
            lod_levels=[],
        )

        self.assertEqual(state, "unloaded")

    # ------------------------------------------------------------------
    # Mesh classification
    # ------------------------------------------------------------------

    def test_classify_mesh_local_small_object(self) -> None:
        # Object smaller than one tile, low overlap count → local_overlap
        result = t.classify_mesh(
            {"min": (0.0, 0.0, 0.0), "max": (4.0, 3.0, 4.0)},
            tile_size_x=10.0,
            tile_size_z=10.0,
            xz_overlap_count=1,
            overlap_threshold=4,
        )
        self.assertEqual(result["policy"], "local_overlap")

    def test_classify_mesh_shared_bucket_by_overlap_count(self) -> None:
        # Overlap count exceeds threshold → shared_bucket
        result = t.classify_mesh(
            {"min": (0.0, 0.0, 0.0), "max": (8.0, 3.0, 8.0)},
            tile_size_x=10.0,
            tile_size_z=10.0,
            xz_overlap_count=5,
            overlap_threshold=4,
        )
        self.assertEqual(result["policy"], "shared_bucket")

    def test_classify_mesh_shared_bucket_by_width(self) -> None:
        # Width / tile_size > SPANNING_THRESHOLD_TILES (4) → shared_bucket
        result = t.classify_mesh(
            {"min": (0.0, 0.0, 0.0), "max": (50.0, 3.0, 8.0)},  # 50/10 = 5 > 4
            tile_size_x=10.0,
            tile_size_z=10.0,
            xz_overlap_count=1,
            overlap_threshold=4,
        )
        self.assertEqual(result["policy"], "shared_bucket")
        self.assertIn("width_threshold", result["reasons"])

    def test_classify_mesh_result_contains_required_keys(self) -> None:
        result = t.classify_mesh(
            {"min": (0.0, 0.0, 0.0), "max": (4.0, 2.0, 4.0)},
            10.0, 10.0, 1, 4,
        )
        for key in ("policy", "xz_overlap_count", "dimensions", "dim_ratio", "reasons"):
            self.assertIn(key, result)

    # ------------------------------------------------------------------
    # Output helpers
    # ------------------------------------------------------------------

    def test_sanitize_name_replaces_special_characters(self) -> None:
        # strip("_") removes leading/trailing underscores produced by non-alnum chars
        self.assertEqual(t.sanitize_name("My Object! (v2)"), "My_Object___v2")

    def test_sanitize_name_preserves_alphanumerics(self) -> None:
        self.assertEqual(t.sanitize_name("Tile_0_1"), "Tile_0_1")

    # ------------------------------------------------------------------
    # Untold object metadata
    # ------------------------------------------------------------------

    def test_semantic_override_wins_over_existing_metadata(self) -> None:
        obj = FakeObject(
            "Wall",
            untold_quadtree_node_id="F01_Q_0",
            untold_floor_id=1,
            untold_quadtree_depth=1,
            untold_spatial_class="local",
            untold_semantic_guess="StructuralInterior",
            untold_semantic_confidence=0.8,
            untold_semantic_override="ExteriorShell",
        )

        metadata = t.read_untold_metadata(obj)

        self.assertEqual(metadata["semantic"], "ExteriorShell")
        self.assertEqual(metadata["confidence"], 1.0)
        self.assertEqual(metadata["source"], "custom_property_override")

    def test_auto_semantic_override_uses_existing_metadata(self) -> None:
        obj = FakeObject(
            "Chair",
            untold_quadtree_node_id="F01_Q_1",
            untold_semantic_guess="RoomContents",
            untold_semantic_confidence=0.7,
            untold_semantic_override="Auto",
        )

        metadata = t.read_untold_metadata(obj)

        self.assertEqual(metadata["semantic"], "RoomContents")
        self.assertEqual(metadata["source"], "custom_property")

    def test_aggregate_priority_hint_uses_highest_hint(self) -> None:
        objs = [
            FakeObject("A", untold_streaming_priority_hint="Low"),
            FakeObject("B", untold_streaming_priority_hint="Critical"),
            FakeObject("C"),
        ]

        self.assertEqual(t.aggregate_priority_hint(objs, default_priority=8), 15)

    def test_aggregate_priority_hint_keeps_default_when_higher(self) -> None:
        objs = [FakeObject("A", untold_streaming_priority_hint="Low")]

        self.assertEqual(t.aggregate_priority_hint(objs, default_priority=10), 10)

    def test_format_bytes_bytes(self) -> None:
        self.assertIn("B", t.format_bytes(500))
        self.assertIn("500", t.format_bytes(500))

    def test_format_bytes_kilobytes(self) -> None:
        result = t.format_bytes(1024)
        self.assertIn("KB", result)
        self.assertIn("1.00", result)

    def test_format_bytes_megabytes(self) -> None:
        result = t.format_bytes(1024 * 1024)
        self.assertIn("MB", result)

    # ------------------------------------------------------------------
    # Argument parsing
    # ------------------------------------------------------------------

    def test_parse_args_defaults(self) -> None:
        # Pass a dummy argv[0]; all flags optional
        args = t.parse_args(["script.py"])
        self.assertIsNone(args.input)
        self.assertIsNone(args.tile_size_x)
        self.assertAlmostEqual(args.tile_size_y, 10000.0)
        self.assertFalse(args.dry_run)
        self.assertFalse(args.generate_hlod)
        self.assertFalse(args.generate_lod)
        self.assertFalse(args.compress_geometry)
        self.assertFalse(args.quadtree)
        self.assertEqual(args.scene_profile, "auto")
        self.assertEqual(args.tier_radius, [])

    def test_parse_args_tile_size_and_flags(self) -> None:
        args = t.parse_args([
            "script.py",
            "--tile-size-x", "25",
            "--tile-size-z", "25",
            "--generate-hlod",
            "--generate-lod",
            "--compress-geometry",
            "--quadtree",
            "--scene-profile", "outdoor",
            "--tier-radius", "StructuralInterior=10,16",
            "--tier-radius", "RoomContents=5,9,8",
            "--dry-run",
            "--parallel-workers", "4",
        ])
        self.assertAlmostEqual(args.tile_size_x, 25.0)
        self.assertAlmostEqual(args.tile_size_z, 25.0)
        self.assertTrue(args.generate_hlod)
        self.assertTrue(args.generate_lod)
        self.assertTrue(args.compress_geometry)
        self.assertTrue(args.quadtree)
        self.assertEqual(args.scene_profile, "outdoor")
        self.assertEqual(args.tier_radius, [
            ("StructuralInterior", {"streaming": 10.0, "unload": 16.0}),
            ("RoomContents", {"streaming": 5.0, "unload": 9.0, "priority": 8}),
        ])
        self.assertTrue(args.dry_run)
        self.assertEqual(args.parallel_workers, 4)

    def test_compute_tier_radii_applies_absolute_overrides(self) -> None:
        previous = dict(t.TIER_RADIUS_OVERRIDES)
        try:
            t.TIER_RADIUS_OVERRIDES.clear()
            t.TIER_RADIUS_OVERRIDES.update({
                "StructuralInterior": {"streaming": 10.0, "unload": 16.0},
                "RoomContents": {"streaming": 5.0, "unload": 9.0, "priority": 8},
            })
            radii = t.compute_tier_radii(scene_half_diag=100.0, profile="indoor")
            self.assertEqual(radii["StructuralInterior"]["streaming"], 10.0)
            self.assertEqual(radii["StructuralInterior"]["unload"], 16.0)
            self.assertEqual(radii["StructuralInterior"]["priority"], 10)
            self.assertEqual(radii["RoomContents"]["streaming"], 5.0)
            self.assertEqual(radii["RoomContents"]["unload"], 9.0)
            self.assertEqual(radii["RoomContents"]["priority"], 8)
        finally:
            t.TIER_RADIUS_OVERRIDES.clear()
            t.TIER_RADIUS_OVERRIDES.update(previous)

    def test_parse_args_blender_separator(self) -> None:
        # When invoked via Blender, argv contains "--" before the script args
        args = t.parse_args([
            "blender", "--background", "--python", "tilestreamingpartition.py",
            "--",
            "--tile-size-x", "50",
            "--auto-tile-size",
            "--visible-only",
        ])
        self.assertAlmostEqual(args.tile_size_x, 50.0)
        self.assertTrue(args.auto_tile_size)
        self.assertTrue(args.visible_only)

    def test_parse_args_floor_count_and_band_height(self) -> None:
        args = t.parse_args([
            "script.py",
            "--floor-count", "3",
            "--floor-band-height", "4.5",
        ])
        self.assertEqual(args.floor_count, 3)
        self.assertAlmostEqual(args.floor_band_height, 4.5)

    def test_parse_args_bake_materials_and_resolution(self) -> None:
        args = t.parse_args([
            "script.py",
            "--bake-materials",
            "--bake-resolution", "2048",
        ])
        self.assertTrue(args.bake_materials)
        self.assertEqual(args.bake_resolution, 2048)

    def test_parse_args_bake_materials_defaults_off(self) -> None:
        args = t.parse_args(["script.py"])
        self.assertFalse(args.bake_materials)
        self.assertIsNone(args.bake_resolution)

    def test_apply_cli_overrides_sets_bake_materials_globals(self) -> None:
        previous = (t.BAKE_MATERIALS, t.BAKE_RESOLUTION)
        try:
            args = t.parse_args(["script.py", "--bake-materials", "--bake-resolution", "2048"])
            t.apply_cli_overrides(args)
            self.assertTrue(t.BAKE_MATERIALS)
            self.assertEqual(t.BAKE_RESOLUTION, 2048)
        finally:
            t.BAKE_MATERIALS, t.BAKE_RESOLUTION = previous

    def test_config_snapshot_and_bundle_round_trips_bake_settings(self) -> None:
        """Regression guard: BAKE_MATERIALS/BAKE_RESOLUTION/BAKE_CACHE must survive
        the snapshot -> worker-subprocess-restore round trip, or --bake-materials
        would silently do nothing whenever --parallel-workers spawns workers
        (the default for multi-tile scenes) despite working for --parallel-workers 1."""
        previous = (t.BAKE_MATERIALS, t.BAKE_RESOLUTION, t.BAKE_CACHE)
        try:
            t.BAKE_MATERIALS = True
            t.BAKE_RESOLUTION = 2048
            t.BAKE_CACHE = False
            snapshot = t._config_snapshot()
            self.assertEqual(snapshot["BAKE_MATERIALS"], True)
            self.assertEqual(snapshot["BAKE_RESOLUTION"], 2048)
            self.assertEqual(snapshot["BAKE_CACHE"], False)

            t.BAKE_MATERIALS = False
            t.BAKE_RESOLUTION = 1024
            t.BAKE_CACHE = True
            t._apply_bundle_config(snapshot)
            self.assertTrue(t.BAKE_MATERIALS)
            self.assertEqual(t.BAKE_RESOLUTION, 2048)
            self.assertFalse(t.BAKE_CACHE)
        finally:
            t.BAKE_MATERIALS, t.BAKE_RESOLUTION, t.BAKE_CACHE = previous

    def test_parse_args_no_bake_cache(self) -> None:
        args = t.parse_args(["script.py", "--bake-materials", "--no-bake-cache"])
        self.assertTrue(args.bake_materials)
        self.assertTrue(args.no_bake_cache)

    def test_apply_cli_overrides_disables_bake_cache(self) -> None:
        previous = t.BAKE_CACHE
        try:
            args = t.parse_args(["script.py", "--no-bake-cache"])
            t.apply_cli_overrides(args)
            self.assertFalse(t.BAKE_CACHE)
        finally:
            t.BAKE_CACHE = previous


if __name__ == "__main__":
    unittest.main()
