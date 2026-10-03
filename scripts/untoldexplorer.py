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
from array import array
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
    "morph_target_table": 23,
    "morph_target_data": 24,
    "gaussian_asset_table": 25,
    "morph_driver_table": 26,
    "muscle_table": 27,
}

VERTEX_LAYOUT_PBR_STATIC_V1 = 1
MORPH_ENTRY_SIZE = 16
try:
    import numpy as _np_for_morphs
    _MORPH_DTYPE = _np_for_morphs.dtype([
        ("vi", "<u4"),
        ("px", "<u2"), ("py", "<u2"), ("pz", "<u2"),
        ("nx", "<u2"), ("ny", "<u2"), ("nz", "<u2"),
    ])
    assert _MORPH_DTYPE.itemsize == MORPH_ENTRY_SIZE
except ImportError:
    _MORPH_DTYPE = None
MORPH_FLAG_HAS_NORMAL_DELTAS = 1 << 0
MUSCLE_RECORD_SIZE = 128
MUSCLE_FLAG_HAS_DRIVER = 1 << 0
# Set from --export-shapekeys; shape keys are skipped entirely when False.
EXPORT_SHAPE_KEYS = False
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
# The name of the material a mesh with no material of its own is given. It is one name
# for all of them, and not one made from the object's name: the material is part of what
# tells two models apart (see model_content_signature), so a name taken from the object
# made every copy of a prop with no material a model of its own.
DEFAULT_MATERIAL_NAME = "default_material"
# Material alpha modes, the low two bits of a material record's flags (the engine's
# MaterialAlphaMode).
MATERIAL_ALPHA_MODE_OPAQUE = 0
MATERIAL_ALPHA_MODE_MASK = 1
MATERIAL_ALPHA_MODE_BLEND = 2
# The opacity a fully transmissive surface (Principled Transmission Weight 1) keeps
# when exported: the engine has no transmission, so glass becomes a blended surface
# this opaque, enough to keep its tint and reflections visible.
TRANSMISSION_OPACITY = 0.1
# Samples per channel of the lookup tables that carry RGB Curves and ColorRamp nodes.
CURVE_LUT_SIZE = 256
# Rec. 709 luminance, which Blender uses to turn a colour into a value (a Color output
# linked to a Fac or Alpha input).
LUMINANCE_WEIGHTS = (0.2126, 0.7152, 0.0722)
# Records the name of the source object a temporary export object stands in for:
# each single-material fragment produced by split_blender_objects_by_material(), and
# each mesh made from a curve, surface or text object by convert_curve_objects_to_meshes().
# Multi-model .untoldpack grouping (see group_export_nodes_by_root) uses it to reunite
# the fragments of one object into a single model, and extract_nodes_from_objects uses
# it to parent the source object's children to its stand-in.
UNTOLD_MATERIAL_SPLIT_SOURCE_PROP = "_untold_material_split_source"
# Object types whose evaluated geometry is exported as a mesh when it has faces (a
# curve with a bevel or extrusion, a surface, a text object).
CONVERTIBLE_GEOMETRY_OBJECT_TYPES = {"CURVE", "SURFACE", "FONT"}

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

    def string_at(self, offset: int) -> Optional[str]:
        for value, existing in self._offsets.items():
            if existing == offset:
                return value
        return None

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
class ColorGradeLUTRecord:
    """An externally-authored .cube LUT, applied as a post-tonemap creative grade.

    References a plain .cube file staged next to the export -- no Blender
    render/bake, no custom domain. The engine loads the .cube directly (see
    CubeLUTLoader) rather than through the native .utex texture pipeline, so
    there is no texture_index here.
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
class MuscleRecord:
    skeleton_entity_id: int
    name_offset: int
    flags: int
    forward_joint_offset: int
    forward_tip_joint_offset: int
    origin_joint_offset: int
    origin_tip_joint_offset: int
    origin_fraction: float
    origin_offset: tuple[float, float, float]
    insertion_joint_offset: int
    insertion_tip_joint_offset: int
    insertion_fraction: float
    insertion_offset: tuple[float, float, float]
    belly_radius: float
    tendon_radius: float
    max_contraction: float
    fiber_compliance: float
    cross_compliance: float
    volume_compliance: float
    damping: float
    bone_radius: float
    skin_influence: float
    rings: int
    segments: int
    driver_joint_offset: int
    driver_start_angle: float
    driver_full_angle: float


MUSCLE_DEFAULTS: dict[str, float] = {
    "maxContraction": 0.25,
    "fiberCompliance": 2e-6,
    "crossCompliance": 4e-6,
    "volumeCompliance": 0.0,
    "damping": 6.0,
    "boneRadius": 0.0,
    "skinInfluence": 0.03,
    "rings": 7,
    "segments": 8,
}


def load_muscle_rig(path: Path) -> dict:
    """Reads and validates a muscle rig description (`--muscles`).

    Schema (angles in degrees, lengths in model units, offsets in the character
    frame lateral-left / up / forward):

        {
          "skeleton": "Armature",                       # optional skeleton name
          "forwardReference": {"from": "LeftFoot", "to": "LeftToeBase"},   # optional
          "muscles": [
            {"name": "bicepsL",
             "origin":    {"joint": "LeftArm",     "fraction": 0.15, "offset": [0, 0, 0.03], "tip": null},
             "insertion": {"joint": "LeftForeArm", "fraction": 0.2,  "offset": [0, 0, 0.01]},
             "bellyRadius": 0.045, "tendonRadius": 0.012,
             "maxContraction": 0.25, "fiberCompliance": 2e-6, "crossCompliance": 4e-6,
             "volumeCompliance": 0, "damping": 6, "boneRadius": 0.03, "skinInfluence": 0.03,
             "rings": 7, "segments": 8,
             "driver": {"joint": "LeftForeArm", "startAngle": 10, "fullAngle": 110}}
          ]
        }
    """
    with open(path, "r", encoding="utf-8") as handle:
        rig = json.load(handle)
    return validate_muscle_rig(rig)


def validate_muscle_rig(rig: object) -> dict:
    if not isinstance(rig, dict) or not isinstance(rig.get("muscles"), list) or not rig["muscles"]:
        raise RuntimeError("Muscle rig JSON must be an object with a non-empty 'muscles' list")
    forward = rig.get("forwardReference")
    if forward is not None and (not isinstance(forward, dict) or not forward.get("from") or not forward.get("to")):
        raise RuntimeError("Muscle rig 'forwardReference' needs 'from' and 'to' joint names")
    for index, muscle in enumerate(rig["muscles"]):
        if not isinstance(muscle, dict) or not muscle.get("name"):
            raise RuntimeError(f"Muscle #{index} needs a 'name'")
        for key in ("origin", "insertion"):
            attachment = muscle.get(key)
            if not isinstance(attachment, dict) or not attachment.get("joint"):
                raise RuntimeError(f"Muscle {muscle['name']}: '{key}' needs a 'joint'")
            offset = attachment.get("offset", [0.0, 0.0, 0.0])
            if not isinstance(offset, (list, tuple)) or len(offset) != 3:
                raise RuntimeError(f"Muscle {muscle['name']}: '{key}.offset' must have three components")
        for key in ("bellyRadius", "tendonRadius"):
            if float(muscle.get(key, 0.0)) <= 0.0:
                raise RuntimeError(f"Muscle {muscle['name']}: '{key}' must be positive")
        if int(muscle.get("rings", MUSCLE_DEFAULTS["rings"])) < 2 or int(muscle.get("segments", MUSCLE_DEFAULTS["segments"])) < 3:
            raise RuntimeError(f"Muscle {muscle['name']}: needs rings >= 2 and segments >= 3")
        driver = muscle.get("driver")
        if driver is not None and (not isinstance(driver, dict) or not driver.get("joint")):
            raise RuntimeError(f"Muscle {muscle['name']}: 'driver' needs a 'joint'")
    return rig


def build_muscle_records(rig: dict, skeletons: list["SkeletonRecord"], string_table: "StringTableBuilder") -> list[MuscleRecord]:
    """Resolves a validated rig against the exported skeletons. The rig's
    'skeleton' name selects the target skeleton; the first exported skeleton is
    used otherwise."""
    if not skeletons:
        raise RuntimeError("--muscles requires a rigged (armature) export")
    target = skeletons[0]
    wanted = rig.get("skeleton")
    if wanted:
        matches = [
            skeleton for skeleton in skeletons
            if string_table.string_at(skeleton.name_offset) == wanted
        ]
        if not matches:
            raise RuntimeError(f"--muscles: skeleton '{wanted}' not found in the export")
        target = matches[0]

    forward = rig.get("forwardReference")
    forward_joint = string_table.add(forward["from"]) if forward else INVALID_INDEX
    forward_tip = string_table.add(forward["to"]) if forward else INVALID_INDEX

    def attachment_fields(attachment: dict) -> tuple[int, int, float, tuple[float, float, float]]:
        tip = attachment.get("tip")
        offset = attachment.get("offset", [0.0, 0.0, 0.0])
        return (
            string_table.add(str(attachment["joint"])),
            string_table.add(str(tip)) if tip else INVALID_INDEX,
            float(attachment.get("fraction", 0.5)),
            (float(offset[0]), float(offset[1]), float(offset[2])),
        )

    records: list[MuscleRecord] = []
    for muscle in rig["muscles"]:
        origin_joint, origin_tip, origin_fraction, origin_offset = attachment_fields(muscle["origin"])
        insertion_joint, insertion_tip, insertion_fraction, insertion_offset = attachment_fields(muscle["insertion"])
        driver = muscle.get("driver")
        flags = MUSCLE_FLAG_HAS_DRIVER if driver else 0

        def value(key: str) -> float:
            return float(muscle.get(key, MUSCLE_DEFAULTS[key]))

        records.append(
            MuscleRecord(
                skeleton_entity_id=target.entity_id,
                name_offset=string_table.add(str(muscle["name"])),
                flags=flags,
                forward_joint_offset=forward_joint,
                forward_tip_joint_offset=forward_tip,
                origin_joint_offset=origin_joint,
                origin_tip_joint_offset=origin_tip,
                origin_fraction=origin_fraction,
                origin_offset=origin_offset,
                insertion_joint_offset=insertion_joint,
                insertion_tip_joint_offset=insertion_tip,
                insertion_fraction=insertion_fraction,
                insertion_offset=insertion_offset,
                belly_radius=float(muscle["bellyRadius"]),
                tendon_radius=float(muscle["tendonRadius"]),
                max_contraction=value("maxContraction"),
                fiber_compliance=value("fiberCompliance"),
                cross_compliance=value("crossCompliance"),
                volume_compliance=value("volumeCompliance"),
                damping=value("damping"),
                bone_radius=value("boneRadius"),
                skin_influence=value("skinInfluence"),
                rings=int(muscle.get("rings", MUSCLE_DEFAULTS["rings"])),
                segments=int(muscle.get("segments", MUSCLE_DEFAULTS["segments"])),
                driver_joint_offset=string_table.add(str(driver["joint"])) if driver else INVALID_INDEX,
                driver_start_angle=math.radians(float(driver.get("startAngle", 0.0))) if driver else 0.0,
                driver_full_angle=math.radians(float(driver.get("fullAngle", 90.0))) if driver else 0.0,
            )
        )
    return records


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
    # Per-pixel colour nodes between the image and the socket it feeds (Invert, Gamma,
    # Bright/Contrast, Hue/Saturation/Value, RGB Curves, ColorRamp), in the order they
    # apply; staging writes the adjusted image (see adjust_staged_image).
    adjustments: tuple["ImageAdjustment", ...] = ()
    # The image is sRGB-encoded (its Blender colour space is not data): the adjustments
    # run on linear values, as Blender's shader nodes do.
    srgb_source: bool = False


@dataclass(frozen=True)
class ImageAdjustment:
    """One per-pixel colour operation of a shader node, applied to linear RGB values
    exactly as Blender's node does it.

    kind: "invert" (no params), "gamma" (gamma), "bright_contrast" (bright, contrast),
    "hue_saturation" (hue, saturation, value), "curves" (three lookup tables of
    CURVE_LUT_SIZE samples over [0, 1], for R, G and B) or "ramp" (three tables for
    R, G and B, indexed by the luminance of the input).
    fac: how much of the result is mixed over the input, for the nodes that have one.
    """
    kind: str
    params: tuple[float, ...] = ()
    fac: float = 1.0

    def key(self) -> str:
        return hashlib.sha1(repr((self.kind, self.params, self.fac)).encode("utf-8")).hexdigest()[:8]


@dataclass(frozen=True)
class UVTransform:
    """A texture-coordinate scale and offset applied to a mesh's first UV map, read
    from the Mapping node in front of a material's image textures."""
    scale: tuple[float, float]
    offset: tuple[float, float]

    def apply(self, uv: tuple[float, float]) -> tuple[float, float]:
        return (uv[0] * self.scale[0] + self.offset[0], uv[1] * self.scale[1] + self.offset[1])


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
    # MATERIAL_ALPHA_MODE_*: blended when the surface is not fully opaque in Blender.
    alpha_mode: int = MATERIAL_ALPHA_MODE_OPAQUE
    # A texture feeding the Principled Alpha input that is not the base colour
    # texture's own alpha. The engine reads alpha from the base colour texture only,
    # so staging writes it into that texture's alpha channel (see compose_alpha_texture).
    alpha_texture: Optional[ExportedTexture] = None


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
    morph_targets: tuple["ExportedMorphTarget", ...] = ()


@dataclass(frozen=True)
class ExportedNode:
    entity_name: str
    parent_entity_name: Optional[str]
    local_transform_rows: list[list[float]]
    local_bounds: AABB
    world_bounds: AABB
    skeleton: Optional[ExportedSkeleton] = None
    mesh: Optional[ExportedMesh] = None
    # Name of the object this node was split from by split_blender_objects_by_material(),
    # if any (see UNTOLD_MATERIAL_SPLIT_SOURCE_PROP). None for nodes that were never
    # material-split.
    material_split_root_name: Optional[str] = None


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
class ExportedMorphDriver:
    joint_path: str
    pose_rotation: tuple[float, float, float, float]
    radius: float
    kernel: int = 0


@dataclass(frozen=True)
class ExportedMorphTarget:
    name: str
    flags: int
    position_scale: float
    entry_count: int
    entries: bytes
    driver: Optional[ExportedMorphDriver] = None


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


class TextureWriteError(Exception):
    """Raised when Blender could not write a texture to disk, not even from a metadata-free copy."""


class TextureWriteFailures:
    """What one export has found out about the textures Blender cannot write.

    A pack or a tiled scene stages a texture once for every model or tile that uses it.
    Remembering a write that failed spares the others the attempt that fails and Blender's
    error output. It belongs to one export: the same image may be fine in the next one.
    """

    # Both by where the texture comes from (see texture_staging_key).
    # Written from a metadata-free copy instead: what went wrong with the ordinary write.
    written_from_copy: dict[str, str]
    # Left out of the export: why.
    left_out: dict[str, str]

    def __init__(self) -> None:
        self.written_from_copy = {}
        self.left_out = {}


class TextureStagingContext:
    staged_by_key: dict[str, Path]
    used_names: set[str]
    # One line per texture that was left out of the export, for the caller to report.
    skipped_textures: list[str]
    # Shared with the other models or tiles of the same export.
    write_failures: TextureWriteFailures
    # Where Textures/ goes; None means beside the output file.
    assets_dir: Optional[Path]

    def __init__(
        self,
        skipped_textures: Optional[list[str]] = None,
        write_failures: Optional[TextureWriteFailures] = None,
        assets_dir: Optional[Path] = None,
    ) -> None:
        self.staged_by_key = {}
        self.used_names = set()
        self.skipped_textures = skipped_textures if skipped_textures is not None else []
        self.write_failures = write_failures if write_failures is not None else TextureWriteFailures()
        self.assets_dir = assets_dir


class HDRStagingContext:
    staged_by_key: dict[str, Path]
    used_names: set[str]

    def __init__(self) -> None:
        self.staged_by_key = {}
        self.used_names = set()


def clean_generated_sidecar_dirs(output_path: Path, assets_dir: Optional[Path] = None) -> None:
    """Remove sidecar directories fully owned by a single-asset export.

    Re-exporting into an existing asset folder must not leave stale staged
    textures, baked .utex files, color LUTs, or HDR environments from earlier
    runs. The .untold file itself is overwritten separately. The sidecars live in
    assets_dir when the export was given one (see --assets-dir), else beside the
    output.
    """
    for dirname in ("Textures", "HDR"):
        sidecar_dir = (assets_dir or output_path.parent) / dirname
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


def pack_model_group_key(node: ExportedNode) -> str:
    """The .untoldpack model identity a root node resolves to.

    Ordinarily this is just the node's own entity_name. But a multi-material
    object with no real Blender parent gets replaced by several parentless
    material-split fragments (see split_blender_objects_by_material) that
    aren't parented to each other, so plain parent-chain walking can't reunite
    them -- material_split_root_name (the pre-split object's name) is used
    instead so they still collapse into one pack model.
    """
    return node.material_split_root_name if node.material_split_root_name is not None else node.entity_name


def normalize_export_nodes(nodes: list[ExportedNode]) -> list[ExportedNode]:
    """Bake every node's mesh vertices into its export-set root's local space.

    Each root's own local_transform_rows is folded into its (and its
    descendants') baked vertex data, and reset to identity afterward. Callers
    that need a model to be re-placeable after baking (e.g. a .untoldpack
    model, one of several sharing one manifest) must zero the root's
    local_transform_rows *before* calling this -- see zero_root_transform --
    otherwise the root's absolute placement in the source scene ends up baked
    into the geometry, and applying it again as an entity transform on load
    doubles it up.
    """
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


def zero_root_transform(nodes: list[ExportedNode]) -> list[ExportedNode]:
    """Reset every root node's (parent_entity_name is None) local_transform_rows
    to identity, leaving descendant transforms untouched.

    Used before normalize_export_nodes() when building one .untoldpack model's
    own .untold file, so that model's geometry gets baked relative to its own
    root instead of the source scene's absolute world space -- the root's real
    placement is carried separately in the manifest and applied once, at load
    time, as that model's entity transform.
    """
    return [
        replace(node, local_transform_rows=identity_matrix_rows()) if node.parent_entity_name is None else node
        for node in nodes
    ]


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


