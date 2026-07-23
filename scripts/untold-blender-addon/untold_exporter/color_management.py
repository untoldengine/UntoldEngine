from __future__ import annotations

import bpy
from bpy.props import BoolProperty, StringProperty

from .material_fidelity import _wrapped_lines

# Compositor node types that apply color grading independently of the scene's
# View Transform/Look. A LUT baked from view_settings never captures these —
# surfaced as an explicit warning rather than silently producing a mismatched
# look. Matches untoldexplorer.py's out-of-scope note for M1.
_COMPOSITOR_GRADING_NODE_TYPES = {
    "CompositorNodeColorBalance",
    "CompositorNodeCurveRGB",
    "CompositorNodeHueCorrect",
}


class UntoldColorManagementState(bpy.types.PropertyGroup):
    scanned: BoolProperty(default=False)
    view_transform: StringProperty()
    look: StringProperty()
    exposure: StringProperty()
    gamma: StringProperty()
    compositor_warning: StringProperty()


class UNTOLD_OT_scan_color_management(bpy.types.Operator):
    bl_idname = "untold.scan_color_management"
    bl_label = "Scan Color Management"
    bl_description = (
        "Preview the View Transform/Look/Exposure/Gamma that --bake-color-management "
        "would capture, without actually exporting"
    )
    bl_options = {"REGISTER"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        state = context.scene.untold_color_management
        scene = context.scene
        view_settings = scene.view_settings

        state.view_transform = str(getattr(view_settings, "view_transform", "Standard"))
        state.look = str(getattr(view_settings, "look", "None"))
        state.exposure = f"{getattr(view_settings, 'exposure', 0.0):.2f}"
        state.gamma = f"{getattr(view_settings, 'gamma', 1.0):.2f}"

        node_tree = getattr(scene, "node_tree", None)
        warning = ""
        if getattr(scene, "use_nodes", False) and node_tree is not None:
            offending = sorted({
                node.bl_idname for node in node_tree.nodes
                if node.bl_idname in _COMPOSITOR_GRADING_NODE_TYPES
            })
            if offending:
                warning = (
                    "Compositor grading nodes found (" + ", ".join(offending) + "). "
                    "These are NOT captured by the color-management LUT bake."
                )
        state.compositor_warning = warning
        state.scanned = True

        for area in context.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()

        self.report({"INFO"}, f"View Transform: {state.view_transform} ({state.look})")
        return {"FINISHED"}


class UNTOLD_PT_color_management(bpy.types.Panel):
    bl_label = "Color Management"
    bl_idname = "UNTOLD_PT_color_management"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Untold Materials"

    def draw(self, context: bpy.types.Context) -> None:
        layout = self.layout
        state = context.scene.untold_color_management

        layout.operator(UNTOLD_OT_scan_color_management.bl_idname, icon="VIEWZOOM")

        if not state.scanned:
            layout.label(text="Scan to preview --bake-color-management results", icon="INFO")
            return

        summary = layout.box()
        summary.label(text=f"View Transform: {state.view_transform}", icon="CHECKMARK")
        summary.label(text=f"Look: {state.look}")
        summary.label(text=f"Exposure: {state.exposure}   Gamma: {state.gamma}")

        if state.compositor_warning:
            layout.separator(factor=0.5)
            box = layout.box()
            box.label(text="Not captured by this bake:", icon="ERROR")
            for line in _wrapped_lines(state.compositor_warning):
                box.label(text=line)


classes = (
    UntoldColorManagementState,
    UNTOLD_OT_scan_color_management,
    UNTOLD_PT_color_management,
)


def register() -> None:
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.untold_color_management = bpy.props.PointerProperty(type=UntoldColorManagementState)


def unregister() -> None:
    del bpy.types.Scene.untold_color_management
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
