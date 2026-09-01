from __future__ import annotations

import bpy
from bpy.props import BoolProperty, CollectionProperty, EnumProperty, IntProperty, StringProperty

from . import bridge


# Matches untoldexplorer.py's MATERIAL_GRAPH_SUPPORTED/BAKEABLE/UNBAKEABLE constants.
_CLASSIFICATION_ICON = {
    "bakeable": "MODIFIER_ON",
    "unbakeable": "ERROR",
}

_PANEL_WRAP_WIDTH = 40  # characters; the 3D-viewport sidebar is narrow.


def _wrapped_lines(text: str, width: int = _PANEL_WRAP_WIDTH) -> list[str]:
    """Simple word-wrap: layout.label() does not wrap text on its own, and
    material fidelity reasons can run long (e.g. multiple offending nodes
    joined together)."""
    words = text.split(" ")
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if len(candidate) > width and current:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines or [text]


class UntoldMaterialFidelityItem(bpy.types.PropertyGroup):
    material_name: StringProperty()
    classification: StringProperty()  # "bakeable" or "unbakeable" (supported materials are never stored)
    reason: StringProperty()


class UntoldMaterialFidelityWarning(bpy.types.PropertyGroup):
    text: StringProperty()


class UntoldMaterialFidelityState(bpy.types.PropertyGroup):
    scope: EnumProperty(
        name="Scope",
        description="Objects to analyze",
        items=[
            ("SCENE", "Visible Scene", "Analyze visible scene meshes"),
            ("SELECTED", "Selected Objects", "Analyze selected meshes only"),
        ],
        default="SCENE",
    )
    scanned: BoolProperty(default=False)
    supported_count: IntProperty()
    bakeable_count: IntProperty()
    unbakeable_count: IntProperty()
    items: CollectionProperty(type=UntoldMaterialFidelityItem)
    uv_warnings: CollectionProperty(type=UntoldMaterialFidelityWarning)


class UNTOLD_OT_scan_material_fidelity(bpy.types.Operator):
    bl_idname = "untold.scan_material_fidelity"
    bl_label = "Scan Materials"
    bl_description = (
        "Classify every material as supported or divergent from how it renders in "
        "Blender, without actually exporting"
    )
    bl_options = {"REGISTER"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        state = context.scene.untold_material_fidelity
        try:
            result = bridge.scan_material_fidelity(context, state.scope)
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}

        state.items.clear()
        state.uv_warnings.clear()
        for entry in result["materials"]:
            item = state.items.add()
            item.material_name = entry["material_name"]
            item.classification = entry["classification"]
            item.reason = entry["reason"]
        for warning in result["uv_warnings"]:
            entry = state.uv_warnings.add()
            entry.text = warning

        state.supported_count = result["supported_count"]
        state.bakeable_count = result["bakeable_count"]
        state.unbakeable_count = result["unbakeable_count"]
        state.scanned = True

        for area in context.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()

        self.report(
            {"INFO"},
            f"Materials: {state.supported_count} supported, {state.bakeable_count} bakeable, "
            f"{state.unbakeable_count} unbakeable",
        )
        return {"FINISHED"}


class UNTOLD_PT_material_fidelity(bpy.types.Panel):
    bl_label = "Material Fidelity"
    bl_idname = "UNTOLD_PT_material_fidelity"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Untold Materials"

    def draw(self, context: bpy.types.Context) -> None:
        layout = self.layout
        state = context.scene.untold_material_fidelity

        layout.prop(state, "scope")
        layout.operator(UNTOLD_OT_scan_material_fidelity.bl_idname, icon="VIEWZOOM")

        if not state.scanned:
            layout.label(text="Scan materials for fidelity issues", icon="INFO")
            return

        summary = layout.box()
        summary.label(text=f"Supported: {state.supported_count}", icon="CHECKMARK")
        summary.label(text=f"Fixable by baking: {state.bakeable_count}", icon="MODIFIER_ON")
        summary.label(text=f"Not fixable by baking: {state.unbakeable_count}", icon="ERROR")

        if not state.items and not state.uv_warnings:
            return

        layout.separator(factor=0.5)
        layout.label(text="Materials needing attention:")
        for item in state.items:
            box = layout.box()
            box.label(text=item.material_name, icon=_CLASSIFICATION_ICON.get(item.classification, "DOT"))
            col = box.column(align=True)
            for line in _wrapped_lines(item.reason):
                col.label(text=line)

        if state.uv_warnings:
            layout.separator(factor=0.5)
            layout.label(text="UV warnings:", icon="UV")
            for warning in state.uv_warnings:
                box = layout.box()
                for line in _wrapped_lines(warning.text):
                    box.label(text=line)

        if state.bakeable_count or state.unbakeable_count:
            layout.separator(factor=0.5)
            layout.label(text="These will render differently than in Blender", icon="INFO")
            layout.label(text="unless baked to flat textures elsewhere or fixed in the graph.")


classes = (
    UntoldMaterialFidelityItem,
    UntoldMaterialFidelityWarning,
    UntoldMaterialFidelityState,
    UNTOLD_OT_scan_material_fidelity,
    UNTOLD_PT_material_fidelity,
)


def register() -> None:
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.untold_material_fidelity = bpy.props.PointerProperty(type=UntoldMaterialFidelityState)


def unregister() -> None:
    del bpy.types.Scene.untold_material_fidelity
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