def write_morph_target_record(writer: BinaryWriter, mesh_record_index: int, name_offset: int, flags: int, first_entry_index: int, entry_count: int, position_scale: float) -> None:
    writer.write_u32(mesh_record_index)
    writer.write_u32(name_offset)
    writer.write_u32(flags)
    writer.write_u32(first_entry_index)
    writer.write_u32(entry_count)
    writer.write_f32(position_scale)


def write_morph_driver_record(writer: BinaryWriter, target_index: int, joint_path_offset: int, kernel: int, pose_rotation, radius: float) -> None:
    writer.write_u32(target_index)
    writer.write_u32(joint_path_offset)
    writer.write_u32(kernel)
    for component in pose_rotation:
        writer.write_f32(float(component))
    writer.write_f32(radius)
    writer.write_u32(0)


def write_muscle_record(writer: BinaryWriter, record: "MuscleRecord") -> None:
    """Serializes one UntoldMuscleRecordV1 (128 bytes, see assetFormat.md)."""
    writer.write_u32(record.skeleton_entity_id)
    writer.write_u32(record.name_offset)
    writer.write_u32(record.flags)
    writer.write_u32(record.forward_joint_offset)
    writer.write_u32(record.forward_tip_joint_offset)
    writer.write_u32(record.origin_joint_offset)
    writer.write_u32(record.origin_tip_joint_offset)
    writer.write_f32(record.origin_fraction)
    for component in record.origin_offset:
        writer.write_f32(float(component))
    writer.write_u32(record.insertion_joint_offset)
    writer.write_u32(record.insertion_tip_joint_offset)
    writer.write_f32(record.insertion_fraction)
    for component in record.insertion_offset:
        writer.write_f32(float(component))
    writer.write_f32(record.belly_radius)
    writer.write_f32(record.tendon_radius)
    writer.write_f32(record.max_contraction)
    writer.write_f32(record.fiber_compliance)
    writer.write_f32(record.cross_compliance)
    writer.write_f32(record.volume_compliance)
    writer.write_f32(record.damping)
    writer.write_f32(record.bone_radius)
    writer.write_f32(record.skin_influence)
    writer.write_u32(record.rings)
    writer.write_u32(record.segments)
    writer.write_u32(record.driver_joint_offset)
    writer.write_f32(record.driver_start_angle)
    writer.write_f32(record.driver_full_angle)
    writer.write_u32(0)


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
    return payload


def write_validation_file(
    output_path: Path,
    asset_name: str,
    validation_meshes: list[ValidationMesh],
) -> Path:
    validation_path = validation_path_for_output(output_path)
    payload = build_validation_payload(asset_name, validation_meshes)
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


def choose_export_objects(
    imported_objects: list[object],
    mesh_name: Optional[str],
    skipped_ancestor_ids: Optional[set[int]] = None,
) -> list[object]:
    """The mesh objects to export plus every ancestor they need as a transform node.

    skipped_ancestor_ids names objects that must not come back in as ancestors: objects
    left out of the export (see filter_scene_objects_for_export) and curves replaced by
    their mesh stand-ins (see convert_curve_objects_to_meshes). The walk continues past
    them to the next ancestor; extract_nodes_from_objects then places each child relative
    to the nearest ancestor that is exported.
    """
    mesh_objects = choose_mesh_objects(imported_objects, mesh_name)
    skipped_ids = skipped_ancestor_ids or set()
    selected_ids: set[int] = set()
    selected_objects: list[object] = []

    def add_object_and_ancestors(obj: object) -> None:
        current = obj
        chain: list[object] = []
        while current is not None:
            pointer = current.as_pointer()
            if pointer in selected_ids:
                break
            if pointer not in skipped_ids:
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


def _layer_collection_tree(layer_collection: object) -> Iterable[tuple[object, bool]]:
    """Yields (layer collection, disabled in renders) for a view layer's collection tree,
    leaving out excluded collections and everything under them; a collection is
    disabled in renders when it or any parent collection is."""
    stack = [(layer_collection, False)]
    while stack:
        current, parent_render_disabled = stack.pop()
        if getattr(current, "exclude", False):
            continue
        render_disabled = parent_render_disabled or bool(getattr(current.collection, "hide_render", False))
        yield current, render_disabled
        for child in current.children:
            stack.append((child, render_disabled))


def filter_scene_objects_for_export(objects: list[object], *, include_hidden: bool = False, quiet: bool = False) -> list[object]:
    """Drop the objects of a whole-scene export that Blender itself does not show.

    Objects that only live in collections excluded from the view layer (the checkbox
    in the Outliner) are always dropped: Blender does not evaluate them, so their
    transforms are stale, and they appear in no viewport or render.

    Hidden objects are dropped unless include_hidden is set: hidden in the viewport
    (the eye or the monitor icon, on the object or a collection holding it) or disabled
    in renders (the camera icon, on the object or on every collection holding it).
    Artists often hide what they are not working on, so include_hidden lets a game
    cook them anyway.
    """
    if bpy is None:
        return list(objects)
    view_layer = bpy.context.view_layer
    # Objects removed since the view layer last updated (an export's temporary
    # objects) are still listed, as None, until it does.
    objects = [obj for obj in objects if obj is not None]
    view_layer_object_ids = {obj.as_pointer() for obj in view_layer.objects if obj is not None}
    collection_render_disabled: dict[int, bool] = {}
    for layer_collection, render_disabled in _layer_collection_tree(view_layer.layer_collection):
        pointer = layer_collection.collection.as_pointer()
        collection_render_disabled[pointer] = collection_render_disabled.get(pointer, True) and render_disabled

    def is_hidden(obj: object) -> bool:
        if not obj.visible_get(view_layer=view_layer) or getattr(obj, "hide_render", False):
            return True
        states = [
            collection_render_disabled[collection.as_pointer()]
            for collection in getattr(obj, "users_collection", [])
            if collection.as_pointer() in collection_render_disabled
        ]
        return bool(states) and all(states)

    kept: list[object] = []
    excluded_names: list[str] = []
    hidden_names: list[str] = []
    for obj in objects:
        if obj.as_pointer() not in view_layer_object_ids:
            excluded_names.append(obj.name)
        elif not include_hidden and is_hidden(obj):
            hidden_names.append(obj.name)
        else:
            kept.append(obj)
    if quiet:
        return kept
    if excluded_names:
        print(f"  Skipped {len(excluded_names)} object(s) in collections excluded from the view layer", flush=True)
    if hidden_names:
        print(
            f"  Skipped {len(hidden_names)} hidden or render-disabled object(s): {', '.join(sorted(hidden_names))} "
            "(pass --include-hidden to export them)",
            flush=True,
        )
    return kept


def convert_curve_objects_to_meshes(objects: list[object]) -> tuple[list[object], set[int]]:
    """Replace each curve, surface or text object whose evaluated geometry has faces
    (a bevelled or extruded curve, for instance) with a temporary mesh object built
    from that geometry, placed and parented like the source.

    Returns the new object list and the pointers of the replaced source objects. A
    curve without faces (a path used by a Curve modifier or as a guide) is left as it
    is and exports nothing, as before.
    """
    if bpy is None or not any(getattr(obj, "type", None) in CONVERTIBLE_GEOMETRY_OBJECT_TYPES for obj in objects):
        return list(objects), set()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result: list[object] = []
    replaced_ids: set[int] = set()
    for obj in objects:
        if getattr(obj, "type", None) not in CONVERTIBLE_GEOMETRY_OBJECT_TYPES:
            result.append(obj)
            continue
        mesh = bpy.data.meshes.new_from_object(
            obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph
        )
        if len(mesh.polygons) == 0:
            bpy.data.meshes.remove(mesh)
            result.append(obj)
            continue
        print(f"  Converting {obj.type.lower()} '{obj.name}' to a mesh", flush=True)
        stand_in = bpy.data.objects.new(f"{obj.name}_mesh", mesh)
        stand_in.parent = obj.parent
        if obj.parent is not None:
            stand_in.matrix_parent_inverse = obj.matrix_parent_inverse.copy()
        stand_in.matrix_world = obj.matrix_world.copy()
        stand_in[UNTOLD_EXPORT_TEMP_OBJECT_PROP] = True
        stand_in[UNTOLD_MATERIAL_SPLIT_SOURCE_PROP] = obj.name
        bpy.context.scene.collection.objects.link(stand_in)
        result.append(stand_in)
        replaced_ids.add(obj.as_pointer())
    return result, replaced_ids


def prepare_export_objects_from_blender_objects(
    objects: list[object],
    mesh_name: Optional[str] = None,
    *,
    filter_scene: bool = False,
    include_hidden: bool = False,
) -> list[object]:
    """Apply the common Blender-object export preparation path.

    Used by both the CLI importer path and the Blender add-on path so object
    selection, curve conversion, linked armatures, and material splitting stay
    consistent.

    filter_scene applies filter_scene_objects_for_export (with include_hidden) first;
    the CLI sets it when it exports a whole scene. It is ignored when mesh_name picks
    one mesh, so an explicitly named mesh is exported even when hidden.
    """
    skipped_ids: set[int] = set()
    if filter_scene and mesh_name is None:
        kept = filter_scene_objects_for_export(objects, include_hidden=include_hidden)
        kept_ids = {obj.as_pointer() for obj in kept}
        skipped_ids = {
            obj.as_pointer()
            for obj in objects
            if obj.as_pointer() not in kept_ids
            and getattr(obj, "type", None) in CONVERTIBLE_GEOMETRY_OBJECT_TYPES | {"MESH"}
        }
        objects = kept
    objects, replaced_ids = convert_curve_objects_to_meshes(objects)
    export_objects = choose_export_objects(objects, mesh_name, skipped_ids | replaced_ids)
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
    # For SUN lights, Blender's `energy` is already irradiance in W/m² (the
    # "Strength" field), not radiant power in watts like other light types.
    # No unit conversion is needed here for either case; do not "fix" this
    # into a watts-style conversion for SUN lights.
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


def _image_is_srgb(image: object) -> bool:
    """True when Blender decodes the image from sRGB before shader nodes see it."""
    settings = getattr(image, "colorspace_settings", None)
    if settings is None or getattr(settings, "is_data", False):
        return False
    return "srgb" in str(getattr(settings, "name", "")).lower()


def _exported_texture_from_image(image: object, asset_path: Path, channel: int = TEXTURE_CHANNEL_R) -> ExportedTexture:
    """Build the pre-staging ExportedTexture for a Blender image datablock.

    File-backed images are keyed and named by their (resolved) source path. Packed
    and generated images have an empty filepath and no file on disk at all, so they
    are keyed and named by the Blender image name instead and written out through
    Blender at staging time (see stage_texture_for_output / write_blender_image_to_path).

    Deriving a path from the empty filepath is not an option: Path("") resolves to
    the asset's parent *directory*, which gave every packed image in a material the
    same source_path, name and uri. texture_staging_key keys on source_path first,
    so the staging pass collapsed all of them onto the first one written and the
    normal/roughness/metallic slots ended up pointing at the base color PNG.
    """
    source_image_name = getattr(image, "name", None)
    image_name = source_image_name or "texture"
    size = getattr(image, "size", ())
    width = int(size[0]) if len(size) > 0 else 0
    height = int(size[1]) if len(size) > 1 else 0
    mip_count = 1 if width > 0 and height > 0 else 0

    filepath = getattr(image, "filepath", "") or ""
    if not filepath:
        return ExportedTexture(
            name=image_name,
            uri=image_name,
            width=width,
            height=height,
            mip_count=mip_count,
            source_path=None,
            source_image_name=source_image_name,
            channel=channel,
            srgb_source=_image_is_srgb(image),
        )

    raw_path = bpy.path.abspath(filepath, library=getattr(image, "library", None)) if bpy is not None else filepath
    texture_path = Path(raw_path)
    if not texture_path.is_absolute():
        texture_path = (asset_path.parent / texture_path).resolve()
    try:
        uri = os.path.relpath(texture_path, asset_path.parent)
    except ValueError:
        uri = str(texture_path)
    return ExportedTexture(
        name=texture_path.name or image_name,
        uri=uri,
        width=width,
        height=height,
        mip_count=mip_count,
        source_path=texture_path,
        source_image_name=source_image_name,
        channel=channel,
        srgb_source=_image_is_srgb(image),
    )


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
        return _exported_texture_from_image(source_node.image, asset_path, channel=texture_channel)

    adjustment_input = _ADJUSTMENT_NODE_INPUTS.get(source_node.bl_idname)
    if adjustment_input is not None:
        # Written into the staged image (see stage_texture_for_output). A node whose
        # settings are themselves linked cannot be: the texture goes through as is and
        # material fidelity analysis reports the node, as before; a ColorRamp then
        # gives no texture, since its output is not the texture's.
        resolved = _resolve_texture_from_socket(source_node.inputs.get(adjustment_input), asset_path, visited_nodes, channel)
        if resolved is None:
            return None
        adjustment = image_adjustment_for_node(source_node, getattr(source_socket, "name", ""))
        if adjustment is NOT_REPRESENTABLE:
            return None if source_node.bl_idname == "ShaderNodeValToRGB" else resolved
        if adjustment is None:
            return resolved
        return replace(resolved, adjustments=resolved.adjustments + (adjustment,))

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


# The colour nodes written into a staged image, and the input the texture comes in by.
_ADJUSTMENT_NODE_INPUTS = {
    "ShaderNodeInvert": "Color",
    "ShaderNodeGamma": "Color",
    "ShaderNodeBrightContrast": "Color",
    "ShaderNodeHueSaturation": "Color",
    "ShaderNodeRGBCurve": "Color",
    "ShaderNodeCurveRGB": "Color",
    "ShaderNodeValToRGB": "Fac",
}

# image_adjustment_for_node's answer for a node an image adjustment cannot reproduce.
NOT_REPRESENTABLE = object()


def _unlinked_value(node: object, socket_name: str, default):
    """A setting's value, None when the socket is linked (its value varies per pixel)."""
    socket = node.inputs.get(socket_name) if getattr(node, "inputs", None) is not None else None
    if socket is None:
        return default
    if getattr(socket, "is_linked", False):
        return None
    value = getattr(socket, "default_value", default)
    return tuple(float(component) for component in value) if hasattr(value, "__len__") else float(value)


def _curve_mapping_tables(node: object) -> Optional[tuple[float, ...]]:
    """R, G and B lookup tables of an RGB Curves node: the combined (C) curve first,
    then each channel's own curve, as Cycles bakes them."""
    mapping = getattr(node, "mapping", None)
    curves = list(getattr(mapping, "curves", []))
    if mapping is None or len(curves) < 4:
        return None
    initialize = getattr(mapping, "initialize", None)
    if callable(initialize):
        initialize()
    positions = [index / (CURVE_LUT_SIZE - 1) for index in range(CURVE_LUT_SIZE)]
    combined = [mapping.evaluate(curves[3], position) for position in positions]
    tables: list[float] = []
    for channel in range(3):
        tables.extend(float(mapping.evaluate(curves[channel], value)) for value in combined)
    return tuple(tables)


def _color_ramp_tables(node: object) -> Optional[tuple[float, ...]]:
    ramp = getattr(node, "color_ramp", None)
    if ramp is None:
        return None
    samples = [ramp.evaluate(index / (CURVE_LUT_SIZE - 1)) for index in range(CURVE_LUT_SIZE)]
    return tuple(float(sample[channel]) for channel in range(3) for sample in samples)


def _is_identity_table(tables: tuple[float, ...]) -> bool:
    size = len(tables) // 3
    return all(
        abs(tables[channel * size + index] - index / (size - 1)) <= 1.0e-4
        for channel in range(3)
        for index in range(size)
    )


def image_adjustment_for_node(node: object, output_name: str = "Color"):
    """The image adjustment a colour node applies to the texture passing through it.

    Returns an ImageAdjustment, None for a node set up to change nothing, or
    NOT_REPRESENTABLE when a setting is linked (it varies per pixel) or, for a
    ColorRamp, when its Alpha output is the one used.
    """
    node_id = node.bl_idname
    if node_id == "ShaderNodeInvert":
        fac = _unlinked_value(node, "Fac", 1.0)
        if fac is None:
            return NOT_REPRESENTABLE
        return ImageAdjustment("invert", fac=fac) if fac != 0.0 else None
    if node_id == "ShaderNodeGamma":
        gamma = _unlinked_value(node, "Gamma", 1.0)
        if gamma is None:
            return NOT_REPRESENTABLE
        return ImageAdjustment("gamma", (gamma,)) if gamma != 1.0 else None
    if node_id == "ShaderNodeBrightContrast":
        bright = _unlinked_value(node, "Bright", 0.0)
        contrast = _unlinked_value(node, "Contrast", 0.0)
        if bright is None or contrast is None:
            return NOT_REPRESENTABLE
        return ImageAdjustment("bright_contrast", (bright, contrast)) if (bright, contrast) != (0.0, 0.0) else None
    if node_id == "ShaderNodeHueSaturation":
        values = [_unlinked_value(node, name, default) for name, default in (("Hue", 0.5), ("Saturation", 1.0), ("Value", 1.0), ("Fac", 1.0))]
        if any(value is None for value in values):
            return NOT_REPRESENTABLE
        hue, saturation, value, fac = values
        if fac == 0.0 or (abs(hue - 0.5) < 1.0e-6 and saturation == 1.0 and value == 1.0):
            return None
        return ImageAdjustment("hue_saturation", (hue, saturation, value), fac=fac)
    if node_id in {"ShaderNodeRGBCurve", "ShaderNodeCurveRGB"}:
        fac = _unlinked_value(node, "Fac", 1.0)
        tables = _curve_mapping_tables(node)
        if fac is None or tables is None:
            return NOT_REPRESENTABLE
        if fac == 0.0 or _is_identity_table(tables):
            return None
        return ImageAdjustment("curves", tables, fac=fac)
    if node_id == "ShaderNodeValToRGB":
        tables = _color_ramp_tables(node)
        if output_name != "Color" or tables is None:
            return NOT_REPRESENTABLE
        return ImageAdjustment("ramp", tables)
    return NOT_REPRESENTABLE


