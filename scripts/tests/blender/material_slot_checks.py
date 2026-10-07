# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Checks that a multi-material object keeps the materials its slots show when the
export splits it: a slot linked to the object overrides the mesh data's material, as
an IFC import links a material to each object over a mesh shared by hundreds of them.
They need a real Blender (bmesh and the separate operator). Run them from the
repository root:

    blender --background --factory-startup --python-exit-code 1 \
        --python scripts/tests/blender/material_slot_checks.py
"""

import sys
import unittest
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parents[2]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import untoldexplorer as u


def material(name: str):
    created = bpy.data.materials.new(name)
    created.use_nodes = True
    return created


def two_material_cube(name: str, mesh=None):
    """A cube whose faces use slot 0 and slot 1 half and half; with `mesh`, a linked
    duplicate of that cube (one mesh datablock, its own object)."""
    if mesh is None:
        bpy.ops.mesh.primitive_cube_add()
        cube = bpy.context.active_object
        mesh = cube.data
        bpy.data.objects.remove(cube)
        mesh.materials.append(material(f"{name} data 0"))
        mesh.materials.append(material(f"{name} data 1"))
        for index, polygon in enumerate(mesh.polygons):
            polygon.material_index = 0 if index < 3 else 1
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def override_slot(obj, index: int, name: str):
    """Links slot `index` to the object and gives it its own material."""
    slot = obj.material_slots[index]
    slot.link = "OBJECT"
    slot.material = material(name)
    return slot.material


def materials_by_source(fragments) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    for fragment in fragments:
        source = fragment.get(u.UNTOLD_MATERIAL_SPLIT_SOURCE_PROP) or fragment.name
        result.setdefault(source, set()).add(u.mesh_object_material(fragment).name)
    return result


class MaterialSlotChecks(unittest.TestCase):
    def tearDown(self) -> None:
        u.cleanup_temporary_export_objects([])
        for collection in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.materials):
            for block in list(collection):
                collection.remove(block)

    def test_a_slot_linked_to_the_object_is_what_its_fragment_exports(self) -> None:
        cube = two_material_cube("Chair")
        override_slot(cube, 1, "Chair wood")
        fragments = u.split_blender_objects_by_material([cube])
        self.assertEqual(len(fragments), 2)
        self.assertEqual(materials_by_source(fragments), {"Chair": {"Chair data 0", "Chair wood"}})

    def test_linked_duplicates_keep_their_own_object_materials(self) -> None:
        first = two_material_cube("First")
        second = two_material_cube("Second", mesh=first.data)
        override_slot(first, 1, "First wood")
        override_slot(second, 1, "Second steel")
        fragments = u.split_blender_objects_by_material([first, second])
        self.assertEqual(len(fragments), 4)
        self.assertEqual(
            materials_by_source(fragments),
            {"First": {"First data 0", "First wood"}, "Second": {"First data 0", "Second steel"}},
        )

    def test_the_export_carries_the_object_material(self) -> None:
        cube = two_material_cube("Chair")
        override_slot(cube, 1, "Chair wood")
        prepared = u.prepare_export_objects_from_blender_objects([cube])
        nodes = u.extract_nodes_from_objects(prepared, Path(bpy.app.tempdir) / "scene.blend", validate=True)
        exported = {node.mesh.material.name for node in nodes if node.mesh is not None}
        self.assertEqual(exported, {"Chair data 0", "Chair wood"})

    def test_a_rigged_object_keeps_the_object_material_of_each_piece(self) -> None:
        cube = two_material_cube("Rigged")
        override_slot(cube, 1, "Rigged wood")
        armature = bpy.data.objects.new("Rig", bpy.data.armatures.new("Rig"))
        bpy.context.scene.collection.objects.link(armature)
        modifier = cube.modifiers.new("Armature", "ARMATURE")
        modifier.object = armature
        fragments = u.split_blender_objects_by_material([cube])
        self.assertEqual(len(fragments), 2)
        self.assertEqual(materials_by_source(fragments), {"Rigged": {"Rigged data 0", "Rigged wood"}})


if __name__ == "__main__":
    argv = [sys.argv[0]] + (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    unittest.main(argv=argv, exit=True)
