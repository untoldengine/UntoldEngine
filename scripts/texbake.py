#!/usr/bin/env python3

# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
texbake.py — Offline texture baker for the UntoldEngine native asset pipeline.

Converts PNG/JPEG/TGA source textures to the engine-native .utex container format
using ASTC block compression for material textures. Color LUTs use uncompressed
RGBA16Float. Run this as a post-export step after export-untold or
export-untold-tiles has produced a textures/ directory.

Requirements:
    Run `untoldengine bootstrap` to install Pillow, lz4, and astcenc automatically.
    Or install manually:
      pip install Pillow lz4
      Download astcenc from https://github.com/ARM-software/astc-encoder/releases
      and set ASTCENC_BIN=/full/path/to/astcenc

Usage (single file):
    python scripts/texbake.py --input textures/wall_basecolor.png --slot base_color

Usage (single file, auto-detect slot from filename):
    python scripts/texbake.py --input textures/wall_normal.png

Usage (batch directory, auto-detect slots):
    python scripts/texbake.py --dir build/textures/

Options:
    --input PATH       Source image file (PNG, JPEG, TGA)
    --output PATH      Output .utex path (default: same location as input, .utex extension)
    --slot SLOT        Texture slot. One of:
                           base_color, emissive, normal, roughness, metallic,
                           occlusion, orm, opacity, data, lut
    --quality LEVEL    astcenc quality level: fastest, fast, medium, thorough, exhaustive
                       (default: thorough)
    --dir PATH         Batch mode: convert all supported images in this directory
    --keep-temp        Do not delete intermediate per-mip PNG and .astc files

Texture slot → ASTC format mapping:
    Slot          sRGB    Block   MTLPixelFormat
    ─────────── ──────── ─────── ───────────────────────────────────
    base_color   yes      4×4    186  (astc_4x4_sRGB)
    emissive     yes      4×4    186  (astc_4x4_sRGB)
    normal       no       4×4    204  (astc_4x4_ldr, `-normal -perceptual` encode — see below)
    roughness    no       6×6    208  (astc_6x6_ldr)
    metallic     no       6×6    208  (astc_6x6_ldr)
    occlusion    no       6×6    208  (astc_6x6_ldr)
    orm          no       6×6    208  (astc_6x6_ldr)
    opacity      no       4×4    204  (astc_4x4_ldr)
    data         no       4×4    204  (astc_4x4_ldr)  ← default for unrecognised slots
    lut          no       1×1    115  (rgba16Float, uncompressed, one mip)

Normal map encoding:
    Normal maps are compressed with astcenc's `-normal -perceptual` mode instead of
    generic RGB compression. `-normal` re-weights the ASTC error metric for unit-vector
    data (RGB color compression perceptually favors green, which is the wrong tradeoff
    for X/Y/Z surface vectors) and repacks the map as a 2-component X+Y map — stored as
    (RGB=X, A=Y) — with Z reconstructed at sample time. FLAG_NORMAL_PACKED_XY is set in
    the .utex header so the engine's shaders know to reconstruct Z instead of reading it
    directly; see the decode in modelShader.metal / TransparencyShader.metal.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

try:
    from PIL import Image
    _HAS_PILLOW = True
except ImportError:
    Image = None
    _HAS_PILLOW = False

try:
    import lz4.block as _lz4_block
    _HAS_LZ4 = True
except ImportError:
    _lz4_block = None
    _HAS_LZ4 = False

# ──────────────────────────────────────────────
# .utex format constants  (mirrors NativeTexFormat.swift)
# ──────────────────────────────────────────────

UTEX_MAGIC = b"UTEX\x00\x00\x00\x00"
UTEX_VERSION = 1
UTEX_HEADER_SIZE = 64
UTEX_MIP_ENTRY_SIZE = 16
UTEX_PAYLOAD_ALIGNMENT = 16

# Header struct:  8s I I I I I I B B 2x I I 5I
# Sizes:          8  4 4 4 4 4 4 1 1 2  4 4 20  = 64 bytes
_HEADER_FMT = "<8sIIIIIIBBxxII5I"
assert struct.calcsize(_HEADER_FMT) == UTEX_HEADER_SIZE

# Mip entry:  I I I I  = 16 bytes
_MIP_ENTRY_FMT = "<IIII"
assert struct.calcsize(_MIP_ENTRY_FMT) == UTEX_MIP_ENTRY_SIZE

# MTLPixelFormat raw values for ASTC formats on Apple Silicon / iOS.
# Source: Metal framework headers.
MTL_ASTC_4X4_SRGB = 186
MTL_ASTC_5X5_SRGB = 188
MTL_ASTC_6X6_SRGB = 190
MTL_ASTC_8X8_SRGB = 194
MTL_ASTC_4X4_LDR = 204
MTL_ASTC_5X5_LDR = 206
MTL_ASTC_6X6_LDR = 208
MTL_ASTC_8X8_LDR = 212
MTL_RGBA16_FLOAT = 115
# Single-channel, 16-bit, linear, uncompressed — height/displacement map data. Bypasses
# ASTC deliberately: block compression's stepping artifacts are especially visible when
# the height field is ray-marched per-pixel (POM), and most source displacement maps are
# already single-channel grayscale where RGBA conversion + block compression only wastes
# precision without any benefit. See docs/proposals/HeightMapParallaxOcclusionMapping.md.
MTL_R16_UNORM = 20

# Flags (matches NativeTexFlags in Swift)
FLAG_HAS_ALPHA = 1 << 0
FLAG_PREMULTIPLIED_ALPHA = 1 << 1
# Normal map was compressed with astcenc's `-normal` mode: RGB=X (duplicated across
# R/G/B), A=Y, Z reconstructed in-shader. See modelShader.metal / TransparencyShader.metal.
FLAG_NORMAL_PACKED_XY = 1 << 2

# KHR ASTC container magic (16-byte header produced by astcenc)
_ASTC_MAGIC = b"\x13\xab\xa1\x5c"

# ──────────────────────────────────────────────
# Per-slot configuration
# ──────────────────────────────────────────────

@dataclass(frozen=True)
class SlotConfig:
    srgb: bool
    block_size: str    # e.g. "4x4"
    block_w: int
    block_h: int
    pixel_format: int  # MTLPixelFormat raw value
    generate_mips: bool = True  # LUT strips must never be mip-filtered — see "lut" slot below.
    encoding: str = "astc"


