# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Checks for the procedural material bake that need a real Blender (and its Cycles).

They are kept out of `make testexporter`, which runs without Blender. Run them from
the repository root:

    blender --background --factory-startup --python-exit-code 1 \
        --python scripts/tests/blender/material_bake_checks.py

Every material and mesh is made by the checks themselves; what they export goes to a
temporary folder.
"""

import struct
import sys
import tempfile
import unittest
from pathlib import Path

import bpy
import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parents[2]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import untoldexplorer as u


BRICK_WIDTH = 0.25
ROW_HEIGHT = 0.1


def new_material(name: str):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    principled = next(node for node in tree.nodes if node.bl_idname == "ShaderNodeBsdfPrincipled")
    return material, tree, principled


def brick_material(name: str = "Bricks", coordinates: str = "Object", along: str = "Y"):
    """Bricks laid along one level axis and up z, in object or world coordinates: with
    `along` "Y", the bricks of a wall facing x."""
    material, tree, principled = new_material(name)
    if coordinates == "Object":
        source = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    else:
        source = tree.nodes.new("ShaderNodeNewGeometry").outputs["Position"]
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    combine = tree.nodes.new("ShaderNodeCombineXYZ")
    bricks = tree.nodes.new("ShaderNodeTexBrick")
    tree.links.new(source, separate.inputs["Vector"])
    tree.links.new(separate.outputs[along], combine.inputs["X"])
    tree.links.new(separate.outputs["Z"], combine.inputs["Y"])
    tree.links.new(combine.outputs["Vector"], bricks.inputs["Vector"])
    bricks.inputs["Color1"].default_value = (0.5, 0.15, 0.1, 1.0)
    bricks.inputs["Color2"].default_value = (0.5, 0.15, 0.1, 1.0)   # every brick alike: an exact period
    bricks.inputs["Mortar"].default_value = (0.8, 0.8, 0.75, 1.0)
    bricks.inputs["Scale"].default_value = 1.0
    bricks.inputs["Mortar Size"].default_value = 0.012
    bricks.inputs["Mortar Smooth"].default_value = 0.0
    bricks.inputs["Brick Width"].default_value = BRICK_WIDTH
    bricks.inputs["Row Height"].default_value = ROW_HEIGHT
    tree.links.new(bricks.outputs["Color"], principled.inputs["Base Color"])
    return material


def noise_material(name: str, coordinates: str):
    """Coloured noise read from object coordinates, world positions or the UV map."""
    material, tree, principled = new_material(name)
    noise = tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 12.0
    noise.inputs["Detail"].default_value = 3.0
    if coordinates == "Position":
        tree.links.new(tree.nodes.new("ShaderNodeNewGeometry").outputs["Position"], noise.inputs["Vector"])
    else:
        tree.links.new(tree.nodes.new("ShaderNodeTexCoord").outputs[coordinates], noise.inputs["Vector"])
    tree.links.new(noise.outputs["Color"], principled.inputs["Base Color"])
    return material


def quad_object(name: str, corners, material, *, with_uvs: bool = False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(corners, [], [(0, 1, 2, 3)])
    if with_uvs:
        layer = mesh.uv_layers.new(name="UVMap")
        for loop, uv in zip(mesh.loops, [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]):
            layer.data[loop.index].uv = uv
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def wall_object(name: str, material, width: float = 3.0, height: float = 2.5):
    """A wall facing +x, in the plane x = 0."""
    return quad_object(name, [(0, 0, 0), (0, width, 0), (0, width, height), (0, 0, height)], material)


def floor_object(name: str, material, size: float = 3.0, **kwargs):
    return quad_object(name, [(0, 0, 0), (size, 0, 0), (size, size, 0), (0, size, 0)], material, **kwargs)


def texture_pixels(texture) -> np.ndarray:
    """A baked texture's values as stored, (height, width, 3), row 0 at v = 0."""
    image = bpy.data.images[texture.source_image_name]
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return pixels.reshape(height, width, 4)[..., :3].astype(np.float64)


