import struct
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import texbake as t
import untoldexplorer as u

IDENTITY_ROWS = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]]


def _build_minimal_untold_file(tmpdir: Path) -> Path:
    """Build a .untold file containing only string/texture/light/camera chunks.

    Mirrors the layout untoldexplorer.build_untold_file() produces, using the
    same low-level writer functions, but without mesh/entity/material data —
    patch_refs() only requires string_table and texture_table unconditionally,
    and reads light/camera tables if present.

    Uses non-ASCII light/camera names, matching the real-world regression:
    a Blender scene with CJK object names hit corrupted light/camera names
    after `--optimize` because texbake.patch_refs() rebuilt the string table
    (base_color.png -> .utex changes every subsequent string's offset) without
    remapping the light_table/camera_table name_offset fields.
    """
    textures_dir = tmpdir / "Textures"
    textures_dir.mkdir()
    (textures_dir / "wall.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 16)
    (textures_dir / "wall.utex").write_bytes(b"UTEX\x00\x00\x00\x00" + b"\x00" * 16)

    strings = u.StringTableBuilder()
    texture_name_off = strings.add("wall")
    texture_uri_off = strings.add("Textures/wall.png")
    light_name_off = strings.add("日光")  # "日光" (sunlight) — non-ASCII, like the real asset
    camera_name_off = strings.add("摄像机")  # "摄像机" (camera)
    view_name_off = strings.add("AgX")
    look_name_off = strings.add("Medium High Contrast")

    texture_writer = u.BinaryWriter()
    u.write_texture_record(
        texture_writer,
        u.TextureRecord(
            name_offset=texture_name_off, uri_offset=texture_uri_off,
            texture_format=0, flags=u.TEXTURE_FLAG_SRGB, width=64, height=64, mip_count=1,
        ),
    )

    light_writer = u.BinaryWriter()
    u.write_light_record(
        light_writer,
        u.LightRecord(
            entity_id=0, name_offset=light_name_off, light_type=u.LIGHT_TYPE_DIRECTIONAL,
            flags=0, color=(1.0, 1.0, 1.0), intensity=1.0, position=(0.0, 0.0, 0.0), radius=0.0,
            direction=(0.0, -1.0, 0.0), falloff=0.0, right=(1.0, 0.0, 0.0), inner_cone=0.0,
            up=(0.0, 1.0, 0.0), outer_cone=0.0, area_size=(0.0, 0.0), source_power=0.0,
            source_exposure=0.0, local_transform_rows=IDENTITY_ROWS,
        ),
    )

    camera_writer = u.BinaryWriter()
    u.write_camera_record(
        camera_writer,
        u.CameraRecord(
            entity_id=1, name_offset=camera_name_off, flags=0, position=(0.0, 0.0, 0.0),
            forward=(0.0, 0.0, -1.0), up=(0.0, 1.0, 0.0), right=(1.0, 0.0, 0.0),
            fov_y_degrees=60.0, near_clip=0.1, far_clip=100.0, aspect_ratio=1.0,
            local_transform_rows=IDENTITY_ROWS,
        ),
    )

    color_writer = u.BinaryWriter()
    u.write_color_management_record(
        color_writer,
        u.ColorManagementRecord(
            lut_texture_index=0,
            view_transform_name_offset=view_name_off,
            look_name_offset=look_name_off,
            exposure=0.0,
            gamma=1.0,
            shaper_min_stops=-10.0,
            shaper_max_stops=6.0,
            lut_size=32,
        ),
    )

    chunk_payloads = [
        (u.CHUNK_TYPES["string_table"], strings.data, 0),
        (u.CHUNK_TYPES["texture_table"], texture_writer.data, 1),
        (u.CHUNK_TYPES["light_table"], light_writer.data, 1),
        (u.CHUNK_TYPES["camera_table"], camera_writer.data, 1),
        (u.CHUNK_TYPES["color_management_table"], color_writer.data, 1),
    ]

    header_writer = u.BinaryWriter()
    u.write_header(
        header_writer,
        file_type=u.FILE_TYPES["tile"],
        chunk_count=len(chunk_payloads),
        mesh_count=0, material_count=0, texture_count=1, entity_count=0,
        world_bounds=u.AABB((0.0, 0.0, 0.0), (0.0, 0.0, 0.0)),
        root_transform_rows=IDENTITY_ROWS,
        content_hash=b"\x00" * 32,
    )
    header_bytes = header_writer.data
    chunk_table_size = len(chunk_payloads) * u.CHUNK_ENTRY_SIZE
    body_start = u.align(len(header_bytes) + chunk_table_size, u.FILE_ALIGNMENT)

    body = bytearray()
    entries = []
    for chunk_type, payload, count in chunk_payloads:
        while len(body) % u.FILE_ALIGNMENT:
            body.append(0)
        entries.append((chunk_type, body_start + len(body), len(payload), count))
        body += payload

    chunk_table_writer = u.BinaryWriter()
    for chunk_type, offset, size, count in entries:
        u.write_chunk_entry(
            chunk_table_writer, chunk_type=chunk_type, compression_type=u.COMPRESSION_NONE,
            file_offset=offset, compressed_size=size, uncompressed_size=size, element_count=count,
        )

    file_bytes = bytearray(header_bytes)
    file_bytes += chunk_table_writer.data
    while len(file_bytes) < body_start:
        file_bytes.append(0)
    file_bytes += body

    output_path = tmpdir / "scene.untold"
    output_path.write_bytes(bytes(file_bytes))
    return output_path


def _read_string_at(data: bytes, string_table: bytes, offset: int) -> str:
    end = string_table.index(b"\x00", offset)
    return string_table[offset:end].decode("utf-8")


class TexbakePatchRefsTests(unittest.TestCase):
    def test_patch_refs_remaps_light_and_camera_name_offsets(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir_str:
            tmpdir = Path(tmpdir_str)
            untold_path = _build_minimal_untold_file(tmpdir)

            t.patch_refs(untold_path)

            data = untold_path.read_bytes()
            version, file_type, _res, header_size, chunk_count = struct.unpack_from("<5I", data, 8)
            chunks = {}
            off = header_size
            for _ in range(chunk_count):
                ctype, _comp, foff, csize, _usize, count, _reserved = struct.unpack_from("<IIQQQII", data, off)
                chunks[ctype] = (foff, csize, count)
                off += 40

            str_off, str_size, _ = chunks[u.CHUNK_TYPES["string_table"]]
            string_table = data[str_off:str_off + str_size]

            tex_off, _, tex_count = chunks[u.CHUNK_TYPES["texture_table"]]
            self.assertEqual(tex_count, 1)
            uri_offset = struct.unpack_from("<I", data, tex_off + 4)[0]
            self.assertEqual(_read_string_at(data, string_table, uri_offset), "Textures/wall.utex")

            light_off, _, light_count = chunks[u.CHUNK_TYPES["light_table"]]
            self.assertEqual(light_count, 1)
            light_name_offset = struct.unpack_from("<I", data, light_off + 4)[0]
            self.assertEqual(_read_string_at(data, string_table, light_name_offset), "日光")

            camera_off, _, camera_count = chunks[u.CHUNK_TYPES["camera_table"]]
            self.assertEqual(camera_count, 1)
            camera_name_offset = struct.unpack_from("<I", data, camera_off + 4)[0]
            self.assertEqual(_read_string_at(data, string_table, camera_name_offset), "摄像机")

            color_off, _, color_count = chunks[u.CHUNK_TYPES["color_management_table"]]
            self.assertEqual(color_count, 1)
            view_offset, look_offset = struct.unpack_from("<II", data, color_off + 4)
            self.assertEqual(_read_string_at(data, string_table, view_offset), "AgX")
            self.assertEqual(_read_string_at(data, string_table, look_offset), "Medium High Contrast")

    def test_lut_slot_maps_to_uncompressed_rgba16float(self) -> None:
        config = t._SLOT_CONFIG["lut"]
        self.assertEqual(config.encoding, "rgba16f")
        self.assertEqual(config.pixel_format, t.MTL_RGBA16_FLOAT)
        self.assertEqual(t._untold_format_for_config(config), t._UNTOLD_FORMAT_RGBA16_FLOAT)

    def test_height_slot_maps_to_uncompressed_r16unorm(self) -> None:
        config = t._SLOT_CONFIG["height"]
        self.assertEqual(config.encoding, "r16")
        self.assertEqual(config.pixel_format, t.MTL_R16_UNORM)
        self.assertEqual(t._untold_format_for_config(config), t._UNTOLD_FORMAT_R16_UNORM)


class TexbakeSlotDetectionTests(unittest.TestCase):
    def test_detect_slot_routes_displacement_keywords_to_height(self) -> None:
        for name in ("Poliigon_BrickWallThin_11512_Displacement", "wall_height", "height_map", "rock_disp"):
            with self.subTest(name=name):
                self.assertEqual(t.detect_slot(Path(f"{name}.tiff")), "height")

    def test_detect_slot_routes_bump_keywords_to_height_not_normal(self) -> None:
        for name in ("metal_bump", "bump_metal"):
            with self.subTest(name=name):
                self.assertEqual(t.detect_slot(Path(f"{name}.png")), "height")

    def test_detect_slot_still_routes_normal_keywords_to_normal(self) -> None:
        self.assertEqual(t.detect_slot(Path("wall_normal.png")), "normal")

    def test_slot_from_texture_flags_routes_height_flag(self) -> None:
        self.assertEqual(t._slot_from_texture_flags(t._UNTOLD_TEX_FLAG_HEIGHT), "height")

    def test_slot_from_texture_flags_returns_none_when_no_flag_set(self) -> None:
        self.assertIsNone(t._slot_from_texture_flags(0))


if __name__ == "__main__":
    unittest.main()
