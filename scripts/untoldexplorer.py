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
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Iterable, Optional

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
FORMAT_VERSION = 1
FILE_ALIGNMENT = 16
INVALID_INDEX = 0xFFFFFFFF
HEADER_SIZE = 204
CHUNK_ENTRY_SIZE = 40
VERTEX_STRIDE = 32

FILE_TYPES = {
    "tile": 1,
    "lod": 2,
    "hlod": 3,
    "shared": 4,
}

CHUNK_TYPES = {
    "string_table": 1,
    "entity_table": 2,
    "mesh_table": 3,
    "material_table": 4,
    "texture_table": 5,
    "vertex_data": 6,
    "index_data": 7,
}

VERTEX_LAYOUT_PBR_STATIC_V1 = 1
INDEX_TYPE_UINT16 = 1
INDEX_TYPE_UINT32 = 2
TEXTURE_FORMAT_UNKNOWN = 0
TEXTURE_FLAG_SRGB = 1 << 0
TEXTURE_FLAG_NORMAL_MAP = 1 << 1
TEXTURE_FLAG_EMISSIVE = 1 << 6
TEXTURE_FLAG_OCCLUSION = 1 << 7


def align(value: int, alignment: int) -> int:
    remainder = value % alignment
    return value if remainder == 0 else value + (alignment - remainder)


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def normalize3(vector: tuple[float, float, float], fallback: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = vector
    length = math.sqrt((x * x) + (y * y) + (z * z))
    if length <= 1.0e-8:
        return fallback
    return (x / length, y / length, z / length)


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
    local_bounds: AABB


@dataclass(frozen=True)
class ExportedTexture:
    name: str
    uri: str
    width: int
    height: int
    mip_count: int
    source_path: Optional[Path] = None
    source_image_name: Optional[str] = None


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
    vertex_count: int
    index_count: int
    index_type: int
    material: ExportedMaterial
    validation_mesh: ValidationMesh


@dataclass(frozen=True)
class ExportedNode:
    entity_name: str
    parent_entity_name: Optional[str]
    local_transform_rows: list[list[float]]
    local_bounds: AABB
    world_bounds: AABB
    mesh: Optional[ExportedMesh] = None


@dataclass
class TextureStagingContext:
    staged_by_key: dict[str, Path]
    used_names: set[str]

    def __init__(self) -> None:
        self.staged_by_key = {}
        self.used_names = set()


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
    file_offset: int,
    size: int,
    element_count: int,
) -> None:
    writer.write_u32(chunk_type)
    writer.write_u32(0)
    writer.write_u64(file_offset)
    writer.write_u64(size)
    writer.write_u64(size)
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
    writer.write_u64(0)
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
    writer.write_u32(0)
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


def build_validation_payload(asset_name: str, validation_meshes: list[ValidationMesh]) -> dict[str, object]:
    return {
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
            }
            for mesh in validation_meshes
        ],
    }


def write_validation_file(output_path: Path, asset_name: str, validation_meshes: list[ValidationMesh]) -> Path:
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


def make_export_orientation_matrix(source_orientation: str) -> object:
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
    return axis_conversion(
        from_forward=from_forward,
        from_up=from_up,
        to_forward="Z",
        to_up="Y",
    ).to_4x4()


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
    return _resolve_texture_from_socket(input_socket, asset_path, visited_nodes=set())


