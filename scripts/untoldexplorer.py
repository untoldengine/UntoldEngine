#!/usr/bin/env python3

# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import struct
import sys
import tempfile
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Callable, Iterable, Optional

try:
    import bpy  # type: ignore
    import bmesh  # type: ignore
    from bpy_extras.io_utils import axis_conversion  # type: ignore
    from mathutils import Matrix, Vector  # type: ignore
except ImportError:
    bpy = None
    bmesh = None
    axis_conversion = None
    Matrix = None
    Vector = None

try:
    import numpy as np
    _HAS_NUMPY = True
except ImportError:
    np = None
    _HAS_NUMPY = False


MAGIC = b"UNTOLD\x00\x00"
# Bumped from 1 to 2 when the exporter started multiplying emissive_factor by
# Emission Strength (see extract_material). Readers use this to know whether
# a file's emissiveFactor is trustworthy or a leftover Blender default.
# Bumped to 4 when the material record grew height-map fields (heightTextureIndex,
# heightScale, heightMidlevel) and height-remap fields (heightRemapMin, heightRemapMax) —
# see extract_material's Displacement/Bump detection and write_material_record.
FORMAT_VERSION = 4
FILE_ALIGNMENT = 16
INVALID_INDEX = 0xFFFFFFFF
HEADER_SIZE = 204
CHUNK_ENTRY_SIZE = 40
VERTEX_STRIDE = 32

COMPRESSION_NONE = 0
COMPRESSION_LZ4 = 1

FILE_TYPES = {
    "tile": 1,
    "lod": 2,
    "hlod": 3,
    "shared": 4,
    "animation": 5,
}

CHUNK_TYPES = {
    "string_table": 1,
    "entity_table": 2,
    "mesh_table": 3,
    "material_table": 4,
    "texture_table": 5,
    "vertex_data": 6,
    "index_data": 7,
    "skeleton_table": 8,
    "skeleton_joint_table": 9,
    "skin_table": 10,
    "skin_joint_mapping_table": 11,
    "animation_clip_table": 12,
    "animation_channel_table": 13,
    "translation_keyframe_table": 14,
    "rotation_keyframe_table": 15,
    "joint_index_data": 16,
    "joint_weight_data": 17,
    "edge_index_data": 18,
    "light_table": 19,
    "camera_table": 20,
    "color_management_table": 21,
    "color_grade_lut_table": 22,
}

VERTEX_LAYOUT_PBR_STATIC_V1 = 1
INDEX_TYPE_UINT16 = 1
INDEX_TYPE_UINT32 = 2
LIGHT_TYPE_DIRECTIONAL = 1
LIGHT_TYPE_POINT = 2
LIGHT_TYPE_SPOT = 3
LIGHT_TYPE_AREA = 4
LIGHT_FLAG_CASTS_SHADOW = 1 << 0
LIGHT_FLAG_RADIOMETRIC = 1 << 1
LIGHT_FLAG_CUSTOM_DISTANCE = 1 << 2
ARCHITECTURAL_EDGE_ANGLE_DEGREES = 30.0
ARCHITECTURAL_EDGE_POSITION_EPSILON = 1.0e-5
TEXTURE_FORMAT_UNKNOWN = 0
TEXTURE_FORMAT_RGBA16_FLOAT = 8
TEXTURE_FLAG_SRGB = 1 << 0
TEXTURE_FLAG_NORMAL_MAP = 1 << 1
TEXTURE_FLAG_LUT = 1 << 2
TEXTURE_FLAG_HEIGHT = 1 << 3
TEXTURE_FLAG_EMISSIVE = 1 << 6
TEXTURE_FLAG_OCCLUSION = 1 << 7
TEXTURE_CHANNEL_R = 0
TEXTURE_CHANNEL_G = 1
TEXTURE_CHANNEL_B = 2
TEXTURE_CHANNEL_A = 3
UNTOLD_EXPORT_TEMP_OBJECT_PROP = "_untold_export_temp_object"

ProgressCallback = Callable[[str, int, int, str], None]


class ProgressReporter:
    def __init__(self, label: str, total_steps: int, on_progress: Optional[ProgressCallback] = None) -> None:
        self.label = label
        self.total_steps = max(int(total_steps), 1)
        self.completed_steps = 0
        self.on_progress = on_progress

    def stage(self, stage: str, detail: str = "") -> None:
        self._emit(stage, detail, self.completed_steps)

    def advance(self, stage: str, detail: str = "", steps: int = 1) -> None:
        self.completed_steps = min(self.total_steps, self.completed_steps + max(int(steps), 0))
        self._emit(stage, detail, self.completed_steps)

    def _emit(self, stage: str, detail: str, completed_steps: int) -> None:
        percent = (100.0 * completed_steps) / self.total_steps
        suffix = f" - {detail}" if detail else ""
        print(
            f"[progress] {self.label}: {percent:6.2f}% "
            f"({completed_steps}/{self.total_steps}) {stage}{suffix}",
            flush=True,
        )
        if self.on_progress is not None:
            self.on_progress(stage, completed_steps, self.total_steps, detail)


def align(value: int, alignment: int) -> int:
    remainder = value % alignment
    return value if remainder == 0 else value + (alignment - remainder)


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def clamp_texture_channel(channel: int) -> int:
    channel = int(channel)
    if channel in (TEXTURE_CHANNEL_R, TEXTURE_CHANNEL_G, TEXTURE_CHANNEL_B, TEXTURE_CHANNEL_A):
        return channel
    return TEXTURE_CHANNEL_R


def pack_material_texture_channels(
    roughness: int = TEXTURE_CHANNEL_R,
    metallic: int = TEXTURE_CHANNEL_R,
) -> int:
    return (clamp_texture_channel(roughness) & 0b11) | ((clamp_texture_channel(metallic) & 0b11) << 2)


def texture_channel_from_socket_name(name: str, default: int = TEXTURE_CHANNEL_R) -> int:
    normalized = str(name or "").strip().lower().replace(" ", "").replace("_", "")
    channel_by_name = {
        "r": TEXTURE_CHANNEL_R,
        "red": TEXTURE_CHANNEL_R,
        "x": TEXTURE_CHANNEL_R,
        "g": TEXTURE_CHANNEL_G,
        "green": TEXTURE_CHANNEL_G,
        "y": TEXTURE_CHANNEL_G,
        "b": TEXTURE_CHANNEL_B,
        "blue": TEXTURE_CHANNEL_B,
        "z": TEXTURE_CHANNEL_B,
        "a": TEXTURE_CHANNEL_A,
        "alpha": TEXTURE_CHANNEL_A,
        "w": TEXTURE_CHANNEL_A,
    }
    return channel_by_name.get(normalized, default)


