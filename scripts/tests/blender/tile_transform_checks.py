# Copyright (C) Untold Engine Studios
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Run with Blender --background --factory-startup --python-exit-code 1
--python scripts/tests/blender/tile_transform_checks.py.
"""

import math
import struct
import sys
import tempfile
import unittest
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import tilestreamingpartition as tiles
import untoldexplorer as exporter


def evaluated_world_vertices(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]


class TileTransformChecks(unittest.TestCase):
    def setUp(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.mesh.primitive_cube_add(location=(10, 20, 3))
        self.obj = bpy.context.object
        self.obj.rotation_euler.z = math.pi / 2
        self.obj.scale = (2, 0.5, 1)

    def assert_snapshot_matches(self):
        bpy.context.view_layer.update()
        expected = evaluated_world_vertices(self.obj)
        original_mesh = self.obj.data
        original_modifiers = len(self.obj.modifiers)
        scene = bpy.data.scenes.new("Tile transform check")
        try:
            snapshot = tiles.duplicate_objects_to_scene([self.obj], scene)[0]
            with tiles.scene_context(scene):
                actual = evaluated_world_vertices(snapshot)
            self.assertEqual(len(actual), len(expected))
            for before, after in zip(expected, actual):
                self.assertLess((before - after).length, 1e-4)
            self.assertEqual(len(snapshot.modifiers), 0)
            self.assertEqual(len(snapshot.constraints), 0)
            self.assertIs(self.obj.data, original_mesh)
            self.assertEqual(len(self.obj.modifiers), original_modifiers)
        finally:
            tiles.remove_scene(scene)

    def test_rotated_scaled_parented_array(self):
        parent = bpy.data.objects.new("Parent", None)
        bpy.context.scene.collection.objects.link(parent)
        parent.location = (4, -7, 2)
        parent.rotation_euler.x = 0.4
        self.obj.parent = parent
        array = self.obj.modifiers.new("Array", 'ARRAY')
        array.count = 4
        array.use_relative_offset = False
        array.use_constant_offset = True
        array.constant_offset_displace = (3, 0, 0)
        self.assert_snapshot_matches()

    def test_mirror_and_solidify(self):
        self.obj.data.vertices[0].co.x -= 1
        self.obj.modifiers.new("Mirror", 'MIRROR')
        solidify = self.obj.modifiers.new("Solidify", 'SOLIDIFY')
        solidify.thickness = 0.3
        self.assert_snapshot_matches()

    def test_constraint_is_baked_once(self):
        target = bpy.data.objects.new("Constraint target", None)
        bpy.context.scene.collection.objects.link(target)
        target.location = (-5, 6, 8)
        self.obj.constraints.new('COPY_LOCATION').target = target
        self.assert_snapshot_matches()

    def test_reflected_transform(self):
        self.obj.scale.x = -2
        self.assert_snapshot_matches()

    def test_rotated_array_is_clipped_in_world_space(self):
        self.obj.modifiers.new('Array', 'ARRAY').count = 2
        bpy.context.view_layer.update()
        scene = bpy.data.scenes.new('Tile clipping check')
        try:
            snapshots = tiles.duplicate_objects_to_scene([self.obj], scene)
            clipped, _ = tiles.clip_objects_to_tile(snapshots, {
                'min_x': 9.75, 'max_x': 10.25,
                'min_y': 0, 'max_y': 100,
                'min_z': 19, 'max_z': 25,
            }, 0)
            self.assertEqual(len(clipped), 1)
            with tiles.scene_context(scene):
                points = evaluated_world_vertices(clipped[0])
            minimum = tuple(min(p[i] for p in points) for i in range(3))
            maximum = tuple(max(p[i] for p in points) for i in range(3))
            for actual, expected in zip((*minimum, *maximum), (9.75, 19, 2, 10.25, 25, 4)):
                self.assertAlmostEqual(actual, expected, places=4)
        finally:
            tiles.remove_scene(scene)

    def test_material_split_keeps_object_linked_texture_material(self):
        mesh = self.obj.data
        for name in ('Data A', 'Data B'):
            mesh.materials.append(bpy.data.materials.new(name))
        for i, face in enumerate(mesh.polygons):
            face.material_index = i % 2
        override = bpy.data.materials.new('Object texture material')
        self.obj.material_slots[1].link = 'OBJECT'
        self.obj.material_slots[1].material = override
        bpy.context.view_layer.update()
        scene = bpy.data.scenes.new('Tile material check')
        try:
            copies = tiles.duplicate_objects_to_scene([self.obj], scene)
            fragments = tiles.split_objects_by_material(copies, scene)
            actual = {obj.material_slots[0].material.name for obj in fragments}
            self.assertEqual(actual, {'Data A', override.name})
            with tempfile.TemporaryDirectory() as folder:
                output = Path(folder) / 'split.untold'
                with tiles.scene_context(scene):
                    exporter.export_objects_to_untold(
                        fragments, source_asset_path=Path(folder) / 'scene.blend', output_path=output,
                    )
                data = output.read_bytes()
                count = struct.unpack_from('<I', data, 24)[0]
                chunks = {}
                for i in range(count):
                    kind, _, offset, size, _, elements, _ = struct.unpack_from('<IIQQQII', data, 204 + i * 40)
                    chunks[kind] = (data[offset:offset + size], elements)
                strings = chunks[1][0]
                materials, count = chunks[4]
                names = set()
                for i in range(count):
                    name_offset = struct.unpack_from('<I', materials, i * (len(materials) // count))[0]
                    names.add(strings[name_offset:].split(b'\0', 1)[0].decode())
                self.assertEqual(names, {'Data A', override.name})
                self.assertEqual(chunks[3][1], 2)
        finally:
            tiles.remove_scene(scene)

    def test_merge_preserves_textures_behind_color_nodes(self):
        other = self.obj.copy()
        other.data = self.obj.data.copy()
        bpy.context.scene.collection.objects.link(other)
        for i, obj in enumerate((self.obj, other)):
            image = bpy.data.images.new(f'Artwork {i}', width=4, height=4)
            mat = bpy.data.materials.new(f'Artwork material {i}')
            mat.use_nodes = True
            texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
            texture.image = image
            adjustment = mat.node_tree.nodes.new('ShaderNodeHueSaturation')
            principled = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            mat.node_tree.links.new(texture.outputs['Color'], adjustment.inputs['Color'])
            mat.node_tree.links.new(adjustment.outputs['Color'], principled.inputs['Base Color'])
            obj.data.materials.append(mat)
        bpy.context.view_layer.update()
        scene = bpy.data.scenes.new('Tile distinct materials check')
        try:
            snapshots = tiles.duplicate_objects_to_scene([self.obj, other], scene)
            merged = tiles.merge_objects_by_material(snapshots, scene)
            self.assertEqual(len(merged), 2, 'different artwork textures must keep their own surfaces')
            self.assertEqual(
                {obj.material_slots[0].material.name for obj in merged},
                {'Artwork material 0', 'Artwork material 1'},
            )
        finally:
            tiles.remove_scene(scene)

    def test_textured_array_survives_merge_and_native_export(self):
        image = bpy.data.images.new('Tile checker', width=4, height=4)
        image.pixels.foreach_set([0.2, 0.4, 0.6, 1.0] * 16)
        mat = bpy.data.materials.new('Tile checker material')
        mat.use_nodes = True
        texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = image
        principled = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        mat.node_tree.links.new(texture.outputs['Color'], principled.inputs['Base Color'])
        self.obj.data.materials.append(mat)
        array = self.obj.modifiers.new('Array', 'ARRAY')
        array.count = 3
        other = self.obj.copy()
        other.data = self.obj.data.copy()
        other.data.uv_layers[0].name = 'Different UV name'
        other.location = (-3, 1, 2)
        bpy.context.scene.collection.objects.link(other)
        bpy.context.view_layer.update()
        conversion = exporter.resolve_conversion_matrix(True, 'blender-native')
        expected = set()
        for obj in (self.obj, other):
            evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.data
            for loop in mesh.loops:
                point = conversion @ evaluated.matrix_world @ mesh.vertices[loop.vertex_index].co
                uv = mesh.uv_layers[0].data[loop.index].uv
                expected.add(tuple(round(v, 3) for v in (*point, *uv)))

        scene = bpy.data.scenes.new('Tile native export check')
        try:
            snapshots = tiles.duplicate_objects_to_scene([self.obj, other], scene)
            snapshots = tiles.split_objects_by_material(snapshots, scene)
            merged = tiles.merge_objects_by_material(snapshots, scene)
            self.assertEqual(len(merged), 1)
            with tempfile.TemporaryDirectory() as folder:
                output = Path(folder) / 'tile.untold'
                with tiles.scene_context(scene):
                    exporter.export_objects_to_untold(
                        merged, source_asset_path=Path(folder) / 'scene.blend',
                        output_path=output, convert_orientation=True,
                    )
                data = output.read_bytes()
                count = struct.unpack_from('<I', data, 24)[0]
                chunks = {}
                for i in range(count):
                    kind, compression, offset, size, _, elements, _ = struct.unpack_from(
                        '<IIQQQII', data, 204 + 40 * i
                    )
                    self.assertEqual(compression, 0)
                    chunks[kind] = (data[offset:offset + size], elements)
                vertices = chunks[6][0]
                actual = set()
                for offset in range(0, len(vertices), 32):
                    point = struct.unpack_from('<3f', vertices, offset)
                    uv = struct.unpack_from('<2e', vertices, offset + 20)
                    actual.add(tuple(round(v, 3) for v in (*point, *uv)))
                self.assertEqual(actual, expected)
                strings = chunks[1][0]
                textures, count = chunks[5]
                self.assertEqual(count, 1)
                uri_offset = struct.unpack_from('<I', textures, 4)[0]
                uri = strings[uri_offset:].split(b'\0', 1)[0].decode()
                texture_path = output.parent / uri
                self.assertTrue(exporter._png_is_complete(texture_path))
                decoded = bpy.data.images.load(str(texture_path), check_existing=False)
                try:
                    self.assertEqual(tuple(decoded.size), (4, 4))
                    for wanted, written in zip(image.pixels[:4], decoded.pixels[:4]):
                        self.assertAlmostEqual(wanted, written, delta=1 / 255)
                finally:
                    bpy.data.images.remove(decoded)
        finally:
            tiles.remove_scene(scene)


if __name__ == '__main__':
    unittest.main(argv=[__file__])
