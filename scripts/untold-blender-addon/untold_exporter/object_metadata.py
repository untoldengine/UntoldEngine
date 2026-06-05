from __future__ import annotations

import bpy
from bpy.props import EnumProperty


SEMANTIC_ITEMS = (
    ("Auto", "Auto", "Let the exporter infer the mesh semantic tier"),
    ("ExteriorShell", "Exterior Shell", "Outer shell, facade, roof, or always-visible exterior mesh"),
    ("StructuralInterior", "Structural Interior", "Interior floors, walls, ceilings, stairs, and structural meshes"),
    ("RoomContents", "Room Contents", "Furniture, fixtures, and room-scale content meshes"),
    ("FineProps", "Fine Props", "Small close-range detail props"),
)

PRIORITY_ITEMS = (
    ("Auto", "Auto", "Use the semantic tier's default tile priority"),
    ("Low", "Low", "Low-priority mesh when aggregating tile load priority"),
    ("Normal", "Normal", "Normal-priority mesh when aggregating tile load priority"),
    ("High", "High", "High-priority mesh when aggregating tile load priority"),
    ("Critical", "Critical", "Critical-priority mesh when aggregating tile load priority"),
)


def _set_or_clear_custom_prop(obj: bpy.types.Object, key: str, value: str, clear_value: str = "Auto") -> None:
    if value == clear_value:
        if key in obj:
            del obj[key]
    else:
        obj[key] = value


def _semantic_updated(self, _context) -> None:
    obj = self.id_data
    _set_or_clear_custom_prop(obj, "untold_semantic_override", self.semantic_tag)


def _priority_updated(self, _context) -> None:
    obj = self.id_data
    _set_or_clear_custom_prop(obj, "untold_streaming_priority_hint", self.streaming_priority_hint)


class UntoldObjectMetadata(bpy.types.PropertyGroup):
    semantic_tag: EnumProperty(
        name="Object Semantic",
        description="Mesh-level semantic tier used by tiled scene export",
        items=SEMANTIC_ITEMS,
        default="Auto",
        update=_semantic_updated,
    )

    streaming_priority_hint: EnumProperty(
        name="Priority Hint",
        description="Object-level hint aggregated into generated tile priority",
        items=PRIORITY_ITEMS,
        default="Auto",
        update=_priority_updated,
    )


class UNTOLD_PT_object_metadata(bpy.types.Panel):
    bl_label = "Untold"
    bl_idname = "UNTOLD_PT_object_metadata"
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "object"

    @classmethod
    def poll(cls, context: bpy.types.Context) -> bool:
        obj = context.object
        return obj is not None and obj.type == "MESH"

    def draw(self, context: bpy.types.Context) -> None:
        layout = self.layout
        metadata = context.object.untold_metadata
        layout.prop(metadata, "semantic_tag")
        layout.prop(metadata, "streaming_priority_hint")


classes = (
    UntoldObjectMetadata,
    UNTOLD_PT_object_metadata,
)


def register() -> None:
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Object.untold_metadata = bpy.props.PointerProperty(
        type=UntoldObjectMetadata
    )


def unregister() -> None:
    del bpy.types.Object.untold_metadata
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
