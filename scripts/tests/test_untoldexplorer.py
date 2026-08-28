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

    def test_unique_hdr_destination_name_deduplicates_collisions(self) -> None:
        context = u.HDRStagingContext()

        first = u.unique_hdr_destination_name("forest.exr", context)
        second = u.unique_hdr_destination_name("forest.exr", context)
        third = u.unique_hdr_destination_name("forest.exr", context)

        self.assertEqual(first, "forest.exr")
        self.assertTrue(second.startswith("forest_"))
        self.assertTrue(second.endswith(".exr"))
        self.assertNotEqual(second, first)
        self.assertNotEqual(third, second)

    def test_hdr_staging_key_prefers_resolved_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "forest.exr"
            key = u.hdr_staging_key(path, "IgnoredImage", "fallback")

        self.assertTrue(key.startswith("path:"))
        self.assertIn("forest.exr", key)

    def test_clean_generated_sidecar_dirs_removes_stale_export_assets(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            output_path = Path(tmpdir) / "asset" / "asset.untold"
            textures_dir = output_path.parent / "Textures"
            hdr_dir = output_path.parent / "HDR"
            textures_dir.mkdir(parents=True)
            hdr_dir.mkdir()
            (textures_dir / "old.png").write_bytes(b"stale texture")
            (hdr_dir / "old.exr").write_bytes(b"stale hdr")
            output_path.write_bytes(b"previous export")

            u.clean_generated_sidecar_dirs(output_path)

            self.assertFalse(textures_dir.exists())
            self.assertFalse(hdr_dir.exists())
            self.assertTrue(output_path.exists())

    def test_cleanup_temporary_export_objects_removes_tagged_split_meshes(self) -> None:
        class FakeBpyCollection:
            def __init__(self) -> None:
                self.removed = []

            def remove(self, item, do_unlink=False) -> None:
                self.removed.append((item, do_unlink))

        class FakeBpy:
            def __init__(self) -> None:
                self.data = FakeData(objects=FakeBpyCollection(), meshes=FakeBpyCollection())

        class FakeTempObject(dict):
            def __init__(self, name: str, data=None, tagged: bool = False) -> None:
                super().__init__()
                self.name = name
                self.data = data
                if tagged:
                    self[u.UNTOLD_EXPORT_TEMP_OBJECT_PROP] = True

        previous_bpy = u.bpy
        fake_bpy = FakeBpy()
        mesh = FakeData(users=0)
        temp_obj = FakeTempObject("Wall_mat0", mesh, tagged=True)
        real_obj = FakeTempObject("Wall", FakeData(users=0), tagged=False)
        try:
            u.bpy = fake_bpy
            u.cleanup_temporary_export_objects([real_obj, temp_obj])
        finally:
            u.bpy = previous_bpy

        self.assertEqual(fake_bpy.data.objects.removed, [(temp_obj, True)])
        self.assertEqual(fake_bpy.data.meshes.removed, [(mesh, False)])

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

    def test_set_scene_color_management_raw_forces_raw_despite_broken_enum_introspection(self) -> None:
        # Regression test: bl_rna.properties[...].enum_items.keys() returns a
        # placeholder ('NONE') instead of the config's real dynamic enum
        # values in this environment, which used to make every "is this a
        # valid option" guard silently false -- so _set_scene_color_management_raw
        # never actually assigned Raw/Standard/None at all, leaving whatever
        # View Transform the scene already had (e.g. AgX) untouched. The fix
        # attempts the assignment directly instead of pre-checking via that
        # introspection.
        class _FakeViewSettings:
            def __init__(self, valid_view_transforms, valid_looks, view_transform, look):
                self._valid_view_transforms = valid_view_transforms
                self._valid_looks = valid_looks
                self.view_transform = view_transform
                self.look = look
                self.exposure = 0.5
                self.gamma = 1.2

            def __setattr__(self, name, value):
                if name == "view_transform" and hasattr(self, "_valid_view_transforms") and value not in self._valid_view_transforms:
                    raise TypeError(f"enum {value!r} not in {self._valid_view_transforms}")
                if name == "look" and hasattr(self, "_valid_looks") and value not in self._valid_looks:
                    raise TypeError(f"enum {value!r} not in {self._valid_looks}")
                object.__setattr__(self, name, value)

        class _FakeDisplaySettings:
            def __init__(self, valid_devices, display_device):
                self._valid_devices = valid_devices
                self.display_device = display_device

            def __setattr__(self, name, value):
                if name == "display_device" and hasattr(self, "_valid_devices") and value not in self._valid_devices:
                    raise TypeError(f"enum {value!r} not in {self._valid_devices}")
                object.__setattr__(self, name, value)

        class _FakeScene:
            def __init__(self, view_settings, display_settings):
                self.view_settings = view_settings
                self.display_settings = display_settings

        # Scene supports "Raw" -- must end up set to "Raw", not left at "AgX".
        scene_with_raw = _FakeScene(
            _FakeViewSettings(("AgX", "Raw", "Standard"), ("AgX - Base Contrast", "None"), "AgX", "AgX - Base Contrast"),
            _FakeDisplaySettings(("sRGB", "None"), "sRGB"),
        )
        u._set_scene_color_management_raw(scene_with_raw)
        self.assertEqual(scene_with_raw.view_settings.view_transform, "Raw")
        self.assertEqual(scene_with_raw.view_settings.look, "None")
        self.assertEqual(scene_with_raw.view_settings.exposure, 0.0)
        self.assertEqual(scene_with_raw.view_settings.gamma, 1.0)

        # Scene has no "Raw" option -- must fall back to "Standard", not be left unset.
        scene_without_raw = _FakeScene(
            _FakeViewSettings(("AgX", "Standard"), ("AgX - Base Contrast",), "AgX", "AgX - Base Contrast"),
            _FakeDisplaySettings(("sRGB", "Display P3"), "sRGB"),
        )
        u._set_scene_color_management_raw(scene_without_raw)
        self.assertEqual(scene_without_raw.view_settings.view_transform, "Standard")

    def test_lut_shaper_decode_is_monotonic_and_anchors_middle_gray(self) -> None:
        # t=0.5 with the default -10..+6 stop range lands 8 stops below the
        # midpoint's own reference, not exactly at 0.18 -- what matters is that
        # decode is monotonically increasing and passes through known stops.
        anchor_t = (0.0 - u._LUT_SHAPER_MIN_STOPS) / (u._LUT_SHAPER_MAX_STOPS - u._LUT_SHAPER_MIN_STOPS)
        self.assertAlmostEqual(u._lut_shaper_decode(anchor_t), u._LUT_SHAPER_MIDDLE_GRAY, places=5)

        values = [u._lut_shaper_decode(i / 100) for i in range(101)]
        self.assertEqual(values, sorted(values))
        self.assertLess(values[0], u._LUT_SHAPER_MIDDLE_GRAY)
        self.assertGreater(values[-1], u._LUT_SHAPER_MIDDLE_GRAY)

    def test_identity_lut_grid_pixels_row_order_survives_blenders_vertical_flip(self) -> None:
        # Regression test: Blender's `image.pixels` buffer is bottom-up, but
        # `image.save_render()` flips vertically when writing a top-down PNG.
        # build_identity_lut_grid_pixels must pre-compensate so that after that
        # flip, PNG/texture row g still holds green-axis grid index g (the
        # convention the runtime LUT sampler assumes). This test simulates the
        # flip directly on the returned buffer rather than actually saving a
        # PNG through Blender.
        lut_size = 4
        width = lut_size * lut_size
        pixels = u.build_identity_lut_grid_pixels(lut_size)
        self.assertEqual(len(pixels), width * lut_size * 4)

        def buffer_pixel(px: int, py: int) -> tuple[float, float, float, float]:
            idx = (py * width + px) * 4
            return tuple(pixels[idx : idx + 4])

        # Simulate save_render's vertical flip: post-flip row g == buffer row (lut_size - 1 - g).
        def post_flip_pixel(px: int, g: int) -> tuple[float, float, float, float]:
            return buffer_pixel(px, lut_size - 1 - g)

        expected_green = [u._lut_shaper_decode(i / (lut_size - 1)) for i in range(lut_size)]
        for g in range(lut_size):
            # px=0 -> r index 0 within tile b=0; green channel (index 1) must
            # equal expected_green[g] once the flip is undone.
            _, green, _, _ = post_flip_pixel(0, g)
            self.assertAlmostEqual(green, expected_green[g], places=5)

    def test_rgba16f_utex_preserves_precision_orientation_and_format(self) -> None:
        # Two bottom-up Blender rows. The native payload must reverse them so
        # Metal row zero contains the image's top row.
        bottom_row = [0.001, 0.002, 0.003, 1.0, 0.004, 0.005, 0.006, 1.0]
        top_row = [0.501, 0.502, 0.503, 1.0, 0.504, 0.505, 0.506, 1.0]
        data = u.build_rgba16f_utex_bytes(bottom_row + top_row, 2, 2)
        width, height, decoded = u.decode_rgba16f_utex_bytes(data)

        self.assertEqual((width, height), (2, 2))
        header = struct.unpack_from(u._UTEX_HEADER_FMT, data, 0)
        self.assertEqual(header[6], u._UTEX_RGBA16_FLOAT_PIXEL_FORMAT)
        self.assertEqual((header[7], header[8]), (1, 1))
        for actual, expected in zip(decoded[:8], top_row):
            self.assertAlmostEqual(actual, expected, delta=0.0003)
        for actual, expected in zip(decoded[8:], bottom_row):
            self.assertAlmostEqual(actual, expected, delta=0.0003)

    def test_color_lut_filename_is_content_addressed(self) -> None:
        first = u.color_lut_filename(b"first LUT")
        self.assertEqual(first, u.color_lut_filename(b"first LUT"))
        self.assertNotEqual(first, u.color_lut_filename(b"second LUT"))
        self.assertTrue(first.startswith("gradelut_"))
        self.assertTrue(first.endswith(".utex"))

    def test_cpu_lut_sampler_matches_identity_grid_at_grid_points(self) -> None:
        lut_size = 4
        source = u.build_identity_lut_grid_pixels(lut_size)
        data = u.build_rgba16f_utex_bytes(source, lut_size * lut_size, lut_size)
        _, _, pixels = u.decode_rgba16f_utex_bytes(data)
        values = [u._lut_shaper_decode(index / (lut_size - 1)) for index in range(lut_size)]

        for red_index, green_index, blue_index in ((0, 0, 0), (1, 2, 3), (3, 1, 2)):
            color = (values[red_index], values[green_index], values[blue_index])
            sampled = u.sample_color_lut_pixels(pixels, lut_size, color)
            for actual, expected in zip(sampled, color):
                self.assertAlmostEqual(actual, expected, delta=0.006)

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
        self.assertAlmostEqual(lights[1].outer_cone, 20.0)
        self.assertAlmostEqual(lights[1].inner_cone, 15.0)
        self.assertAlmostEqual(lights[1].radius, 6.0)
        self.assertEqual(lights[1].range, 0.0)
        self.assertTrue(lights[1].casts_shadow)

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

    def test_blender_light_shadow_and_custom_distance_are_exported_independently(self) -> None:
        light = FakeData(
            type="POINT",
            shadow_soft_size=0.25,
            use_shadow=False,
            use_custom_distance=True,
            cutoff_distance=14.0,
        )

        self.assertAlmostEqual(u._blender_light_radius(light, u.LIGHT_TYPE_POINT), 0.25)
        self.assertAlmostEqual(u._blender_light_influence_range(light, u.LIGHT_TYPE_POINT), 14.0)
        self.assertFalse(u._blender_light_casts_shadow(light))

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

        # Material record: 108 bytes (per assetFormat.md schema — grew from 88 to 108
        # bytes at FORMAT_VERSION 3/4 with the height-map and height-remap fields).
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
            height_texture_index=u.INVALID_INDEX,
            height_scale=0.05, height_midlevel=0.5,
            height_remap_min=0.0, height_remap_max=1.0,
            roughness_texture_channel=u.TEXTURE_CHANNEL_G,
            metallic_texture_channel=u.TEXTURE_CHANNEL_B,
        )
        u.write_material_record(wm, mat)
        self.assertEqual(wm.count, 108)
        self.assertEqual(struct.unpack_from("<I", wm.data, 100)[0], 0b1001)

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

    def test_extract_material_reads_height_from_displacement_node(self) -> None:
        """The standard ArchViz/Poliigon authoring pattern: an Image Texture feeds a
        Displacement node's Height socket, which feeds Material Output's Displacement
        input. Scale/Midlevel on the Displacement node become heightScale/heightMidlevel."""
        height_tex = _make_image_node("height_map")
        height_input = FakeSocket("Height")
        height_input.link_from(height_tex, "Color")
        scale_socket = FakeSocket("Scale")
        scale_socket.default_value = 0.02
        midlevel_socket = FakeSocket("Midlevel")
        midlevel_socket.default_value = 0.5
        displacement_node = FakeNode(
            "ShaderNodeDisplacement",
            inputs={"Height": height_input, "Scale": scale_socket, "Midlevel": midlevel_socket},
        )
        displacement_node.name = "Displacement"

        principled, output = _make_principled_output(None)
        principled.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        displacement_socket = FakeSocket("Displacement")
        displacement_socket.link_from(displacement_node, "Displacement")
        output.inputs["Displacement"] = displacement_socket

        material = _make_material("disp_mat", [output, principled, displacement_node, height_tex])
        mesh_object = FakeSceneObject("Wall", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")

        self.assertIsNotNone(exported.height_texture)
        self.assertEqual(exported.height_texture.name, "height_map.png")
        self.assertAlmostEqual(exported.height_scale, 0.02)
        self.assertAlmostEqual(exported.height_midlevel, 0.5)

        # The Displacement node's own type is not flagged as bakeable — it's now
        # faithfully handled (extracted as height) — but its Height chain is still
        # walked and would be individually classified if unsupported.
        analysis = u.analyze_material(material)
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_SUPPORTED)

    def test_extract_material_falls_back_to_bump_height_when_no_displacement(self) -> None:
        """Materials authored without a separate Displacement setup sometimes feed a
        Bump node's Height socket into the Principled BSDF's Normal input directly."""
        height_tex = _make_image_node("bump_height")
        height_input = FakeSocket("Height")
        height_input.link_from(height_tex, "Color")
        distance_socket = FakeSocket("Distance")
        distance_socket.default_value = 0.03
        bump_node = FakeNode("ShaderNodeBump", inputs={"Height": height_input, "Distance": distance_socket})
        bump_node.name = "Bump"

        normal_socket = FakeSocket("Normal")
        normal_socket.link_from(bump_node, "Normal")
        base_color_socket = FakeSocket("Base Color")
        base_color_socket.default_value = (1.0, 1.0, 1.0, 1.0)
        principled = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Base Color": base_color_socket, "Normal": normal_socket})
        principled.name = "Principled BSDF"
        surface = FakeSocket("Surface")
        surface.link_from(principled, "BSDF")
        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": surface})
        output.name = "Material Output"

        material = _make_material("bump_mat", [output, principled, bump_node, height_tex])
        mesh_object = FakeSceneObject("Wall", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")

        self.assertIsNotNone(exported.height_texture)
        self.assertEqual(exported.height_texture.name, "bump_height.png")
        self.assertAlmostEqual(exported.height_scale, 0.03)
        # Bump has no Midlevel-equivalent input; height_midlevel stays at the neutral default.
        self.assertAlmostEqual(exported.height_midlevel, 0.5)

    def test_extract_material_without_displacement_or_bump_has_no_height(self) -> None:
        tex = _make_image_node("original")
        principled, output = _make_principled_output(tex)
        material = _make_material("plain_mat", [output, principled, tex])
        mesh_object = FakeSceneObject("Wall", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")

        self.assertIsNone(exported.height_texture)
        self.assertEqual(exported.height_scale, 0.05)
        self.assertEqual(exported.height_midlevel, 0.5)

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

    def test_next_power_of_two(self) -> None:
        self.assertEqual(u._next_power_of_two(0), 1)
        self.assertEqual(u._next_power_of_two(1), 1)
        self.assertEqual(u._next_power_of_two(2), 2)
        self.assertEqual(u._next_power_of_two(3), 4)
        self.assertEqual(u._next_power_of_two(4096), 4096)
        self.assertEqual(u._next_power_of_two(4097), 8192)

    def test_max_upstream_image_dimension_direct_texture(self) -> None:
        image = FakeData(filepath="t.png", library=None, size=(2048, 1024), name="t")
        tex = FakeNode("ShaderNodeTexImage", image=image)
        tex.name = "tex"
        principled, _ = _make_principled_output(tex)
        self.assertEqual(u._max_upstream_image_dimension(principled.inputs["Base Color"]), 2048)

    def test_max_upstream_image_dimension_through_mix_node(self) -> None:
        """Mirrors a real AO-multiplied-into-diffuse setup: Base Color is fed by a
        Mix blending a high-res photo texture with a lower-res AO map. The largest
        of the two source textures should win, regardless of the node sitting
        between them and the Principled BSDF."""
        base_color_image = FakeData(filepath="base.tga", library=None, size=(4096, 4096), name="base")
        base_color_tex = FakeNode("ShaderNodeTexImage", image=base_color_image)
        base_color_tex.name = "Base Color Tex"
        ao_image = FakeData(filepath="ao.png", library=None, size=(2048, 2048), name="ao")
        ao_tex = FakeNode("ShaderNodeTexImage", image=ao_image)
        ao_tex.name = "AO Tex"

        mix_input_a = FakeSocket("A")
        mix_input_a.link_from(base_color_tex, "Color")
        mix_input_b = FakeSocket("B")
        mix_input_b.link_from(ao_tex, "Color")
        mix = FakeNode("ShaderNodeMix", inputs={"A": mix_input_a, "B": mix_input_b})
        mix.name = "Mix"

        principled, _ = _make_principled_output(mix, "Result")
        self.assertEqual(u._max_upstream_image_dimension(principled.inputs["Base Color"]), 4096)

    def test_max_upstream_image_dimension_no_texture_upstream(self) -> None:
        mix = FakeNode("ShaderNodeMix")
        mix.name = "Mix"
        principled, _ = _make_principled_output(mix, "Result")
        self.assertEqual(u._max_upstream_image_dimension(principled.inputs["Base Color"]), 0)

    def test_max_upstream_image_dimension_unlinked_socket(self) -> None:
        principled, _ = _make_principled_output(None)
        self.assertEqual(u._max_upstream_image_dimension(principled.inputs["Base Color"]), 0)

    def test_resolution_for_material_auto_detects_from_source_texture(self) -> None:
        image = FakeData(filepath="t.tga", library=None, size=(4096, 4096), name="t")
        tex = FakeNode("ShaderNodeTexImage", image=image)
        tex.name = "tex"
        mix_input = FakeSocket("A")
        mix_input.link_from(tex, "Color")
        mix = FakeNode("ShaderNodeMix", inputs={"A": mix_input})
        mix.name = "Mix"
        principled, output = _make_principled_output(mix, "Result")
        material = _make_material("bed_mat", [output, principled, mix, tex])
        plan = {"base_color": True, "orm": False, "normal": False, "emissive": False}

        self.assertEqual(u._resolution_for_material(material, 1024, plan), 4096)

    def test_resolution_for_material_auto_detected_rounds_up_to_power_of_two(self) -> None:
        image = FakeData(filepath="t.tga", library=None, size=(3000, 3000), name="t")
        tex = FakeNode("ShaderNodeTexImage", image=image)
        tex.name = "tex"
        principled, output = _make_principled_output(tex)
        material = _make_material("odd_res_mat", [output, principled, tex])
        plan = {"base_color": True, "orm": False, "normal": False, "emissive": False}

        self.assertEqual(u._resolution_for_material(material, 1024, plan), 4096)

    def test_resolution_for_material_auto_detected_never_below_default(self) -> None:
        image = FakeData(filepath="t.png", library=None, size=(512, 512), name="t")
        tex = FakeNode("ShaderNodeTexImage", image=image)
        tex.name = "tex"
        principled, output = _make_principled_output(tex)
        material = _make_material("small_tex_mat", [output, principled, tex])
        plan = {"base_color": True, "orm": False, "normal": False, "emissive": False}

        self.assertEqual(u._resolution_for_material(material, 1024, plan), 1024)

    def test_resolution_for_material_falls_back_to_default_without_plan(self) -> None:
        image = FakeData(filepath="t.tga", library=None, size=(4096, 4096), name="t")
        tex = FakeNode("ShaderNodeTexImage", image=image)
        tex.name = "tex"
        principled, output = _make_principled_output(tex)
        material = _make_material("no_plan_mat", [output, principled, tex])

        self.assertEqual(u._resolution_for_material(material, 1024, None), 1024)
        self.assertEqual(u._resolution_for_material(material, 1024, {}), 1024)

    def test_resolution_for_material_override_takes_precedence_over_auto_detected(self) -> None:
        image = FakeData(filepath="t.tga", library=None, size=(4096, 4096), name="t")
        tex = FakeNode("ShaderNodeTexImage", image=image)
        tex.name = "tex"
        principled, output = _make_principled_output(tex)
        mat = self._FakeMaterialWithProps("mat", {"untold_bake_resolution": 2048})
        mat.node_tree = FakeData(nodes=[output, principled, tex])
        plan = {"base_color": True, "orm": False, "normal": False, "emissive": False}

        self.assertEqual(u._resolution_for_material(mat, 1024, plan), 2048)

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


def _build_minimal_png(bit_depth: int, color_type: int) -> bytes:
    """A syntactically valid PNG containing only a magic + IHDR chunk. _png_ihdr only
    reads the first 26 bytes, so the rest of a real PNG (IDAT/IEND, valid CRCs) is
    unnecessary."""
    return (
        b"\x89PNG\r\n\x1a\n"
        + b"\x00\x00\x00\x0d"  # chunk length (unused by the reader)
        + b"IHDR"
        + b"\x00\x00\x00\x01\x00\x00\x00\x01"  # width=1, height=1 (unused)
        + bytes([bit_depth, color_type])
        + b"\x00\x00\x00\x00\x00"  # compression, filter, interlace + padding (unused)
    )


def _build_minimal_tiff(bits_per_sample: list[int], *, big_endian: bool = False) -> bytes:
    """A minimal little/big-endian TIFF with BitsPerSample(258) and SamplesPerPixel(277)
    tags, matching exactly what _tiff_bits_per_sample_and_channels reads. No image data —
    the reader only walks the first IFD's tag table."""
    endian = ">" if big_endian else "<"
    samples_per_pixel = len(bits_per_sample)
    entries: list[tuple[int, bytes]] = []
    extra_data = b""

    if samples_per_pixel == 1:
        entries.append((258, struct.pack(endian + "HHI", 258, 3, 1) + struct.pack(endian + "HH", bits_per_sample[0], 0)))
    else:
        ifd_entry_count = 2
        bits_offset = 8 + 2 + ifd_entry_count * 12 + 4
        entries.append((258, struct.pack(endian + "HHI", 258, 3, samples_per_pixel) + struct.pack(endian + "I", bits_offset)))
        extra_data = b"".join(struct.pack(endian + "H", v) for v in bits_per_sample)

    entries.append((277, struct.pack(endian + "HHI", 277, 3, 1) + struct.pack(endian + "HH", samples_per_pixel, 0)))
    entries.sort(key=lambda e: e[0])

    header = (b"MM" if big_endian else b"II") + struct.pack(endian + "HI", 42, 8)
    ifd_body = struct.pack(endian + "H", len(entries)) + b"".join(e[1] for e in entries) + struct.pack(endian + "I", 0)
    return header + ifd_body + extra_data


class TextureBitDepthDetectionTests(unittest.TestCase):
    """Regression coverage for the needs_conversion detection bug: Blender's own
    image.depth/image.channels report 32/4 ("already 8-bit RGBA") for genuinely
    16-bit-per-channel PNG/TIFF sources, silently defeating the safety net that
    downconverts 16-bit/grayscale textures to avoid the Metal sRGB-16-bit and
    grayscale-loads-as-red bugs. _source_bit_depth_and_channels reads the true values
    from the source file's own header instead of trusting Blender's post-load metadata."""

    def test_tiff_single_channel_16bit_inline(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "height.tiff"
            path.write_bytes(_build_minimal_tiff([16]))
            self.assertEqual(u._tiff_bits_per_sample_and_channels(path), (16, 1))

    def test_tiff_multi_channel_8bit_via_offset(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "color.tiff"
            path.write_bytes(_build_minimal_tiff([8, 8, 8]))
            self.assertEqual(u._tiff_bits_per_sample_and_channels(path), (8, 3))

    def test_tiff_big_endian(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "height_be.tiff"
            path.write_bytes(_build_minimal_tiff([16], big_endian=True))
            self.assertEqual(u._tiff_bits_per_sample_and_channels(path), (16, 1))

    def test_tiff_invalid_file_returns_none(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "not_a_tiff.tiff"
            path.write_bytes(b"not a tiff file")
            self.assertIsNone(u._tiff_bits_per_sample_and_channels(path))

    def test_png_ihdr_16bit_grayscale(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "height.png"
            path.write_bytes(_build_minimal_png(bit_depth=16, color_type=0))
            self.assertEqual(u._png_ihdr(path), (16, 0))
            self.assertEqual(u._png_bit_depth(path), 16)

    def test_png_ihdr_8bit_rgb(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "color.png"
            path.write_bytes(_build_minimal_png(bit_depth=8, color_type=2))
            self.assertEqual(u._png_ihdr(path), (8, 2))

    def test_png_ihdr_invalid_file_returns_none(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "not_a_png.png"
            path.write_bytes(b"not a png file")
            self.assertIsNone(u._png_ihdr(path))

    def test_source_bit_depth_dispatches_to_tiff_reader(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "height.tiff"
            path.write_bytes(_build_minimal_tiff([16]))
            image = FakeData(filepath_raw=str(path), filepath=str(path), library=None)
            original_bpy = u.bpy
            try:
                u.bpy = None  # exercise the no-bpy fallback path (Path(filepath) directly)
                self.assertEqual(u._source_bit_depth_and_channels(image), (16, 1))
            finally:
                u.bpy = original_bpy

    def test_source_bit_depth_dispatches_to_png_reader_with_channel_mapping(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "height.png"
            path.write_bytes(_build_minimal_png(bit_depth=16, color_type=0))  # grayscale
            image = FakeData(filepath_raw=str(path), filepath=str(path), library=None)
            original_bpy = u.bpy
            try:
                u.bpy = None
                self.assertEqual(u._source_bit_depth_and_channels(image), (16, 1))
            finally:
                u.bpy = original_bpy

    def test_source_bit_depth_uses_bpy_path_abspath_when_available(self) -> None:
        """Inside real Blender, filepath_raw can be a blend-relative '//' path that only
        bpy.path.abspath knows how to resolve — this must be preferred over treating the
        raw string as a plain OS path when bpy is available."""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "height.tiff"
            path.write_bytes(_build_minimal_tiff([16]))
            image = FakeData(filepath_raw="//not/a/real/relative/path.tiff", filepath="", library=None)
            original_bpy = u.bpy
            try:
                u.bpy = FakeData(path=FakeData(abspath=lambda p, library=None: str(path)))
                self.assertEqual(u._source_bit_depth_and_channels(image), (16, 1))
            finally:
                u.bpy = original_bpy

    def test_source_bit_depth_returns_none_for_unsupported_suffix(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "photo.jpg"
            path.write_bytes(b"not actually decoded, suffix-only dispatch")
            image = FakeData(filepath_raw=str(path), filepath=str(path), library=None)
            original_bpy = u.bpy
            try:
                u.bpy = None
                self.assertIsNone(u._source_bit_depth_and_channels(image))
            finally:
                u.bpy = original_bpy

    def test_source_bit_depth_returns_none_when_no_filepath(self) -> None:
        image = FakeData(filepath_raw="", filepath="", library=None)
        original_bpy = u.bpy
        try:
            u.bpy = None
            self.assertIsNone(u._source_bit_depth_and_channels(image))
        finally:
            u.bpy = original_bpy

    def test_source_bit_depth_returns_none_when_file_missing(self) -> None:
        image = FakeData(filepath_raw="/nonexistent/path/height.tiff", filepath="", library=None)
        original_bpy = u.bpy
        try:
            u.bpy = None
            self.assertIsNone(u._source_bit_depth_and_channels(image))
        finally:
            u.bpy = original_bpy

    def test_needs_conversion_now_fires_for_real_world_16bit_grayscale_tiff(self) -> None:
        """The actual regression: a genuinely 16-bit single-channel source (e.g. a
        Poliigon displacement map) must compute depth=16, channels=1 -> needs_conversion
        True, even though Blender's own image.depth/channels report 32/4 for this exact
        case (confirmed against real Blender 5.1 + a real Poliigon TIFF asset)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "displacement.tiff"
            path.write_bytes(_build_minimal_tiff([16]))
            image = FakeData(filepath_raw=str(path), filepath=str(path), library=None,
                              depth=32, channels=4)  # Blender's (misleading) post-load metadata
            original_bpy = u.bpy
            try:
                u.bpy = None
                source_info = u._source_bit_depth_and_channels(image)
                self.assertEqual(source_info, (16, 1))
                bits_per_sample, image_channels = source_info
                image_depth = bits_per_sample * image_channels
                needs_conversion = image_depth > 32 or image_channels < 3
                self.assertTrue(needs_conversion, "16-bit grayscale source must trigger the 8-bit safety downconvert")
            finally:
                u.bpy = original_bpy


if __name__ == "__main__":
    unittest.main()
