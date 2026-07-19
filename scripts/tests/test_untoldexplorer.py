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

class FakeSocket:
    def __init__(self, name: str = "") -> None:
        self.name = name
        self.is_linked = False
        self.links = []

    def link_from(self, from_node: object, from_socket_name: str) -> None:
        self.is_linked = True
        self.links = [FakeLink(from_node, FakeSocket(from_socket_name))]


class FakeLink:
    def __init__(self, from_node: object, from_socket: FakeSocket) -> None:
        self.from_node = from_node
        self.from_socket = from_socket


class FakeNode:
    def __init__(self, bl_idname: str, *, image: object = None, inputs: dict[str, FakeSocket] | None = None) -> None:
        self.bl_idname = bl_idname
        self.image = image
        self.inputs = inputs or {}


class UntoldExplorerTests(unittest.TestCase):
    def test_align_and_clamp_helpers(self) -> None:
        self.assertEqual(u.align(16, 16), 16)
        self.assertEqual(u.align(17, 16), 32)
        self.assertEqual(u.clamp(-1.0, 0.0, 1.0), 0.0)
        self.assertEqual(u.clamp(0.5, 0.0, 1.0), 0.5)
        self.assertEqual(u.clamp(2.0, 0.0, 1.0), 1.0)
    def test_material_texture_channel_helpers(self) -> None:
        self.assertEqual(
            u.pack_material_texture_channels(u.TEXTURE_CHANNEL_R, u.TEXTURE_CHANNEL_G),
            0b0100,
        )
        self.assertEqual(
            u.pack_material_texture_channels(u.TEXTURE_CHANNEL_B, u.TEXTURE_CHANNEL_A),
            0b1110,
        )
        self.assertEqual(u.pack_material_texture_channels(99, -1), 0)

        self.assertEqual(u.texture_channel_from_socket_name("Red", u.TEXTURE_CHANNEL_B), u.TEXTURE_CHANNEL_R)
        self.assertEqual(u.texture_channel_from_socket_name("G", u.TEXTURE_CHANNEL_R), u.TEXTURE_CHANNEL_G)
        self.assertEqual(u.texture_channel_from_socket_name("Alpha", u.TEXTURE_CHANNEL_R), u.TEXTURE_CHANNEL_A)
        self.assertEqual(u.texture_channel_from_socket_name("Color", u.TEXTURE_CHANNEL_B), u.TEXTURE_CHANNEL_B)

    def test_resolve_texture_from_socket_preserves_separate_rgb_channel(self) -> None:
        image = FakeData(filepath="textures/packed.png", library=None, size=(256, 128), name="packed")
        image_node = FakeNode("ShaderNodeTexImage", image=image)
        separate_input = FakeSocket("Image")
        separate_input.link_from(image_node, "Color")
        separate_node = FakeNode("ShaderNodeSeparateRGB", inputs={"Image": separate_input})
        metallic_input = FakeSocket("Metallic")
        metallic_input.link_from(separate_node, "G")

        with tempfile.TemporaryDirectory() as tmpdir:
            texture = u.resolve_texture_from_socket(metallic_input, Path(tmpdir) / "asset.untold")

        self.assertIsNotNone(texture)
        self.assertEqual(texture.channel, u.TEXTURE_CHANNEL_G, "SeparateRGB G output should map to green")
        self.assertTrue(texture.uri.endswith("textures/packed.png"))

    def test_resolve_texture_from_socket_preserves_image_alpha_channel(self) -> None:
        image = FakeData(filepath="textures/mask.png", library=None, size=(64, 64), name="mask")
        image_node = FakeNode("ShaderNodeTexImage", image=image)
        alpha_input = FakeSocket("Alpha")
        alpha_input.link_from(image_node, "Alpha")

        with tempfile.TemporaryDirectory() as tmpdir:
            texture = u.resolve_texture_from_socket(alpha_input, Path(tmpdir) / "asset.untold")

        self.assertIsNotNone(texture)
        self.assertEqual(texture.channel, u.TEXTURE_CHANNEL_A)

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

    def test_extract_scene_payload_exports_sun_spot_area_and_camera_fields(self) -> None:
        original_bpy = u.bpy
        original_vector = u.Vector
        u.bpy = FakeData(
            context=FakeData(scene=FakeData(unit_settings=FakeData(scale_length=1.0)))
        )
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
            area = FakeSceneObject(
                "Area",
                "LIGHT",
                FakeData(
                    type="AREA",
                    color=(1.0, 1.0, 1.0),
                    energy=7.0,
                    shape="RECTANGLE",
                    size=3.0,
                    size_y=2.0,
                ),
                translation=(3.0, 4.0, 5.0),
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

            lights, cameras = u.extract_scene_payload_from_objects([sun, spot, area, camera])
        finally:
            u.bpy = original_bpy
            u.Vector = original_vector

        self.assertEqual(len(lights), 3)
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

        self.assertEqual(lights[2].entity_name, "Area")
        self.assertEqual(lights[2].light_type, u.LIGHT_TYPE_AREA)
        self.assertEqual(lights[2].position, (3.0, 4.0, 5.0))
        self.assertEqual(lights[2].direction, (0.0, 0.0, -1.0))
        self.assertEqual(lights[2].right, (1.0, 0.0, 0.0))
        self.assertEqual(lights[2].up, (0.0, 1.0, 0.0))
        self.assertEqual(lights[2].area_size, (3.0, 2.0))
        self.assertEqual(
            lights[2].local_transform_rows,
            [
                [1.0, 0.0, 0.0, 3.0],
                [0.0, 1.0, 0.0, 4.0],
                [0.0, 0.0, 1.0, 5.0],
                [0.0, 0.0, 0.0, 1.0],
            ],
        )

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
            roughness_texture_channel=u.TEXTURE_CHANNEL_G,
            metallic_texture_channel=u.TEXTURE_CHANNEL_B,
        )
        u.write_material_record(wm, mat)
        self.assertEqual(wm.count, 88)
        self.assertEqual(struct.unpack_from("<I", wm.data, 80)[0], 0b1001)

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