def base_color_seen_on(obj, width: int, height: int) -> np.ndarray:
    """What the object's own material shows over the first repeat of its UV map, baked
    straight from the object: the truth a baked tile is compared with. Linear values."""
    material = obj.data.materials[0]
    working = material.copy()
    obj.data.materials[0] = working
    tree = working.node_tree
    principled = next(node for node in tree.nodes if node.bl_idname == "ShaderNodeBsdfPrincipled")
    output = next(node for node in tree.nodes if node.bl_idname == "ShaderNodeOutputMaterial")
    emission = tree.nodes.new("ShaderNodeEmission")
    tree.links.new(principled.inputs["Base Color"].links[0].from_socket, emission.inputs["Color"])
    tree.links.new(emission.outputs[0], output.inputs["Surface"])
    target = bpy.data.images.new("truth", width, height, alpha=False, float_buffer=True)
    target.colorspace_settings.name = "Non-Color"
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = target
    tree.nodes.active = node
    scene = bpy.context.scene
    saved = (scene.render.engine, scene.cycles.samples, scene.render.bake.margin)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.render.bake.margin = 0
    try:
        with bpy.context.temp_override(
            active_object=obj, object=obj, selected_objects=[obj], selected_editable_objects=[obj]
        ):
            bpy.ops.object.bake(type="EMIT")
        pixels = np.empty(width * height * 4, dtype=np.float32)
        target.pixels.foreach_get(pixels)
        return pixels.reshape(height, width, 4)[..., :3].astype(np.float64)
    finally:
        scene.render.engine, scene.cycles.samples, scene.render.bake.margin = saved
        obj.data.materials[0] = material
        bpy.data.materials.remove(working)
        bpy.data.images.remove(target)


def read_untold_vertices(path: Path) -> list[tuple[tuple[float, float, float], tuple[float, float]]]:
    """(position, uv0) of every vertex of the first mesh of a .untold file."""
    raw = path.read_bytes()
    header_size, chunk_count = struct.unpack_from("<II", raw, 20)
    chunks = {}
    for index in range(chunk_count):
        kind, _, offset, size, _, count, _ = struct.unpack_from("<IIQQQII", raw, header_size + index * 40)
        chunks[kind] = (offset, size, count)
    offset, size, _ = chunks[u.CHUNK_TYPES["vertex_data"]]
    vertices = np.frombuffer(raw[offset:offset + size], dtype=u._VERTEX_DTYPE)
    uv = np.stack([vertices["uv0u"], vertices["uv0v"]], axis=1).view(np.float16).astype(np.float64)
    return [
        ((float(v["px"]), float(v["py"]), float(v["pz"])), (float(uv[i, 0]), float(uv[i, 1])))
        for i, v in enumerate(vertices)
    ]