_SLOT_CONFIG: dict[str, SlotConfig] = {
    "base_color": SlotConfig(srgb=True,  block_size="4x4", block_w=4, block_h=4, pixel_format=MTL_ASTC_4X4_SRGB),
    "emissive":   SlotConfig(srgb=True,  block_size="4x4", block_w=4, block_h=4, pixel_format=MTL_ASTC_4X4_SRGB),
    "normal":     SlotConfig(srgb=False, block_size="4x4", block_w=4, block_h=4, pixel_format=MTL_ASTC_4X4_LDR),
    "roughness":  SlotConfig(srgb=False, block_size="6x6", block_w=6, block_h=6, pixel_format=MTL_ASTC_6X6_LDR),
    "metallic":   SlotConfig(srgb=False, block_size="6x6", block_w=6, block_h=6, pixel_format=MTL_ASTC_6X6_LDR),
    "occlusion":  SlotConfig(srgb=False, block_size="6x6", block_w=6, block_h=6, pixel_format=MTL_ASTC_6X6_LDR),
    "orm":        SlotConfig(srgb=False, block_size="6x6", block_w=6, block_h=6, pixel_format=MTL_ASTC_6X6_LDR),
    "opacity":    SlotConfig(srgb=False, block_size="4x4", block_w=4, block_h=4, pixel_format=MTL_ASTC_4X4_LDR),
    "data":       SlotConfig(srgb=False, block_size="4x4", block_w=4, block_h=4, pixel_format=MTL_ASTC_4X4_LDR),
    # LUTs remain uncompressed RGBA16Float. ASTC errors become color-transform
    # errors and are especially visible in dark gradients.
    "lut":        SlotConfig(srgb=False, block_size="1x1", block_w=1, block_h=1, pixel_format=MTL_RGBA16_FLOAT, generate_mips=False, encoding="rgba16f"),
    # Height/displacement maps stay uncompressed single-channel R16Unorm — see MTL_R16_UNORM.
    "height":     SlotConfig(srgb=False, block_size="1x1", block_w=1, block_h=1, pixel_format=MTL_R16_UNORM, generate_mips=True, encoding="r16"),
}

SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".tga", ".bmp"}

# ──────────────────────────────────────────────
# Slot auto-detection from filename
# ──────────────────────────────────────────────

def detect_slot(path: Path) -> str:
    """Infer texture slot from filename keywords. Returns 'data' if unrecognised."""
    stem = path.stem.lower()
    if any(k in stem for k in ("basecolor", "base_color", "albedo", "diffuse", "colour", "color")):
        return "base_color"
    if any(k in stem for k in ("emissive", "emission", "_emit", "emit_")):
        return "emissive"
    if any(k in stem for k in ("normal", "_nrm", "nrm_", "_nml", "nml_")):
        return "normal"
    if any(k in stem for k in ("height", "displacement", "_disp", "disp_", "_bump", "bump_")):
        return "height"
    if any(k in stem for k in ("roughness", "_rough", "rough_")):
        return "roughness"
    if any(k in stem for k in ("metallic", "_metal", "metal_", "metalness")):
        return "metallic"
    if any(k in stem for k in ("occlusion", "_ao_", "_ao", "ao_", "ambient")):
        return "occlusion"
    if any(k in stem for k in ("_orm", "orm_")):
        return "orm"
    if any(k in stem for k in ("opacity", "_alpha", "alpha_", "_mask", "mask_")):
        return "opacity"
    return "data"


def _slot_from_texture_flags(flags: int) -> str | None:
    """Map .untold texture record flags (field index 3) to a texbake slot name.

    The exporter sets these flags at export time from material slot information,
    so they are authoritative even when the filename has no recognisable keywords
    (e.g. "SimpleDungeonTexture" → TEXTURE_FLAG_SRGB → "base_color").

    Returns None when no slot-relevant flag is set; caller should fall back to
    detect_slot() in that case.
    """
    if flags & _UNTOLD_TEX_FLAG_LUT:
        return "lut"
    if flags & _UNTOLD_TEX_FLAG_HEIGHT:
        return "height"
    if flags & _UNTOLD_TEX_FLAG_NORMAL_MAP:
        return "normal"
    if flags & _UNTOLD_TEX_FLAG_EMISSIVE:
        return "emissive"
    if flags & _UNTOLD_TEX_FLAG_OCCLUSION:
        return "occlusion"
    if flags & _UNTOLD_TEX_FLAG_SRGB:
        return "base_color"
    return None

# ──────────────────────────────────────────────
# Mip chain generation
# ──────────────────────────────────────────────

def mip_count_for(width: int, height: int) -> int:
    """Number of mip levels for a texture of the given base dimensions."""
    return int(math.floor(math.log2(max(width, height)))) + 1


def generate_mip_chain(img: "Image.Image") -> list["Image.Image"]:
    """
    Return a list of PIL Images from mip 0 (full-res) down to mip N (1×1 or smallest).
    Downsampling uses LANCZOS in the encoded gamma space, which is the standard
    approach. For sRGB textures this introduces a small linearisation error at mip
    boundaries; acceptable for production game content.
    """
    # Ensure RGBA so the ASTC encoder always receives a 4-channel input.
    img = img.convert("RGBA")
    base_w, base_h = img.size
    levels = mip_count_for(base_w, base_h)
    mips: list[Image.Image] = [img]
    for level in range(1, levels):
        w = max(1, base_w >> level)
        h = max(1, base_h >> level)
        mips.append(mips[0].resize((w, h), Image.LANCZOS))
    return mips

# ──────────────────────────────────────────────
# ASTC compression via astcenc
# ──────────────────────────────────────────────

def find_astcenc() -> str:
    """
    Locate the astcenc binary. Tries an explicit env var, the location
    `untoldengine bootstrap` installs to, a shared Tools folder, then common
    names on PATH.
    Returns the binary name/path if found, raises RuntimeError otherwise.
    """
    env_override = os.environ.get("ASTCENC_BIN")
    if env_override:
        astcenc_path = Path(env_override).expanduser()
        if astcenc_path.is_file() and os.access(astcenc_path, os.X_OK):
            return str(astcenc_path)

    untoldengine_home = os.environ.get("UNTOLDENGINE_HOME")
    home_root = Path(untoldengine_home).expanduser() if untoldengine_home else Path.home() / ".untoldengine"
    bootstrap_candidate = home_root / "tools" / "astcenc" / "astcenc"
    if bootstrap_candidate.is_file() and os.access(bootstrap_candidate, os.X_OK):
        return str(bootstrap_candidate)

    repo_root = Path(__file__).resolve().parents[1]
    shared_tools_candidate = repo_root.parent / "Tools" / "astcenc" / "astcenc"
    if shared_tools_candidate.is_file() and os.access(shared_tools_candidate, os.X_OK):
        return str(shared_tools_candidate)

    candidates = ["astcenc", "astcenc-native", "astcenc-avx2", "astcenc-sse4.2"]
    for name in candidates:
        if shutil.which(name):
            return name
    raise RuntimeError(
        "astcenc not found.\n"
        "Run:  untoldengine bootstrap\n"
        "Or set ASTCENC_BIN=/full/path/to/astcenc\n"
        f"Or place it at:  {bootstrap_candidate}\n"
        "Download it from:  https://github.com/ARM-software/astc-encoder/releases"
    )


