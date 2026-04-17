import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import untoldexplorer as u


class UntoldExplorerTests(unittest.TestCase):
    def test_align_and_clamp_helpers(self) -> None:
        self.assertEqual(u.align(16, 16), 16)
        self.assertEqual(u.align(17, 16), 32)
        self.assertEqual(u.clamp(-1.0, 0.0, 1.0), 0.0)
        self.assertEqual(u.clamp(0.5, 0.0, 1.0), 0.5)
        self.assertEqual(u.clamp(2.0, 0.0, 1.0), 1.0)

    def test_normalize_and_pack_helpers_use_fallbacks_and_clamping(self) -> None:
        self.assertEqual(u.normalize3((0.0, 0.0, 0.0), (1.0, 2.0, 3.0)), (1.0, 2.0, 3.0))
        self.assertEqual(u.pack_snorm10(2.0), 511)
        self.assertEqual(u.pack_snorm10(-2.0), 513)
        self.assertEqual(u.pack_snorm2(-0.1), 3)
        self.assertEqual(u.pack_snorm2(0.0), 1)
        self.assertEqual(u.pack_normal((0.0, 0.0, 0.0)), u.pack_normal((0.0, 0.0, 1.0)))
        self.assertEqual(u.pack_tangent((0.0, 0.0, 0.0), -1.0), u.pack_tangent((1.0, 0.0, 0.0), -1.0))

    def test_binary_writer_alignment_and_string_table_dedup(self) -> None:
        writer = u.BinaryWriter()
        writer.write_u8(7)
        writer.align(4)
        writer.write_u16(9)

        self.assertEqual(writer.count, 6)
        self.assertEqual(writer.data, b"\x07\x00\x00\x00\x09\x00")

        strings = u.StringTableBuilder()
        first = strings.add("material")
        second = strings.add("material")
        third = strings.add("mesh")
        missing = strings.add(None)

        self.assertEqual(first, second)
        self.assertEqual(third, len("material") + 1)
        self.assertEqual(missing, u.INVALID_INDEX)
        self.assertEqual(strings.data, b"material\x00mesh\x00")

    def test_aabb_from_points_and_empty_input(self) -> None:
        bounds = u.aabb_from_points([(3.0, -1.0, 8.0), (-2.0, 4.0, 1.5), (0.0, 2.0, 9.0)])
        self.assertEqual(bounds.minimum, (-2.0, -1.0, 1.5))
        self.assertEqual(bounds.maximum, (3.0, 4.0, 9.0))

        with self.assertRaises(ValueError):
            u.aabb_from_points([])

    def test_write_vertex_emits_expected_stride_and_color_bytes(self) -> None:
        writer = u.BinaryWriter()
        u.write_vertex(
            writer,
            position=(1.0, 2.0, 3.0),
            normal=(0.0, 0.0, 1.0),
            tangent=(1.0, 0.0, 0.0),
            handedness=1.0,
            uv0=(0.5, 0.25),
            uv1=(1.0, 0.0),
            color0=(1.0, 0.5, 0.0, 0.25),
        )

        self.assertEqual(writer.count, u.VERTEX_STRIDE)

        px, py, pz = struct.unpack_from("<fff", writer.data, 0)
        self.assertEqual((px, py, pz), (1.0, 2.0, 3.0))
        self.assertEqual(writer.data[-4:], bytes([255, 128, 0, 64]))

    def test_write_header_uses_fixed_header_size(self) -> None:
        writer = u.BinaryWriter()
        u.write_header(
            writer,
            file_type=u.FILE_TYPES["tile"],
            chunk_count=2,
            mesh_count=3,
            material_count=4,
            texture_count=5,
            entity_count=6,
            world_bounds=u.AABB((0.0, 1.0, 2.0), (3.0, 4.0, 5.0)),
            root_transform_rows=[
                [1.0, 0.0, 0.0, 0.0],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0],
            ],
            content_hash=b"\xAB" * 32,
        )

        self.assertEqual(writer.count, u.HEADER_SIZE)
        self.assertEqual(writer.data[:8], u.MAGIC)
        self.assertEqual(struct.unpack_from("<I", writer.data, 8)[0], u.FORMAT_VERSION)
        self.assertEqual(struct.unpack_from("<I", writer.data, 20)[0], u.HEADER_SIZE)

    def test_validation_payload_and_file_write(self) -> None:
        mesh = u.ValidationMesh(
            name="Cube",
            vertex_count=3,
            index_count=3,
            positions=[(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)],
            normals=[(0.0, 0.0, 1.0)] * 3,
            tangents=[u.ValidationTangent((1.0, 0.0, 0.0), 1.0)] * 3,
            uv0=[(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)],
            indices=[0, 1, 2],
        )

        payload = u.build_validation_payload("cube_asset", [mesh])
        self.assertEqual(payload["format"], "untold-validation")
        self.assertEqual(payload["mesh_count"], 1)
        self.assertEqual(payload["meshes"][0]["name"], "Cube")

        with tempfile.TemporaryDirectory() as tmpdir:
            output_path = Path(tmpdir) / "cube.untold"
            validation_path = u.write_validation_file(output_path, "cube_asset", [mesh])

            self.assertEqual(validation_path, output_path.with_suffix(".validation.json"))
            written = json.loads(validation_path.read_text(encoding="utf-8"))
            self.assertEqual(written["asset_name"], "cube_asset")
            self.assertEqual(written["meshes"][0]["indices"], [0, 1, 2])

    def test_parse_args_handles_blender_style_separator(self) -> None:
        args = u.parse_args([
            "blender",
            "--background",
            "--python",
            "scripts/untoldexplorer.py",
            "--",
            "--input",
            "scene.usdz",
            "--output",
            "out/test.untold",
            "--file-type",
            "shared",
            "--mesh-name",
            "Building",
            "--ConvertOrientation",
            "--source-orientation",
            "engine-oriented",
            "--validate",
            "--animation",
        ])

        self.assertEqual(args.input, "scene.usdz")
        self.assertEqual(args.output, "out/test.untold")
        self.assertEqual(args.file_type, "shared")
        self.assertEqual(args.mesh_name, "Building")
        self.assertTrue(args.convert_orientation)
        self.assertEqual(args.source_orientation, "engine-oriented")
        self.assertTrue(args.validate)
        self.assertTrue(args.animation)

    def test_normalize_blender_path_and_blender_required(self) -> None:
        resolved = u.normalize_blender_path("./scripts/../scripts/untoldexplorer.py")
        self.assertEqual(resolved, (Path.cwd() / "scripts/untoldexplorer.py").resolve())

        with self.assertRaises(RuntimeError):
            u.blender_required()

    def test_normalize_weights_padding_case_stays_four_wide(self) -> None:
        weights = u.normalize_weights([0.75, 0.25])[:2]
        padded = weights + [0.0] * (4 - len(weights))
        self.assertEqual(len(padded), 4)
        self.assertAlmostEqual(sum(padded), 1.0)
        self.assertEqual(padded[2:], [0.0, 0.0])


if __name__ == "__main__":
    unittest.main()
