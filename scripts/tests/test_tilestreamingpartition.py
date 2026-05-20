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


if __name__ == "__main__":
    unittest.main()