def _linked_source(input_socket: object) -> tuple[Optional[object], Optional[object]]:
    """The node and output socket feeding an input socket, looking through reroutes."""
    socket = input_socket
    while socket is not None and getattr(socket, "is_linked", False):
        link = socket.links[0]
        node = link.from_node
        if node.bl_idname != "NodeReroute":
            return node, getattr(link, "from_socket", None)
        socket = node.inputs.get("Input") if getattr(node, "inputs", None) is not None else None
    return None, None


def _is_uv_coordinate_source(node: Optional[object], from_socket: Optional[object]) -> bool:
    if node is None:
        return False
    if node.bl_idname == "ShaderNodeTexCoord":
        return getattr(from_socket, "name", "") == "UV"
    return node.bl_idname == "ShaderNodeUVMap"


def mapping_node_uv_transform(node: object) -> Optional[UVTransform]:
    """The UV scale and offset a Mapping node applies, or None when a positive UV scale
    and offset cannot represent it: a rotation, a linked Location/Rotation/Scale, a
    Normal mapping, or a zero or negative scale (which would also flip normal maps)."""
    vector_type = getattr(node, "vector_type", "POINT")
    if vector_type not in {"POINT", "TEXTURE", "VECTOR"}:
        return None
    inputs = getattr(node, "inputs", None)
    if inputs is None:
        return None
    for name in ("Location", "Rotation", "Scale"):
        socket = inputs.get(name)
        if socket is not None and getattr(socket, "is_linked", False):
            return None
    if not _socket_is_identity(node, "Rotation", (0.0, 0.0, 0.0)):
        return None
    scale_socket = inputs.get("Scale")
    scale = scale_socket.default_value if scale_socket is not None else (1.0, 1.0, 1.0)
    scale_x, scale_y = float(scale[0]), float(scale[1])
    if scale_x <= 1.0e-8 or scale_y <= 1.0e-8:
        return None
    location_socket = inputs.get("Location")
    location = location_socket.default_value if location_socket is not None and vector_type != "VECTOR" else (0.0, 0.0, 0.0)
    location_x, location_y = float(location[0]), float(location[1])
    if vector_type == "TEXTURE":
        # Texture mapping moves the texture instead of the coordinates: the inverse.
        return UVTransform((1.0 / scale_x, 1.0 / scale_y), (-location_x / scale_x, -location_y / scale_y))
    return UVTransform((scale_x, scale_y), (location_x, location_y))


def image_node_uv_transform(image_node: object) -> tuple[bool, Optional[UVTransform]]:
    """How an Image Texture node's coordinates relate to the mesh's UVs.

    Returns (True, None) when it samples the UVs as they are (Vector unlinked or fed
    by UV coordinates), (True, transform) when a Mapping node the exporter can apply
    to the UVs sits in between, and (False, None) for anything else (generated or
    object coordinates, rotations, node math on the vector).
    """
    node, from_socket = _linked_source(image_node.inputs.get("Vector"))
    if node is None:
        return True, None
    if _is_uv_coordinate_source(node, from_socket):
        return True, None
    if node.bl_idname == "ShaderNodeMapping":
        mapping_source, mapping_socket = _linked_source(node.inputs.get("Vector"))
        transform = mapping_node_uv_transform(node)
        if transform is not None and _is_uv_coordinate_source(mapping_source, mapping_socket):
            return True, transform
    return False, None


def _uv_transform_key(transform: Optional[UVTransform]) -> tuple[float, ...]:
    if transform is None:
        return (1.0, 1.0, 0.0, 0.0)
    return tuple(round(value, 6) for value in (*transform.scale, *transform.offset))


def _material_image_uv_transforms(material: object) -> list[Optional[UVTransform]]:
    """The UV transform of every connected Image Texture node the exporter can map to UVs."""
    node_tree = getattr(material, "node_tree", None)
    transforms: list[Optional[UVTransform]] = []
    for node in getattr(node_tree, "nodes", []):
        if node.bl_idname != "ShaderNodeTexImage" or getattr(node, "image", None) is None:
            continue
        if not any(getattr(output, "is_linked", False) for output in getattr(node, "outputs", [])):
            continue
        representable, transform = image_node_uv_transform(node)
        if representable:
            transforms.append(transform)
    return transforms


def material_uv_transform(material: Optional[object]) -> Optional[UVTransform]:
    """The UV scale and offset to bake into a mesh's first UV map for its material.

    The engine has no per-material texture transform, so the Mapping node in front
    of the material's image textures (typically a tiling scale) is applied to the
    UVs instead. When the textures disagree, the transform most of them use wins and
    material fidelity analysis reports the others.
    """
    if material is None:
        return None
    transforms = _material_image_uv_transforms(material)
    if not transforms:
        return None
    counts: dict[tuple[float, ...], int] = {}
    first_by_key: dict[tuple[float, ...], Optional[UVTransform]] = {}
    for transform in transforms:
        key = _uv_transform_key(transform)
        counts[key] = counts.get(key, 0) + 1
        first_by_key.setdefault(key, transform)
    winner = max(counts, key=lambda key: counts[key])
    return first_by_key[winner]


def mesh_object_material(mesh_object: object) -> Optional[object]:
    """The material the mesh's faces use. Each exported mesh has one (multi-material
    objects are split first), but it need not sit in the first slot: an object can use
    only its second material, which used to export as the first one. Object-linked
    slots are honoured through material_slots."""
    data = getattr(mesh_object, "data", None)
    polygons = getattr(data, "polygons", None)
    try:
        index = int(polygons[0].material_index) if polygons is not None and len(polygons) > 0 else 0
    except (TypeError, IndexError, AttributeError):
        index = 0
    slots = getattr(mesh_object, "material_slots", None)
    if slots is not None and index < len(slots):
        material = getattr(slots[index], "material", None)
        if material is not None:
            return material
    materials = getattr(data, "materials", [])
    if materials and index < len(materials) and materials[index] is not None:
        return materials[index]
    return materials[0] if materials and materials[0] is not None else None


def _emission_surface_node(material: object) -> Optional[object]:
    """The Emission shader wired straight into the active Material Output's Surface, if any."""
    node_tree = getattr(material, "node_tree", None)
    if node_tree is None:
        return None
    output_node = _material_output_node(node_tree)
    if output_node is None:
        return None
    node, _ = _linked_source(output_node.inputs.get("Surface"))
    return node if node is not None and node.bl_idname == "ShaderNodeEmission" else None


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
    "ShaderNodeFresnel": "view-dependent; exported as seen straight on",
    "ShaderNodeLayerWeight": "view-dependent; exported as seen straight on",
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
    # Applied to the mesh's UVs (material_uv_transform) and written into the staged
    # texture (stage_texture_for_output) respectively.
    if (
        node_id == "ShaderNodeMapping"
        and mapping_node_uv_transform(node) is not None
        and _is_uv_coordinate_source(*_linked_source(node.inputs.get("Vector")))
    ):
        return None
    if node_id in _ADJUSTMENT_NODE_INPUTS and image_adjustment_for_node(node, from_socket_name) is not NOT_REPRESENTABLE:
        return None
    if node_id in {"ShaderNodeBsdfTransparent", "ShaderNodeMixShader"}:
        return MaterialGraphFinding(
            node_name, node_id, MATERIAL_GRAPH_BAKEABLE,
            "approximated: the surface is blended at the opacity the shaders mix to",
        )
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

    # An Emission shader used as the whole surface is exported as an emissive material.
    emission_node = _emission_surface_node(material)
    if emission_node is not None:
        emission_name = getattr(emission_node, "name", "") or emission_node.bl_idname
        findings = [finding for finding in findings if finding.node_name != emission_name]

    principled = _principled_bsdf_node(node_tree)
    if principled is not None:
        transmission, unfollowed = principled_transmission(principled)
        if transmission or unfollowed:
            opacity = 1.0 - transmission * (1.0 - TRANSMISSION_OPACITY)
            reason = f"transmission is approximated as a blended surface at {opacity:.0%} opacity"
            if unfollowed:
                reason = (
                    "Transmission is driven by a texture or node math the exporter cannot follow; "
                    f"its slider value {transmission:.2f} is used, so {reason}"
                )
            findings.append(
                MaterialGraphFinding(
                    getattr(principled, "name", "") or principled.bl_idname,
                    principled.bl_idname,
                    MATERIAL_GRAPH_BAKEABLE,
                    reason,
                )
            )

    distinct_uv_transforms = {_uv_transform_key(transform) for transform in _material_image_uv_transforms(material)}
    if len(distinct_uv_transforms) > 1:
        findings.append(
            MaterialGraphFinding(
                material_name,
                "ShaderNodeMapping",
                MATERIAL_GRAPH_BAKEABLE,
                "image textures use different Mapping transforms; only the most common one is applied to the UVs",
            )
        )

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
# Color-grade LUT import (.cube)
#
# Stages an externally-authored standard .cube file as-is -- no bake, no
# shaper encoding, no .utex conversion. It's meant to be applied as a
# creative grade *on top of*
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


def stage_color_grade_lut_for_output(lut_path: Path, output_dir: Path, uri_base: Optional[Path] = None) -> ColorGradeLUT:
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
        # Relative to the file that references it (uri_base), which is output_dir
        # unless the export keeps its assets in a separate folder.
        uri=relative_asset_uri(destination_path, uri_base or output_dir),
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


def write_blender_image_to_path(
    image_name: str,
    destination_path: Path,
    *,
    preserve_precision: bool = False,
    failed_write_problem: Optional[str] = None,
) -> Optional[str]:
    """Write a Blender image to destination_path in a form the engine can load.

    Returns None when Blender wrote the image as it is. When it could only be written
    from a metadata-free copy, returns what went wrong with the ordinary write. Hand that
    back as failed_write_problem the next time the same image is written, and the write
    that fails is not attempted again.
    """
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

    # Must read the source file's own header before filepath_raw is overwritten to the
    # destination path in _save_blender_image — image.filepath/.filepath_raw both then
    # point at the (not yet written) output PNG, not the original source, and the header
    # would resolve to the wrong file or nothing at all.
    source_info = _source_bit_depth_and_channels(image)

    def save(target: object) -> Optional[str]:
        """Write target to destination_path. Returns what went wrong, or None if nothing did."""
        try:
            _save_blender_image(
                target,
                destination_path,
                image_name=image_name,
                source_image=image,
                source_info=source_info,
                preserve_precision=preserve_precision,
            )
        except (RuntimeError, OSError) as exc:
            lines = str(exc).strip().splitlines()
            return lines[0] if lines else type(exc).__name__
        return _written_image_problem(destination_path)

    can_copy = _can_copy_without_metadata(image)
    problem = failed_write_problem if can_copy else None
    failed_before = problem is not None
    if not failed_before:
        problem = save(image)
        if problem is None:
            return None

        # Blender writes the metadata it read from an image's source file back out on every
        # save, and a bad entry can abort the write after the file has been started. Seen
        # with JPEGs that Blender itself saved from a source with an embedded ICC profile:
        # they carry a "Blender:ICCProfile:..." comment, which comes back as a text entry
        # named ICCProfile that the PNG writer takes for the profile itself. libpng rejects
        # it ("ICC profile too short") once the PNG header is on disk, leaving a 33-byte
        # file. The pixels are fine, so write them again from a copy that has no metadata.
        _remove_incomplete_file(destination_path)
        if not can_copy:
            raise TextureWriteError(f"'{image_name}' could not be written: {problem}. Skipping texture.")
        print(f"  Blender could not write image '{image_name}' ({problem}). Retrying from a copy without the source file's metadata.", flush=True)

    try:
        metadata_free_copy = _metadata_free_image_copy(image)
    except Exception as exc:
        raise TextureWriteError(
            f"'{image_name}' could not be written: {problem}. "
            f"Copying its pixels for a second attempt failed too: {exc}. Skipping texture."
        ) from exc
    try:
        retry_problem = save(metadata_free_copy)
    finally:
        bpy.data.images.remove(metadata_free_copy)
    if retry_problem is not None:
        _remove_incomplete_file(destination_path)
        raise TextureWriteError(
            f"'{image_name}' could not be written: {problem}. "
            f"A second attempt from a copy without metadata failed too: {retry_problem}. Skipping texture."
        )
    if not failed_before:
        print(f"  Wrote image '{image_name}' from the copy.", flush=True)
    return problem


