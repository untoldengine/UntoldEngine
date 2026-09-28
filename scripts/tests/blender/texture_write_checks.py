# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Checks for texture writing that need a real Blender.

They are kept out of `make testexporter`, which runs without Blender. Run them from
the repository root:

    blender --background --factory-startup --python-exit-code 1 \
        --python scripts/tests/blender/texture_write_checks.py

Every image is made by the checks themselves, in a temporary folder.
"""

import struct
import sys
import tempfile
import unittest
from array import array
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parents[2]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import untoldexplorer as u


SIZE = 16
HEADER_ONLY_PNG = bytes.fromhex("89504e470d0a1a0a0000000d49484452000008000000080008020000003dc54467")
# The comment Blender's JPEG writer leaves in a file it saved from a source with an
# embedded ICC profile. Read back, it becomes a metadata entry named "ICCProfile".
ICC_PROFILE_COMMENT = b"Blender:ICCProfile:copyright:No copyright, use freely"


def gradient_pixels(width: int, height: int) -> array:
    pixels = array("f", bytes(4 * width * height * 4))
    for y in range(height):
        for x in range(width):
            offset = (y * width + x) * 4
            pixels[offset] = x / (width - 1)
            pixels[offset + 1] = y / (height - 1)
            pixels[offset + 2] = ((x + y) % 5) / 4
            pixels[offset + 3] = 1.0 if (x + y) % 2 else 0.25
    return pixels


def write_source_image(path: Path, *, file_format: str, color_depth: str = "8", color_mode: str = "RGB") -> None:
    """Write a gradient to path as a plain image file of the given kind, with no metadata."""
    image = bpy.data.images.new("source", SIZE, SIZE, alpha=True, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(gradient_pixels(SIZE, SIZE))
    scene = bpy.context.scene
    settings = scene.render.image_settings
    saved = (settings.file_format, settings.color_depth, settings.color_mode)
    saved_color_management = u._set_scene_color_management_raw(scene)
    try:
        settings.file_format = file_format
        settings.color_depth = color_depth
        settings.color_mode = color_mode
        image.save_render(str(path), scene=scene)
    finally:
        u._restore_scene_color_management(scene, saved_color_management)
        settings.file_format, settings.color_depth, settings.color_mode = saved
        bpy.data.images.remove(image)


def add_jpeg_comment(path: Path, comment: bytes) -> None:
    """Insert a COM segment after the first segment of a JPEG file."""
    data = path.read_bytes()
    assert data[:2] == b"\xff\xd8", "not a JPEG file"
    first_segment_end = 4 + struct.unpack(">H", data[4:6])[0]
    segment = b"\xff\xfe" + struct.pack(">H", len(comment) + 2) + comment
    path.write_bytes(data[:first_segment_end] + segment + data[first_segment_end:])


def load_image(path: Path, colorspace: str) -> object:
    image = bpy.data.images.load(str(path))
    image.colorspace_settings.name = colorspace
    return image


def decoded_pixels(path: Path) -> array:
    image = load_image(path, "Non-Color")
    try:
        pixels = array("f", bytes(4 * image.size[0] * image.size[1] * image.channels))
        image.pixels.foreach_get(pixels)
        return pixels
    finally:
        bpy.data.images.remove(image)


class FailFirstSave:
    """Replaces _save_blender_image to fail its first call the way Blender's PNG writer
    does on bad metadata: the header is on disk by the time the error is raised."""

    def __init__(self) -> None:
        self.real_save = u._save_blender_image
        self.calls = 0

    def __call__(self, image: object, destination_path: Path, **arguments) -> None:
        self.calls += 1
        if self.calls == 1:
            destination_path.write_bytes(HEADER_ONLY_PNG)
            raise RuntimeError("Error: Could not write image: forced failure of the first attempt")
        self.real_save(image, destination_path, **arguments)


class TextureWriteChecks(unittest.TestCase):
    def setUp(self) -> None:
        self.tmpdir = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmpdir.name)
        self.images_before = set(bpy.data.images.keys())
        u._images_written_from_copy.clear()

    def tearDown(self) -> None:
        for name in set(bpy.data.images.keys()) - self.images_before:
            bpy.data.images.remove(bpy.data.images[name])
        self.tmpdir.cleanup()

    def assert_no_copy_left(self) -> None:
        leftover = [name for name in bpy.data.images.keys() if name.endswith(".untold_export")]
        self.assertEqual(leftover, [], "the metadata-free copy must be removed from the .blend data")

    def test_jpeg_with_icc_profile_comment_is_exported(self) -> None:
        """The scene that brought this up: a packed JPEG normal map whose source file is gone."""
        source_path = self.folder / "floor_normal.jpg"
        write_source_image(source_path, file_format="JPEG")
        clean_path = self.folder / "floor_normal_clean.jpg"
        clean_path.write_bytes(source_path.read_bytes())
        add_jpeg_comment(source_path, ICC_PROFILE_COMMENT)

        image = load_image(source_path, "Non-Color")
        image.pack()
        source_path.unlink()
        clean_image = load_image(clean_path, "Non-Color")

        # Not an assertion: a Blender that no longer trips over the comment is fine too.
        probe_path = self.folder / "probe.png"
        original = (image.filepath_raw, image.file_format)
        try:
            image.filepath_raw, image.file_format = str(probe_path), "PNG"
            image.save()
            print("  note: this Blender saves the image with the ICCProfile comment by itself")
        except RuntimeError:
            self.assertEqual(probe_path.read_bytes()[:16], HEADER_ONLY_PNG[:16], "expected the header-only file")
        finally:
            image.filepath_raw, image.file_format = original
            probe_path.unlink(missing_ok=True)

        exported = self.folder / "Textures" / "floor_normal.png"
        u.write_blender_image_to_path(image.name, exported)
        expected = self.folder / "Textures" / "floor_normal_clean.png"
        u.write_blender_image_to_path(clean_image.name, expected)

        self.assertTrue(u._png_is_complete(exported))
        self.assertEqual(u._png_ihdr(exported), u._png_ihdr(expected))
        self.assertEqual(decoded_pixels(exported), decoded_pixels(expected))
        self.assertEqual((image.filepath_raw, image.file_format), original)
        self.assert_no_copy_left()

    def write_with_first_attempt_failing(self, image: object, destination: Path) -> FailFirstSave:
        fail_first_save = FailFirstSave()
        u._save_blender_image = fail_first_save
        try:
            u.write_blender_image_to_path(image.name, destination)
        finally:
            u._save_blender_image = fail_first_save.real_save
        return fail_first_save

    def check_copy_matches_ordinary_write(
        self,
        image: object,
        *,
        ordinary_ihdr: tuple[int, int],
        copy_ihdr: tuple[int, int],
    ) -> None:
        """The file written from the metadata-free copy must hold the pixels that the
        ordinary write holds."""
        ordinary = self.folder / "ordinary.png"
        from_copy = self.folder / "from_copy.png"

        u.write_blender_image_to_path(image.name, ordinary)
        fail_first_save = self.write_with_first_attempt_failing(image, from_copy)

        self.assertEqual(fail_first_save.calls, 2, "the second attempt must have been made")
        self.assertTrue(u._png_is_complete(ordinary))
        self.assertTrue(u._png_is_complete(from_copy))
        self.assertEqual(u._png_ihdr(ordinary), ordinary_ihdr)
        self.assertEqual(u._png_ihdr(from_copy), copy_ihdr)
        self.assertEqual(decoded_pixels(from_copy), decoded_pixels(ordinary))
        self.assert_no_copy_left()

    def test_copy_of_rgb_jpeg(self) -> None:
        path = self.folder / "color.jpg"
        write_source_image(path, file_format="JPEG")
        self.check_copy_matches_ordinary_write(load_image(path, "sRGB"), ordinary_ihdr=(8, 2), copy_ihdr=(8, 2))

    def test_copy_of_rgba_png(self) -> None:
        path = self.folder / "color_alpha.png"
        write_source_image(path, file_format="PNG", color_mode="RGBA")
        self.check_copy_matches_ordinary_write(load_image(path, "sRGB"), ordinary_ihdr=(8, 6), copy_ihdr=(8, 6))

    def test_copy_of_gray_png_is_converted_to_rgb_like_its_source(self) -> None:
        for colorspace in ("Non-Color", "sRGB"):
            with self.subTest(colorspace=colorspace):
                path = self.folder / f"gray_{colorspace}.png"
                write_source_image(path, file_format="PNG", color_mode="BW")
                self.check_copy_matches_ordinary_write(
                    load_image(path, colorspace), ordinary_ihdr=(8, 2), copy_ihdr=(8, 2)
                )

    def test_copy_of_packed_gray_jpeg_holds_the_same_pixels_as_rgb(self) -> None:
        """Without a source file to inspect, a gray JPEG is written as it is: a gray PNG.
        The copy is RGB, as every new image, with the gray value in all three channels."""
        path = self.folder / "gray.jpg"
        write_source_image(path, file_format="JPEG", color_mode="BW")
        image = load_image(path, "Non-Color")
        image.pack()
        path.unlink()
        self.check_copy_matches_ordinary_write(image, ordinary_ihdr=(8, 0), copy_ihdr=(8, 2))

    def test_16_bit_image_is_reported_rather_than_copied(self) -> None:
        """A copy of a float buffer is not written back the way its source is, so no
        second attempt is made for one: the texture is reported, and no file is left."""
        path = self.folder / "color_16.png"
        write_source_image(path, file_format="PNG", color_depth="16")
        image = load_image(path, "sRGB")
        destination = self.folder / "Textures" / "color_16.png"

        with self.assertRaises(u.TextureWriteError):
            self.write_with_first_attempt_failing(image, destination)

        self.assertFalse(destination.exists())
        self.assert_no_copy_left()


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TextureWriteChecks)
    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
