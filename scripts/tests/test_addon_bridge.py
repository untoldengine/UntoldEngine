# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Tests for what the Blender add-on does with the result of an export
(scripts/untold-blender-addon/untold_exporter/bridge.py).

bridge.py imports bpy at module level, so it is loaded here with a stand-in for it. The
Blender side of an export (finding and extracting objects) is left out: the stand-in
exporter hands hand-made nodes to the exporter's own writers, so the files, their names
and their folders are the real ones.
"""

import contextlib
import importlib.util
import io
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

# Before bridge.py is loaded: the exporter decides at import whether it runs in Blender.
import texbake as t  # noqa: E402
import untoldexplorer as u  # noqa: E402

BRIDGE_PATH = SCRIPT_DIR / "untold-blender-addon" / "untold_exporter" / "bridge.py"


def _load_bridge():
    """bridge.py as a module of its own, with a stand-in for bpy while it loads."""
    spec = importlib.util.spec_from_file_location("untold_exporter_bridge_under_test", BRIDGE_PATH)
    module = importlib.util.module_from_spec(spec)
    with mock.patch.dict(sys.modules, {"bpy": mock.MagicMock()}):
        spec.loader.exec_module(module)
    return module


def _textured_node(name: str, texture_source: Path, *, scale: float = 1.0) -> "u.ExportedNode":
    """A one-triangle model whose material has the image as its base colour texture."""
    positions = [(0.0, 0.0, 0.0), (scale, 0.0, 0.0), (0.0, scale, 0.0)]
    vertices = b"".join(
        struct.pack("<3fII", *position, u.pack_normal((0.0, 0.0, 1.0)), u.pack_tangent((1.0, 0.0, 0.0), 1.0))
        + b"\x00" * (u.VERTEX_STRIDE - 20)
        for position in positions
    )
    bounds = u.aabb_from_points(positions)
    texture = u.ExportedTexture(
        name=texture_source.name, uri=texture_source.name, width=4, height=4, mip_count=1, source_path=texture_source
    )
    material = u.ExportedMaterial(
        name="paint", base_color_factor=(1.0, 1.0, 1.0, 1.0), emissive_factor=(0.0, 0.0, 0.0),
        normal_scale=1.0, metallic_factor=0.0, roughness_factor=0.5, occlusion_strength=1.0,
        alpha_cutoff=0.5, base_color_texture=texture,
    )
    rows = u.identity_matrix_rows()
    mesh = u.ExportedMesh(
        entity_name=name, parent_entity_name=None, mesh_name=name, local_transform_rows=rows,
        local_bounds=bounds, world_bounds=bounds, vertices=vertices,
        indices=u.pack_index_data([0, 1, 2], u.INDEX_TYPE_UINT16), edge_indices=b"",
        vertex_count=3, index_count=3, edge_index_count=0, index_type=u.INDEX_TYPE_UINT16,
        material=material, skin_binding=None,
        validation_mesh=u.ValidationMesh(name=name, vertex_count=3, index_count=3, positions=positions,
                                         normals=[], tangents=[], uv0=[], indices=[0, 1, 2], edge_indices=[]),
    )
    return u.ExportedNode(entity_name=name, parent_entity_name=None, local_transform_rows=rows,
                          local_bounds=bounds, world_bounds=bounds, mesh=mesh)


def _texture_uris(untold_path: Path) -> list[str]:
    """The texture URIs a written .untold holds."""
    raw = untold_path.read_bytes()
    header = struct.unpack_from(t._UNTOLD_HEADER_FMT, raw, 0)
    chunks = []
    for index in range(header[5]):
        fields = struct.unpack_from(t._UNTOLD_CHUNK_FMT, raw, t._UNTOLD_HEADER_SIZE + index * t._UNTOLD_CHUNK_ENTRY_SIZE)
        chunks.append({
            "chunk_type": fields[0], "compression_type": fields[1], "file_offset": fields[2],
            "compressed_size": fields[3], "uncompressed_size": fields[4], "element_count": fields[5],
        })
    strings = t._decompress_chunk(raw, next(c for c in chunks if c["chunk_type"] == t._CHUNK_STRING_TABLE))
    table = next(c for c in chunks if c["chunk_type"] == t._CHUNK_TEXTURE_TABLE)
    records = t._decompress_chunk(raw, table)
    size = struct.calcsize(t._UNTOLD_TEXTURE_FMT)
    uris = []
    for index in range(table["element_count"]):
        uri_offset = struct.unpack_from(t._UNTOLD_TEXTURE_FMT, records, index * size)[1]
        uris.append(strings[uri_offset:strings.index(b"\x00", uri_offset)].decode("utf-8"))
    return uris


class _TexbakeWithoutEncoder:
    """texbake as the bridge uses it, with the ASTC encoder left out: baking a folder
    leaves a .utex beside each texture, and patching a file is texbake's own."""

    def __init__(self) -> None:
        self.baked: list[tuple[Path, list[Path] | None]] = []
        self.patched: list[Path] = []

    def bake_directory(self, directory, quality, keep_temp, progress_callback=None, untold_files=None) -> None:
        self.baked.append((directory, list(untold_files) if untold_files is not None else None))
        for source in sorted(directory.iterdir()):
            if source.suffix.lower() == ".png":
                source.with_suffix(".utex").write_bytes(b"UTEX\x00\x00\x00\x00" + b"\x00" * 16)

    def patch_refs(self, untold_path: Path) -> None:
        self.patched.append(untold_path)
        t.patch_refs(untold_path)