def _resolve_texture_from_socket(input_socket: object, asset_path: Path, visited_nodes: set[int]) -> Optional[ExportedTexture]:
    if not getattr(input_socket, "is_linked", False):
        return None

    source_link = input_socket.links[0]
    source_node = source_link.from_node
    source_node_id = id(source_node)
    if source_node_id in visited_nodes:
        return None
    visited_nodes.add(source_node_id)

    if source_node.bl_idname == "ShaderNodeTexImage" and source_node.image is not None:
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
        )

    passthrough_input_names = {
        "ShaderNodeNormalMap":      ["Color"],
        "ShaderNodeSeparateColor":  ["Color"],
        "ShaderNodeSeparateRGB":    ["Image"],
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
        resolved = _resolve_texture_from_socket(nested_input, asset_path, visited_nodes)
        if resolved is not None:
            return resolved

    return None


def _png_bit_depth(path: Path) -> int:
    """Return the bit depth field from a PNG IHDR chunk (8 or 16), or 0 on failure."""
    try:
        with open(path, "rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return 0
            f.read(4)  # chunk length
            if f.read(4) != b"IHDR":
                return 0
            f.read(8)  # width (4) + height (4)
            return f.read(1)[0]
    except Exception:
        return 0


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

    if view_settings is not None:
        try:
            view_transform_items = view_settings.bl_rna.properties["view_transform"].enum_items.keys()
        except Exception:
            view_transform_items = ()
        if "Raw" in view_transform_items:
            view_settings.view_transform = "Raw"
        elif "Standard" in view_transform_items:
            # Fallback for configurations without a Raw view.
            view_settings.view_transform = "Standard"

        try:
            look_items = view_settings.bl_rna.properties["look"].enum_items.keys()
        except Exception:
            look_items = ()
        if "None" in look_items:
            view_settings.look = "None"
        if hasattr(view_settings, "exposure"):
            view_settings.exposure = 0.0
        if hasattr(view_settings, "gamma"):
            view_settings.gamma = 1.0

    if display_settings is not None:
        try:
            display_items = display_settings.bl_rna.properties["display_device"].enum_items.keys()
        except Exception:
            display_items = ()
        if "None" in display_items:
            display_settings.display_device = "None"
        elif "sRGB" in display_items:
            display_settings.display_device = "sRGB"

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


def write_blender_image_to_path(image_name: str, destination_path: Path) -> None:
    blender_required()
    image = bpy.data.images.get(image_name)
    if image is None:
        raise RuntimeError(f"Blender image '{image_name}' is no longer available for export")

    destination_path.parent.mkdir(parents=True, exist_ok=True)

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
        # Fix: downconvert to 8-bit via save_render so the file on disk is a
        # standard 8-bit sRGB PNG that Metal handles correctly.
        image_depth = getattr(image, "depth", 0)
        if image_depth > 32:
            print(f"  Converting 16-bit image '{image_name}' to 8-bit for Metal compatibility", flush=True)
            scene = bpy.context.scene
            img_settings = scene.render.image_settings
            saved = (img_settings.file_format, img_settings.color_depth, img_settings.color_mode)
            saved_color_management = _set_scene_color_management_raw(scene)
            try:
                img_settings.file_format = image.file_format
                img_settings.color_depth = "8"
                img_settings.color_mode = "RGBA" if getattr(image, "channels", 4) == 4 else "RGB"
                image.save_render(str(destination_path), scene=scene)
            finally:
                _restore_scene_color_management(scene, saved_color_management)
                img_settings.file_format, img_settings.color_depth, img_settings.color_mode = saved
        else:
            image.save()
    finally:
        image.filepath_raw = original_filepath_raw
        image.file_format = original_file_format


def texture_staging_key(texture: ExportedTexture) -> str:
    if texture.source_path is not None:
        return f"path:{texture.source_path.expanduser().resolve()}"
    if texture.source_image_name:
        return f"image:{texture.source_image_name}"
    return f"uri:{texture.uri}"


def unique_texture_destination_name(texture: ExportedTexture, context: TextureStagingContext) -> str:
    source_name = texture.source_path.name if texture.source_path is not None else texture.name
    base = Path(source_name).stem or "texture"
    suffix = Path(source_name).suffix
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


def stage_texture_for_output(texture: ExportedTexture, output_path: Path, context: TextureStagingContext) -> ExportedTexture:
    source_path = texture.source_path
    texture_dir = output_path.parent / "Textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    staging_key = texture_staging_key(texture)

    existing_destination = context.staged_by_key.get(staging_key)
    if existing_destination is not None:
        return replace(
            texture,
            uri=existing_destination.relative_to(output_path.parent).as_posix(),
            source_path=existing_destination,
        )

    if source_path is not None:
        source_path = source_path.expanduser().resolve()

    destination_name = unique_texture_destination_name(texture, context)
    destination_path = texture_dir / destination_name

    if source_path is not None and source_path.is_file():
        if source_path != destination_path:
            # 16-bit PNGs must be converted to 8-bit: Metal has no sRGB 16-bit
            # format so they would load without gamma correction and appear too bright.
            if _png_bit_depth(source_path) == 16 and texture.source_image_name:
                write_blender_image_to_path(texture.source_image_name, destination_path)
            else:
                shutil.copy2(source_path, destination_path)
    elif texture.source_image_name:
        write_blender_image_to_path(texture.source_image_name, destination_path)
    else:
        missing_path = str(source_path) if source_path is not None else "<none>"
        raise RuntimeError(f"Texture source does not exist and no Blender image fallback is available: {missing_path}")

    context.staged_by_key[staging_key] = destination_path

    return replace(
        texture,
        uri=destination_path.relative_to(output_path.parent).as_posix(),
        source_path=destination_path,
    )


def stage_material_for_output(material: ExportedMaterial, output_path: Path, context: TextureStagingContext) -> ExportedMaterial:
    return replace(
        material,
        base_color_texture=stage_texture_for_output(material.base_color_texture, output_path, context) if material.base_color_texture is not None else None,
        normal_texture=stage_texture_for_output(material.normal_texture, output_path, context) if material.normal_texture is not None else None,
        metallic_texture=stage_texture_for_output(material.metallic_texture, output_path, context) if material.metallic_texture is not None else None,
        roughness_texture=stage_texture_for_output(material.roughness_texture, output_path, context) if material.roughness_texture is not None else None,
        emissive_texture=stage_texture_for_output(material.emissive_texture, output_path, context) if material.emissive_texture is not None else None,
        occlusion_texture=stage_texture_for_output(material.occlusion_texture, output_path, context) if material.occlusion_texture is not None else None,
    )


def stage_mesh_for_output(exported_mesh: ExportedMesh, output_path: Path, context: TextureStagingContext) -> ExportedMesh:
    return replace(
        exported_mesh,
        material=stage_material_for_output(exported_mesh.material, output_path, context),
    )


def stage_nodes_for_output(exported_nodes: list[ExportedNode], output_path: Path) -> list[ExportedNode]:
    context = TextureStagingContext()
    staged_nodes: list[ExportedNode] = []
    for exported_node in exported_nodes:
        if exported_node.mesh is None:
            staged_nodes.append(exported_node)
        else:
            staged_nodes.append(
                replace(
                    exported_node,
                    mesh=stage_mesh_for_output(exported_node.mesh, output_path, context),
                )
            )
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
    emissive_default = emissive_input.default_value if emissive_input is not None else (0.0, 0.0, 0.0, 1.0)
    emissive = (float(emissive_default[0]), float(emissive_default[1]), float(emissive_default[2]))
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

    # ── index buffer ───────────────────────────────────────────────────────

    index_type = INDEX_TYPE_UINT16 if n_unique <= 65535 else INDEX_TYPE_UINT32
    idx_arr = inverse.astype(np.uint16 if index_type == INDEX_TYPE_UINT16 else np.uint32)
    index_bytes = idx_arr.tobytes()

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
        )

    return ExportedMesh(
        entity_name=mesh_object.name,
        parent_entity_name=getattr(getattr(mesh_object, "parent", None), "name", None),
        mesh_name=mesh_object.data.name or mesh_object.name,
        local_transform_rows=local_transform_rows,
        local_bounds=local_bounds,
        world_bounds=world_bounds,
        vertices=vertex_bytes,
        indices=index_bytes,
        vertex_count=n_unique,
        index_count=int(inverse.size),
        index_type=index_type,
        material=extract_material(mesh_object, asset_path),
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
        if convert_orientation:
            conversion_matrix = (
                _cached_conversion_matrix
                if _cached_conversion_matrix is not None
                else make_export_orientation_matrix(source_orientation)
            )
        else:
            conversion_matrix = None

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
        exported_positions: list[tuple[float, float, float]] = [] if _validate else None
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
                key = (
                    round(position[0], 8), round(position[1], 8), round(position[2], 8),
                    round(normal[0], 8),   round(normal[1], 8),   round(normal[2], 8),
                    round(tangent[0], 8),  round(tangent[1], 8),  round(tangent[2], 8),
                    handedness,
                    round(uv0_pair[0], 8), round(uv0_pair[1], 8),
                    round(uv1_pair[0], 8), round(uv1_pair[1], 8),
                    color_to_u8(float(color_value[0])), color_to_u8(float(color_value[1])),
                    color_to_u8(float(color_value[2])), color_to_u8(float(color_value[3])),
                )
                vertex_index = unique_vertices.get(key)
                if vertex_index is None:
                    vertex_index = len(unique_vertices)
                    unique_vertices[key] = vertex_index
                    if _validate:
                        exported_positions.append(position)
                        exported_normals.append(normal)
                        exported_tangents.append(ValidationTangent(xyz=tangent, handedness=handedness))
                        exported_uv0.append(uv0_pair)
                    write_vertex(
                        vertex_writer,
                        position=position, normal=normal, tangent=tangent,
                        handedness=handedness, uv0=uv0_pair, uv1=uv1_pair,
                        color0=vector4(color_value),
                    )
                indices.append(vertex_index)

        if len(unique_vertices) > 65535:
            index_type = INDEX_TYPE_UINT32

        index_writer = BinaryWriter()
        for index in indices:
            if index_type == INDEX_TYPE_UINT16:
                index_writer.write_u16(index)
            else:
                index_writer.write_u32(index)

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
        ) if _validate else None

        return ExportedMesh(
            entity_name=mesh_object.name,
            parent_entity_name=getattr(getattr(mesh_object, "parent", None), "name", None),
            mesh_name=mesh_object.data.name or mesh_object.name,
            local_transform_rows=local_transform_rows,
            local_bounds=aabb_from_points(local_points),
            world_bounds=aabb_from_points(world_points),
            vertices=vertex_writer.data,
            indices=index_writer.data,
            vertex_count=len(unique_vertices),
            index_count=len(indices),
            index_type=index_type,
            material=extract_material(mesh_object, asset_path),
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
                bpy.context.scene.collection.objects.link(new_obj)
                result.append(new_obj)
            finally:
                bm.free()
    return result


def extract_nodes(
    asset_path: Path,
    mesh_name: Optional[str],
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    validate: bool = False,
) -> list[ExportedNode]:
    blender_required()
    clear_scene()
    imported_objects = import_usd_asset(asset_path)
    export_objects = choose_export_objects(imported_objects, mesh_name)
    export_objects = split_blender_objects_by_material(export_objects)
    return extract_nodes_from_objects(
        export_objects,
        asset_path,
        convert_orientation=convert_orientation,
        source_orientation=source_orientation,
        validate=validate,
    )


def extract_nodes_from_objects(
    export_objects: list[object],
    asset_path: Path,
    convert_orientation: bool = False,
    source_orientation: str = "blender-native",
    validate: bool = False,
) -> list[ExportedNode]:
    blender_required()
    if not export_objects:
        raise RuntimeError("No Blender objects were provided for export")
    conversion_matrix = make_export_orientation_matrix(source_orientation) if convert_orientation else None

    import bpy as _bpy
    depsgraph = _bpy.context.evaluated_depsgraph_get()

    mesh_objects = [obj for obj in export_objects if getattr(obj, "type", None) == "MESH"]
    total = len(mesh_objects)
    print(f"  Processing {total} mesh(es) ...", flush=True)
    exported_meshes_by_name: dict[str, ExportedMesh] = {}
    skipped = 0
    for i, obj in enumerate(mesh_objects, 1):
        print(f"  [{i}/{total}] {obj.name}", flush=True)
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
    if skipped:
        print(f"  Skipped {skipped} mesh(es) with errors", flush=True)

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
        local_transform_rows = matrix_rows_from_blender(obj.matrix_local)
        if conversion_matrix is not None:
            local_transform_rows = transform_matrix_rows(local_transform_rows, conversion_matrix)

        mesh = exported_meshes_by_name.get(obj.name)
        if mesh is not None:
            local_bounds = mesh.local_bounds
            world_bounds = mesh.world_bounds
        else:
            world_corners = aggregate_world_corners(obj)
            if world_corners:
                world_bounds = aabb_from_points(world_corners)
                inverse_world = obj.matrix_world.inverted_safe()
                local_points = [vector3(inverse_world @ Vector(point)) for point in world_corners]
                if conversion_matrix is not None:
                    local_points = [transform_point(conversion_matrix, point) for point in local_points]
                local_bounds = aabb_from_points(local_points)
            else:
                local_bounds = AABB((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))
                world_bounds = local_bounds

        parent = getattr(obj, "parent", None)
        parent_entity_name = parent.name if parent is not None and parent.as_pointer() in export_object_ids else None
        nodes.append(
            ExportedNode(
                entity_name=obj.name,
                parent_entity_name=parent_entity_name,
                local_transform_rows=local_transform_rows,
                local_bounds=local_bounds,
                world_bounds=world_bounds,
                mesh=mesh,
            )
        )

    return nodes


def build_untold_file(exported_nodes: list[ExportedNode], output_path: Path, file_type_name: str) -> bytes:
    if not exported_nodes:
        raise RuntimeError("No nodes were extracted for export")

    string_table = StringTableBuilder()
    textures: list[TextureRecord] = []
    texture_indices: dict[str, int] = {}
    materials: list[MaterialRecord] = []
    material_indices: dict[tuple[object, ...], int] = {}
    entities: list[EntityRecord] = []
    meshes: list[MeshRecord] = []
    vertex_writer = BinaryWriter()
    index_writer = BinaryWriter()

    def add_texture(texture: Optional[ExportedTexture], flags: int = 0) -> int:
        if texture is None:
            return INVALID_INDEX
        existing = texture_indices.get(texture.uri)
        if existing is not None:
            existing_record = textures[existing]
            textures[existing] = TextureRecord(
                name_offset=existing_record.name_offset,
                uri_offset=existing_record.uri_offset,
                texture_format=existing_record.texture_format,
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
            )
        )
        return index

    world_bounds = aabb_from_points(
        point
        for exported_node in exported_nodes
        for point in aabb_corners(exported_node.world_bounds)
    )

    entity_ids_by_name = {exported_node.entity_name: entity_id for entity_id, exported_node in enumerate(exported_nodes)}

    for entity_id, exported_node in enumerate(exported_nodes):
        first_mesh_record_index = len(meshes)
        mesh_record_count = 0

        if exported_node.mesh is not None:
            exported_mesh = exported_node.mesh
            material_index = add_material(exported_mesh.material)
            vertex_data_offset = vertex_writer.count
            index_data_offset = index_writer.count
            vertex_writer.write_bytes(exported_mesh.vertices)
            index_writer.write_bytes(exported_mesh.indices)

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
                    ),
                    local_bounds=exported_mesh.local_bounds,
                )
            )
            mesh_record_count = 1

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

    mesh_writer = BinaryWriter()
    for mesh in meshes:
        write_mesh_record(mesh_writer, mesh)
    mesh_chunk = mesh_writer.data

    chunk_payloads = [
        (CHUNK_TYPES["string_table"], string_chunk, 0),
        (CHUNK_TYPES["entity_table"], entity_chunk, len(entities)),
        (CHUNK_TYPES["mesh_table"], mesh_chunk, len(meshes)),
        (CHUNK_TYPES["material_table"], material_chunk, len(materials)),
        (CHUNK_TYPES["texture_table"], texture_chunk, len(textures)),
        (CHUNK_TYPES["vertex_data"], vertex_writer.data, 0),
        (CHUNK_TYPES["index_data"], index_writer.data, 0),
    ]

    content_hash = hashlib.sha256(b"".join(payload for _, payload, _ in chunk_payloads)).digest()
    file_type = FILE_TYPES[file_type_name]
    chunk_table_size = CHUNK_ENTRY_SIZE * len(chunk_payloads)
    running_offset = HEADER_SIZE + chunk_table_size
    chunk_entries: list[tuple[int, int, int, int]] = []
    for chunk_type, payload, element_count in chunk_payloads:
        running_offset = align(running_offset, FILE_ALIGNMENT)
        chunk_entries.append((chunk_type, running_offset, len(payload), element_count))
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
    for chunk_type, file_offset, size, element_count in chunk_entries:
        write_chunk_entry(
            file_writer,
            chunk_type=chunk_type,
            file_offset=file_offset,
            size=size,
            element_count=element_count,
        )
    for (_, payload, _), (_, file_offset, _, _) in zip(chunk_payloads, chunk_entries):
        file_writer.align(FILE_ALIGNMENT)
        if file_writer.count != file_offset:
            raise RuntimeError(
                f"Chunk offset mismatch while building {output_path}: expected {file_offset}, wrote {file_writer.count}"
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
) -> dict[str, object]:
    exported_nodes = extract_nodes_from_objects(
        export_objects,
        source_asset_path,
        convert_orientation=convert_orientation,
        source_orientation=source_orientation,
        validate=validate,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    exported_nodes = stage_nodes_for_output(exported_nodes, output_path)
    untold_bytes = build_untold_file(exported_nodes, output_path, file_type_name)
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
        "vertex_count": sum(exported_mesh.vertex_count for exported_mesh in exported_meshes),
        "index_count": sum(exported_mesh.index_count for exported_mesh in exported_meshes),
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser(description="Cook static USD scene data into UntoldEngine's .untold V1 format.")
    parser.add_argument("--input", required=True, help="Path to a source USD/USDZ asset.")
    parser.add_argument("--output", required=True, help="Path to the output .untold file.")
    parser.add_argument("--file-type", default="tile", choices=sorted(FILE_TYPES.keys()), help="Untold file type to emit.")
    parser.add_argument("--mesh-name", default=None, help="Optional mesh object name when the USD asset imports multiple meshes.")
    parser.add_argument(
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
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    input_path = normalize_blender_path(args.input)
    output_path = normalize_blender_path(args.output)

    if input_path.suffix.lower() not in {".usd", ".usda", ".usdc", ".usdz"}:
        raise RuntimeError(f"Unsupported source asset type: {input_path.suffix}")
    if not input_path.is_file():
        raise RuntimeError(f"Input asset does not exist: {input_path}")

    print(f"Importing {input_path.name} ...", flush=True)
    exported_nodes = extract_nodes(
        input_path,
        args.mesh_name,
        convert_orientation=args.convert_orientation,
        source_orientation=args.source_orientation,
        validate=args.validate,
    )
    print(f"Staging {len(exported_nodes)} node(s) ...", flush=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    exported_nodes = stage_nodes_for_output(exported_nodes, output_path)
    print("Building .untold file ...", flush=True)
    untold_bytes = build_untold_file(exported_nodes, output_path, args.file_type)
    output_path.write_bytes(untold_bytes)
    exported_meshes = [exported_node.mesh for exported_node in exported_nodes if exported_node.mesh is not None]
    print(f"Wrote {output_path} ({len(untold_bytes)} bytes)")
    print(f"Nodes: {len(exported_nodes)}, Meshes: {len(exported_meshes)}")
    print(f"Vertices: {sum(exported_mesh.vertex_count for exported_mesh in exported_meshes)}, indices: {sum(exported_mesh.index_count for exported_mesh in exported_meshes)}")
    if args.validate:
        # This sidecar is only for validation/debugging in engine-side tests.
        validation_path = write_validation_file(output_path, output_path.stem, [exported_mesh.validation_mesh for exported_mesh in exported_meshes])
        print(f"Wrote {validation_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        raise
