"""Blender-side numerical golden test for Untold color-management LUTs.

Run through Blender, not regular Python:
  blender --background --factory-startup --python scripts/tests/blender_color_management_golden.py
"""

from __future__ import annotations

import json
import math
import random
import sys
import tempfile
from pathlib import Path

import bpy

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import untoldexplorer as u


def linear_to_srgb(value: float) -> float:
    value = max(value, 0.0)
    if value <= 0.0031308:
        return value * 12.92
    return 1.055 * (value ** (1.0 / 2.4)) - 0.055


def perceptual_luma_ssim(
    reference: list[tuple[float, float, float]],
    candidate: list[tuple[float, float, float]],
) -> float:
    """Global SSIM over display-encoded luminance for the synthetic HDR image."""
    if len(reference) != len(candidate) or not reference:
        raise ValueError("SSIM inputs must have the same non-zero length")

    def luminance(pixel: tuple[float, float, float]) -> float:
        encoded = tuple(linear_to_srgb(channel) for channel in pixel)
        return 0.2126 * encoded[0] + 0.7152 * encoded[1] + 0.0722 * encoded[2]

    x = [luminance(pixel) for pixel in reference]
    y = [luminance(pixel) for pixel in candidate]
    mean_x = sum(x) / len(x)
    mean_y = sum(y) / len(y)
    variance_x = sum((value - mean_x) ** 2 for value in x) / len(x)
    variance_y = sum((value - mean_y) ** 2 for value in y) / len(y)
    covariance = sum(
        (x[index] - mean_x) * (y[index] - mean_y)
        for index in range(len(x))
    ) / len(x)
    c1 = 0.01 ** 2
    c2 = 0.03 ** 2
    return (
        (2.0 * mean_x * mean_y + c1)
        * (2.0 * covariance + c2)
        / ((mean_x * mean_x + mean_y * mean_y + c1) * (variance_x + variance_y + c2))
    )


def transform_samples_with_blender(
    samples: list[tuple[float, float, float]],
    output_dir: Path,
) -> list[tuple[float, float, float]]:
    scene = bpy.context.scene
    display = scene.display_settings
    image_settings = scene.render.image_settings
    saved = (
        display.display_device,
        scene.render.dither_intensity,
        image_settings.file_format,
        image_settings.color_depth,
        image_settings.color_mode,
        getattr(image_settings, "color_management", None),
    )
    image = bpy.data.images.new(
        "untold_color_golden_samples",
        width=len(samples),
        height=1,
        float_buffer=True,
        alpha=True,
    )
    path = output_dir / "golden_samples.png"
    try:
        display.display_device = "sRGB"
        scene.render.dither_intensity = 0.0
        image_settings.file_format = "PNG"
        image_settings.color_depth = "16"
        image_settings.color_mode = "RGBA"
        if hasattr(image_settings, "color_management"):
            image_settings.color_management = "FOLLOW_SCENE"
        pixels: list[float] = []
        for red, green, blue in samples:
            pixels.extend((red, green, blue, 1.0))
        image.pixels = pixels
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save_render(str(path), scene=scene)
    finally:
        (
            display.display_device,
            scene.render.dither_intensity,
            image_settings.file_format,
            image_settings.color_depth,
            image_settings.color_mode,
            saved_output_color_management,
        ) = saved
        if saved_output_color_management is not None:
            image_settings.color_management = saved_output_color_management
        bpy.data.images.remove(image)

    reloaded = bpy.data.images.load(str(path))
    try:
        reloaded.colorspace_settings.name = "sRGB"
        transformed = list(reloaded.pixels)
    finally:
        bpy.data.images.remove(reloaded)
    return [
        tuple(transformed[index + channel] for channel in range(3))
        for index in range(0, len(transformed), 4)
    ]


def main() -> None:
    scene = bpy.context.scene
    try:
        scene.view_settings.view_transform = "AgX"
    except Exception:
        # Custom OCIO configurations may not expose AgX. The test still
        # validates their active smooth display transform.
        pass

    randomizer = random.Random(0x554E544F4C44)
    samples: list[tuple[float, float, float]] = []
    image_sample_count = 64 * 32
    for _ in range(image_sample_count):
        samples.append(
            tuple(
                u._LUT_SHAPER_MIDDLE_GRAY
                * (2.0 ** randomizer.uniform(u._LUT_SHAPER_MIN_STOPS, u._LUT_SHAPER_MAX_STOPS))
                for _ in range(3)
            )
        )
    for stop in range(-10, 7):
        value = u._LUT_SHAPER_MIDDLE_GRAY * (2.0 ** stop)
        samples.append((value, value, value))

    # Exercise every atlas slice boundary explicitly, on both sides and
    # exactly at the grid point. Random sampling alone can miss a flipped row
    # or a cross-tile interpolation seam.
    base = (
        u._lut_shaper_decode(0.23),
        u._lut_shaper_decode(0.51),
        u._lut_shaper_decode(0.77),
    )
    for axis in range(3):
        for grid_index in range(1, 31):
            grid_t = grid_index / 31.0
            for delta in (-1.0e-5, 0.0, 1.0e-5):
                color = list(base)
                color[axis] = u._lut_shaper_decode(grid_t + delta)
                samples.append(tuple(color))

    with tempfile.TemporaryDirectory(prefix="untold_color_golden_") as directory:
        output_dir = Path(directory)
        bake = u.bake_color_management_lut(32, output_dir)
        width, height, pixels = u.decode_rgba16f_utex_bytes(bake.lut_texture.source_path.read_bytes())
        assert width == bake.lut_size * bake.lut_size
        assert height == bake.lut_size

        expected = transform_samples_with_blender(samples, output_dir)
        actual = [
            u.sample_color_lut_pixels(pixels, bake.lut_size, sample)
            for sample in samples
        ]

    errors = [
        abs(actual[index][channel] - expected[index][channel])
        for index in range(len(samples))
        for channel in range(3)
    ]
    mean_error = sum(errors) / len(errors)
    max_error = max(errors)
    image_expected = expected[:image_sample_count]
    image_actual = actual[:image_sample_count]
    image_ssim = perceptual_luma_ssim(image_expected, image_actual)
    encoded_squared_errors = [
        (
            linear_to_srgb(actual[index][channel])
            - linear_to_srgb(expected[index][channel])
        ) ** 2
        for index in range(image_sample_count)
        for channel in range(3)
    ]
    image_srgb_rmse = math.sqrt(sum(encoded_squared_errors) / len(encoded_squared_errors))
    result = {
        "blender_version": bpy.app.version_string,
        "view_transform": scene.view_settings.view_transform,
        "sample_count": len(samples),
        "synthetic_hdr_image_size": [64, 32],
        "mean_absolute_linear_error": mean_error,
        "max_absolute_linear_error": max_error,
        "perceptual_luma_ssim": image_ssim,
        "image_srgb_rmse": image_srgb_rmse,
    }
    print("UNTOLD_COLOR_GOLDEN " + json.dumps(result, sort_keys=True))
    if mean_error > 0.008 or max_error > 0.05 or image_ssim < 0.995:
        raise AssertionError(
            "Color LUT error exceeded budget: "
            f"mean={mean_error:.6f}, max={max_error:.6f}, SSIM={image_ssim:.6f}"
        )


if __name__ == "__main__":
    main()