def compress_mip_to_astc(
    astcenc_bin: str,
    mip_img: "Image.Image",
    block_size: str,
    quality: str,
    srgb: bool,
    tmp_dir: Path,
    label: str,
    extra_args: list[str] | None = None,
) -> bytes:
    """
    Compress a single PIL Image to raw ASTC block bytes.
    Returns only the block payload (strips the 16-byte KHR ASTC container header).

    extra_args: additional astcenc CLI options appended after the required
    profile/input/output/blocksize/quality arguments (e.g. ["-normal", "-perceptual"]
    for normal maps — see astcenc's -normal mode, which re-weights the error metric
    for unit-vector data instead of the default RGB-luminance weighting, and packs
    the map as a 2-component X+Y map with Z reconstructed in-shader).
    """
    input_png = tmp_dir / f"{label}.png"
    output_astc = tmp_dir / f"{label}.astc"

    mip_img.save(str(input_png))

    # astcenc v4+ flags: -cs for sRGB encode, -cl for linear (LDR) encode
    encode_flag = "-cs" if srgb else "-cl"

    cmd = [
        astcenc_bin,
        encode_flag,
        str(input_png),
        str(output_astc),
        block_size,
        f"-{quality}",
    ]
    if extra_args:
        cmd.extend(extra_args)

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"astcenc failed for {label}:\n{result.stdout}\n{result.stderr}"
        )

    raw = output_astc.read_bytes()

    # Validate and strip the 16-byte KHR ASTC container header
    if len(raw) < 16:
        raise RuntimeError(f"astcenc output is unexpectedly short for {label}")
    if raw[:4] != _ASTC_MAGIC:
        raise RuntimeError(f"astcenc output has unexpected magic bytes for {label}")

    return raw[16:]  # raw ASTC block data only

# ──────────────────────────────────────────────
# Expected block payload sizes (for validation)
# ──────────────────────────────────────────────

def expected_block_bytes(width: int, height: int, block_w: int, block_h: int) -> int:
    """
    Compute the expected byte count for an ASTC-compressed mip level.
    Each ASTC block is always 16 bytes regardless of block dimensions.
    """
    blocks_wide = math.ceil(width / block_w)
    blocks_high = math.ceil(height / block_h)
    return blocks_wide * blocks_high * 16

# ──────────────────────────────────────────────
# .utex writer
# ──────────────────────────────────────────────

def align_up(value: int, alignment: int) -> int:
    remainder = value % alignment
    return value if remainder == 0 else value + (alignment - remainder)


def write_utex(
    output_path: Path,
    mip_payloads: list[bytes],
    mip_dimensions: list[tuple[int, int]],
    cfg: SlotConfig,
    has_alpha: bool,
    extra_flags: int = 0,
) -> None:
    """Assemble and write a .utex file from per-mip ASTC block payloads."""
    mip_count = len(mip_payloads)
    assert mip_count == len(mip_dimensions)

    payload_offset = align_up(
        UTEX_HEADER_SIZE + mip_count * UTEX_MIP_ENTRY_SIZE,
        UTEX_PAYLOAD_ALIGNMENT
    )

    # Build aligned mip payloads and compute their offsets
    mip_offsets: list[int] = []
    aligned_payloads: list[bytes] = []
    cursor = 0
    for payload in mip_payloads:
        mip_offsets.append(cursor)
        aligned_payloads.append(payload)
        cursor = align_up(cursor + len(payload), UTEX_PAYLOAD_ALIGNMENT)

    total_payload_size = cursor
    flags = (FLAG_HAS_ALPHA if has_alpha else 0) | extra_flags
    base_w, base_h = mip_dimensions[0]

    header_bytes = struct.pack(
        _HEADER_FMT,
        UTEX_MAGIC,               # magic[8]
        UTEX_VERSION,             # version
        flags,                    # flags
        base_w,                   # width
        base_h,                   # height
        mip_count,                # mipCount
        cfg.pixel_format,         # pixelFormat
        cfg.block_w,              # blockWidth
        cfg.block_h,              # blockHeight
        # xx = 2 padding bytes (handled by format string)
        payload_offset,           # payloadOffset
        total_payload_size,       # totalPayloadSize
        0, 0, 0, 0, 0,           # reserved1[5]
    )
    assert len(header_bytes) == UTEX_HEADER_SIZE

    mip_table_bytes = bytearray()
    for i, (payload, (w, h)) in enumerate(zip(mip_payloads, mip_dimensions)):
        mip_table_bytes += struct.pack(
            _MIP_ENTRY_FMT,
            mip_offsets[i],   # byteOffset
            len(payload),     # byteSize
            w,                # widthPx
            h,                # heightPx
        )

    # Pad between mip table end and payload start
    table_end = UTEX_HEADER_SIZE + mip_count * UTEX_MIP_ENTRY_SIZE
    pad_bytes = bytes(payload_offset - table_end)

    # Concatenate and write
    out = bytearray()
    out += header_bytes
    out += mip_table_bytes
    out += pad_bytes
    for payload in aligned_payloads:
        out += payload
        # Align each mip in the payload section
        aligned_size = align_up(len(payload), UTEX_PAYLOAD_ALIGNMENT)
        out += bytes(aligned_size - len(payload))

    output_path.write_bytes(bytes(out))

# ──────────────────────────────────────────────
# Main bake routine for a single texture
# ──────────────────────────────────────────────