def _png_is_complete(path: Path) -> bool:
    """Return True when a PNG was written through to its closing IEND chunk.

    libpng writes the signature and IHDR before anything else, so a write that fails
    later leaves a header-only file that still passes a signature check.
    """
    iend_chunk = b"\x00\x00\x00\x00IEND\xaeB`\x82"
    try:
        with open(path, "rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return False
            f.seek(-len(iend_chunk), os.SEEK_END)
            return f.read() == iend_chunk
    except OSError:
        return False


def _written_image_problem(path: Path) -> Optional[str]:
    """Return what is wrong with a just-written image file, or None when it is complete."""
    if not path.is_file():
        return "no file was written"
    size = path.stat().st_size
    if size == 0:
        return "the file is empty"
    if path.suffix.lower() == ".png" and not _png_is_complete(path):
        return f"the PNG is incomplete ({size} bytes, no closing IEND chunk)"
    return None


def _remove_incomplete_file(path: Path) -> None:
    """Delete what a failed write left behind, so a truncated file never outlives the failure."""
    try:
        path.unlink(missing_ok=True)
    except OSError as exc:
        print(f"  Warning: could not remove incomplete file '{path}': {exc}", flush=True)


def _can_copy_without_metadata(image: object) -> bool:
    """Return True when _metadata_free_image_copy reproduces the image exactly.

    That holds for 8-bit images, which Blender keeps as RGBA bytes in the image's own
    color space. A float buffer holds scene-linear values instead, and a generated copy
    of those is not written back the way its source is: a 16-bit sRGB texture came out
    darker. A texture that is reported as skipped is better than one that is subtly wrong.
    """
    return not getattr(image, "is_float", False) and getattr(image, "channels", 0) == 4


def _metadata_free_image_copy(image: object) -> object:
    """Copy an image's pixels into a new datablock that has none of its source file's metadata.

    Blender has no Python API to edit or drop the metadata an image was loaded with. A
    generated image has no source file and so no metadata, which makes it a way to get the
    same pixels to disk without it. The caller removes the copy once it is saved.
    """
    width, height = int(image.size[0]), int(image.size[1])
    # image.depth is the bits per pixel of the source: only 32 (RGBA) and 16 (gray + alpha)
    # have an alpha channel to keep.
    copy = bpy.data.images.new(
        f"{image.name}.untold_export",
        width=width,
        height=height,
        alpha=image.depth in (16, 32),
    )
    try:
        # Before the pixels: changing the color space of a generated image clears them.
        copy.colorspace_settings.name = image.colorspace_settings.name
        copy.alpha_mode = image.alpha_mode
        pixels = array("f", bytes(4 * width * height * 4))
        image.pixels.foreach_get(pixels)
        copy.pixels.foreach_set(pixels)
    except Exception:
        bpy.data.images.remove(copy)
        raise
    return copy


def _save_blender_image(
    image: object,
    destination_path: Path,
    *,
    image_name: str,
    source_image: object,
    source_info: Optional[tuple[int, int]],
    preserve_precision: bool,
) -> None:
    """Save image to destination_path, converted as the engine needs.

    image is the datablock that gets written: source_image itself, or a metadata-free
    copy of it. What to convert is always decided from source_image and source_info.
    """
    original_filepath_raw = getattr(image, "filepath_raw", "")
    original_file_format = getattr(image, "file_format", "PNG")
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
        # directly (JPEG, packed images, generated images, etc.). Captured by the caller,
        # before filepath_raw was overwritten to point at the destination instead of the source.
        if source_info is not None:
            bits_per_sample, image_channels = source_info
            image_depth = bits_per_sample * image_channels
        else:
            image_depth = getattr(source_image, "depth", 0)
            image_channels = getattr(source_image, "channels", 4)
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
            # Height/displacement and normal maps are the channels that want to keep their
            # precision instead of being flattened to 8-bit: POM ray-marches height data, and
            # 8-bit quantization becomes visible stair-stepping at grazing angles once amplified
            # by the parallax offset math (see HeightMapParallaxOcclusionMapping.md §2.2).
            # Normal maps encode fine per-texel surface detail (fabric weave, wrinkles, ...);
            # quantizing that to 8-bit before ASTC compression even runs compounds into visible
            # noise once lit. The sRGB-16-bit Metal gap that forces 8-bit for color textures
            # doesn't apply to either — both are always linear/non-color data. PNG supports
            # 16-bit grayscale and RGB natively, so only skip the downconvert when there's real
            # precision to keep.
            target_depth = "16" if (preserve_precision and image_depth >= 16) else "8"
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
            colorspace_name = getattr(getattr(source_image, "colorspace_settings", None), "name", "sRGB")
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


def adjustments_suffix(adjustments: tuple[ImageAdjustment, ...]) -> str:
    """Tells an adjusted image apart from its source in staging keys and file names:
    "_inverted" for a lone Invert (readable, and what earlier exports wrote), else a
    short fingerprint of the adjustments."""
    if not adjustments:
        return ""
    if adjustments == (ImageAdjustment("invert"),):
        return "_inverted"
    return "_adj" + hashlib.sha1("|".join(adjustment.key() for adjustment in adjustments).encode("utf-8")).hexdigest()[:8]


def texture_staging_key(texture: ExportedTexture) -> str:
    inverted = adjustments_suffix(texture.adjustments)
    if texture.source_path is not None:
        return f"path:{texture.source_path.expanduser().resolve()}{inverted}"
    if texture.source_image_name:
        return f"image:{texture.source_image_name}{inverted}"
    return f"uri:{texture.uri}{inverted}"


def srgb_to_linear(values: "np.ndarray") -> "np.ndarray":
    return np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(values: "np.ndarray") -> "np.ndarray":
    values = np.clip(values, 0.0, 1.0)
    return np.where(values <= 0.0031308, values * 12.92, 1.055 * np.power(values, 1.0 / 2.4) - 0.055)


def _rgb_to_hsv(rgb: "np.ndarray") -> "np.ndarray":
    maximum = rgb.max(axis=1)
    minimum = rgb.min(axis=1)
    delta = maximum - minimum
    value = maximum
    saturation = np.where(maximum > 0.0, delta / np.where(maximum > 0.0, maximum, 1.0), 0.0)
    safe_delta = np.where(delta > 0.0, delta, 1.0)
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    hue = np.where(
        maximum == r,
        (g - b) / safe_delta,
        np.where(maximum == g, 2.0 + (b - r) / safe_delta, 4.0 + (r - g) / safe_delta),
    )
    hue = np.where(delta > 0.0, (hue / 6.0) % 1.0, 0.0)
    return np.stack([hue, saturation, value], axis=1)


def _hsv_to_rgb(hsv: "np.ndarray") -> "np.ndarray":
    hue, saturation, value = hsv[:, 0], hsv[:, 1], hsv[:, 2]
    sector = (hue % 1.0) * 6.0
    index = np.floor(sector).astype(np.int32) % 6
    fraction = sector - np.floor(sector)
    p = value * (1.0 - saturation)
    q = value * (1.0 - saturation * fraction)
    t = value * (1.0 - saturation * (1.0 - fraction))
    choices_r = np.stack([value, q, p, p, t, value], axis=1)
    choices_g = np.stack([t, value, value, q, p, p], axis=1)
    choices_b = np.stack([p, p, t, value, value, q], axis=1)
    rows = np.arange(len(hue))
    return np.stack([choices_r[rows, index], choices_g[rows, index], choices_b[rows, index]], axis=1)


def _lookup(table: "np.ndarray", values: "np.ndarray") -> "np.ndarray":
    """Linear interpolation into a table sampled evenly over [0, 1]."""
    return np.interp(np.clip(values, 0.0, 1.0), np.linspace(0.0, 1.0, len(table)), table)


def apply_image_adjustments(rgb: "np.ndarray", adjustments: Iterable[ImageAdjustment]) -> "np.ndarray":
    """Run linear RGB values (an N x 3 array) through shader-node adjustments, using the
    same formulas as Cycles' nodes (svm_gamma, svm_brightness, svm_hsv, svm_invert,
    curves and ramp lookups)."""
    result = np.asarray(rgb, dtype=np.float64)
    for adjustment in adjustments:
        before = result
        params = adjustment.params
        if adjustment.kind == "invert":
            result = 1.0 - result
        elif adjustment.kind == "gamma":
            result = np.where(result > 0.0, np.power(np.maximum(result, 0.0), params[0]), result)
        elif adjustment.kind == "bright_contrast":
            bright, contrast = params
            result = np.maximum((1.0 + contrast) * result + (bright - contrast * 0.5), 0.0)
        elif adjustment.kind == "hue_saturation":
            hue, saturation, value = params
            hsv = _rgb_to_hsv(result)
            hsv[:, 0] = (hsv[:, 0] + hue + 0.5) % 1.0
            hsv[:, 1] = np.clip(hsv[:, 1] * saturation, 0.0, 1.0)
            hsv[:, 2] = hsv[:, 2] * value
            result = _hsv_to_rgb(hsv)
        elif adjustment.kind == "curves":
            tables = np.asarray(params, dtype=np.float64).reshape(3, -1)
            result = np.stack([_lookup(tables[channel], result[:, channel]) for channel in range(3)], axis=1)
        elif adjustment.kind == "ramp":
            tables = np.asarray(params, dtype=np.float64).reshape(3, -1)
            luminance = result @ np.asarray(LUMINANCE_WEIGHTS)
            result = np.stack([_lookup(tables[channel], luminance) for channel in range(3)], axis=1)
        else:
            raise ValueError(f"Unknown image adjustment: {adjustment.kind}")
        if adjustment.fac != 1.0:
            result = before + (result - before) * adjustment.fac
        if adjustment.kind == "hue_saturation":
            result = np.maximum(result, 0.0)
    return result


def adjust_staged_image(path: Path, adjustments: tuple[ImageAdjustment, ...], *, srgb: bool) -> None:
    """Apply shader-node adjustments to the colour channels of a staged image in place,
    leaving alpha alone. An sRGB image is decoded to linear first and encoded back, so
    the nodes see the values Blender's shader sees."""
    blender_required()
    if not _HAS_NUMPY:
        print(f"  Warning: '{path.name}' needs numpy to apply its colour nodes; staged without them.", flush=True)
        return
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        image.colorspace_settings.name = "Non-Color"
        channels = int(image.channels)
        pixels = np.empty(len(image.pixels), dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape(-1, channels)
        color = pixels[:, :3] if channels >= 3 else np.repeat(pixels[:, :1], 3, axis=1)
        if srgb:
            color = srgb_to_linear(color)
        color = apply_image_adjustments(color, adjustments)
        color = linear_to_srgb(color) if srgb else np.clip(color, 0.0, 1.0)
        if channels >= 3:
            pixels[:, :3] = color
        else:
            pixels[:, 0] = color @ np.asarray(LUMINANCE_WEIGHTS)
        image.pixels.foreach_set(pixels.ravel())
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
    finally:
        bpy.data.images.remove(image)


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
    base = f"{base}{adjustments_suffix(texture.adjustments)}"
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
    used_as: Optional[str] = None,
) -> Optional[ExportedTexture]:
    """Stage a texture for output.  Returns None if the texture format is not
    supported by the engine pipeline (e.g. EXR, HDR) or the texture could not be
    written — callers should treat None as "no texture" for that material slot.

    preserve_precision: keep 16-bit depth for a genuinely-16-bit source instead of
    the usual 8-bit downconvert (see write_blender_image_to_path). Set by the
    height/displacement and normal slots — texbake.py's height and normal paths are
    the consumers built to preserve and use that extra precision.

    used_as: where the texture is used (see texture_usage), so a skipped texture is
    reported together with the material and object that lose it.
    """
    source_path = texture.source_path
    texture_dir = (context.assets_dir or output_path.parent) / "Textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    staging_key = texture_staging_key(texture)

    def skip(reason: str) -> None:
        message = f"{reason} It was the {used_as}." if used_as else reason
        print(f"  Warning: {message}", flush=True)
        context.skipped_textures.append(message)

    # The engine loads no EXR/HDR/Cineon/DPX textures. With Blender at hand the image
    # is converted to PNG like any other 16-bit source (see write_blender_image_to_path:
    # data maps such as an EXR normal or metallic map keep their values, colour values
    # above 1 are clipped); without it the file could only be copied as it is, so the
    # texture is skipped with a warning and the export carries on.
    if source_path is not None and bpy is None:
        resolved = source_path.expanduser().resolve()
        if resolved.suffix.lower() in _UNSUPPORTED_TEXTURE_SUFFIXES:
            skip(
                f"texture '{texture.name}' uses unsupported format "
                f"'{resolved.suffix}' (EXR/HDR are not supported by the engine). "
                f"Skipping texture."
            )
            return None

    existing_destination = context.staged_by_key.get(staging_key)
    if existing_destination is not None:
        return replace(
            texture,
            uri=relative_asset_uri(existing_destination, output_path.parent),
            source_path=existing_destination,
        )

    # An image fails to write whether or not colour nodes are then applied to it.
    source_key = texture_staging_key(replace(texture, adjustments=()))
    write_failures = context.write_failures
    known_failure = write_failures.left_out.get(source_key)
    if known_failure is not None:
        skip(known_failure)
        return None

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

    def write_image(image_name: str) -> None:
        problem = write_blender_image_to_path(
            image_name,
            destination_path,
            preserve_precision=preserve_precision,
            failed_write_problem=write_failures.written_from_copy.get(source_key),
        )
        if problem is not None:
            write_failures.written_from_copy[source_key] = problem

    try:
        if source_path is not None and source_path.is_file():
            if source_path != destination_path:
                if texture.source_image_name:
                    write_image(texture.source_image_name)
                elif bpy is not None:
                    tmp_image = bpy.data.images.load(str(source_path))
                    try:
                        write_image(tmp_image.name)
                    finally:
                        bpy.data.images.remove(tmp_image)
                else:
                    shutil.copy2(source_path, destination_path)
        elif texture.source_image_name:
            write_image(texture.source_image_name)
        else:
            missing_path = str(source_path) if source_path is not None else "<none>"
            raise RuntimeError(f"Texture source does not exist and no Blender image fallback is available: {missing_path}")
    except (UnsupportedTextureFormatError, TextureWriteError) as exc:
        # One texture that cannot be exported costs its material a texture slot, not the
        # whole export: a multi-model pack writes its manifest last, so stopping here would
        # throw away every model already written.
        if isinstance(exc, TextureWriteError):
            # Taken to be the image's fault, not the folder's: its other uses in this
            # export are left out without trying again.
            write_failures.left_out[source_key] = str(exc)
        skip(str(exc))
        return None

    if texture.adjustments:
        if bpy is not None:
            adjust_staged_image(destination_path, texture.adjustments, srgb=texture.srgb_source)
        else:
            print(f"  Warning: texture '{texture.name}' feeds colour nodes, which need Blender to apply; staged as is.", flush=True)

    context.staged_by_key[staging_key] = destination_path

    return replace(
        texture,
        uri=relative_asset_uri(destination_path, output_path.parent),
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


def texture_usage(slot: str, material_name: str, object_name: Optional[str] = None) -> str:
    """Describe where a texture is used, for the report of a texture that had to be skipped."""
    usage = f"{slot} texture of material '{material_name}'"
    return f"{usage} on object '{object_name}'" if object_name else usage


def _load_image_pixels(path: Path) -> tuple["np.ndarray", int, int]:
    """A staged image's pixels as stored (no colour transform): rows of RGBA, plus its size."""
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        image.colorspace_settings.name = "Non-Color"
        width, height = int(image.size[0]), int(image.size[1])
        channels = int(image.channels)
        pixels = np.empty(len(image.pixels), dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape(-1, channels)
    finally:
        bpy.data.images.remove(image)
    if channels >= 4:
        rgba = pixels[:, :4].copy()
    elif channels == 3:
        rgba = np.concatenate([pixels, np.ones((len(pixels), 1), dtype=np.float32)], axis=1)
    else:
        rgba = np.concatenate([np.repeat(pixels[:, :1], 3, axis=1), pixels[:, 1:2] if channels == 2 else np.ones((len(pixels), 1), dtype=np.float32)], axis=1)
    return rgba, width, height


def _resample_nearest(values: "np.ndarray", width: int, height: int, new_width: int, new_height: int) -> "np.ndarray":
    if (width, height) == (new_width, new_height):
        return values
    columns = np.minimum((np.arange(new_width) * width) // new_width, width - 1)
    rows = np.minimum((np.arange(new_height) * height) // new_height, height - 1)
    grid = values.reshape(height, width, -1)
    return grid[rows][:, columns].reshape(new_width * new_height, -1)


def compose_alpha_texture(
    base_color_texture: Optional[ExportedTexture],
    alpha_texture: ExportedTexture,
    output_path: Path,
    context: TextureStagingContext,
    *,
    used_as: Optional[str] = None,
) -> Optional[ExportedTexture]:
    """Write the Principled Alpha texture into the alpha channel of the (staged) base
    colour texture, or of a white texture when the base colour is a constant, since
    the engine reads a material's alpha from its base colour texture only.

    The alpha image is staged on its own first (so its colour nodes are applied) in a
    temporary folder, read as a value (its alpha channel when the Alpha output feeds
    the socket, else the luminance of its colour, as Blender converts a colour linked
    to a value) and resampled to the base colour texture's size.
    """
    if bpy is None or not _HAS_NUMPY:
        print(f"  Warning: the {used_as or 'alpha texture'} needs Blender and numpy to be written; the material stays without it.", flush=True)
        return base_color_texture
    base_key = texture_staging_key(base_color_texture) if base_color_texture is not None else "white"
    key = f"alpha:{base_key}|{texture_staging_key(alpha_texture)}|{alpha_texture.channel}"
    existing = context.staged_by_key.get(key)
    if existing is not None:
        return ExportedTexture(
            name=existing.name,
            uri=relative_asset_uri(existing, output_path.parent),
            width=base_color_texture.width if base_color_texture is not None else alpha_texture.width,
            height=base_color_texture.height if base_color_texture is not None else alpha_texture.height,
            mip_count=1,
            source_path=existing,
            srgb_source=True,
        )

    with tempfile.TemporaryDirectory() as scratch:
        scratch_context = TextureStagingContext(
            context.skipped_textures, context.write_failures, assets_dir=Path(scratch)
        )
        staged_alpha = stage_texture_for_output(alpha_texture, Path(scratch) / "alpha.untold", scratch_context, used_as=used_as)
        if staged_alpha is None or staged_alpha.source_path is None:
            return base_color_texture
        alpha_rgba, alpha_width, alpha_height = _load_image_pixels(staged_alpha.source_path)

    if alpha_texture.channel == TEXTURE_CHANNEL_A:
        alpha_values = alpha_rgba[:, 3:4]
    elif alpha_texture.channel in (TEXTURE_CHANNEL_G, TEXTURE_CHANNEL_B):
        alpha_values = alpha_rgba[:, alpha_texture.channel:alpha_texture.channel + 1]
    else:
        # The staged image holds encoded values; Blender converts the linear colour.
        color = srgb_to_linear(alpha_rgba[:, :3]) if alpha_texture.srgb_source else alpha_rgba[:, :3]
        alpha_values = (color @ np.asarray(LUMINANCE_WEIGHTS, dtype=np.float32)).reshape(-1, 1)

    if base_color_texture is not None and base_color_texture.source_path is not None:
        rgba, width, height = _load_image_pixels(base_color_texture.source_path)
        stem = Path(base_color_texture.name).stem or "base_color"
    else:
        width, height = alpha_width, alpha_height
        rgba = np.ones((width * height, 4), dtype=np.float32)
        stem = f"{Path(alpha_texture.name).stem or 'alpha'}_white"
    rgba[:, 3:4] = np.clip(_resample_nearest(alpha_values, alpha_width, alpha_height, width, height), 0.0, 1.0)

    texture_dir = (context.assets_dir or output_path.parent) / "Textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    fingerprint = hashlib.sha1(key.encode("utf-8")).hexdigest()[:8]
    destination_name = unique_texture_destination_name(
        ExportedTexture(name=f"{stem}_alpha_{fingerprint}.png", uri="", width=width, height=height, mip_count=1),
        context,
        ".png",
    )
    destination_path = texture_dir / destination_name
    image = bpy.data.images.new(destination_path.stem, width, height, alpha=True)
    try:
        image.colorspace_settings.name = "Non-Color"
        image.alpha_mode = "STRAIGHT"
        image.pixels.foreach_set(rgba.ravel())
        image.filepath_raw = str(destination_path)
        image.file_format = "PNG"
        image.save()
    finally:
        bpy.data.images.remove(image)
    context.staged_by_key[key] = destination_path
    return ExportedTexture(
        name=destination_name,
        uri=relative_asset_uri(destination_path, output_path.parent),
        width=width,
        height=height,
        mip_count=1,
        source_path=destination_path,
        srgb_source=True,
    )


def stage_material_for_output(
    material: ExportedMaterial,
    output_path: Path,
    context: TextureStagingContext,
    *,
    object_name: Optional[str] = None,
) -> ExportedMaterial:
    def stage(texture: Optional[ExportedTexture], slot: str, preserve_precision: bool = False) -> Optional[ExportedTexture]:
        if texture is None:
            return None
        return stage_texture_for_output(
            texture,
            output_path,
            context,
            preserve_precision=preserve_precision,
            used_as=texture_usage(slot, material.name, object_name),
        )

    base_color_texture = stage(material.base_color_texture, "base color")
    if material.alpha_texture is not None:
        base_color_texture = compose_alpha_texture(
            base_color_texture,
            material.alpha_texture,
            output_path,
            context,
            used_as=texture_usage("alpha", material.name, object_name),
        )
    return replace(
        material,
        alpha_texture=None,
        base_color_texture=base_color_texture,
        normal_texture=stage(material.normal_texture, "normal", preserve_precision=True),
        metallic_texture=stage(material.metallic_texture, "metallic"),
        roughness_texture=stage(material.roughness_texture, "roughness"),
        emissive_texture=stage(material.emissive_texture, "emissive"),
        occlusion_texture=stage(material.occlusion_texture, "occlusion"),
        height_texture=stage(material.height_texture, "height", preserve_precision=True),
    )


def stage_mesh_for_output(
    exported_mesh: ExportedMesh,
    output_path: Path,
    context: TextureStagingContext,
    *,
    object_name: Optional[str] = None,
) -> ExportedMesh:
    return replace(
        exported_mesh,
        material=stage_material_for_output(
            exported_mesh.material,
            output_path,
            context,
            object_name=object_name or exported_mesh.entity_name,
        ),
    )


def stage_nodes_for_output(
    exported_nodes: list[ExportedNode],
    output_path: Path,
    progress_callback: Optional[ProgressCallback] = None,
    skipped_textures: Optional[list[str]] = None,
    write_failures: Optional[TextureWriteFailures] = None,
    assets_dir: Optional[Path] = None,
    context: Optional[TextureStagingContext] = None,
) -> list[ExportedNode]:
    """Stage every node's textures next to output_path, or in assets_dir when given.

    context: staging shared with other files of the same export (the models of a
    pack), so a texture they have in common is staged once; it then also decides where
    Textures/ goes, in place of skipped_textures, write_failures and assets_dir.

    skipped_textures: a list that receives one line per texture that had to be left
    out, so the caller can report them together once the export is done.

    write_failures: what the export already knows about textures Blender cannot write.
    An export that stages several models or tiles hands the same one to each of them.
    """
    if context is None:
        context = TextureStagingContext(skipped_textures, write_failures, assets_dir)
    staged_nodes: list[ExportedNode] = []
    total = len(exported_nodes)
    for i, exported_node in enumerate(exported_nodes, 1):
        if exported_node.mesh is None:
            staged_nodes.append(exported_node)
        else:
            staged_nodes.append(
                replace(
                    exported_node,
                    mesh=stage_mesh_for_output(
                        exported_node.mesh,
                        output_path,
                        context,
                        # A material-split fragment is named "<object>_mat<n>"; report the
                        # object as it is named in Blender.
                        object_name=exported_node.material_split_root_name or exported_node.entity_name,
                    ),
                )
            )
        if progress_callback is not None:
            progress_callback("Stage nodes", i, total, exported_node.entity_name)
    return staged_nodes


def print_skipped_textures(skipped_textures: list[str]) -> None:
    """Repeat the textures that were left out at the end of an export, where they get read."""
    if not skipped_textures:
        return
    print(
        f"Warning: {len(skipped_textures)} texture(s) could not be exported. "
        "The materials that use them were written without them:",
        flush=True,
    )
    for skipped_texture in skipped_textures:
        print(f"  - {skipped_texture}", flush=True)


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
        return _exported_texture_from_image(image, asset_path)
    return None


def _as_color(value) -> tuple[float, float, float]:
    if isinstance(value, tuple):
        return (float(value[0]), float(value[1]), float(value[2])) if len(value) >= 3 else (float(value[0]),) * 3
    return (float(value),) * 3


def _as_scalar(value) -> float:
    """A value as Blender converts it for a float socket: a colour becomes its luminance."""
    if isinstance(value, tuple):
        color = _as_color(value)
        return sum(component * weight for component, weight in zip(color, LUMINANCE_WEIGHTS))
    return float(value)


def _socket_default(socket: object):
    value = getattr(socket, "default_value", None)
    if value is None:
        return None
    return tuple(float(component) for component in value) if hasattr(value, "__len__") else float(value)


def _enabled_inputs(node: object) -> list:
    return [socket for socket in getattr(node, "inputs", []) if getattr(socket, "enabled", True)]


def _mix_colors(blend_type: str, fac: float, a: tuple, b: tuple) -> Optional[tuple]:
    if blend_type == "MIX":
        return tuple(x + (y - x) * fac for x, y in zip(a, b))
    if blend_type == "MULTIPLY":
        return tuple(x * (1.0 - fac + fac * y) for x, y in zip(a, b))
    if blend_type == "ADD":
        return tuple(x + fac * y for x, y in zip(a, b))
    if blend_type == "SUBTRACT":
        return tuple(x - fac * y for x, y in zip(a, b))
    if blend_type == "SCREEN":
        return tuple(1.0 - (1.0 - fac + fac * (1.0 - y)) * (1.0 - x) for x, y in zip(a, b))
    return None


_MATH_OPERATIONS = {
    "ADD": lambda a, b: a + b,
    "SUBTRACT": lambda a, b: a - b,
    "MULTIPLY": lambda a, b: a * b,
    "DIVIDE": lambda a, b: a / b if b != 0.0 else 0.0,
    "POWER": lambda a, b: a ** b if a > 0.0 or float(b).is_integer() else 0.0,
    "MINIMUM": min,
    "MAXIMUM": max,
    "GREATER_THAN": lambda a, b: 1.0 if a > b else 0.0,
    "LESS_THAN": lambda a, b: 1.0 if a < b else 0.0,
    "ABSOLUTE": lambda a, b: abs(a),
}


def evaluate_socket_facing(socket: object, _groups: tuple = (), _depth: int = 0):
    """The value a shader node chain gives an input socket for a surface seen straight
    on: a float or an RGB(A) tuple, or None when the chain holds something that is not
    a constant there (an image or procedural texture, an unknown node).

    View-dependent nodes take their straight-on value (Layer Weight Facing 0, Fresnel
    the normal-incidence reflectance), so a material built on them exports what it
    shows facing the camera; the engine's own Fresnel then brightens its edges. A Mix
    whose factor is 0 or 1 never looks at the side it ignores.
    """
    if socket is None or _depth > 64:
        return None
    if not getattr(socket, "is_linked", False):
        return _socket_default(socket)
    link = socket.links[0]
    return _evaluate_node_output(link.from_node, getattr(getattr(link, "from_socket", None), "name", ""), _groups, _depth + 1)


def _evaluate_node_output(node: object, output_name: str, groups: tuple, depth: int):
    node_id = node.bl_idname
    inputs = _enabled_inputs(node)

    def value_of(socket):
        return evaluate_socket_facing(socket, groups, depth)

    if node_id == "NodeReroute":
        return value_of(node.inputs.get("Input") if hasattr(node.inputs, "get") else inputs[0])
    if node_id in {"ShaderNodeValue", "ShaderNodeRGB"}:
        outputs = list(getattr(node, "outputs", []))
        return _socket_default(outputs[0]) if outputs else None
    if node_id == "ShaderNodeLayerWeight":
        if output_name == "Facing":
            return 0.0
        blend = _unlinked_value(node, "Blend", 0.5)
        if blend is None:
            return None
        eta = 1.0 / max(1.0 - min(max(blend, 0.0), 0.99999), 1.0e-5)
        return ((eta - 1.0) / (eta + 1.0)) ** 2
    if node_id == "ShaderNodeFresnel":
        ior = _unlinked_value(node, "IOR", 1.45)
        return None if ior is None else ((ior - 1.0) / (ior + 1.0)) ** 2
    if node_id in {"ShaderNodeMix", "ShaderNodeMixRGB"}:
        if len(inputs) < 3:
            return None
        fac = value_of(inputs[0])
        if fac is None:
            return None
        fac = _as_scalar(fac)
        if node_id == "ShaderNodeMix" and getattr(node, "data_type", "RGBA") != "RGBA":
            if getattr(node, "data_type", "") != "FLOAT":
                return None
            fac = min(max(fac, 0.0), 1.0) if getattr(node, "clamp_factor", True) else fac
            a = value_of(inputs[1]) if fac < 1.0 else 0.0
            b = value_of(inputs[2]) if fac > 0.0 else 0.0
            if a is None or b is None:
                return None
            return _as_scalar(a) + (_as_scalar(b) - _as_scalar(a)) * fac
        fac = min(max(fac, 0.0), 1.0) if getattr(node, "clamp_factor", True) else fac
        blend_type = getattr(node, "blend_type", "MIX")
        a = value_of(inputs[1]) if not (blend_type == "MIX" and fac >= 1.0) else (0.0, 0.0, 0.0)
        b = value_of(inputs[2]) if fac > 0.0 else (0.0, 0.0, 0.0)
        if a is None or b is None:
            return None
        mixed = _mix_colors(blend_type, fac, _as_color(a), _as_color(b))
        if mixed is None:
            return None
        if getattr(node, "clamp_result", False) or getattr(node, "use_clamp", False):
            mixed = tuple(min(max(component, 0.0), 1.0) for component in mixed)
        return mixed
    if node_id == "ShaderNodeMath":
        operation = _MATH_OPERATIONS.get(getattr(node, "operation", ""))
        if operation is None or not inputs:
            return None
        a = value_of(inputs[0])
        b = value_of(inputs[1]) if len(inputs) > 1 else 0.0
        if a is None or b is None:
            return None
        result = operation(_as_scalar(a), _as_scalar(b))
        return min(max(result, 0.0), 1.0) if getattr(node, "use_clamp", False) else result
    if node_id in _ADJUSTMENT_NODE_INPUTS:
        source = value_of(node.inputs.get(_ADJUSTMENT_NODE_INPUTS[node_id]))
        adjustment = image_adjustment_for_node(node, output_name)
        if source is None or adjustment is NOT_REPRESENTABLE or not _HAS_NUMPY:
            return None
        color = _as_color(source)
        if adjustment is None:
            return color
        adjusted = apply_image_adjustments(np.asarray([color], dtype=np.float64), (adjustment,))[0]
        return tuple(float(component) for component in adjusted)
    if node_id == "ShaderNodeGroup":
        tree = getattr(node, "node_tree", None)
        group_output = _group_output_node(tree) if tree is not None else None
        if group_output is None:
            return None
        inner = group_output.inputs.get(output_name) if hasattr(group_output.inputs, "get") else None
        return evaluate_socket_facing(inner, groups + (node,), depth) if inner is not None else None
    if node_id == "NodeGroupInput" and groups:
        outer = groups[-1].inputs.get(output_name) if hasattr(groups[-1].inputs, "get") else None
        return evaluate_socket_facing(outer, groups[:-1], depth) if outer is not None else None
    return None


def _scalar_socket_factor(input_socket: object, texture: Optional[ExportedTexture], default: float) -> float:
    """Factor exported for a scalar Principled socket (Metallic, Roughness).

    The engine multiplies the channel's texture sample by this factor. Same rule as
    Base Color in extract_material: once a texture drives the socket, Blender ignores
    the socket's default_value entirely, so the factor must be 1.0. Exporting the
    slider value instead halved roughness (Principled default 0.5) and zeroed
    metallic (default 0.0) on every textured material.

    Unlinked sockets export the slider value itself. A linked socket whose source
    could not be traced back to a texture (a Value node, node math — see the
    material fidelity report) keeps the slider value as the best available fallback.
    """
    if input_socket is None:
        return default
    if texture is not None:
        return 1.0
    if getattr(input_socket, "is_linked", False):
        # No texture behind it: the chain's value seen straight on, if it has one.
        value = evaluate_socket_facing(input_socket)
        if value is not None:
            return min(max(_as_scalar(value), 0.0), 1.0)
    return float(input_socket.default_value)


def principled_transmission(node: object) -> tuple[float, bool]:
    """A Principled BSDF's transmission in [0, 1], and whether it could not be followed.

    The socket is "Transmission Weight" from Blender 4.0 and "Transmission" before;
    the old name is looked up only when the new one is absent, so a linked "Transmission
    Weight" is not mistaken for a missing one (which read as no transmission at all).
    A linked socket gets the value its node chain has seen straight on (see
    evaluate_socket_facing). When a texture is in the way the slider value stands in,
    as for the other scalar inputs (see _scalar_socket_factor), and the second value is
    True so material fidelity analysis reports it.
    """
    inputs = getattr(node, "inputs", None)
    socket = None
    if inputs is not None:
        socket = inputs.get("Transmission Weight")
        if socket is None:
            socket = inputs.get("Transmission")
    if socket is None:
        return 0.0, False
    unfollowed = False
    if getattr(socket, "is_linked", False):
        value = evaluate_socket_facing(socket)
        if value is not None:
            return min(max(_as_scalar(value), 0.0), 1.0), False
        unfollowed = True
    value = getattr(socket, "default_value", 0.0)
    try:
        transmission = float(value)
    except (TypeError, ValueError):
        transmission = 0.0
    return min(max(transmission, 0.0), 1.0), unfollowed


def _shader_opacity(node: Optional[object]) -> Optional[float]:
    """How much of the surface a shader covers: 1 for a BSDF, 0 for Transparent BSDF,
    less for a transmissive Principled BSDF (see TRANSMISSION_OPACITY), mixed by a Mix
    Shader's factor. A Mix Shader driven by Geometry > Backfacing takes the front-face
    side. None for anything else (a linked factor, Add Shader, ...)."""
    if node is None:
        return None
    node_id = node.bl_idname
    if node_id == "ShaderNodeBsdfTransparent":
        return 0.0
    if node_id == "ShaderNodeBsdfPrincipled":
        transmission, _ = principled_transmission(node)
        return 1.0 - transmission * (1.0 - TRANSMISSION_OPACITY)
    if node_id in {"ShaderNodeBsdfDiffuse", "ShaderNodeBsdfGlossy", "ShaderNodeEmission"}:
        return 1.0
    if node_id == "ShaderNodeMixShader":
        inputs = list(getattr(node, "inputs", []))
        if len(inputs) < 3:
            return None
        fac_socket = inputs[0]
        if getattr(fac_socket, "is_linked", False):
            source, source_socket = _linked_source(fac_socket)
            if source is None or source.bl_idname != "ShaderNodeNewGeometry" or getattr(source_socket, "name", "") != "Backfacing":
                return None
            fac = 0.0
        else:
            fac = float(getattr(fac_socket, "default_value", 0.5))
        first = _shader_opacity(_linked_source(inputs[1])[0])
        second = _shader_opacity(_linked_source(inputs[2])[0])
        if first is None or second is None:
            return None
        return (1.0 - fac) * first + fac * second
    return None


def surface_opacity(material: object) -> float:
    """The opacity the material's surface shader gives (see _shader_opacity); 1 when
    the shader tree is not one it can read."""
    node_tree = getattr(material, "node_tree", None)
    output = _material_output_node(node_tree) if node_tree is not None else None
    if output is None:
        return 1.0
    opacity = _shader_opacity(_linked_source(output.inputs.get("Surface"))[0])
    return 1.0 if opacity is None else min(max(opacity, 0.0), 1.0)


def _same_image(first: ExportedTexture, second: ExportedTexture) -> bool:
    return replace(first, channel=TEXTURE_CHANNEL_R, adjustments=()) == replace(second, channel=TEXTURE_CHANNEL_R, adjustments=())


def _material_alpha(
    material: object,
    alpha_input: Optional[object],
    alpha: float,
    base_color_texture: Optional[ExportedTexture],
    asset_path: Path,
) -> tuple[float, int, Optional[ExportedTexture]]:
    """The base colour factor's alpha, the alpha mode and the texture to write into the
    base colour texture's alpha channel (None when there is none, or when the Alpha
    input already reads the base colour image's own alpha).

    The engine multiplies the base colour texture's alpha by the factor's alpha, and
    blends only materials flagged MATERIAL_ALPHA_MODE_BLEND: before this every
    material was flagged opaque, so Alpha and glass rendered solid.
    """
    opacity = surface_opacity(material)
    alpha_texture = None
    uses_base_alpha = False
    if alpha_input is not None and getattr(alpha_input, "is_linked", False):
        alpha_texture = resolve_texture_from_socket(alpha_input, asset_path)
        if (
            alpha_texture is not None
            and base_color_texture is not None
            and alpha_texture.channel == TEXTURE_CHANNEL_A
            and not alpha_texture.adjustments
            and _same_image(alpha_texture, base_color_texture)
        ):
            uses_base_alpha = True
            alpha_texture = None
    factor_alpha = alpha * opacity
    blended = alpha_texture is not None or uses_base_alpha or factor_alpha < 1.0 - 1.0e-4
    return factor_alpha, MATERIAL_ALPHA_MODE_BLEND if blended else MATERIAL_ALPHA_MODE_OPAQUE, alpha_texture


def extract_material(mesh_object: object, asset_path: Path) -> ExportedMaterial:
    material = mesh_object_material(mesh_object)
    if material is None:
        return ExportedMaterial(
            name=DEFAULT_MATERIAL_NAME,
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

    emission_node = _emission_surface_node(material) if principled is None else None
    if emission_node is not None:
        # An Emission shader as the whole surface: it reflects nothing and glows with
        # its color times its strength.
        color_input = emission_node.inputs.get("Color")
        strength_input = emission_node.inputs.get("Strength")
        strength = (
            float(strength_input.default_value)
            if strength_input is not None and not strength_input.is_linked
            else 1.0
        )
        emissive_texture = resolve_texture_from_socket(color_input, asset_path) if color_input is not None else None
        if color_input is not None and not color_input.is_linked:
            color = color_input.default_value
            emissive = (float(color[0]) * strength, float(color[1]) * strength, float(color[2]) * strength)
        else:
            emissive = (strength, strength, strength)
        return ExportedMaterial(
            name=material.name,
            base_color_factor=(0.0, 0.0, 0.0, 1.0),
            emissive_factor=emissive,
            normal_scale=1.0,
            metallic_factor=0.0,
            roughness_factor=1.0,
            occlusion_strength=1.0,
            alpha_cutoff=float(getattr(material, "alpha_threshold", 0.5)),
            base_color_texture=None,
            emissive_texture=emissive_texture,
        )

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
        if base_color_input is not None and resolve_texture_from_socket(base_color_input, asset_path) is None:
            # Node math with no texture behind it: its colour seen straight on.
            value = evaluate_socket_facing(base_color_input)
            if value is not None:
                base_color = (*(min(max(component, 0.0), 1.0) for component in _as_color(value)), 1.0)
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
        if resolve_texture_from_socket(emissive_input, asset_path) is None:
            value = evaluate_socket_facing(emissive_input)
            if value is not None:
                emissive = tuple(max(component, 0.0) * emission_strength for component in _as_color(value))
    else:
        emissive_default = emissive_input.default_value
        emissive = (
            float(emissive_default[0]) * emission_strength,
            float(emissive_default[1]) * emission_strength,
            float(emissive_default[2]) * emission_strength,
        )
    # A linked Alpha's slider is stale, like Base Color's above.
    alpha = float(alpha_input.default_value) if alpha_input is not None and not alpha_input.is_linked else 1.0

    base_color_texture = resolve_texture_from_socket(base_color_input, asset_path) if base_color_input is not None else None
    alpha, alpha_mode, alpha_texture = _material_alpha(material, alpha_input, alpha, base_color_texture, asset_path)
    normal_texture = resolve_texture_from_socket(normal_input, asset_path) if normal_input is not None else None
    emissive_texture = resolve_texture_from_socket(emissive_input, asset_path) if emissive_input is not None else None
    metallic_texture = resolve_texture_from_socket(metallic_input, asset_path) if metallic_input is not None else None
    roughness_texture = resolve_texture_from_socket(roughness_input, asset_path) if roughness_input is not None else None
    metallic = _scalar_socket_factor(metallic_input, metallic_texture, default=0.0)
    roughness = _scalar_socket_factor(roughness_input, roughness_texture, default=0.5)
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
        alpha_mode=alpha_mode,
        alpha_texture=alpha_texture,
    )



def extract_shape_key_targets(mesh_object, evaluated_mesh, u_vi, conv_np):
    """Sparse float16 morph deltas per non-basis shape key, mapped from the
    ORIGINAL mesh's vertex domain (the evaluated mesh has shape keys flattened)
    onto the exported deduplicated vertex order via u_vi."""
    if not EXPORT_SHAPE_KEYS or not _HAS_NUMPY:
        return ()
    data = getattr(mesh_object, "data", None)
    shape_keys = getattr(data, "shape_keys", None)
    if shape_keys is None or len(shape_keys.key_blocks) < 2:
        return ()
    n_orig = len(data.vertices)
    if n_orig != len(evaluated_mesh.vertices):
        print(
            f"[untold] Skipping shape keys on {mesh_object.name}: evaluated vertex "
            f"count {len(evaluated_mesh.vertices)} != original {n_orig} (generative modifiers?)"
        )
        return ()

    def block_positions(block):
        cos = np.empty(n_orig * 3, dtype=np.float32)
        block.data.foreach_get("co", cos)
        return cos.reshape(-1, 3)

    armature = armature_for_mesh(mesh_object)
    targets = []
    for block in shape_keys.key_blocks[1:]:
        reference = block.relative_key or shape_keys.key_blocks[0]
        delta = block_positions(block) - block_positions(reference)
        du = delta[u_vi]
        if conv_np is not None:
            du = du @ conv_np[:3, :3].T
        magnitudes = np.abs(du).max(axis=1)
        sparse_indices = np.nonzero(magnitudes > 1e-5)[0]
        if sparse_indices.size == 0:
            continue

        entry_array = np.zeros(sparse_indices.size, dtype=_MORPH_DTYPE)
        entry_array["vi"] = sparse_indices.astype(np.uint32)
        d16 = du[sparse_indices].astype(np.float16).view(np.uint16)
        entry_array["px"] = d16[:, 0]
        entry_array["py"] = d16[:, 1]
        entry_array["pz"] = d16[:, 2]

        driver = None
        def block_prop(name, default=None):
            try:
                return block.get(name, default)
            except TypeError:
                # Some Blender versions don't expose IDProperties on ShapeKey
                # blocks; fall back to a "<key name>_<prop>" property stored on
                # the mesh object instead.
                return mesh_object.get(f"{block.name}_{name}", default)

        joint_name = block_prop("untold_driver_joint")
        if joint_name and armature is not None:
            bone = armature.data.bones.get(joint_name)
            if bone is not None:
                pose = tuple(float(v) for v in (block_prop("untold_driver_pose") or (0.0, 0.0, 0.0, 1.0)))
                driver = ExportedMorphDriver(
                    joint_path=bone_path(bone),
                    pose_rotation=pose if len(pose) == 4 else (0.0, 0.0, 0.0, 1.0),
                    radius=float(block_prop("untold_driver_radius", 0.5)),
                )
            else:
                print(f"[untold] Shape key {block.name}: driver joint {joint_name!r} not found in armature")

        targets.append(ExportedMorphTarget(
            name=block.name,
            flags=0,
            position_scale=1.0,
            entry_count=int(sparse_indices.size),
            entries=entry_array.tobytes(),
            driver=driver,
        ))
    return tuple(targets)


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
        uv_transform = material_uv_transform(mesh_object_material(mesh_object))
        if uv_transform is not None:
            loop_uv0 = loop_uv0 * np.array(uv_transform.scale, dtype=np.float32) + np.array(
                uv_transform.offset, dtype=np.float32
            )
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
    u_vi   = c_vi[first_occ]   # (U,) exported vertex -> original Blender vertex
    morph_targets = extract_shape_key_targets(mesh_object, mesh_data, u_vi, conv_np)

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
        morph_targets=morph_targets,
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
        uv_transform = material_uv_transform(mesh_object_material(mesh_object)) if has_uvs else None

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
                if uv_transform is not None:
                    uv0_pair = uv_transform.apply(uv0_pair)
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


def mesh_share_key(obj: object) -> Optional[tuple]:
    """Identifies mesh objects whose exported mesh is the same: linked duplicates (one
    mesh datablock, Alt+D in Blender) with the same materials and nothing that changes
    the mesh per object. Their geometry is then split and extracted once and reused.

    None for anything that can differ per object: modifiers (a Mirror or Array can
    depend on the object), skinning or shape keys (see _is_rigged_object).
    """
    if getattr(obj, "type", None) != "MESH" or getattr(obj, "data", None) is None:
        return None
    if getattr(obj, "modifiers", None) or _is_rigged_object(obj):
        return None
    materials = tuple(
        slot.material.as_pointer() if getattr(slot, "material", None) is not None else 0
        for slot in getattr(obj, "material_slots", [])
    )
    return (obj.data.as_pointer(), materials)


def _is_rigged_object(obj: object) -> bool:
    """Whether a mesh object carries skinning or morph targets: an Armature modifier,
    or shape keys."""
    if any(getattr(modifier, "type", None) == "ARMATURE" for modifier in getattr(obj, "modifiers", None) or []):
        return True
    return getattr(getattr(obj, "data", None), "shape_keys", None) is not None


def _separate_rigged_object_by_material(obj: object) -> list[object]:
    """Separate a rigged mesh object into one object per material with Blender's own
    separate-by-material, on a duplicate, so vertex groups, armature modifiers and
    shape keys survive the split."""
    import bpy

    duplicate = obj.copy()
    duplicate.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(duplicate)
    before = set(bpy.context.scene.objects)

    with bpy.context.temp_override(
        object=duplicate,
        active_object=duplicate,
        selected_objects=[duplicate],
        selected_editable_objects=[duplicate],
    ):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="MATERIAL")
        bpy.ops.object.mode_set(mode="OBJECT")

    pieces = [o for o in bpy.context.scene.objects if o not in before]
    pieces.append(duplicate)
    for piece in pieces:
        piece[UNTOLD_EXPORT_TEMP_OBJECT_PROP] = True
        # A stand-in being split passes on the object it already stands in for.
        piece[UNTOLD_MATERIAL_SPLIT_SOURCE_PROP] = obj.get(UNTOLD_MATERIAL_SPLIT_SOURCE_PROP) or obj.name
        # Collapse to the one used material slot so downstream extraction
        # (which requires a single material assignment) picks the right one.
        piece_used = {p.material_index for p in piece.data.polygons}
        if piece_used:
            used_index = piece_used.pop()
            material = (
                piece.data.materials[used_index]
                if used_index < len(piece.data.materials)
                else None
            )
            piece.data.materials.clear()
            if material is not None:
                piece.data.materials.append(material)
            for polygon in piece.data.polygons:
                polygon.material_index = 0
    return pieces


def split_blender_objects_by_material(objects: list[object]) -> list[object]:
    """Split any Blender mesh object that assigns multiple materials across its
    faces into separate single-material objects.

    The V1 exporter requires each mesh to carry exactly one material.  This
    mirrors the split step in the tile-streaming pipeline so that direct
    export-untold calls on multi-material USD assets also work.

    The fragments are cut from the object's evaluated mesh, with its modifiers and
    shape keys applied, since the fragments carry no modifiers of their own: cutting
    the base mesh lost Geometry Nodes, Curve, Mirror, Bevel and Solidify results and
    left arrays and curve-deformed parts in the wrong place.

    A rigged object (an Armature modifier, or shape keys) is separated by Blender
    itself instead, on a duplicate, from its base mesh: its rest pose is kept, and so
    are its vertex groups, its armature modifier and its shape keys, which a cut
    fragment does not carry. Cutting one silently un-skinned rigged characters and
    dropped their morph targets.
    """
    import bpy, bmesh as _bmesh  # noqa: F401 — bmesh may not be at module level

    # Every evaluated mesh is taken before the first fragment is linked into the
    # scene, which invalidates the depsgraph.
    evaluated_meshes: dict[int, object] = {}
    depsgraph = None
    # Copies of one mesh (see mesh_share_key) are cut once: the first one's fragment
    # meshes are linked into the others' fragment objects.
    fragments_by_share_key: dict[tuple, list[tuple[int, object]]] = {}
    keys_to_cut: set[tuple] = set()
    for obj in objects:
        if getattr(obj, "type", None) != "MESH" or obj.data is None:
            continue
        if len({p.material_index for p in obj.data.polygons}) <= 1 and not getattr(obj, "modifiers", None):
            continue
        if _is_rigged_object(obj):
            continue
        share_key = mesh_share_key(obj)
        if share_key is not None:
            if share_key in keys_to_cut:
                continue
            keys_to_cut.add(share_key)
        if depsgraph is None:
            depsgraph = bpy.context.evaluated_depsgraph_get()
        evaluated_meshes[obj.as_pointer()] = bpy.data.meshes.new_from_object(
            obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph
        )

    result = []
    split_count = 0
    for obj in objects:
        if getattr(obj, "type", None) != "MESH" or obj.data is None:
            result.append(obj)
            continue
        share_key = mesh_share_key(obj)
        shared_fragments = fragments_by_share_key.get(share_key) if share_key is not None else None
        if shared_fragments is not None:
            for mat_idx, fragment_mesh in shared_fragments:
                result.append(_material_fragment_object(obj, mat_idx, fragment_mesh))
            continue
        evaluated_mesh = evaluated_meshes.pop(obj.as_pointer(), None)
        mesh = evaluated_mesh if evaluated_mesh is not None else obj.data
        used_indices = {p.material_index for p in mesh.polygons}
        if len(used_indices) <= 1:
            if evaluated_mesh is not None:
                bpy.data.meshes.remove(evaluated_mesh)
            result.append(obj)
            continue
        print(f"  Splitting '{obj.name}' into {len(used_indices)} single-material mesh(es)", flush=True)
        split_count += len(used_indices)
        if _is_rigged_object(obj):
            result.extend(_separate_rigged_object_by_material(obj))
            continue
        fragments: list[tuple[int, object]] = []
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
                new_mesh = bpy.data.meshes.new(f"{obj.data.name}_mat{mat_idx}")
                bm.to_mesh(new_mesh)
                new_mesh.update()
                mat = mesh.materials[mat_idx] if mat_idx < len(mesh.materials) else None
                if mat:
                    new_mesh.materials.append(mat)
                    for p in new_mesh.polygons:
                        p.material_index = 0
                fragments.append((mat_idx, new_mesh))
                result.append(_material_fragment_object(obj, mat_idx, new_mesh))
            finally:
                bm.free()
        if share_key is not None:
            fragments_by_share_key[share_key] = fragments
        if evaluated_mesh is not None:
            bpy.data.meshes.remove(evaluated_mesh)
    return result


def _material_fragment_object(obj: object, mat_idx: int, mesh: object) -> object:
    """A temporary object for one material's fragment of obj, placed like obj."""
    import bpy
    new_obj = bpy.data.objects.new(f"{obj.name}_mat{mat_idx}", mesh)
    # Preserve the source object's parent link (if any) so nodes that already sit
    # under a real Blender hierarchy still group correctly;
    # UNTOLD_MATERIAL_SPLIT_SOURCE_PROP below is what reunites fragments of a
    # *parentless* multi-material object, which parent-chain walking alone can't do
    # since these fragments aren't parented to each other.
    new_obj.parent = obj.parent
    if obj.parent is not None:
        new_obj.matrix_parent_inverse = obj.matrix_parent_inverse.copy()
    new_obj.matrix_world = obj.matrix_world.copy()
    new_obj[UNTOLD_EXPORT_TEMP_OBJECT_PROP] = True
    # A stand-in being split (a converted curve) passes on the object it already
    # stands in for.
    new_obj[UNTOLD_MATERIAL_SPLIT_SOURCE_PROP] = obj.get(UNTOLD_MATERIAL_SPLIT_SOURCE_PROP) or obj.name
    bpy.context.scene.collection.objects.link(new_obj)
    return new_obj


def cleanup_temporary_export_objects(objects: Iterable[object]) -> None:
    """Remove temporary Blender objects created for one export pass, including those
    no longer in the export list (a converted curve that was then split)."""
    if bpy is None:
        return
    candidates = list(objects)
    candidate_ids = {id(obj) for obj in candidates}
    for obj in list(getattr(bpy.data, "objects", [])):
        try:
            if obj.get(UNTOLD_EXPORT_TEMP_OBJECT_PROP) and id(obj) not in candidate_ids:
                candidates.append(obj)
        except ReferenceError:
            continue
    for obj in candidates:
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
    include_hidden: bool = False,
) -> list[ExportedNode]:
    blender_required()
    stage_label = "Open .blend" if asset_path.suffix.lower() == ".blend" else "Import USD"
    if progress_callback is not None:
        progress_callback(stage_label, 0, 1, asset_path.name)
    imported_objects = load_source_objects(asset_path)
    if progress_callback is not None:
        progress_callback("Select objects", 0, 1, f"{len(imported_objects)} imported object(s)")
    export_objects = prepare_export_objects_from_blender_objects(
        imported_objects,
        mesh_name,
        filter_scene=True,
        include_hidden=include_hidden,
    )
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
    include_hidden: bool = False,
) -> tuple[list[ExportedLight], list[ExportedCamera]]:
    """The scene's lights and cameras, by the same rule as its meshes (see
    filter_scene_objects_for_export): never from collections excluded from the view
    layer, and hidden ones only with include_hidden."""
    blender_required()
    include_scene_payload = mesh_name is None
    return extract_scene_payload_from_objects(
        filter_scene_objects_for_export(list(bpy.context.scene.objects), include_hidden=include_hidden, quiet=True),
        convert_orientation=convert_orientation,
        source_orientation=source_orientation,
        include_scene_payload=include_scene_payload,
    )


def placed_mesh_copy(mesh: ExportedMesh, obj: object, conversion_matrix: Optional[object]) -> ExportedMesh:
    """An extracted mesh for another object that copies its mesh (see mesh_share_key):
    the same vertices, indices and material, with the object's own name, parent and
    transform. Its world bounds are the local bounds' corners through the object's
    world transform (a box around the exact bounds, which only empty nodes' bounds use
    before normalize_export_nodes recomputes them from the vertices)."""
    local_rows = matrix_rows_from_blender(obj.matrix_local)
    world_rows = matrix_rows_from_blender(obj.matrix_world)
    if conversion_matrix is not None:
        local_rows = transform_matrix_rows(local_rows, conversion_matrix)
        world_rows = transform_matrix_rows(world_rows, conversion_matrix)
    corners = [transform_point_rows(world_rows, corner) for corner in aabb_corners(mesh.local_bounds)]
    return replace(
        mesh,
        entity_name=obj.get("mesh_original_name") or obj.name,
        parent_entity_name=getattr(getattr(obj, "parent", None), "name", None),
        local_transform_rows=local_rows,
        world_bounds=aabb_from_points(corners),
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
    # Copies of one mesh (see mesh_share_key) are extracted once; each copy takes the
    # result with its own placement. An extraction that failed fails for every copy.
    extracted_by_share_key: dict[tuple, object] = {}
    reused = 0
    skipped = 0
    for i, obj in enumerate(mesh_objects, 1):
        percent = (100.0 * i) / max(total, 1)
        print(f"  [{i}/{total} | {percent:6.2f}%] {obj.name}", flush=True)
        share_key = mesh_share_key(obj)
        try:
            earlier = extracted_by_share_key.get(share_key) if share_key is not None else None
            if isinstance(earlier, ExportedMesh):
                exported_meshes_by_name[obj.name] = placed_mesh_copy(earlier, obj, conversion_matrix)
                reused += 1
            elif isinstance(earlier, RuntimeError):
                raise earlier
            else:
                exported_meshes_by_name[obj.name] = extract_mesh_object(
                    obj,
                    asset_path,
                    convert_orientation=convert_orientation,
                    source_orientation=source_orientation,
                    _cached_conversion_matrix=conversion_matrix,
                    _depsgraph=depsgraph,
                    _validate=validate,
                )
                if share_key is not None:
                    extracted_by_share_key[share_key] = exported_meshes_by_name[obj.name]
        except RuntimeError as exc:
            if share_key is not None:
                extracted_by_share_key.setdefault(share_key, exc)
            print(f"    Skipped: {exc}", flush=True)
            skipped += 1
        if progress_callback is not None:
            progress_callback("Extract meshes", i, total, obj.name)
    if skipped:
        print(f"  Skipped {skipped} mesh(es) with errors", flush=True)
    if reused:
        print(f"  Reused the geometry of {reused} mesh(es) that copy another one", flush=True)

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
    # A source object replaced by stand-ins (split by material, or a curve converted to
    # a mesh) is not exported itself; its children hang from its first stand-in, which
    # has the same world transform.
    stand_in_by_source_name: dict[str, object] = {}
    for obj in export_objects:
        source_name = obj.get(UNTOLD_MATERIAL_SPLIT_SOURCE_PROP)
        if source_name:
            stand_in_by_source_name.setdefault(source_name, obj)

    def exported_parent(obj: object) -> Optional[object]:
        """The nearest ancestor (or ancestor's stand-in) that is itself exported."""
        parent = getattr(obj, "parent", None)
        while parent is not None:
            if parent.as_pointer() in export_object_ids:
                return parent
            stand_in = stand_in_by_source_name.get(parent.name)
            if stand_in is not None and stand_in.as_pointer() != obj.as_pointer():
                return stand_in
            parent = getattr(parent, "parent", None)
        return None

    nodes: list[ExportedNode] = []
    for obj in export_objects:
        if getattr(obj, "type", None) in {"LIGHT", "CAMERA"}:
            continue

        parent = exported_parent(obj)
        blender_parent = getattr(obj, "parent", None)
        if parent is not None and blender_parent is not None and parent.as_pointer() == blender_parent.as_pointer():
            local_matrix = obj.matrix_local
        elif parent is not None:
            local_matrix = parent.matrix_world.inverted_safe() @ obj.matrix_world
        else:
            # Its Blender parent is not exported, so this node is a root: matrix_local
            # would place it relative to a parent that is no longer there.
            local_matrix = obj.matrix_world if blender_parent is not None else obj.matrix_local
        local_transform_rows = matrix_rows_from_blender(local_matrix)
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

        parent_entity_name = (parent.get("mesh_original_name") or parent.name) if parent is not None else None
        nodes.append(
            ExportedNode(
                entity_name=obj.get("mesh_original_name") or obj.name,
                parent_entity_name=parent_entity_name,
                local_transform_rows=local_transform_rows,
                local_bounds=local_bounds,
                world_bounds=world_bounds,
                skeleton=skeleton,
                mesh=mesh,
                material_split_root_name=obj.get(UNTOLD_MATERIAL_SPLIT_SOURCE_PROP),
            )
        )

    return nodes


def _blender_python_packages_dir() -> Path:
    """Directory `untoldengine bootstrap` installs Blender-context Python packages
    into (see BlenderPythonPackageDependency in BootstrapCommand.swift).

    This script runs inside Blender's own bundled Python interpreter, which has its
    own separate site-packages from the system `python3`. Worse, `untoldengine
    export` launches Blender with `--factory-startup`, which excludes user
    site-packages from `sys.path` entirely — so even `pip install --user` run
    against Blender's own bundled python3 is invisible here. Blender's embedded
    interpreter also ignores the `PYTHONPATH` environment variable, so bootstrap
    can't inject it that way either. `pip install --target` into this fixed
    directory, added to sys.path explicitly below, is the only path that works.
    """
    home_root = os.environ.get("UNTOLDENGINE_HOME")
    base = Path(home_root).expanduser() if home_root else Path.home() / ".untoldengine"
    return base / "tools" / "blender-python-packages"


def _compress_geometry_chunks(vertex_raw: bytes, index_raw: bytes) -> tuple[bytes, bytes]:
    """Compress vertex and index byte arrays with LZ4 raw block format.

    Uses lz4.block (not lz4.frame) to produce raw LZ4 block data compatible
    with Apple's COMPRESSION_LZ4_RAW algorithm on the runtime side.
    Install the dependency with: untoldengine bootstrap
    """
    try:
        import lz4.block as lz4_block  # type: ignore[import]
    except ImportError:
        vendor_dir = _blender_python_packages_dir()
        if vendor_dir.is_dir() and str(vendor_dir) not in sys.path:
            sys.path.insert(0, str(vendor_dir))
        try:
            import lz4.block as lz4_block  # type: ignore[import]
        except ImportError:
            raise RuntimeError(
                "The 'lz4' package is required for geometry compression, and wasn't "
                "found in Blender's bundled Python or in "
                f"{vendor_dir}. Run: untoldengine bootstrap"
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
    color_grade_lut: Optional[ColorGradeLUT] = None,
    muscle_rig: Optional[dict] = None,
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
    morph_entry_writer = BinaryWriter()
    morph_target_records: list[tuple] = []
    morph_driver_records: list[tuple] = []

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
            material.alpha_mode,
        )
        existing = material_indices.get(key)
        if existing is not None:
            return existing

        index = len(materials)
        material_indices[key] = index
        materials.append(
            MaterialRecord(
                name_offset=string_table.add(material.name),
                flags=material.alpha_mode,
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

            for morph in exported_mesh.morph_targets:
                first_entry_index = morph_entry_writer.count // MORPH_ENTRY_SIZE
                morph_entry_writer.write_bytes(morph.entries)
                if morph.driver is not None:
                    morph_driver_records.append((
                        len(morph_target_records),
                        string_table.add(morph.driver.joint_path),
                        morph.driver.kernel,
                        morph.driver.pose_rotation,
                        morph.driver.radius,
                    ))
                morph_target_records.append((
                    len(meshes) - 1,
                    string_table.add(morph.name),
                    morph.flags,
                    first_entry_index,
                    morph.entry_count,
                    morph.position_scale,
                ))

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
        # Set unconditionally for every light type, including SUN/directional:
        # `intensity` above is always a physical quantity (watts for
        # point/spot/area, W/m² irradiance for SUN), never the old arbitrary
        # engine units.
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
    muscle_records: list[MuscleRecord] = []
    if muscle_rig is not None:
        muscle_records = build_muscle_records(muscle_rig, skeletons, string_table)

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

    morph_target_writer = BinaryWriter()
    for mesh_record_index, name_offset, flags, first_entry_index, entry_count, position_scale in morph_target_records:
        write_morph_target_record(
            morph_target_writer, mesh_record_index, name_offset, flags,
            first_entry_index, entry_count, position_scale,
        )
    morph_target_chunk = morph_target_writer.data

    morph_driver_writer = BinaryWriter()
    for target_index, joint_path_offset, kernel, pose_rotation, radius in morph_driver_records:
        write_morph_driver_record(
            morph_driver_writer, target_index, joint_path_offset, kernel, pose_rotation, radius,
        )
    morph_driver_chunk = morph_driver_writer.data
    morph_entry_raw = morph_entry_writer.data

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
    if muscle_records:
        muscle_writer = BinaryWriter()
        for muscle_record in muscle_records:
            write_muscle_record(muscle_writer, muscle_record)
        muscle_chunk = muscle_writer.data
        chunk_payloads.append(
            (CHUNK_TYPES["muscle_table"], muscle_chunk, len(muscle_chunk), len(muscle_records), COMPRESSION_NONE)
        )
    if morph_target_records:
        chunk_payloads.append(
            (CHUNK_TYPES["morph_target_table"], morph_target_chunk, len(morph_target_chunk), len(morph_target_records), COMPRESSION_NONE)
        )
        chunk_payloads.append(
            (CHUNK_TYPES["morph_target_data"], morph_entry_raw, len(morph_entry_raw), len(morph_entry_raw) // MORPH_ENTRY_SIZE, COMPRESSION_NONE)
        )
        if morph_driver_records:
            chunk_payloads.append(
                (CHUNK_TYPES["morph_driver_table"], morph_driver_chunk, len(morph_driver_chunk), len(morph_driver_records), COMPRESSION_NONE)
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
    if output_path.suffix.lower() != ".untoldanim":
        raise RuntimeError(f"Animation export requires a .untoldanim output path, got: {output_path.suffix or '<none>'}")
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
    color_grade_lut_path: Optional[Path] = None,
    clean_sidecars: bool = False,
    progress_callback: Optional[ProgressCallback] = None,
    muscle_rig_path: Optional[Path] = None,
    texture_write_failures: Optional[TextureWriteFailures] = None,
) -> dict[str, object]:
    """Export the objects to a single `.untold` file, whatever number of models they hold.

    texture_write_failures: for a caller that exports several files in one run, such as
    one per tile, to hand the same one to every call (see TextureWriteFailures).
    """
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
    exported_nodes = normalize_export_nodes(exported_nodes)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if clean_sidecars:
        clean_generated_sidecar_dirs(output_path)

    color_grade_lut: Optional[ColorGradeLUT] = None
    if color_grade_lut_path is not None:
        if progress_callback is not None:
            progress_callback("Stage color grade LUT", 0, 1, color_grade_lut_path.name)
        color_grade_lut = stage_color_grade_lut_for_output(color_grade_lut_path, output_path.parent)

    skipped_textures: list[str] = []
    exported_nodes = stage_nodes_for_output(
        exported_nodes,
        output_path,
        progress_callback=progress_callback,
        skipped_textures=skipped_textures,
        write_failures=texture_write_failures,
    )
    muscle_rig = load_muscle_rig(muscle_rig_path) if muscle_rig_path is not None else None
    untold_bytes = build_untold_file(
        exported_nodes,
        output_path,
        file_type_name,
        exported_lights=exported_lights,
        exported_cameras=exported_cameras,
        compress_geometry=compress_geometry,
        color_grade_lut=color_grade_lut,
        muscle_rig=muscle_rig,
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
        "color_grade_lut_staged": color_grade_lut is not None,
        "skipped_textures": skipped_textures,
    }


UNTOLDPACK_FORMAT_VERSION = 1


def group_export_nodes_by_root(nodes: list[ExportedNode]) -> dict[str, list[ExportedNode]]:
    """Bucket nodes by the export-set root they descend from.

    A root is any node with parent_entity_name is None. A .blend scene with
    exactly one root is "one model" (current single-.untold behavior); more
    than one root means the scene contains multiple independent models that
    should become separate .untold files referenced by a .untoldpack
    manifest, rather than being fused into a single file.

    Uses pack_model_group_key() to resolve each root's identity so that
    material-split fragments of one parentless multi-material object collapse
    back into a single model instead of becoming separate ones.
    """
    nodes_by_name = {node.entity_name: node for node in nodes}

    def find_root_name(name: str) -> str:
        node = nodes_by_name[name]
        while node.parent_entity_name is not None:
            node = nodes_by_name[node.parent_entity_name]
        return pack_model_group_key(node)

    groups: dict[str, list[ExportedNode]] = {}
    for node in nodes:
        groups.setdefault(find_root_name(node.entity_name), []).append(node)
    return groups


def sanitize_pack_model_name(name: str) -> str:
    safe = "".join(char if char.isalnum() or char in "_-" else "_" for char in name)
    return safe.strip("_") or "model"


def unique_pack_model_dir_name(root_name: str, used_names: set[str]) -> str:
    """Sanitizes root_name for use as a pack model's subfolder, disambiguating
    collisions from sanitize_pack_model_name() collapsing distinct root names
    (e.g. "Chair.1" and "Chair 1", or two names that both sanitize down to the
    "model" fallback) -- without this, the second model would silently write
    into the first's folder and overwrite its .untold file.
    """
    candidate = sanitize_pack_model_name(root_name)
    if candidate not in used_names:
        used_names.add(candidate)
        return candidate

    fingerprint = hashlib.sha1(root_name.encode("utf-8")).hexdigest()[:8]
    candidate = f"{sanitize_pack_model_name(root_name)}_{fingerprint}"
    if candidate not in used_names:
        used_names.add(candidate)
        return candidate

    counter = 1
    while True:
        candidate = f"{sanitize_pack_model_name(root_name)}_{fingerprint}_{counter}"
        if candidate not in used_names:
            used_names.add(candidate)
            return candidate
        counter += 1


def write_untoldpack_manifest(
    pack_path: Path,
    source_asset_name: str,
    models: list[dict[str, object]],
) -> None:
    pack_data = {
        "formatVersion": UNTOLDPACK_FORMAT_VERSION,
        "sourceAsset": source_asset_name,
        "models": models,
    }
    pack_path.write_text(json.dumps(pack_data, indent=2), encoding="utf-8")


def relative_asset_uri(path: Path, base_dir: Path) -> str:
    """A path as the engine resolves it from a file in base_dir: relative, with
    forward slashes (it may start with ../ when the asset sits outside base_dir)."""
    return Path(os.path.relpath(path, base_dir)).as_posix()


def read_pack_model_dirs(pack_path: Path) -> list[Path]:
    """Best-effort read of an existing .untoldpack manifest's per-model directories.

    Used only for stale-file cleanup bookkeeping when a re-export changes a scene's
    model topology (see the two call sites in main()) -- a missing or unreadable
    manifest just yields nothing to clean up rather than failing the export. Only
    directories strictly inside the manifest's own folder are returned, so a
    malformed manifest can never point the cleanup at the folder itself or outside it.
    """
    if not pack_path.is_file():
        return []
    try:
        pack_data = json.loads(pack_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    pack_dir = pack_path.parent.resolve()
    model_dirs: list[Path] = []
    for model in pack_data.get("models", []):
        path = model.get("path")
        if not path:
            continue
        model_dir = (pack_dir / path).parent.resolve()
        if model_dir != pack_dir and pack_dir in model_dir.parents:
            model_dirs.append(model_dir)
    return model_dirs


def remove_pack_model_dirs(model_dirs: Iterable[Path]) -> None:
    """Delete the given per-model folders, if present."""
    for model_dir in model_dirs:
        if model_dir.is_dir():
            shutil.rmtree(model_dir)


def remove_results_left_in_assets_dir(output_path: Path, assets_dir: Optional[Path], keep_dirs: Iterable[Path] = ()) -> list[Path]:
    """Remove the results an earlier export wrote inside assets_dir itself.

    Before --assets-dir existed, a source kept in its own folder was exported into
    that folder: <assets_dir>/<stem>.untold or <stem>.untoldpack. Once the result
    lives at output_path instead, those leftovers would show up as a second copy
    of the model, so they go (with the old manifest's model folders that the new
    export did not reuse). Nothing happens when assets_dir is the output's folder.
    """
    if assets_dir is None or assets_dir.resolve() == output_path.parent.resolve():
        return []
    keep = {path.resolve() for path in keep_dirs}
    removed: list[Path] = []
    old_pack = assets_dir / f"{output_path.stem}.untoldpack"
    if old_pack.is_file():
        remove_pack_model_dirs(path for path in read_pack_model_dirs(old_pack) if path not in keep)
        old_pack.unlink()
        removed.append(old_pack)
    old_single = assets_dir / f"{output_path.stem}.untold"
    if old_single.is_file():
        old_single.unlink()
        removed.append(old_single)
    return removed


def write_single_untold_from_nodes(
    exported_nodes: list[ExportedNode],
    *,
    exported_lights: list[ExportedLight],
    exported_cameras: list[ExportedCamera],
    output_path: Path,
    file_type_name: str,
    compress_geometry: bool,
    color_grade_lut_path: Optional[Path],
    validate: bool,
    progress_callback: Optional[ProgressCallback],
    assets_dir: Optional[Path] = None,
    muscle_rig_path: Optional[Path] = None,
) -> dict[str, object]:
    """Builds and writes a single `.untold` file from already-extracted nodes.

    Its textures (and color grade LUT) are staged in assets_dir/Textures when an
    assets_dir is given (see --assets-dir), else beside output_path.

    Shares its stale-artifact cleanup with write_untold_pack_from_groups() (see
    export_objects_to_untold_or_pack) so both the CLI's `export` command and the
    Blender add-on's "Export Untold Asset" operator behave identically when a
    scene's model topology changes between runs at the same --output stem.
    """
    exported_nodes = normalize_export_nodes(exported_nodes)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    color_grade_lut: Optional[ColorGradeLUT] = None
    if color_grade_lut_path is not None:
        if progress_callback is not None:
            progress_callback("Stage color grade LUT", 0, 1, color_grade_lut_path.name)
        color_grade_lut = stage_color_grade_lut_for_output(
            color_grade_lut_path, assets_dir or output_path.parent, uri_base=output_path.parent
        )

    skipped_textures: list[str] = []
    exported_nodes = stage_nodes_for_output(
        exported_nodes,
        output_path,
        progress_callback=progress_callback,
        skipped_textures=skipped_textures,
        assets_dir=assets_dir,
    )
    muscle_rig = load_muscle_rig(muscle_rig_path) if muscle_rig_path is not None else None
    untold_bytes = build_untold_file(
        exported_nodes,
        output_path,
        file_type_name,
        exported_lights=exported_lights,
        exported_cameras=exported_cameras,
        compress_geometry=compress_geometry,
        color_grade_lut=color_grade_lut,
        muscle_rig=muscle_rig,
        progress_callback=progress_callback,
    )
    if progress_callback is not None:
        progress_callback("Write file", 0, 1, output_path.name)
    output_path.write_bytes(untold_bytes)

    exported_meshes = [node.mesh for node in exported_nodes if node.mesh is not None]

    validation_path: Optional[Path] = None
    if validate:
        validation_path = write_validation_file(
            output_path,
            output_path.stem,
            [mesh.validation_mesh for mesh in exported_meshes],
        )

    # A previous export at this same --output stem may have been a multi-model
    # .untoldpack; it no longer is, so the old manifest and its per-model .untold
    # subfolders are now stale. Removed only now that the new single .untold has
    # written successfully, so a caller still loading `withExtension:
    # "untoldpack"` can't silently pick up an outdated model set.
    removed_stale_pack_path: Optional[Path] = None
    pack_path = output_path.with_suffix(".untoldpack")
    if pack_path.is_file():
        remove_pack_model_dirs(read_pack_model_dirs(pack_path))
        pack_path.unlink()
        removed_stale_pack_path = pack_path
    removed_earlier_results = remove_results_left_in_assets_dir(output_path, assets_dir)

    return {
        "is_pack": False,
        "output_path": output_path,
        "validation_path": validation_path,
        "bytes_written": len(untold_bytes),
        "node_count": len(exported_nodes),
        "mesh_count": len(exported_meshes),
        "light_count": len(exported_lights),
        "camera_count": len(exported_cameras),
        "vertex_count": sum(mesh.vertex_count for mesh in exported_meshes),
        "index_count": sum(mesh.index_count for mesh in exported_meshes),
        "color_grade_lut_staged": color_grade_lut is not None,
        "color_grade_lut_uri": color_grade_lut.uri if color_grade_lut is not None else None,
        "removed_stale_pack_path": removed_stale_pack_path,
        "skipped_textures": skipped_textures,
        "removed_earlier_results": removed_earlier_results,
    }


def model_content_signature(nodes: list[ExportedNode], digests: dict[int, tuple[bytes, str]]) -> Optional[str]:
    """A fingerprint of what a pack model's .untold would hold, independent of where the
    model stands (its root transform goes in the manifest) and of its objects' names:
    geometry, materials (a mesh with none has the same one as any other, see
    DEFAULT_MATERIAL_NAME) and hierarchy.
    Two models with the same fingerprint are the same model placed twice, and are
    written once. None for a model that is not compared: skinned or with morph targets.

    digests caches the hash of each geometry buffer by object identity, since copies
    of a mesh share their buffers (see placed_mesh_copy).
    """
    def digest(data: bytes) -> str:
        # Keyed by identity, holding the buffer so its identity cannot be reused.
        cached = digests.get(id(data))
        if cached is None or cached[0] is not data:
            cached = (data, hashlib.sha1(data).hexdigest())
            digests[id(data)] = cached
        return cached[1]

    position = {node.entity_name: index for index, node in enumerate(nodes)}
    parts = []
    for node in nodes:
        if node.skeleton is not None:
            return None
        mesh = node.mesh
        if mesh is not None and (mesh.skin_binding is not None or mesh.morph_targets):
            return None
        is_root = node.parent_entity_name is None or node.parent_entity_name not in position
        rows = identity_matrix_rows() if is_root else node.local_transform_rows
        mesh_part = None
        if mesh is not None:
            mesh_part = (digest(mesh.vertices), digest(mesh.indices), mesh.index_type, repr(mesh.material))
        parts.append((
            None if is_root else position[node.parent_entity_name],
            tuple(tuple(round(float(value), 6) for value in row) for row in rows),
            mesh_part,
        ))
    return hashlib.sha1(repr(parts).encode("utf-8")).hexdigest()


def write_untold_pack_from_groups(
    model_groups: dict[str, list[ExportedNode]],
    *,
    source_asset_name: str,
    output_path: Path,
    file_type_name: str,
    compress_geometry: bool,
    validate: bool,
    progress_callback: Optional[ProgressCallback],
    assets_dir: Optional[Path] = None,
) -> dict[str, object]:
    """Builds and writes one self-contained `.untold` per model plus a
    `.untoldpack` manifest referencing them, instead of fusing unrelated models
    into one file. See write_single_untold_from_nodes() for the single-model
    counterpart and its matching stale-artifact cleanup.

    The per-model folders go in assets_dir when one is given (see --assets-dir),
    else beside the manifest; the manifest's model paths are relative to its own
    folder either way.

    A model that is a copy of one already written (see model_content_signature) is not
    written again: its manifest entry points at the first one's .untold with its own
    transform. Textures go in one Textures/ folder beside the model folders, shared by
    every model, instead of a copy in each.
    """
    pack_path = output_path.with_suffix(".untoldpack")
    models_root = assets_dir or output_path.parent
    # Captured before write_untoldpack_manifest() overwrites pack_path below, so
    # any model directories from a previous pack export that the new manifest no
    # longer references can be pruned as orphans once the new pack has written
    # successfully (see the orphan cleanup below).
    old_model_dirs = read_pack_model_dirs(pack_path)
    new_model_dirs: list[Path] = []

    manifest_models: list[dict[str, object]] = []
    model_paths: list[Path] = []
    total_meshes = 0
    total_vertices = 0
    total_indices = 0
    total_bytes = 0
    skipped_textures: list[str] = []
    write_failures = TextureWriteFailures()
    # One staging for the whole pack: Textures/ beside the model folders, each texture
    # written once and referenced from every model that uses it (../Textures/...).
    texture_context = TextureStagingContext(skipped_textures, write_failures, assets_dir=models_root)
    used_model_dir_names: set[str] = set()
    written_by_signature: dict[str, Path] = {}
    geometry_digests: dict[int, tuple[bytes, str]] = {}
    shared_model_count = 0
    for root_name, raw_group_nodes in model_groups.items():
        # The root's own placement is captured here, from the un-baked node, and
        # carried in the manifest instead of being baked into the geometry
        # (zero_root_transform below) -- otherwise applying this same transform
        # again as the model's entity transform on load would double it up.
        original_root_transform = next(
            node.local_transform_rows for node in raw_group_nodes if node.parent_entity_name is None
        )
        signature = model_content_signature(raw_group_nodes, geometry_digests)
        written = written_by_signature.get(signature) if signature is not None else None
        if written is not None:
            manifest_models.append(
                {
                    "displayName": root_name,
                    "path": relative_asset_uri(written, pack_path.parent),
                    "transform": original_root_transform,
                }
            )
            shared_model_count += 1
            if progress_callback is not None:
                progress_callback("Share models", 0, 1, f"{root_name} -> {written.name}")
            continue

        group_nodes = normalize_export_nodes(zero_root_transform(raw_group_nodes))

        model_dir_name = unique_pack_model_dir_name(root_name, used_model_dir_names)
        model_output_path = models_root / model_dir_name / f"{model_dir_name}.untold"
        model_output_path.parent.mkdir(parents=True, exist_ok=True)
        # A Textures/ folder of the model's own from an earlier export is no longer used.
        own_textures = model_output_path.parent / "Textures"
        if own_textures.is_dir():
            shutil.rmtree(own_textures)

        staged_group_nodes = stage_nodes_for_output(
            group_nodes,
            model_output_path,
            progress_callback=progress_callback,
            context=texture_context,
        )
        model_bytes = build_untold_file(
            staged_group_nodes,
            model_output_path,
            file_type_name,
            compress_geometry=compress_geometry,
            progress_callback=progress_callback,
        )
        model_output_path.write_bytes(model_bytes)
        group_meshes = [node.mesh for node in staged_group_nodes if node.mesh is not None]
        total_meshes += len(group_meshes)
        total_vertices += sum(mesh.vertex_count for mesh in group_meshes)
        total_indices += sum(mesh.index_count for mesh in group_meshes)
        total_bytes += len(model_bytes)
        model_paths.append(model_output_path)

        if validate:
            write_validation_file(
                model_output_path,
                model_output_path.stem,
                [mesh.validation_mesh for mesh in group_meshes],
            )

        manifest_models.append(
            {
                "displayName": root_name,
                "path": relative_asset_uri(model_output_path, pack_path.parent),
                "transform": original_root_transform,
            }
        )
        new_model_dirs.append(model_output_path.parent.resolve())
        if signature is not None:
            written_by_signature[signature] = model_output_path

    write_untoldpack_manifest(pack_path, source_asset_name, manifest_models)

    # A previous export at this same --output stem may have been a single
    # .untold; it no longer is, so the old file is now stale and would shadow
    # the pack for a caller still loading it `withExtension: "untold"`. Only
    # removed after the new pack has written successfully.
    removed_stale_single_path: Optional[Path] = None
    if output_path.is_file():
        output_path.unlink()
        removed_stale_single_path = output_path

    # A previous pack export at this stem may have included models that no
    # longer exist in the source scene (renamed/deleted objects) -- their
    # subfolders are now orphaned since the new manifest doesn't reference them.
    orphaned_dirs = [path for path in old_model_dirs if path not in new_model_dirs]
    if orphaned_dirs:
        remove_pack_model_dirs(orphaned_dirs)
    orphaned_dir_names = [path.name for path in orphaned_dirs]
    removed_earlier_results = remove_results_left_in_assets_dir(output_path, assets_dir, keep_dirs=new_model_dirs)

    return {
        "is_pack": True,
        "pack_path": pack_path,
        "models": manifest_models,
        "model_paths": model_paths,
        "model_count": len(manifest_models),
        "written_model_count": len(model_paths),
        "shared_model_count": shared_model_count,
        "mesh_count": total_meshes,
        "vertex_count": total_vertices,
        "index_count": total_indices,
        "bytes_written": total_bytes,
        "removed_stale_single_path": removed_stale_single_path,
        "removed_orphan_dir_names": orphaned_dir_names,
        "skipped_textures": skipped_textures,
        "removed_earlier_results": removed_earlier_results,
    }


def export_objects_to_untold_or_pack(
    export_objects: list[object],
    *,
    source_asset_path: Path,
    output_path: Path,
    file_type_name: str = "tile",
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    validate: bool = False,
    compress_geometry: bool = False,
    color_grade_lut_path: Optional[Path] = None,
    clean_sidecars: bool = False,
    progress_callback: Optional[ProgressCallback] = None,
    assets_dir: Optional[Path] = None,
    muscle_rig_path: Optional[Path] = None,
) -> dict[str, object]:
    """Like export_objects_to_untold(), but writes a `.untoldpack` manifest plus
    one self-contained `.untold` per model instead of fusing everything into a
    single file when `export_objects` spans more than one independent root
    model (see group_export_nodes_by_root).

    This is the single source of truth for the single-vs-pack decision, shared
    by the untoldengine CLI's `export` command (main(), below) and the Blender
    add-on's "Export Untold Asset" operator (untold_exporter/bridge.py) so the
    two can't drift out of sync the way they did before this function existed
    -- the add-on called export_objects_to_untold() directly and so never
    produced a pack no matter how many independent models a scene had.

    Callers that must always fuse everything into one file regardless of root
    count -- e.g. scripts/tilestreamingpartition.py, where a tile is expected
    to intentionally bundle many independent props into one payload -- should
    keep calling export_objects_to_untold() directly instead of this function.
    """
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

    if clean_sidecars:
        clean_generated_sidecar_dirs(output_path, assets_dir)

    model_groups = group_export_nodes_by_root(exported_nodes)
    if len(model_groups) <= 1:
        result = write_single_untold_from_nodes(
            exported_nodes,
            exported_lights=exported_lights,
            exported_cameras=exported_cameras,
            output_path=output_path,
            file_type_name=file_type_name,
            compress_geometry=compress_geometry,
            color_grade_lut_path=color_grade_lut_path,
            validate=validate,
            progress_callback=progress_callback,
            assets_dir=assets_dir,
            muscle_rig_path=muscle_rig_path,
        )
        return result

    result = write_untold_pack_from_groups(
        model_groups,
        source_asset_name=source_asset_path.name,
        output_path=output_path,
        file_type_name=file_type_name,
        compress_geometry=compress_geometry,
        validate=validate,
        progress_callback=progress_callback,
        assets_dir=assets_dir,
    )
    result["node_count"] = len(exported_nodes)
    result["light_count"] = len(exported_lights)
    result["camera_count"] = len(exported_cameras)
    result["dropped_scene_payload"] = bool(
        exported_lights or exported_cameras or color_grade_lut_path is not None or muscle_rig_path is not None
    )
    return result


def parse_args(argv: list[str]) -> argparse.Namespace:
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser(description="Cook USD scene or animation data into UntoldEngine's .untold format.")
    parser.add_argument("--input", required=True, help="Path to a source USD/USDZ asset or a .blend file.")
    parser.add_argument("--output", required=True, help="Path to the output .untold file (or .untoldanim with --animation).")
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
    parser.add_argument(
        "--include-hidden",
        action="store_true",
        help="Also export objects hidden in the viewport or disabled in renders (the eye, monitor and camera "
             "icons in Blender's Outliner). Objects in collections excluded from the view layer are never exported.",
    )
    parser.add_argument(
        "--assets-dir",
        default=None,
        help="Folder for what the export writes besides the result. Defaults to the --output folder. The "
             "result at --output refers to the textures, the color grade LUT and the per-model folders of "
             "a .untoldpack in it by relative paths, so both folders must move together. The HDR "
             "environments are staged there too, as copies to put in the project's HDR folder: nothing "
             "refers to them.",
    )
    parser.add_argument("--validate", action="store_true", help="Write a companion .validation.json file for engine-side validation tests.")
    parser.add_argument("--export-shapekeys", action="store_true", help="Export Blender shape keys as morph target chunks (with optional untold_driver_* custom-property pose drivers).")
    parser.add_argument(
        "--muscles",
        default=None,
        help="Path to a JSON muscle rig (see load_muscle_rig) to emit as the muscle table chunk; the engine builds and simulates volumetric XPBD muscles from it at load.",
    )
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
        "--color-grade-lut",
        default=None,
        help="Path to an externally-authored standard .cube 3D LUT to stage alongside the export "
             "and apply as a post-tonemap creative grade. Nothing is rendered or derived from "
             "Blender -- the .cube is copied as-is and loaded directly by the engine, so any LUT "
             "from any grading tool works.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    global EXPORT_SHAPE_KEYS
    args = parse_args(argv)
    EXPORT_SHAPE_KEYS = bool(getattr(args, "export_shapekeys", False))
    input_path = normalize_blender_path(args.input)
    output_path = normalize_blender_path(args.output)
    assets_dir = normalize_blender_path(args.assets_dir) if args.assets_dir else None

    if input_path.suffix.lower() not in {".usd", ".usda", ".usdc", ".usdz", ".blend"}:
        raise RuntimeError(f"Unsupported source asset type: {input_path.suffix}")
    if not input_path.is_file():
        raise RuntimeError(f"Input asset does not exist: {input_path}")

    print(f"{'Opening' if input_path.suffix.lower() == '.blend' else 'Importing'} {input_path.name} ...", flush=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if args.animation:
        if output_path.suffix.lower() != ".untoldanim":
            raise RuntimeError(f"--animation requires a .untoldanim --output path, got: {output_path.suffix or '<none>'}")
        progress = ProgressReporter("animation export", 4)
        progress.stage("Open .blend" if input_path.suffix.lower() == ".blend" else "Import USD", input_path.name)
        exported_clips = extract_animation_clips(
            input_path,
            convert_orientation=args.convert_orientation,
            source_orientation=args.source_orientation,
        )
        progress.advance("Extract animation", f"{len(exported_clips)} clip(s)")
        print(f"Building animation .untoldanim file with {len(exported_clips)} clip(s) ...", flush=True)
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
            include_hidden=args.include_hidden,
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
            include_hidden=args.include_hidden,
        )
        clean_generated_sidecar_dirs(output_path, assets_dir)

        model_groups = group_export_nodes_by_root(exported_nodes)
        staged_hdr_assets = stage_hdr_assets_for_output(assets_dir or output_path.parent, input_path)
        progress_stage_callback = lambda stage, done, total, detail: progress.stage(
            stage,
            f"{done}/{total} {detail}" if total > 1 else detail,
        )

        if len(model_groups) <= 1:
            print(f"Staging {len(exported_nodes)} node(s) ...", flush=True)
            if args.color_grade_lut:
                print(f"Staging color grade LUT {args.color_grade_lut} ...", flush=True)
            print("Building .untold file ...", flush=True)
            result = write_single_untold_from_nodes(
                exported_nodes,
                exported_lights=exported_lights,
                exported_cameras=exported_cameras,
                output_path=output_path,
                file_type_name=args.file_type,
                compress_geometry=args.compress_geometry,
                color_grade_lut_path=Path(args.color_grade_lut) if args.color_grade_lut else None,
                validate=args.validate,
                progress_callback=progress_stage_callback,
                assets_dir=assets_dir,
                muscle_rig_path=normalize_blender_path(args.muscles) if args.muscles else None,
            )
            progress.advance("Stage nodes", output_path.name)
            progress.advance("Build file", output_path.name)
            progress.advance("Write file", output_path.name)
            print(f"Wrote {result['output_path']} ({result['bytes_written']} bytes)")
            print(f"Nodes: {result['node_count']}, Meshes: {result['mesh_count']}")
            print(f"Lights: {result['light_count']}, Cameras: {result['camera_count']}")
            if staged_hdr_assets:
                print(f"HDR environments: {len(staged_hdr_assets)}")
            if result["color_grade_lut_uri"] is not None:
                print(f"Color grade LUT: {result['color_grade_lut_uri']}")
            print(f"Vertices: {result['vertex_count']}, indices: {result['index_count']}")
            if result["validation_path"] is not None:
                print(f"Wrote {result['validation_path']}")
            # This scene used to export as a multi-model .untoldpack (a previous run
            # at this same --output stem); it no longer does, so the old manifest and
            # its per-model .untold subfolders are now stale (see
            # write_single_untold_from_nodes), and ExportCommand.swift's post-export
            # pack detection now reflects this run's actual output rather than
            # leftover state from an earlier one.
            if result["removed_stale_pack_path"] is not None:
                print(f"Removed stale pack manifest: {result['removed_stale_pack_path']}", flush=True)
            print_skipped_textures(result["skipped_textures"])
            for removed_path in result["removed_earlier_results"]:
                print(f"Removed an earlier result from the assets folder: {removed_path}", flush=True)
            progress.advance("Complete", output_path.name)
        else:
            # Multiple independent models were found in the source scene: emit one
            # self-contained .untold per model plus a .untoldpack manifest that
            # references them, instead of fusing unrelated models into one file.
            progress.advance("Stage nodes", output_path.with_suffix(".untoldpack").name)
            if exported_lights or exported_cameras:
                print(
                    f"Note: {len(exported_lights)} light(s) and {len(exported_cameras)} camera(s) are scene-level "
                    "and were not written into any individual .untold model; recreate them in the scene built from this pack.",
                    flush=True,
                )
            if args.color_grade_lut:
                print("Note: --color-grade-lut is scene-level and was not applied to individual pack models.", flush=True)

            result = write_untold_pack_from_groups(
                model_groups,
                source_asset_name=input_path.name,
                output_path=output_path,
                file_type_name=args.file_type,
                compress_geometry=args.compress_geometry,
                validate=args.validate,
                progress_callback=progress_stage_callback,
                assets_dir=assets_dir,
            )
            progress.advance("Build file", result["pack_path"].name)
            print(f"Wrote {result['pack_path']} ({result['model_count']} model(s))")
            if result["shared_model_count"]:
                print(
                    f"{result['written_model_count']} model file(s) written; {result['shared_model_count']} "
                    "placement(s) reuse a model already written",
                    flush=True,
                )
            print(f"Nodes: {len(exported_nodes)}, Meshes: {result['mesh_count']}")
            if staged_hdr_assets:
                print(f"HDR environments: {len(staged_hdr_assets)}")
            # This scene used to export as a single .untold (a previous run at this
            # same --output stem); it no longer does, so the old file was stale and
            # would have shadowed the pack for a caller still loading it
            # `withExtension: "untold"` (see write_untold_pack_from_groups).
            if result["removed_stale_single_path"] is not None:
                print(f"Removed stale single-file export: {result['removed_stale_single_path']}", flush=True)
            # A previous pack export at this stem may have included models that no
            # longer exist in the source scene (renamed/deleted objects); their
            # subfolders were orphaned since the new manifest doesn't reference them.
            if result["removed_orphan_dir_names"]:
                print(f"Removed {len(result['removed_orphan_dir_names'])} orphaned pack model folder(s): {', '.join(result['removed_orphan_dir_names'])}", flush=True)
            for removed_path in result["removed_earlier_results"]:
                print(f"Removed an earlier result from the assets folder: {removed_path}", flush=True)
            progress.advance("Write file", result["pack_path"].name)
            print_skipped_textures(result["skipped_textures"])
            progress.advance("Complete", result["pack_path"].name)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        raise
