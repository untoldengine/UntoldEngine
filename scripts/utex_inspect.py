#!/usr/bin/env python3

# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
utex_inspect.py — Debug inspector for engine-native .utex texture containers.

Parses a .utex file and prints the header and mip table in a human-readable format.
Does not decode or display ASTC pixel data.

Usage:
    python scripts/utex_inspect.py path/to/texture.utex
    python scripts/utex_inspect.py path/to/texture.utex --hex-header
"""

from __future__ import annotations

import argparse
import math
import struct
import sys
from pathlib import Path

# ──────────────────────────────────────────────
# Format constants  (must match NativeTexFormat.swift and texbake.py)
# ──────────────────────────────────────────────

UTEX_MAGIC = b"UTEX\x00\x00\x00\x00"
UTEX_VERSION = 1
UTEX_HEADER_SIZE = 64
UTEX_MIP_ENTRY_SIZE = 16
UTEX_PAYLOAD_ALIGNMENT = 16

_HEADER_FMT = "<8sIIIIIIBBxxII5I"
_MIP_ENTRY_FMT = "<IIII"

assert struct.calcsize(_HEADER_FMT) == UTEX_HEADER_SIZE
assert struct.calcsize(_MIP_ENTRY_FMT) == UTEX_MIP_ENTRY_SIZE

# Known MTLPixelFormat values for ASTC
_MTL_PIXEL_FORMAT_NAMES: dict[int, str] = {
    186: "astc_4x4_sRGB",
    187: "astc_5x4_sRGB",
    188: "astc_5x5_sRGB",
    189: "astc_6x5_sRGB",
    190: "astc_6x6_sRGB",
    192: "astc_8x5_sRGB",
    193: "astc_8x6_sRGB",
    194: "astc_8x8_sRGB",
    195: "astc_10x5_sRGB",
    196: "astc_10x6_sRGB",
    197: "astc_10x8_sRGB",
    198: "astc_10x10_sRGB",
    199: "astc_12x10_sRGB",
    200: "astc_12x12_sRGB",
    204: "astc_4x4_ldr",
    205: "astc_5x4_ldr",
    206: "astc_5x5_ldr",
    207: "astc_6x5_ldr",
    208: "astc_6x6_ldr",
    210: "astc_8x5_ldr",
    211: "astc_8x6_ldr",
    212: "astc_8x8_ldr",
    213: "astc_10x5_ldr",
    214: "astc_10x6_ldr",
    215: "astc_10x8_ldr",
    216: "astc_10x10_ldr",
    217: "astc_12x10_ldr",
    218: "astc_12x12_ldr",
}

FLAG_HAS_ALPHA = 1 << 0
FLAG_PREMULTIPLIED_ALPHA = 1 << 1

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

def _pixel_format_name(raw: int) -> str:
    name = _MTL_PIXEL_FORMAT_NAMES.get(raw)
    return f"MTLPixelFormat.{name}" if name else f"<unknown:{raw}>"


def _describe_flags(flags: int) -> str:
    parts = []
    if flags & FLAG_HAS_ALPHA:
        parts.append("hasAlpha")
    if flags & FLAG_PREMULTIPLIED_ALPHA:
        parts.append("premultipliedAlpha")
    unknown = flags & ~(FLAG_HAS_ALPHA | FLAG_PREMULTIPLIED_ALPHA)
    if unknown:
        parts.append(f"<unknown bits: 0x{unknown:08x}>")
    return " | ".join(parts) if parts else "none"


def _expected_block_bytes(width: int, height: int, bw: int, bh: int) -> int:
    return math.ceil(width / bw) * math.ceil(height / bh) * 16


def _fmt_bytes(n: int) -> str:
    if n >= 1_048_576:
        return f"{n / 1_048_576:.2f} MB  ({n:,} bytes)"
    if n >= 1024:
        return f"{n / 1024:.1f} KB  ({n:,} bytes)"
    return f"{n:,} bytes"


# ──────────────────────────────────────────────
# Inspector
# ──────────────────────────────────────────────

def inspect(path: Path, hex_header: bool) -> int:
    data = path.read_bytes()
    file_size = len(data)

    if file_size < UTEX_HEADER_SIZE:
        print(f"error: file too small to contain a valid header ({file_size} bytes)", file=sys.stderr)
        return 1

    # Parse header
    (
        magic,
        version,
        flags,
        width,
        height,
        mip_count,
        pixel_format,
        block_width,
        block_height,
        # 2 padding bytes consumed by 'xx' in format string
        payload_offset,
        total_payload_size,
        *reserved1,
    ) = struct.unpack_from(_HEADER_FMT, data, 0)

    # ── Header block ──
    print(f"{'─' * 60}")
    print(f"  File    {path}")
    print(f"  Size    {_fmt_bytes(file_size)}")
    print(f"{'─' * 60}")
    print("  HEADER")
    print(f"{'─' * 60}")

    magic_ok = magic == UTEX_MAGIC
    magic_display = repr(magic) + ("  ✓" if magic_ok else "  ✗ INVALID")
    print(f"  magic          {magic_display}")
    print(f"  version        {version}" + ("" if version == UTEX_VERSION else f"  ✗ expected {UTEX_VERSION}"))
    print(f"  flags          0x{flags:08x}  ({_describe_flags(flags)})")
    print(f"  dimensions     {width} × {height} px  (mip 0)")
    print(f"  mipCount       {mip_count}")
    print(f"  pixelFormat    {pixel_format}  →  {_pixel_format_name(pixel_format)}")
    print(f"  blockSize      {block_width} × {block_height}")
    print(f"  payloadOffset  {payload_offset}  (0x{payload_offset:08x})")
    print(f"  payloadSize    {_fmt_bytes(total_payload_size)}")

    if hex_header:
        print()
        print("  Raw header bytes (hex):")
        raw = data[:UTEX_HEADER_SIZE]
        for row_start in range(0, UTEX_HEADER_SIZE, 16):
            chunk = raw[row_start:row_start + 16]
            hex_str = " ".join(f"{b:02x}" for b in chunk)
            print(f"    {row_start:3d}:  {hex_str}")

    # ── Early-exit on corrupt header ──
    if not magic_ok:
        print("\n✗ Cannot continue: invalid magic bytes.")
        return 1

    if version != UTEX_VERSION:
        print(f"\n✗ Cannot continue: unsupported version {version}.")
        return 1

    if mip_count == 0:
        print("\n✗ mipCount is zero — file is invalid.")
        return 1

    # ── Mip table ──
    expected_table_start = UTEX_HEADER_SIZE
    expected_table_end = UTEX_HEADER_SIZE + mip_count * UTEX_MIP_ENTRY_SIZE

    if file_size < expected_table_end:
        print(f"\n✗ File too small to contain mip table ({file_size} < {expected_table_end})")
        return 1

    print()
    print(f"{'─' * 60}")
    print(f"  MIP TABLE  ({mip_count} entries)")
    print(f"{'─' * 60}")
    print(f"  {'Mip':>4}  {'Width':>7}  {'Height':>7}  {'Offset':>10}  {'Size':>12}  {'Expected':>12}  Status")
    print(f"  {'───':>4}  {'─────':>7}  {'──────':>7}  {'──────':>10}  {'────':>12}  {'────────':>12}  ──────")

    has_errors = False
    total_mip_sum = 0

    for i in range(mip_count):
        offset_in_file = UTEX_HEADER_SIZE + i * UTEX_MIP_ENTRY_SIZE
        byte_offset, byte_size, w_px, h_px = struct.unpack_from(_MIP_ENTRY_FMT, data, offset_in_file)
        total_mip_sum += byte_size

        expected_bytes = (
            _expected_block_bytes(w_px, h_px, block_width, block_height)
            if block_width > 0 and block_height > 0 else 0
        )
        size_match = byte_size == expected_bytes
        payload_end = int(payload_offset) + int(byte_offset) + int(byte_size)
        in_bounds = payload_end <= file_size

        status_parts = []
        if not size_match:
            status_parts.append("⚠ size mismatch")
            has_errors = True
        if not in_bounds:
            status_parts.append("✗ out of bounds")
            has_errors = True
        status = "  ".join(status_parts) if status_parts else "✓"

        print(
            f"  {i:>4}  {w_px:>7}  {h_px:>7}  {byte_offset:>10,}  "
            f"{byte_size:>12,}  {expected_bytes:>12,}  {status}"
        )

    # ── Summary ──
    print()
    print(f"{'─' * 60}")
    print("  SUMMARY")
    print(f"{'─' * 60}")
    print(f"  Declared payload size  {_fmt_bytes(total_payload_size)}")
    print(f"  Sum of mip sizes       {_fmt_bytes(total_mip_sum)}")

    payload_in_file = file_size - int(payload_offset)
    print(f"  Payload bytes in file  {_fmt_bytes(payload_in_file)}")

    if total_mip_sum > total_payload_size:
        print("  ⚠  Sum of mip sizes exceeds declared totalPayloadSize")
        has_errors = True

    if not has_errors:
        print("  ✓  Container looks valid")
    else:
        print("  ✗  Validation issues found (see table above)")

    print(f"{'─' * 60}")
    return 1 if has_errors else 0


# ──────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Inspect an engine-native .utex texture container.",
    )
    parser.add_argument("file", type=Path, help=".utex file to inspect")
    parser.add_argument(
        "--hex-header",
        action="store_true",
        help="Print the raw header bytes as a hex dump",
    )
    args = parser.parse_args(argv)

    if not args.file.exists():
        print(f"error: file not found: {args.file}", file=sys.stderr)
        return 1

    return inspect(args.file, args.hex_header)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