def bake_texture(
    input_path: Path,
    output_path: Path,
    slot: str,
    quality: str,
    keep_temp: bool,
) -> None:
    if not _HAS_PILLOW:
        raise RuntimeError("Pillow is required. Install with: pip install Pillow")

    cfg = _SLOT_CONFIG.get(slot)
    if cfg is None:
        print(f"  [warn] Unknown slot '{slot}', falling back to 'data'")
        cfg = _SLOT_CONFIG["data"]

    print(f"  Loading   {input_path.name}")
    img = Image.open(input_path)
    has_alpha = img.mode in ("RGBA", "LA", "PA") or (img.mode == "P" and "transparency" in img.info)

    if cfg.encoding == "rgba16f":
        rgba = img.convert("RGBA")
        payload = bytearray(rgba.width * rgba.height * 8)
        offset = 0
        for channel in rgba.tobytes():
            struct.pack_into("<e", payload, offset, channel / 255.0)
            offset += 2
        write_utex(output_path, [bytes(payload)], [rgba.size], cfg, has_alpha)
        size_kb = output_path.stat().st_size / 1024
        print(f"  Written   {output_path.name}  ({size_kb:.1f} KB, RGBA16Float)")
        return

    if cfg.encoding == "r16":
        # Height/displacement data is single-channel and precision-sensitive —
        # ASTC's block quantization introduces visible stair-stepping in the
        # POM ray march, so this stays uncompressed R16Unorm instead. Source
        # 16-bit grayscale (e.g. Poliigon Displacement.tiff) is preserved
        # bit-exact; 8-bit sources are rescaled (×257) to fill the 16-bit range.
        gray = img.convert("I")
        high_precision_modes = {"I", "I;16", "I;16B", "I;16L", "I;16N", "F"}
        source_is_16bit = img.mode in high_precision_modes
        scale = 1 if source_is_16bit else 257

        if cfg.generate_mips:
            levels = mip_count_for(gray.width, gray.height)
            mip_imgs = [gray] + [
                gray.resize((max(1, gray.width >> lvl), max(1, gray.height >> lvl)), Image.LANCZOS)
                for lvl in range(1, levels)
            ]
        else:
            mip_imgs = [gray]
        print(f"  Mip chain {gray.width}×{gray.height} → {len(mip_imgs)} levels")

        mip_payloads: list[bytes] = []
        mip_dimensions: list[tuple[int, int]] = []
        for mip_img in mip_imgs:
            w, h = mip_img.size
            pixels = list(mip_img.getdata())
            payload = bytearray(w * h * 2)
            for i, value in enumerate(pixels):
                clamped = max(0, min(65535, int(value) * scale))
                struct.pack_into("<H", payload, i * 2, clamped)
            mip_payloads.append(bytes(payload))
            mip_dimensions.append((w, h))

        write_utex(output_path, mip_payloads, mip_dimensions, cfg, has_alpha=False)
        size_kb = output_path.stat().st_size / 1024
        print(f"  Written   {output_path.name}  ({size_kb:.1f} KB, R16Unorm, {len(mip_payloads)} mip levels)")
        return

    astcenc = find_astcenc()

    if cfg.generate_mips:
        mips = generate_mip_chain(img)
        print(f"  Mip chain {img.size[0]}×{img.size[1]} → {len(mips)} levels")
    else:
        mips = [img.convert("RGBA")]
        print(f"  Mip chain {img.size[0]}×{img.size[1]} → 1 level (mips disabled for slot '{slot}')")

    # Normal maps are unit-vector data, not color/luminance data: astcenc's default RGB
    # error metric perceptually weights green (tuned for human color vision) over red/blue,
    # which is the wrong tradeoff for X/Y/Z surface vectors and shows up as visible noise on
    # fine, high-frequency normal detail (fabric weave, wrinkles, ...). `-normal` re-weights
    # the error metric for vector data and repacks the map as 2-component X+Y (RGB=X, A=Y)
    # with Z reconstructed in-shader, freeing up bits that would otherwise encode a
    # redundant/inferable Z channel. `-perceptual` is also valid for normal-map data.
    # See FLAG_NORMAL_PACKED_XY and the decode in modelShader.metal / TransparencyShader.metal.
    extra_args = ["-normal", "-perceptual"] if slot == "normal" else None
    extra_flags = FLAG_NORMAL_PACKED_XY if slot == "normal" else 0

    tmp_dir = Path(tempfile.mkdtemp(prefix="texbake_"))
    try:
        mip_payloads: list[bytes] = []
        mip_dimensions: list[tuple[int, int]] = []

        for i, mip_img in enumerate(mips):
            w, h = mip_img.size
            label = f"{input_path.stem}_mip{i}"
            payload = compress_mip_to_astc(
                astcenc_bin=astcenc,
                mip_img=mip_img,
                block_size=cfg.block_size,
                quality=quality,
                srgb=cfg.srgb,
                tmp_dir=tmp_dir,
                label=label,
                extra_args=extra_args,
            )
            expected = expected_block_bytes(w, h, cfg.block_w, cfg.block_h)
            if len(payload) != expected:
                print(
                    f"  [warn] mip {i} ({w}×{h}): expected {expected} bytes, "
                    f"got {len(payload)} bytes from astcenc"
                )
            mip_payloads.append(payload)
            mip_dimensions.append((w, h))
            print(f"  mip {i:2d}  {w:5d}×{h:<5d}  {len(payload):>8,} bytes  [{label}]")

        write_utex(output_path, mip_payloads, mip_dimensions, cfg, has_alpha, extra_flags=extra_flags)
        size_kb = output_path.stat().st_size / 1024
        print(f"  Written   {output_path.name}  ({size_kb:.1f} KB)")

    finally:
        if not keep_temp:
            shutil.rmtree(tmp_dir, ignore_errors=True)
        else:
            print(f"  Temp dir  {tmp_dir}")

# ──────────────────────────────────────────────
# Flags map: read sibling .untold files to get authoritative slot info
# ──────────────────────────────────────────────

def _build_flags_map_from_untold_dir(textures_dir: Path) -> dict[str, int]:
    """Scan .untold files in the parent directory of `textures_dir` and build a
    mapping of {texture_stem_lower → flags} from their texture records.

    Used by bake_directory so that textures with opaque names (no slot keywords)
    are encoded with the correct sRGB/LDR block format.

    Returns an empty dict when no .untold files are found or parsing fails.
    """
    result: dict[str, int] = {}
    search_dir = textures_dir.parent
    untold_files = list(search_dir.glob("*.untold"))
    if not untold_files:
        return result

    for untold_path in untold_files:
        try:
            raw = untold_path.read_bytes()
            hdr = struct.unpack_from(_UNTOLD_HEADER_FMT, raw, 0)
            if hdr[0] != _UNTOLD_MAGIC:
                continue
            chunk_count = hdr[5]

            chunks: list[dict] = []
            for i in range(chunk_count):
                off = _UNTOLD_HEADER_SIZE + i * _UNTOLD_CHUNK_ENTRY_SIZE
                f = struct.unpack_from(_UNTOLD_CHUNK_FMT, raw, off)
                chunks.append({
                    "chunk_type":        f[0],
                    "compression_type":  f[1],
                    "file_offset":       f[2],
                    "compressed_size":   f[3],
                    "uncompressed_size": f[4],
                    "element_count":     f[5],
                    "reserved0":         f[6],
                })

            str_chunk = next((c for c in chunks if c["chunk_type"] == _CHUNK_STRING_TABLE), None)
            tex_chunk = next((c for c in chunks if c["chunk_type"] == _CHUNK_TEXTURE_TABLE), None)
            if str_chunk is None or tex_chunk is None:
                continue

            str_data = _decompress_chunk(raw, str_chunk)
            strings_by_offset: dict[int, str] = {}
            pos = 0
            while pos < len(str_data):
                nul = str_data.find(b"\x00", pos)
                if nul == -1:
                    break
                strings_by_offset[pos] = str_data[pos:nul].decode("utf-8")
                pos = nul + 1

            tex_data  = _decompress_chunk(raw, tex_chunk)
            tex_count = tex_chunk["element_count"]
            tex_size  = struct.calcsize(_UNTOLD_TEXTURE_FMT)

            for i in range(tex_count):
                rec = list(struct.unpack_from(_UNTOLD_TEXTURE_FMT, tex_data, i * tex_size))
                uri_offset = rec[1]
                flags      = rec[3]
                if uri_offset == _UNTOLD_INVALID_INDEX:
                    continue
                uri = strings_by_offset.get(uri_offset, "")
                if not uri:
                    continue
                stem = Path(uri).stem.lower()
                if stem not in result:   # first .untold wins
                    result[stem] = flags
        except Exception:
            pass   # silently skip unreadable files; fallback to detect_slot

    return result