def _make_image_node(name: str = "tex") -> FakeNode:
    image = FakeData(filepath=f"textures/{name}.png", library=None, size=(64, 64), name=name)
    node = FakeNode("ShaderNodeTexImage", image=image)
    node.name = name
    return node


def _make_principled_output(base_color_source: FakeNode | None, base_color_socket: str = "Color") -> tuple[FakeNode, FakeNode]:
    base_color = FakeSocket("Base Color")
    if base_color_source is not None:
        base_color.link_from(base_color_source, base_color_socket)
    principled = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Base Color": base_color})
    principled.name = "Principled BSDF"
    surface = FakeSocket("Surface")
    surface.link_from(principled, "BSDF")
    output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": surface})
    output.name = "Material Output"
    return principled, output


def _make_material(name: str, nodes: list[FakeNode]) -> FakeData:
    return FakeData(name=name, node_tree=FakeData(nodes=nodes))


class MaterialGraphAnalysisTests(unittest.TestCase):
    def test_texture_into_principled_is_supported(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        analysis = u.analyze_material(_make_material("ok_mat", [output, principled, tex]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_SUPPORTED)
        self.assertEqual(analysis.findings, [])

    def test_mix_node_is_bakeable(self) -> None:
        tex_a = _make_image_node("a")
        tex_b = _make_image_node("b")
        input_a = FakeSocket("A")
        input_a.link_from(tex_a, "Color")
        input_b = FakeSocket("B")
        input_b.link_from(tex_b, "Color")
        mix = FakeNode("ShaderNodeMix", inputs={"A": input_a, "B": input_b})
        mix.name = "Mix"
        principled, output = _make_principled_output(mix, "Result")
        analysis = u.analyze_material(_make_material("mix_mat", [output, principled, mix, tex_a, tex_b]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_BAKEABLE)
        self.assertEqual([f.node_type for f in analysis.findings], ["ShaderNodeMix"])

    def test_fresnel_makes_material_unbakeable(self) -> None:
        fresnel = FakeNode("ShaderNodeFresnel")
        fresnel.name = "Fresnel"
        fac = FakeSocket("Factor")
        fac.link_from(fresnel, "Fac")
        mix = FakeNode("ShaderNodeMix", inputs={"Factor": fac})
        mix.name = "Mix"
        principled, output = _make_principled_output(mix, "Result")
        analysis = u.analyze_material(_make_material("fresnel_mat", [output, principled, mix, fresnel]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_UNBAKEABLE)
        categories = {f.node_type: f.category for f in analysis.findings}
        self.assertEqual(categories["ShaderNodeFresnel"], u.MATERIAL_GRAPH_UNBAKEABLE)

    def test_identity_mapping_is_supported_but_scaled_mapping_is_bakeable(self) -> None:
        def make_mapping(scale: tuple[float, float, float]) -> FakeNode:
            tex = _make_image_node()
            location = FakeSocket("Location")
            location.default_value = (0.0, 0.0, 0.0)
            rotation = FakeSocket("Rotation")
            rotation.default_value = (0.0, 0.0, 0.0)
            scale_socket = FakeSocket("Scale")
            scale_socket.default_value = scale
            vector = FakeSocket("Vector")
            mapping = FakeNode(
                "ShaderNodeMapping",
                inputs={"Location": location, "Rotation": rotation, "Scale": scale_socket, "Vector": vector},
            )
            mapping.name = "Mapping"
            color = FakeSocket("Color")
            color.link_from(mapping, "Vector")
            tex.inputs = {"Vector": color}
            return tex

        tex_identity = make_mapping((1.0, 1.0, 1.0))
        principled, output = _make_principled_output(tex_identity)
        analysis = u.analyze_material(_make_material("id_mat", [output, principled, tex_identity]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_SUPPORTED)

        tex_scaled = make_mapping((2.0, 1.0, 1.0))
        principled, output = _make_principled_output(tex_scaled)
        analysis = u.analyze_material(_make_material("scaled_mat", [output, principled, tex_scaled]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_BAKEABLE)
        self.assertEqual([f.node_type for f in analysis.findings], ["ShaderNodeMapping"])

    def test_unconnected_nodes_are_not_flagged(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        stray_noise = FakeNode("ShaderNodeTexNoise")
        stray_noise.name = "Noise Texture"
        analysis = u.analyze_material(_make_material("ao_mat", [output, principled, tex, stray_noise]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_SUPPORTED)

    def test_node_group_contents_are_analyzed(self) -> None:
        noise = FakeNode("ShaderNodeTexNoise")
        noise.name = "Noise Texture"
        group_result = FakeSocket("Result")
        group_result.link_from(noise, "Color")
        group_output = FakeNode("NodeGroupOutput", inputs={"Result": group_result})
        group = FakeNode("ShaderNodeGroup")
        group.name = "NodeGroup"
        group.node_tree = FakeData(nodes=[group_output, noise])
        principled, output = _make_principled_output(group, "Result")
        analysis = u.analyze_material(_make_material("group_mat", [output, principled, group]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_BAKEABLE)
        self.assertEqual([f.node_type for f in analysis.findings], ["ShaderNodeTexNoise"])

    def test_animated_node_tree_is_unbakeable(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        material = _make_material("anim_mat", [output, principled, tex])
        material.node_tree.animation_data = FakeData(action=FakeData(name="mat_action"), drivers=[])
        analysis = u.analyze_material(material)
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_UNBAKEABLE)

    def test_report_lines_summarize_and_warn_on_missing_uvs(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        supported_material = _make_material("ok_mat", [output, principled, tex])

        input_a = FakeSocket("A")
        input_a.link_from(_make_image_node("a"), "Color")
        mix = FakeNode("ShaderNodeMix", inputs={"A": input_a})
        mix.name = "Mix"
        principled2, output2 = _make_principled_output(mix, "Result")
        bakeable_material = _make_material("mix_mat", [output2, principled2, mix])

        supported_mesh = FakeSceneObject("Floor", "MESH", FakeData(materials=[supported_material], uv_layers=[]))
        bakeable_mesh = FakeSceneObject("Wall", "MESH", FakeData(materials=[bakeable_material], uv_layers=[]))

        lines = u.material_fidelity_report_lines([supported_mesh, bakeable_mesh])
        self.assertIn("1 supported, 1 bakeable, 0 unbakeable", lines[0])
        self.assertTrue(any("mix_mat" in line and "[bakeable]" in line for line in lines))
        self.assertTrue(any("Wall" in line and "no UV map" in line for line in lines))
        # The supported mesh has no UVs either, but is never flagged: no bake needed.
        self.assertFalse(any("Floor" in line for line in lines))

    def test_compute_material_fidelity_exposes_structured_data(self) -> None:
        """The addon's pre-export panel needs structured per-material data
        (not pre-formatted text) to render classification/reason as UI rows."""
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        supported_material = _make_material("ok_mat", [output, principled, tex])

        input_a = FakeSocket("A")
        input_a.link_from(_make_image_node("a"), "Color")
        mix = FakeNode("ShaderNodeMix", inputs={"A": input_a})
        mix.name = "Mix"
        principled2, output2 = _make_principled_output(mix, "Result")
        bakeable_material = _make_material("mix_mat", [output2, principled2, mix])

        supported_mesh = FakeSceneObject("Floor", "MESH", FakeData(materials=[supported_material], uv_layers=[]))
        bakeable_mesh = FakeSceneObject("Wall", "MESH", FakeData(materials=[bakeable_material], uv_layers=[]))

        report = u.compute_material_fidelity([supported_mesh, bakeable_mesh])
        self.assertEqual(set(report.analyses_by_name), {"ok_mat", "mix_mat"})
        self.assertEqual(report.analyses_by_name["ok_mat"].classification, u.MATERIAL_GRAPH_SUPPORTED)
        mix_analysis = report.analyses_by_name["mix_mat"]
        self.assertEqual(mix_analysis.classification, u.MATERIAL_GRAPH_BAKEABLE)
        self.assertEqual(mix_analysis.findings[0].node_type, "ShaderNodeMix")
        self.assertTrue(any("Wall" in w and "no UV map" in w for w in report.uv_warnings))

        # material_fidelity_report_lines must still produce identical output
        # built on top of the same structured data (behavior-preserving refactor).
        lines = u.material_fidelity_report_lines([supported_mesh, bakeable_mesh])
        self.assertIn("1 supported, 1 bakeable, 0 unbakeable", lines[0])

    def test_safe_bake_stem_sanitizes_material_names(self) -> None:
        self.assertEqual(u._safe_bake_stem("wall mat.001"), "wall_mat_001")
        self.assertEqual(u._safe_bake_stem(""), "material")

    def test_extract_material_substitutes_baked_channels(self) -> None:
        tex = _make_image_node("original")
        principled, output = _make_principled_output(tex)
        material = _make_material("baked_mat", [output, principled, tex])
        mesh_object = FakeSceneObject("Wall", "MESH", FakeData(materials=[material]))

        def make_baked(suffix: str) -> u.ExportedTexture:
            return u.ExportedTexture(
                name=f"baked_mat_{suffix}.png", uri=f"baked_mat_{suffix}.png",
                width=1024, height=1024, mip_count=1,
                source_path=Path(f"/tmp/bake/baked_mat_{suffix}.png"),
            )

        baked = u.BakedMaterialTextures(
            base_color=make_baked("basecolor"),
            orm=make_baked("orm"),
            normal=make_baked("normal"),
        )
        u._baked_material_textures["Wall"] = baked  # keyed by mesh object name, not material name
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")
        finally:
            u._baked_material_textures.clear()

        self.assertIs(exported.base_color_texture, baked.base_color)
        self.assertEqual(exported.base_color_factor[:3], (1.0, 1.0, 1.0))
        self.assertEqual(exported.roughness_texture.uri, "baked_mat_orm.png")
        self.assertEqual(exported.roughness_texture_channel, u.TEXTURE_CHANNEL_G)
        self.assertEqual(exported.metallic_texture.uri, "baked_mat_orm.png")
        self.assertEqual(exported.metallic_texture_channel, u.TEXTURE_CHANNEL_B)
        self.assertEqual(exported.roughness_factor, 1.0)
        self.assertEqual(exported.metallic_factor, 1.0)
        self.assertIs(exported.normal_texture, baked.normal)
        self.assertEqual(exported.normal_scale, 1.0)

    def test_bake_plan_marks_only_divergent_channels(self) -> None:
        # Mix on base color, math node on roughness, clean normal/emissive.
        mix = FakeNode("ShaderNodeMix")
        mix.name = "Mix"
        base_color = FakeSocket("Base Color")
        base_color.link_from(mix, "Result")
        math_node = FakeNode("ShaderNodeMath")
        math_node.name = "Math"
        roughness = FakeSocket("Roughness")
        roughness.link_from(math_node, "Value")
        principled = FakeNode(
            "ShaderNodeBsdfPrincipled",
            inputs={"Base Color": base_color, "Roughness": roughness},
        )
        surface = FakeSocket("Surface")
        surface.link_from(principled, "BSDF")
        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": surface})
        material = _make_material("chan_mat", [output, principled, mix, math_node])

        plan = u.material_bake_plan(material)
        self.assertEqual(
            plan,
            {"base_color": True, "orm": True, "normal": False, "emissive": False},
        )

    def test_bake_plan_skips_view_dependent_channel_but_keeps_others(self) -> None:
        mix = FakeNode("ShaderNodeMix")
        mix.name = "Mix"
        base_color = FakeSocket("Base Color")
        base_color.link_from(mix, "Result")
        fresnel = FakeNode("ShaderNodeFresnel")
        fresnel.name = "Fresnel"
        roughness = FakeSocket("Roughness")
        roughness.link_from(fresnel, "Fac")
        principled = FakeNode(
            "ShaderNodeBsdfPrincipled",
            inputs={"Base Color": base_color, "Roughness": roughness},
        )
        surface = FakeSocket("Surface")
        surface.link_from(principled, "BSDF")
        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": surface})
        material = _make_material("partial_mat", [output, principled, mix, fresnel])

        plan = u.material_bake_plan(material)
        self.assertTrue(plan["base_color"])
        self.assertFalse(plan["orm"])

    def test_bake_plan_mix_shader_above_principled_is_unbakeable(self) -> None:
        """The channel bake recipes only read individual Principled BSDF inputs, so they
        cannot reproduce a Mix Shader combining the Principled with another shader —
        baking per channel from the Principled alone would silently discard the
        blending and produce a confidently wrong texture. The whole material must be
        skipped, not partially baked."""
        principled = FakeNode("ShaderNodeBsdfPrincipled", inputs={})
        diffuse = FakeNode("ShaderNodeBsdfDiffuse")
        diffuse.name = "Diffuse BSDF"
        shader_a = FakeSocket("Shader")
        shader_a.link_from(principled, "BSDF")
        shader_b = FakeSocket("Shader")
        shader_b.link_from(diffuse, "BSDF")
        mix_shader = FakeNode("ShaderNodeMixShader", inputs={"Shader": shader_a, "Shader.001": shader_b})
        mix_shader.name = "Mix Shader"
        surface = FakeSocket("Surface")
        surface.link_from(mix_shader, "Shader")
        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": surface})
        material = _make_material("global_mat", [output, mix_shader, principled, diffuse])

        self.assertEqual(u.material_bake_plan(material), {})

    def test_bake_plan_empty_for_supported_material(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        material = _make_material("ok_mat", [output, principled, tex])
        self.assertEqual(u.material_bake_plan(material), {})

    def test_png_needs_conversion_flags_indexed_grayscale_and_16bit(self) -> None:
        def make_png_header(bit_depth: int, color_type: int) -> bytes:
            # Magic + chunk length (unused) + "IHDR" + width + height + bit_depth + color_type.
            # _png_ihdr only reads the first 26 bytes, so the rest of a real PNG isn't needed.
            return (
                b"\x89PNG\r\n\x1a\n"
                + b"\x00\x00\x00\x0d"
                + b"IHDR"
                + b"\x00\x00\x04\x00\x00\x00\x04\x00"  # 1024x1024
                + bytes([bit_depth, color_type])
            )

        with tempfile.TemporaryDirectory() as tmpdir:
            cases = [
                ("rgb_8bit.png", 8, 2, False),       # standard RGB — no conversion
                ("rgba_8bit.png", 8, 6, False),      # standard RGBA — no conversion
                ("gray_8bit.png", 8, 0, True),       # grayscale — Metal maps to R-only
                ("gray_alpha.png", 8, 4, True),      # grayscale+alpha — same issue
                ("indexed_1bit.png", 1, 3, True),    # palette — not direct color samples
                ("indexed_8bit.png", 8, 3, True),    # palette — not direct color samples
                ("rgb_16bit.png", 16, 2, True),      # 16-bit — Metal has no sRGB 16-bit format
            ]
            for filename, bit_depth, color_type, expected in cases:
                path = Path(tmpdir) / filename
                path.write_bytes(make_png_header(bit_depth, color_type))
                self.assertEqual(
                    u._png_needs_conversion(path), expected,
                    f"{filename} (bit_depth={bit_depth}, color_type={color_type})",
                )

    def test_material_node_tree_fingerprint_deterministic_and_sensitive(self) -> None:
        mix = FakeNode("ShaderNodeMix")
        mix.name = "Mix"
        principled, output = _make_principled_output(mix, "Result")
        material = _make_material("fp_mat", [output, principled, mix])

        fp1 = u._material_node_tree_fingerprint(material)
        fp2 = u._material_node_tree_fingerprint(material)
        self.assertEqual(fp1, fp2, "same material state must hash identically")

        # An unlinked socket's default_value change must change the hash.
        roughness = FakeSocket("Roughness")
        roughness.default_value = 0.5
        principled.inputs["Roughness"] = roughness
        fp3 = u._material_node_tree_fingerprint(material)
        self.assertNotEqual(fp1, fp3)

        roughness.default_value = 0.9
        fp4 = u._material_node_tree_fingerprint(material)
        self.assertNotEqual(fp3, fp4)

    def test_material_node_tree_fingerprint_sensitive_to_output_socket_value(self) -> None:
        """Regression test: constant-value nodes (ShaderNodeRGB, ShaderNodeValue)
        store their configured value on the OUTPUT socket, not an input. A fix
        that only hashed inputs silently missed edits to these nodes, serving a
        stale cached bake after an artist changed a Color/Value node's value."""
        rgb = FakeNode("ShaderNodeRGB")
        rgb.name = "Color"
        color_socket = FakeSocket("Color")
        color_socket.default_value = (0.6, 0.2, 0.2, 1.0)
        rgb.outputs = {"Color": color_socket}
        principled, output = _make_principled_output(rgb)
        material = _make_material("rgb_mat", [output, principled, rgb])

        fp1 = u._material_node_tree_fingerprint(material)
        color_socket.default_value = (0.3, 0.2, 0.2, 1.0)
        fp2 = u._material_node_tree_fingerprint(material)
        self.assertNotEqual(fp1, fp2, "editing an RGB node's output color must change the fingerprint")

    def test_material_node_tree_fingerprint_handles_missing_links_gracefully(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        material = _make_material("no_links_mat", [output, principled, tex])
        # _make_material's fake node_tree has no .links attribute at all.
        self.assertFalse(hasattr(material.node_tree, "links"))
        fp = u._material_node_tree_fingerprint(material)
        self.assertTrue(fp)

    class _FakeMaterialWithProps:
        def __init__(self, name: str, props: dict | None = None) -> None:
            self.name = name
            self._props = props or {}

        def get(self, key, default=None):
            return self._props.get(key, default)

    def test_resolution_for_material_uses_override_when_set(self) -> None:
        mat = self._FakeMaterialWithProps("mat", {"untold_bake_resolution": 2048})
        self.assertEqual(u._resolution_for_material(mat, 1024), 2048)

    def test_resolution_for_material_falls_back_to_default_when_unset(self) -> None:
        mat = self._FakeMaterialWithProps("mat")
        self.assertEqual(u._resolution_for_material(mat, 1024), 1024)

    def test_resolution_for_material_falls_back_on_invalid_override(self) -> None:
        mat = self._FakeMaterialWithProps("mat", {"untold_bake_resolution": -5})
        self.assertEqual(u._resolution_for_material(mat, 1024), 1024)

        mat2 = self._FakeMaterialWithProps("mat2", {"untold_bake_resolution": "not-a-number"})
        self.assertEqual(u._resolution_for_material(mat2, 1024), 1024)

    def test_resolution_for_material_clamps_override_above_max(self) -> None:
        mat = self._FakeMaterialWithProps("mat", {"untold_bake_resolution": 999999})
        self.assertEqual(u._resolution_for_material(mat, 1024), u.MAX_BAKE_RESOLUTION)

    def test_material_bake_cache_put_then_get_round_trips(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_dir = Path(tmpdir) / "cache"
            source_file = Path(tmpdir) / "source.png"
            source_file.write_bytes(b"fake-png-bytes")

            cache = u.MaterialBakeCache(cache_dir)
            self.assertIsNone(cache.get("some-key"))
            cached_path = cache.put("some-key", source_file)
            self.assertTrue(cached_path.is_file())
            self.assertEqual(cached_path.read_bytes(), b"fake-png-bytes")
            self.assertEqual(cache.hits, 0)
            self.assertEqual(cache.misses, 1)

            cache.save_manifest()
            self.assertTrue(cache.manifest_path.is_file())

            # A fresh cache instance loading the saved manifest should find the entry.
            reloaded = u.MaterialBakeCache(cache_dir)
            found = reloaded.get("some-key")
            self.assertEqual(found, cached_path)
            self.assertEqual(reloaded.hits, 1)

    def test_material_bake_cache_miss_when_cached_file_deleted(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_dir = Path(tmpdir) / "cache"
            source_file = Path(tmpdir) / "source.png"
            source_file.write_bytes(b"fake-png-bytes")

            cache = u.MaterialBakeCache(cache_dir)
            cache.put("some-key", source_file)
            cache.save_manifest()

            reloaded = u.MaterialBakeCache(cache_dir)
            (cache_dir / reloaded._manifest["some-key"]).unlink()
            self.assertIsNone(reloaded.get("some-key"))

    def test_material_bake_cache_key_differs_by_channel_and_resolution(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        material = _make_material("key_mat", [output, principled, tex])
        mesh_object = FakeSceneObject("Obj", "MESH", FakeData(uv_layers=[], materials=[material]))
        mesh_object.matrix_world = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

        key_a = u._material_bake_cache_key(mesh_object, material, "base_color", 1024)
        key_b = u._material_bake_cache_key(mesh_object, material, "normal", 1024)
        key_c = u._material_bake_cache_key(mesh_object, material, "base_color", 2048)
        self.assertNotEqual(key_a, key_b)
        self.assertNotEqual(key_a, key_c)
        self.assertEqual(key_a, u._material_bake_cache_key(mesh_object, material, "base_color", 1024))

    def test_validate_bake_resolution_rejects_non_positive(self) -> None:
        for bad_value in (0, -1, -1024):
            with self.assertRaises(RuntimeError):
                u.validate_bake_resolution(bad_value)

    def test_validate_bake_resolution_passes_through_normal_values(self) -> None:
        self.assertEqual(u.validate_bake_resolution(1024), 1024)
        self.assertEqual(u.validate_bake_resolution(1), 1)
        self.assertEqual(u.validate_bake_resolution(u.MAX_BAKE_RESOLUTION), u.MAX_BAKE_RESOLUTION)

    def test_validate_bake_resolution_clamps_high_values(self) -> None:
        self.assertEqual(u.validate_bake_resolution(u.MAX_BAKE_RESOLUTION + 1), u.MAX_BAKE_RESOLUTION)
        self.assertEqual(u.validate_bake_resolution(1_000_000), u.MAX_BAKE_RESOLUTION)

    def test_cleanup_material_bake_temp_dir_removes_directory_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as parent:
            bake_dir = Path(parent) / "untold_material_bake_test"
            bake_dir.mkdir()
            (bake_dir / "wall_basecolor.png").write_bytes(b"fake")

            u._set_material_bake_temp_dir(bake_dir)
            self.assertTrue(bake_dir.is_dir())

            u.cleanup_material_bake_temp_dir()
            self.assertFalse(bake_dir.exists())

            # Safe to call again with nothing pending, and safe when nothing was ever set.
            u.cleanup_material_bake_temp_dir()

    def test_write_blender_image_forces_lazy_pixel_load_before_giving_up(self) -> None:
        """Blender reports has_data=False for packed/external images until something
        forces a real decode, even when the data is completely valid. Regression
        for a bug where valid packed textures (e.g. from a downloaded .blend with
        broken external filepaths) were being skipped as 'missing' because the
        exporter checked has_data before ever touching .pixels."""

        class LazyPixels:
            def __init__(self, image: "FakeImage") -> None:
                self._image = image

            def __getitem__(self, index):
                self._image.has_data = True  # accessing pixels forces the real decode
                return 0.0

        class FakeImage:
            def __init__(self, *, decodes_successfully: bool) -> None:
                self.has_data = False
                self.size = (64, 64)
                self._decodes_successfully = decodes_successfully
                self.filepath_raw = ""
                self.file_format = "PNG"

            @property
            def pixels(self):
                if not self._decodes_successfully:
                    raise RuntimeError("simulated decode failure")
                return LazyPixels(self)

            def save(self):
                pass

        original_bpy = u.bpy
        try:
            valid_image = FakeImage(decodes_successfully=True)
            u.bpy = FakeData(data=FakeData(images=FakeData(get=lambda name: valid_image)))
            with tempfile.TemporaryDirectory() as tmpdir:
                u.write_blender_image_to_path("valid", Path(tmpdir) / "out.png")
            self.assertTrue(valid_image.has_data)

            broken_image = FakeImage(decodes_successfully=False)
            u.bpy = FakeData(data=FakeData(images=FakeData(get=lambda name: broken_image)))
            with tempfile.TemporaryDirectory() as tmpdir:
                with self.assertRaises(u.UnsupportedTextureFormatError):
                    u.write_blender_image_to_path("broken", Path(tmpdir) / "out.png")
        finally:
            u.bpy = original_bpy

    def test_report_lines_all_supported_is_single_summary(self) -> None:
        tex = _make_image_node()
        principled, output = _make_principled_output(tex)
        material = _make_material("ok_mat", [output, principled, tex])
        mesh = FakeSceneObject("Floor", "MESH", FakeData(materials=[material], uv_layers=[]))
        lines = u.material_fidelity_report_lines([mesh])
        self.assertEqual(lines, ["Material fidelity report: 1 supported, 0 bakeable, 0 unbakeable"])


if __name__ == "__main__":
    unittest.main()