def normalize3(vector: tuple[float, float, float], fallback: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = vector
    length = math.sqrt((x * x) + (y * y) + (z * z))
    if length <= 1.0e-8:
        return fallback
    return (x / length, y / length, z / length)


def _sub3(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross3(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        (a[1] * b[2]) - (a[2] * b[1]),
        (a[2] * b[0]) - (a[0] * b[2]),
        (a[0] * b[1]) - (a[1] * b[0]),
    )


def _dot3(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    return (a[0] * b[0]) + (a[1] * b[1]) + (a[2] * b[2])


def build_architectural_edge_indices(
    positions: list[tuple[float, float, float]],
    indices: list[int],
    angle_degrees: float = ARCHITECTURAL_EDGE_ANGLE_DEGREES,
    position_epsilon: float = ARCHITECTURAL_EDGE_POSITION_EPSILON,
) -> list[int]:
    """Return boundary and hard-angle edges from an already indexed triangle mesh."""
    if len(indices) < 3:
        return []

    quant_scale = 1.0 / max(position_epsilon, 1.0e-12)

    def quantized_position(index: int) -> tuple[int, int, int]:
        position = positions[index]
        return (
            int(round(position[0] * quant_scale)),
            int(round(position[1] * quant_scale)),
            int(round(position[2] * quant_scale)),
        )

    cos_threshold = math.cos(math.radians(max(0.0, min(180.0, angle_degrees))))
    edge_faces: dict[
        tuple[tuple[int, int, int], tuple[int, int, int]],
        list[tuple[tuple[float, float, float], tuple[int, int]]],
    ] = {}

    for triangle_start in range(0, len(indices) - 2, 3):
        tri = (indices[triangle_start], indices[triangle_start + 1], indices[triangle_start + 2])
        if tri[0] >= len(positions) or tri[1] >= len(positions) or tri[2] >= len(positions):
            continue

        p0 = positions[tri[0]]
        p1 = positions[tri[1]]
        p2 = positions[tri[2]]
        normal = normalize3(_cross3(_sub3(p1, p0), _sub3(p2, p0)), (0.0, 0.0, 0.0))
        if normal == (0.0, 0.0, 0.0):
            continue

        for a, b in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
            qa = quantized_position(a)
            qb = quantized_position(b)
            key = (qa, qb) if qa <= qb else (qb, qa)
            edge_faces.setdefault(key, []).append((normal, (a, b)))

    edge_indices: list[int] = []
    for faces in edge_faces.values():
        if len(faces) == 1:
            edge_indices.extend(faces[0][1])
            continue

        keep = False
        for i in range(len(faces)):
            for j in range(i + 1, len(faces)):
                if _dot3(faces[i][0], faces[j][0]) <= cos_threshold:
                    keep = True
                    break
            if keep:
                break
        if keep:
            edge_indices.extend(faces[0][1])

    return edge_indices


def pack_index_data(indices: list[int], index_type: int) -> bytes:
    writer = BinaryWriter()
    for index in indices:
        if index_type == INDEX_TYPE_UINT16:
            writer.write_u16(index)
        else:
            writer.write_u32(index)
    return writer.data


def pack_snorm10(value: float) -> int:
    clamped = clamp(value, -1.0, 1.0)
    scaled = int(round(clamped * 511.0))
    return scaled & 0x3FF


def pack_snorm2(value: float) -> int:
    return (-1 if value < 0.0 else 1) & 0x3


def pack_normal(normal: tuple[float, float, float]) -> int:
    nx, ny, nz = normalize3(normal, (0.0, 0.0, 1.0))
    return pack_snorm10(nx) | (pack_snorm10(ny) << 10) | (pack_snorm10(nz) << 20)


def pack_tangent(tangent: tuple[float, float, float], handedness: float) -> int:
    tx, ty, tz = normalize3(tangent, (1.0, 0.0, 0.0))
    return (
        pack_snorm10(tx)
        | (pack_snorm10(ty) << 10)
        | (pack_snorm10(tz) << 20)
        | (pack_snorm2(handedness) << 30)
    )


def float_to_half_bits(value: float) -> int:
    return struct.unpack("<H", struct.pack("<e", value))[0]


def color_to_u8(value: float) -> int:
    return int(round(clamp(value, 0.0, 1.0) * 255.0))


if _HAS_NUMPY:
    _VERTEX_DTYPE = np.dtype([
        ("px", np.float32), ("py", np.float32), ("pz", np.float32),
        ("normal",  np.uint32),
        ("tangent", np.uint32),
        ("uv0u", np.uint16), ("uv0v", np.uint16),
        ("uv1u", np.uint16), ("uv1v", np.uint16),
        ("cr", np.uint8), ("cg", np.uint8), ("cb", np.uint8), ("ca", np.uint8),
    ])
    assert _VERTEX_DTYPE.itemsize == VERTEX_STRIDE, (
        f"_VERTEX_DTYPE is {_VERTEX_DTYPE.itemsize} bytes, expected {VERTEX_STRIDE}"
    )

    def _np_pack_snorm10(values: "np.ndarray") -> "np.ndarray":
        clamped = np.clip(values, -1.0, 1.0)
        scaled = np.round(clamped * 511.0).astype(np.int32)
        return (scaled & 0x3FF).astype(np.uint32)

    def _np_pack_normals(normals: "np.ndarray") -> "np.ndarray":
        lens = np.linalg.norm(normals, axis=1, keepdims=True)
        lens = np.where(lens <= 1.0e-8, 1.0, lens)
        n = normals / lens
        return (
            _np_pack_snorm10(n[:, 0])
            | (_np_pack_snorm10(n[:, 1]) << 10)
            | (_np_pack_snorm10(n[:, 2]) << 20)
        )

    def _np_pack_tangents(tangents: "np.ndarray", bitangent_signs: "np.ndarray") -> "np.ndarray":
        lens = np.linalg.norm(tangents, axis=1, keepdims=True)
        lens = np.where(lens <= 1.0e-8, 1.0, lens)
        t = tangents / lens
        hw = np.where(bitangent_signs >= 0.0, np.int32(1), np.int32(-1)).astype(np.int32) & np.int32(0x3)
        return (
            _np_pack_snorm10(t[:, 0])
            | (_np_pack_snorm10(t[:, 1]) << 10)
            | (_np_pack_snorm10(t[:, 2]) << 20)
            | (hw.astype(np.uint32) << 30)
        )
else:
    _VERTEX_DTYPE = None
    _np_pack_normals = None
    _np_pack_tangents = None


class BinaryWriter:
    def __init__(self) -> None:
        self._buffer = bytearray()

    @property
    def data(self) -> bytes:
        return bytes(self._buffer)

    @property
    def count(self) -> int:
        return len(self._buffer)

    def align(self, alignment: int) -> None:
        target = align(len(self._buffer), alignment)
        if target > len(self._buffer):
            self._buffer.extend(b"\x00" * (target - len(self._buffer)))

    def write_bytes(self, data: bytes) -> None:
        self._buffer.extend(data)

    def write_u8(self, value: int) -> None:
        self._buffer.extend(struct.pack("<B", value))

    def write_u16(self, value: int) -> None:
        self._buffer.extend(struct.pack("<H", value))

    def write_u32(self, value: int) -> None:
        self._buffer.extend(struct.pack("<I", value))

    def write_u64(self, value: int) -> None:
        self._buffer.extend(struct.pack("<Q", value))

    def write_f32(self, value: float) -> None:
        self._buffer.extend(struct.pack("<f", float(value)))

    def write_c_string(self, value: str) -> None:
        self._buffer.extend(value.encode("utf-8"))
        self._buffer.append(0)

    def write_matrix4x4_column_major(self, matrix_rows: list[list[float]]) -> None:
        for column in range(4):
            for row in range(4):
                self.write_f32(matrix_rows[row][column])


class StringTableBuilder:
    def __init__(self) -> None:
        self._writer = BinaryWriter()
        self._offsets: dict[str, int] = {}

    def add(self, value: Optional[str]) -> int:
        if not value:
            return INVALID_INDEX
        existing = self._offsets.get(value)
        if existing is not None:
            return existing
        offset = self._writer.count
        self._writer.write_c_string(value)
        self._offsets[value] = offset
        return offset

    @property
    def data(self) -> bytes:
        return self._writer.data


@dataclass(frozen=True)
class AABB:
    minimum: tuple[float, float, float]
    maximum: tuple[float, float, float]


@dataclass(frozen=True)
class TextureRecord:
    name_offset: int
    uri_offset: int
    texture_format: int = TEXTURE_FORMAT_UNKNOWN
    flags: int = 0
    width: int = 0
    height: int = 0
    mip_count: int = 0


@dataclass(frozen=True)
class LightRecord:
    entity_id: int
    name_offset: int
    light_type: int
    flags: int
    color: tuple[float, float, float]
    intensity: float
    position: tuple[float, float, float]
    radius: float
    direction: tuple[float, float, float]
    falloff: float
    right: tuple[float, float, float]
    inner_cone: float
    up: tuple[float, float, float]
    outer_cone: float
    area_size: tuple[float, float]
    source_power: float
    source_exposure: float
    local_transform_rows: list[list[float]]


@dataclass(frozen=True)
class CameraRecord:
    entity_id: int
    name_offset: int
    flags: int
    position: tuple[float, float, float]
    forward: tuple[float, float, float]
    up: tuple[float, float, float]
    right: tuple[float, float, float]
    fov_y_degrees: float
    near_clip: float
    far_clip: float
    aspect_ratio: float
    local_transform_rows: list[list[float]]


@dataclass(frozen=True)
class ColorManagementRecord:
    lut_texture_index: int
    view_transform_name_offset: int
    look_name_offset: int
    exposure: float
    gamma: float
    shaper_min_stops: float
    shaper_max_stops: float
    lut_size: int


@dataclass(frozen=True)
class ColorGradeLUTRecord:
    """An externally-authored .cube LUT, applied as a post-tonemap creative grade.

    Unlike ColorManagementRecord (which bakes Blender's whole View Transform into
    a proprietary shaper-encoded texture), this references a plain .cube file
    staged next to the export -- no Blender render/bake, no custom domain. The
    engine loads the .cube directly (see CubeLUTLoader) rather than through the
    native .utex texture pipeline, so there is no texture_index here.
    """

    lut_uri_offset: int
    lut_size: int
    domain_min: tuple[float, float, float]
    domain_max: tuple[float, float, float]


@dataclass(frozen=True)
class MaterialRecord:
    name_offset: int
    flags: int
    base_color_factor: tuple[float, float, float, float]
    emissive_factor: tuple[float, float, float]
    normal_scale: float
    metallic_factor: float
    roughness_factor: float
    occlusion_strength: float
    alpha_cutoff: float
    base_color_texture_index: int
    normal_texture_index: int = INVALID_INDEX
    metallic_texture_index: int = INVALID_INDEX
    roughness_texture_index: int = INVALID_INDEX
    emissive_texture_index: int = INVALID_INDEX
    occlusion_texture_index: int = INVALID_INDEX
    height_texture_index: int = INVALID_INDEX
    height_scale: float = 0.05
    height_midlevel: float = 0.5
    height_remap_min: float = 0.0
    height_remap_max: float = 1.0
    roughness_texture_channel: int = TEXTURE_CHANNEL_R
    metallic_texture_channel: int = TEXTURE_CHANNEL_R


@dataclass(frozen=True)
class EntityRecord:
    entity_id: int
    parent_entity_id: int
    name_offset: int
    first_mesh_record_index: int
    mesh_record_count: int
    flags: int
    local_bounds: AABB
    world_bounds: AABB
    local_transform_rows: list[list[float]]


@dataclass(frozen=True)
class MeshRecord:
    entity_id: int
    mesh_name_offset: int
    material_index: int
    index_type: int
    vertex_count: int
    index_count: int
    vertex_stride_bytes: int
    flags: int
    vertex_data_offset: int
    index_data_offset: int
    vertex_data_size_bytes: int
    index_data_size_bytes: int
    estimated_gpu_bytes: int
    edge_index_data_offset: int
    edge_index_count: int
    local_bounds: AABB


@dataclass(frozen=True)
class SkeletonRecord:
    entity_id: int
    name_offset: int
    first_joint_record_index: int
    joint_record_count: int


@dataclass(frozen=True)
class SkeletonJointRecord:
    parent_joint_index: int
    joint_path_offset: int
    flags: int
    bind_transform_rows: list[list[float]]
    rest_transform_rows: list[list[float]]


@dataclass(frozen=True)
class SkinRecord:
    entity_id: int
    mesh_record_index: int
    skeleton_entity_id: int
    joint_count: int
    first_joint_mapping_index: int
    joint_index_data_offset: int
    joint_weight_data_offset: int
    vertex_count: int


@dataclass(frozen=True)
class SkinJointMappingRecord:
    skeleton_joint_index: int


@dataclass(frozen=True)
class AnimationClipRecord:
    name_offset: int
    duration: float
    first_channel_record_index: int
    channel_record_count: int
    flags: int = 0


@dataclass(frozen=True)
class AnimationChannelRecord:
    joint_path_offset: int
    first_translation_keyframe_index: int
    translation_keyframe_count: int
    first_rotation_keyframe_index: int
    rotation_keyframe_count: int
    flags: int = 0


@dataclass(frozen=True)
class TranslationKeyframeRecord:
    time: float
    value: tuple[float, float, float]


@dataclass(frozen=True)
class RotationKeyframeRecord:
    time: float
    value: tuple[float, float, float, float]


@dataclass(frozen=True)
class ExportedTexture:
    name: str
    uri: str
    width: int
    height: int
    mip_count: int
    source_path: Optional[Path] = None
    source_image_name: Optional[str] = None
    channel: int = TEXTURE_CHANNEL_R
    texture_format: int = TEXTURE_FORMAT_UNKNOWN


@dataclass(frozen=True)
class ExportedMaterial:
    name: str
    base_color_factor: tuple[float, float, float, float]
    emissive_factor: tuple[float, float, float]
    normal_scale: float
    metallic_factor: float
    roughness_factor: float
    occlusion_strength: float
    alpha_cutoff: float
    base_color_texture: Optional[ExportedTexture]
    normal_texture: Optional[ExportedTexture] = None
    metallic_texture: Optional[ExportedTexture] = None
    roughness_texture: Optional[ExportedTexture] = None
    emissive_texture: Optional[ExportedTexture] = None
    occlusion_texture: Optional[ExportedTexture] = None
    height_texture: Optional[ExportedTexture] = None
    # Blender's Displacement node Scale is a world-space displacement distance (typically
    # a fraction of a meter), while the engine's heightScale is a UV-normalized ray-march
    # depth fraction — these are not the same unit and there is no exact conversion without
    # knowing the mesh's texel density. This value is carried through as a reasonable
    # starting point, not a precise conversion; expect to retune heightScale after import.
    height_scale: float = 0.05
    # Always the neutral default (0.5 = no additional shift) for Displacement-sourced height —
    # Blender's Midlevel is NOT copied here. The engine's POM is unidirectional (cannot bulge
    # outward past the true polygon surface the way Blender's signed displacement-around-
    # Midlevel can), so heightMidlevel is just an additive shift, not a true zero-reference;
    # copying Blender's Midlevel into it would not reproduce "neutral gray = no visible depth".
    # Blender's Midlevel is used to derive height_remap_max instead — see extract_material's
    # Displacement-node detection block.
    height_midlevel: float = 0.5
    # Derived from Blender's Displacement Midlevel when present (clamped to (0, 1]): raw values
    # at/above this clip to "no depth", values below get contrast-stretched into the full depth
    # range. Identity (0.0, 1.0) when no Midlevel is available (e.g. Bump-sourced height).
    height_remap_min: float = 0.0
    height_remap_max: float = 1.0
    roughness_texture_channel: int = TEXTURE_CHANNEL_R
    metallic_texture_channel: int = TEXTURE_CHANNEL_R


@dataclass(frozen=True)
class ValidationTangent:
    xyz: tuple[float, float, float]
    handedness: float


@dataclass(frozen=True)
class ValidationMesh:
    name: str
    vertex_count: int
    index_count: int
    positions: list[tuple[float, float, float]]
    normals: list[tuple[float, float, float]]
    tangents: list[ValidationTangent]
    uv0: list[tuple[float, float]]
    indices: list[int]
    edge_indices: list[int]


@dataclass(frozen=True)
class ExportedMesh:
    entity_name: str
    parent_entity_name: Optional[str]
    mesh_name: str
    local_transform_rows: list[list[float]]
    local_bounds: AABB
    world_bounds: AABB
    vertices: bytes
    indices: bytes
    edge_indices: bytes
    vertex_count: int
    index_count: int
    edge_index_count: int
    index_type: int
    material: ExportedMaterial
    skin_binding: Optional["ExportedSkinBinding"]
    validation_mesh: ValidationMesh


@dataclass(frozen=True)
class ExportedNode:
    entity_name: str
    parent_entity_name: Optional[str]
    local_transform_rows: list[list[float]]
    local_bounds: AABB
    world_bounds: AABB
    skeleton: Optional[ExportedSkeleton] = None
    mesh: Optional[ExportedMesh] = None


@dataclass(frozen=True)
class ExportedLight:
    entity_name: str
    light_type: int
    color: tuple[float, float, float]
    intensity: float
    position: tuple[float, float, float]
    radius: float
    range: float
    direction: tuple[float, float, float]
    falloff: float
    right: tuple[float, float, float]
    inner_cone: float
    up: tuple[float, float, float]
    outer_cone: float
    area_size: tuple[float, float]
    source_power: float
    source_exposure: float
    casts_shadow: bool
    local_transform_rows: list[list[float]]


@dataclass(frozen=True)
class ExportedCamera:
    entity_name: str
    position: tuple[float, float, float]
    forward: tuple[float, float, float]
    up: tuple[float, float, float]
    right: tuple[float, float, float]
    fov_y_degrees: float
    near_clip: float
    far_clip: float
    aspect_ratio: float
    local_transform_rows: list[list[float]]


@dataclass(frozen=True)
class ExportedSkeletonJoint:
    name: str
    path: str
    parent_index: int
    bind_transform_rows: list[list[float]]
    rest_transform_rows: list[list[float]]


@dataclass(frozen=True)
class ExportedSkeleton:
    entity_name: str
    name: str
    joints: list[ExportedSkeletonJoint]


@dataclass(frozen=True)
class ExportedSkinBinding:
    skeleton_entity_name: str
    joint_count: int
    skin_to_skeleton_map: list[int]
    joint_indices: bytes
    joint_weights: bytes


@dataclass(frozen=True)
class ExportedAnimationChannel:
    joint_path: str
    translations: list["KeyframeVector3"]
    rotations: list["KeyframeQuaternion"]


@dataclass(frozen=True)
class ExportedAnimationClip:
    name: str
    duration: float
    channels: list[ExportedAnimationChannel]


@dataclass(frozen=True)
class KeyframeVector3:
    time: float
    value: tuple[float, float, float]


@dataclass(frozen=True)
class KeyframeQuaternion:
    time: float
    value: tuple[float, float, float, float]


class UnsupportedTextureFormatError(Exception):
    """Raised when a texture is not usable by the engine pipeline (e.g. EXR/HDR format, or no pixel data)."""


class TextureStagingContext:
    staged_by_key: dict[str, Path]
    used_names: set[str]

    def __init__(self) -> None:
        self.staged_by_key = {}
        self.used_names = set()


class HDRStagingContext:
    staged_by_key: dict[str, Path]
    used_names: set[str]

    def __init__(self) -> None:
        self.staged_by_key = {}
        self.used_names = set()


def clean_generated_sidecar_dirs(output_path: Path) -> None:
    """Remove sidecar directories fully owned by a single-asset export.

    Re-exporting into an existing asset folder must not leave stale staged
    textures, baked .utex files, color LUTs, or HDR environments from earlier
    runs. The .untold file itself is overwritten separately.
    """
    for dirname in ("Textures", "HDR"):
        sidecar_dir = output_path.parent / dirname
        if sidecar_dir.is_dir():
            shutil.rmtree(sidecar_dir)


def aabb_from_points(points: Iterable[tuple[float, float, float]]) -> AABB:
    point_list = list(points)
    if not point_list:
        raise ValueError("Cannot build bounds from an empty point set")
    min_x = min(point[0] for point in point_list)
    min_y = min(point[1] for point in point_list)
    min_z = min(point[2] for point in point_list)
    max_x = max(point[0] for point in point_list)
    max_y = max(point[1] for point in point_list)
    max_z = max(point[2] for point in point_list)
    return AABB((min_x, min_y, min_z), (max_x, max_y, max_z))


def write_aabb(writer: BinaryWriter, bounds: AABB) -> None:
    for value in bounds.minimum:
        writer.write_f32(value)
    for value in bounds.maximum:
        writer.write_f32(value)


def identity_matrix_rows() -> list[list[float]]:
    return [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def matrix_rows_multiply(lhs: list[list[float]], rhs: list[list[float]]) -> list[list[float]]:
    return [
        [
            sum(lhs[row][k] * rhs[k][column] for k in range(4))
            for column in range(4)
        ]
        for row in range(4)
    ]


def transform_point_rows(matrix_rows: list[list[float]], point: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = point
    return (
        matrix_rows[0][0] * x + matrix_rows[0][1] * y + matrix_rows[0][2] * z + matrix_rows[0][3],
        matrix_rows[1][0] * x + matrix_rows[1][1] * y + matrix_rows[1][2] * z + matrix_rows[1][3],
        matrix_rows[2][0] * x + matrix_rows[2][1] * y + matrix_rows[2][2] * z + matrix_rows[2][3],
    )


def transform_direction_rows(
    matrix_rows: list[list[float]],
    direction: tuple[float, float, float],
    fallback: tuple[float, float, float],
) -> tuple[float, float, float]:
    x, y, z = direction
    transformed = (
        matrix_rows[0][0] * x + matrix_rows[0][1] * y + matrix_rows[0][2] * z,
        matrix_rows[1][0] * x + matrix_rows[1][1] * y + matrix_rows[1][2] * z,
        matrix_rows[2][0] * x + matrix_rows[2][1] * y + matrix_rows[2][2] * z,
    )
    return normalize3(transformed, fallback)


def _unpack_snorm10(bits: int) -> float:
    signed = bits if bits < 512 else bits - 1024
    return max(-1.0, signed / 511.0)


def unpack_normal(packed: int) -> tuple[float, float, float]:
    return normalize3(
        (
            _unpack_snorm10(packed & 0x3FF),
            _unpack_snorm10((packed >> 10) & 0x3FF),
            _unpack_snorm10((packed >> 20) & 0x3FF),
        ),
        (0.0, 0.0, 1.0),
    )


def unpack_tangent(packed: int) -> tuple[tuple[float, float, float], float]:
    tangent = normalize3(
        (
            _unpack_snorm10(packed & 0x3FF),
            _unpack_snorm10((packed >> 10) & 0x3FF),
            _unpack_snorm10((packed >> 20) & 0x3FF),
        ),
        (1.0, 0.0, 0.0),
    )
    handedness = -1.0 if ((packed >> 30) & 0x3) == 0x3 else 1.0
    return tangent, handedness


def bake_mesh_vertices_to_world(mesh: ExportedMesh, world_transform_rows: list[list[float]]) -> ExportedMesh:
    vertex_bytes = bytearray(mesh.vertices)
    transformed_positions: list[tuple[float, float, float]] = []

    for offset in range(0, len(vertex_bytes), VERTEX_STRIDE):
        px, py, pz, packed_normal, packed_tangent = struct.unpack_from("<3fII", vertex_bytes, offset)
        position = transform_point_rows(world_transform_rows, (px, py, pz))
        normal = transform_direction_rows(world_transform_rows, unpack_normal(packed_normal), (0.0, 0.0, 1.0))
        tangent_xyz, handedness = unpack_tangent(packed_tangent)
        tangent = transform_direction_rows(world_transform_rows, tangent_xyz, (1.0, 0.0, 0.0))

        struct.pack_into(
            "<3fII",
            vertex_bytes,
            offset,
            position[0],
            position[1],
            position[2],
            pack_normal(normal),
            pack_tangent(tangent, handedness),
        )
        transformed_positions.append(position)

    baked_bounds = aabb_from_points(transformed_positions)
    validation_mesh = mesh.validation_mesh
    if validation_mesh is not None:
        validation_mesh = replace(
            validation_mesh,
            positions=transformed_positions,
            normals=[
                transform_direction_rows(world_transform_rows, normal, (0.0, 0.0, 1.0))
                for normal in validation_mesh.normals
            ],
            tangents=[
                ValidationTangent(
                    xyz=transform_direction_rows(world_transform_rows, tangent.xyz, (1.0, 0.0, 0.0)),
                    handedness=tangent.handedness,
                )
                for tangent in validation_mesh.tangents
            ],
        )

    return replace(
        mesh,
        local_transform_rows=identity_matrix_rows(),
        local_bounds=baked_bounds,
        world_bounds=baked_bounds,
        vertices=bytes(vertex_bytes),
        validation_mesh=validation_mesh,
    )


def bake_skeleton_to_world(skeleton: ExportedSkeleton, world_transform_rows: list[list[float]]) -> ExportedSkeleton:
    baked_joints: list[ExportedSkeletonJoint] = []
    for joint in skeleton.joints:
        bind_transform_rows = matrix_rows_multiply(world_transform_rows, joint.bind_transform_rows)
        if joint.parent_index == INVALID_INDEX:
            rest_transform_rows = matrix_rows_multiply(world_transform_rows, joint.rest_transform_rows)
        else:
            rest_transform_rows = joint.rest_transform_rows
        baked_joints.append(
            replace(
                joint,
                bind_transform_rows=bind_transform_rows,
                rest_transform_rows=rest_transform_rows,
            )
        )

    return replace(skeleton, joints=baked_joints)


def normalize_export_nodes(nodes: list[ExportedNode]) -> list[ExportedNode]:
    if not nodes:
        return nodes

    nodes_by_name = {node.entity_name: node for node in nodes}
    children_by_name: dict[str, list[str]] = {}
    for node in nodes:
        children_by_name.setdefault(node.entity_name, [])
        if node.parent_entity_name is not None:
            children_by_name.setdefault(node.parent_entity_name, []).append(node.entity_name)

    world_transform_by_name: dict[str, list[list[float]]] = {}

    def resolved_world_transform(node_name: str) -> list[list[float]]:
        cached = world_transform_by_name.get(node_name)
        if cached is not None:
            return cached

        node = nodes_by_name[node_name]
        if node.parent_entity_name is None:
            world = node.local_transform_rows
        else:
            world = matrix_rows_multiply(
                resolved_world_transform(node.parent_entity_name),
                node.local_transform_rows,
            )
        world_transform_by_name[node_name] = world
        return world

    baked_meshes_by_name: dict[str, ExportedMesh] = {}
    for node in nodes:
        if node.mesh is None:
            continue
        baked_meshes_by_name[node.entity_name] = bake_mesh_vertices_to_world(
            node.mesh,
            resolved_world_transform(node.entity_name),
        )

    baked_skeletons_by_name: dict[str, ExportedSkeleton] = {}
    for node in nodes:
        if node.skeleton is None:
            continue
        baked_skeletons_by_name[node.entity_name] = bake_skeleton_to_world(
            node.skeleton,
            resolved_world_transform(node.entity_name),
        )

    aggregated_world_corners_by_name: dict[str, list[tuple[float, float, float]]] = {}

    def aggregate_world_corners(node_name: str) -> list[tuple[float, float, float]]:
        cached = aggregated_world_corners_by_name.get(node_name)
        if cached is not None:
            return cached

        corners: list[tuple[float, float, float]] = []
        baked_mesh = baked_meshes_by_name.get(node_name)
        if baked_mesh is not None:
            corners.extend(aabb_corners(baked_mesh.world_bounds))
        for child_name in children_by_name.get(node_name, []):
            corners.extend(aggregate_world_corners(child_name))

        aggregated_world_corners_by_name[node_name] = corners
        return corners

    normalized_nodes: list[ExportedNode] = []
    for node in nodes:
        baked_mesh = baked_meshes_by_name.get(node.entity_name)
        baked_skeleton = baked_skeletons_by_name.get(node.entity_name)
        if baked_mesh is not None:
            local_bounds = baked_mesh.local_bounds
            world_bounds = baked_mesh.world_bounds
        else:
            world_corners = aggregate_world_corners(node.entity_name)
            if world_corners:
                world_bounds = aabb_from_points(world_corners)
                local_bounds = world_bounds
            else:
                local_bounds = AABB((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
                world_bounds = local_bounds

        normalized_nodes.append(
            replace(
                node,
                local_transform_rows=identity_matrix_rows(),
                local_bounds=local_bounds,
                world_bounds=world_bounds,
                skeleton=baked_skeleton,
                mesh=baked_mesh,
            )
        )

    return normalized_nodes


def write_header(
    writer: BinaryWriter,
    *,
    file_type: int,
    chunk_count: int,
    mesh_count: int,
    material_count: int,
    texture_count: int,
    entity_count: int,
    world_bounds: AABB,
    root_transform_rows: list[list[float]],
    content_hash: bytes,
) -> None:
    writer.write_bytes(MAGIC)
    writer.write_u32(FORMAT_VERSION)
    writer.write_u32(file_type)
    writer.write_u32(0)
    writer.write_u32(HEADER_SIZE)
    writer.write_u32(chunk_count)
    writer.write_u32(mesh_count)
    writer.write_u32(material_count)
    writer.write_u32(texture_count)
    writer.write_u32(entity_count)
    writer.write_u32(VERTEX_LAYOUT_PBR_STATIC_V1)
    writer.write_u32(0)
    write_aabb(writer, world_bounds)
    writer.write_matrix4x4_column_major(root_transform_rows)
    writer.write_bytes(content_hash)
    writer.write_bytes(b"\x00" * 32)


def write_chunk_entry(
    writer: BinaryWriter,
    *,
    chunk_type: int,
    compression_type: int = COMPRESSION_NONE,
    file_offset: int,
    compressed_size: int,
    uncompressed_size: int,
    element_count: int,
) -> None:
    writer.write_u32(chunk_type)
    writer.write_u32(compression_type)
    writer.write_u64(file_offset)
    writer.write_u64(compressed_size)
    writer.write_u64(uncompressed_size)
    writer.write_u32(element_count)
    writer.write_u32(0)


def write_entity_record(writer: BinaryWriter, entity: EntityRecord) -> None:
    writer.write_u32(entity.entity_id)
    writer.write_u32(entity.parent_entity_id)
    writer.write_u32(entity.name_offset)
    writer.write_u32(entity.first_mesh_record_index)
    writer.write_u32(entity.mesh_record_count)
    writer.write_u32(entity.flags)
    write_aabb(writer, entity.local_bounds)
    write_aabb(writer, entity.world_bounds)
    writer.write_matrix4x4_column_major(entity.local_transform_rows)


def write_mesh_record(writer: BinaryWriter, mesh: MeshRecord) -> None:
    writer.write_u32(mesh.entity_id)
    writer.write_u32(mesh.mesh_name_offset)
    writer.write_u32(mesh.material_index)
    writer.write_u32(mesh.index_type)
    writer.write_u32(mesh.vertex_count)
    writer.write_u32(mesh.index_count)
    writer.write_u32(mesh.vertex_stride_bytes)
    writer.write_u32(mesh.flags)
    writer.write_u64(mesh.vertex_data_offset)
    writer.write_u64(mesh.index_data_offset)
    writer.write_u64(mesh.vertex_data_size_bytes)
    writer.write_u64(mesh.index_data_size_bytes)
    writer.write_u64(mesh.estimated_gpu_bytes)
    writer.write_u64((mesh.edge_index_count << 32) | mesh.edge_index_data_offset)
    write_aabb(writer, mesh.local_bounds)


def write_material_record(writer: BinaryWriter, material: MaterialRecord) -> None:
    writer.write_u32(material.name_offset)
    writer.write_u32(material.flags)
    for value in material.base_color_factor:
        writer.write_f32(value)
    for value in material.emissive_factor:
        writer.write_f32(value)
    writer.write_f32(material.normal_scale)
    writer.write_f32(material.metallic_factor)
    writer.write_f32(material.roughness_factor)
    writer.write_f32(material.occlusion_strength)
    writer.write_f32(material.alpha_cutoff)
    writer.write_u32(material.base_color_texture_index)
    writer.write_u32(material.normal_texture_index)
    writer.write_u32(material.metallic_texture_index)
    writer.write_u32(material.roughness_texture_index)
    writer.write_u32(material.emissive_texture_index)
    writer.write_u32(material.occlusion_texture_index)
    writer.write_u32(material.height_texture_index)
    writer.write_f32(material.height_scale)
    writer.write_f32(material.height_midlevel)
    writer.write_f32(material.height_remap_min)
    writer.write_f32(material.height_remap_max)
    writer.write_u32(pack_material_texture_channels(material.roughness_texture_channel, material.metallic_texture_channel))
    writer.write_u32(0)


def write_texture_record(writer: BinaryWriter, texture: TextureRecord) -> None:
    writer.write_u32(texture.name_offset)
    writer.write_u32(texture.uri_offset)
    writer.write_u32(texture.texture_format)
    writer.write_u32(texture.flags)
    writer.write_u32(texture.width)
    writer.write_u32(texture.height)
    writer.write_u32(texture.mip_count)
    writer.write_u32(0)


def write_light_record(writer: BinaryWriter, light: LightRecord) -> None:
    writer.write_u32(light.entity_id)
    writer.write_u32(light.name_offset)
    writer.write_u32(light.light_type)
    writer.write_u32(light.flags)
    for value in light.color:
        writer.write_f32(value)
    writer.write_f32(light.intensity)
    for value in light.position:
        writer.write_f32(value)
    writer.write_f32(light.radius)
    for value in light.direction:
        writer.write_f32(value)
    writer.write_f32(light.falloff)
    for value in light.right:
        writer.write_f32(value)
    writer.write_f32(light.inner_cone)
    for value in light.up:
        writer.write_f32(value)
    writer.write_f32(light.outer_cone)
    writer.write_f32(light.area_size[0])
    writer.write_f32(light.area_size[1])
    writer.write_f32(light.source_power)
    writer.write_f32(light.source_exposure)
    writer.write_matrix4x4_column_major(light.local_transform_rows)


def write_camera_record(writer: BinaryWriter, camera: CameraRecord) -> None:
    writer.write_u32(camera.entity_id)
    writer.write_u32(camera.name_offset)
    writer.write_u32(camera.flags)
    writer.write_u32(0)
    for value in camera.position:
        writer.write_f32(value)
    writer.write_f32(camera.fov_y_degrees)
    for value in camera.forward:
        writer.write_f32(value)
    writer.write_f32(camera.near_clip)
    for value in camera.up:
        writer.write_f32(value)
    writer.write_f32(camera.far_clip)
    for value in camera.right:
        writer.write_f32(value)
    writer.write_f32(camera.aspect_ratio)
    writer.write_matrix4x4_column_major(camera.local_transform_rows)


def write_color_management_record(writer: BinaryWriter, record: ColorManagementRecord) -> None:
    writer.write_u32(record.lut_texture_index)
    writer.write_u32(record.view_transform_name_offset)
    writer.write_u32(record.look_name_offset)
    writer.write_f32(record.exposure)
    writer.write_f32(record.gamma)
    writer.write_f32(record.shaper_min_stops)
    writer.write_f32(record.shaper_max_stops)
    writer.write_u32(record.lut_size)


def write_color_grade_lut_record(writer: BinaryWriter, record: ColorGradeLUTRecord) -> None:
    writer.write_u32(record.lut_uri_offset)
    writer.write_u32(record.lut_size)
    for value in record.domain_min:
        writer.write_f32(value)
    for value in record.domain_max:
        writer.write_f32(value)


def write_skeleton_record(writer: BinaryWriter, skeleton: SkeletonRecord) -> None:
    writer.write_u32(skeleton.entity_id)
    writer.write_u32(skeleton.name_offset)
    writer.write_u32(skeleton.first_joint_record_index)
    writer.write_u32(skeleton.joint_record_count)
    writer.write_u32(0)
    writer.write_u32(0)


def write_skeleton_joint_record(writer: BinaryWriter, joint: SkeletonJointRecord) -> None:
    writer.write_u32(joint.parent_joint_index)
    writer.write_u32(joint.joint_path_offset)
    writer.write_u32(joint.flags)
    writer.write_u32(0)
    writer.write_matrix4x4_column_major(joint.bind_transform_rows)
    writer.write_matrix4x4_column_major(joint.rest_transform_rows)


def write_skin_record(writer: BinaryWriter, skin: SkinRecord) -> None:
    writer.write_u32(skin.entity_id)
    writer.write_u32(skin.mesh_record_index)
    writer.write_u32(skin.skeleton_entity_id)
    writer.write_u32(skin.joint_count)
    writer.write_u32(skin.first_joint_mapping_index)
    writer.write_u32(skin.vertex_count)
    writer.write_u64(skin.joint_index_data_offset)
    writer.write_u64(skin.joint_weight_data_offset)
    writer.write_u32(0)
    writer.write_u32(0)


def write_skin_joint_mapping_record(writer: BinaryWriter, mapping: SkinJointMappingRecord) -> None:
    writer.write_u32(mapping.skeleton_joint_index)


def write_animation_clip_record(writer: BinaryWriter, clip: AnimationClipRecord) -> None:
    writer.write_u32(clip.name_offset)
    writer.write_f32(clip.duration)
    writer.write_u32(clip.first_channel_record_index)
    writer.write_u32(clip.channel_record_count)
    writer.write_u32(clip.flags)
    writer.write_u32(0)
    writer.write_u32(0)


def write_animation_channel_record(writer: BinaryWriter, channel: AnimationChannelRecord) -> None:
    writer.write_u32(channel.joint_path_offset)
    writer.write_u32(channel.first_translation_keyframe_index)
    writer.write_u32(channel.translation_keyframe_count)
    writer.write_u32(channel.first_rotation_keyframe_index)
    writer.write_u32(channel.rotation_keyframe_count)
    writer.write_u32(channel.flags)
    writer.write_u32(0)


def write_translation_keyframe_record(writer: BinaryWriter, keyframe: TranslationKeyframeRecord) -> None:
    writer.write_f32(keyframe.time)
    writer.write_f32(keyframe.value[0])
    writer.write_f32(keyframe.value[1])
    writer.write_f32(keyframe.value[2])
    writer.write_u32(0)


def write_rotation_keyframe_record(writer: BinaryWriter, keyframe: RotationKeyframeRecord) -> None:
    writer.write_f32(keyframe.time)
    writer.write_f32(keyframe.value[0])
    writer.write_f32(keyframe.value[1])
    writer.write_f32(keyframe.value[2])
    writer.write_f32(keyframe.value[3])


def write_vertex(
    writer: BinaryWriter,
    *,
    position: tuple[float, float, float],
    normal: tuple[float, float, float],
    tangent: tuple[float, float, float],
    handedness: float,
    uv0: tuple[float, float],
    uv1: tuple[float, float],
    color0: tuple[float, float, float, float],
) -> None:
    writer.write_f32(position[0])
    writer.write_f32(position[1])
    writer.write_f32(position[2])
    writer.write_u32(pack_normal(normal))
    writer.write_u32(pack_tangent(tangent, handedness))
    writer.write_u16(float_to_half_bits(uv0[0]))
    writer.write_u16(float_to_half_bits(uv0[1]))
    writer.write_u16(float_to_half_bits(uv1[0]))
    writer.write_u16(float_to_half_bits(uv1[1]))
    writer.write_u8(color_to_u8(color0[0]))
    writer.write_u8(color_to_u8(color0[1]))
    writer.write_u8(color_to_u8(color0[2]))
    writer.write_u8(color_to_u8(color0[3]))


def validation_path_for_output(output_path: Path) -> Path:
    return output_path.with_suffix(".validation.json")


def build_validation_payload(
    asset_name: str,
    validation_meshes: list[ValidationMesh],
    color_management_bake: Optional["ColorManagementBake"] = None,
) -> dict[str, object]:
    payload: dict[str, object] = {
        "format": "untold-validation",
        "version": 1,
        "asset_name": asset_name,
        "mesh_count": len(validation_meshes),
        "meshes": [
            {
                "name": mesh.name,
                "vertex_count": mesh.vertex_count,
                "index_count": mesh.index_count,
                "positions": [list(position) for position in mesh.positions],
                "normals": [list(normal) for normal in mesh.normals],
                "tangents": [
                    {
                        "xyz": list(tangent.xyz),
                        "handedness": tangent.handedness,
                    }
                    for tangent in mesh.tangents
                ],
                "uv0": [list(uv) for uv in mesh.uv0],
                "indices": mesh.indices,
                "edge_indices": mesh.edge_indices,
            }
            for mesh in validation_meshes
        ],
    }
    if color_management_bake is not None:
        payload["color_management"] = {
            "view_transform": color_management_bake.view_transform,
            "look": color_management_bake.look,
            "exposure": color_management_bake.exposure,
            "gamma": color_management_bake.gamma,
            "display_device": color_management_bake.display_device,
            "lut_size": color_management_bake.lut_size,
            "shaper_min_stops": color_management_bake.shaper_min_stops,
            "shaper_max_stops": color_management_bake.shaper_max_stops,
            "lut_uri": color_management_bake.lut_texture.uri,
        }
    return payload


def write_validation_file(
    output_path: Path,
    asset_name: str,
    validation_meshes: list[ValidationMesh],
    color_management_bake: Optional["ColorManagementBake"] = None,
) -> Path:
    validation_path = validation_path_for_output(output_path)
    payload = build_validation_payload(asset_name, validation_meshes, color_management_bake)
    validation_path.write_text(f"{json.dumps(payload, indent=2)}\n", encoding="utf-8")
    return validation_path


def blender_required() -> None:
    if bpy is None:
        raise RuntimeError("This exporter must run inside Blender so it can use bpy for USD import and mesh extraction.")


def normalize_blender_path(path: str) -> Path:
    raw_path = path
    if bpy is not None and path.startswith("//"):
        raw_path = bpy.path.abspath(path)
    return Path(raw_path).expanduser().resolve()


def matrix_rows_from_blender(matrix: object) -> list[list[float]]:
    return [[float(matrix[row][column]) for column in range(4)] for row in range(4)]


def vector3(value: object) -> tuple[float, float, float]:
    return (float(value[0]), float(value[1]), float(value[2]))


def vector4(value: object) -> tuple[float, float, float, float]:
    return (float(value[0]), float(value[1]), float(value[2]), float(value[3]))


def clear_scene() -> None:
    blender_required()
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_usd_asset(asset_path: Path) -> list[object]:
    blender_required()
    existing_ids = {obj.as_pointer() for obj in bpy.data.objects}
    result = bpy.ops.wm.usd_import(filepath=str(asset_path))
    if "FINISHED" not in result:
        raise RuntimeError(f"Blender USD import failed for {asset_path}")
    imported = [obj for obj in bpy.data.objects if obj.as_pointer() not in existing_ids]
    if not imported:
        raise RuntimeError(f"No objects were imported from {asset_path}")
    return imported


def load_blend_scene(asset_path: Path) -> list[object]:
    """Open a .blend file in place of the factory-startup scene and return its objects.

    Unlike import_usd_asset, this replaces the whole scene (equivalent to
    File > Open) rather than merging into it, so there is no existing-vs-new
    object bookkeeping to do.
    """
    blender_required()
    result = bpy.ops.wm.open_mainfile(filepath=str(asset_path))
    if "FINISHED" not in result:
        raise RuntimeError(f"Blender failed to open {asset_path}")
    scene_objects = list(bpy.context.scene.objects)
    if not scene_objects:
        raise RuntimeError(f"No objects were found in {asset_path}")
    return scene_objects


def load_source_objects(asset_path: Path) -> list[object]:
    if asset_path.suffix.lower() == ".blend":
        return load_blend_scene(asset_path)
    clear_scene()
    return import_usd_asset(asset_path)


def get_scene_unit_scale() -> float:
    """Return the source file's Blender-units-to-meters ratio (Scene Properties > Units > Unit Scale).

    Some asset packs are modeled with raw coordinates in centimeters (or another
    non-meter scale) and rely on this scene setting purely for Blender's own UI
    to display "nice" meter values; the raw mesh/object coordinates never get
    rescaled by it. The engine assumes 1 exported unit = 1 meter, so this ratio
    must be baked into exported geometry explicitly.
    """
    if bpy is None:
        return 1.0
    scene = getattr(bpy.context, "scene", None)
    if scene is None:
        return 1.0
    try:
        return float(scene.unit_settings.scale_length)
    except (AttributeError, TypeError, ValueError):
        return 1.0


def make_export_orientation_matrix(source_orientation: str, unit_scale: float = 1.0) -> object:
    blender_required()
    if axis_conversion is None or Matrix is None or Vector is None:
        raise RuntimeError("Blender axis conversion helpers are unavailable in this environment")
    source_axes = {
        "blender-native": ("-Y", "Z"),
        "engine-oriented": ("Z", "Y"),
    }
    if source_orientation not in source_axes:
        raise RuntimeError(f"Unsupported source orientation: {source_orientation}")
    from_forward, from_up = source_axes[source_orientation]
    rotation = axis_conversion(
        from_forward=from_forward,
        from_up=from_up,
        to_forward="Z",
        to_up="Y",
    ).to_4x4()
    if unit_scale != 1.0:
        rotation = Matrix.Scale(unit_scale, 4) @ rotation
    return rotation


def resolve_conversion_matrix(convert_orientation: bool, source_orientation: str) -> Optional[object]:
    """Build the matrix export code should pass through, folding in unit-scale correction.

    Axis conversion stays opt-in via --convert-orientation, but unit-scale
    correction is not a style choice: it is applied automatically whenever the
    source file's Unit Scale differs from 1.0, regardless of that flag.
    """
    unit_scale = get_scene_unit_scale()
    if not convert_orientation and unit_scale == 1.0:
        return None
    axis_key = source_orientation if convert_orientation else "engine-oriented"
    return make_export_orientation_matrix(axis_key, unit_scale)


def transform_point(matrix: object, point: tuple[float, float, float]) -> tuple[float, float, float]:
    result = matrix @ Vector(point)
    return (float(result.x), float(result.y), float(result.z))


def transform_direction(matrix: object, direction: tuple[float, float, float], fallback: tuple[float, float, float]) -> tuple[float, float, float]:
    rotation_scale = matrix.to_3x3()
    result = rotation_scale @ Vector(direction)
    return normalize3((float(result.x), float(result.y), float(result.z)), fallback)


def transform_matrix_rows(matrix_rows: list[list[float]], conversion_matrix: object) -> list[list[float]]:
    source_matrix = Matrix(matrix_rows)
    converted = conversion_matrix @ source_matrix @ conversion_matrix.inverted()
    return matrix_rows_from_blender(converted)


def transform_bounds(points: list[tuple[float, float, float]], conversion_matrix: object) -> AABB:
    return aabb_from_points(transform_point(conversion_matrix, point) for point in points)


def pack_joint_indices(indices: list[int]) -> bytes:
    padded = list(indices[:4]) + [0] * max(0, 4 - len(indices))
    return struct.pack("<4H", *padded[:4])


def pack_joint_weights(weights: list[float]) -> bytes:
    padded = list(weights[:4]) + [0.0] * max(0, 4 - len(weights))
    return struct.pack("<4f", *padded[:4])


def normalize_weights(weights: list[float]) -> list[float]:
    total = sum(weights)
    if total <= 1.0e-8:
        return [0.0, 0.0, 0.0, 0.0]
    return [weight / total for weight in weights]


def armature_for_mesh(mesh_object: object) -> Optional[object]:
    parent = getattr(mesh_object, "parent", None)
    if parent is not None and getattr(parent, "type", None) == "ARMATURE":
        return parent

    for modifier in getattr(mesh_object, "modifiers", []):
        if getattr(modifier, "type", None) == "ARMATURE" and getattr(modifier, "object", None) is not None:
            return modifier.object
    return None


def bone_path(bone: object) -> str:
    names: list[str] = [bone.name]
    parent = bone.parent
    while parent is not None:
        names.append(parent.name)
        parent = parent.parent
    return "/" + "/".join(reversed(names))


def extract_skeleton(armature_object: object, entity_name: str, conversion_matrix: Optional[object]) -> ExportedSkeleton:
    bones = list(getattr(armature_object.data, "bones", []))
    bone_index_by_name = {bone.name: index for index, bone in enumerate(bones)}
    joints: list[ExportedSkeletonJoint] = []

    for bone in bones:
        bind_matrix = bone.matrix_local.copy()
        if bone.parent is not None:
            rest_local = bone.parent.matrix_local.inverted() @ bone.matrix_local
        else:
            rest_local = bone.matrix_local.copy()

        bind_rows = matrix_rows_from_blender(bind_matrix)
        rest_rows = matrix_rows_from_blender(rest_local)
        if conversion_matrix is not None:
            bind_rows = transform_matrix_rows(bind_rows, conversion_matrix)
            rest_rows = transform_matrix_rows(rest_rows, conversion_matrix)

        joints.append(
            ExportedSkeletonJoint(
                name=bone.name,
                path=bone_path(bone),
                parent_index=bone_index_by_name.get(bone.parent.name, INVALID_INDEX) if bone.parent is not None else INVALID_INDEX,
                bind_transform_rows=bind_rows,
                rest_transform_rows=rest_rows,
            )
        )

    return ExportedSkeleton(entity_name=entity_name, name=armature_object.name, joints=joints)


def extract_skin_binding(mesh_object: object) -> Optional[tuple[str, list[int], list[tuple[int, int, int, int]], list[tuple[float, float, float, float]]]]:
    armature_object = armature_for_mesh(mesh_object)
    if armature_object is None:
        return None

    bones = list(getattr(armature_object.data, "bones", []))
    if not bones:
        return None

    bone_index_by_name = {bone.name: index for index, bone in enumerate(bones)}
    group_name_by_index = {group.index: group.name for group in getattr(mesh_object, "vertex_groups", [])}

    per_vertex_global_indices: list[list[int]] = []
    per_vertex_weights: list[list[float]] = []
    used_skeleton_indices: set[int] = set()

    for vertex in getattr(mesh_object.data, "vertices", []):
        influences: list[tuple[int, float]] = []
        for assignment in getattr(vertex, "groups", []):
            group_name = group_name_by_index.get(assignment.group)
            if group_name is None:
                continue
            skeleton_index = bone_index_by_name.get(group_name)
            if skeleton_index is None:
                continue
            weight = float(assignment.weight)
            if weight <= 0.0:
                continue
            influences.append((skeleton_index, weight))

        influences.sort(key=lambda item: item[1], reverse=True)
        influences = influences[:4]
        if not influences:
            per_vertex_global_indices.append([0, 0, 0, 0])
            per_vertex_weights.append([0.0, 0.0, 0.0, 0.0])
            continue

        used_skeleton_indices.update(index for index, _ in influences)
        indices = [index for index, _ in influences]
        weights = normalize_weights([weight for _, weight in influences])[:len(indices)]
        per_vertex_global_indices.append(indices + [0] * (4 - len(indices)))
        per_vertex_weights.append(weights + [0.0] * (4 - len(weights)))

    if not used_skeleton_indices:
        return None

    skin_to_skeleton_map = sorted(used_skeleton_indices)
    skeleton_to_skin = {skeleton_index: skin_index for skin_index, skeleton_index in enumerate(skin_to_skeleton_map)}

    packed_indices: list[tuple[int, int, int, int]] = []
    packed_weights: list[tuple[float, float, float, float]] = []
    for global_indices, weights in zip(per_vertex_global_indices, per_vertex_weights):
        local_indices = [
            skeleton_to_skin.get(global_index, 0) if weight > 0.0 else 0
            for global_index, weight in zip(global_indices, weights)
        ]
        packed_indices.append((local_indices[0], local_indices[1], local_indices[2], local_indices[3]))
        packed_weights.append((weights[0], weights[1], weights[2], weights[3]))

    return armature_object.name, skin_to_skeleton_map, packed_indices, packed_weights


def aabb_corners(bounds: AABB) -> list[tuple[float, float, float]]:
    minimum = bounds.minimum
    maximum = bounds.maximum
    return [
        (minimum[0], minimum[1], minimum[2]),
        (minimum[0], minimum[1], maximum[2]),
        (minimum[0], maximum[1], minimum[2]),
        (minimum[0], maximum[1], maximum[2]),
        (maximum[0], minimum[1], minimum[2]),
        (maximum[0], minimum[1], maximum[2]),
        (maximum[0], maximum[1], minimum[2]),
        (maximum[0], maximum[1], maximum[2]),
    ]


def choose_mesh_objects(imported_objects: list[object], mesh_name: Optional[str]) -> list[object]:
    mesh_objects = [obj for obj in imported_objects if getattr(obj, "type", None) == "MESH"]
    if mesh_name:
        for obj in mesh_objects:
            if obj.name == mesh_name:
                return [obj]
        raise RuntimeError(f"Mesh named '{mesh_name}' was not found in imported objects")
    if not mesh_objects:
        raise RuntimeError("No mesh objects were found in the imported asset")
    return sorted(mesh_objects, key=lambda obj: obj.name)


def choose_export_objects(imported_objects: list[object], mesh_name: Optional[str]) -> list[object]:
    mesh_objects = choose_mesh_objects(imported_objects, mesh_name)
    selected_ids: set[int] = set()
    selected_objects: list[object] = []

    def add_object_and_ancestors(obj: object) -> None:
        current = obj
        chain: list[object] = []
        while current is not None:
            pointer = current.as_pointer()
            if pointer in selected_ids:
                break
            chain.append(current)
            current = getattr(current, "parent", None)

        for candidate in reversed(chain):
            pointer = candidate.as_pointer()
            if pointer in selected_ids:
                continue
            selected_ids.add(pointer)
            selected_objects.append(candidate)

    for mesh_object in mesh_objects:
        add_object_and_ancestors(mesh_object)

    return selected_objects


def include_linked_armatures(export_objects: list[object]) -> list[object]:
    selected_ids = {obj.as_pointer() for obj in export_objects}
    selected_objects = list(export_objects)

    def add_object_and_ancestors(obj: object) -> None:
        current = obj
        chain: list[object] = []
        while current is not None:
            pointer = current.as_pointer()
            if pointer in selected_ids:
                break
            chain.append(current)
            current = getattr(current, "parent", None)

        for candidate in reversed(chain):
            pointer = candidate.as_pointer()
            if pointer in selected_ids:
                continue
            selected_ids.add(pointer)
            selected_objects.append(candidate)

    mesh_objects = [obj for obj in export_objects if getattr(obj, "type", None) == "MESH"]
    for mesh_object in mesh_objects:
        armature_object = armature_for_mesh(mesh_object)
        if armature_object is not None:
            add_object_and_ancestors(armature_object)

    return selected_objects


def prepare_export_objects_from_blender_objects(
    objects: list[object],
    mesh_name: Optional[str] = None,
) -> list[object]:
    """Apply the common Blender-object export preparation path.

    Used by both the CLI importer path and the Blender add-on path so object
    selection, linked armatures, and material splitting stay consistent.
    """
    export_objects = choose_export_objects(objects, mesh_name)
    export_objects = include_linked_armatures(export_objects)
    export_objects = split_blender_objects_by_material(export_objects)
    return export_objects


def _object_transform_rows(
    obj: object,
    conversion_matrix: Optional[object],
    *,
    world: bool = True,
) -> list[list[float]]:
    matrix = obj.matrix_world if world else obj.matrix_local
    rows = matrix_rows_from_blender(matrix)
    if conversion_matrix is not None:
        rows = transform_matrix_rows(rows, conversion_matrix)
    return rows


def _semantic_camera_transform_rows(obj: object, conversion_matrix: Optional[object]) -> list[list[float]]:
    matrix = obj.matrix_world
    position = vector3(matrix.translation)
    right = transform_direction(matrix, (1.0, 0.0, 0.0), (1.0, 0.0, 0.0))
    up = transform_direction(matrix, (0.0, 1.0, 0.0), (0.0, 1.0, 0.0))
    forward = transform_direction(matrix, (0.0, 0.0, -1.0), (0.0, 0.0, 1.0))

    if conversion_matrix is not None:
        position = transform_point(conversion_matrix, position)
        right = transform_direction(conversion_matrix, right, (1.0, 0.0, 0.0))
        up = transform_direction(conversion_matrix, up, (0.0, 1.0, 0.0))
        forward = transform_direction(conversion_matrix, forward, (0.0, 0.0, 1.0))

    return [
        [right[0], up[0], forward[0], position[0]],
        [right[1], up[1], forward[1], position[1]],
        [right[2], up[2], forward[2], position[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _semantic_light_transform_rows(
    obj: object,
    conversion_matrix: Optional[object],
    light_type: int,
) -> list[list[float]]:
    matrix = obj.matrix_world
    position = vector3(matrix.translation)
    right = transform_direction(matrix, (1.0, 0.0, 0.0), (1.0, 0.0, 0.0))
    up = transform_direction(matrix, (0.0, 1.0, 0.0), (0.0, 1.0, 0.0))

    if light_type == LIGHT_TYPE_DIRECTIONAL:
        forward = transform_direction(matrix, (0.0, 0.0, 1.0), (0.0, 0.0, 1.0))
    elif light_type == LIGHT_TYPE_AREA:
        forward = transform_direction(matrix, (0.0, 0.0, 1.0), (0.0, 0.0, 1.0))
    elif light_type == LIGHT_TYPE_SPOT:
        forward = transform_direction(matrix, (0.0, 0.0, 1.0), (0.0, 0.0, 1.0))
    else:
        forward = transform_direction(matrix, (0.0, 0.0, 1.0), (0.0, 0.0, 1.0))

    if conversion_matrix is not None:
        position = transform_point(conversion_matrix, position)
        right = transform_direction(conversion_matrix, right, (1.0, 0.0, 0.0))
        up = transform_direction(conversion_matrix, up, (0.0, 1.0, 0.0))
        forward = transform_direction(conversion_matrix, forward, (0.0, 0.0, 1.0))

    return [
        [right[0], up[0], forward[0], position[0]],
        [right[1], up[1], forward[1], position[1]],
        [right[2], up[2], forward[2], position[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _position_from_matrix_rows(matrix_rows: list[list[float]]) -> tuple[float, float, float]:
    return (matrix_rows[0][3], matrix_rows[1][3], matrix_rows[2][3])


def _direction_from_matrix_rows(
    matrix_rows: list[list[float]],
    direction: tuple[float, float, float],
    fallback: tuple[float, float, float],
) -> tuple[float, float, float]:
    return transform_direction_rows(matrix_rows, direction, fallback)


def _blender_light_type(light_data: object) -> int:
    light_type = getattr(light_data, "type", "")
    if light_type == "SUN":
        return LIGHT_TYPE_DIRECTIONAL
    if light_type == "SPOT":
        return LIGHT_TYPE_SPOT
    if light_type == "AREA":
        return LIGHT_TYPE_AREA
    return LIGHT_TYPE_POINT


def _blender_light_radius(light_data: object, light_type: int) -> float:
    if light_type == LIGHT_TYPE_AREA:
        shape = getattr(light_data, "shape", "SQUARE")
        if shape == "RECTANGLE":
            return max(float(getattr(light_data, "size", 1.0)), float(getattr(light_data, "size_y", 1.0)), 0.001)
        return max(float(getattr(light_data, "size", 1.0)), 0.001)
    return max(float(getattr(light_data, "shadow_soft_size", 1.0)), 0.001)


def _blender_light_area_size(light_data: object) -> tuple[float, float]:
    shape = getattr(light_data, "shape", "SQUARE")
    width = max(float(getattr(light_data, "size", 1.0)), 0.001)
    height = max(float(getattr(light_data, "size_y", width if shape == "RECTANGLE" else width)), 0.001)
    return (width, height)


def _blender_light_source_exposure(light_data: object) -> float:
    value = getattr(light_data, "exposure", 0.0)
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _blender_light_influence_range(light_data: object, light_type: int) -> float:
    if light_type == LIGHT_TYPE_DIRECTIONAL:
        return 0.0
    if not bool(getattr(light_data, "use_custom_distance", False)):
        return 0.0
    try:
        return max(float(getattr(light_data, "cutoff_distance", 0.0)), 0.0)
    except (TypeError, ValueError):
        return 0.0


def _blender_light_casts_shadow(light_data: object) -> bool:
    return bool(getattr(light_data, "use_shadow", True))


def _blender_light_engine_intensity(light_data: object) -> float:
    power = max(float(getattr(light_data, "energy", 1.0)), 0.0)
    exposure = _blender_light_source_exposure(light_data)
    return power * math.pow(2.0, exposure)


def _blender_light_color(light_data: object) -> tuple[float, float, float]:
    color = getattr(light_data, "color", None)
    if color is None:
        return (1.0, 1.0, 1.0)
    try:
        return (
            clamp(float(color[0]), 0.0, 1.0),
            clamp(float(color[1]), 0.0, 1.0),
            clamp(float(color[2]), 0.0, 1.0),
        )
    except (TypeError, ValueError, IndexError):
        return (1.0, 1.0, 1.0)


def extract_scene_payload_from_objects(
    objects: list[object],
    *,
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    include_scene_payload: bool = True,
) -> tuple[list[ExportedLight], list[ExportedCamera]]:
    blender_required()
    if not include_scene_payload:
        return [], []

    conversion_matrix = resolve_conversion_matrix(convert_orientation, source_orientation)
    lights: list[ExportedLight] = []
    cameras: list[ExportedCamera] = []

    for obj in objects:
        object_type = getattr(obj, "type", None)
        if object_type == "LIGHT":
            light_data = obj.data
            light_type = _blender_light_type(light_data)
            transform_rows = _semantic_light_transform_rows(obj, conversion_matrix, light_type)
            spot_size = max(float(getattr(light_data, "spot_size", math.radians(45.0))), math.radians(0.1))
            spot_blend = clamp(float(getattr(light_data, "spot_blend", 0.15)), 0.0, 1.0)
            # Blender spot_size is the full cone angle; Untold stores the
            # half-angle consumed by cos(theta) and the shadow projection.
            outer_cone = math.degrees(spot_size * 0.5)
            inner_cone = max(0.1, outer_cone * (1.0 - spot_blend))
            influence_range = _blender_light_influence_range(light_data, light_type)
            lights.append(
                ExportedLight(
                    entity_name=obj.name,
                    light_type=light_type,
                    color=_blender_light_color(light_data),
                    intensity=_blender_light_engine_intensity(light_data),
                    position=_position_from_matrix_rows(transform_rows),
                    radius=_blender_light_radius(light_data, light_type),
                    range=influence_range,
                    direction=_direction_from_matrix_rows(transform_rows, (0.0, 0.0, -1.0), (0.0, -1.0, 0.0)),
                    falloff=0.5,
                    right=_direction_from_matrix_rows(transform_rows, (1.0, 0.0, 0.0), (1.0, 0.0, 0.0)),
                    inner_cone=inner_cone,
                    up=_direction_from_matrix_rows(transform_rows, (0.0, 1.0, 0.0), (0.0, 1.0, 0.0)),
                    outer_cone=outer_cone,
                    area_size=_blender_light_area_size(light_data),
                    source_power=max(float(getattr(light_data, "energy", 1.0)), 0.0),
                    source_exposure=_blender_light_source_exposure(light_data),
                    casts_shadow=_blender_light_casts_shadow(light_data),
                    local_transform_rows=transform_rows,
                )
            )
        elif object_type == "CAMERA":
            camera_data = obj.data
            transform_rows = _semantic_camera_transform_rows(obj, conversion_matrix)
            sensor_fit = getattr(camera_data, "sensor_fit", "AUTO")
            sensor_width = max(float(getattr(camera_data, "sensor_width", 36.0)), 0.001)
            sensor_height = max(float(getattr(camera_data, "sensor_height", 24.0)), 0.001)
            aspect = sensor_width / sensor_height
            if sensor_fit == "VERTICAL":
                aspect = sensor_height / sensor_width
            cameras.append(
                ExportedCamera(
                    entity_name=obj.name,
                    position=_position_from_matrix_rows(transform_rows),
                    forward=_direction_from_matrix_rows(transform_rows, (0.0, 0.0, 1.0), (0.0, 0.0, 1.0)),
                    up=_direction_from_matrix_rows(transform_rows, (0.0, 1.0, 0.0), (0.0, 1.0, 0.0)),
                    right=_direction_from_matrix_rows(transform_rows, (1.0, 0.0, 0.0), (1.0, 0.0, 0.0)),
                    fov_y_degrees=math.degrees(float(getattr(camera_data, "angle_y", getattr(camera_data, "angle", math.radians(50.0))))),
                    near_clip=max(float(getattr(camera_data, "clip_start", 0.1)), 0.001),
                    far_clip=max(float(getattr(camera_data, "clip_end", 1000.0)), 0.001),
                    aspect_ratio=aspect,
                    local_transform_rows=transform_rows,
                )
            )

    return lights, cameras


def triangulate_mesh(mesh_data: object) -> None:
    blender_required()
    bm = bmesh.new()
    try:
        bm.from_mesh(mesh_data)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(mesh_data)
    finally:
        bm.free()


def resolve_texture_from_socket(input_socket: object, asset_path: Path) -> Optional[ExportedTexture]:
    return _resolve_texture_from_socket(input_socket, asset_path, visited_nodes=set(), channel=TEXTURE_CHANNEL_R)


def _resolve_texture_from_socket(input_socket: object, asset_path: Path, visited_nodes: set[int], channel: int) -> Optional[ExportedTexture]:
    if not getattr(input_socket, "is_linked", False):
        return None

    source_link = input_socket.links[0]
    source_node = source_link.from_node
    source_socket = getattr(source_link, "from_socket", None)
    source_node_id = id(source_node)
    if source_node_id in visited_nodes:
        return None
    visited_nodes.add(source_node_id)

    if source_node.bl_idname == "ShaderNodeTexImage" and source_node.image is not None:
        texture_channel = texture_channel_from_socket_name(getattr(source_socket, "name", ""), channel)
        image = source_node.image
        image_path = bpy.path.abspath(image.filepath, library=image.library) if bpy is not None else image.filepath
        texture_path = Path(image_path)
        if not texture_path.is_absolute():
            texture_path = (asset_path.parent / texture_path).resolve()
        try:
            uri = os.path.relpath(texture_path, asset_path.parent)
        except ValueError:
            uri = str(texture_path)
        width = int(image.size[0]) if len(image.size) > 0 else 0
        height = int(image.size[1]) if len(image.size) > 1 else 0
        return ExportedTexture(
            name=texture_path.name or image.name,
            uri=uri,
            width=width,
            height=height,
            mip_count=1 if width > 0 and height > 0 else 0,
            source_path=texture_path,
            source_image_name=getattr(image, "name", None),
            channel=texture_channel,
        )

    if source_node.bl_idname in {"ShaderNodeSeparateColor", "ShaderNodeSeparateRGB"}:
        texture_channel = texture_channel_from_socket_name(getattr(source_socket, "name", ""), channel)
        input_name = "Color" if source_node.bl_idname == "ShaderNodeSeparateColor" else "Image"
        nested_input = source_node.inputs.get(input_name)
        if nested_input is not None:
            return _resolve_texture_from_socket(nested_input, asset_path, visited_nodes, texture_channel)

    passthrough_input_names = {
        "ShaderNodeNormalMap":      ["Color"],
        "ShaderNodeRGBToBW":        ["Color"],
        "NodeReroute":              ["Input"],
        # Color-correction nodes — the texture passes through their Color input.
        "ShaderNodeGamma":          ["Color"],
        "ShaderNodeBrightContrast": ["Color"],
        "ShaderNodeHueSaturation":  ["Color"],
        "ShaderNodeInvert":         ["Color"],
        "ShaderNodeCurveRGB":       ["Color"],
        "ShaderNodeCurveFloat":     ["Value"],
        # Mix nodes — try both color inputs; returns whichever one traces to a texture.
        "ShaderNodeMixRGB":         ["Color1", "Color2"],
        "ShaderNodeMix":            ["A", "B"],        # Blender 4+ name
    }
    input_names = passthrough_input_names.get(source_node.bl_idname, [])
    for input_name in input_names:
        nested_input = source_node.inputs.get(input_name)
        if nested_input is None:
            continue
        resolved = _resolve_texture_from_socket(nested_input, asset_path, visited_nodes, channel)
        if resolved is not None:
            return resolved

    return None


# --- Material graph fidelity analysis (see docs/API/UsingBlenderAddon.md#material-fidelity) ---
#
# Classifies each material by how faithfully the exporter can represent its node
# graph, so exports can report exactly which materials will diverge from Blender:
#   supported  — every reachable node is represented exactly.
#   bakeable   — static nodes the exporter drops or only traces through; an
#                export-time Cycles bake (Milestone 2+) can capture them.
#   unbakeable — view-dependent or animated inputs; no baked texture can
#                represent them.

MATERIAL_GRAPH_SUPPORTED = "supported"
MATERIAL_GRAPH_BAKEABLE = "bakeable"
MATERIAL_GRAPH_UNBAKEABLE = "unbakeable"

_GRAPH_FAITHFUL_NODE_IDS = {
    "ShaderNodeOutputMaterial",
    "ShaderNodeBsdfPrincipled",
    "ShaderNodeTexImage",
    "ShaderNodeNormalMap",
    "ShaderNodeSeparateColor",
    "ShaderNodeSeparateRGB",
    "ShaderNodeUVMap",
    "NodeReroute",
    "ShaderNodeGroup",
    "NodeGroupInput",
    "NodeGroupOutput",
    # extract_material reads these directly (Displacement -> height texture/Scale/Midlevel,
    # or Bump -> height texture/Distance as a fallback) — see the height/displacement
    # detection block. Their own Height/Scale/Midlevel/Distance inputs are still walked and
    # classified individually below; only the node type itself is exempted here.
    "ShaderNodeDisplacement",
    "ShaderNodeBump",
}

# Traced through by _resolve_texture_from_socket, but their math is dropped.
_GRAPH_TRACED_THROUGH_NODE_IDS = {
    "ShaderNodeMix",
    "ShaderNodeMixRGB",
    "ShaderNodeRGBToBW",
    "ShaderNodeGamma",
    "ShaderNodeBrightContrast",
    "ShaderNodeHueSaturation",
    "ShaderNodeInvert",
    "ShaderNodeCurveRGB",
    "ShaderNodeCurveFloat",
}

_GRAPH_UNBAKEABLE_NODE_IDS = {
    "ShaderNodeFresnel": "view-dependent",
    "ShaderNodeLayerWeight": "view-dependent",
    "ShaderNodeCameraData": "view-dependent",
    "ShaderNodeLightPath": "depends on the active render ray",
}

# Nodes whose fidelity depends on which output socket feeds the graph.
_GRAPH_UNBAKEABLE_OUTPUT_SOCKETS = {
    "ShaderNodeTexCoord": {"Camera", "Window", "Reflection"},
    "ShaderNodeNewGeometry": {"Incoming"},
}
_GRAPH_FAITHFUL_OUTPUT_SOCKETS = {
    "ShaderNodeTexCoord": {"UV"},
}


@dataclass
class MaterialGraphFinding:
    node_name: str
    node_type: str
    category: str  # MATERIAL_GRAPH_BAKEABLE or MATERIAL_GRAPH_UNBAKEABLE
    reason: str


@dataclass
class MaterialGraphAnalysis:
    material_name: str
    classification: str
    findings: list[MaterialGraphFinding]


def _socket_is_identity(node: object, socket_name: str, identity_value, tolerance: float = 1.0e-6) -> bool:
    """True when an input socket is unlinked and holds its identity value."""
    socket = node.inputs.get(socket_name) if getattr(node, "inputs", None) is not None else None
    if socket is None:
        return True
    if getattr(socket, "is_linked", False):
        return False
    value = getattr(socket, "default_value", None)
    if value is None:
        return True
    try:
        if isinstance(identity_value, tuple):
            return all(abs(float(value[i]) - identity_value[i]) <= tolerance for i in range(len(identity_value)))
        return abs(float(value) - float(identity_value)) <= tolerance
    except (TypeError, ValueError, IndexError):
        return False


def _node_is_identity_configured(node: object) -> bool:
    """True for color/vector nodes configured so they pass their input through unchanged."""
    node_id = node.bl_idname
    if node_id == "ShaderNodeMapping":
        return (
            _socket_is_identity(node, "Location", (0.0, 0.0, 0.0))
            and _socket_is_identity(node, "Rotation", (0.0, 0.0, 0.0))
            and _socket_is_identity(node, "Scale", (1.0, 1.0, 1.0))
        )
    if node_id == "ShaderNodeGamma":
        return _socket_is_identity(node, "Gamma", 1.0)
    if node_id == "ShaderNodeBrightContrast":
        return _socket_is_identity(node, "Bright", 0.0) and _socket_is_identity(node, "Contrast", 0.0)
    if node_id == "ShaderNodeHueSaturation":
        return (
            _socket_is_identity(node, "Hue", 0.5)
            and _socket_is_identity(node, "Saturation", 1.0)
            and _socket_is_identity(node, "Value", 1.0)
        )
    if node_id == "ShaderNodeInvert":
        return _socket_is_identity(node, "Fac", 0.0)
    return False


def _classify_graph_node(node: object, from_socket_name: str) -> Optional[MaterialGraphFinding]:
    node_id = node.bl_idname
    node_name = getattr(node, "name", "") or node_id

    unbakeable_sockets = _GRAPH_UNBAKEABLE_OUTPUT_SOCKETS.get(node_id)
    if unbakeable_sockets is not None and from_socket_name in unbakeable_sockets:
        return MaterialGraphFinding(node_name, node_id, MATERIAL_GRAPH_UNBAKEABLE, f"'{from_socket_name}' output is view-dependent")
    faithful_sockets = _GRAPH_FAITHFUL_OUTPUT_SOCKETS.get(node_id)
    if faithful_sockets is not None:
        if from_socket_name in faithful_sockets:
            return None
        return MaterialGraphFinding(
            node_name, node_id, MATERIAL_GRAPH_BAKEABLE,
            f"'{from_socket_name}' coordinates are frozen into UV space when baked",
        )

    unbakeable_reason = _GRAPH_UNBAKEABLE_NODE_IDS.get(node_id)
    if unbakeable_reason is not None:
        return MaterialGraphFinding(node_name, node_id, MATERIAL_GRAPH_UNBAKEABLE, unbakeable_reason)

    if node_id in _GRAPH_FAITHFUL_NODE_IDS:
        return None
    if _node_is_identity_configured(node):
        return None
    if node_id in _GRAPH_TRACED_THROUGH_NODE_IDS or node_id == "ShaderNodeMapping":
        return MaterialGraphFinding(node_name, node_id, MATERIAL_GRAPH_BAKEABLE, "node math is dropped by the exporter")
    return MaterialGraphFinding(node_name, node_id, MATERIAL_GRAPH_BAKEABLE, "not evaluated by the exporter")


def _material_output_node(node_tree: object) -> Optional[object]:
    fallback = None
    for node in getattr(node_tree, "nodes", []):
        if node.bl_idname != "ShaderNodeOutputMaterial":
            continue
        if getattr(node, "is_active_output", False):
            return node
        if fallback is None:
            fallback = node
    return fallback


def _principled_bsdf_node(node_tree: object) -> Optional[object]:
    return next((node for node in getattr(node_tree, "nodes", []) if node.bl_idname == "ShaderNodeBsdfPrincipled"), None)


def _group_output_node(node_tree: object) -> Optional[object]:
    for node in getattr(node_tree, "nodes", []):
        if node.bl_idname == "NodeGroupOutput":
            return node
    return None


def _graph_node_key(node: object) -> int:
    """Stable identity for a graph node.

    bpy creates a fresh Python wrapper on every node access, so id() differs
    between two lookups of the same node; as_pointer() is stable.
    """
    as_pointer = getattr(node, "as_pointer", None)
    if callable(as_pointer):
        try:
            return as_pointer()
        except Exception:
            pass
    return id(node)


def _node_tree_is_animated(node_tree: object) -> bool:
    animation_data = getattr(node_tree, "animation_data", None)
    if animation_data is None:
        return False
    if getattr(animation_data, "action", None) is not None:
        return True
    return bool(getattr(animation_data, "drivers", None))


def _walk_material_graph(
    node: object,
    from_socket_name: str,
    findings: list[MaterialGraphFinding],
    visited_nodes: set[int],
    classified: set[tuple[int, str]],
    stop_node_ids: Optional[set[int]] = None,
    image_sizes: Optional[list[int]] = None,
) -> None:
    muted = getattr(node, "mute", False)
    node_key = _graph_node_key(node)
    classification_key = (node_key, from_socket_name)
    if not muted and classification_key not in classified:
        classified.add(classification_key)
        finding = _classify_graph_node(node, from_socket_name)
        if finding is not None:
            findings.append(finding)

    if stop_node_ids is not None and node_key in stop_node_ids:
        return
    if node_key in visited_nodes:
        return
    visited_nodes.add(node_key)

    if image_sizes is not None and node.bl_idname == "ShaderNodeTexImage" and node.image is not None:
        size = getattr(node.image, "size", None)
        if size is not None and size[0] > 0 and size[1] > 0:
            image_sizes.append(max(int(size[0]), int(size[1])))

    group_tree = getattr(node, "node_tree", None) if node.bl_idname == "ShaderNodeGroup" else None
    if group_tree is not None:
        group_output = _group_output_node(group_tree)
        if group_output is not None:
            _walk_material_graph(group_output, "", findings, visited_nodes, classified, stop_node_ids, image_sizes)

    inputs = getattr(node, "inputs", None)
    if inputs is None:
        return
    for socket in inputs.values():
        if not getattr(socket, "is_linked", False):
            continue
        for link in getattr(socket, "links", []):
            source_socket_name = getattr(getattr(link, "from_socket", None), "name", "") or ""
            _walk_material_graph(
                link.from_node, source_socket_name, findings, visited_nodes, classified, stop_node_ids, image_sizes
            )


def analyze_material(material: object) -> MaterialGraphAnalysis:
    """Classify how faithfully the exporter can represent a material's node graph.

    Walks only nodes reachable from the active Material Output so deliberately
    unconnected nodes (e.g. the AO textures found by _detect_occlusion_texture)
    are not flagged.
    """
    material_name = getattr(material, "name", "<unnamed>")
    node_tree = getattr(material, "node_tree", None)
    if node_tree is None:
        return MaterialGraphAnalysis(material_name, MATERIAL_GRAPH_SUPPORTED, [])

    findings: list[MaterialGraphFinding] = []
    if _node_tree_is_animated(node_tree):
        findings.append(
            MaterialGraphFinding(material_name, "node_tree", MATERIAL_GRAPH_UNBAKEABLE, "animated node values (keyframes or drivers)")
        )

    output_node = _material_output_node(node_tree)
    if output_node is not None:
        _walk_material_graph(output_node, "", findings, visited_nodes=set(), classified=set())

    if any(finding.category == MATERIAL_GRAPH_UNBAKEABLE for finding in findings):
        classification = MATERIAL_GRAPH_UNBAKEABLE
    elif findings:
        classification = MATERIAL_GRAPH_BAKEABLE
    else:
        classification = MATERIAL_GRAPH_SUPPORTED
    return MaterialGraphAnalysis(material_name, classification, findings)


def _mesh_uv_warning(mesh_data: object) -> Optional[str]:
    """Return a warning string when the mesh has no usable UVs for baking."""
    uv_layers = getattr(mesh_data, "uv_layers", None)
    if uv_layers is None or len(uv_layers) == 0:
        return "has no UV map"
    if not _HAS_NUMPY:
        return None
    try:
        layer_data = uv_layers[0].data
        uv_flat = np.empty(len(layer_data) * 2, dtype=np.float32)
        layer_data.foreach_get("uv", uv_flat)
        uvs = uv_flat.reshape(-1, 2)
        if len(uvs) > 0 and np.all(np.ptp(uvs, axis=0) < 1.0e-6):
            return "has a collapsed UV map (all UVs identical)"
    except Exception:
        return None
    return None


@dataclass
class MaterialFidelityReport:
    analyses_by_name: dict[str, MaterialGraphAnalysis]
    uv_warnings: list[str]  # pre-formatted, e.g. "Warning: mesh 'X' has no UV map; ..."


def compute_material_fidelity(mesh_objects: Iterable[object]) -> MaterialFidelityReport:
    """Classify every material used by mesh_objects as supported/bakeable/unbakeable,
    and flag meshes that need a UV map for baking but don't have one.

    Shared by the console report (material_fidelity_report_lines) and the
    Blender addon's pre-export material panel — both want the same
    per-material classification, but the panel needs structured data
    (name/classification/findings) to render as UI rows rather than
    pre-formatted text.
    """
    analyses_by_name: dict[str, MaterialGraphAnalysis] = {}
    uv_warnings: list[str] = []
    for mesh_object in mesh_objects:
        materials = getattr(getattr(mesh_object, "data", None), "materials", None) or []
        object_needs_bake = False
        for material in materials:
            if material is None:
                continue
            name = getattr(material, "name", "<unnamed>")
            if name not in analyses_by_name:
                try:
                    analyses_by_name[name] = analyze_material(material)
                except Exception as exc:
                    print(f"  Warning: material analysis failed for '{name}': {exc}", flush=True)
                    continue
            if analyses_by_name[name].classification != MATERIAL_GRAPH_SUPPORTED:
                object_needs_bake = True
        if object_needs_bake:
            uv_warning = _mesh_uv_warning(getattr(mesh_object, "data", None))
            if uv_warning is not None:
                uv_warnings.append(f"Warning: mesh '{mesh_object.name}' {uv_warning}; export-time baking will require one")
    return MaterialFidelityReport(analyses_by_name=analyses_by_name, uv_warnings=uv_warnings)


def material_fidelity_report_lines(mesh_objects: Iterable[object]) -> list[str]:
    """Build the per-export material fidelity report (Milestone 1 diagnostics)."""
    report = compute_material_fidelity(mesh_objects)
    analyses_by_name = report.analyses_by_name
    if not analyses_by_name:
        return []

    counts = {MATERIAL_GRAPH_SUPPORTED: 0, MATERIAL_GRAPH_BAKEABLE: 0, MATERIAL_GRAPH_UNBAKEABLE: 0}
    for analysis in analyses_by_name.values():
        counts[analysis.classification] += 1

    lines = [
        "Material fidelity report: "
        f"{counts[MATERIAL_GRAPH_SUPPORTED]} supported, "
        f"{counts[MATERIAL_GRAPH_BAKEABLE]} bakeable, "
        f"{counts[MATERIAL_GRAPH_UNBAKEABLE]} unbakeable"
    ]
    for analysis in sorted(analyses_by_name.values(), key=lambda a: a.material_name):
        if analysis.classification == MATERIAL_GRAPH_SUPPORTED:
            continue
        details = "; ".join(
            f"{finding.node_name} ({finding.node_type}): {finding.reason}" for finding in analysis.findings
        )
        lines.append(f"  [{analysis.classification}] {analysis.material_name} — {details}")
    lines.extend(report.uv_warnings)
    if counts[MATERIAL_GRAPH_BAKEABLE] or counts[MATERIAL_GRAPH_UNBAKEABLE]:
        lines.append("  Materials listed above will render differently in the engine than in Blender")
        lines.append("  unless baked to flat textures with a third-party tool or fixed in the graph.")
    return lines


def _png_bit_depth(path: Path) -> int:
    """Return the bit depth field from a PNG IHDR chunk (8 or 16), or 0 on failure."""
    info = _png_ihdr(path)
    return info[0] if info else 0


def _png_ihdr(path: Path) -> tuple[int, int] | None:
    """Return (bit_depth, color_type) from a PNG IHDR chunk, or None on failure.

    PNG color types:
      0 = Grayscale        (1 channel)
      2 = RGB              (3 channels)
      3 = Indexed/palette  (3 channels)
      4 = Grayscale+Alpha  (2 channels)
      6 = RGBA             (4 channels)
    """
    try:
        with open(path, "rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return None
            f.read(4)  # chunk length
            if f.read(4) != b"IHDR":
                return None
            f.read(8)  # width (4) + height (4)
            bit_depth = f.read(1)[0]
            color_type = f.read(1)[0]
            return bit_depth, color_type
    except Exception:
        return None


def _tiff_bits_per_sample_and_channels(path: Path) -> tuple[int, int] | None:
    """Return (bitsPerSample, samplesPerPixel) read directly from TIFF IFD tags 258/277,
    or None on failure. Dependency-free (no Pillow) since this runs inside Blender's own
    Python, which may not have Pillow installed.
    """
    _TAG_BITS_PER_SAMPLE = 258
    _TAG_SAMPLES_PER_PIXEL = 277
    _TYPE_SHORT = 3
    _TYPE_SIZES = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8}  # BYTE, ASCII, SHORT, LONG, RATIONAL
    try:
        with open(path, "rb") as f:
            byte_order = f.read(2)
            if byte_order == b"II":
                endian = "<"
            elif byte_order == b"MM":
                endian = ">"
            else:
                return None
            magic, first_ifd_offset = struct.unpack(endian + "HI", f.read(6))
            if magic != 42:
                return None
            f.seek(first_ifd_offset)
            (entry_count,) = struct.unpack(endian + "H", f.read(2))
            bits_per_sample: int | None = None
            samples_per_pixel: int | None = None
            for _ in range(entry_count):
                tag, field_type, count = struct.unpack(endian + "HHI", f.read(8))
                value_bytes = f.read(4)
                if tag == _TAG_SAMPLES_PER_PIXEL and field_type == _TYPE_SHORT:
                    samples_per_pixel = struct.unpack(endian + "H", value_bytes[:2])[0]
                elif tag == _TAG_BITS_PER_SAMPLE and field_type == _TYPE_SHORT:
                    type_size = _TYPE_SIZES.get(field_type, 4)
                    if type_size * count <= 4:
                        # Value fits inline in the entry itself (single-channel case).
                        bits_per_sample = struct.unpack(endian + "H", value_bytes[:2])[0]
                    else:
                        # Value is an offset to an array (multi-channel case) — every
                        # channel in a real texture shares one bit depth, so the first
                        # entry is sufficient.
                        (offset,) = struct.unpack(endian + "I", value_bytes)
                        cur = f.tell()
                        f.seek(offset)
                        bits_per_sample = struct.unpack(endian + "H", f.read(2))[0]
                        f.seek(cur)
            if bits_per_sample is None or samples_per_pixel is None:
                return None
            return bits_per_sample, samples_per_pixel
    except Exception:
        return None


def _source_bit_depth_and_channels(image: object) -> tuple[int, int] | None:
    """Best-effort read of the TRUE on-disk bit depth and channel count for an image's
    source file, bypassing Blender's post-load image.depth/image.channels — which, as of
    the Blender version this was diagnosed against, unreliably reports 32/4 ("already
    8-bit RGBA") for genuinely 16-bit-per-channel sources, both grayscale TIFF and
    grayscale PNG. That silently defeats the needs_conversion safety net below: a 16-bit
    sRGB color texture can keep its 16-bit depth on disk, and Metal has no sRGB 16-bit
    pixel format, so MTKTextureLoader silently treats it as linear (washed-out/too-bright
    at runtime) instead of the intended 8-bit downconvert catching it at export time.

    Returns None when there's no inspectable file-backed source (packed/generated images,
    or a format other than PNG/TIFF) — callers should fall back to Blender's own
    image.depth/image.channels in that case, same as before this function existed.
    """
    filepath = getattr(image, "filepath_raw", "") or getattr(image, "filepath", "")
    if not filepath:
        return None
    try:
        if bpy is not None:
            # Resolves blend-file-relative "//" paths; only meaningful inside Blender.
            source_path = Path(bpy.path.abspath(filepath, library=getattr(image, "library", None)))
        else:
            source_path = Path(filepath)
    except Exception:
        return None
    if not source_path.is_file():
        return None

    suffix = source_path.suffix.lower()
    if suffix == ".png":
        info = _png_ihdr(source_path)
        if info is None:
            return None
        bit_depth, color_type = info
        channels = {0: 1, 2: 3, 3: 3, 4: 2, 6: 4}.get(color_type)
        if channels is None:
            return None
        return bit_depth, channels
    if suffix in (".tif", ".tiff"):
        return _tiff_bits_per_sample_and_channels(source_path)
    return None


def _set_scene_color_management_raw(scene: object) -> tuple[object, ...]:
    """Temporarily force identity color management so image saves preserve texture values."""
    view_settings = getattr(scene, "view_settings", None)
    display_settings = getattr(scene, "display_settings", None)
    sequencer_settings = getattr(scene, "sequencer_colorspace_settings", None)
    saved = (
        getattr(view_settings, "view_transform", None),
        getattr(view_settings, "look", None),
        getattr(view_settings, "exposure", None),
        getattr(view_settings, "gamma", None),
        getattr(display_settings, "display_device", None),
        getattr(sequencer_settings, "name", None),
    )

    # NOTE: bl_rna.properties[...].enum_items.keys() is unreliable in this
    # context — it returns a placeholder ('NONE') instead of the config's
    # actual dynamic enum values, silently making every "is this a valid
    # option" guard below always false. Rather than gate on that introspection,
    # attempt the assignment directly and fall back only if Blender itself
    # rejects the value (invalid enum raises on assignment).
    if view_settings is not None:
        try:
            view_settings.view_transform = "Raw"
        except Exception:
            try:
                view_settings.view_transform = "Standard"
            except Exception:
                pass

        try:
            view_settings.look = "None"
        except Exception:
            pass
        if hasattr(view_settings, "exposure"):
            view_settings.exposure = 0.0
        if hasattr(view_settings, "gamma"):
            view_settings.gamma = 1.0

    if display_settings is not None:
        try:
            display_settings.display_device = "None"
        except Exception:
            try:
                display_settings.display_device = "sRGB"
            except Exception:
                pass

    if sequencer_settings is not None and hasattr(sequencer_settings, "name"):
        try:
            sequencer_settings.name = "Raw"
        except Exception:
            pass

    return saved


def _restore_scene_color_management(scene: object, saved: tuple[object, ...]) -> None:
    view_settings = getattr(scene, "view_settings", None)
    display_settings = getattr(scene, "display_settings", None)
    sequencer_settings = getattr(scene, "sequencer_colorspace_settings", None)
    (
        saved_view_transform,
        saved_look,
        saved_exposure,
        saved_gamma,
        saved_display_device,
        saved_sequencer_name,
    ) = saved

    if view_settings is not None:
        if saved_view_transform is not None and hasattr(view_settings, "view_transform"):
            view_settings.view_transform = saved_view_transform
        if saved_look is not None and hasattr(view_settings, "look"):
            view_settings.look = saved_look
        if saved_exposure is not None and hasattr(view_settings, "exposure"):
            view_settings.exposure = saved_exposure
        if saved_gamma is not None and hasattr(view_settings, "gamma"):
            view_settings.gamma = saved_gamma

    if display_settings is not None and saved_display_device is not None and hasattr(display_settings, "display_device"):
        display_settings.display_device = saved_display_device

    if sequencer_settings is not None and saved_sequencer_name is not None and hasattr(sequencer_settings, "name"):
        sequencer_settings.name = saved_sequencer_name


_PNG_COLOR_SPACE_CHUNK_TYPES = {b"sRGB", b"gAMA", b"cHRM", b"iCCP"}


def _strip_png_color_profile_chunks(path: Path) -> None:
    """Remove sRGB/gAMA/cHRM/iCCP chunks from a PNG file in place.

    _set_scene_color_management_raw tries to force View Transform "Raw" (so
    the written pixel bytes are untouched linear data) but the Display Device
    still falls back to "sRGB" in configs without a "None" display (confirmed
    the case here). Blender's PNG writer embeds color-space chunks based on
    that Display Device regardless of View Transform, so the file ends up
    correctly holding linear bytes but *tagged* as sRGB-encoded. Color-
    management-aware loaders (ImageIO/MTKTextureLoader) honor that tag and
    apply their own implicit sRGB decode on load, silently corrupting values
    that are already linear. Stripping the tag makes the file's declared
    color space match what its bytes actually are: untagged/raw.
    """
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return
    out = bytearray(data[:8])
    pos = 8
    while pos < len(data):
        length = int.from_bytes(data[pos : pos + 4], "big")
        chunk_type = data[pos + 4 : pos + 8]
        chunk_end = pos + 8 + length + 4
        if chunk_type not in _PNG_COLOR_SPACE_CHUNK_TYPES:
            out += data[pos:chunk_end]
        pos = chunk_end
        if chunk_type == b"IEND":
            break
    path.write_bytes(bytes(out))


# ──────────────────────────────────────────────
# Color-grading LUT bake
#
# Captures the scene's active View Transform/Look/Exposure/Gamma by baking a
# known identity color grid through Blender's own color management
# (image.save_render) rather than reimplementing Filmic/AgX curve math. This
# reproduces whatever Blender actually does, including HDR highlight
# compression, for any current or future view transform or custom Look.
# ──────────────────────────────────────────────

MAX_COLOR_LUT_SIZE = 64
MIN_COLOR_LUT_SIZE = 4

# Log2 "shaper" domain, anchored on 18% middle gray, that the identity grid is
# built in. Blender's own curves already saturate to white by ~4 stops over
# 1.0 (see the feasibility spike), so -10..+6 stops is a generous starting
# range covering both deep shadow and bright HDR highlight detail. The Metal
# sampler uses this exact encode/decode contract.
_LUT_SHAPER_MIDDLE_GRAY = 0.18
_LUT_SHAPER_MIN_STOPS = -10.0
_LUT_SHAPER_MAX_STOPS = 6.0


def validate_lut_size(lut_size: int) -> int:
    """Validate a --color-lut-size value, clamping instead of failing at either end."""
    if lut_size < MIN_COLOR_LUT_SIZE:
        raise RuntimeError(f"--color-lut-size must be >= {MIN_COLOR_LUT_SIZE}, got {lut_size}")
    if lut_size > MAX_COLOR_LUT_SIZE:
        print(
            f"Warning: --color-lut-size {lut_size} is very high; clamping to {MAX_COLOR_LUT_SIZE}.",
            flush=True,
        )
        return MAX_COLOR_LUT_SIZE
    return lut_size


def _lut_shaper_decode(t: float) -> float:
    """Map a normalized [0, 1] shaper-space value to a scene-linear color value."""
    stops = _LUT_SHAPER_MIN_STOPS + t * (_LUT_SHAPER_MAX_STOPS - _LUT_SHAPER_MIN_STOPS)
    return _LUT_SHAPER_MIDDLE_GRAY * (2.0 ** stops)


def build_identity_lut_grid_pixels(lut_size: int) -> list[float]:
    """RGBA float pixel buffer (Blender's flat .pixels layout) for a
    lut_size-cubed identity LUT grid, unwrapped as a 2D strip: width =
    lut_size * lut_size (blue axis tiled horizontally), height = lut_size.

    Blender's `.pixels` buffer is bottom-up, but `image.save_render()` flips
    vertically when writing a top-down PNG. Rows are written here in reverse
    (green index g placed at buffer row `lut_size - 1 - g`) so that after that
    flip, PNG/texture row g still holds green index g — the convention the
    runtime LUT sampler assumes.
    """
    width = lut_size * lut_size
    step = 1.0 / (lut_size - 1) if lut_size > 1 else 0.0
    linear_steps = [_lut_shaper_decode(i * step) for i in range(lut_size)]

    pixels = [0.0] * (width * lut_size * 4)
    for g in range(lut_size):
        green = linear_steps[g]
        row_offset = (lut_size - 1 - g) * width * 4
        for b in range(lut_size):
            blue = linear_steps[b]
            tile_offset = row_offset + b * lut_size * 4
            for r in range(lut_size):
                idx = tile_offset + r * 4
                pixels[idx + 0] = linear_steps[r]
                pixels[idx + 1] = green
                pixels[idx + 2] = blue
                pixels[idx + 3] = 1.0
    return pixels


@dataclass(frozen=True)
class ColorManagementBake:
    lut_texture: "ExportedTexture"
    view_transform: str
    look: str
    exposure: float
    gamma: float
    lut_size: int
    display_device: str = "sRGB"
    shaper_min_stops: float = _LUT_SHAPER_MIN_STOPS
    shaper_max_stops: float = _LUT_SHAPER_MAX_STOPS


_UTEX_MAGIC = b"UTEX\x00\x00\x00\x00"
_UTEX_VERSION = 1
_UTEX_HEADER_SIZE = 64
_UTEX_MIP_ENTRY_SIZE = 16
_UTEX_RGBA16_FLOAT_PIXEL_FORMAT = 115
_UTEX_HEADER_FMT = "<8sIIIIIIBBxxII5I"
_UTEX_MIP_ENTRY_FMT = "<IIII"


def build_rgba16f_utex_bytes(
    pixels: list[float],
    width: int,
    height: int,
    *,
    source_rows_bottom_up: bool = True,
) -> bytes:
    """Build a one-mip RGBA16Float .utex payload.

    Blender image buffers are bottom-up while Metal uploads texture rows
    top-down. Reverse the rows by default so the LUT's green axis has the same
    orientation in Blender, the native container, and the Metal sampler.
    """
    expected_values = width * height * 4
    if width <= 0 or height <= 0 or len(pixels) != expected_values:
        raise ValueError(
            f"Expected {expected_values} RGBA values for {width}x{height}, got {len(pixels)}"
        )

    payload = bytearray(expected_values * 2)
    output_index = 0
    row_indices = range(height - 1, -1, -1) if source_rows_bottom_up else range(height)
    for source_y in row_indices:
        row_start = source_y * width * 4
        for value in pixels[row_start : row_start + width * 4]:
            struct.pack_into("<e", payload, output_index, float(value))
            output_index += 2

    payload_offset = _UTEX_HEADER_SIZE + _UTEX_MIP_ENTRY_SIZE
    header = struct.pack(
        _UTEX_HEADER_FMT,
        _UTEX_MAGIC,
        _UTEX_VERSION,
        1,  # NativeTexFlags.hasAlpha
        width,
        height,
        1,
        _UTEX_RGBA16_FLOAT_PIXEL_FORMAT,
        1,
        1,
        payload_offset,
        len(payload),
        0, 0, 0, 0, 0,
    )
    mip = struct.pack(_UTEX_MIP_ENTRY_FMT, 0, len(payload), width, height)
    return header + mip + bytes(payload)


def color_lut_filename(utex_bytes: bytes) -> str:
    """Return a stable, collision-safe filename derived from LUT contents."""
    digest = hashlib.sha256(utex_bytes).hexdigest()[:16]
    return f"gradelut_{digest}.utex"


def decode_rgba16f_utex_bytes(data: bytes) -> tuple[int, int, list[float]]:
    """Decode the RGBA16Float subset of .utex used by color LUT validation."""
    if len(data) < _UTEX_HEADER_SIZE + _UTEX_MIP_ENTRY_SIZE:
        raise ValueError("Truncated .utex data")
    header = struct.unpack_from(_UTEX_HEADER_FMT, data, 0)
    if header[0] != _UTEX_MAGIC or header[1] != _UTEX_VERSION:
        raise ValueError("Invalid .utex header")
    width, height, mip_count, pixel_format = header[3], header[4], header[5], header[6]
    payload_offset, payload_size = header[9], header[10]
    if mip_count != 1 or pixel_format != _UTEX_RGBA16_FLOAT_PIXEL_FORMAT:
        raise ValueError("Expected a one-mip RGBA16Float .utex")
    expected_size = width * height * 8
    if payload_size != expected_size or payload_offset + payload_size > len(data):
        raise ValueError("Invalid RGBA16Float .utex payload size")
    values = [
        item[0]
        for item in struct.iter_unpack(
            "<e",
            data[payload_offset : payload_offset + payload_size],
        )
    ]
    return width, height, values


def sample_color_lut_pixels(
    pixels: list[float],
    lut_size: int,
    color: tuple[float, float, float],
) -> tuple[float, float, float]:
    """CPU reference for LookShader.metal's trilinear LUT sampling."""
    width = lut_size * lut_size
    if len(pixels) != width * lut_size * 4:
        raise ValueError("LUT pixel count does not match lut_size")

    coords: list[float] = []
    for channel in color:
        stops = math.log2(max(channel, 1.0e-6) / _LUT_SHAPER_MIDDLE_GRAY)
        t = max(0.0, min(1.0, (stops - _LUT_SHAPER_MIN_STOPS) / (_LUT_SHAPER_MAX_STOPS - _LUT_SHAPER_MIN_STOPS)))
        coords.append(t * (lut_size - 1))

    low = [math.floor(value) for value in coords]
    high = [min(value + 1, lut_size - 1) for value in low]
    frac = [coords[index] - low[index] for index in range(3)]

    def texel(r: int, g: int, b: int) -> tuple[float, float, float]:
        offset = (g * width + b * lut_size + r) * 4
        return tuple(pixels[offset + channel] for channel in range(3))

    result = [0.0, 0.0, 0.0]
    for bz, blue_index in enumerate((low[2], high[2])):
        wb = (1.0 - frac[2]) if bz == 0 else frac[2]
        for gy, green_index in enumerate((low[1], high[1])):
            wg = (1.0 - frac[1]) if gy == 0 else frac[1]
            for rx, red_index in enumerate((low[0], high[0])):
                wr = (1.0 - frac[0]) if rx == 0 else frac[0]
                sample = texel(red_index, green_index, blue_index)
                weight = wr * wg * wb
                for channel in range(3):
                    result[channel] += sample[channel] * weight
    return result[0], result[1], result[2]


def bake_color_management_lut(lut_size: int, textures_dir: Path) -> ColorManagementBake:
    """Bake Blender's active view transform into an RGBA16Float LUT.

    The runtime's look pass (fragmentLookShader) writes to a linear
    intermediate texture and applies exactly one gamma encode later, in
    fragmentOutputTransformShader — the same contract ACESFilmicToneMapping's
    output already follows. A LUT baked straight through save_render() would
    violate that: save_render() bakes the View Transform AND the scene's
    display-device sRGB gamma together, so the shipped texture would already
    be gamma-encoded, and the engine's existing gamma step would then apply a
    second time on top — washing out the image (lifted blacks, crushed
    contrast). To keep the single-gamma-encode contract, this bakes through
    the real display transform (to capture the View Transform's tonemap curve
    correctly) and then decodes the result back to linear before writing the
    file actually shipped as the LUT texture.
    """
    blender_required()
    import bpy as _bpy

    scene = _bpy.context.scene
    view_settings = scene.view_settings
    view_transform = str(getattr(view_settings, "view_transform", "Standard"))
    look = str(getattr(view_settings, "look", "None"))
    exposure = float(getattr(view_settings, "exposure", 0.0))
    gamma = float(getattr(view_settings, "gamma", 1.0))

    lut_size = validate_lut_size(lut_size)
    width = lut_size * lut_size
    height = lut_size
    textures_dir.mkdir(parents=True, exist_ok=True)

    # Step 1: bake the identity grid through the scene's real, active color
    # management into a canonical sRGB display target. The engine output
    # transform is also sRGB, so the exported result does not depend on the
    # display device selected in the author's Blender UI.
    with tempfile.NamedTemporaryFile(
        prefix=".gradelut_display_encoded_",
        suffix=".png",
        dir=textures_dir,
        delete=False,
    ) as intermediate_file:
        intermediate_path = Path(intermediate_file.name)
    bake_image = _bpy.data.images.new(
        "untold_lut_bake", width=width, height=height, float_buffer=True, alpha=True
    )
    display_settings = scene.display_settings
    saved_display_device = str(getattr(display_settings, "display_device", "sRGB"))
    saved_dither = float(getattr(scene.render, "dither_intensity", 0.0))
    try:
        try:
            display_settings.display_device = "sRGB"
        except Exception as error:
            raise RuntimeError(
                "The active Blender OCIO configuration has no sRGB display device; "
                "Untold's canonical output target is sRGB."
            ) from error
        if hasattr(scene.render, "dither_intensity"):
            scene.render.dither_intensity = 0.0

        bake_image.pixels = build_identity_lut_grid_pixels(lut_size)
        img_settings = scene.render.image_settings
        saved_settings = (
            img_settings.file_format,
            img_settings.color_depth,
            img_settings.color_mode,
            getattr(img_settings, "color_management", None),
        )
        img_settings.file_format = "PNG"
        img_settings.color_depth = "16"
        img_settings.color_mode = "RGBA"
        if hasattr(img_settings, "color_management"):
            img_settings.color_management = "FOLLOW_SCENE"
        try:
            bake_image.filepath_raw = str(intermediate_path)
            bake_image.file_format = "PNG"
            # Uses the scene's real, active view_settings — this is the whole
            # point of the bake, so no neutralization here.
            bake_image.save_render(str(intermediate_path), scene=scene)
        finally:
            img_settings.file_format, img_settings.color_depth, img_settings.color_mode = saved_settings[:3]
            if saved_settings[3] is not None:
                img_settings.color_management = saved_settings[3]
    except Exception:
        try:
            intermediate_path.unlink()
        except OSError:
            pass
        raise
    finally:
        _bpy.data.images.remove(bake_image)
        if hasattr(scene.render, "dither_intensity"):
            scene.render.dither_intensity = saved_dither
        display_settings.display_device = saved_display_device

    # Step 2: reload the display-encoded PNG. Blender decodes any image whose
    # colorspace is "sRGB" back to linear float pixels when populating
    # .pixels — recovering the tonemapped-but-linear value the engine needs,
    # using Blender's own color pipeline rather than hand-rolled OETF math.
    try:
        reloaded = _bpy.data.images.load(str(intermediate_path))
        try:
            reloaded.colorspace_settings.name = "sRGB"
            linear_pixels = list(reloaded.pixels)
        finally:
            _bpy.data.images.remove(reloaded)
    finally:
        try:
            intermediate_path.unlink()
        except OSError:
            pass

    # Step 3: preserve the decoded linear values as half floats. This avoids
    # both 8-bit shadow quantization and ASTC approximation in the color
    # transform. Content-addressing prevents different scenes exported into
    # the same directory from overwriting each other's LUT.
    utex_bytes = build_rgba16f_utex_bytes(linear_pixels, width, height)
    output_path = textures_dir / color_lut_filename(utex_bytes)
    output_path.write_bytes(utex_bytes)

    lut_texture = ExportedTexture(
        name="ColorGradeLUT",
        uri=str(Path("Textures") / output_path.name),
        width=width,
        height=height,
        mip_count=1,
        source_path=output_path,
        texture_format=TEXTURE_FORMAT_RGBA16_FLOAT,
    )
    return ColorManagementBake(
        lut_texture=lut_texture,
        view_transform=view_transform,
        look=look,
        exposure=exposure,
        gamma=gamma,
        lut_size=lut_size,
        display_device="sRGB",
    )


# ──────────────────────────────────────────────
# Color-grade LUT import (.cube)
#
# Unlike bake_color_management_lut above (which renders through Blender to
# capture the whole View Transform), this stages an externally-authored
# standard .cube file as-is -- no bake, no shaper encoding, no .utex
# conversion. It's meant to be applied as a creative grade *on top of*
# whichever tonemap operator the engine runs, in ordinary 0-1 display-referred
# space, so any .cube produced by any grading tool works, not just ones this
# exporter produces. The engine parses and uploads the .cube directly (see
# CubeLUTLoader.swift) rather than going through the native texture pipeline.
# ──────────────────────────────────────────────

_CUBE_LUT_MIN_SIZE = 2
_CUBE_LUT_MAX_SIZE = 129  # generous upper bound; common grading tools cap at 33 or 65
_CUBE_LUT_HEADER_MAX_LINES = 32


@dataclass(frozen=True)
class ColorGradeLUT:
    """A staged, externally-authored .cube LUT (see stage_color_grade_lut_for_output)."""

    uri: str
    lut_size: int
    domain_min: tuple[float, float, float]
    domain_max: tuple[float, float, float]
    source_path: Path


def _parse_cube_lut_header(path: Path) -> tuple[int, tuple[float, float, float], tuple[float, float, float]]:
    """Read just enough of a .cube file to validate it and recover LUT_3D_SIZE
    and DOMAIN_MIN/DOMAIN_MAX, without loading the (potentially large) data body.
    """
    lut_size: Optional[int] = None
    domain_min = (0.0, 0.0, 0.0)
    domain_max = (1.0, 1.0, 1.0)
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for _ in range(_CUBE_LUT_HEADER_MAX_LINES):
                line = handle.readline()
                if not line:
                    break
                stripped = line.split("#", 1)[0].strip()
                if not stripped:
                    continue
                parts = stripped.split()
                keyword = parts[0].upper()
                if keyword == "LUT_3D_SIZE" and len(parts) >= 2:
                    lut_size = int(parts[1])
                elif keyword == "DOMAIN_MIN" and len(parts) >= 4:
                    domain_min = (float(parts[1]), float(parts[2]), float(parts[3]))
                elif keyword == "DOMAIN_MAX" and len(parts) >= 4:
                    domain_max = (float(parts[1]), float(parts[2]), float(parts[3]))
                elif keyword == "LUT_1D_SIZE":
                    raise RuntimeError(f"'{path.name}' is a 1D .cube LUT; only 3D LUTs (LUT_3D_SIZE) are supported")
                elif keyword[0].isdigit() or keyword[0] in "+-.":
                    # Reached the first data row without finding LUT_3D_SIZE.
                    break
    except (OSError, ValueError) as exc:
        raise RuntimeError(f"Could not read '{path}' as a .cube LUT: {exc}") from exc

    if lut_size is None:
        raise RuntimeError(f"'{path.name}' has no LUT_3D_SIZE header; not a valid 3D .cube LUT")
    if not (_CUBE_LUT_MIN_SIZE <= lut_size <= _CUBE_LUT_MAX_SIZE):
        raise RuntimeError(
            f"'{path.name}' has an unsupported LUT_3D_SIZE {lut_size} "
            f"(expected {_CUBE_LUT_MIN_SIZE}-{_CUBE_LUT_MAX_SIZE})"
        )
    return lut_size, domain_min, domain_max


def stage_color_grade_lut_for_output(lut_path: Path, output_dir: Path) -> ColorGradeLUT:
    """Validate and stage an externally-authored .cube LUT next to the export.

    Nothing is rendered or derived here -- the artist's .cube is copied as-is
    (content-addressed so identical LUTs reused across exports don't pile up
    under Textures/), and the engine parses/uploads it directly at load time.
    """
    lut_path = lut_path.expanduser().resolve()
    if not lut_path.is_file():
        raise RuntimeError(f"--color-grade-lut path does not exist: {lut_path}")
    if lut_path.suffix.lower() != ".cube":
        raise RuntimeError(f"--color-grade-lut expects a .cube file, got: {lut_path}")

    lut_size, domain_min, domain_max = _parse_cube_lut_header(lut_path)

    data = lut_path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()[:16]
    textures_dir = output_dir / "Textures"
    textures_dir.mkdir(parents=True, exist_ok=True)
    destination_path = textures_dir / f"gradelut_{digest}.cube"
    if not destination_path.is_file():
        destination_path.write_bytes(data)

    return ColorGradeLUT(
        uri=str(Path("Textures") / destination_path.name),
        lut_size=lut_size,
        domain_min=domain_min,
        domain_max=domain_max,
        source_path=destination_path,
    )


# Formats that do not support 8-bit color depth (only 16 or 32-bit).
# EXR/HDR are high-dynamic-range formats not intended for the engine's
# texture pipeline.  We warn and skip them rather than crashing.
_FORMATS_WITHOUT_8BIT = {"OPEN_EXR", "OPEN_EXR_MULTILAYER", "HDR", "CINEON", "DPX"}

# File extensions that map to formats not supported by the engine pipeline.
_UNSUPPORTED_TEXTURE_SUFFIXES = {".exr", ".hdr", ".cin", ".dpx"}
_HDR_IMAGE_SUFFIXES = {".exr", ".hdr"}


def write_blender_image_to_path(image_name: str, destination_path: Path, *, preserve_precision: bool = False) -> None:
    blender_required()
    image = bpy.data.images.get(image_name)
    if image is None:
        raise RuntimeError(f"Blender image '{image_name}' is no longer available for export")

    if not getattr(image, "has_data", True):
        # Blender lazily decodes packed/external image data — has_data is False
        # until something forces a load, even for a fully valid, fully packed
        # image.  Force the load once before concluding the data is missing;
        # accessing .pixels decodes the whole buffer as a side effect.
        try:
            image.pixels[0]
        except Exception:
            pass

    if not getattr(image, "has_data", True) or image.size[0] == 0 or image.size[1] == 0:
        raise UnsupportedTextureFormatError(
            f"'{image_name}' has no pixel data (missing source file or an unassigned "
            f"image reference). Skipping texture."
        )

    destination_path.parent.mkdir(parents=True, exist_ok=True)

    original_filepath_raw = getattr(image, "filepath_raw", "")
    original_file_format = getattr(image, "file_format", "PNG")
    # Must read the source file's own header before filepath_raw is overwritten to the
    # destination path below — image.filepath/.filepath_raw both then point at the (not
    # yet written) output PNG, not the original source, and the header would resolve to
    # the wrong file or nothing at all.
    source_info = _source_bit_depth_and_channels(image)
    try:
        image.filepath_raw = str(destination_path)
        if destination_path.suffix:
            file_format_by_suffix = {
                ".avif": "AVIF",
                ".bmp": "BMP",
                ".cin": "CINEON",
                ".dpx": "DPX",
                ".exr": "OPEN_EXR",
                ".hdr": "HDR",
                ".iris": "IRIS",
                ".jpg": "JPEG",
                ".jpeg": "JPEG",
                ".jp2": "JPEG2000",
                ".j2c": "JPEG2000",
                ".png": "PNG",
                ".sgi": "IRIS",
                ".tga": "TARGA",
                ".tif": "TIFF",
                ".tiff": "TIFF",
                ".webp": "WEBP",
            }
            normalized_suffix = destination_path.suffix.lower()
            image.file_format = file_format_by_suffix.get(normalized_suffix, normalized_suffix[1:].upper())

        # Metal has no sRGB 16-bit pixel format (no RGBA16Unorm_sRGB).  When
        # MTKTextureLoader receives a 16-bit PNG with .SRGB = true, it silently
        # ignores the sRGB flag and loads the texture as linear RGBA16Unorm.
        # The gamma-compressed sRGB values are then used without expansion,
        # making the surface appear too bright / washed out in the engine.
        # Grayscale textures (e.g. GIMP 16-bit grayscale with sRGB TRC) are also
        # problematic: Metal maps a single-channel PNG to the R channel only,
        # which makes meshes appear red.  Blender reports depth=16 for 16-bit
        # grayscale (channels==1), which is not caught by the depth>32 check for
        # RGB/RGBA 16-bit images.
        # Fix: downconvert any 16-bit or grayscale image to 8-bit RGB(A) via
        # save_render so the file on disk is a standard format Metal handles correctly.
        #
        # image.depth/image.channels are Blender's OWN post-load metadata, and in
        # current Blender versions they unreliably report 32/4 ("already 8-bit RGBA")
        # for genuinely 16-bit-per-channel PNG/TIFF sources — both grayscale and color
        # — which silently defeats the needs_conversion check below. Read the true
        # values from the source file's own header when one is available, and only
        # fall back to Blender's metadata for formats/sources that can't be inspected
        # directly (JPEG, packed images, generated images, etc.). Captured above, before
        # filepath_raw was overwritten to point at the destination instead of the source.
        if source_info is not None:
            bits_per_sample, image_channels = source_info
            image_depth = bits_per_sample * image_channels
        else:
            image_depth = getattr(image, "depth", 0)
            image_channels = getattr(image, "channels", 4)
        # Convert when: 16-bit RGB/RGBA (depth > 32), OR any grayscale image
        # (channels < 3, any bit depth).  depth = bits-per-pixel:
        #   8-bit grayscale  → depth=8,  channels=1  (missed by depth>32)
        #   16-bit grayscale → depth=16, channels=1
        #   16-bit RGB/RGBA  → depth=48/64
        needs_conversion = image_depth > 32 or image_channels < 3
        if needs_conversion:
            out_format = image.file_format
            if out_format in _FORMATS_WITHOUT_8BIT:
                # EXR/HDR/etc. are not part of the engine's texture workflow.
                # Raise so the caller can skip this texture with a warning.
                raise UnsupportedTextureFormatError(
                    f"'{image_name}' uses {out_format} format which is not supported "
                    f"by the engine texture pipeline (only 8-bit PNG/JPEG/TGA/etc. "
                    f"are supported). Skipping texture."
                )
            # Height/displacement is the one channel that wants to keep its precision
            # instead of being flattened to 8-bit: POM ray-marches this data, and 8-bit
            # quantization becomes visible stair-stepping at grazing angles once amplified
            # by the parallax offset math (see HeightMapParallaxOcclusionMapping.md §2.2).
            # The sRGB-16-bit Metal gap that forces 8-bit for color textures doesn't apply
            # here — height is always linear/non-color data. PNG supports 16-bit grayscale
            # natively, so only skip the downconvert when there's real precision to keep.
            target_depth = "16" if (preserve_precision and image_channels < 3 and image_depth >= 16) else "8"
            print(f"  Converting image '{image_name}' (depth={image_depth}, channels={image_channels}) to {target_depth}-bit RGB for Metal compatibility", flush=True)
            scene = bpy.context.scene
            img_settings = scene.render.image_settings
            saved = (img_settings.file_format, img_settings.color_depth, img_settings.color_mode)

            # Choose the view transform based on the image's color space.
            #
            # Blender always stores pixel data internally as linear.  save_render()
            # applies the active view transform before writing to disk:
            #
            #   "Raw"      — passes linear values through unchanged.  Correct for
            #                non-color data (normals, roughness, metallic) that the
            #                engine loads without sRGB expansion.
            #
            #   "Standard" — re-encodes linear → sRGB gamma.  Correct for color
            #                textures (base color, emissive) so that when the engine
            #                loads them with SRGB=true, the hardware sRGB→linear
            #                conversion restores the original values.
            #
            # Using "Raw" for an sRGB texture saves linear values to disk.  The
            # engine then loads those linear values as sRGB and applies sRGB→linear
            # expansion a second time, making the surface appear too dark / wrong.
            _LINEAR_COLORSPACES = {"Non-Color", "Linear", "Linear Rec.709", "Linear BT.709", "Raw"}
            colorspace_name = getattr(getattr(image, "colorspace_settings", None), "name", "sRGB")
            is_linear_data = colorspace_name in _LINEAR_COLORSPACES
            target_view_transform = "Raw" if is_linear_data else "Standard"

            saved_color_management = _set_scene_color_management_raw(scene)
            # Override the view transform to the correct value for this image type.
            view_settings = getattr(scene, "view_settings", None)
            if view_settings is not None and hasattr(view_settings, "view_transform"):
                try:
                    view_settings.view_transform = target_view_transform
                except Exception:
                    pass  # fall back to whatever _set_scene_color_management_raw set
            try:
                img_settings.file_format = out_format
                img_settings.color_depth = target_depth
                img_settings.color_mode = "RGBA" if image_channels == 4 else "RGB"
                image.save_render(str(destination_path), scene=scene)
            finally:
                _restore_scene_color_management(scene, saved_color_management)
                img_settings.file_format, img_settings.color_depth, img_settings.color_mode = saved
            if is_linear_data and out_format == "PNG":
                # View Transform "Raw" wrote untouched linear bytes, but the
                # Display Device still falls back to sRGB in configs without
                # a "None" display, so the file gets tagged as sRGB-encoded
                # despite holding linear data — see _strip_png_color_profile_chunks.
                _strip_png_color_profile_chunks(destination_path)
        else:
            image.save()
    finally:
        image.filepath_raw = original_filepath_raw
        image.file_format = original_file_format


def write_blender_hdr_image_to_path(image_name: str, destination_path: Path) -> None:
    blender_required()
    image = bpy.data.images.get(image_name)
    if image is None:
        raise RuntimeError(f"Blender image '{image_name}' is no longer available for HDR export")

    if not getattr(image, "has_data", True):
        try:
            image.pixels[0]
        except Exception:
            pass

    if not getattr(image, "has_data", True) or image.size[0] == 0 or image.size[1] == 0:
        raise RuntimeError(f"Blender HDR image '{image_name}' has no pixel data")

    destination_path.parent.mkdir(parents=True, exist_ok=True)

    normalized_suffix = destination_path.suffix.lower()
    if normalized_suffix == ".hdr":
        original_filepath_raw = getattr(image, "filepath_raw", "")
        original_file_format = getattr(image, "file_format", "OPEN_EXR")
        try:
            image.filepath_raw = str(destination_path)
            image.file_format = "HDR"
            image.save()
        finally:
            image.filepath_raw = original_filepath_raw
            image.file_format = original_file_format
        return

    # EXR: always re-encode with ZIP, regardless of the source's original
    # codec. Real-world EXRs (Poly Haven HDRIs, Blender's own bundled studio
    # lights) are commonly DWAA/DWAB-compressed. Apple's ImageIO OpenEXR
    # decoder -- what the engine uses at runtime -- recognizes the DWAA/DWAB
    # container but cannot decode it (a documented ImageIO limitation), which
    # silently produces a black/missing IBL environment. ZIP is lossless
    # relative to the source and decodes reliably via ImageIO.
    scene = bpy.context.scene
    img_settings = scene.render.image_settings
    saved_image_settings = (img_settings.file_format, img_settings.exr_codec, img_settings.color_depth)
    # save_render() bakes in the scene's active view transform (e.g. AgX,
    # Filmic), which would corrupt linear HDR radiance values on write.
    saved_color_management = _set_scene_color_management_raw(scene)
    try:
        img_settings.file_format = "OPEN_EXR"
        img_settings.exr_codec = "ZIP"
        # The engine only ever samples this as a half-float texture, so 16-bit
        # loses nothing at runtime while keeping the staged file smaller.
        img_settings.color_depth = "16"
        image.save_render(str(destination_path), scene=scene)
    finally:
        _restore_scene_color_management(scene, saved_color_management)
        img_settings.file_format, img_settings.exr_codec, img_settings.color_depth = saved_image_settings


def texture_staging_key(texture: ExportedTexture) -> str:
    if texture.source_path is not None:
        return f"path:{texture.source_path.expanduser().resolve()}"
    if texture.source_image_name:
        return f"image:{texture.source_image_name}"
    return f"uri:{texture.uri}"


def hdr_staging_key(source_path: Optional[Path], image_name: Optional[str], label: str) -> str:
    if source_path is not None:
        return f"path:{source_path.expanduser().resolve()}"
    if image_name:
        return f"image:{image_name}"
    return f"label:{label}"


def unique_asset_destination_name(source_name: str, used_names: set[str], fallback_stem: str) -> str:
    source_path = Path(source_name)
    base = source_path.stem or fallback_stem
    suffix = source_path.suffix
    candidate = f"{base}{suffix}"
    if candidate not in used_names:
        used_names.add(candidate)
        return candidate

    fingerprint = hashlib.sha1(source_name.encode("utf-8")).hexdigest()[:8]
    candidate = f"{base}_{fingerprint}{suffix}"
    if candidate not in used_names:
        used_names.add(candidate)
        return candidate

    counter = 1
    while True:
        candidate = f"{base}_{fingerprint}_{counter}{suffix}"
        if candidate not in used_names:
            used_names.add(candidate)
            return candidate
        counter += 1


def unique_texture_destination_name(
    texture: ExportedTexture, context: TextureStagingContext, suffix_override: Optional[str] = None
) -> str:
    source_name = texture.source_path.name if texture.source_path is not None else texture.name
    base = Path(source_name).stem or "texture"
    suffix = suffix_override if suffix_override is not None else Path(source_name).suffix
    candidate = f"{base}{suffix}"
    if candidate not in context.used_names:
        context.used_names.add(candidate)
        return candidate

    fingerprint_source = texture.source_image_name or texture.uri or source_name
    fingerprint = hashlib.sha1(fingerprint_source.encode("utf-8")).hexdigest()[:8]
    candidate = f"{base}_{fingerprint}{suffix}"
    if candidate not in context.used_names:
        context.used_names.add(candidate)
        return candidate

    counter = 1
    while True:
        candidate = f"{base}_{fingerprint}_{counter}{suffix}"
        if candidate not in context.used_names:
            context.used_names.add(candidate)
            return candidate
        counter += 1


def unique_hdr_destination_name(source_name: str, context: HDRStagingContext) -> str:
    return unique_asset_destination_name(source_name, context.used_names, "environment")


def stage_texture_for_output(
    texture: ExportedTexture,
    output_path: Path,
    context: TextureStagingContext,
    *,
    preserve_precision: bool = False,
) -> Optional[ExportedTexture]:
    """Stage a texture for output.  Returns None if the texture format is not
    supported by the engine pipeline (e.g. EXR, HDR) — callers should treat
    None as "no texture" for that material slot.

    preserve_precision: keep 16-bit depth for a genuinely-16-bit grayscale source
    instead of the usual 8-bit downconvert (see write_blender_image_to_path). Only
    the height/displacement slot sets this — texbake.py's height path is the only
    consumer built to preserve and use that extra precision.
    """
    source_path = texture.source_path
    texture_dir = output_path.parent / "Textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    staging_key = texture_staging_key(texture)

    # Early rejection: file-backed textures with unsupported suffixes (EXR, HDR, …)
    # are not part of the engine pipeline.  Skip with a warning so the export
    # continues without crashing.
    if source_path is not None:
        resolved = source_path.expanduser().resolve()
        if resolved.suffix.lower() in _UNSUPPORTED_TEXTURE_SUFFIXES:
            print(
                f"  Warning: texture '{texture.name}' uses unsupported format "
                f"'{resolved.suffix}' (EXR/HDR are not supported by the engine). "
                f"Skipping texture.",
                flush=True,
            )
            return None

    existing_destination = context.staged_by_key.get(staging_key)
    if existing_destination is not None:
        return replace(
            texture,
            uri=existing_destination.relative_to(output_path.parent).as_posix(),
            source_path=existing_destination,
        )

    if source_path is not None:
        source_path = source_path.expanduser().resolve()

    # File-backed textures are always re-encoded through Blender rather than
    # raw-copied (see below) — except when Blender isn't available at all
    # (e.g. pure-Python unit tests), where the original bytes are copied
    # untouched since no re-encoding can happen. Re-encoded output always
    # normalizes to PNG: never trust the source's on-disk suffix or encoding.
    # A source can be indexed/palette color (PNG color type 3, TGA color-mapped
    # datatype, ...), 16-bit, grayscale, or even a non-raster format like PSD
    # that Blender can read but cannot write back out under its own suffix —
    # all of which either fail outright in Metal or crash Blender's image
    # writer if the original suffix is preserved. write_blender_image_to_path
    # already handles the indexed/16-bit/grayscale cases via
    # image.depth/image.channels, which reflect the fully-decoded image
    # regardless of source format.
    will_reencode = bool(texture.source_image_name) or bpy is not None
    destination_name = unique_texture_destination_name(
        texture, context, suffix_override=".png" if will_reencode else None
    )
    destination_path = texture_dir / destination_name

    try:
        if source_path is not None and source_path.is_file():
            if source_path != destination_path:
                if texture.source_image_name:
                    write_blender_image_to_path(texture.source_image_name, destination_path, preserve_precision=preserve_precision)
                elif bpy is not None:
                    tmp_image = bpy.data.images.load(str(source_path))
                    try:
                        write_blender_image_to_path(tmp_image.name, destination_path, preserve_precision=preserve_precision)
                    finally:
                        bpy.data.images.remove(tmp_image)
                else:
                    shutil.copy2(source_path, destination_path)
        elif texture.source_image_name:
            write_blender_image_to_path(texture.source_image_name, destination_path, preserve_precision=preserve_precision)
        else:
            missing_path = str(source_path) if source_path is not None else "<none>"
            raise RuntimeError(f"Texture source does not exist and no Blender image fallback is available: {missing_path}")
    except UnsupportedTextureFormatError as exc:
        print(f"  Warning: {exc}", flush=True)
        return None

    context.staged_by_key[staging_key] = destination_path

    return replace(
        texture,
        uri=destination_path.relative_to(output_path.parent).as_posix(),
        source_path=destination_path,
    )


def _image_absolute_path(image: object, asset_path: Optional[Path] = None) -> Optional[Path]:
    filepath = getattr(image, "filepath", "") or ""
    if not filepath:
        return None
    raw_path = bpy.path.abspath(filepath, library=getattr(image, "library", None)) if bpy is not None else filepath
    image_path = Path(raw_path)
    if not image_path.is_absolute() and asset_path is not None:
        image_path = (asset_path.parent / image_path).resolve()
    return image_path


def _is_hdr_image(image: object, asset_path: Optional[Path] = None) -> bool:
    image_path = _image_absolute_path(image, asset_path)
    if image_path is not None and image_path.suffix.lower() in _HDR_IMAGE_SUFFIXES:
        return True
    file_format = str(getattr(image, "file_format", "") or "").upper()
    return file_format in {"OPEN_EXR", "OPEN_EXR_MULTILAYER", "HDR"}


def stage_hdr_source_for_output(
    *,
    output_dir: Path,
    context: HDRStagingContext,
    label: str,
    source_path: Optional[Path],
    image_name: Optional[str] = None,
    source_name: Optional[str] = None,
) -> Optional[Path]:
    """Stage an HDR/EXR environment asset into output_dir/HDR.

    HDR assets are intentionally separate from material textures because they
    use the engine environment/IBL path, not the 8-bit material texture path.
    """
    hdr_dir = output_dir / "HDR"
    staging_key = hdr_staging_key(source_path, image_name, label)

    existing_destination = context.staged_by_key.get(staging_key)
    if existing_destination is not None:
        return existing_destination

    if source_path is not None:
        source_path = source_path.expanduser().resolve()

    destination_name_source = source_name
    if destination_name_source is None:
        if source_path is not None:
            destination_name_source = source_path.name
        elif image_name:
            destination_name_source = image_name
        else:
            destination_name_source = f"{label}.exr"

    if Path(destination_name_source).suffix.lower() not in _HDR_IMAGE_SUFFIXES:
        destination_name_source = f"{Path(destination_name_source).stem or label}.exr"

    destination_path = hdr_dir / unique_hdr_destination_name(destination_name_source, context)

    try:
        if destination_path.suffix.lower() == ".exr":
            # Always re-encode EXRs through Blender (never a raw file copy).
            # The source's on-disk codec is untrusted here: DWAA/DWAB-
            # compressed EXRs are common in the wild and Apple's ImageIO
            # OpenEXR decoder (used by the engine at runtime) cannot read
            # them. write_blender_hdr_image_to_path forces ZIP on write.
            if image_name:
                write_blender_hdr_image_to_path(image_name, destination_path)
            elif source_path is not None and source_path.is_file():
                blender_required()
                loaded_image = bpy.data.images.load(str(source_path))
                try:
                    write_blender_hdr_image_to_path(loaded_image.name, destination_path)
                finally:
                    bpy.data.images.remove(loaded_image)
            else:
                return None
        elif source_path is not None and source_path.is_file():
            hdr_dir.mkdir(parents=True, exist_ok=True)
            if source_path != destination_path:
                shutil.copy2(source_path, destination_path)
        elif image_name:
            write_blender_hdr_image_to_path(image_name, destination_path)
        else:
            return None
    except Exception as exc:
        print(f"  Warning: failed to stage HDR environment '{label}': {exc}", flush=True)
        return None

    context.staged_by_key[staging_key] = destination_path
    print(f"  Staged HDR environment '{label}' -> {destination_path.relative_to(output_dir).as_posix()}", flush=True)
    return destination_path


def stage_world_hdr_images_for_output(output_dir: Path, asset_path: Path, context: HDRStagingContext) -> list[Path]:
    blender_required()
    staged: list[Path] = []
    for world in bpy.data.worlds:
        node_tree = getattr(world, "node_tree", None)
        if node_tree is None:
            continue
        for node in getattr(node_tree, "nodes", []):
            if getattr(node, "bl_idname", "") != "ShaderNodeTexEnvironment":
                continue
            image = getattr(node, "image", None)
            if image is None or not _is_hdr_image(image, asset_path):
                continue
            image_size = getattr(image, "size", (0, 0))
            if image_size[0] <= 1 or image_size[1] <= 1:
                # 1x1 EXRs are constant-color placeholders (e.g. Blender's USD
                # importer bakes a dome light's flat color into a throwaway
                # 1x1 image rather than a real environment map). Never a real HDRI.
                continue
            image_path = _image_absolute_path(image, asset_path)
            staged_path = stage_hdr_source_for_output(
                output_dir=output_dir,
                context=context,
                label=f"world:{getattr(world, 'name', 'World')}",
                source_path=image_path,
                image_name=getattr(image, "name", None),
                source_name=(image_path.name if image_path is not None else getattr(image, "name", None)),
            )
            if staged_path is not None:
                staged.append(staged_path)
    return staged


def stage_material_preview_studio_lights_for_output(output_dir: Path, context: HDRStagingContext) -> list[Path]:
    blender_required()
    staged: list[Path] = []
    for screen in bpy.data.screens:
        for area in getattr(screen, "areas", []):
            if getattr(area, "type", None) != "VIEW_3D":
                continue
            for space in getattr(area, "spaces", []):
                if getattr(space, "type", None) != "VIEW_3D":
                    continue
                shading = getattr(space, "shading", None)
                if shading is None or getattr(shading, "type", None) != "MATERIAL":
                    continue
                if getattr(shading, "light", None) != "STUDIO":
                    continue
                selected_studio_light = getattr(shading, "selected_studio_light", None)
                studio_light_name = getattr(shading, "studio_light", None) or getattr(selected_studio_light, "name", None)
                studio_light_path = getattr(selected_studio_light, "path", None)
                if not studio_light_path:
                    continue
                source_path = Path(studio_light_path)
                if source_path.suffix.lower() not in _HDR_IMAGE_SUFFIXES:
                    continue
                staged_path = stage_hdr_source_for_output(
                    output_dir=output_dir,
                    context=context,
                    label=f"material-preview:{studio_light_name or source_path.name}",
                    source_path=source_path,
                    image_name=None,
                    source_name=studio_light_name or source_path.name,
                )
                if staged_path is not None:
                    staged.append(staged_path)
    return staged


def stage_hdr_assets_for_output(output_dir: Path, asset_path: Path) -> list[Path]:
    if bpy is None:
        return []
    context = HDRStagingContext()
    staged = stage_world_hdr_images_for_output(output_dir, asset_path, context)
    staged.extend(stage_material_preview_studio_lights_for_output(output_dir, context))
    unique_staged: list[Path] = []
    seen: set[Path] = set()
    for staged_path in staged:
        if staged_path in seen:
            continue
        seen.add(staged_path)
        unique_staged.append(staged_path)
    return unique_staged


def stage_material_for_output(material: ExportedMaterial, output_path: Path, context: TextureStagingContext) -> ExportedMaterial:
    return replace(
        material,
        base_color_texture=stage_texture_for_output(material.base_color_texture, output_path, context) if material.base_color_texture is not None else None,
        normal_texture=stage_texture_for_output(material.normal_texture, output_path, context) if material.normal_texture is not None else None,
        metallic_texture=stage_texture_for_output(material.metallic_texture, output_path, context) if material.metallic_texture is not None else None,
        roughness_texture=stage_texture_for_output(material.roughness_texture, output_path, context) if material.roughness_texture is not None else None,
        emissive_texture=stage_texture_for_output(material.emissive_texture, output_path, context) if material.emissive_texture is not None else None,
        occlusion_texture=stage_texture_for_output(material.occlusion_texture, output_path, context) if material.occlusion_texture is not None else None,
        height_texture=stage_texture_for_output(material.height_texture, output_path, context, preserve_precision=True) if material.height_texture is not None else None,
    )


def stage_mesh_for_output(exported_mesh: ExportedMesh, output_path: Path, context: TextureStagingContext) -> ExportedMesh:
    return replace(
        exported_mesh,
        material=stage_material_for_output(exported_mesh.material, output_path, context),
    )


def stage_nodes_for_output(
    exported_nodes: list[ExportedNode],
    output_path: Path,
    progress_callback: Optional[ProgressCallback] = None,
) -> list[ExportedNode]:
    context = TextureStagingContext()
    staged_nodes: list[ExportedNode] = []
    total = len(exported_nodes)
    for i, exported_node in enumerate(exported_nodes, 1):
        if exported_node.mesh is None:
            staged_nodes.append(exported_node)
        else:
            staged_nodes.append(
                replace(
                    exported_node,
                    mesh=stage_mesh_for_output(exported_node.mesh, output_path, context),
                )
            )
        if progress_callback is not None:
            progress_callback("Stage nodes", i, total, exported_node.entity_name)
    return staged_nodes


def _detect_occlusion_texture(material: object, asset_path: Path) -> Optional[ExportedTexture]:
    """Search the material node tree for a ShaderNodeTexImage whose filename
    suggests it is an occlusion / AO map.  Blender's USD importer has no
    Principled BSDF occlusion socket, so these nodes often appear unconnected."""
    node_tree = getattr(material, "node_tree", None)
    if node_tree is None:
        return None
    for node in node_tree.nodes:
        if node.bl_idname != "ShaderNodeTexImage" or node.image is None:
            continue
        image = node.image
        filepath = getattr(image, "filepath", "") or ""
        stem = Path(filepath).stem if filepath else image.name
        name_lower = stem.lower().replace("-", "_")
        parts = name_lower.split("_")
        if "occlusion" not in name_lower and not any(p == "ao" for p in parts):
            continue
        raw_path = bpy.path.abspath(filepath, library=image.library) if bpy is not None and filepath else filepath
        texture_path = Path(raw_path) if raw_path else Path(image.name)
        if not texture_path.is_absolute() and filepath:
            texture_path = (asset_path.parent / texture_path).resolve()
        try:
            uri = os.path.relpath(texture_path, asset_path.parent)
        except ValueError:
            uri = str(texture_path)
        width = int(image.size[0]) if len(image.size) > 0 else 0
        height = int(image.size[1]) if len(image.size) > 1 else 0
        return ExportedTexture(
            name=texture_path.name or image.name,
            uri=uri,
            width=width,
            height=height,
            mip_count=1 if width > 0 and height > 0 else 0,
            source_path=texture_path,
            source_image_name=getattr(image, "name", None),
        )
    return None


def extract_material(mesh_object: object, asset_path: Path) -> ExportedMaterial:
    material_slots = getattr(mesh_object.data, "materials", [])
    material = material_slots[0] if material_slots and material_slots[0] is not None else None
    if material is None:
        return ExportedMaterial(
            name=f"{mesh_object.name}_material",
            base_color_factor=(1.0, 1.0, 1.0, 1.0),
            emissive_factor=(0.0, 0.0, 0.0),
            normal_scale=1.0,
            metallic_factor=0.0,
            roughness_factor=0.5,
            occlusion_strength=1.0,
            alpha_cutoff=0.5,
            base_color_texture=None,
            normal_texture=None,
            metallic_texture=None,
            roughness_texture=None,
            emissive_texture=None,
            occlusion_texture=None,
            roughness_texture_channel=TEXTURE_CHANNEL_R,
            metallic_texture_channel=TEXTURE_CHANNEL_R,
        )

    principled = None
    if getattr(material, "node_tree", None) is not None:
        for node in material.node_tree.nodes:
            if node.bl_idname == "ShaderNodeBsdfPrincipled":
                principled = node
                break

    if principled is None:
        base_color = vector4(material.diffuse_color)
        return ExportedMaterial(
            name=material.name,
            base_color_factor=base_color,
            emissive_factor=(0.0, 0.0, 0.0),
            normal_scale=1.0,
            metallic_factor=float(getattr(material, "metallic", 0.0)),
            roughness_factor=float(getattr(material, "roughness", 0.5)),
            occlusion_strength=1.0,
            alpha_cutoff=float(getattr(material, "alpha_threshold", 0.5)),
            base_color_texture=None,
            normal_texture=None,
            metallic_texture=None,
            roughness_texture=None,
            emissive_texture=None,
            occlusion_texture=None,
        )

    inputs = principled.inputs
    base_color_input = inputs.get("Base Color")
    emissive_input = inputs.get("Emission Color") or inputs.get("Emission")
    emission_strength_input = inputs.get("Emission Strength")
    metallic_input = inputs.get("Metallic")
    roughness_input = inputs.get("Roughness")
    normal_input = inputs.get("Normal")
    alpha_input = inputs.get("Alpha")

    # When a texture is connected to Base Color, Blender ignores the socket's
    # default_value entirely.  Reading it here would tint the texture with a
    # stale editor color and produce wrong results in the engine.  Only use the
    # default_value when NO texture is connected (i.e. solid color material).
    if base_color_input is None or base_color_input.is_linked:
        base_color = (1.0, 1.0, 1.0, 1.0)
    else:
        base_color = vector4(base_color_input.default_value)
    # Blender 4.0+ splits Emission into "Emission Color" (defaults to white)
    # and "Emission Strength" (defaults to 0.0) — a material is only actually
    # emissive if the artist raised Strength above zero. Reading Color alone
    # exports a bogus white emissive_factor on every material that has never
    # touched the Emission input at all. Older single-socket "Emission" inputs
    # have no separate strength control, so treat those as already-scaled.
    if emission_strength_input is not None and not emission_strength_input.is_linked:
        emission_strength = float(emission_strength_input.default_value)
    else:
        emission_strength = 1.0

    # Same stale-default_value issue as Base Color above: when a texture is
    # connected to Emission, Blender leaves the socket's default_value at
    # whatever was last set in the editor, not (0, 0, 0). Reading it in that
    # case exports a bogus emissive_factor untied to the actual texture.
    if emissive_input is None:
        emissive = (0.0, 0.0, 0.0)
    elif emissive_input.is_linked:
        emissive = (emission_strength, emission_strength, emission_strength)
    else:
        emissive_default = emissive_input.default_value
        emissive = (
            float(emissive_default[0]) * emission_strength,
            float(emissive_default[1]) * emission_strength,
            float(emissive_default[2]) * emission_strength,
        )
    metallic = float(metallic_input.default_value) if metallic_input is not None else 0.0
    roughness = float(roughness_input.default_value) if roughness_input is not None else 0.5
    alpha = float(alpha_input.default_value) if alpha_input is not None else 1.0

    base_color_texture = resolve_texture_from_socket(base_color_input, asset_path) if base_color_input is not None else None
    normal_texture = resolve_texture_from_socket(normal_input, asset_path) if normal_input is not None else None
    emissive_texture = resolve_texture_from_socket(emissive_input, asset_path) if emissive_input is not None else None
    metallic_texture = resolve_texture_from_socket(metallic_input, asset_path) if metallic_input is not None else None
    roughness_texture = resolve_texture_from_socket(roughness_input, asset_path) if roughness_input is not None else None
    normal_scale = 1.0
    if normal_input is not None and normal_input.is_linked:
        source = normal_input.links[0].from_node
        if source.bl_idname == "ShaderNodeNormalMap":
            strength_input = source.inputs.get("Strength")
            normal_scale = float(strength_input.default_value) if strength_input is not None else 1.0

    # Height/displacement detection: prefer the Material Output's Displacement input (the
    # standard ArchViz/Poliigon authoring pattern — an Image Texture feeding a Displacement
    # node's Height socket), falling back to a Bump node feeding the Principled BSDF's Normal
    # input directly (common in materials authored without a separate Displacement setup).
    # See docs/proposals/HeightMapParallaxOcclusionMapping.md for the domain rationale.
    height_texture: Optional[ExportedTexture] = None
    height_scale = 0.05
    height_midlevel = 0.5
    height_remap_min = 0.0
    height_remap_max = 1.0

    material_output = _material_output_node(material.node_tree) if getattr(material, "node_tree", None) is not None else None
    displacement_input = material_output.inputs.get("Displacement") if material_output is not None else None
    if displacement_input is not None and displacement_input.is_linked:
        displacement_source = displacement_input.links[0].from_node
        if displacement_source.bl_idname == "ShaderNodeDisplacement":
            height_input = displacement_source.inputs.get("Height")
            height_texture = resolve_texture_from_socket(height_input, asset_path) if height_input is not None else None
            if height_texture is not None:
                # Blender's Displacement Scale is a world-space distance, not the engine's
                # UV-normalized heightScale — carried through as a starting point only (see
                # ExportedMaterial.height_scale docstring), not a precise unit conversion.
                scale_input = displacement_source.inputs.get("Scale")
                midlevel_input = displacement_source.inputs.get("Midlevel")
                if scale_input is not None and not scale_input.is_linked:
                    height_scale = float(scale_input.default_value)
                if midlevel_input is not None and not midlevel_input.is_linked:
                    # The engine's POM is unidirectional (ray-marches INTO the surface from an
                    # apparent flat top; it cannot bulge outward past the true polygon surface
                    # the way Blender's signed displacement-around-Midlevel can). Copying
                    # Blender's Midlevel straight into heightMidlevel does NOT reproduce
                    # "neutral gray = no visible depth" — heightMidlevel is just an additive
                    # shift, not a zero-reference (see HeightMapParallaxOcclusionMapping.md).
                    # Instead, use it as the remap ceiling: raw values at/above Midlevel clip to
                    # "no depth" (the closest unidirectional approximation of "flush or bulging
                    # outward"), and values below it get contrast-stretched into the full depth
                    # range. heightMidlevel itself stays at its neutral default so it remains
                    # available as a separate, manual runtime tuning shift. Clamped to (0, 1]
                    # since raw texture samples are always in that range — an out-of-range
                    # authored Midlevel (e.g. an artist overshooting a slider) would otherwise
                    # make the remap divide by a value that never matches any real sample.
                    blender_midlevel = float(midlevel_input.default_value)
                    height_remap_max = min(max(blender_midlevel, 0.01), 1.0)

    if height_texture is None and normal_input is not None and normal_input.is_linked:
        normal_source = normal_input.links[0].from_node
        if normal_source.bl_idname == "ShaderNodeBump":
            height_input = normal_source.inputs.get("Height")
            height_texture = resolve_texture_from_socket(height_input, asset_path) if height_input is not None else None
            if height_texture is not None:
                distance_input = normal_source.inputs.get("Distance")
                if distance_input is not None and not distance_input.is_linked:
                    height_scale = float(distance_input.default_value)
                # Bump has no Midlevel-equivalent input; height_midlevel/height_remap_max stay
                # at their neutral defaults.

    occlusion_texture = _detect_occlusion_texture(material, asset_path)

    return ExportedMaterial(
        name=material.name,
        base_color_factor=(base_color[0], base_color[1], base_color[2], alpha),
        emissive_factor=emissive,
        normal_scale=normal_scale,
        metallic_factor=metallic,
        roughness_factor=roughness,
        occlusion_strength=1.0,
        alpha_cutoff=float(getattr(material, "alpha_threshold", 0.5)),
        base_color_texture=base_color_texture,
        normal_texture=normal_texture,
        metallic_texture=metallic_texture,
        roughness_texture=roughness_texture,
        emissive_texture=emissive_texture,
        occlusion_texture=occlusion_texture,
        height_texture=height_texture,
        height_scale=height_scale,
        height_midlevel=height_midlevel,
        height_remap_min=height_remap_min,
        height_remap_max=height_remap_max,
        roughness_texture_channel=roughness_texture.channel if roughness_texture is not None else TEXTURE_CHANNEL_R,
        metallic_texture_channel=metallic_texture.channel if metallic_texture is not None else TEXTURE_CHANNEL_R,
    )


def _extract_mesh_numpy(mesh_object: object, mesh_data: object, asset_path: Path,
                        *, conversion_matrix, validate: bool) -> ExportedMesh:
    """numpy-accelerated mesh extraction (inner worker, mesh_data already evaluated)."""
    n_polys = len(mesh_data.polygons)

    # Skip expensive bmesh roundtrip when the mesh is already fully triangulated.
    if n_polys > 0:
        loop_totals = np.empty(n_polys, dtype=np.int32)
        mesh_data.polygons.foreach_get("loop_total", loop_totals)
        if not np.all(loop_totals == 3):
            triangulate_mesh(mesh_data)

    mesh_data.calc_loop_triangles()

    n_polys_after = len(mesh_data.polygons)
    if n_polys_after > 0:
        mat_idx_arr = np.empty(n_polys_after, dtype=np.int32)
        mesh_data.polygons.foreach_get("material_index", mat_idx_arr)
        if len(np.unique(mat_idx_arr)) > 1:
            raise RuntimeError("V1 exporter only supports one material assignment per mesh")

    n_verts = len(mesh_data.vertices)
    n_loops = len(mesh_data.loops)
    n_tris  = len(mesh_data.loop_triangles)

    if n_verts == 0 or n_tris == 0:
        raise RuntimeError("The imported mesh has no vertices")

    skin_binding_source = extract_skin_binding(mesh_object)
    vertex_skin_indices = None
    vertex_skin_weights = None
    skeleton_entity_name = None
    skin_to_skeleton_map = None
    if skin_binding_source is not None:
        skeleton_entity_name, skin_to_skeleton_map, raw_joint_indices, raw_joint_weights = skin_binding_source
        vertex_skin_indices = np.array(raw_joint_indices, dtype=np.uint16)
        vertex_skin_weights = np.array(raw_joint_weights, dtype=np.float32)

    has_uvs = len(mesh_data.uv_layers) > 0
    if has_uvs:
        mesh_data.calc_tangents(uvmap=mesh_data.uv_layers[0].name)

    # ── bulk extraction via foreach_get (runs entirely in C) ──────────────

    pos_flat = np.empty(n_verts * 3, dtype=np.float32)
    mesh_data.vertices.foreach_get("co", pos_flat)
    all_positions = pos_flat.reshape(-1, 3)  # (V, 3) — all local-space verts

    nor_flat = np.empty(n_loops * 3, dtype=np.float32)
    mesh_data.loops.foreach_get("normal", nor_flat)
    loop_normals = nor_flat.reshape(-1, 3)

    if has_uvs:
        tan_flat = np.empty(n_loops * 3, dtype=np.float32)
        mesh_data.loops.foreach_get("tangent", tan_flat)
        loop_tangents = tan_flat.reshape(-1, 3)
        bts_flat = np.empty(n_loops, dtype=np.float32)
        mesh_data.loops.foreach_get("bitangent_sign", bts_flat)
    else:
        loop_tangents = np.zeros((n_loops, 3), dtype=np.float32)
        loop_tangents[:, 0] = 1.0
        bts_flat = np.ones(n_loops, dtype=np.float32)

    lvi_flat = np.empty(n_loops, dtype=np.int32)
    mesh_data.loops.foreach_get("vertex_index", lvi_flat)  # loop → vertex index

    if has_uvs:
        uv0_flat = np.empty(n_loops * 2, dtype=np.float32)
        mesh_data.uv_layers[0].data.foreach_get("uv", uv0_flat)
        loop_uv0 = uv0_flat.reshape(-1, 2)
    else:
        loop_uv0 = np.zeros((n_loops, 2), dtype=np.float32)

    if len(mesh_data.uv_layers) > 1:
        uv1_flat = np.empty(n_loops * 2, dtype=np.float32)
        mesh_data.uv_layers[1].data.foreach_get("uv", uv1_flat)
        loop_uv1 = uv1_flat.reshape(-1, 2)
    else:
        loop_uv1 = np.zeros((n_loops, 2), dtype=np.float32)

    color_layer = mesh_data.color_attributes.active_color
    if color_layer is not None and color_layer.domain == "CORNER":
        col_flat = np.empty(n_loops * 4, dtype=np.float32)
        color_layer.data.foreach_get("color", col_flat)
        loop_colors = col_flat.reshape(-1, 4)
    elif color_layer is not None and color_layer.domain == "POINT":
        col_flat = np.empty(n_verts * 4, dtype=np.float32)
        color_layer.data.foreach_get("color", col_flat)
        loop_colors = col_flat.reshape(-1, 4)[lvi_flat]
    else:
        loop_colors = np.ones((n_loops, 4), dtype=np.float32)

    # Triangle loop indices — flat (n_tris*3,) after ravel
    tl_flat = np.empty(n_tris * 3, dtype=np.int32)
    mesh_data.loop_triangles.foreach_get("loops", tl_flat)

    # ── gather per-corner data ─────────────────────────────────────────────

    c_vi  = lvi_flat[tl_flat]               # corner → vertex index
    c_pos = all_positions[c_vi]             # (N, 3)
    c_nor = loop_normals[tl_flat]           # (N, 3)
    c_tan = loop_tangents[tl_flat]          # (N, 3)
    c_bts = bts_flat[tl_flat]              # (N,)
    c_uv0 = loop_uv0[tl_flat]              # (N, 2)
    c_uv1 = loop_uv1[tl_flat]              # (N, 2)
    c_col = loop_colors[tl_flat]            # (N, 4)
    if vertex_skin_indices is not None and vertex_skin_weights is not None:
        c_jidx = vertex_skin_indices[c_vi]
        c_jwgt = vertex_skin_weights[c_vi]
    else:
        c_jidx = np.zeros((len(c_vi), 4), dtype=np.uint16)
        c_jwgt = np.zeros((len(c_vi), 4), dtype=np.float32)

    # ── orientation conversion ─────────────────────────────────────────────

    conv_np = None
    if conversion_matrix is not None:
        conv_np = np.array(
            [[float(conversion_matrix[r][c]) for c in range(4)] for r in range(4)],
            dtype=np.float32,
        )
        R = conv_np[:3, :3]
        T = conv_np[:3, 3]
        c_pos = c_pos @ R.T + T
        c_nor = c_nor @ R.T
        c_tan = c_tan @ R.T

    # ── deduplication via numpy unique (void-view trick, O(N log N) in C) ──

    _P = np.float64(1.0e8)
    keys = np.concatenate([
        (c_pos.astype(np.float64) * _P).round().astype(np.int64),   # (N, 3)
        (c_nor.astype(np.float64) * _P).round().astype(np.int64),   # (N, 3)
        (c_tan.astype(np.float64) * _P).round().astype(np.int64),   # (N, 3)
        np.where(c_bts >= 0, np.int64(1), np.int64(-1)).reshape(-1, 1),  # (N, 1)
        (c_uv0.astype(np.float64) * _P).round().astype(np.int64),   # (N, 2)
        (c_uv1.astype(np.float64) * _P).round().astype(np.int64),   # (N, 2)
        (np.clip(c_col, 0.0, 1.0) * 255.0).round().astype(np.int64),  # (N, 4)
        c_jidx.astype(np.int64),  # (N, 4)
        (np.clip(c_jwgt, 0.0, 1.0) * _P).round().astype(np.int64),  # (N, 4)
    ], axis=1)  # (N, 18) int64

    keys_c = np.ascontiguousarray(keys)
    keys_v = keys_c.view(np.dtype((np.void, keys_c.dtype.itemsize * keys_c.shape[1])))
    _, first_occ, inverse = np.unique(keys_v.ravel(), return_index=True, return_inverse=True)

    n_unique = len(first_occ)

    # ── gather unique vertex data ──────────────────────────────────────────

    u_pos = c_pos[first_occ]   # (U, 3)
    u_nor = c_nor[first_occ]   # (U, 3)
    u_tan = c_tan[first_occ]   # (U, 3)
    u_bts = c_bts[first_occ]   # (U,)
    u_uv0 = c_uv0[first_occ]   # (U, 2)
    u_uv1 = c_uv1[first_occ]   # (U, 2)
    u_col = c_col[first_occ]   # (U, 4)
    u_jidx = c_jidx[first_occ] # (U, 4)
    u_jwgt = c_jwgt[first_occ] # (U, 4)

    # ── vectorized packing ─────────────────────────────────────────────────

    vtx = np.empty(n_unique, dtype=_VERTEX_DTYPE)
    vtx["px"]      = u_pos[:, 0]
    vtx["py"]      = u_pos[:, 1]
    vtx["pz"]      = u_pos[:, 2]
    vtx["normal"]  = _np_pack_normals(u_nor)
    vtx["tangent"] = _np_pack_tangents(u_tan, u_bts)
    uv0h = u_uv0.astype(np.float16).view(np.uint16)
    uv1h = u_uv1.astype(np.float16).view(np.uint16)
    vtx["uv0u"] = uv0h[:, 0];  vtx["uv0v"] = uv0h[:, 1]
    vtx["uv1u"] = uv1h[:, 0];  vtx["uv1v"] = uv1h[:, 1]
    col8 = (np.clip(u_col, 0.0, 1.0) * 255.0).round().astype(np.uint8)
    vtx["cr"] = col8[:, 0];  vtx["cg"] = col8[:, 1]
    vtx["cb"] = col8[:, 2];  vtx["ca"] = col8[:, 3]
    vertex_bytes = vtx.tobytes()
    joint_index_bytes = u_jidx.astype(np.uint16).tobytes()
    joint_weight_bytes = u_jwgt.astype(np.float32).tobytes()

    # ── index buffer ───────────────────────────────────────────────────────

    index_type = INDEX_TYPE_UINT16 if n_unique <= 65535 else INDEX_TYPE_UINT32
    idx_arr = inverse.astype(np.uint16 if index_type == INDEX_TYPE_UINT16 else np.uint32)
    index_bytes = idx_arr.tobytes()
    edge_indices = build_architectural_edge_indices(
        [tuple(float(v) for v in u_pos[i]) for i in range(n_unique)],
        inverse.tolist(),
    )
    edge_index_bytes = pack_index_data(edge_indices, index_type)

    # ── bounds ─────────────────────────────────────────────────────────────

    local_bounds = AABB(
        (float(u_pos[:, 0].min()), float(u_pos[:, 1].min()), float(u_pos[:, 2].min())),
        (float(u_pos[:, 0].max()), float(u_pos[:, 1].max()), float(u_pos[:, 2].max())),
    )

    # World bounds: apply matrix_world to all local verts, then optional conversion.
    mw = np.array(
        [[float(mesh_object.matrix_world[r][c]) for c in range(4)] for r in range(4)],
        dtype=np.float32,
    )
    wp = all_positions @ mw[:3, :3].T + mw[:3, 3]
    if conv_np is not None:
        wp = wp @ conv_np[:3, :3].T + conv_np[:3, 3]
    world_bounds = AABB(
        (float(wp[:, 0].min()), float(wp[:, 1].min()), float(wp[:, 2].min())),
        (float(wp[:, 0].max()), float(wp[:, 1].max()), float(wp[:, 2].max())),
    )

    local_transform_rows = matrix_rows_from_blender(mesh_object.matrix_local)
    if conversion_matrix is not None:
        local_transform_rows = transform_matrix_rows(local_transform_rows, conversion_matrix)

    # ── validation mesh (only when requested) ─────────────────────────────

    vmesh = None
    if validate:
        vmesh = ValidationMesh(
            name=mesh_object.data.name or mesh_object.name,
            vertex_count=n_unique,
            index_count=int(inverse.size),
            positions=[tuple(float(v) for v in u_pos[i]) for i in range(n_unique)],
            normals=[tuple(float(v) for v in u_nor[i]) for i in range(n_unique)],
            tangents=[
                ValidationTangent(
                    xyz=tuple(float(v) for v in u_tan[i]),
                    handedness=float(u_bts[i]),
                )
                for i in range(n_unique)
            ],
            uv0=[tuple(float(v) for v in u_uv0[i]) for i in range(n_unique)],
            indices=inverse.tolist(),
            edge_indices=edge_indices,
        )

    return ExportedMesh(
        entity_name=mesh_object.get("mesh_original_name") or mesh_object.name,
        parent_entity_name=getattr(getattr(mesh_object, "parent", None), "name", None),
        mesh_name=mesh_object.data.name or mesh_object.name,
        local_transform_rows=local_transform_rows,
        local_bounds=local_bounds,
        world_bounds=world_bounds,
        vertices=vertex_bytes,
        indices=index_bytes,
        edge_indices=edge_index_bytes,
        vertex_count=n_unique,
        index_count=int(inverse.size),
        edge_index_count=len(edge_indices),
        index_type=index_type,
        material=extract_material(mesh_object, asset_path),
        skin_binding=(
            ExportedSkinBinding(
                skeleton_entity_name=skeleton_entity_name,
                joint_count=len(skin_to_skeleton_map),
                skin_to_skeleton_map=skin_to_skeleton_map,
                joint_indices=joint_index_bytes,
                joint_weights=joint_weight_bytes,
            )
            if skeleton_entity_name is not None and skin_to_skeleton_map is not None
            else None
        ),
        validation_mesh=vmesh,
    )


def extract_mesh_object(
    mesh_object: object,
    asset_path: Path,
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    *,
    _cached_conversion_matrix=None,
    _depsgraph=None,
    _validate: bool = False,
) -> ExportedMesh:
    depsgraph = _depsgraph if _depsgraph is not None else bpy.context.evaluated_depsgraph_get()
    evaluated_object = mesh_object.evaluated_get(depsgraph)
    mesh_data = evaluated_object.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
    if mesh_data is None:
        raise RuntimeError(f"Failed to evaluate mesh data for {mesh_object.name}")

    try:
        conversion_matrix = (
            _cached_conversion_matrix
            if _cached_conversion_matrix is not None
            else resolve_conversion_matrix(convert_orientation, source_orientation)
        )

        if _HAS_NUMPY:
            return _extract_mesh_numpy(
                mesh_object, mesh_data, asset_path,
                conversion_matrix=conversion_matrix,
                validate=_validate,
            )

        # ── Python fallback (no numpy) ─────────────────────────────────────
        triangulate_mesh(mesh_data)
        mesh_data.calc_loop_triangles()
        material_indices = {polygon.material_index for polygon in mesh_data.polygons}
        if len(material_indices) > 1:
            raise RuntimeError("V1 exporter only supports one material assignment per mesh")
        has_uvs = len(mesh_data.uv_layers) > 0
        uv0_layer = mesh_data.uv_layers[0].data if has_uvs else None
        uv1_layer = mesh_data.uv_layers[1].data if len(mesh_data.uv_layers) > 1 else None
        if has_uvs:
            mesh_data.calc_tangents(uvmap=mesh_data.uv_layers[0].name)

        color_layer = mesh_data.color_attributes.active_color
        vertex_writer = BinaryWriter()
        index_type = INDEX_TYPE_UINT16
        unique_vertices: dict[tuple[object, ...], int] = {}
        indices: list[int] = []
        joint_index_writer = BinaryWriter()
        joint_weight_writer = BinaryWriter()
        skin_binding_source = extract_skin_binding(mesh_object)
        skeleton_entity_name = None
        skin_to_skeleton_map = None
        vertex_skin_indices: list[tuple[int, int, int, int]] = []
        vertex_skin_weights: list[tuple[float, float, float, float]] = []
        if skin_binding_source is not None:
            skeleton_entity_name, skin_to_skeleton_map, vertex_skin_indices, vertex_skin_weights = skin_binding_source
        exported_positions: list[tuple[float, float, float]] = []
        exported_normals: list[tuple[float, float, float]] = [] if _validate else None
        exported_tangents: list[ValidationTangent] = [] if _validate else None
        exported_uv0: list[tuple[float, float]] = [] if _validate else None

        for triangle in mesh_data.loop_triangles:
            for loop_index in triangle.loops:
                loop = mesh_data.loops[loop_index]
                vertex = mesh_data.vertices[loop.vertex_index]
                uv0 = uv0_layer[loop_index].uv if uv0_layer is not None else (0.0, 0.0)
                uv1 = uv1_layer[loop_index].uv if uv1_layer is not None else (0.0, 0.0)
                if color_layer is not None and color_layer.domain == "CORNER":
                    color_value = color_layer.data[loop_index].color
                elif color_layer is not None and color_layer.domain == "POINT":
                    color_value = color_layer.data[loop.vertex_index].color
                else:
                    color_value = (1.0, 1.0, 1.0, 1.0)

                normal = normalize3(vector3(loop.normal), (0.0, 0.0, 1.0))
                tangent = normalize3(vector3(loop.tangent), (1.0, 0.0, 0.0)) if hasattr(loop, "tangent") else (1.0, 0.0, 0.0)
                handedness = 1.0 if float(getattr(loop, "bitangent_sign", 1.0)) >= 0.0 else -1.0
                position = (float(vertex.co.x), float(vertex.co.y), float(vertex.co.z))
                if conversion_matrix is not None:
                    position = transform_point(conversion_matrix, position)
                    normal = transform_direction(conversion_matrix, normal, (0.0, 0.0, 1.0))
                    tangent = transform_direction(conversion_matrix, tangent, (1.0, 0.0, 0.0))
                uv0_pair = (float(uv0[0]), float(uv0[1]))
                uv1_pair = (float(uv1[0]), float(uv1[1]))
                if vertex_skin_indices:
                    joint_index_tuple = vertex_skin_indices[loop.vertex_index]
                    joint_weight_tuple = vertex_skin_weights[loop.vertex_index]
                else:
                    joint_index_tuple = (0, 0, 0, 0)
                    joint_weight_tuple = (0.0, 0.0, 0.0, 0.0)
                key = (
                    round(position[0], 8), round(position[1], 8), round(position[2], 8),
                    round(normal[0], 8),   round(normal[1], 8),   round(normal[2], 8),
                    round(tangent[0], 8),  round(tangent[1], 8),  round(tangent[2], 8),
                    handedness,
                    round(uv0_pair[0], 8), round(uv0_pair[1], 8),
                    round(uv1_pair[0], 8), round(uv1_pair[1], 8),
                    color_to_u8(float(color_value[0])), color_to_u8(float(color_value[1])),
                    color_to_u8(float(color_value[2])), color_to_u8(float(color_value[3])),
                    joint_index_tuple,
                    tuple(round(weight, 8) for weight in joint_weight_tuple),
                )
                vertex_index = unique_vertices.get(key)
                if vertex_index is None:
                    vertex_index = len(unique_vertices)
                    unique_vertices[key] = vertex_index
                    exported_positions.append(position)
                    if _validate:
                        exported_normals.append(normal)
                        exported_tangents.append(ValidationTangent(xyz=tangent, handedness=handedness))
                        exported_uv0.append(uv0_pair)
                    write_vertex(
                        vertex_writer,
                        position=position, normal=normal, tangent=tangent,
                        handedness=handedness, uv0=uv0_pair, uv1=uv1_pair,
                        color0=vector4(color_value),
                    )
                    joint_index_writer.write_bytes(pack_joint_indices(list(joint_index_tuple)))
                    joint_weight_writer.write_bytes(pack_joint_weights(list(joint_weight_tuple)))
                indices.append(vertex_index)

        if len(unique_vertices) > 65535:
            index_type = INDEX_TYPE_UINT32

        index_bytes = pack_index_data(indices, index_type)
        edge_indices = build_architectural_edge_indices(exported_positions, indices)
        edge_index_bytes = pack_index_data(edge_indices, index_type)

        local_points = [vector3(vertex.co) for vertex in mesh_data.vertices]
        if not local_points:
            raise RuntimeError("The imported mesh has no vertices")
        world_points = [vector3(mesh_object.matrix_world @ vertex.co) for vertex in mesh_data.vertices]
        local_transform_rows = matrix_rows_from_blender(mesh_object.matrix_local)
        if conversion_matrix is not None:
            local_points = [transform_point(conversion_matrix, point) for point in local_points]
            world_points = [transform_point(conversion_matrix, point) for point in world_points]
            local_transform_rows = transform_matrix_rows(local_transform_rows, conversion_matrix)

        vmesh = ValidationMesh(
            name=mesh_object.data.name or mesh_object.name,
            vertex_count=len(unique_vertices),
            index_count=len(indices),
            positions=exported_positions,
            normals=exported_normals,
            tangents=exported_tangents,
            uv0=exported_uv0,
            indices=indices,
            edge_indices=edge_indices,
        ) if _validate else None

        return ExportedMesh(
            entity_name=mesh_object.get("mesh_original_name") or mesh_object.name,
            parent_entity_name=getattr(getattr(mesh_object, "parent", None), "name", None),
            mesh_name=mesh_object.data.name or mesh_object.name,
            local_transform_rows=local_transform_rows,
            local_bounds=aabb_from_points(local_points),
            world_bounds=aabb_from_points(world_points),
            vertices=vertex_writer.data,
            indices=index_bytes,
            edge_indices=edge_index_bytes,
            vertex_count=len(unique_vertices),
            index_count=len(indices),
            edge_index_count=len(edge_indices),
            index_type=index_type,
            material=extract_material(mesh_object, asset_path),
            skin_binding=(
                ExportedSkinBinding(
                    skeleton_entity_name=skeleton_entity_name,
                    joint_count=len(skin_to_skeleton_map),
                    skin_to_skeleton_map=skin_to_skeleton_map,
                    joint_indices=joint_index_writer.data,
                    joint_weights=joint_weight_writer.data,
                )
                if skeleton_entity_name is not None and skin_to_skeleton_map is not None
                else None
            ),
            validation_mesh=vmesh,
        )
    finally:
        evaluated_object.to_mesh_clear()


def extract_meshes(
    asset_path: Path,
    mesh_name: Optional[str],
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
) -> list[ExportedMesh]:
    blender_required()
    clear_scene()
    imported_objects = import_usd_asset(asset_path)
    mesh_objects = choose_mesh_objects(imported_objects, mesh_name)
    return [
        extract_mesh_object(
            mesh_object,
            asset_path,
            convert_orientation=convert_orientation,
            source_orientation=source_orientation,
        )
        for mesh_object in mesh_objects
    ]


def split_blender_objects_by_material(objects: list[object]) -> list[object]:
    """Split any Blender mesh object that assigns multiple materials across its
    faces into separate single-material objects.

    The V1 exporter requires each mesh to carry exactly one material.  This
    mirrors the split step in the tile-streaming pipeline so that direct
    export-untold calls on multi-material USD assets also work.
    """
    import bpy, bmesh as _bmesh  # noqa: F401 — bmesh may not be at module level
    result = []
    split_count = 0
    for obj in objects:
        if getattr(obj, "type", None) != "MESH" or obj.data is None:
            result.append(obj)
            continue
        mesh = obj.data
        used_indices = {p.material_index for p in mesh.polygons}
        if len(used_indices) <= 1:
            result.append(obj)
            continue
        print(f"  Splitting '{obj.name}' into {len(used_indices)} single-material mesh(es)", flush=True)
        split_count += len(used_indices)
        for mat_idx in sorted(used_indices):
            bm = _bmesh.new()
            try:
                bm.from_mesh(mesh)
                to_delete = [f for f in bm.faces if f.material_index != mat_idx]
                if to_delete:
                    _bmesh.ops.delete(bm, geom=to_delete, context="FACES")
                loose_edges = [e for e in bm.edges if not e.link_faces]
                if loose_edges:
                    _bmesh.ops.delete(bm, geom=loose_edges, context="EDGES")
                loose_verts = [v for v in bm.verts if not v.link_faces and not v.link_edges]
                if loose_verts:
                    _bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")
                if not bm.faces:
                    continue
                new_mesh = bpy.data.meshes.new(f"{mesh.name}_mat{mat_idx}")
                bm.to_mesh(new_mesh)
                new_mesh.update()
                mat = mesh.materials[mat_idx] if mat_idx < len(mesh.materials) else None
                if mat:
                    new_mesh.materials.append(mat)
                    for p in new_mesh.polygons:
                        p.material_index = 0
                new_obj = bpy.data.objects.new(f"{obj.name}_mat{mat_idx}", new_mesh)
                new_obj.matrix_world = obj.matrix_world.copy()
                new_obj[UNTOLD_EXPORT_TEMP_OBJECT_PROP] = True
                bpy.context.scene.collection.objects.link(new_obj)
                result.append(new_obj)
            finally:
                bm.free()
    return result


def cleanup_temporary_export_objects(objects: Iterable[object]) -> None:
    """Remove temporary Blender objects created for one export pass."""
    if bpy is None:
        return
    for obj in list(objects):
        try:
            if not obj.get(UNTOLD_EXPORT_TEMP_OBJECT_PROP):
                continue
        except ReferenceError:
            continue
        mesh = getattr(obj, "data", None)
        try:
            bpy.data.objects.remove(obj, do_unlink=True)
        except ReferenceError:
            pass
        if mesh is not None and getattr(mesh, "users", 0) == 0:
            try:
                bpy.data.meshes.remove(mesh)
            except ReferenceError:
                pass


def extract_nodes(
    asset_path: Path,
    mesh_name: Optional[str],
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    validate: bool = False,
    progress_callback: Optional[ProgressCallback] = None,
) -> list[ExportedNode]:
    blender_required()
    stage_label = "Open .blend" if asset_path.suffix.lower() == ".blend" else "Import USD"
    if progress_callback is not None:
        progress_callback(stage_label, 0, 1, asset_path.name)
    imported_objects = load_source_objects(asset_path)
    if progress_callback is not None:
        progress_callback("Select objects", 0, 1, f"{len(imported_objects)} imported object(s)")
    export_objects = prepare_export_objects_from_blender_objects(imported_objects, mesh_name)
    try:
        return extract_nodes_from_objects(
            export_objects,
            asset_path,
            convert_orientation=convert_orientation,
            source_orientation=source_orientation,
            validate=validate,
            progress_callback=progress_callback,
        )
    finally:
        cleanup_temporary_export_objects(export_objects)


def extract_scene_payload_from_current_scene(
    *,
    mesh_name: Optional[str],
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
) -> tuple[list[ExportedLight], list[ExportedCamera]]:
    blender_required()
    include_scene_payload = mesh_name is None
    return extract_scene_payload_from_objects(
        list(bpy.data.objects),
        convert_orientation=convert_orientation,
        source_orientation=source_orientation,
        include_scene_payload=include_scene_payload,
    )


def extract_nodes_from_objects(
    export_objects: list[object],
    asset_path: Path,
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    validate: bool = False,
    progress_callback: Optional[ProgressCallback] = None,
) -> list[ExportedNode]:
    blender_required()
    if not export_objects:
        raise RuntimeError("No Blender objects were provided for export")
    conversion_matrix = resolve_conversion_matrix(convert_orientation, source_orientation)

    import bpy as _bpy
    depsgraph = _bpy.context.evaluated_depsgraph_get()

    mesh_objects = [obj for obj in export_objects if getattr(obj, "type", None) == "MESH"]

    total = len(mesh_objects)
    print(f"  Processing {total} mesh(es) ...", flush=True)
    exported_meshes_by_name: dict[str, ExportedMesh] = {}
    skipped = 0
    for i, obj in enumerate(mesh_objects, 1):
        percent = (100.0 * i) / max(total, 1)
        print(f"  [{i}/{total} | {percent:6.2f}%] {obj.name}", flush=True)
        try:
            exported_meshes_by_name[obj.name] = extract_mesh_object(
                obj,
                asset_path,
                convert_orientation=convert_orientation,
                source_orientation=source_orientation,
                _cached_conversion_matrix=conversion_matrix,
                _depsgraph=depsgraph,
                _validate=validate,
            )
        except RuntimeError as exc:
            print(f"    Skipped: {exc}", flush=True)
            skipped += 1
        if progress_callback is not None:
            progress_callback("Extract meshes", i, total, obj.name)
    if skipped:
        print(f"  Skipped {skipped} mesh(es) with errors", flush=True)

    for report_line in material_fidelity_report_lines(mesh_objects):
        print(f"  {report_line}", flush=True)

    descendant_world_corners_by_name: dict[str, list[tuple[float, float, float]]] = {}

    def aggregate_world_corners(obj: object) -> list[tuple[float, float, float]]:
        existing = descendant_world_corners_by_name.get(obj.name)
        if existing is not None:
            return existing

        corners: list[tuple[float, float, float]] = []
        mesh = exported_meshes_by_name.get(obj.name)
        if mesh is not None:
            corners.extend(aabb_corners(mesh.world_bounds))

        for child in getattr(obj, "children", []):
            if child.as_pointer() not in {candidate.as_pointer() for candidate in export_objects}:
                continue
            corners.extend(aggregate_world_corners(child))

        descendant_world_corners_by_name[obj.name] = corners
        return corners

    export_object_ids = {obj.as_pointer() for obj in export_objects}
    nodes: list[ExportedNode] = []
    for obj in export_objects:
        if getattr(obj, "type", None) in {"LIGHT", "CAMERA"}:
            continue

        local_transform_rows = matrix_rows_from_blender(obj.matrix_local)
        if conversion_matrix is not None:
            local_transform_rows = transform_matrix_rows(local_transform_rows, conversion_matrix)

        mesh = exported_meshes_by_name.get(obj.name)
        skeleton = extract_skeleton(obj, obj.name, conversion_matrix) if getattr(obj, "type", None) == "ARMATURE" else None
        if mesh is not None:
            local_bounds = mesh.local_bounds
            world_bounds = mesh.world_bounds
        else:
            world_corners = aggregate_world_corners(obj)
            if world_corners:
                world_bounds = aabb_from_points(world_corners)
                inverse_world = obj.matrix_world.inverted_safe()
                if conversion_matrix is not None:
                    inv_conversion = conversion_matrix.inverted()
                    local_points = [
                        transform_point(
                            conversion_matrix,
                            vector3(inverse_world @ Vector(transform_point(inv_conversion, point))),
                        )
                        for point in world_corners
                    ]
                else:
                    local_points = [vector3(inverse_world @ Vector(point)) for point in world_corners]
                local_bounds = aabb_from_points(local_points)
            else:
                local_bounds = AABB((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
                world_bounds = local_bounds

        parent = getattr(obj, "parent", None)
        parent_entity_name = parent.name if parent is not None and parent.as_pointer() in export_object_ids else None
        nodes.append(
            ExportedNode(
                entity_name=obj.get("mesh_original_name") or obj.name,
                parent_entity_name=parent_entity_name,
                local_transform_rows=local_transform_rows,
                local_bounds=local_bounds,
                world_bounds=world_bounds,
                skeleton=skeleton,
                mesh=mesh,
            )
        )

    return normalize_export_nodes(nodes)


def _compress_geometry_chunks(vertex_raw: bytes, index_raw: bytes) -> tuple[bytes, bytes]:
    """Compress vertex and index byte arrays with LZ4 raw block format.

    Uses lz4.block (not lz4.frame) to produce raw LZ4 block data compatible
    with Apple's COMPRESSION_LZ4_RAW algorithm on the runtime side.
    Install the dependency with: pip install lz4
    """
    try:
        import lz4.block as lz4_block  # type: ignore[import]
    except ImportError:
        raise RuntimeError(
            "The 'lz4' package is required for geometry compression. "
            "Install it with: pip install lz4"
        )
    vertex_compressed: bytes = lz4_block.compress(vertex_raw, store_size=False)
    index_compressed: bytes = lz4_block.compress(index_raw, store_size=False)
    return vertex_compressed, index_compressed


def _format_byte_count(size: int) -> str:
    if size < 1024:
        return f"{size} B"
    if size < 1024 * 1024:
        return f"{size / 1024.0:.1f} KB"
    return f"{size / (1024.0 * 1024.0):.1f} MB"


def build_untold_file(
    exported_nodes: list[ExportedNode],
    output_path: Path,
    file_type_name: str,
    *,
    exported_lights: Optional[list[ExportedLight]] = None,
    exported_cameras: Optional[list[ExportedCamera]] = None,
    compress_geometry: bool = False,
    color_management_bake: Optional[ColorManagementBake] = None,
    color_grade_lut: Optional[ColorGradeLUT] = None,
    progress_callback: Optional[ProgressCallback] = None,
) -> bytes:
    if not exported_nodes:
        raise RuntimeError("No nodes were extracted for export")
    exported_lights = exported_lights or []
    exported_cameras = exported_cameras or []

    string_table = StringTableBuilder()
    textures: list[TextureRecord] = []
    texture_indices: dict[str, int] = {}
    materials: list[MaterialRecord] = []
    material_indices: dict[tuple[object, ...], int] = {}
    entities: list[EntityRecord] = []
    light_records: list[LightRecord] = []
    camera_records: list[CameraRecord] = []
    color_management_records: list[ColorManagementRecord] = []
    color_grade_lut_records: list[ColorGradeLUTRecord] = []
    meshes: list[MeshRecord] = []
    skeletons: list[SkeletonRecord] = []
    skeleton_joints: list[SkeletonJointRecord] = []
    skins: list[SkinRecord] = []
    skin_joint_mappings: list[SkinJointMappingRecord] = []
    vertex_writer = BinaryWriter()
    index_writer = BinaryWriter()
    edge_index_writer = BinaryWriter()
    joint_index_writer = BinaryWriter()
    joint_weight_writer = BinaryWriter()

    def add_texture(texture: Optional[ExportedTexture], flags: int = 0) -> int:
        if texture is None:
            return INVALID_INDEX
        existing = texture_indices.get(texture.uri)
        if existing is not None:
            existing_record = textures[existing]
            textures[existing] = TextureRecord(
                name_offset=existing_record.name_offset,
                uri_offset=existing_record.uri_offset,
                texture_format=(
                    existing_record.texture_format
                    if existing_record.texture_format != TEXTURE_FORMAT_UNKNOWN
                    else texture.texture_format
                ),
                flags=existing_record.flags | flags,
                width=existing_record.width,
                height=existing_record.height,
                mip_count=existing_record.mip_count,
            )
            return existing

        index = len(textures)
        texture_indices[texture.uri] = index
        textures.append(
            TextureRecord(
                name_offset=string_table.add(texture.name),
                uri_offset=string_table.add(texture.uri),
                texture_format=texture.texture_format,
                flags=flags,
                width=texture.width,
                height=texture.height,
                mip_count=texture.mip_count,
            )
        )
        return index

    def add_material(material: ExportedMaterial) -> int:
        base_color_texture_index = add_texture(material.base_color_texture, TEXTURE_FLAG_SRGB)
        normal_texture_index = add_texture(material.normal_texture, TEXTURE_FLAG_NORMAL_MAP)
        metallic_texture_index = add_texture(material.metallic_texture)
        roughness_texture_index = add_texture(material.roughness_texture)
        emissive_texture_index = add_texture(material.emissive_texture, TEXTURE_FLAG_EMISSIVE | TEXTURE_FLAG_SRGB)
        occlusion_texture_index = add_texture(material.occlusion_texture, TEXTURE_FLAG_OCCLUSION)
        height_texture_index = add_texture(material.height_texture, TEXTURE_FLAG_HEIGHT)

        key = (
            material.name,
            material.base_color_factor,
            material.emissive_factor,
            material.normal_scale,
            material.metallic_factor,
            material.roughness_factor,
            material.occlusion_strength,
            material.alpha_cutoff,
            base_color_texture_index,
            normal_texture_index,
            metallic_texture_index,
            roughness_texture_index,
            emissive_texture_index,
            occlusion_texture_index,
            height_texture_index,
            material.height_scale,
            material.height_midlevel,
            material.height_remap_min,
            material.height_remap_max,
            material.roughness_texture_channel,
            material.metallic_texture_channel,
        )
        existing = material_indices.get(key)
        if existing is not None:
            return existing

        index = len(materials)
        material_indices[key] = index
        materials.append(
            MaterialRecord(
                name_offset=string_table.add(material.name),
                flags=0,
                base_color_factor=material.base_color_factor,
                emissive_factor=material.emissive_factor,
                normal_scale=material.normal_scale,
                metallic_factor=material.metallic_factor,
                roughness_factor=material.roughness_factor,
                occlusion_strength=material.occlusion_strength,
                alpha_cutoff=material.alpha_cutoff,
                base_color_texture_index=base_color_texture_index,
                normal_texture_index=normal_texture_index,
                metallic_texture_index=metallic_texture_index,
                roughness_texture_index=roughness_texture_index,
                emissive_texture_index=emissive_texture_index,
                occlusion_texture_index=occlusion_texture_index,
                height_texture_index=height_texture_index,
                height_scale=material.height_scale,
                height_midlevel=material.height_midlevel,
                height_remap_min=material.height_remap_min,
                height_remap_max=material.height_remap_max,
                roughness_texture_channel=material.roughness_texture_channel,
                metallic_texture_channel=material.metallic_texture_channel,
            )
        )
        return index

    world_bounds = aabb_from_points(
        point
        for exported_node in exported_nodes
        for point in aabb_corners(exported_node.world_bounds)
    )

    entity_ids_by_name = {exported_node.entity_name: entity_id for entity_id, exported_node in enumerate(exported_nodes)}
    next_scene_payload_entity_id = len(exported_nodes)

    total_nodes = len(exported_nodes)
    for entity_id, exported_node in enumerate(exported_nodes):
        first_mesh_record_index = len(meshes)
        mesh_record_count = 0

        if exported_node.skeleton is not None:
            exported_skeleton = exported_node.skeleton
            first_joint_record_index = len(skeleton_joints)
            for joint in exported_skeleton.joints:
                skeleton_joints.append(
                    SkeletonJointRecord(
                        parent_joint_index=joint.parent_index,
                        joint_path_offset=string_table.add(joint.path),
                        flags=0,
                        bind_transform_rows=joint.bind_transform_rows,
                        rest_transform_rows=joint.rest_transform_rows,
                    )
                )
            skeletons.append(
                SkeletonRecord(
                    entity_id=entity_id,
                    name_offset=string_table.add(exported_skeleton.name),
                    first_joint_record_index=first_joint_record_index,
                    joint_record_count=len(exported_skeleton.joints),
                )
            )

        if exported_node.mesh is not None:
            exported_mesh = exported_node.mesh
            material_index = add_material(exported_mesh.material)
            vertex_data_offset = vertex_writer.count
            index_data_offset = index_writer.count
            edge_index_data_offset = edge_index_writer.count
            vertex_writer.write_bytes(exported_mesh.vertices)
            index_writer.write_bytes(exported_mesh.indices)
            edge_index_writer.write_bytes(exported_mesh.edge_indices)

            meshes.append(
                MeshRecord(
                    entity_id=entity_id,
                    mesh_name_offset=string_table.add(exported_mesh.mesh_name),
                    material_index=material_index,
                    index_type=exported_mesh.index_type,
                    vertex_count=exported_mesh.vertex_count,
                    index_count=exported_mesh.index_count,
                    vertex_stride_bytes=VERTEX_STRIDE,
                    flags=0,
                    vertex_data_offset=vertex_data_offset,
                    index_data_offset=index_data_offset,
                    vertex_data_size_bytes=len(exported_mesh.vertices),
                    index_data_size_bytes=len(exported_mesh.indices),
                    estimated_gpu_bytes=(
                        exported_mesh.vertex_count * VERTEX_STRIDE
                        + exported_mesh.index_count * (2 if exported_mesh.index_type == INDEX_TYPE_UINT16 else 4)
                        + exported_mesh.edge_index_count * (2 if exported_mesh.index_type == INDEX_TYPE_UINT16 else 4)
                    ),
                    edge_index_data_offset=edge_index_data_offset,
                    edge_index_count=exported_mesh.edge_index_count,
                    local_bounds=exported_mesh.local_bounds,
                )
            )
            mesh_record_count = 1

            if exported_mesh.skin_binding is not None:
                skin_binding = exported_mesh.skin_binding
                first_joint_mapping_index = len(skin_joint_mappings)
                for skeleton_joint_index in skin_binding.skin_to_skeleton_map:
                    skin_joint_mappings.append(SkinJointMappingRecord(skeleton_joint_index=skeleton_joint_index))
                joint_index_data_offset = joint_index_writer.count
                joint_weight_data_offset = joint_weight_writer.count
                joint_index_writer.write_bytes(skin_binding.joint_indices)
                joint_weight_writer.write_bytes(skin_binding.joint_weights)
                skins.append(
                    SkinRecord(
                        entity_id=entity_id,
                        mesh_record_index=len(meshes) - 1,
                        skeleton_entity_id=entity_ids_by_name.get(skin_binding.skeleton_entity_name, INVALID_INDEX),
                        joint_count=skin_binding.joint_count,
                        first_joint_mapping_index=first_joint_mapping_index,
                        joint_index_data_offset=joint_index_data_offset,
                        joint_weight_data_offset=joint_weight_data_offset,
                        vertex_count=exported_mesh.vertex_count,
                    )
                )

        parent_entity_id = entity_ids_by_name.get(exported_node.parent_entity_name, INVALID_INDEX) if exported_node.parent_entity_name is not None else INVALID_INDEX
        entities.append(
            EntityRecord(
                entity_id=entity_id,
                parent_entity_id=parent_entity_id,
                name_offset=string_table.add(exported_node.entity_name),
                first_mesh_record_index=first_mesh_record_index,
                mesh_record_count=mesh_record_count,
                flags=0,
                local_bounds=exported_node.local_bounds,
                world_bounds=exported_node.world_bounds,
                local_transform_rows=exported_node.local_transform_rows,
            )
        )
        if progress_callback is not None:
            progress_callback("Build records", entity_id + 1, total_nodes, exported_node.entity_name)

    for exported_light in exported_lights:
        entity_id = next_scene_payload_entity_id
        next_scene_payload_entity_id += 1
        light_flags = LIGHT_FLAG_RADIOMETRIC
        if exported_light.casts_shadow:
            light_flags |= LIGHT_FLAG_CASTS_SHADOW
        if exported_light.range > 0.0:
            light_flags |= LIGHT_FLAG_CUSTOM_DISTANCE
        light_records.append(
            LightRecord(
                entity_id=entity_id,
                name_offset=string_table.add(exported_light.entity_name),
                light_type=exported_light.light_type,
                flags=light_flags,
                color=exported_light.color,
                intensity=exported_light.intensity,
                position=exported_light.position,
                radius=exported_light.radius,
                direction=exported_light.direction,
                # Binary-compatible reuse of the legacy falloff slot. The
                # RADIOMETRIC flag tells new runtimes this is influence range.
                falloff=exported_light.range,
                right=exported_light.right,
                inner_cone=exported_light.inner_cone,
                up=exported_light.up,
                outer_cone=exported_light.outer_cone,
                area_size=exported_light.area_size,
                source_power=exported_light.source_power,
                source_exposure=exported_light.source_exposure,
                local_transform_rows=exported_light.local_transform_rows,
            )
        )

    for exported_camera in exported_cameras:
        entity_id = next_scene_payload_entity_id
        next_scene_payload_entity_id += 1
        camera_records.append(
            CameraRecord(
                entity_id=entity_id,
                name_offset=string_table.add(exported_camera.entity_name),
                flags=0,
                position=exported_camera.position,
                forward=exported_camera.forward,
                up=exported_camera.up,
                right=exported_camera.right,
                fov_y_degrees=exported_camera.fov_y_degrees,
                near_clip=exported_camera.near_clip,
                far_clip=exported_camera.far_clip,
                aspect_ratio=exported_camera.aspect_ratio,
                local_transform_rows=exported_camera.local_transform_rows,
            )
        )

    if color_management_bake is not None:
        lut_texture_index = add_texture(color_management_bake.lut_texture, TEXTURE_FLAG_LUT)
        color_management_records.append(
            ColorManagementRecord(
                lut_texture_index=lut_texture_index,
                view_transform_name_offset=string_table.add(color_management_bake.view_transform),
                look_name_offset=string_table.add(color_management_bake.look),
                exposure=color_management_bake.exposure,
                gamma=color_management_bake.gamma,
                shaper_min_stops=color_management_bake.shaper_min_stops,
                shaper_max_stops=color_management_bake.shaper_max_stops,
                lut_size=color_management_bake.lut_size,
            )
        )

    if color_grade_lut is not None:
        color_grade_lut_records.append(
            ColorGradeLUTRecord(
                lut_uri_offset=string_table.add(color_grade_lut.uri),
                lut_size=color_grade_lut.lut_size,
                domain_min=color_grade_lut.domain_min,
                domain_max=color_grade_lut.domain_max,
            )
        )

    if progress_callback is not None:
        progress_callback("Build chunks", 0, 1, output_path.name)
    string_chunk = string_table.data
    entity_writer = BinaryWriter()
    for entity in entities:
        write_entity_record(entity_writer, entity)
    entity_chunk = entity_writer.data

    material_writer = BinaryWriter()
    for material in materials:
        write_material_record(material_writer, material)
    material_chunk = material_writer.data

    texture_writer = BinaryWriter()
    for texture_record in textures:
        write_texture_record(texture_writer, texture_record)
    texture_chunk = texture_writer.data

    light_writer = BinaryWriter()
    for light_record in light_records:
        write_light_record(light_writer, light_record)
    light_chunk = light_writer.data

    camera_writer = BinaryWriter()
    for camera_record in camera_records:
        write_camera_record(camera_writer, camera_record)
    camera_chunk = camera_writer.data

    color_management_writer = BinaryWriter()
    for color_management_record in color_management_records:
        write_color_management_record(color_management_writer, color_management_record)
    color_management_chunk = color_management_writer.data

    color_grade_lut_writer = BinaryWriter()
    for color_grade_lut_record in color_grade_lut_records:
        write_color_grade_lut_record(color_grade_lut_writer, color_grade_lut_record)
    color_grade_lut_chunk = color_grade_lut_writer.data

    skeleton_writer = BinaryWriter()
    for skeleton in skeletons:
        write_skeleton_record(skeleton_writer, skeleton)
    skeleton_chunk = skeleton_writer.data

    skeleton_joint_writer = BinaryWriter()
    for joint in skeleton_joints:
        write_skeleton_joint_record(skeleton_joint_writer, joint)
    skeleton_joint_chunk = skeleton_joint_writer.data

    skin_writer = BinaryWriter()
    for skin in skins:
        write_skin_record(skin_writer, skin)
    skin_chunk = skin_writer.data

    skin_mapping_writer = BinaryWriter()
    for mapping in skin_joint_mappings:
        write_skin_joint_mapping_record(skin_mapping_writer, mapping)
    skin_mapping_chunk = skin_mapping_writer.data

    mesh_writer = BinaryWriter()
    for mesh in meshes:
        write_mesh_record(mesh_writer, mesh)
    mesh_chunk = mesh_writer.data

    vertex_raw = vertex_writer.data
    index_raw = index_writer.data
    edge_index_raw = edge_index_writer.data
    joint_index_raw = joint_index_writer.data
    joint_weight_raw = joint_weight_writer.data

    if compress_geometry:
        if progress_callback is not None:
            progress_callback("Compress geometry", 0, 1, output_path.name)
        vertex_compressed, index_compressed = _compress_geometry_chunks(vertex_raw, index_raw)
        compressed_size = len(vertex_compressed) + len(index_compressed)
        raw_size = len(vertex_raw) + len(index_raw)
        if compressed_size < raw_size:
            vertex_payload, index_payload = vertex_compressed, index_compressed
            geo_compression = COMPRESSION_LZ4
            if progress_callback is not None:
                saved = raw_size - compressed_size
                progress_callback(
                    "Compress geometry",
                    1,
                    1,
                    f"{_format_byte_count(raw_size)} -> {_format_byte_count(compressed_size)} "
                    f"(saved {_format_byte_count(saved)})",
                )
        else:
            vertex_payload, index_payload = vertex_raw, index_raw
            geo_compression = COMPRESSION_NONE
            if progress_callback is not None:
                progress_callback(
                    "Compress geometry",
                    1,
                    1,
                    f"kept uncompressed; LZ4 would be {_format_byte_count(compressed_size)} "
                    f"for {_format_byte_count(raw_size)} raw geometry",
                )
    else:
        vertex_payload, index_payload = vertex_raw, index_raw
        geo_compression = COMPRESSION_NONE

    # Each entry: (chunk_type, compressed_payload, uncompressed_size, element_count, compression_type)
    chunk_payloads = [
        (CHUNK_TYPES["string_table"], string_chunk, len(string_chunk), 0, COMPRESSION_NONE),
        (CHUNK_TYPES["entity_table"], entity_chunk, len(entity_chunk), len(entities), COMPRESSION_NONE),
        (CHUNK_TYPES["mesh_table"], mesh_chunk, len(mesh_chunk), len(meshes), COMPRESSION_NONE),
        (CHUNK_TYPES["material_table"], material_chunk, len(material_chunk), len(materials), COMPRESSION_NONE),
        (CHUNK_TYPES["texture_table"], texture_chunk, len(texture_chunk), len(textures), COMPRESSION_NONE),
        (CHUNK_TYPES["skeleton_table"], skeleton_chunk, len(skeleton_chunk), len(skeletons), COMPRESSION_NONE),
        (CHUNK_TYPES["skeleton_joint_table"], skeleton_joint_chunk, len(skeleton_joint_chunk), len(skeleton_joints), COMPRESSION_NONE),
        (CHUNK_TYPES["skin_table"], skin_chunk, len(skin_chunk), len(skins), COMPRESSION_NONE),
        (CHUNK_TYPES["skin_joint_mapping_table"], skin_mapping_chunk, len(skin_mapping_chunk), len(skin_joint_mappings), COMPRESSION_NONE),
        (CHUNK_TYPES["light_table"], light_chunk, len(light_chunk), len(light_records), COMPRESSION_NONE),
        (CHUNK_TYPES["camera_table"], camera_chunk, len(camera_chunk), len(camera_records), COMPRESSION_NONE),
        (CHUNK_TYPES["vertex_data"], vertex_payload, len(vertex_raw), 0, geo_compression),
        (CHUNK_TYPES["index_data"], index_payload, len(index_raw), 0, geo_compression),
        (CHUNK_TYPES["edge_index_data"], edge_index_raw, len(edge_index_raw), 0, COMPRESSION_NONE),
        (CHUNK_TYPES["joint_index_data"], joint_index_raw, len(joint_index_raw), 0, COMPRESSION_NONE),
        (CHUNK_TYPES["joint_weight_data"], joint_weight_raw, len(joint_weight_raw), 0, COMPRESSION_NONE),
    ]
    if color_management_records:
        chunk_payloads.append(
            (
                CHUNK_TYPES["color_management_table"],
                color_management_chunk,
                len(color_management_chunk),
                len(color_management_records),
                COMPRESSION_NONE,
            )
        )
    if color_grade_lut_records:
        chunk_payloads.append(
            (
                CHUNK_TYPES["color_grade_lut_table"],
                color_grade_lut_chunk,
                len(color_grade_lut_chunk),
                len(color_grade_lut_records),
                COMPRESSION_NONE,
            )
        )

    # Content hash is computed over the (compressed) bytes in chunk order — matches
    # runtime validation in UntoldReader.validateContentHash.
    content_hash = hashlib.sha256(
        b"".join(payload for chunk_type, payload, _, _, _ in sorted(chunk_payloads, key=lambda item: item[0]))
    ).digest()
    file_type = FILE_TYPES[file_type_name]
    chunk_table_size = CHUNK_ENTRY_SIZE * len(chunk_payloads)
    running_offset = HEADER_SIZE + chunk_table_size
    # chunk_entries: (chunk_type, file_offset, compressed_size, uncompressed_size, element_count, compression_type)
    chunk_entries: list[tuple[int, int, int, int, int, int]] = []
    for chunk_type, payload, uncompressed_size, element_count, compression_type in chunk_payloads:
        running_offset = align(running_offset, FILE_ALIGNMENT)
        chunk_entries.append((chunk_type, running_offset, len(payload), uncompressed_size, element_count, compression_type))
        running_offset += len(payload)

    file_writer = BinaryWriter()
    write_header(
        file_writer,
        file_type=file_type,
        chunk_count=len(chunk_payloads),
        mesh_count=len(meshes),
        material_count=len(materials),
        texture_count=len(textures),
        entity_count=len(entities),
        world_bounds=world_bounds,
        root_transform_rows=[
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        ],
        content_hash=content_hash,
    )
    for chunk_type, file_offset, compressed_size, uncompressed_size, element_count, compression_type in chunk_entries:
        write_chunk_entry(
            file_writer,
            chunk_type=chunk_type,
            compression_type=compression_type,
            file_offset=file_offset,
            compressed_size=compressed_size,
            uncompressed_size=uncompressed_size,
            element_count=element_count,
        )
    total_chunks = len(chunk_payloads)
    for chunk_index, ((_, payload, _, _, _), (_, file_offset, _, _, _, _)) in enumerate(zip(chunk_payloads, chunk_entries), 1):
        file_writer.align(FILE_ALIGNMENT)
        if file_writer.count != file_offset:
            raise RuntimeError(
                f"Chunk offset mismatch while building {output_path}: expected {file_offset}, wrote {file_writer.count}"
            )
        file_writer.write_bytes(payload)
        if progress_callback is not None:
            progress_callback("Write chunks", chunk_index, total_chunks, output_path.name)
    return file_writer.data


def extract_animation_clips(asset_path: Path, convert_orientation: bool = False, source_orientation: str = "blender-native") -> list[ExportedAnimationClip]:
    blender_required()
    imported_objects = load_source_objects(asset_path)
    conversion_matrix = resolve_conversion_matrix(convert_orientation, source_orientation)
    armatures = [obj for obj in imported_objects if getattr(obj, "type", None) == "ARMATURE"]
    if not armatures:
        raise RuntimeError("No armature objects were found in the imported animation asset")

    armature = armatures[0]
    actions = list(getattr(bpy.data, "actions", []))
    if not actions and getattr(armature, "animation_data", None) is not None and armature.animation_data.action is not None:
        actions = [armature.animation_data.action]
    return extract_animation_clips_from_armature(
        armature,
        actions,
        conversion_matrix=conversion_matrix,
    )


def iter_action_fcurves(action: object) -> list[object]:
    legacy = getattr(action, "fcurves", None)
    if legacy is not None:
        try:
            return list(legacy)
        except TypeError:
            pass

    collected: list[object] = []
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for channelbag in getattr(strip, "channelbags", []):
                collected.extend(list(getattr(channelbag, "fcurves", [])))
    return collected


def extract_animation_clips_from_armature(
    armature: object,
    actions: list[object],
    *,
    conversion_matrix: Optional[object] = None,
) -> list[ExportedAnimationClip]:
    blender_required()
    if not actions:
        raise RuntimeError("No animation actions were provided for export")

    bones = list(getattr(armature.data, "bones", []))
    if not bones:
        raise RuntimeError("The selected armature has no bones")
    pose_bones = armature.pose.bones
    armature_world_matrix = armature.matrix_world.copy()
    fps = float(bpy.context.scene.render.fps) / float(getattr(bpy.context.scene.render, "fps_base", 1.0) or 1.0)

    clips: list[ExportedAnimationClip] = []
    previous_action = armature.animation_data.action if getattr(armature, "animation_data", None) is not None else None

    try:
        if getattr(armature, "animation_data", None) is None:
            armature.animation_data_create()
        for action in actions:
            armature.animation_data.action = action
            action_fcurves = iter_action_fcurves(action)
            keyframes = sorted({
                int(round(point.co.x))
                for fcurve in action_fcurves
                for point in fcurve.keyframe_points
            })
            if not keyframes:
                continue

            channels: list[ExportedAnimationChannel] = []
            for bone in bones:
                joint_path = bone_path(bone)
                translations: list[KeyframeVector3] = []
                rotations: list[KeyframeQuaternion] = []
                pose_bone = pose_bones.get(bone.name)
                if pose_bone is None:
                    continue

                for frame in keyframes:
                    bpy.context.scene.frame_set(frame)
                    pose_matrix = pose_bone.matrix.copy()
                    if pose_bone.parent is not None:
                        local_matrix = pose_bone.parent.matrix.inverted() @ pose_matrix
                    else:
                        # Match the baked model export: root-joint animation must include
                        # the armature object's world transform so clips live in the same
                        # normalized space as the exported skeleton bind/rest transforms.
                        local_matrix = armature_world_matrix @ pose_matrix
                    if conversion_matrix is not None:
                        local_matrix = conversion_matrix @ local_matrix @ conversion_matrix.inverted()
                    translation, rotation, _ = local_matrix.decompose()
                    time = float(frame) / fps
                    translations.append(KeyframeVector3(time=time, value=(float(translation.x), float(translation.y), float(translation.z))))
                    quat = rotation.normalized()
                    rotations.append(KeyframeQuaternion(time=time, value=(float(quat.x), float(quat.y), float(quat.z), float(quat.w))))

                channels.append(ExportedAnimationChannel(joint_path=joint_path, translations=translations, rotations=rotations))

            duration = max((channel.translations[-1].time if channel.translations else 0.0) for channel in channels) if channels else 0.0
            clips.append(ExportedAnimationClip(name=action.name, duration=duration, channels=channels))
    finally:
        if getattr(armature, "animation_data", None) is not None:
            armature.animation_data.action = previous_action

    if not clips:
        raise RuntimeError("No animation clips were extracted from the selected armature")
    return clips


def export_animation_clips_to_untold(
    exported_clips: list[ExportedAnimationClip],
    output_path: Path,
    progress_callback: Optional[ProgressCallback] = None,
) -> dict[str, object]:
    if progress_callback is not None:
        progress_callback("Build animation", 0, 1, output_path.name)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    untold_bytes = build_animation_untold_file(exported_clips, output_path)
    if progress_callback is not None:
        progress_callback("Write animation", 0, 1, output_path.name)
    output_path.write_bytes(untold_bytes)
    return {
        "output_path": output_path,
        "bytes_written": len(untold_bytes),
        "clip_count": len(exported_clips),
        "channel_count": sum(len(clip.channels) for clip in exported_clips),
        "duration": max((clip.duration for clip in exported_clips), default=0.0),
    }


def build_animation_untold_file(exported_clips: list[ExportedAnimationClip], output_path: Path) -> bytes:
    if not exported_clips:
        raise RuntimeError("No animation clips were extracted for export")

    string_table = StringTableBuilder()
    clip_records: list[AnimationClipRecord] = []
    channel_records: list[AnimationChannelRecord] = []
    translation_keyframes: list[TranslationKeyframeRecord] = []
    rotation_keyframes: list[RotationKeyframeRecord] = []

    for clip in exported_clips:
        first_channel_record_index = len(channel_records)
        for channel in clip.channels:
            first_translation_keyframe_index = len(translation_keyframes)
            first_rotation_keyframe_index = len(rotation_keyframes)
            translation_keyframes.extend(
                TranslationKeyframeRecord(time=keyframe.time, value=keyframe.value)
                for keyframe in channel.translations
            )
            rotation_keyframes.extend(
                RotationKeyframeRecord(time=keyframe.time, value=keyframe.value)
                for keyframe in channel.rotations
            )
            channel_records.append(
                AnimationChannelRecord(
                    joint_path_offset=string_table.add(channel.joint_path),
                    first_translation_keyframe_index=first_translation_keyframe_index,
                    translation_keyframe_count=len(channel.translations),
                    first_rotation_keyframe_index=first_rotation_keyframe_index,
                    rotation_keyframe_count=len(channel.rotations),
                )
            )

        clip_records.append(
            AnimationClipRecord(
                name_offset=string_table.add(clip.name),
                duration=clip.duration,
                first_channel_record_index=first_channel_record_index,
                channel_record_count=len(clip.channels),
            )
        )

    string_chunk = string_table.data
    clip_writer = BinaryWriter()
    for clip in clip_records:
        write_animation_clip_record(clip_writer, clip)
    clip_chunk = clip_writer.data

    channel_writer = BinaryWriter()
    for channel in channel_records:
        write_animation_channel_record(channel_writer, channel)
    channel_chunk = channel_writer.data

    translation_writer = BinaryWriter()
    for keyframe in translation_keyframes:
        write_translation_keyframe_record(translation_writer, keyframe)
    translation_chunk = translation_writer.data

    rotation_writer = BinaryWriter()
    for keyframe in rotation_keyframes:
        write_rotation_keyframe_record(rotation_writer, keyframe)
    rotation_chunk = rotation_writer.data

    chunk_payloads = [
        (CHUNK_TYPES["string_table"], string_chunk, len(string_chunk), 0, COMPRESSION_NONE),
        (CHUNK_TYPES["animation_clip_table"], clip_chunk, len(clip_chunk), len(clip_records), COMPRESSION_NONE),
        (CHUNK_TYPES["animation_channel_table"], channel_chunk, len(channel_chunk), len(channel_records), COMPRESSION_NONE),
        (CHUNK_TYPES["translation_keyframe_table"], translation_chunk, len(translation_chunk), len(translation_keyframes), COMPRESSION_NONE),
        (CHUNK_TYPES["rotation_keyframe_table"], rotation_chunk, len(rotation_chunk), len(rotation_keyframes), COMPRESSION_NONE),
    ]

    content_hash = hashlib.sha256(
        b"".join(payload for chunk_type, payload, _, _, _ in sorted(chunk_payloads, key=lambda item: item[0]))
    ).digest()
    chunk_table_size = CHUNK_ENTRY_SIZE * len(chunk_payloads)
    running_offset = HEADER_SIZE + chunk_table_size
    chunk_entries: list[tuple[int, int, int, int, int, int]] = []
    for chunk_type, payload, uncompressed_size, element_count, compression_type in chunk_payloads:
        running_offset = align(running_offset, FILE_ALIGNMENT)
        chunk_entries.append((chunk_type, running_offset, len(payload), uncompressed_size, element_count, compression_type))
        running_offset += len(payload)

    file_writer = BinaryWriter()
    write_header(
        file_writer,
        file_type=FILE_TYPES["animation"],
        chunk_count=len(chunk_payloads),
        mesh_count=0,
        material_count=0,
        texture_count=0,
        entity_count=0,
        world_bounds=AABB((0.0, 0.0, 0.0), (0.0, 0.0, 0.0)),
        root_transform_rows=[
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        ],
        content_hash=content_hash,
    )
    for chunk_type, file_offset, compressed_size, uncompressed_size, element_count, compression_type in chunk_entries:
        write_chunk_entry(
            file_writer,
            chunk_type=chunk_type,
            compression_type=compression_type,
            file_offset=file_offset,
            compressed_size=compressed_size,
            uncompressed_size=uncompressed_size,
            element_count=element_count,
        )
    for (_, payload, _, _, _), (_, file_offset, _, _, _, _) in zip(chunk_payloads, chunk_entries):
        file_writer.align(FILE_ALIGNMENT)
        if file_writer.count != file_offset:
            raise RuntimeError(
                f"Chunk offset mismatch while building animation asset {output_path}: expected {file_offset}, wrote {file_writer.count}"
            )
        file_writer.write_bytes(payload)
    return file_writer.data


def export_objects_to_untold(
    export_objects: list[object],
    *,
    source_asset_path: Path,
    output_path: Path,
    file_type_name: str = "tile",
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    validate: bool = False,
    compress_geometry: bool = False,
    bake_color_management: bool = False,
    color_lut_size: int = 32,
    color_grade_lut_path: Optional[Path] = None,
    clean_sidecars: bool = False,
    progress_callback: Optional[ProgressCallback] = None,
) -> dict[str, object]:
    exported_lights, exported_cameras = extract_scene_payload_from_objects(
        export_objects,
        convert_orientation=convert_orientation,
        source_orientation=source_orientation,
        include_scene_payload=True,
    )
    try:
        exported_nodes = extract_nodes_from_objects(
            export_objects,
            source_asset_path,
            convert_orientation=convert_orientation,
            source_orientation=source_orientation,
            validate=validate,
            progress_callback=progress_callback,
        )
    finally:
        cleanup_temporary_export_objects(export_objects)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if clean_sidecars:
        clean_generated_sidecar_dirs(output_path)

    color_management_bake: Optional[ColorManagementBake] = None
    if bake_color_management:
        if progress_callback is not None:
            progress_callback("Bake color management", 0, 1, "LUT")
        color_management_bake = bake_color_management_lut(
            validate_lut_size(color_lut_size),
            output_path.parent / "Textures",
        )

    color_grade_lut: Optional[ColorGradeLUT] = None
    if color_grade_lut_path is not None:
        if progress_callback is not None:
            progress_callback("Stage color grade LUT", 0, 1, color_grade_lut_path.name)
        color_grade_lut = stage_color_grade_lut_for_output(color_grade_lut_path, output_path.parent)

    exported_nodes = stage_nodes_for_output(exported_nodes, output_path, progress_callback=progress_callback)
    untold_bytes = build_untold_file(
        exported_nodes,
        output_path,
        file_type_name,
        exported_lights=exported_lights,
        exported_cameras=exported_cameras,
        compress_geometry=compress_geometry,
        color_management_bake=color_management_bake,
        color_grade_lut=color_grade_lut,
        progress_callback=progress_callback,
    )
    if progress_callback is not None:
        progress_callback("Write file", 0, 1, output_path.name)
    output_path.write_bytes(untold_bytes)

    exported_meshes = [
        exported_node.mesh
        for exported_node in exported_nodes
        if exported_node.mesh is not None
    ]

    validation_path: Optional[Path] = None
    if validate:
        validation_path = write_validation_file(
            output_path,
            output_path.stem,
            [exported_mesh.validation_mesh for exported_mesh in exported_meshes],
            color_management_bake,
        )

    return {
        "output_path": output_path,
        "validation_path": validation_path,
        "bytes_written": len(untold_bytes),
        "node_count": len(exported_nodes),
        "mesh_count": len(exported_meshes),
        "light_count": len(exported_lights),
        "camera_count": len(exported_cameras),
        "vertex_count": sum(exported_mesh.vertex_count for exported_mesh in exported_meshes),
        "index_count": sum(exported_mesh.index_count for exported_mesh in exported_meshes),
        "color_management_baked": color_management_bake is not None,
        "color_grade_lut_staged": color_grade_lut is not None,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser(description="Cook USD scene or animation data into UntoldEngine's .untold format.")
    parser.add_argument("--input", required=True, help="Path to a source USD/USDZ asset or a .blend file.")
    parser.add_argument("--output", required=True, help="Path to the output .untold file.")
    parser.add_argument("--file-type", default="tile", choices=sorted(FILE_TYPES.keys()), help="Untold file type to emit.")
    parser.add_argument("--mesh-name", default=None, help="Optional mesh object name when the USD asset imports multiple meshes.")
    parser.add_argument(
        "--convert-orientation",
        "--ConvertOrientation",
        action="store_true",
        dest="convert_orientation",
        help="Convert exported data into engine space (Forward +Z, Up +Y). Use --source-orientation to describe the input asset orientation.",
    )
    parser.add_argument(
        "--source-orientation",
        default="blender-native",
        choices=["blender-native", "engine-oriented"],
        help="Orientation of the input USD/USDZ before any exporter-side conversion. Use 'blender-native' for assets still in Blender's default space (-Y forward, +Z up), or 'engine-oriented' for assets already oriented to the engine's convention (+Z forward, +Y up).",
    )
    parser.add_argument("--validate", action="store_true", help="Write a companion .validation.json file for engine-side validation tests.")
    parser.add_argument(
        "--compress-geometry",
        action="store_true",
        help="Compress vertex and index chunks with LZ4 (requires: pip install lz4). Reduces file size without changing metadata chunks.",
    )
    parser.add_argument(
        "--animation",
        action="store_true",
        help="Export animation-only clip data keyed by the source armature joint paths instead of exporting mesh/model data.",
    )
    parser.add_argument(
        "--bake-color-management",
        action="store_true",
        help="Bake the scene's active View Transform/Look/Exposure/Gamma into a color-grading "
             "RGBA16Float LUT so Untold can closely reproduce Blender's sRGB display transform, "
             "including Filmic/AgX highlight compression.",
    )
    parser.add_argument(
        "--color-lut-size",
        type=int,
        default=32,
        help=f"Grid size (N) for the NxNxN color-grading LUT (default: 32, max: {MAX_COLOR_LUT_SIZE}).",
    )
    parser.add_argument(
        "--color-grade-lut",
        default=None,
        help="Path to an externally-authored standard .cube 3D LUT to stage alongside the export "
             "and apply as a post-tonemap creative grade. Unlike --bake-color-management, nothing is "
             "rendered or derived from Blender -- the .cube is copied as-is and loaded directly by "
             "the engine, so any LUT from any grading tool works.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    input_path = normalize_blender_path(args.input)
    output_path = normalize_blender_path(args.output)

    if input_path.suffix.lower() not in {".usd", ".usda", ".usdc", ".usdz", ".blend"}:
        raise RuntimeError(f"Unsupported source asset type: {input_path.suffix}")
    if not input_path.is_file():
        raise RuntimeError(f"Input asset does not exist: {input_path}")
    args.color_lut_size = validate_lut_size(args.color_lut_size)

    print(f"{'Opening' if input_path.suffix.lower() == '.blend' else 'Importing'} {input_path.name} ...", flush=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if args.animation:
        progress = ProgressReporter("animation export", 4)
        progress.stage("Open .blend" if input_path.suffix.lower() == ".blend" else "Import USD", input_path.name)
        exported_clips = extract_animation_clips(
            input_path,
            convert_orientation=args.convert_orientation,
            source_orientation=args.source_orientation,
        )
        progress.advance("Extract animation", f"{len(exported_clips)} clip(s)")
        print(f"Building animation .untold file with {len(exported_clips)} clip(s) ...", flush=True)
        untold_bytes = build_animation_untold_file(exported_clips, output_path)
        progress.advance("Build file", output_path.name)
        output_path.write_bytes(untold_bytes)
        progress.advance("Write file", output_path.name)
        print(f"Wrote {output_path} ({len(untold_bytes)} bytes)")
        print(f"Animation clips: {len(exported_clips)}")
        progress.advance("Complete", output_path.name)
    else:
        progress = ProgressReporter("asset export", 5)
        exported_nodes = extract_nodes(
            input_path,
            args.mesh_name,
            convert_orientation=args.convert_orientation,
            source_orientation=args.source_orientation,
            validate=args.validate,
            progress_callback=lambda stage, done, total, detail: progress.stage(
                stage,
                f"{done}/{total} {detail}" if total > 1 else detail,
            ),
        )
        progress.advance("Extract nodes", f"{len(exported_nodes)} node(s)")
        exported_lights, exported_cameras = extract_scene_payload_from_current_scene(
            mesh_name=args.mesh_name,
            convert_orientation=args.convert_orientation,
            source_orientation=args.source_orientation,
        )
        clean_generated_sidecar_dirs(output_path)
        print(f"Staging {len(exported_nodes)} node(s) ...", flush=True)
        exported_nodes = stage_nodes_for_output(exported_nodes, output_path)
        staged_hdr_assets = stage_hdr_assets_for_output(output_path.parent, input_path)
        progress.advance("Stage nodes", output_path.name)

        color_management_bake: Optional[ColorManagementBake] = None
        if args.bake_color_management:
            print("Baking color management LUT ...", flush=True)
            color_management_bake = bake_color_management_lut(
                args.color_lut_size,
                output_path.parent / "Textures",
            )

        color_grade_lut: Optional[ColorGradeLUT] = None
        if args.color_grade_lut:
            print(f"Staging color grade LUT {args.color_grade_lut} ...", flush=True)
            color_grade_lut = stage_color_grade_lut_for_output(Path(args.color_grade_lut), output_path.parent)

        print("Building .untold file ...", flush=True)
        untold_bytes = build_untold_file(
            exported_nodes,
            output_path,
            args.file_type,
            exported_lights=exported_lights,
            exported_cameras=exported_cameras,
            compress_geometry=args.compress_geometry,
            color_management_bake=color_management_bake,
            color_grade_lut=color_grade_lut,
            progress_callback=lambda stage, done, total, detail: progress.stage(
                stage,
                f"{done}/{total} {detail}" if total > 1 else detail,
            ),
        )
        progress.advance("Build file", output_path.name)
        output_path.write_bytes(untold_bytes)
        progress.advance("Write file", output_path.name)
        exported_meshes = [exported_node.mesh for exported_node in exported_nodes if exported_node.mesh is not None]
        print(f"Wrote {output_path} ({len(untold_bytes)} bytes)")
        print(f"Nodes: {len(exported_nodes)}, Meshes: {len(exported_meshes)}")
        print(f"Lights: {len(exported_lights)}, Cameras: {len(exported_cameras)}")
        if staged_hdr_assets:
            print(f"HDR environments: {len(staged_hdr_assets)}")
        if color_grade_lut is not None:
            print(f"Color grade LUT: {color_grade_lut.uri}")
        print(f"Vertices: {sum(exported_mesh.vertex_count for exported_mesh in exported_meshes)}, indices: {sum(exported_mesh.index_count for exported_mesh in exported_meshes)}")
        if args.validate:
            # This sidecar is only for validation/debugging in engine-side tests.
            validation_path = write_validation_file(output_path, output_path.stem, [exported_mesh.validation_mesh for exported_mesh in exported_meshes], color_management_bake)
            print(f"Wrote {validation_path}")
        progress.advance("Complete", output_path.name)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        raise