# ──────────────────────────────────────────────
# Batch directory mode
# ──────────────────────────────────────────────

def bake_directory(
    directory: Path,
    quality: str,
    keep_temp: bool,
    progress_callback: Callable[[int, int, str], None] | None = None,
) -> None:
    sources = sorted(
        p for p in directory.iterdir()
        if p.suffix.lower() in SUPPORTED_EXTENSIONS and p.suffix.lower() != ".utex"
    )
    if not sources:
        print(f"No supported texture files found in {directory}")
        return

    # Build flags map from sibling .untold files so textures with opaque names
    # (e.g. "SimpleDungeonTexture") get the correct sRGB/LDR encoding.
    flags_map = _build_flags_map_from_untold_dir(directory)
    if flags_map:
        print(f"  Loaded slot hints for {len(flags_map)} texture(s) from .untold files\n")

    print(f"Batch baking {len(sources)} texture(s) in {directory}\n")
    errors: list[tuple[Path, str]] = []
    total = len(sources)

    for index, src in enumerate(sources):
        stem  = src.stem.lower()
        flags = flags_map.get(stem)
        slot  = (_slot_from_texture_flags(flags) if flags is not None else None) or detect_slot(src)
        out = src.with_suffix(".utex")
        print(f"[{slot}] {src.name}")
        try:
            bake_texture(src, out, slot, quality, keep_temp)
        except Exception as exc:
            errors.append((src, str(exc)))
            print(f"  [error] {exc}")
        print()
        if progress_callback is not None:
            progress_callback(index + 1, total, src.name)

    if errors:
        print(f"\n{len(errors)} error(s):")
        for path, msg in errors:
            print(f"  {path.name}: {msg}")
        sys.exit(1)
    else:
        print(f"Done. {len(sources)} texture(s) baked.")

# ──────────────────────────────────────────────
# .untold binary format constants
# (mirrors UntoldFormat.swift — must stay in sync)
# ──────────────────────────────────────────────

_UNTOLD_MAGIC           = b"UNTOLD\x00\x00"
_UNTOLD_HEADER_SIZE     = 204
_UNTOLD_CHUNK_ENTRY_SIZE = 40
_UNTOLD_FILE_ALIGNMENT  = 16
_UNTOLD_INVALID_INDEX   = 0xFFFFFFFF
_UNTOLD_HASH_OFFSET     = 140   # byte offset of SHA-256 hash inside header
_UNTOLD_HASH_SIZE       = 32

# magic(8) version(I) fileType(I) flags(I) headerSize(I) chunkCount(I)
# meshCount(I) materialCount(I) textureRefCount(I) entityCount(I)
# vertexLayout(I) reserved0(I) worldBounds(6f) rootTransform(16f)
# contentHash(32s) reserved1(32s)
_UNTOLD_HEADER_FMT   = "<8sIIIIIIIIIII6f16f32s32s"
_UNTOLD_CHUNK_FMT    = "<IIQQQII"   # 40 bytes
_UNTOLD_ENTITY_FMT   = "<6I6f6f16f" # 136 bytes
_UNTOLD_MESH_FMT     = "<8I6Q6f"    # 104 bytes
# nameOffset(I) flags(I) baseColorFactor(4f) emissiveFactor(3f) normalScale(f)
# metallicFactor(f) roughnessFactor(f) occlusionStrength(f) alphaCutoff(f)
# baseColorTex(I) normalTex(I) metallicTex(I) roughnessTex(I) emissiveTex(I)
# occlusionTex(I) heightTex(I) heightScale(f) heightMidlevel(f) heightRemapMin(f)
# heightRemapMax(f) packedChannels(I) reserved(I)
_UNTOLD_MATERIAL_FMT = "<II12f7I4f2I"   # 108 bytes (format version >= 4, height + remap fields)
_UNTOLD_TEXTURE_FMT  = "<8I"        # 32 bytes
# entityId(I) nameOffset(I) lightType(I) flags(I) color(3f) intensity(f)
# position(3f) radius(f) direction(3f) falloff(f) right(3f) innerCone(f)
# up(3f) outerCone(f) areaSize(2f) sourcePower(f) sourceExposure(f)
# localTransform(16f)
_UNTOLD_LIGHT_FMT    = "<4I40f"     # 176 bytes
# entityId(I) nameOffset(I) flags(I) reserved(I) position(3f) fovY(f)
# forward(3f) nearClip(f) up(3f) farClip(f) right(3f) aspectRatio(f)
# localTransform(16f)
_UNTOLD_CAMERA_FMT   = "<4I32f"     # 144 bytes
_UNTOLD_COLOR_MANAGEMENT_FMT = "<IIIffffI"  # 32 bytes
# entityId(I) nameOffset(I) firstJointRecordIndex(I) jointRecordCount(I)
# reserved(2I)
_UNTOLD_SKELETON_FMT = "<6I"        # 24 bytes
# parentJointIndex(I) jointPathOffset(I) flags(I) reserved(I)
# bindTransform(16f) restTransform(16f)
_UNTOLD_SKELETON_JOINT_FMT = "<4I32f"  # 144 bytes
# nameOffset(I) duration(f) firstChannelRecordIndex(I) channelRecordCount(I)
# flags(I) reserved(2I)
_UNTOLD_ANIM_CLIP_FMT       = "<IfIIIII"  # 28 bytes
# jointPathOffset(I) firstTranslationKeyframeIndex(I) translationKeyframeCount(I)
# firstRotationKeyframeIndex(I) rotationKeyframeCount(I) flags(I) reserved(I)
_UNTOLD_ANIM_CHANNEL_FMT    = "<7I"       # 28 bytes

assert struct.calcsize(_UNTOLD_HEADER_FMT)   == _UNTOLD_HEADER_SIZE
assert struct.calcsize(_UNTOLD_CHUNK_FMT)    == _UNTOLD_CHUNK_ENTRY_SIZE
assert struct.calcsize(_UNTOLD_ENTITY_FMT)   == 136
assert struct.calcsize(_UNTOLD_MESH_FMT)     == 104
assert struct.calcsize(_UNTOLD_MATERIAL_FMT) == 108
assert struct.calcsize(_UNTOLD_TEXTURE_FMT)  == 32
assert struct.calcsize(_UNTOLD_LIGHT_FMT)    == 176
assert struct.calcsize(_UNTOLD_CAMERA_FMT)   == 144
assert struct.calcsize(_UNTOLD_COLOR_MANAGEMENT_FMT) == 32
assert struct.calcsize(_UNTOLD_SKELETON_FMT) == 24
assert struct.calcsize(_UNTOLD_SKELETON_JOINT_FMT) == 144
assert struct.calcsize(_UNTOLD_ANIM_CLIP_FMT)       == 28
assert struct.calcsize(_UNTOLD_ANIM_CHANNEL_FMT)    == 28