class MaterialBakeChecks(unittest.TestCase):
    def setUp(self) -> None:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        u.clear_material_bakes()
        u.MATERIAL_BAKE_OPTIONS.enabled = True
        u.MATERIAL_BAKE_OPTIONS.resolution = 512
        u.MATERIAL_BAKE_OPTIONS.tile_meters = 2.0

    def tearDown(self) -> None:
        u.clear_material_bakes()

    def bake_of(self, obj):
        u.prepare_material_bakes([obj])
        bake = u.material_bake_for(obj.data.materials[0])
        self.assertIsNotNone(bake)
        return bake

    def test_a_brick_wall_becomes_a_tile_of_whole_bricks_that_matches_blender(self) -> None:
        wall = wall_object("Wall", brick_material())
        bake = self.bake_of(wall)
        self.assertTrue(bake.has_textures)
        self.assertEqual(bake.plane, "+x")
        self.assertFalse(bake.world_mapped)
        # A whole number of bricks along, and of pairs of rows up (every other row is
        # shifted by half a brick), to the millimetre.
        along, up = bake.tile[0] / BRICK_WIDTH, bake.tile[1] / (2 * ROW_HEIGHT)
        self.assertAlmostEqual(along, round(along), delta=0.002 / BRICK_WIDTH)
        self.assertAlmostEqual(up, round(up), delta=0.002 / (2 * ROW_HEIGHT))
        self.assertGreaterEqual(bake.tile[0], 1.0)
        self.assertLessEqual(bake.tile[0], 2.0 + 1.0e-6)

        # Lay the tile onto the wall the way the export does, and bake the wall's own
        # material through those UVs: the first repeat must show what the tile holds.
        u.write_projected_uv_layer(wall.data, wall, bake)
        tile = texture_pixels(bake.base_color_texture)
        truth = u.linear_to_srgb(base_color_seen_on(wall, tile.shape[1], tile.shape[0]))
        difference = np.abs(tile - truth).max(axis=2)
        # A joint that falls between two texels may land on either: allow a little.
        self.assertLess(float((difference > 0.1).mean()), 0.02)
        self.assertLess(float(difference.mean()), 0.01)

    def test_noise_becomes_a_tile_that_repeats_without_a_seam(self) -> None:
        floor = floor_object("Floor", noise_material("Rust", "Object"))
        bake = self.bake_of(floor)
        self.assertTrue(bake.has_textures)
        self.assertEqual(bake.plane, "+z")
        self.assertEqual(tuple(round(length, 6) for length in bake.tile), (2.0, 2.0))
        tile = texture_pixels(bake.base_color_texture)
        for axis in (0, 1):
            inside = np.abs(np.diff(tile, axis=axis)).mean()
            first = np.take(tile, 0, axis=axis)
            last = np.take(tile, -1, axis=axis)
            self.assertLess(float(np.abs(first - last).mean()), 2.0 * float(inside))
        # Away from the band that fades across the seam, the tile is the noise itself.
        u.write_projected_uv_layer(floor.data, floor, bake)
        truth = u.linear_to_srgb(base_color_seen_on(floor, tile.shape[1], tile.shape[0]))
        band = int(tile.shape[0] * 0.125) + 2
        difference = np.abs(tile - truth)[band:, band:]
        self.assertLess(float(difference.mean()), 0.01)

    def test_a_world_pattern_is_mapped_in_the_world_on_a_single_mesh(self) -> None:
        material = brick_material("WorldBricks", coordinates="Position", along="X")
        wall = wall_object("Wall", material)
        # Turned to face +y, moved and raised: the bricks stay where the world has them.
        wall.rotation_euler = (0.0, 0.0, 1.5707963267948966)
        wall.location = (10.3, 4.0, 0.37)
        bpy.context.view_layer.update()
        bake = self.bake_of(wall)
        self.assertTrue(bake.world_mapped)
        self.assertEqual(bake.plane, "+y")

        nodes = u.extract_nodes_from_objects([wall], Path(bpy.app.tempdir) / "scene.blend", validate=True)
        mesh = nodes[0].mesh.validation_mesh
        matrix = np.array(wall.matrix_world)
        for position, uv in zip(mesh.positions, mesh.uv0):
            world = matrix @ np.array([*position, 1.0])
            # Facing y: u along world x, v up world z, whole repeats aside.
            for value, expected in ((uv[0], world[0] / bake.tile[0]), (uv[1], world[2] / bake.tile[1])):
                self.assertAlmostEqual((value - expected) - round(value - expected), 0.0, delta=2.0e-3)

        # And what the wall shows through those UVs is what the tile holds.
        u.prepare_material_bakes([wall])
        bake = u.material_bake_for(material)
        u.write_projected_uv_layer(wall.data, wall, bake)
        tile = texture_pixels(bake.base_color_texture)
        seen = base_color_seen_on(wall, tile.shape[1], tile.shape[0])
        # Away from the origin the wall does not start at a repeat's corner, so only
        # part of the first repeat lies on it: compare where it does.
        covered = seen.sum(axis=2) > 0.0
        self.assertGreater(float(covered.mean()), 0.2)
        difference = np.abs(tile - u.linear_to_srgb(seen)).max(axis=2)[covered]
        self.assertLess(float((difference > 0.1).mean()), 0.03)
        self.assertLess(float(difference.mean()), 0.015)

    def test_copies_of_a_mesh_with_a_world_pattern_share_by_scale(self) -> None:
        material = brick_material("WorldBricks", coordinates="Position")
        wall = wall_object("Wall", material)
        copies = {"Wall": wall}
        for name, scale, location in (("Twin", 1.0, (5.0, 0.0, 0.0)), ("Large", 2.0, (0.0, 9.0, 0.0)), ("AlmostLarge", 2.1, (9.0, 9.0, 0.0))):
            copy = bpy.data.objects.new(name, wall.data)
            copy.scale = (scale, scale, scale)
            copy.location = location
            bpy.context.scene.collection.objects.link(copy)
            copies[name] = copy
        bpy.context.view_layer.update()
        objects = list(copies.values())
        u.prepare_material_bakes(objects)
        bake = u.material_bake_for(material)
        self.assertEqual(u.mesh_share_key(copies["Wall"]), u.mesh_share_key(copies["Twin"]))
        self.assertEqual(u.mesh_share_key(copies["Large"]), u.mesh_share_key(copies["AlmostLarge"]))
        self.assertNotEqual(u.mesh_share_key(copies["Wall"]), u.mesh_share_key(copies["Large"]))

        nodes = u.extract_nodes_from_objects(objects, Path(bpy.app.tempdir) / "scene.blend", validate=True)
        uv = {node.entity_name: np.array(node.mesh.validation_mesh.uv0).max(axis=0) for node in nodes}
        self.assertTrue(np.allclose(uv["Wall"], [3.0 / bake.tile[0], 2.5 / bake.tile[1]], atol=1.0e-3))
        self.assertTrue(np.allclose(uv["Twin"], uv["Wall"]))
        self.assertTrue(np.allclose(uv["Large"], uv["Wall"] * 2.0, atol=2.0e-3))
        self.assertTrue(np.allclose(uv["AlmostLarge"], uv["Large"]))

    def test_inputs_with_no_pattern_become_their_value(self) -> None:
        material, tree, principled = new_material("Plain")
        value = tree.nodes.new("ShaderNodeValue")
        value.outputs[0].default_value = 0.8
        remap = tree.nodes.new("ShaderNodeMapRange")
        remap.inputs["To Min"].default_value = 0.2
        remap.inputs["To Max"].default_value = 0.6
        tree.links.new(value.outputs[0], remap.inputs["Value"])
        tree.links.new(remap.outputs["Result"], principled.inputs["Roughness"])
        principled.inputs["Roughness"].default_value = 0.05   # the stale slider
        floor = floor_object("Floor", material)
        bake = self.bake_of(floor)
        self.assertFalse(bake.has_textures)
        self.assertAlmostEqual(bake.roughness, 0.2 + 0.8 * 0.4, places=3)
        exported = u.extract_material(floor, Path(bpy.app.tempdir) / "scene.blend")
        self.assertAlmostEqual(exported.roughness_factor, 0.52, places=3)
        self.assertIsNone(exported.roughness_texture)

    def test_a_pattern_on_the_uv_map_becomes_its_average_and_keeps_the_uvs(self) -> None:
        floor = floor_object("Floor", noise_material("Speckle", "UV"), with_uvs=True)
        bake = self.bake_of(floor)
        self.assertFalse(bake.has_textures)
        self.assertIsNotNone(bake.base_color)
        self.assertTrue(all(0.2 < component < 0.8 for component in bake.base_color))
        nodes = u.extract_nodes_from_objects([floor], Path(bpy.app.tempdir) / "scene.blend", validate=True)
        material = nodes[0].mesh.material
        self.assertIsNone(material.base_color_texture)
        self.assertTrue(np.allclose(material.base_color_factor[:3], bake.base_color, atol=0.02))
        self.assertEqual(sorted(nodes[0].mesh.validation_mesh.uv0), [(0.0, 0.0), (0.0, 1.0), (1.0, 0.0), (1.0, 1.0)])

    def test_baking_can_be_switched_off(self) -> None:
        floor = floor_object("Floor", noise_material("Rust", "Object"))
        u.MATERIAL_BAKE_OPTIONS.enabled = False
        u.prepare_material_bakes([floor])
        self.assertIsNone(u.material_bake_for(floor.data.materials[0]))

    def test_baking_leaves_the_scene_as_it_was(self) -> None:
        floor = floor_object("Floor", noise_material("Rust", "Object"))
        before = (len(bpy.data.scenes), len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.materials))
        self.bake_of(floor)
        self.assertEqual((len(bpy.data.scenes), len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.materials)), before)
        # The next export's bake takes the previous one's images away.
        names = set(u._MATERIAL_BAKE_IMAGE_NAMES)
        self.assertTrue(names)
        self.bake_of(floor)
        self.assertEqual(len([image for image in bpy.data.images if image.name.startswith("Rust_")]), len(names))

    def test_an_export_writes_the_textures_and_the_projected_uvs(self) -> None:
        wall = wall_object("Wall", brick_material())
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "wall.untold"
            source = Path(folder) / "scene.blend"
            nodes = u.extract_nodes_from_objects([wall], source)
            result = u.write_single_untold_from_nodes(
                nodes,
                exported_lights=[],
                exported_cameras=[],
                output_path=output,
                file_type_name="tile",
                compress_geometry=False,
                color_grade_lut_path=None,
                validate=False,
                progress_callback=None,
            )
            self.assertEqual(result["skipped_textures"], [])
            textures = sorted(path.name for path in (Path(folder) / "Textures").iterdir())
            self.assertEqual(len(textures), 1)
            self.assertRegex(textures[0], r"^Bricks_[0-9a-f]{6}_basecolor\.png$")
            bake_tile = None
            u.prepare_material_bakes([wall])
            bake_tile = u.material_bake_for(wall.data.materials[0]).tile
            vertices = read_untold_vertices(output)
            self.assertEqual(len(vertices), 4)
            for position, uv in vertices:
                # A wall in the plane x = 0: u runs along y, v up z, in repeats of the tile.
                self.assertAlmostEqual(uv[0], position[1] / bake_tile[0], delta=2.0e-3)
                self.assertAlmostEqual(uv[1], position[2] / bake_tile[1], delta=2.0e-3)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(MaterialBakeChecks)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