class AddonTextureBakeTests(unittest.TestCase):
    """The add-on's "Bake textures" bakes and patches what the export wrote."""

    def setUp(self) -> None:
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)
        self.source = self.root / "source" / "wall.png"
        self.source.parent.mkdir()
        self.source.write_bytes(b"png bytes")
        self.output_dir = self.root / "Models"
        self.bridge = _load_bridge()
        self.texbake = _TexbakeWithoutEncoder()

    def tearDown(self) -> None:
        self.tmpdir.cleanup()

    def _export(self, models: dict[str, list["u.ExportedNode"]], output_name: str) -> dict:
        """export_asset on a scene that holds these models."""

        def export_objects_to_untold_or_pack(export_objects, *, output_path, file_type_name, validate, compress_geometry,
                                             progress_callback, **_):
            if len(models) == 1:
                return u.write_single_untold_from_nodes(
                    next(iter(models.values())), exported_lights=[], exported_cameras=[], output_path=output_path,
                    file_type_name=file_type_name, compress_geometry=compress_geometry, color_grade_lut_path=None,
                    validate=validate, progress_callback=progress_callback,
                )
            return u.write_untold_pack_from_groups(
                models, source_asset_name="scene.blend", output_path=output_path, file_type_name=file_type_name,
                compress_geometry=compress_geometry, validate=validate, progress_callback=progress_callback,
            )

        exporter = SimpleNamespace(
            prepare_export_objects_from_blender_objects=lambda objects: list(objects),
            export_objects_to_untold_or_pack=export_objects_to_untold_or_pack,
            stage_hdr_assets_for_output=lambda output_dir, source_asset_path: [],
        )
        bridge = self.bridge
        scene_object = SimpleNamespace(as_pointer=lambda: 1)
        with (
            mock.patch.object(bridge, "exporter_module", lambda: exporter),
            mock.patch.object(bridge, "texbake_module", lambda: self.texbake),
            mock.patch.object(bridge, "scene_export_candidates", lambda context, scope: [scene_object]),
            mock.patch.object(bridge, "scene_payload_candidates", lambda context, scope: []),
            mock.patch.object(bridge, "source_asset_path_for_export", lambda output_path: self.root / "scene.blend"),
            mock.patch.object(u, "bpy", None),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            return bridge.export_asset(
                context=None, output_path=self.output_dir / output_name, scope="ALL", file_type_name="tile",
                convert_orientation=False, source_orientation="blender-native", validate=False,
                compress_geometry=False, bake_textures=True, texture_quality="medium", keep_texture_temp=False,
            )

    def test_one_model_written_under_a_packs_name_is_baked_where_it_was_written(self) -> None:
        """A scene with one model is written as a single .untold whatever the output
        names. Asked for scene.untoldpack, the bake went on to patch that name, a file
        that is not there, and the export failed after it had written scene.untold."""
        result = self._export({"Wall": [_textured_node("Wall", self.source)]}, "scene.untoldpack")

        written = self.output_dir / "scene.untold"
        self.assertEqual(result["output_path"], written)
        self.assertFalse((self.output_dir / "scene.untoldpack").exists())
        self.assertEqual(result["texture_bake_status"], "baked")
        self.assertEqual(self.texbake.baked, [(self.output_dir / "Textures", [written])])
        self.assertEqual(self.texbake.patched, [written])
        self.assertEqual(_texture_uris(written), ["Textures/wall.utex"])

    def test_a_single_model_named_as_such_is_baked_as_before(self) -> None:
        result = self._export({"Wall": [_textured_node("Wall", self.source)]}, "scene.untold")

        written = self.output_dir / "scene.untold"
        self.assertEqual(result["texture_bake_status"], "baked")
        self.assertEqual(self.texbake.patched, [written])
        self.assertEqual(_texture_uris(written), ["Textures/wall.utex"])

    def test_a_packs_shared_textures_are_baked_once_and_every_model_patched(self) -> None:
        """The models of a pack share one Textures folder beside their own folders. The
        bake looked for a folder in each model's own, found none and baked nothing."""
        models = {
            "Wall": [_textured_node("Wall", self.source)],
            "Tower": [_textured_node("Tower", self.source, scale=2.0)],
        }
        result = self._export(models, "scene.untold")

        self.assertTrue(result["is_pack"])
        model_paths = list(result["model_paths"])
        self.assertEqual(len(model_paths), 2)
        self.assertEqual(result["texture_bake_status"], "baked")
        self.assertEqual(self.texbake.baked, [(self.output_dir / "Textures", model_paths)])
        self.assertEqual(self.texbake.patched, model_paths)
        for model_path in model_paths:
            self.assertEqual(_texture_uris(model_path), ["../Textures/wall.utex"])

    def test_an_export_without_textures_says_so(self) -> None:
        node = _textured_node("Wall", self.source)
        bare = u.replace(node, mesh=u.replace(node.mesh, material=u.replace(node.mesh.material, base_color_texture=None)))
        result = self._export({"Wall": [bare]}, "scene.untold")

        self.assertEqual(result["texture_bake_status"], "no textures")
        self.assertEqual(self.texbake.baked, [])
        self.assertEqual(self.texbake.patched, [])


if __name__ == "__main__":
    unittest.main()