# .untold texture record flags written by untoldexplorer.py
# (index [3] in _UNTOLD_TEXTURE_FMT "<8I")
_UNTOLD_TEX_FLAG_SRGB       = 1 << 0   # base-color / any sRGB texture
_UNTOLD_TEX_FLAG_NORMAL_MAP = 1 << 1
_UNTOLD_TEX_FLAG_LUT        = 1 << 2   # color-grading LUT strip — never mip-filtered
_UNTOLD_TEX_FLAG_HEIGHT     = 1 << 3   # displacement/bump height map — baked to R16Unorm
_UNTOLD_TEX_FLAG_EMISSIVE   = 1 << 6
_UNTOLD_TEX_FLAG_OCCLUSION  = 1 << 7

# Chunk type IDs (matches UntoldChunkType)
_CHUNK_STRING_TABLE  = 1
_CHUNK_ENTITY_TABLE  = 2
_CHUNK_MESH_TABLE    = 3
_CHUNK_MATERIAL_TABLE = 4
_CHUNK_TEXTURE_TABLE = 5
_CHUNK_VERTEX_DATA   = 6
_CHUNK_INDEX_DATA    = 7
_CHUNK_SKELETON_TABLE         = 8
_CHUNK_SKELETON_JOINT_TABLE   = 9
_CHUNK_ANIMATION_CLIP_TABLE   = 12
_CHUNK_ANIMATION_CHANNEL_TABLE = 13
_CHUNK_LIGHT_TABLE   = 19
_CHUNK_CAMERA_TABLE  = 20
_CHUNK_COLOR_MANAGEMENT_TABLE = 21

# Compression type IDs (matches UntoldCompressionType)
_COMPRESS_NONE = 0
_COMPRESS_LZ4  = 1

# UntoldTextureFormat ASTC values (matches UntoldFormat.swift)
_UNTOLD_FORMAT_ASTC_4X4 = 4
_UNTOLD_FORMAT_ASTC_5X5 = 5
_UNTOLD_FORMAT_ASTC_6X6 = 6
_UNTOLD_FORMAT_ASTC_8X8 = 7
_UNTOLD_FORMAT_RGBA16_FLOAT = 8
_UNTOLD_FORMAT_R16_UNORM = 9

def _untold_format_for_config(cfg: SlotConfig) -> int:
    if cfg.pixel_format == MTL_RGBA16_FLOAT:
        return _UNTOLD_FORMAT_RGBA16_FLOAT
    if cfg.pixel_format == MTL_R16_UNORM:
        return _UNTOLD_FORMAT_R16_UNORM
    return {
        "4x4": _UNTOLD_FORMAT_ASTC_4X4,
        "5x5": _UNTOLD_FORMAT_ASTC_5X5,
        "6x6": _UNTOLD_FORMAT_ASTC_6X6,
        "8x8": _UNTOLD_FORMAT_ASTC_8X8,
    }.get(cfg.block_size, _UNTOLD_FORMAT_ASTC_4X4)

# ──────────────────────────────────────────────
# .untold patcher
# ──────────────────────────────────────────────

def _decompress_chunk(data: bytes, chunk: dict) -> bytes:
    """Return the uncompressed payload for a chunk entry."""
    start = chunk["file_offset"]
    raw = data[start:start + chunk["compressed_size"]]
    ctype = chunk["compression_type"]
    if ctype == _COMPRESS_NONE:
        return raw
    if ctype == _COMPRESS_LZ4:
        if not _HAS_LZ4:
            raise RuntimeError(
                "The .untold file contains LZ4-compressed chunks.\n"
                "Install the lz4 Python package:  pip install lz4"
            )
        return _lz4_block.decompress(raw, uncompressed_size=chunk["uncompressed_size"])
    raise RuntimeError(f"Unsupported compression type {ctype} in chunk type {chunk['chunk_type']}")


def _recompress_chunk(payload: bytes, original_compression: int) -> bytes:
    """Re-compress a chunk payload using the same compression type as the original."""
    if original_compression == _COMPRESS_NONE:
        return payload
    if original_compression == _COMPRESS_LZ4:
        if not _HAS_LZ4:
            raise RuntimeError("pip install lz4  (needed to re-compress LZ4 chunks)")
        return _lz4_block.compress(payload, store_size=False)
    raise RuntimeError(f"Unsupported compression type {original_compression}")


def _read_cstring(data: bytes, offset: int) -> str:
    """Read a null-terminated UTF-8 string from `data` at `offset`."""
    end = data.index(b"\x00", offset)
    return data[offset:end].decode("utf-8")


