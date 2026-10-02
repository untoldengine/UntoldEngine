import contextlib
import io
import json
import math
import struct
import sys
import tempfile
import unittest
import zlib
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

    def test_resolve_texture_from_socket_keeps_packed_images_distinct(self) -> None:
        """Packed/generated images have an empty filepath. They must be keyed by
        their Blender image name, never by a path derived from the empty string:
        that resolves to the asset's parent directory, so every packed texture in a
        material shared one staging key and collapsed onto the base color."""
        base_image = FakeData(filepath="", library=None, size=(2048, 2048), name="T_Zombie_BC")
        normal_image = FakeData(filepath="", library=None, size=(2048, 2048), name="T_Zombie_N")
        base_input = FakeSocket("Base Color")
        base_input.link_from(FakeNode("ShaderNodeTexImage", image=base_image), "Color")
        normal_color_input = FakeSocket("Color")
        normal_color_input.link_from(FakeNode("ShaderNodeTexImage", image=normal_image), "Color")
        normal_input = FakeSocket("Normal")
        normal_input.link_from(FakeNode("ShaderNodeNormalMap", inputs={"Color": normal_color_input}), "Normal")

        with tempfile.TemporaryDirectory() as tmpdir:
            asset_path = Path(tmpdir) / "asset.untold"
            base = u.resolve_texture_from_socket(base_input, asset_path)
            normal = u.resolve_texture_from_socket(normal_input, asset_path)

        self.assertIsNotNone(base)
        self.assertIsNotNone(normal)
        for texture in (base, normal):
            self.assertIsNone(texture.source_path, "packed images have no file on disk to key by")
        self.assertEqual(base.source_image_name, "T_Zombie_BC")
        self.assertEqual(normal.source_image_name, "T_Zombie_N")
        self.assertNotEqual(base.name, normal.name)
        self.assertNotEqual(base.uri, normal.uri)
        self.assertNotEqual(u.texture_staging_key(base), u.texture_staging_key(normal))

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
            def __init__(self, items=()) -> None:
                self.items = list(items)
                self.removed = []

            def __iter__(self):
                return iter(self.items)

            def remove(self, item, do_unlink=False) -> None:
                self.removed.append((item, do_unlink))

        class FakeBpy:
            def __init__(self, objects=()) -> None:
                self.data = FakeData(objects=FakeBpyCollection(objects), meshes=FakeBpyCollection())

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

    def test_unique_pack_model_dir_name_disambiguates_sanitize_collisions(self) -> None:
        used_names: set[str] = set()

        first = u.unique_pack_model_dir_name("Chair.1", used_names)
        second = u.unique_pack_model_dir_name("Chair 1", used_names)
        third = u.unique_pack_model_dir_name("???", used_names)
        fourth = u.unique_pack_model_dir_name("!!!", used_names)

        # "Chair.1" and "Chair 1" both sanitize down to "Chair_1"; "???" and "!!!"
        # both fall back to "model". Without disambiguation the second write of
        # each pair would land in the first's folder and overwrite its .untold.
        self.assertEqual(first, "Chair_1")
        self.assertNotEqual(second, first)
        self.assertEqual(third, "model")
        self.assertNotEqual(fourth, third)
        self.assertEqual(len({first, second, third, fourth}), 4)

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

    def test_extract_material_exports_unit_factor_for_textured_metallic_roughness(self) -> None:
        """Blender ignores a socket's slider once a texture is linked to it, and the
        engine multiplies the texture sample by the exported factor. A textured
        Metallic or Roughness socket must therefore export 1.0: exporting the slider
        halved roughness (default 0.5) and zeroed metallic (default 0.0) on every
        textured material. Unlinked sockets still export the slider value."""
        orm = _make_image_node("orm")
        separate_input = FakeSocket("Color")
        separate_input.link_from(orm, "Color")
        separate = FakeNode("ShaderNodeSeparateColor", inputs={"Color": separate_input})
        separate.name = "Separate Color"

        principled, output = _make_principled_output(_make_image_node("albedo"))
        metallic = FakeSocket("Metallic")
        metallic.default_value = 0.0
        metallic.link_from(separate, "Blue")
        roughness = FakeSocket("Roughness")
        roughness.default_value = 0.5
        roughness.link_from(separate, "Green")
        principled.inputs["Metallic"] = metallic
        principled.inputs["Roughness"] = roughness
        material = _make_material("orm_mat", [output, principled, separate, orm])
        mesh_object = FakeSceneObject("Zombie", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")

        self.assertIsNotNone(exported.metallic_texture)
        self.assertIsNotNone(exported.roughness_texture)
        self.assertEqual(exported.metallic_texture.channel, u.TEXTURE_CHANNEL_B)
        self.assertEqual(exported.roughness_texture.channel, u.TEXTURE_CHANNEL_G)
        self.assertEqual(exported.metallic_factor, 1.0, "textured metallic must not be scaled by the ignored slider")
        self.assertEqual(exported.roughness_factor, 1.0, "textured roughness must not be scaled by the ignored slider")

        principled_plain, output_plain = _make_principled_output(None)
        principled_plain.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        metallic_plain = FakeSocket("Metallic")
        metallic_plain.default_value = 0.25
        roughness_plain = FakeSocket("Roughness")
        roughness_plain.default_value = 0.8
        principled_plain.inputs["Metallic"] = metallic_plain
        principled_plain.inputs["Roughness"] = roughness_plain
        plain_material = _make_material("plain_mat", [output_plain, principled_plain])
        plain_object = FakeSceneObject("Cube", "MESH", FakeData(materials=[plain_material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported_plain = u.extract_material(plain_object, Path(tmpdir) / "asset.untold")

        self.assertAlmostEqual(exported_plain.metallic_factor, 0.25)
        self.assertAlmostEqual(exported_plain.roughness_factor, 0.8)

    def test_extract_material_reads_height_from_displacement_node(self) -> None:
        """The standard ArchViz/Poliigon authoring pattern: an Image Texture feeds a
        Displacement node's Height socket, which feeds Material Output's Displacement
        input. Scale becomes heightScale directly. Midlevel does NOT get copied into
        heightMidlevel (which stays at its neutral default) — the engine's POM is
        unidirectional and heightMidlevel is just an additive shift, not a true
        zero-reference, so copying Blender's Midlevel there would not reproduce "neutral
        gray = no visible depth". Instead Midlevel becomes the height_remap_max ceiling:
        raw values at/above it clip to "no depth", values below get contrast-stretched
        into the full depth range."""
        height_tex = _make_image_node("height_map")
        height_input = FakeSocket("Height")
        height_input.link_from(height_tex, "Color")
        scale_socket = FakeSocket("Scale")
        scale_socket.default_value = 0.02
        midlevel_socket = FakeSocket("Midlevel")
        midlevel_socket.default_value = 0.7
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
        self.assertAlmostEqual(exported.height_midlevel, 0.5, msg="heightMidlevel stays neutral, Blender's Midlevel is not copied here")
        self.assertAlmostEqual(exported.height_remap_min, 0.0)
        self.assertAlmostEqual(exported.height_remap_max, 0.7, msg="Blender's Midlevel becomes the remap ceiling")

        # The Displacement node's own type is not flagged as bakeable — it's now
        # faithfully handled (extracted as height) — but its Height chain is still
        # walked and would be individually classified if unsupported.
        analysis = u.analyze_material(material)
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_SUPPORTED)

    def _make_displacement_material(self, *, midlevel: float, name: str = "disp_mat") -> FakeData:
        height_tex = _make_image_node("height_map")
        height_input = FakeSocket("Height")
        height_input.link_from(height_tex, "Color")
        scale_socket = FakeSocket("Scale")
        scale_socket.default_value = 0.02
        midlevel_socket = FakeSocket("Midlevel")
        midlevel_socket.default_value = midlevel
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

        return _make_material(name, [output, principled, displacement_node, height_tex])

    def test_extract_material_clamps_out_of_range_midlevel_to_remap_ceiling(self) -> None:
        """Regression: a real Poliigon .blend was found with Midlevel authored as 7.4
        (an artist overshooting a slider, not a valid [0,1] height reference). Raw texture
        samples are always in [0,1], so an unclamped remap ceiling of 7.4 would make
        virtually every real sample divide down toward "maximum depth" — a badly broken
        result, not a validation error, so it must be clamped rather than trusted as-is."""
        material = self._make_displacement_material(midlevel=7.4, name="overshoot_mat")
        mesh_object = FakeSceneObject("Wall", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")

        self.assertAlmostEqual(exported.height_remap_max, 1.0)

    def test_extract_material_clamps_near_zero_midlevel_to_remap_floor(self) -> None:
        material = self._make_displacement_material(midlevel=0.0, name="zero_mat")
        mesh_object = FakeSceneObject("Wall", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.untold")

        self.assertAlmostEqual(exported.height_remap_max, 0.01)

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
        # Bump has no Midlevel-equivalent input; height_midlevel/height_remap_max stay at
        # their neutral defaults.
        self.assertAlmostEqual(exported.height_midlevel, 0.5)
        self.assertAlmostEqual(exported.height_remap_min, 0.0)
        self.assertAlmostEqual(exported.height_remap_max, 1.0)

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
                Path(self.filepath_raw).write_bytes(_build_complete_png())

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

    def test_write_morph_target_record_layout_matches_runtime(self) -> None:
        writer = u.BinaryWriter()
        u.write_morph_target_record(writer, 3, 42, u.MORPH_FLAG_HAS_NORMAL_DELTAS, 7, 100, 1.5)
        self.assertEqual(len(writer.data), 24)
        mesh_index, name_offset, flags, first_entry, entry_count, scale = struct.unpack(
            "<5If", writer.data
        )
        self.assertEqual(
            (mesh_index, name_offset, flags, first_entry, entry_count), (3, 42, 1, 7, 100)
        )
        self.assertAlmostEqual(scale, 1.5)

    def test_write_morph_driver_record_layout_matches_runtime(self) -> None:
        writer = u.BinaryWriter()
        u.write_morph_driver_record(writer, 2, 9, 0, (0.1, 0.2, 0.3, 0.9), 0.75)
        self.assertEqual(len(writer.data), 36)
        target_index, joint_offset, kernel = struct.unpack_from("<3I", writer.data, 0)
        pose = struct.unpack_from("<4f", writer.data, 12)
        radius, reserved = struct.unpack_from("<fI", writer.data, 28)
        self.assertEqual((target_index, joint_offset, kernel), (2, 9, 0))
        self.assertAlmostEqual(pose[3], 0.9, places=5)
        self.assertAlmostEqual(radius, 0.75)
        self.assertEqual(reserved, 0)

    def test_write_muscle_record_layout_matches_runtime(self) -> None:
        record = u.MuscleRecord(
            skeleton_entity_id=3, name_offset=10, flags=u.MUSCLE_FLAG_HAS_DRIVER,
            forward_joint_offset=11, forward_tip_joint_offset=12,
            origin_joint_offset=13, origin_tip_joint_offset=u.INVALID_INDEX, origin_fraction=0.15,
            origin_offset=(0.0, 0.0, 0.02),
            insertion_joint_offset=14, insertion_tip_joint_offset=u.INVALID_INDEX, insertion_fraction=0.2,
            insertion_offset=(0.0, 0.0, 0.01),
            belly_radius=0.04, tendon_radius=0.012, max_contraction=0.25,
            fiber_compliance=2e-6, cross_compliance=4e-6, volume_compliance=0.0,
            damping=6.0, bone_radius=0.03, skin_influence=0.03, rings=7, segments=8,
            driver_joint_offset=14, driver_start_angle=0.2, driver_full_angle=1.9,
        )
        writer = u.BinaryWriter()
        u.write_muscle_record(writer, record)
        self.assertEqual(len(writer.data), u.MUSCLE_RECORD_SIZE)
        skeleton_id, name, flags, fwd, fwd_tip, origin, origin_tip = struct.unpack_from("<7I", writer.data, 0)
        self.assertEqual((skeleton_id, name, flags, fwd, fwd_tip, origin, origin_tip), (3, 10, 1, 11, 12, 13, u.INVALID_INDEX))
        origin_fraction, ox, oy, oz = struct.unpack_from("<4f", writer.data, 28)
        self.assertAlmostEqual(origin_fraction, 0.15, places=6)
        self.assertAlmostEqual(oz, 0.02, places=6)
        insertion, insertion_tip = struct.unpack_from("<2I", writer.data, 44)
        self.assertEqual((insertion, insertion_tip), (14, u.INVALID_INDEX))
        rings, segments, driver = struct.unpack_from("<3I", writer.data, 104)
        self.assertEqual((rings, segments, driver), (7, 8, 14))
        start, full, reserved = struct.unpack_from("<2fI", writer.data, 116)
        self.assertAlmostEqual(full, 1.9, places=5)
        self.assertEqual(reserved, 0)

    def test_validate_muscle_rig_rejects_malformed_input(self) -> None:
        with self.assertRaises(RuntimeError):
            u.validate_muscle_rig({"muscles": []})
        with self.assertRaises(RuntimeError):
            u.validate_muscle_rig({"muscles": [{"name": "x", "origin": {"joint": "a"}, "insertion": {}}]})
        with self.assertRaises(RuntimeError):
            u.validate_muscle_rig({"muscles": [{
                "name": "x", "origin": {"joint": "a"}, "insertion": {"joint": "b"},
                "bellyRadius": 0.0, "tendonRadius": 0.01,
            }]})
        rig = {
            "forwardReference": {"from": "foot", "to": "toe"},
            "muscles": [{
                "name": "biceps", "origin": {"joint": "a", "fraction": 0.1, "offset": [0, 0, 0.02]},
                "insertion": {"joint": "b"}, "bellyRadius": 0.04, "tendonRadius": 0.01,
                "driver": {"joint": "b", "startAngle": 10, "fullAngle": 110},
            }],
        }
        self.assertIs(u.validate_muscle_rig(rig), rig)

    def test_build_muscle_records_resolves_skeleton_and_strings(self) -> None:
        string_table = u.StringTableBuilder()
        skeletons = [
            u.SkeletonRecord(entity_id=4, name_offset=string_table.add("Other"), first_joint_record_index=0, joint_record_count=1),
            u.SkeletonRecord(entity_id=7, name_offset=string_table.add("Armature"), first_joint_record_index=1, joint_record_count=1),
        ]
        rig = u.validate_muscle_rig({
            "skeleton": "Armature",
            "forwardReference": {"from": "foot", "to": "toe"},
            "muscles": [{
                "name": "biceps", "origin": {"joint": "upperArm", "fraction": 0.1, "offset": [0, 0, 0.02]},
                "insertion": {"joint": "forearm", "tip": "hand"}, "bellyRadius": 0.04, "tendonRadius": 0.01,
                "driver": {"joint": "forearm", "startAngle": 10, "fullAngle": 110},
            }],
        })
        records = u.build_muscle_records(rig, skeletons, string_table)
        self.assertEqual(len(records), 1)
        record = records[0]
        self.assertEqual(record.skeleton_entity_id, 7)
        self.assertEqual(string_table.string_at(record.name_offset), "biceps")
        self.assertEqual(string_table.string_at(record.origin_joint_offset), "upperArm")
        self.assertEqual(string_table.string_at(record.insertion_tip_joint_offset), "hand")
        self.assertEqual(string_table.string_at(record.forward_joint_offset), "foot")
        self.assertEqual(record.origin_tip_joint_offset, u.INVALID_INDEX)
        self.assertEqual(record.flags, u.MUSCLE_FLAG_HAS_DRIVER)
        self.assertAlmostEqual(record.driver_start_angle, math.radians(10), places=6)
        self.assertAlmostEqual(record.driver_full_angle, math.radians(110), places=6)
        self.assertEqual(record.rings, 7)
        self.assertAlmostEqual(record.fiber_compliance, 2e-6)
        with self.assertRaises(RuntimeError):
            u.build_muscle_records({**rig, "skeleton": "Missing"}, skeletons, string_table)
        with self.assertRaises(RuntimeError):
            u.build_muscle_records(rig, [], string_table)

    def test_morph_entry_dtype_is_sixteen_bytes(self) -> None:
        self.assertEqual(u.MORPH_ENTRY_SIZE, 16)
        if u._MORPH_DTYPE is not None:
            self.assertEqual(u._MORPH_DTYPE.itemsize, 16)


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


def _make_mapping_node(
    *,
    scale=(1.0, 1.0, 1.0),
    location=(0.0, 0.0, 0.0),
    rotation=(0.0, 0.0, 0.0),
    vector_type: str = "POINT",
    uv_source: bool = True,
) -> FakeNode:
    location_socket = FakeSocket("Location")
    location_socket.default_value = location
    rotation_socket = FakeSocket("Rotation")
    rotation_socket.default_value = rotation
    scale_socket = FakeSocket("Scale")
    scale_socket.default_value = scale
    vector = FakeSocket("Vector")
    if uv_source:
        vector.link_from(FakeNode("ShaderNodeTexCoord"), "UV")
    mapping = FakeNode(
        "ShaderNodeMapping",
        inputs={"Location": location_socket, "Rotation": rotation_socket, "Scale": scale_socket, "Vector": vector},
    )
    mapping.name = "Mapping"
    mapping.vector_type = vector_type
    return mapping


def _make_mapped_image_node(name: str, mapping: FakeNode | None) -> FakeNode:
    node = _make_image_node(name)
    vector = FakeSocket("Vector")
    if mapping is not None:
        vector.link_from(mapping, "Vector")
    node.inputs = {"Vector": vector}
    color_output = FakeSocket("Color")
    color_output.is_linked = True
    node.outputs = [color_output]
    return node


def _make_invert_node(source: FakeNode, fac: float) -> FakeNode:
    fac_socket = FakeSocket("Fac")
    fac_socket.default_value = fac
    color = FakeSocket("Color")
    color.link_from(source, "Color")
    invert = FakeNode("ShaderNodeInvert", inputs={"Fac": fac_socket, "Color": color})
    invert.name = "Invert Color"
    return invert


class BlendImportFidelityTests(unittest.TestCase):
    def test_point_mapping_becomes_a_uv_scale_and_offset(self) -> None:
        transform = u.mapping_node_uv_transform(_make_mapping_node(scale=(2.49, 2.49, 2.49), location=(0.25, 0.5, 0.0)))
        self.assertEqual(transform.scale, (2.49, 2.49))
        self.assertEqual(transform.offset, (0.25, 0.5))
        self.assertEqual(transform.apply((1.0, 2.0)), (2.49 + 0.25, 4.98 + 0.5))

    def test_texture_mapping_is_the_inverse_and_vector_mapping_ignores_location(self) -> None:
        texture = u.mapping_node_uv_transform(
            _make_mapping_node(scale=(2.0, 4.0, 1.0), location=(1.0, 1.0, 0.0), vector_type="TEXTURE")
        )
        self.assertEqual(texture.scale, (0.5, 0.25))
        self.assertEqual(texture.offset, (-0.5, -0.25))
        vector = u.mapping_node_uv_transform(
            _make_mapping_node(scale=(2.0, 2.0, 1.0), location=(1.0, 1.0, 0.0), vector_type="VECTOR")
        )
        self.assertEqual(vector.offset, (0.0, 0.0))

    def test_mappings_a_uv_scale_cannot_represent_are_refused(self) -> None:
        self.assertIsNone(u.mapping_node_uv_transform(_make_mapping_node(rotation=(0.0, 0.0, 0.5))))
        self.assertIsNone(u.mapping_node_uv_transform(_make_mapping_node(scale=(-1.0, 1.0, 1.0))))
        self.assertIsNone(u.mapping_node_uv_transform(_make_mapping_node(vector_type="NORMAL")))
        linked_scale = _make_mapping_node()
        linked_scale.inputs["Scale"].link_from(FakeNode("ShaderNodeValue"), "Value")
        self.assertIsNone(u.mapping_node_uv_transform(linked_scale))

    def test_material_uv_transform_reads_the_mapping_in_front_of_its_textures(self) -> None:
        mapping = _make_mapping_node(scale=(2.49, 2.49, 2.49))
        albedo = _make_mapped_image_node("albedo", mapping)
        roughness = _make_mapped_image_node("roughness", mapping)
        principled, output = _make_principled_output(albedo)
        material = _make_material("brushed", [output, principled, albedo, roughness, mapping])

        transform = u.material_uv_transform(material)
        self.assertEqual(transform.scale, (2.49, 2.49))
        self.assertEqual(u.analyze_material(material).classification, u.MATERIAL_GRAPH_SUPPORTED)

    def test_material_uv_transform_is_none_without_mapping_or_from_generated_coordinates(self) -> None:
        plain = _make_mapped_image_node("plain", None)
        principled, output = _make_principled_output(plain)
        self.assertIsNone(u.material_uv_transform(_make_material("plain", [output, principled, plain])))

        generated = _make_mapping_node(scale=(3.0, 3.0, 3.0), uv_source=False)
        generated.inputs["Vector"].link_from(FakeNode("ShaderNodeTexCoord"), "Generated")
        textured = _make_mapped_image_node("generated", generated)
        principled, output = _make_principled_output(textured)
        material = _make_material("generated", [output, principled, textured, generated])
        self.assertIsNone(u.material_uv_transform(material))
        self.assertNotEqual(u.analyze_material(material).classification, u.MATERIAL_GRAPH_SUPPORTED)

    def test_textures_with_different_mappings_use_the_most_common_one_and_report_it(self) -> None:
        tiled = _make_mapping_node(scale=(4.0, 4.0, 1.0))
        a = _make_mapped_image_node("a", tiled)
        b = _make_mapped_image_node("b", tiled)
        c = _make_mapped_image_node("c", _make_mapping_node(scale=(2.0, 2.0, 1.0)))
        principled, output = _make_principled_output(a)
        material = _make_material("mixed", [output, principled, a, b, c])

        self.assertEqual(u.material_uv_transform(material).scale, (4.0, 4.0))
        findings = u.analyze_material(material).findings
        self.assertTrue(any("different Mapping transforms" in finding.reason for finding in findings))

    def test_invert_becomes_an_adjustment_at_its_strength(self) -> None:
        glossiness = _make_image_node("glossiness")
        roughness = FakeSocket("Roughness")
        roughness.link_from(_make_invert_node(glossiness, 1.0), "Color")
        with tempfile.TemporaryDirectory() as tmpdir:
            texture = u.resolve_texture_from_socket(roughness, Path(tmpdir) / "asset.blend")
        self.assertEqual(texture.adjustments, (u.ImageAdjustment("invert"),))

        partial = FakeSocket("Roughness")
        partial.link_from(_make_invert_node(_make_image_node("gloss"), 0.5), "Color")
        with tempfile.TemporaryDirectory() as tmpdir:
            texture = u.resolve_texture_from_socket(partial, Path(tmpdir) / "asset.blend")
        self.assertEqual(texture.adjustments, (u.ImageAdjustment("invert", fac=0.5),))

    def test_full_invert_is_supported_by_material_analysis(self) -> None:
        glossiness = _make_image_node("glossiness")
        invert = _make_invert_node(glossiness, 1.0)
        principled, output = _make_principled_output(None)
        roughness = FakeSocket("Roughness")
        roughness.link_from(invert, "Color")
        principled.inputs["Roughness"] = roughness
        material = _make_material("gloss_mat", [output, principled, invert, glossiness])
        self.assertEqual(u.analyze_material(material).classification, u.MATERIAL_GRAPH_SUPPORTED)

    def test_inverted_texture_stages_apart_from_the_plain_one(self) -> None:
        plain = u.ExportedTexture(name="gloss.png", uri="gloss.png", width=4, height=4, mip_count=1, source_image_name="gloss")
        inverted = u.replace(plain, adjustments=(u.ImageAdjustment("invert"),))
        self.assertNotEqual(u.texture_staging_key(plain), u.texture_staging_key(inverted))
        context = u.TextureStagingContext()
        self.assertEqual(u.unique_texture_destination_name(inverted, context, ".png"), "gloss_inverted.png")
        self.assertEqual(u.unique_texture_destination_name(plain, context, ".png"), "gloss.png")

    def test_emission_only_surface_exports_an_emissive_material(self) -> None:
        color = FakeSocket("Color")
        color.default_value = (1.0, 0.5, 0.25, 1.0)
        strength = FakeSocket("Strength")
        strength.default_value = 4.0
        emission = FakeNode("ShaderNodeEmission", inputs={"Color": color, "Strength": strength})
        emission.name = "Emission"
        surface = FakeSocket("Surface")
        surface.link_from(emission, "Emission")
        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": surface})
        output.name = "Material Output"
        material = _make_material("luz", [output, emission])
        material.diffuse_color = (0.8, 0.8, 0.8, 1.0)
        mesh_object = FakeSceneObject("Lamp", "MESH", FakeData(materials=[material]))

        with tempfile.TemporaryDirectory() as tmpdir:
            exported = u.extract_material(mesh_object, Path(tmpdir) / "asset.blend")

        self.assertEqual(exported.base_color_factor, (0.0, 0.0, 0.0, 1.0))
        self.assertEqual(exported.emissive_factor, (4.0, 2.0, 1.0))
        self.assertEqual(u.analyze_material(material).classification, u.MATERIAL_GRAPH_SUPPORTED)

    def test_skipped_ancestors_are_walked_past_not_exported(self) -> None:
        class Obj:
            def __init__(self, name, object_type, parent=None):
                self.name, self.type, self.parent = name, object_type, parent

            def as_pointer(self):
                return id(self)

        root = Obj("Root", "EMPTY")
        hidden_wall = Obj("HiddenWall", "MESH", root)
        lamp = Obj("Lamp", "MESH", hidden_wall)
        chosen = u.choose_export_objects([root, lamp], None, {hidden_wall.as_pointer()})
        self.assertEqual([obj.name for obj in chosen], ["Root", "Lamp"])

    def test_include_hidden_flag_is_off_by_default(self) -> None:
        base = ["blender", "--", "--input", "a.blend", "--output", "a.untold"]
        self.assertFalse(u.parse_args(base).include_hidden)
        self.assertTrue(u.parse_args(base + ["--include-hidden"]).include_hidden)
class AssetsDirTests(unittest.TestCase):
    """--assets-dir: the result file in one folder, the files it references in another."""

    def test_relative_asset_uri_uses_forward_slashes_and_parent_steps(self) -> None:
        base = Path("/project/Models")
        self.assertEqual(u.relative_asset_uri(base / "Tower" / "Textures" / "a.png", base), "Tower/Textures/a.png")
        self.assertEqual(u.relative_asset_uri(Path("/project/Shared/a.png"), base), "../Shared/a.png")

    def test_textures_stage_into_the_assets_dir_and_are_referenced_from_the_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            source = root / "source" / "wall.png"
            source.parent.mkdir()
            source.write_bytes(b"png bytes")
            output_path = root / "Models" / "Tower.untold"
            assets_dir = root / "Models" / "Tower"
            texture = u.ExportedTexture(
                name="wall.png", uri="wall.png", width=4, height=4, mip_count=1, source_path=source
            )
            previous_bpy = u.bpy
            try:
                u.bpy = None
                staged = u.stage_texture_for_output(texture, output_path, u.TextureStagingContext(assets_dir=assets_dir))
            finally:
                u.bpy = previous_bpy

            self.assertEqual(staged.uri, "Tower/Textures/wall.png")
            self.assertTrue((assets_dir / "Textures" / "wall.png").is_file())
            self.assertFalse((output_path.parent / "Textures").exists())

    def test_color_grade_lut_uri_is_relative_to_the_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            cube = root / "grade.cube"
            cube.write_text("LUT_3D_SIZE 2\n" + "0 0 0\n" * 8, encoding="utf-8")
            staged = u.stage_color_grade_lut_for_output(cube, root / "Models" / "Tower", uri_base=root / "Models")
            self.assertTrue(staged.uri.startswith("Tower/Textures/gradelut_"))

    def test_sidecar_cleanup_follows_the_assets_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            output_path = root / "Models" / "Tower.untold"
            beside_output = root / "Models" / "Textures"
            in_assets = root / "Models" / "Tower" / "Textures"
            beside_output.mkdir(parents=True)
            in_assets.mkdir(parents=True)

            u.clean_generated_sidecar_dirs(output_path, root / "Models" / "Tower")

            self.assertTrue(beside_output.exists(), "another asset's textures beside the output must survive")
            self.assertFalse(in_assets.exists())

    def test_pack_model_dirs_are_read_relative_to_the_manifest_and_never_escape_it(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir).resolve()
            pack_path = root / "Models" / "Tower.untoldpack"
            pack_path.parent.mkdir()
            pack_path.write_text(json.dumps({"models": [
                {"path": "Tower/Door/Door.untold"},
                {"path": "Loose.untold"},
                {"path": "../Elsewhere/Elsewhere.untold"},
            ]}), encoding="utf-8")
            self.assertEqual(u.read_pack_model_dirs(pack_path), [root / "Models" / "Tower" / "Door"])

    def test_earlier_results_inside_the_assets_dir_are_removed(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir).resolve()
            assets_dir = root / "Models" / "Tower"
            for name in ("Door", "Gone"):
                (assets_dir / name).mkdir(parents=True)
            (assets_dir / "Tower.blend").write_bytes(b"source")
            (assets_dir / "Tower.untoldpack").write_text(json.dumps({"models": [
                {"path": "Door/Door.untold"}, {"path": "Gone/Gone.untold"},
            ]}), encoding="utf-8")
            (assets_dir / "Tower.untold").write_bytes(b"older single-file result")

            removed = u.remove_results_left_in_assets_dir(
                root / "Models" / "Tower.untoldpack", assets_dir, keep_dirs=[assets_dir / "Door"]
            )

            self.assertEqual(sorted(path.name for path in removed), ["Tower.untold", "Tower.untoldpack"])
            self.assertTrue((assets_dir / "Door").is_dir(), "a model folder the new pack uses stays")
            self.assertFalse((assets_dir / "Gone").exists())
            self.assertTrue((assets_dir / "Tower.blend").is_file())

    def test_nothing_is_removed_without_a_separate_assets_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            output_path = Path(tmpdir) / "Tower.untold"
            output_path.write_bytes(b"result")
            self.assertEqual(u.remove_results_left_in_assets_dir(output_path, None), [])
            self.assertEqual(u.remove_results_left_in_assets_dir(output_path, Path(tmpdir)), [])
            self.assertTrue(output_path.is_file())

    def test_assets_dir_argument_defaults_to_none(self) -> None:
        base = ["blender", "--", "--input", "a.blend", "--output", "a.untold"]
        self.assertIsNone(u.parse_args(base).assets_dir)
        self.assertEqual(u.parse_args(base + ["--assets-dir", "a"]).assets_dir, "a")


def _socket(name: str, value=None, linked_from: tuple[FakeNode, str] | None = None) -> FakeSocket:
    socket = FakeSocket(name)
    socket.default_value = value
    if linked_from is not None:
        socket.link_from(*linked_from)
    return socket


def _color_node(bl_idname: str, source: FakeNode, input_name: str = "Color", **settings) -> FakeNode:
    inputs = {input_name: _socket(input_name, linked_from=(source, "Color"))}
    for name, value in settings.items():
        inputs[name.replace("_", " ").title() if name != "fac" else "Fac"] = _socket(name, value)
    node = FakeNode(bl_idname, inputs=inputs)
    node.name = bl_idname
    return node


class _FakeCurveMapping:
    """RGB Curves' mapping: curves R, G, B, C as functions."""

    def __init__(self, red, green, blue, combined) -> None:
        self.curves = [red, green, blue, combined]

    def evaluate(self, curve, position: float) -> float:
        return curve(position)


try:
    import numpy as _np
except ImportError:  # the CI image has no numpy; Blender's Python does
    _np = None


class MaterialColorNodeTests(unittest.TestCase):
    """Colour nodes between an image and a socket become image adjustments."""

    def test_settings_become_adjustments_and_no_op_settings_none(self) -> None:
        tex = _make_image_node()
        self.assertEqual(
            u.image_adjustment_for_node(_color_node("ShaderNodeGamma", tex, Gamma=1.3)),
            u.ImageAdjustment("gamma", (1.3,)),
        )
        self.assertIsNone(u.image_adjustment_for_node(_color_node("ShaderNodeGamma", tex, Gamma=1.0)))
        self.assertEqual(
            u.image_adjustment_for_node(_color_node("ShaderNodeBrightContrast", tex, Bright=0.1, Contrast=0.3)),
            u.ImageAdjustment("bright_contrast", (0.1, 0.3)),
        )
        hsv = FakeNode("ShaderNodeHueSaturation", inputs={
            "Color": _socket("Color", linked_from=(tex, "Color")),
            "Hue": _socket("Hue", 1.0), "Saturation": _socket("Saturation", 1.7),
            "Value": _socket("Value", 0.4), "Fac": _socket("Fac", 0.815),
        })
        self.assertEqual(u.image_adjustment_for_node(hsv), u.ImageAdjustment("hue_saturation", (1.0, 1.7, 0.4), fac=0.815))
        hsv.inputs["Hue"].default_value = 0.5
        hsv.inputs["Saturation"].default_value = 1.0
        hsv.inputs["Value"].default_value = 1.0
        self.assertIsNone(u.image_adjustment_for_node(hsv))

    def test_a_linked_setting_cannot_be_written_into_the_image(self) -> None:
        tex = _make_image_node()
        gamma = _color_node("ShaderNodeGamma", tex, Gamma=1.3)
        gamma.inputs["Gamma"].link_from(FakeNode("ShaderNodeValue"), "Value")
        self.assertIs(u.image_adjustment_for_node(gamma), u.NOT_REPRESENTABLE)

        socket = _socket("Base Color", linked_from=(gamma, "Color"))
        with tempfile.TemporaryDirectory() as tmpdir:
            texture = u.resolve_texture_from_socket(socket, Path(tmpdir) / "asset.blend")
        self.assertEqual(texture.adjustments, (), "the texture still goes through, without the node")

    def test_adjustments_stack_in_node_order(self) -> None:
        tex = _make_image_node("paint")
        gamma = _color_node("ShaderNodeGamma", tex, Gamma=2.0)
        invert = FakeNode("ShaderNodeInvert", inputs={"Color": _socket("Color", linked_from=(gamma, "Color")), "Fac": _socket("Fac", 1.0)})
        socket = _socket("Base Color", linked_from=(invert, "Color"))
        with tempfile.TemporaryDirectory() as tmpdir:
            texture = u.resolve_texture_from_socket(socket, Path(tmpdir) / "asset.blend")
        self.assertEqual(texture.adjustments, (u.ImageAdjustment("gamma", (2.0,)), u.ImageAdjustment("invert")))

    def test_rgb_curves_apply_the_combined_curve_before_each_channel(self) -> None:
        tex = _make_image_node()
        curves = _color_node("ShaderNodeRGBCurve", tex, fac=1.0)
        curves.mapping = _FakeCurveMapping(lambda x: x * 0.5, lambda x: x, lambda x: x, lambda x: x * x)
        adjustment = u.image_adjustment_for_node(curves)
        size = u.CURVE_LUT_SIZE
        red_table = adjustment.params[:size]
        self.assertAlmostEqual(red_table[-1], 0.5)
        self.assertAlmostEqual(red_table[size // 2], ((size // 2) / (size - 1)) ** 2 * 0.5)
        curves.mapping = _FakeCurveMapping(*([lambda x: x] * 4))
        self.assertIsNone(u.image_adjustment_for_node(curves), "identity curves change nothing")

    def test_color_ramp_traces_its_texture_through_the_color_output_only(self) -> None:
        tex = _make_image_node("roughness")
        ramp = FakeNode("ShaderNodeValToRGB", inputs={"Fac": _socket("Fac", linked_from=(tex, "Color"))})
        ramp.color_ramp = FakeData(evaluate=lambda x: (x * 0.131 / 0.6 if x < 0.6 else 0.131,) * 3 + (1.0,))
        with tempfile.TemporaryDirectory() as tmpdir:
            asset = Path(tmpdir) / "asset.blend"
            through_color = u.resolve_texture_from_socket(_socket("Roughness", linked_from=(ramp, "Color")), asset)
            through_alpha = u.resolve_texture_from_socket(_socket("Roughness", linked_from=(ramp, "Alpha")), asset)
        self.assertEqual(through_color.adjustments[0].kind, "ramp")
        self.assertIsNone(through_alpha)

    def test_adjusted_images_stage_apart_and_a_lone_invert_keeps_its_name(self) -> None:
        plain = u.ExportedTexture(name="gloss.png", uri="gloss.png", width=4, height=4, mip_count=1, source_image_name="gloss")
        gamma = u.replace(plain, adjustments=(u.ImageAdjustment("gamma", (1.3,)),))
        keys = {u.texture_staging_key(texture) for texture in (plain, gamma, u.replace(plain, adjustments=(u.ImageAdjustment("invert"),)))}
        self.assertEqual(len(keys), 3)
        self.assertEqual(u.adjustments_suffix((u.ImageAdjustment("invert"),)), "_inverted")
        self.assertTrue(u.adjustments_suffix(gamma.adjustments).startswith("_adj"))

    def test_color_nodes_on_a_texture_count_as_supported(self) -> None:
        tex = _make_image_node()
        hsv = FakeNode("ShaderNodeHueSaturation", inputs={
            "Color": _socket("Color", linked_from=(tex, "Color")),
            "Hue": _socket("Hue", 1.0), "Saturation": _socket("Saturation", 1.0),
            "Value": _socket("Value", 1.0), "Fac": _socket("Fac", 1.0),
        })
        hsv.name = "Hue/Saturation/Value"
        principled, output = _make_principled_output(hsv)
        analysis = u.analyze_material(_make_material("cartel", [output, principled, hsv, tex]))
        self.assertEqual(analysis.classification, u.MATERIAL_GRAPH_SUPPORTED)

    @unittest.skipIf(_np is None, "needs numpy (run under Blender's Python)")
    def test_pixel_math_matches_the_cycles_formulas(self) -> None:
        rgb = _np.array([[0.2, 0.5, 0.8], [1.0, 0.0, 0.0], [0.0, 0.0, 0.0]])
        gamma = u.apply_image_adjustments(rgb, (u.ImageAdjustment("gamma", (2.0,)),))
        self.assertTrue(_np.allclose(gamma, rgb ** 2))
        half_invert = u.apply_image_adjustments(rgb, (u.ImageAdjustment("invert", fac=0.5),))
        self.assertTrue(_np.allclose(half_invert, 0.5))
        rotated = u.apply_image_adjustments(rgb[1:2], (u.ImageAdjustment("hue_saturation", (1.0, 1.0, 1.0)),))
        self.assertTrue(_np.allclose(rotated, [[0.0, 1.0, 1.0]]), "hue 1.0 turns red into cyan")
        contrast = u.apply_image_adjustments(rgb, (u.ImageAdjustment("bright_contrast", (0.0, 1.0)),))
        self.assertTrue(_np.allclose(contrast, _np.maximum(2.0 * rgb - 0.5, 0.0)))
        self.assertTrue(_np.allclose(u.linear_to_srgb(u.srgb_to_linear(rgb)), rgb, atol=1.0e-6))


class MeshMaterialSlotTests(unittest.TestCase):
    def test_the_material_of_the_slot_the_faces_use(self) -> None:
        metal, sign = FakeData(name="METAL"), FakeData(name="INFO CARTEL")
        data = FakeData(materials=[metal, sign], polygons=[FakeData(material_index=1)])
        obj = FakeSceneObject("Cube.004", "MESH", data)
        self.assertIs(u.mesh_object_material(obj), sign)

    def test_an_object_linked_slot_wins_over_the_mesh_material(self) -> None:
        mesh_material, object_material = FakeData(name="mesh"), FakeData(name="object")
        data = FakeData(materials=[mesh_material], polygons=[FakeData(material_index=0)])
        obj = FakeSceneObject("Cube", "MESH", data)
        obj.material_slots = [FakeData(material=object_material)]
        self.assertIs(u.mesh_object_material(obj), object_material)

    def test_without_faces_the_first_material(self) -> None:
        first = FakeData(name="first")
        obj = FakeSceneObject("Empty mesh", "MESH", FakeData(materials=[first, FakeData(name="second")]))
        self.assertIs(u.mesh_object_material(obj), first)


class FacingEvaluationTests(unittest.TestCase):
    """Node chains with no texture behind them are exported as seen straight on."""

    def _mix(self, fac_source, a, b, fac=0.5) -> FakeNode:
        fac_socket = _socket("Factor", fac, linked_from=fac_source)
        mix = FakeNode("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MIX"
        mix.inputs = [fac_socket, a, b]
        return mix

    def test_layer_weight_facing_is_zero_and_its_fresnel_the_normal_reflectance(self) -> None:
        weight = FakeNode("ShaderNodeLayerWeight", inputs={"Blend": _socket("Blend", 0.5)})
        self.assertEqual(u.evaluate_socket_facing(_socket("Roughness", linked_from=(weight, "Facing"))), 0.0)
        fresnel = u.evaluate_socket_facing(_socket("Roughness", linked_from=(weight, "Fresnel")))
        self.assertAlmostEqual(fresnel, ((2.0 - 1.0) / (2.0 + 1.0)) ** 2)

    def test_a_mix_picks_its_side_without_looking_at_the_other(self) -> None:
        weight = FakeNode("ShaderNodeLayerWeight", inputs={"Blend": _socket("Blend", 0.5)})
        texture = _make_image_node("scratches")
        mix = self._mix((weight, "Facing"), _socket("A", (0.004, 0.004, 0.004, 1.0)), _socket("B", linked_from=(texture, "Color")))
        self.assertEqual(u.evaluate_socket_facing(_socket("Base Color", linked_from=(mix, "Result"))), (0.004, 0.004, 0.004))

        constant_one = FakeNode("ShaderNodeMix")
        constant_one.data_type, constant_one.blend_type = "RGBA", "MIX"
        constant_one.inputs = [_socket("Factor", 1.0), _socket("A", linked_from=(texture, "Color")), _socket("B", (0.27, 0.27, 0.27, 1.0))]
        self.assertEqual(u.evaluate_socket_facing(_socket("Roughness", linked_from=(constant_one, "Result"))), (0.27, 0.27, 0.27))

    def test_a_texture_in_the_way_gives_no_value(self) -> None:
        texture = _make_image_node("noise")
        mix = self._mix(None, _socket("A", linked_from=(texture, "Color")), _socket("B", (1.0, 1.0, 1.0, 1.0)), fac=0.5)
        self.assertIsNone(u.evaluate_socket_facing(_socket("Roughness", linked_from=(mix, "Result"))))

    def test_math_and_node_groups(self) -> None:
        math = FakeNode("ShaderNodeMath")
        math.operation = "MULTIPLY"
        math.inputs = [_socket("Value", 0.5), _socket("Value", 0.4)]
        group_input = FakeNode("NodeGroupInput")
        group_output = FakeNode("NodeGroupOutput", inputs={"Rough": _socket("Rough", linked_from=(group_input, "Scale"))})
        group = FakeNode("ShaderNodeGroup", inputs={"Scale": _socket("Scale", linked_from=(math, "Value"))})
        group.node_tree = FakeData(nodes=[group_input, group_output])
        self.assertAlmostEqual(u.evaluate_socket_facing(_socket("Roughness", linked_from=(group, "Rough"))), 0.2)

    def test_linked_scalar_without_texture_uses_the_evaluated_value(self) -> None:
        value = FakeNode("ShaderNodeValue")
        value.outputs = [_socket("Value", 0.27)]
        socket = _socket("Roughness", 0.5, linked_from=(value, "Value"))
        self.assertAlmostEqual(u._scalar_socket_factor(socket, None, default=0.5), 0.27)


class MaterialAlphaTests(unittest.TestCase):
    """Alpha and glass become the engine's blended alpha mode."""

    def _glass_mix(self) -> FakeNode:
        """The scene's GLASS: back faces transparent, front faces 92.5 % transparent and
        7.5 % a fully transmissive Principled BSDF."""
        principled = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Transmission Weight": _socket("Transmission Weight", 1.0)})
        transparent = FakeNode("ShaderNodeBsdfTransparent")
        front = FakeNode("ShaderNodeMixShader")
        front.inputs = [_socket("Fac", 0.075), _socket("Shader", linked_from=(transparent, "BSDF")), _socket("Shader", linked_from=(principled, "BSDF"))]
        backfacing = FakeNode("ShaderNodeNewGeometry")
        outer = FakeNode("ShaderNodeMixShader")
        outer.inputs = [_socket("Fac", 0.5, linked_from=(backfacing, "Backfacing")), _socket("Shader", linked_from=(front, "Shader")), _socket("Shader", linked_from=(FakeNode("ShaderNodeBsdfTransparent"), "BSDF"))]
        return outer

    def _material_with_surface(self, surface: FakeNode) -> FakeData:
        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": _socket("Surface", linked_from=(surface, "Shader"))})
        return _make_material("m", [output, surface])

    def test_shader_opacity_of_glass_transmission_and_transparent_mixes(self) -> None:
        self.assertAlmostEqual(u.surface_opacity(self._material_with_surface(self._glass_mix())), 0.075 * u.TRANSMISSION_OPACITY)
        tempered = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Transmission Weight": _socket("Transmission Weight", 1.0)})
        self.assertAlmostEqual(u.surface_opacity(self._material_with_surface(tempered)), u.TRANSMISSION_OPACITY)
        plain = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Transmission Weight": _socket("Transmission Weight", 0.0)})
        self.assertEqual(u.surface_opacity(self._material_with_surface(plain)), 1.0)

    def test_a_linked_transmission_is_not_mistaken_for_none(self) -> None:
        """A Transmission Weight driven by a texture (frosted or masked glass) used to
        fall through to the pre-4.0 "Transmission" lookup and read as 0: opaque."""
        mask = _make_image_node("frost_mask")
        glass = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Transmission Weight": _socket("Transmission Weight", 1.0, linked_from=(mask, "Color"))})
        self.assertEqual(u.principled_transmission(glass), (1.0, True))
        self.assertAlmostEqual(u.surface_opacity(self._material_with_surface(glass)), u.TRANSMISSION_OPACITY)

        output = FakeNode("ShaderNodeOutputMaterial", inputs={"Surface": _socket("Surface", linked_from=(glass, "BSDF"))})
        glass.name = "Principled BSDF"
        findings = u.analyze_material(_make_material("frosted", [output, glass])).findings
        self.assertTrue(any("cannot follow" in finding.reason and "slider value 1.00" in finding.reason for finding in findings))

    def test_a_transmission_from_constant_node_math_is_evaluated(self) -> None:
        value = FakeNode("ShaderNodeValue")
        value.outputs = [_socket("Value", 0.5)]
        glass = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Transmission Weight": _socket("Transmission Weight", 0.0, linked_from=(value, "Value"))})
        self.assertEqual(u.principled_transmission(glass), (0.5, False))
        self.assertAlmostEqual(u.surface_opacity(self._material_with_surface(glass)), 1.0 - 0.5 * (1.0 - u.TRANSMISSION_OPACITY))

    def test_the_pre_4_0_transmission_socket_is_still_read(self) -> None:
        legacy = FakeNode("ShaderNodeBsdfPrincipled", inputs={"Transmission": _socket("Transmission", 1.0)})
        self.assertEqual(u.principled_transmission(legacy), (1.0, False))

    def test_a_mix_driven_by_anything_but_backfacing_is_left_opaque(self) -> None:
        mix = FakeNode("ShaderNodeMixShader")
        mix.inputs = [_socket("Fac", 0.5, linked_from=(FakeNode("ShaderNodeLayerWeight"), "Facing")), _socket("Shader", linked_from=(FakeNode("ShaderNodeBsdfTransparent"), "BSDF")), _socket("Shader", linked_from=(FakeNode("ShaderNodeBsdfPrincipled"), "BSDF"))]
        self.assertEqual(u.surface_opacity(self._material_with_surface(mix)), 1.0)

    def _principled_material(self, alpha_socket: FakeSocket, base_color_source: FakeNode | None = None) -> tuple[FakeData, FakeNode]:
        principled, output = _make_principled_output(base_color_source)
        principled.inputs["Alpha"] = alpha_socket
        return _make_material("mat", [output, principled]), principled

    def test_constant_alpha_blends_and_full_alpha_stays_opaque(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            asset = Path(tmpdir) / "asset.blend"
            material, _ = self._principled_material(_socket("Alpha", 0.516))
            self.assertEqual(u._material_alpha(material, material.node_tree.nodes[1].inputs["Alpha"], 0.516, None, asset), (0.516, u.MATERIAL_ALPHA_MODE_BLEND, None))
            material, _ = self._principled_material(_socket("Alpha", 1.0))
            self.assertEqual(u._material_alpha(material, material.node_tree.nodes[1].inputs["Alpha"], 1.0, None, asset)[1], u.MATERIAL_ALPHA_MODE_OPAQUE)

    def test_alpha_from_the_base_colour_image_needs_no_extra_texture(self) -> None:
        image = _make_image_node("leaves")
        with tempfile.TemporaryDirectory() as tmpdir:
            asset = Path(tmpdir) / "asset.blend"
            base = u.resolve_texture_from_socket(_socket("Base Color", linked_from=(image, "Color")), asset)
            alpha_socket = _socket("Alpha", 1.0, linked_from=(image, "Alpha"))
            material, _ = self._principled_material(alpha_socket, image)
            factor, mode, alpha_texture = u._material_alpha(material, alpha_socket, 1.0, base, asset)
        self.assertEqual((factor, mode, alpha_texture), (1.0, u.MATERIAL_ALPHA_MODE_BLEND, None))

    def test_alpha_from_another_texture_is_kept_for_staging(self) -> None:
        mask = _make_image_node("mask")
        gamma = _color_node("ShaderNodeGamma", mask, Gamma=1.3)
        alpha_socket = _socket("Alpha", 1.0, linked_from=(gamma, "Color"))
        material, _ = self._principled_material(alpha_socket)
        with tempfile.TemporaryDirectory() as tmpdir:
            factor, mode, alpha_texture = u._material_alpha(material, alpha_socket, 1.0, None, Path(tmpdir) / "asset.blend")
        self.assertEqual((factor, mode), (1.0, u.MATERIAL_ALPHA_MODE_BLEND))
        self.assertEqual(alpha_texture.adjustments, (u.ImageAdjustment("gamma", (1.3,)),))

    def test_the_alpha_mode_is_written_in_the_material_flags(self) -> None:
        writer = u.BinaryWriter()
        u.write_material_record(writer, u.MaterialRecord(
            name_offset=0, flags=u.MATERIAL_ALPHA_MODE_BLEND, base_color_factor=(1.0, 1.0, 1.0, 0.5),
            emissive_factor=(0.0, 0.0, 0.0), normal_scale=1.0, metallic_factor=0.0, roughness_factor=0.5,
            occlusion_strength=1.0, alpha_cutoff=0.5, base_color_texture_index=u.INVALID_INDEX,
        ))
        self.assertEqual(struct.unpack_from("<I", writer.data, 4)[0], u.MATERIAL_ALPHA_MODE_BLEND)


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


# What Blender left on disk for the normal map of a real scene: the PNG signature and
# the IHDR chunk (2048 x 2048, 8-bit RGB), and nothing after them.
_HEADER_ONLY_PNG = bytes.fromhex("89504e470d0a1a0a0000000d49484452000008000000080008020000003dc54467")


def _build_complete_png() -> bytes:
    """A whole 1x1 RGB PNG: signature, IHDR, IDAT and the closing IEND chunk."""

    def chunk(chunk_type: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + payload)
        return struct.pack(">I", len(payload)) + chunk_type + payload + struct.pack(">I", crc)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"\x00\x80\x80\xff"))
        + chunk(b"IEND", b"")
    )


class FakePixels:
    def __init__(self, values: list[float]) -> None:
        self.values = list(values)

    def __getitem__(self, index: int) -> float:
        return self.values[index]

    def foreach_get(self, buffer) -> None:
        for index, value in enumerate(self.values):
            buffer[index] = value

    def foreach_set(self, buffer) -> None:
        self.values = list(buffer)


class FakeWritableImage:
    """A Blender image whose save() either works, or fails the way Blender's PNG writer
    does on bad metadata: the header is already on disk when the error is raised."""

    SAVE_ERROR = (
        "Error: Could not write image: internal error, see console\n"
        "Error: Image 'floor_normal.jpg' could not be saved to 'floor_normal.png'\n"
    )

    def __init__(self, name: str, *, save: str, pixels: list[float] | None = None) -> None:
        self.name = name
        self.has_data = True
        self.size = (1, 1)
        self.depth = 24
        self.channels = 4
        self.is_float = False
        self.alpha_mode = "STRAIGHT"
        self.colorspace_settings = FakeData(name="Non-Color")
        self.filepath_raw = "//textures/floor_normal.jpg"
        self.file_format = "JPEG"
        self.library = None
        self.pixels = FakePixels(pixels if pixels is not None else [0.0, 0.0, 0.0, 0.0])
        self.save_behavior = save
        self.save_count = 0

    def save(self) -> None:
        self.save_count += 1
        destination = Path(self.filepath_raw)
        if self.save_behavior == "works":
            destination.write_bytes(_build_complete_png())
            return
        destination.write_bytes(_HEADER_ONLY_PNG)
        if self.save_behavior == "fails":
            raise RuntimeError(self.SAVE_ERROR)
        # "truncates": the header-only file is left behind without any error.


class FakeImages:
    """bpy.data.images with one source image; every image made by new() saves as told."""

    def __init__(self, source: FakeWritableImage, *, copies_save: str) -> None:
        self.source = source
        self.copies_save = copies_save
        self.created: list[FakeWritableImage] = []
        self.removed: list[FakeWritableImage] = []

    def get(self, name: str):
        return self.source if name == self.source.name else None

    def new(self, name: str, width: int, height: int, alpha: bool = False, float_buffer: bool = False):
        copy = FakeWritableImage(name, save=self.copies_save)
        copy.size = (width, height)
        copy.depth = 32 if alpha else 24
        copy.is_float = float_buffer
        copy.filepath_raw = ""
        copy.file_format = "TARGA"
        copy.colorspace_settings = FakeData(name="sRGB")
        self.created.append(copy)
        return copy

    def remove(self, image: FakeWritableImage) -> None:
        self.removed.append(image)


def _fake_bpy_for_images(images: FakeImages) -> FakeData:
    return FakeData(
        data=FakeData(images=images),
        path=FakeData(abspath=lambda filepath, library=None: filepath),
    )


def _make_node_with_normal_map(
    image_name: str, object_name: str = "Floor", *, as_inverted_roughness: bool = False
) -> "u.ExportedNode":
    """One material-split fragment of an object whose material uses the image as its
    normal map, or inverted as its roughness map."""
    bounds = u.AABB(minimum=(0.0, 0.0, 0.0), maximum=(1.0, 1.0, 1.0))
    texture = u.ExportedTexture(
        name="floor_normal.jpg",
        uri="../textures/floor_normal.jpg",
        width=1,
        height=1,
        mip_count=1,
        source_path=Path("/nonexistent/textures/floor_normal.jpg"),
        source_image_name=image_name,
    )
    material = u.ExportedMaterial(
        name="garage_floor",
        base_color_factor=(1.0, 1.0, 1.0, 1.0),
        emissive_factor=(0.0, 0.0, 0.0),
        normal_scale=1.0,
        metallic_factor=0.0,
        roughness_factor=0.5,
        occlusion_strength=1.0,
        alpha_cutoff=0.5,
        base_color_texture=None,
        normal_texture=None if as_inverted_roughness else texture,
        roughness_texture=u.replace(texture, adjustments=(u.ImageAdjustment("invert"),)) if as_inverted_roughness else None,
    )
    mesh = u.ExportedMesh(
        entity_name=f"{object_name}_mat0",
        parent_entity_name=None,
        mesh_name=object_name,
        local_transform_rows=u.identity_matrix_rows(),
        local_bounds=bounds,
        world_bounds=bounds,
        vertices=b"",
        indices=b"",
        edge_indices=b"",
        vertex_count=0,
        index_count=0,
        edge_index_count=0,
        index_type=u.INDEX_TYPE_UINT16,
        material=material,
        skin_binding=None,
        validation_mesh=u.ValidationMesh(
            name=object_name,
            vertex_count=0,
            index_count=0,
            positions=[],
            normals=[],
            tangents=[],
            uv0=[],
            indices=[],
            edge_indices=[],
        ),
    )
    return u.ExportedNode(
        entity_name=f"{object_name}_mat0",
        parent_entity_name=None,
        local_transform_rows=u.identity_matrix_rows(),
        local_bounds=bounds,
        world_bounds=bounds,
        mesh=mesh,
        material_split_root_name=object_name,
    )


class TextureWriteFailureTests(unittest.TestCase):
    """Regression coverage for an export that stopped half-way and left a 33-byte PNG behind.

    The source was a JPEG that Blender itself had saved from an image with an embedded
    ICC profile. Such a file carries a "Blender:ICCProfile:..." comment; read back, it
    becomes a metadata entry that Blender's PNG writer takes for the profile itself, and
    libpng aborts the write once the PNG header is on disk. The exporter now writes the
    pixels again from a copy that has no metadata, never leaves an incomplete file, and
    reports a texture it cannot write instead of stopping the export."""

    def setUp(self) -> None:
        self.original_bpy = u.bpy
        self.tmpdir = tempfile.TemporaryDirectory()
        self.output_dir = Path(self.tmpdir.name)

    def tearDown(self) -> None:
        u.bpy = self.original_bpy
        self.tmpdir.cleanup()

    def stage_model(self, object_name: str, **staging) -> tuple["u.ExportedMaterial", str]:
        """Stage one model of a pack: the object, with the texture of 'floor_normal.jpg'.
        Returns its staged material and what the staging printed."""
        with contextlib.redirect_stdout(io.StringIO()) as output:
            staged_nodes = u.stage_nodes_for_output(
                [_make_node_with_normal_map("floor_normal.jpg", object_name)],
                self.output_dir / object_name / f"{object_name}.untold",
                **staging,
            )
        return staged_nodes[0].mesh.material, output.getvalue()

    def test_png_is_complete_rejects_the_header_only_file(self) -> None:
        header_only = self.output_dir / "header_only.png"
        header_only.write_bytes(_HEADER_ONLY_PNG)
        complete = self.output_dir / "complete.png"
        complete.write_bytes(_build_complete_png())
        cut_short = self.output_dir / "cut_short.png"
        cut_short.write_bytes(_build_complete_png()[:-1])
        empty = self.output_dir / "empty.png"
        empty.write_bytes(b"")
        not_a_png = self.output_dir / "not_a_png.png"
        not_a_png.write_bytes(b"not a png file, but longer than an IEND chunk")

        self.assertEqual(len(_HEADER_ONLY_PNG), 33)
        self.assertEqual(u._png_ihdr(header_only), (8, 2), "the header alone still reads as a valid PNG header")
        self.assertFalse(u._png_is_complete(header_only))
        self.assertTrue(u._png_is_complete(complete))
        self.assertFalse(u._png_is_complete(cut_short))
        self.assertFalse(u._png_is_complete(empty))
        self.assertFalse(u._png_is_complete(not_a_png))
        self.assertFalse(u._png_is_complete(self.output_dir / "missing.png"))

    def test_written_image_problem_describes_what_is_wrong(self) -> None:
        header_only = self.output_dir / "header_only.png"
        header_only.write_bytes(_HEADER_ONLY_PNG)
        complete = self.output_dir / "complete.png"
        complete.write_bytes(_build_complete_png())
        empty = self.output_dir / "empty.tga"
        empty.write_bytes(b"")
        other_format = self.output_dir / "texture.tga"
        other_format.write_bytes(b"only PNG output is checked for its closing chunk")

        self.assertIsNone(u._written_image_problem(complete))
        self.assertIsNone(u._written_image_problem(other_format))
        self.assertEqual(u._written_image_problem(self.output_dir / "missing.png"), "no file was written")
        self.assertEqual(u._written_image_problem(empty), "the file is empty")
        self.assertIn("33 bytes", u._written_image_problem(header_only))

    def test_failed_save_is_retried_from_a_metadata_free_copy(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails", pixels=[0.5, 0.5, 1.0, 1.0])
        images = FakeImages(source, copies_save="works")
        u.bpy = _fake_bpy_for_images(images)
        destination = self.output_dir / "Textures" / "floor_normal.png"

        with contextlib.redirect_stdout(io.StringIO()) as output:
            u.write_blender_image_to_path("floor_normal.jpg", destination)

        self.assertTrue(u._png_is_complete(destination))
        self.assertEqual(source.save_count, 1)
        self.assertEqual(len(images.created), 1)
        copy = images.created[0]
        self.assertEqual(copy.save_count, 1)
        self.assertEqual(copy.pixels.values, [0.5, 0.5, 1.0, 1.0])
        self.assertEqual(copy.size, (1, 1))
        self.assertEqual(copy.depth, 24, "an RGB source must not grow an alpha channel")
        self.assertEqual(copy.colorspace_settings.name, "Non-Color")
        self.assertEqual(copy.alpha_mode, "STRAIGHT")
        self.assertEqual(images.removed, [copy], "the copy must not stay in the .blend data")
        self.assertEqual(source.filepath_raw, "//textures/floor_normal.jpg")
        self.assertEqual(source.file_format, "JPEG")
        self.assertIn("floor_normal.jpg", output.getvalue())
        self.assertIn("Could not write image: internal error, see console", output.getvalue())

    def test_handing_the_problem_back_goes_straight_to_the_copy(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        images = FakeImages(source, copies_save="works")
        u.bpy = _fake_bpy_for_images(images)
        first = self.output_dir / "Floor" / "Textures" / "floor_normal.png"
        second = self.output_dir / "Wall" / "Textures" / "floor_normal.png"

        with contextlib.redirect_stdout(io.StringIO()) as first_output:
            problem = u.write_blender_image_to_path("floor_normal.jpg", first)
        with contextlib.redirect_stdout(io.StringIO()) as second_output:
            problem_again = u.write_blender_image_to_path("floor_normal.jpg", second, failed_write_problem=problem)

        self.assertEqual(problem, "Error: Could not write image: internal error, see console")
        self.assertEqual(problem_again, problem)
        self.assertTrue(u._png_is_complete(first))
        self.assertTrue(u._png_is_complete(second))
        self.assertEqual(source.save_count, 1, "the write that fails must not be tried again")
        self.assertEqual(len(images.created), 2)
        self.assertEqual(images.removed, images.created)
        self.assertNotEqual(first_output.getvalue(), "")
        self.assertEqual(second_output.getvalue(), "")

    def test_write_remembers_nothing_by_itself(self) -> None:
        """What is known about an image belongs to the export that found it out. Kept by
        the module, it would outlive the export: the add-on runs many in one Blender
        session, and the next one may meet another image by the same name."""
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        images = FakeImages(source, copies_save="works")
        u.bpy = _fake_bpy_for_images(images)

        outputs = []
        for folder in ("first_export", "second_export"):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                u.write_blender_image_to_path("floor_normal.jpg", self.output_dir / folder / "floor_normal.png")
            outputs.append(output.getvalue())

        self.assertEqual(source.save_count, 2, "each export must try the ordinary write for itself")
        self.assertIn("Blender could not write image", outputs[0])
        self.assertIn("Blender could not write image", outputs[1])

    def test_pack_tries_the_failing_write_once_for_all_its_models(self) -> None:
        """A pack writes a texture once for every model that uses it. Only the first of
        them should pay for the failed attempt and show Blender's error output."""
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        u.bpy = _fake_bpy_for_images(FakeImages(source, copies_save="works"))
        write_failures = u.TextureWriteFailures()

        floor, floor_output = self.stage_model("Floor", write_failures=write_failures)
        wall, wall_output = self.stage_model("Wall", write_failures=write_failures)

        self.assertEqual(source.save_count, 1)
        self.assertIn("Blender could not write image", floor_output)
        self.assertEqual(wall_output, "")
        for object_name, material in (("Floor", floor), ("Wall", wall)):
            self.assertEqual(material.normal_texture.uri, "Textures/floor_normal.png")
            self.assertTrue(u._png_is_complete(self.output_dir / object_name / "Textures" / "floor_normal.png"))

    def test_export_does_not_inherit_what_another_one_found_out(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        u.bpy = _fake_bpy_for_images(FakeImages(source, copies_save="works"))

        _, first_output = self.stage_model("Floor")
        _, second_output = self.stage_model("Wall")

        self.assertEqual(source.save_count, 2)
        self.assertIn("Blender could not write image", first_output)
        self.assertIn("Blender could not write image", second_output)

    def test_pack_tries_an_unwritable_texture_once_and_reports_it_for_every_model(self) -> None:
        """A texture that cannot be written at all must not go through both attempts,
        and Blender's error output, again for every model that uses it."""
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        images = FakeImages(source, copies_save="fails")
        u.bpy = _fake_bpy_for_images(images)
        write_failures = u.TextureWriteFailures()
        skipped_textures: list[str] = []
        staging = {"write_failures": write_failures, "skipped_textures": skipped_textures}

        floor, floor_output = self.stage_model("Floor", **staging)
        wall, wall_output = self.stage_model("Wall", **staging)

        self.assertEqual(source.save_count, 1)
        self.assertEqual(len(images.created), 1)
        self.assertIsNone(floor.normal_texture)
        self.assertIsNone(wall.normal_texture)
        self.assertIn("Blender could not write image", floor_output)
        self.assertNotIn("Blender could not write image", wall_output)
        self.assertEqual(len(skipped_textures), 2)
        self.assertIn("object 'Floor'", skipped_textures[0])
        self.assertIn("object 'Wall'", skipped_textures[1])
        self.assertIn(f"  Warning: {skipped_textures[1]}", wall_output)
        for object_name in ("Floor", "Wall"):
            self.assertEqual(list((self.output_dir / object_name / "Textures").iterdir()), [])

    def test_inverted_use_of_an_image_shares_what_is_known_about_it(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        u.bpy = _fake_bpy_for_images(FakeImages(source, copies_save="fails"))
        write_failures = u.TextureWriteFailures()

        self.stage_model("Floor", write_failures=write_failures)
        with contextlib.redirect_stdout(io.StringIO()):
            staged_nodes = u.stage_nodes_for_output(
                [_make_node_with_normal_map("floor_normal.jpg", "Wall", as_inverted_roughness=True)],
                self.output_dir / "Wall" / "Wall.untold",
                write_failures=write_failures,
            )

        self.assertIsNone(staged_nodes[0].mesh.material.roughness_texture)
        self.assertEqual(source.save_count, 1, "the image fails to write whether or not it is inverted afterwards")

    def test_texture_that_has_no_pixel_data_is_not_a_write_failure(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="works")
        source.size = (0, 0)
        u.bpy = _fake_bpy_for_images(FakeImages(source, copies_save="works"))
        write_failures = u.TextureWriteFailures()

        material, _ = self.stage_model("Floor", write_failures=write_failures)

        self.assertIsNone(material.normal_texture)
        self.assertEqual(write_failures.left_out, {})
        self.assertEqual(write_failures.written_from_copy, {})

    def test_silently_truncated_file_is_retried_too(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="truncates")
        images = FakeImages(source, copies_save="works")
        u.bpy = _fake_bpy_for_images(images)
        destination = self.output_dir / "floor_normal.png"

        with contextlib.redirect_stdout(io.StringIO()) as output:
            u.write_blender_image_to_path("floor_normal.jpg", destination)

        self.assertTrue(u._png_is_complete(destination))
        self.assertEqual(len(images.created), 1)
        self.assertIn("33 bytes", output.getvalue())

    def test_successful_save_makes_no_copy(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="works")
        images = FakeImages(source, copies_save="works")
        u.bpy = _fake_bpy_for_images(images)
        destination = self.output_dir / "floor_normal.png"

        with contextlib.redirect_stdout(io.StringIO()) as output:
            problem = u.write_blender_image_to_path("floor_normal.jpg", destination)

        self.assertIsNone(problem)
        self.assertTrue(u._png_is_complete(destination))
        self.assertEqual(images.created, [])
        self.assertEqual(output.getvalue(), "")

    def test_no_file_is_left_behind_when_every_attempt_fails(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        images = FakeImages(source, copies_save="fails")
        u.bpy = _fake_bpy_for_images(images)
        destination = self.output_dir / "Textures" / "floor_normal.png"

        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(u.TextureWriteError) as raised:
                u.write_blender_image_to_path("floor_normal.jpg", destination)

        self.assertFalse(destination.exists(), "a failed write must not leave a truncated PNG")
        self.assertIn("floor_normal.jpg", str(raised.exception))
        self.assertEqual(images.removed, images.created)
        self.assertEqual(source.filepath_raw, "//textures/floor_normal.jpg")
        self.assertEqual(source.file_format, "JPEG")

    def test_float_image_is_not_retried_from_a_copy(self) -> None:
        """A copy of a float buffer is not written back the way its source is (a 16-bit
        sRGB texture came out darker), so such a texture is reported instead."""
        source = FakeWritableImage("floor_height.png", save="fails")
        source.is_float = True
        source.depth = 96
        images = FakeImages(source, copies_save="works")
        u.bpy = _fake_bpy_for_images(images)
        destination = self.output_dir / "floor_height.png"
        scene = FakeData(
            render=FakeData(image_settings=FakeData(file_format="PNG", color_depth="8", color_mode="RGB")),
            view_settings=None,
            display_settings=None,
            sequencer_colorspace_settings=None,
        )
        u.bpy.context = FakeData(scene=scene)
        source.save_render = lambda filepath, scene=None: source.save()

        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(u.TextureWriteError) as raised:
                u.write_blender_image_to_path("floor_height.png", destination)

        self.assertIn("floor_height.png", str(raised.exception))
        self.assertEqual(images.created, [])
        self.assertFalse(destination.exists())

    def test_unwritable_texture_is_reported_and_the_export_continues(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        u.bpy = _fake_bpy_for_images(FakeImages(source, copies_save="fails"))
        output_path = self.output_dir / "Floor" / "Floor.untold"
        skipped_textures: list[str] = []

        with contextlib.redirect_stdout(io.StringIO()) as output:
            staged_nodes = u.stage_nodes_for_output(
                [_make_node_with_normal_map("floor_normal.jpg")],
                output_path,
                skipped_textures=skipped_textures,
            )

        self.assertEqual(len(staged_nodes), 1)
        self.assertIsNone(staged_nodes[0].mesh.material.normal_texture)
        self.assertEqual(list((output_path.parent / "Textures").iterdir()), [])

        self.assertEqual(len(skipped_textures), 1)
        for expected in ("'floor_normal.jpg'", "normal texture", "material 'garage_floor'", "object 'Floor'"):
            self.assertIn(expected, skipped_textures[0])
        self.assertIn(f"  Warning: {skipped_textures[0]}", output.getvalue())

        with contextlib.redirect_stdout(io.StringIO()) as summary:
            u.print_skipped_textures(skipped_textures)
        self.assertIn("1 texture(s) could not be exported", summary.getvalue())
        self.assertIn(skipped_textures[0], summary.getvalue())

    def test_recovered_texture_is_staged_like_any_other(self) -> None:
        source = FakeWritableImage("floor_normal.jpg", save="fails")
        u.bpy = _fake_bpy_for_images(FakeImages(source, copies_save="works"))
        output_path = self.output_dir / "Floor" / "Floor.untold"
        skipped_textures: list[str] = []

        with contextlib.redirect_stdout(io.StringIO()):
            staged_nodes = u.stage_nodes_for_output(
                [_make_node_with_normal_map("floor_normal.jpg")],
                output_path,
                skipped_textures=skipped_textures,
            )

        normal_texture = staged_nodes[0].mesh.material.normal_texture
        self.assertIsNotNone(normal_texture)
        self.assertEqual(normal_texture.uri, "Textures/floor_normal.png")
        self.assertTrue(u._png_is_complete(output_path.parent / "Textures" / "floor_normal.png"))
        self.assertEqual(skipped_textures, [])

    def test_print_skipped_textures_is_silent_when_nothing_was_skipped(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as output:
            u.print_skipped_textures([])
        self.assertEqual(output.getvalue(), "")


_MINIMAL_CUBE_LUT = (
    "TITLE \"Test LUT\"\n"
    "# a comment line\n"
    "LUT_3D_SIZE 2\n"
    "0.0 0.0 0.0\n"
    "1.0 0.0 0.0\n"
    "0.0 1.0 0.0\n"
    "1.0 1.0 0.0\n"
    "0.0 0.0 1.0\n"
    "1.0 0.0 1.0\n"
    "0.0 1.0 1.0\n"
    "1.0 1.0 1.0\n"
)


class ColorGradeLUTTests(unittest.TestCase):
    """stage_color_grade_lut_for_output/_parse_cube_lut_header need no Blender
    context (pure file I/O)."""

    def test_parses_lut_3d_size_and_default_domain(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cube_path = Path(tmp) / "test.cube"
            cube_path.write_text(_MINIMAL_CUBE_LUT)
            lut_size, domain_min, domain_max = u._parse_cube_lut_header(cube_path)
            self.assertEqual(lut_size, 2)
            self.assertEqual(domain_min, (0.0, 0.0, 0.0))
            self.assertEqual(domain_max, (1.0, 1.0, 1.0))

    def test_parses_custom_domain(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cube_path = Path(tmp) / "test.cube"
            cube_path.write_text(
                "LUT_3D_SIZE 2\n"
                "DOMAIN_MIN -1.0 -1.0 -1.0\n"
                "DOMAIN_MAX 2.0 2.0 2.0\n"
                "0.0 0.0 0.0\n" * 8
            )
            _, domain_min, domain_max = u._parse_cube_lut_header(cube_path)
            self.assertEqual(domain_min, (-1.0, -1.0, -1.0))
            self.assertEqual(domain_max, (2.0, 2.0, 2.0))

    def test_rejects_missing_lut_3d_size(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cube_path = Path(tmp) / "bad.cube"
            cube_path.write_text("TITLE \"bad\"\n0.0 0.0 0.0\n")
            with self.assertRaises(RuntimeError):
                u._parse_cube_lut_header(cube_path)

    def test_rejects_1d_lut(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cube_path = Path(tmp) / "bad.cube"
            cube_path.write_text("LUT_1D_SIZE 16\n")
            with self.assertRaises(RuntimeError):
                u._parse_cube_lut_header(cube_path)

    def test_rejects_out_of_range_size(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cube_path = Path(tmp) / "bad.cube"
            cube_path.write_text("LUT_3D_SIZE 1\n0.0 0.0 0.0\n")
            with self.assertRaises(RuntimeError):
                u._parse_cube_lut_header(cube_path)

    def test_stage_copies_file_and_content_addresses(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            cube_path = tmp_path / "artist_grade.cube"
            cube_path.write_text(_MINIMAL_CUBE_LUT)
            output_dir = tmp_path / "out"

            staged = u.stage_color_grade_lut_for_output(cube_path, output_dir)
            self.assertEqual(staged.lut_size, 2)
            self.assertTrue(staged.source_path.is_file())
            self.assertTrue(staged.uri.startswith("Textures/"))
            self.assertTrue(staged.uri.endswith(".cube"))
            self.assertEqual(staged.source_path.read_text(), _MINIMAL_CUBE_LUT)

            # Re-staging identical content resolves to the same destination
            # (content-addressed), rather than piling up duplicate files.
            staged_again = u.stage_color_grade_lut_for_output(cube_path, output_dir)
            self.assertEqual(staged.uri, staged_again.uri)

    def test_stage_rejects_missing_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(RuntimeError):
                u.stage_color_grade_lut_for_output(Path(tmp) / "missing.cube", Path(tmp) / "out")

    def test_stage_rejects_non_cube_extension(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            bad_path = tmp_path / "grade.png"
            bad_path.write_bytes(b"not a cube file")
            with self.assertRaises(RuntimeError):
                u.stage_color_grade_lut_for_output(bad_path, tmp_path / "out")


if __name__ == "__main__":
    unittest.main()
