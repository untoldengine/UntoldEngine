import json
import math
import struct
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import untoldexplorer as u


class FakeVector:
    def __init__(self, values) -> None:
        self.x = float(values[0])
        self.y = float(values[1])
        self.z = float(values[2])

    def __getitem__(self, index: int) -> float:
        return (self.x, self.y, self.z)[index]


class FakeMatrix:
    def __init__(self, translation=(0.0, 0.0, 0.0)) -> None:
        self.translation = translation

    def to_3x3(self):
        return self

    def __matmul__(self, vector):
        return FakeVector(vector)


class FakeData:
    def __init__(self, **values) -> None:
        self.__dict__.update(values)


class FakeSceneObject:
    def __init__(self, name: str, object_type: str, data: FakeData, translation=(0.0, 0.0, 0.0)) -> None:
        self.name = name
        self.type = object_type
        self.data = data
        self.matrix_world = FakeMatrix(translation)


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
            edge_indices=[0, 1, 1, 2, 2, 0],
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
            self.assertEqual(written["meshes"][0]["edge_indices"], [0, 1, 1, 2, 2, 0])

    def test_build_architectural_edge_indices_skips_internal_diagonal(self) -> None:
        positions = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (1.0, 1.0, 0.0),
            (0.0, 1.0, 0.0),
        ]
        indices = [0, 1, 2, 0, 2, 3]

        edges = u.build_architectural_edge_indices(positions, indices)

        self.assertEqual(set(zip(edges[0::2], edges[1::2])), {(0, 1), (1, 2), (2, 3), (3, 0)})

    def test_build_architectural_edge_indices_keeps_hard_angle(self) -> None:
        positions = [
            (0.0, 0.0, 0.0),
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0),
        ]
        indices = [0, 1, 2, 0, 3, 1]

        edges = u.build_architectural_edge_indices(positions, indices)

        self.assertIn((0, 1), set(zip(edges[0::2], edges[1::2])))

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

    def test_extract_scene_payload_exports_sun_spot_and_camera_fields(self) -> None:
        original_bpy = u.bpy
        original_vector = u.Vector
        u.bpy = object()
        u.Vector = FakeVector
        try:
            sun = FakeSceneObject(
                "Sun",
                "LIGHT",
                FakeData(type="SUN", color=(1.0, 0.8, 0.6), energy=4.0, exposure=1.0),
                translation=(1.0, 2.0, 3.0),
            )
            spot = FakeSceneObject(
                "Spot",
                "LIGHT",
                FakeData(
                    type="SPOT",
                    color=(0.2, 0.4, 1.0),
                    energy=5.0,
                    spot_size=math.radians(40.0),
                    spot_blend=0.25,
                    shadow_soft_size=6.0,
                ),
                translation=(2.0, 3.0, 4.0),
            )
            camera = FakeSceneObject(
                "Camera",
                "CAMERA",
                FakeData(
                    angle_y=math.radians(55.0),
                    clip_start=0.05,
                    clip_end=750.0,
                    sensor_width=32.0,
                    sensor_height=20.0,
                    sensor_fit="AUTO",
                ),
                translation=(0.0, 1.0, 6.0),
            )

            lights, cameras = u.extract_scene_payload_from_objects([sun, spot, camera])
        finally:
            u.bpy = original_bpy
            u.Vector = original_vector

        self.assertEqual(len(lights), 2)
        self.assertEqual(len(cameras), 1)

        self.assertEqual(lights[0].entity_name, "Sun")
        self.assertEqual(lights[0].light_type, u.LIGHT_TYPE_DIRECTIONAL)
        self.assertEqual(lights[0].position, (1.0, 2.0, 3.0))
        self.assertAlmostEqual(lights[0].intensity, 8.0)

        self.assertEqual(lights[1].entity_name, "Spot")
        self.assertEqual(lights[1].light_type, u.LIGHT_TYPE_SPOT)
        self.assertAlmostEqual(lights[1].outer_cone, 40.0)
        self.assertAlmostEqual(lights[1].inner_cone, 30.0)
        self.assertAlmostEqual(lights[1].radius, 6.0)

        self.assertEqual(cameras[0].entity_name, "Camera")
        self.assertAlmostEqual(cameras[0].fov_y_degrees, 55.0)
        self.assertAlmostEqual(cameras[0].near_clip, 0.05)
        self.assertAlmostEqual(cameras[0].far_clip, 750.0)
        self.assertAlmostEqual(cameras[0].aspect_ratio, 1.6)

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


    def test_float_to_half_bits_known_values(self) -> None:
        # IEEE-754 half-precision reference values
        self.assertEqual(u.float_to_half_bits(0.0), 0x0000)
        self.assertEqual(u.float_to_half_bits(1.0), 0x3C00)
        self.assertEqual(u.float_to_half_bits(-1.0), 0xBC00)
        self.assertEqual(u.float_to_half_bits(0.5), 0x3800)

    def test_binary_writer_remaining_types(self) -> None:
        # write_u32
        w32 = u.BinaryWriter()
        w32.write_u32(0xDEADBEEF)
        self.assertEqual(w32.data, bytes([0xEF, 0xBE, 0xAD, 0xDE]))  # little-endian

        # write_u64
        w64 = u.BinaryWriter()
        w64.write_u64(0x0102030405060708)
        self.assertEqual(w64.count, 8)

        # write_f32 — IEEE-754 1.0f = 0x3F800000
        wf = u.BinaryWriter()
        wf.write_f32(1.0)
        self.assertEqual(wf.count, 4)
        self.assertEqual(int.from_bytes(wf.data, "little"), 0x3F800000)

        # write_c_string — null-terminated UTF-8
        ws = u.BinaryWriter()
        ws.write_c_string("hello")
        self.assertEqual(ws.data, b"hello\x00")
        self.assertEqual(ws.count, 6)

        # write_matrix4x4_column_major — 16 floats = 64 bytes
        wm = u.BinaryWriter()
        wm.write_matrix4x4_column_major(u.identity_matrix_rows())
        self.assertEqual(wm.count, 64)

    def test_aabb_corners_returns_eight_distinct_points(self) -> None:
        bounds = u.AABB((0.0, 0.0, 0.0), (1.0, 2.0, 3.0))
        corners = u.aabb_corners(bounds)
        self.assertEqual(len(corners), 8)
        # All combinations of min/max must appear
        self.assertIn((0.0, 0.0, 0.0), corners)
        self.assertIn((1.0, 2.0, 3.0), corners)
        self.assertIn((1.0, 0.0, 0.0), corners)
        self.assertIn((0.0, 2.0, 3.0), corners)
        # All 8 corners must be distinct
        self.assertEqual(len(set(corners)), 8)

    def test_matrix_rows_operations(self) -> None:
        I = u.identity_matrix_rows()

        # Identity × Identity = Identity
        self.assertEqual(u.matrix_rows_multiply(I, I), I)

        # Identity does not move a point
        pt = u.transform_point_rows(I, (1.0, 2.0, 3.0))
        self.assertAlmostEqual(pt[0], 1.0)
        self.assertAlmostEqual(pt[1], 2.0)
        self.assertAlmostEqual(pt[2], 3.0)

        # Identity does not rotate a direction
        d = u.transform_direction_rows(I, (0.0, 0.0, 1.0), (0.0, 0.0, 1.0))
        self.assertAlmostEqual(d[0], 0.0)
        self.assertAlmostEqual(d[1], 0.0)
        self.assertAlmostEqual(d[2], 1.0)

    def test_write_chunk_entry_and_record_sizes(self) -> None:
        # Chunk entry must be exactly CHUNK_ENTRY_SIZE bytes
        w = u.BinaryWriter()
        u.write_chunk_entry(
            w,
            chunk_type=u.CHUNK_TYPES["mesh_table"],
            compression_type=u.COMPRESSION_NONE,
            file_offset=256,
            compressed_size=1024,
            uncompressed_size=1024,
            element_count=5,
        )
        self.assertEqual(w.count, u.CHUNK_ENTRY_SIZE)

        # Entity record: 6×u32 + 2×AABB(24) + matrix4x4(64) = 24+24+24+64 = 136 bytes
        we = u.BinaryWriter()
        entity = u.EntityRecord(
            entity_id=1,
            parent_entity_id=u.INVALID_INDEX,
            name_offset=0,
            first_mesh_record_index=0,
            mesh_record_count=1,
            flags=0,
            local_bounds=u.AABB((0.0, 0.0, 0.0), (1.0, 1.0, 1.0)),
            world_bounds=u.AABB((0.0, 0.0, 0.0), (1.0, 1.0, 1.0)),
            local_transform_rows=u.identity_matrix_rows(),
        )
        u.write_entity_record(we, entity)
        self.assertEqual(we.count, 136)

        # Material record: 88 bytes (per assetFormat.md schema)
        wm = u.BinaryWriter()
        mat = u.MaterialRecord(
            name_offset=0, flags=0,
            base_color_factor=(1.0, 1.0, 1.0, 1.0),
            emissive_factor=(0.0, 0.0, 0.0),
            normal_scale=1.0, metallic_factor=0.0, roughness_factor=1.0,
            occlusion_strength=1.0, alpha_cutoff=0.5,
            base_color_texture_index=u.INVALID_INDEX,
            normal_texture_index=u.INVALID_INDEX,
            metallic_texture_index=u.INVALID_INDEX,
            roughness_texture_index=u.INVALID_INDEX,
            emissive_texture_index=u.INVALID_INDEX,
            occlusion_texture_index=u.INVALID_INDEX,
        )
        u.write_material_record(wm, mat)
        self.assertEqual(wm.count, 88)

        # Texture record: 8×u32 = 32 bytes
        wt = u.BinaryWriter()
        tex = u.TextureRecord(
            name_offset=0, uri_offset=0, texture_format=0, flags=0,
            width=512, height=512, mip_count=1,
        )
        u.write_texture_record(wt, tex)
        self.assertEqual(wt.count, 32)

    def test_main_rejects_non_usd_and_missing_input(self) -> None:
        import tempfile

        # Non-USD extension raises RuntimeError before any Blender call
        with tempfile.NamedTemporaryFile(suffix=".obj", delete=False) as f:
            non_usd = f.name
        with self.assertRaises(RuntimeError) as ctx:
            u.main(["script", "--input", non_usd, "--output", "/tmp/out.untold"])
        self.assertIn("Unsupported", str(ctx.exception))

        # Missing file raises RuntimeError before any Blender call
        with self.assertRaises(RuntimeError) as ctx2:
            u.main(["script", "--input", "/nonexistent/ghost.usdz", "--output", "/tmp/out.untold"])
        self.assertIn("does not exist", str(ctx2.exception))


if __name__ == "__main__":
    unittest.main()