def patch_refs(untold_path: Path) -> None:
    """
    Reads a .untold file and, for every texture whose URI has a corresponding
    .utex file on disk (same directory, same basename, .utex extension):
      - updates the URI string in the string table to point to the .utex file
      - updates the textureFormat field to the correct ASTC variant

    All other records and chunk data are left unchanged.
    The file is rewritten in-place.
    """
    data = untold_path.read_bytes()
    base_dir = untold_path.parent

    # ── 1. Parse header ──────────────────────────────────────────────
    hdr = struct.unpack_from(_UNTOLD_HEADER_FMT, data, 0)
    magic      = hdr[0]
    chunk_count = hdr[5]

    if magic != _UNTOLD_MAGIC:
        raise RuntimeError(f"Not a valid .untold file: {untold_path}")

    # ── 2. Parse chunk table ─────────────────────────────────────────
    chunks = []
    for i in range(chunk_count):
        off = _UNTOLD_HEADER_SIZE + i * _UNTOLD_CHUNK_ENTRY_SIZE
        f = struct.unpack_from(_UNTOLD_CHUNK_FMT, data, off)
        chunks.append({
            "chunk_type":       f[0],
            "compression_type": f[1],
            "file_offset":      f[2],
            "compressed_size":  f[3],
            "uncompressed_size": f[4],
            "element_count":    f[5],
            "reserved0":        f[6],
        })

    def get_chunk(ctype: int) -> dict:
        for c in chunks:
            if c["chunk_type"] == ctype:
                return c
        raise RuntimeError(f"Required chunk type {ctype} not found in {untold_path.name}")

    # ── 3. Decode string table ───────────────────────────────────────
    str_chunk = get_chunk(_CHUNK_STRING_TABLE)
    str_data = _decompress_chunk(data, str_chunk)

    # Build offset → string map by scanning all null-terminated strings
    strings_by_offset: dict[int, str] = {}
    pos = 0
    while pos < len(str_data):
        nul = str_data.find(b"\x00", pos)
        if nul == -1:
            break
        strings_by_offset[pos] = str_data[pos:nul].decode("utf-8")
        pos = nul + 1

    # ── 4. Decode texture records ────────────────────────────────────
    tex_chunk = get_chunk(_CHUNK_TEXTURE_TABLE)
    tex_data = _decompress_chunk(data, tex_chunk)
    tex_count = tex_chunk["element_count"]
    tex_size = struct.calcsize(_UNTOLD_TEXTURE_FMT)

    texture_records = []
    for i in range(tex_count):
        texture_records.append(list(struct.unpack_from(_UNTOLD_TEXTURE_FMT, tex_data, i * tex_size)))

    # ── 5. Identify textures that have .utex equivalents ─────────────
    # updates[i] = (new_uri_string, new_untold_format_int)
    updates: dict[int, tuple[str, int]] = {}
    for i, rec in enumerate(texture_records):
        uri_offset = rec[1]
        if uri_offset == _UNTOLD_INVALID_INDEX:
            continue
        uri = strings_by_offset.get(uri_offset, "")
        if not uri:
            continue

        uri_path = Path(uri)
        utex_uri  = str(uri_path.with_suffix(".utex"))
        utex_abs  = base_dir / utex_uri
        if not utex_abs.exists():
            # Also try flat (just basename in same dir)
            utex_abs = base_dir / uri_path.with_suffix(".utex").name
            if not utex_abs.exists():
                continue
            utex_uri = uri_path.with_suffix(".utex").name

        # Use flags from the texture record (field [3]) as the authoritative slot
        # signal — the exporter sets TEXTURE_FLAG_SRGB, NORMAL_MAP, etc. at
        # export time from material data, which is correct even when the filename
        # has no recognised keywords (e.g. "SimpleDungeonTexture").
        flags = rec[3]
        slot  = _slot_from_texture_flags(flags) or detect_slot(uri_path)
        cfg   = _SLOT_CONFIG.get(slot, _SLOT_CONFIG["data"])
        updates[i] = (utex_uri, _untold_format_for_config(cfg))

    if not updates:
        print("  No .utex counterparts found — nothing to patch.")
        return

    print(f"  Patching {len(updates)} texture reference(s):")
    for i, (new_uri, new_fmt) in updates.items():
        old_uri = strings_by_offset.get(texture_records[i][1], "<none>")
        print(f"    [{i}] {old_uri}  →  {new_uri}  (format={new_fmt})")

    # ── 6. Rebuild string table ──────────────────────────────────────
    # Apply URI updates at the old offsets, then rebuild in order.
    updated_strings = dict(strings_by_offset)
    for i, (new_uri, _) in updates.items():
        old_uri_offset = texture_records[i][1]
        updated_strings[old_uri_offset] = new_uri

    new_str_bytes = bytearray()
    old_to_new: dict[int, int] = {}
    for old_off in sorted(updated_strings):
        new_off = len(new_str_bytes)
        old_to_new[old_off] = new_off
        new_str_bytes += updated_strings[old_off].encode("utf-8") + b"\x00"
    new_str_data = bytes(new_str_bytes)

    # ── 7. Re-encode all record tables with updated string offsets ────

    def remap(offset: int) -> int:
        if offset == _UNTOLD_INVALID_INDEX:
            return _UNTOLD_INVALID_INDEX
        return old_to_new.get(offset, offset)

    def patch_table(chunk_type: int, fmt: str, name_field_indices: list[int]) -> bytes | None:
        """Re-encode a record table, remapping string offsets at named field indices.
        Returns None if the chunk is absent (optional tables like entity/mesh may not
        exist in every .untold file)."""
        try:
            c = get_chunk(chunk_type)
        except RuntimeError:
            return None
        raw = _decompress_chunk(data, c)
        rec_size = struct.calcsize(fmt)
        count = c["element_count"]
        out = bytearray(raw)
        for i in range(count):
            off = i * rec_size
            fields = list(struct.unpack_from(fmt, out, off))
            for fi in name_field_indices:
                fields[fi] = remap(fields[fi])
            struct.pack_into(fmt, out, off, *fields)
        return bytes(out)

    new_entity_data   = patch_table(_CHUNK_ENTITY_TABLE,   _UNTOLD_ENTITY_FMT,   [2])      # nameOffset
    new_mesh_data     = patch_table(_CHUNK_MESH_TABLE,     _UNTOLD_MESH_FMT,     [1])      # meshNameOffset
    new_material_data = patch_table(_CHUNK_MATERIAL_TABLE, _UNTOLD_MATERIAL_FMT, [0])      # nameOffset
    # Light/camera/skeleton/animation records also carry string-table offsets
    # (light and camera names, joint paths). Every record table that stores a
    # string offset MUST be patched here whenever the string table is rebuilt —
    # skipping one leaves stale offsets that read garbage or invalid UTF-8 after
    # this pass, since the string table below is fully rebuilt with new offsets.
    new_light_data       = patch_table(_CHUNK_LIGHT_TABLE,             _UNTOLD_LIGHT_FMT,          [1])  # nameOffset
    new_camera_data      = patch_table(_CHUNK_CAMERA_TABLE,            _UNTOLD_CAMERA_FMT,         [1])  # nameOffset
    new_color_management_data = patch_table(
        _CHUNK_COLOR_MANAGEMENT_TABLE,
        _UNTOLD_COLOR_MANAGEMENT_FMT,
        [1, 2],
    )
    new_skeleton_data    = patch_table(_CHUNK_SKELETON_TABLE,          _UNTOLD_SKELETON_FMT,       [1])  # nameOffset
    new_skel_joint_data  = patch_table(_CHUNK_SKELETON_JOINT_TABLE,    _UNTOLD_SKELETON_JOINT_FMT, [1])  # jointPathOffset
    new_anim_clip_data   = patch_table(_CHUNK_ANIMATION_CLIP_TABLE,    _UNTOLD_ANIM_CLIP_FMT,      [0])  # nameOffset
    new_anim_channel_data = patch_table(_CHUNK_ANIMATION_CHANNEL_TABLE, _UNTOLD_ANIM_CHANNEL_FMT,  [0])  # jointPathOffset

    # Texture table: remap nameOffset(0) and uriOffset(1), also set textureFormat(2)
    tex_c    = get_chunk(_CHUNK_TEXTURE_TABLE)
    raw_tex  = _decompress_chunk(data, tex_c)
    out_tex  = bytearray(raw_tex)
    for i in range(tex_count):
        off = i * tex_size
        fields = list(struct.unpack_from(_UNTOLD_TEXTURE_FMT, out_tex, off))
        fields[0] = remap(fields[0])   # nameOffset
        fields[1] = remap(fields[1])   # uriOffset
        if i in updates:
            fields[2] = updates[i][1]  # textureFormat
        struct.pack_into(_UNTOLD_TEXTURE_FMT, out_tex, off, *fields)
    new_texture_data = bytes(out_tex)

    # ── 8. Build updated payload map ─────────────────────────────────
    # For each chunk type, decide whether we use the new or original payload.
    # patch_table returns None for chunks that are absent; skip those.
    _candidate_payloads: list[tuple[int, bytes | None]] = [
        (_CHUNK_STRING_TABLE,   new_str_data),
        (_CHUNK_ENTITY_TABLE,   new_entity_data),
        (_CHUNK_MESH_TABLE,     new_mesh_data),
        (_CHUNK_MATERIAL_TABLE, new_material_data),
        (_CHUNK_TEXTURE_TABLE,  new_texture_data),
        (_CHUNK_LIGHT_TABLE,              new_light_data),
        (_CHUNK_CAMERA_TABLE,             new_camera_data),
        (_CHUNK_COLOR_MANAGEMENT_TABLE,   new_color_management_data),
        (_CHUNK_SKELETON_TABLE,           new_skeleton_data),
        (_CHUNK_SKELETON_JOINT_TABLE,     new_skel_joint_data),
        (_CHUNK_ANIMATION_CLIP_TABLE,     new_anim_clip_data),
        (_CHUNK_ANIMATION_CHANNEL_TABLE,  new_anim_channel_data),
    ]
    updated_payloads: dict[int, bytes] = {
        ctype: payload
        for ctype, payload in _candidate_payloads
        if payload is not None
        # vertex/index data: pass through unchanged (re-compress with original method)
    }

    # ── 9. Repack the file ───────────────────────────────────────────
    # Body start = header + chunk table, aligned to file alignment.
    chunk_table_size = len(chunks) * _UNTOLD_CHUNK_ENTRY_SIZE
    body_start = align_up(_UNTOLD_HEADER_SIZE + chunk_table_size, _UNTOLD_FILE_ALIGNMENT)

    body3: bytearray = bytearray()
    final_entries: list[dict] = []
    final_hash_payloads: list[tuple[int, bytes]] = []

    for chunk in sorted(chunks, key=lambda c: c["file_offset"]):
        ctype = chunk["chunk_type"]
        ccomp = chunk["compression_type"]

        if ctype in updated_payloads:
            uncompressed = updated_payloads[ctype]
            compressed   = _recompress_chunk(uncompressed, ccomp)
            uncompressed_size = len(uncompressed)
        else:
            start         = chunk["file_offset"]
            compressed    = data[start:start + chunk["compressed_size"]]
            uncompressed_size = chunk["uncompressed_size"]

        _align_body(body3, _UNTOLD_FILE_ALIGNMENT)
        file_off = body_start + len(body3)

        final_entries.append({
            "chunk_type":        ctype,
            "compression_type":  ccomp,
            "file_offset":       file_off,
            "compressed_size":   len(compressed),
            "uncompressed_size": uncompressed_size,
            "element_count":     chunk["element_count"],
            "reserved0":         chunk["reserved0"],
        })
        final_hash_payloads.append((ctype, compressed))
        body3 += compressed
        _align_body(body3, _UNTOLD_FILE_ALIGNMENT)

    # Recompute hash with final layout
    content_hash = hashlib.sha256(
        b"".join(p for _, p in sorted(final_hash_payloads, key=lambda t: t[0]))
    ).digest()

    # Build new header bytes: copy original, patch hash field
    new_header = bytearray(data[:_UNTOLD_HEADER_SIZE])
    new_header[_UNTOLD_HASH_OFFSET:_UNTOLD_HASH_OFFSET + _UNTOLD_HASH_SIZE] = content_hash

    # Build new chunk table bytes
    new_chunk_table = bytearray()
    for e in final_entries:
        new_chunk_table += struct.pack(
            _UNTOLD_CHUNK_FMT,
            e["chunk_type"],
            e["compression_type"],
            e["file_offset"],
            e["compressed_size"],
            e["uncompressed_size"],
            e["element_count"],
            e["reserved0"],
        )

    # Pad between chunk table end and body start
    pre_body_pad = body_start - (_UNTOLD_HEADER_SIZE + len(new_chunk_table))
    assert pre_body_pad >= 0, "body_start calculation error"

    # ── 12. Write output ─────────────────────────────────────────────
    out_bytes = bytes(new_header) + bytes(new_chunk_table) + bytes(pre_body_pad) + bytes(body3)
    untold_path.write_bytes(out_bytes)

    orig_kb = len(data) / 1024
    new_kb  = len(out_bytes) / 1024
    print(f"  Written   {untold_path.name}  ({orig_kb:.1f} KB → {new_kb:.1f} KB)")


def _align_body(buf: bytearray, alignment: int) -> None:
    """Pad `buf` in-place to the next `alignment`-byte boundary."""
    rem = len(buf) % alignment
    if rem:
        buf += bytes(alignment - rem)


# ──────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Offline ASTC texture baker — converts images to the engine-native .utex format.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--input", type=Path, help="Source image (PNG, JPEG, TGA)")
    parser.add_argument("--output", type=Path, help="Output .utex path (default: beside input)")
    parser.add_argument(
        "--slot",
        choices=list(_SLOT_CONFIG.keys()),
        help="Texture slot (auto-detected from filename if omitted)",
    )
    parser.add_argument("--dir", type=Path, help="Batch mode: directory of source textures")
    parser.add_argument(
        "--quality",
        choices=["fastest", "fast", "medium", "thorough", "exhaustive"],
        default="thorough",
        help="astcenc quality level (default: thorough)",
    )
    parser.add_argument("--keep-temp", action="store_true", help="Retain intermediate temp files")
    parser.add_argument(
        "--patch-refs",
        type=Path,
        metavar="UNTOLD_FILE_OR_DIR",
        help=(
            "Patch texture references in a .untold file (or all .untold files in a directory) "
            "to point to .utex files where they exist alongside the original images. "
            "Updates URI strings and textureFormat fields; rewrites each file in-place."
        ),
    )
    args = parser.parse_args(argv)

    if args.patch_refs is not None:
        target = args.patch_refs
        if not target.exists():
            print(f"error: path not found: {target}", file=sys.stderr)
            return 1

        if target.is_dir():
            untold_files = sorted(target.rglob("*.untold"))
            if not untold_files:
                print(f"No .untold files found in {target}", file=sys.stderr)
                return 1
            print(f"Patching {len(untold_files)} .untold file(s) in {target}\n")
            errors = 0
            for untold_file in untold_files:
                print(f"  → {untold_file.name}")
                try:
                    patch_refs(untold_file)
                except Exception as exc:
                    print(f"    error: {exc}", file=sys.stderr)
                    errors += 1
            if errors:
                print(f"\n{errors} file(s) failed.", file=sys.stderr)
                return 1
        else:
            if target.suffix.lower() != ".untold":
                print(f"error: expected a .untold file or directory, got: {target.name}", file=sys.stderr)
                return 1
            print(f"Patching refs in  {target}\n")
            try:
                patch_refs(target)
            except Exception as exc:
                print(f"error: {exc}", file=sys.stderr)
                return 1
        return 0

    if args.dir is not None:
        if not args.dir.is_dir():
            print(f"error: --dir '{args.dir}' is not a directory", file=sys.stderr)
            return 1
        bake_directory(args.dir, args.quality, args.keep_temp)
        return 0

    if args.input is None:
        parser.print_help()
        return 1

    if not args.input.exists():
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        return 1

    slot = args.slot or detect_slot(args.input)
    output = args.output or args.input.with_suffix(".utex")

    print(f"Baking  {args.input.name}")
    print(f"Slot    {slot}")
    print(f"Output  {output}")
    print(f"Quality {args.quality}\n")

    try:
        bake_texture(args.input, output, slot, args.quality, args.keep_temp)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
