from pathlib import Path
import importlib

import bpy
from bpy.props import BoolProperty, EnumProperty, FloatProperty, IntProperty, StringProperty
from bpy_extras.io_utils import ExportHelper

from . import bridge
from . import color_management
from . import material_fidelity
from . import object_metadata
from . import viewport_overlay


def exporter_bridge():
    return importlib.reload(bridge)


def _tier_radius_overrides_from_settings(settings) -> list[str]:
    if not getattr(settings, "use_custom_tier_radii", False):
        return []

    overrides: list[str] = []
    tier_fields = [
        ("ExteriorShell", "exterior_shell"),
        ("StructuralInterior", "structural_interior"),
        ("RoomContents", "room_contents"),
        ("FineProps", "fine_props"),
    ]
    for tier, prefix in tier_fields:
        streaming = float(getattr(settings, f"{prefix}_streaming_radius"))
        unload = float(getattr(settings, f"{prefix}_unload_radius"))
        priority = int(getattr(settings, f"{prefix}_priority"))
        if streaming > 0.0 and unload > streaming:
            overrides.append(f"{tier}={streaming:g},{unload:g},{priority}")
    return overrides


def _lod_level_overrides_from_settings(settings) -> list[str]:
    if not getattr(settings, "use_custom_representation_ranges", False):
        return []
    return [
        f"{float(settings.lod1_switch_distance):g}:{float(settings.lod1_reduction_ratio):g}",
        f"{float(settings.lod2_switch_distance):g}:{float(settings.lod2_reduction_ratio):g}",
    ]


def _hlod_level_overrides_from_settings(settings) -> list[str]:
    if not getattr(settings, "use_custom_representation_ranges", False):
        return []
    return [
        f"_hlod:{float(settings.hlod_switch_distance):g}:{float(settings.hlod_reduction_ratio):g}",
    ]


bl_info = {
    "name": "Untold Engine Exporter",
    "author": "Untold Engine Studios",
    "version": (0, 1, 0),
    "blender": (4, 0, 0),
    "location": "File > Export > Untold (.untold)",
    "description": "Export Blender objects to Untold Engine .untold runtime assets",
    "category": "Import-Export",
}


class UNTOLD_OT_export_asset(bpy.types.Operator, ExportHelper):
    bl_idname = "untold.export_asset"
    bl_label = "Export Untold Asset"
    bl_options = {"REGISTER"}

    filename_ext = ".untold"
    filter_glob: bpy.props.StringProperty(
        default="*.untold",
        options={"HIDDEN"},
    )

    scope: EnumProperty(
        name="Scope",
        description="Objects to export",
        items=[
            ("SCENE", "Visible Scene", "Export visible scene meshes and armatures"),
            ("SELECTED", "Selected Objects", "Export selected meshes and their required parents/armatures"),
        ],
        default="SCENE",
    )

    file_type_name: EnumProperty(
        name="File Type",
        description="Untold asset file type to emit",
        items=[
            ("tile", "Standard", "Standard runtime asset/tile payload"),
            ("shared", "Shared", "Shared streamed payload"),
            ("lod", "LOD", "LOD payload"),
            ("hlod", "HLOD", "HLOD payload"),
        ],
        default="tile",
    )

    convert_orientation: BoolProperty(
        name="Convert Orientation",
        description="Convert from the selected source orientation into Untold Engine space (+Z forward, +Y up)",
        default=True,
    )

    source_orientation: EnumProperty(
        name="Source Orientation",
        description="Coordinate convention of the Blender scene data",
        items=[
            ("blender-native", "Blender Native", "Blender default: -Y forward, +Z up"),
            ("engine-oriented", "Engine Oriented", "Already in Untold Engine space: +Z forward, +Y up"),
        ],
        default="blender-native",
    )

    compress_geometry: BoolProperty(
        name="Compress Geometry",
        description="Compress vertex and index chunks with LZ4 if the lz4 Python package is available",
        default=False,
    )

    bake_textures: BoolProperty(
        name="Compress Textures",
        description="Compress the textures to ASTC compression format to save memory. Converts staged "
                    "textures to engine-native .utex files and patches the .untold references",
        default=False,
    )

    texture_quality: EnumProperty(
        name="Texture Quality",
        description="astcenc quality level for .utex baking",
        items=[
            ("fastest", "Fastest", "Lowest ASTC encode time"),
            ("fast", "Fast", "Fast ASTC encode"),
            ("medium", "Medium", "Balanced ASTC encode"),
            ("thorough", "Thorough", "Higher quality ASTC encode"),
            ("exhaustive", "Exhaustive", "Slowest ASTC encode"),
        ],
        default="thorough",
    )

    bake_color_management: BoolProperty(
        name="Bake Color Management",
        description=(
            "Bake the scene's active View Transform/Look/Exposure/Gamma into a color-grading "
            "RGBA16Float LUT targeting canonical sRGB output so Untold can closely reproduce "
            "Blender's color management, including Filmic/AgX highlight compression"
        ),
        default=False,
    )

    color_lut_size: IntProperty(
        name="Color LUT Size",
        description="Grid size (N) for the NxNxN color-grading LUT",
        default=32,
        min=4,
        soft_max=64,
    )

    validate: BoolProperty(
        name="Write Validation JSON",
        description="Write a companion validation JSON file for debugging and tests",
        default=False,
    )

    keep_texture_temp: BoolProperty(
        name="Keep Texture Temp Files",
        description="Keep intermediate mip PNG and ASTC files produced by texture baking",
        default=False,
    )

    @staticmethod
    def _asset_output_path(filepath: str) -> Path:
        selected_path = Path(filepath).expanduser().resolve()
        asset_name = selected_path.stem or "asset"
        return selected_path.parent / asset_name / f"{asset_name}.untold"

    def execute(self, context: bpy.types.Context) -> set[str]:
        output_path = self._asset_output_path(self.filepath)
        compression_summary = {"detail": None}

        wm = context.window_manager
        workspace = context.workspace
        wm.progress_begin(0, 100)

        def progress(stage: str, done: int, total: int, detail: str) -> None:
            if stage == "Compress geometry" and done >= total:
                compression_summary["detail"] = detail
            percent = (100.0 * done) / max(total, 1)
            suffix = f" - {detail}" if detail else ""
            wm.progress_update(percent)
            workspace.status_text_set(f"Untold Export: {stage} {percent:5.1f}%{suffix}")
            print(f"[Untold Exporter] {percent:5.1f}% {stage}{suffix}", flush=True)
            # Force the status bar to redraw now; the UI does not refresh on
            # its own while this blocking export operator is running.
            if not bpy.app.background:
                bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP', iterations=1)

        try:
            result = exporter_bridge().export_asset(
                context=context,
                output_path=output_path,
                scope=self.scope,
                file_type_name=self.file_type_name,
                convert_orientation=self.convert_orientation,
                source_orientation=self.source_orientation,
                validate=self.validate,
                compress_geometry=self.compress_geometry,
                bake_color_management=self.bake_color_management,
                color_lut_size=self.color_lut_size,
                bake_textures=self.bake_textures,
                texture_quality=self.texture_quality,
                keep_texture_temp=self.keep_texture_temp,
                progress_callback=progress,
            )
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            print(f"[Untold Exporter] Error: {exc}", flush=True)
            return {"CANCELLED"}
        finally:
            wm.progress_end()
            workspace.status_text_set(None)

        message = (
            f"Exported {result['mesh_count']} mesh(es), "
            f"{result['vertex_count']} vertices to {output_path.name}"
        )
        if compression_summary["detail"]:
            message += f" | Geometry: {compression_summary['detail']}"
        if result.get("hdr_asset_count"):
            message += f" | HDR: staged {result['hdr_asset_count']}"
        if result.get("texture_bake_status") == "baked":
            message += " | Textures: baked to .utex"
        elif result.get("texture_bake_status") == "no textures":
            message += " | Textures: none to bake"
        self.report({"INFO"}, message)
        print(f"[Untold Exporter] {message}", flush=True)
        return {"FINISHED"}


class UNTOLD_OT_export_animation(bpy.types.Operator, ExportHelper):
    bl_idname = "untold.export_animation"
    bl_label = "Export Untold Animation"
    bl_options = {"REGISTER"}

    filename_ext = ".untold"
    filter_glob: bpy.props.StringProperty(
        default="*.untold",
        options={"HIDDEN"},
    )

    scope: EnumProperty(
        name="Armature",
        description="Armature to export animation from",
        items=[
            ("SELECTED", "Selected Armature", "Export the selected armature, or the armature linked to a selected mesh"),
            ("SCENE", "Visible Scene Armature", "Export the only visible armature in the scene"),
        ],
        default="SELECTED",
    )

    action_mode: EnumProperty(
        name="Actions",
        description="Animation actions to export",
        items=[
            ("CURRENT", "Current Action", "Export the selected armature's active action"),
            ("ALL", "All Actions", "Export all Blender actions as clips"),
        ],
        default="CURRENT",
    )

    convert_orientation: BoolProperty(
        name="Convert Orientation",
        description="Convert from the selected source orientation into Untold Engine space (+Z forward, +Y up)",
        default=True,
    )

    source_orientation: EnumProperty(
        name="Source Orientation",
        description="Coordinate convention of the Blender scene data",
        items=[
            ("blender-native", "Blender Native", "Blender default: -Y forward, +Z up"),
            ("engine-oriented", "Engine Oriented", "Already in Untold Engine space: +Z forward, +Y up"),
        ],
        default="blender-native",
    )

    @staticmethod
    def _animation_output_path(filepath: str) -> Path:
        selected_path = Path(filepath).expanduser().resolve()
        clip_name = selected_path.stem or "animation"
        return selected_path.parent / clip_name / f"{clip_name}.untold"

    def execute(self, context: bpy.types.Context) -> set[str]:
        output_path = self._animation_output_path(self.filepath)

        wm = context.window_manager
        workspace = context.workspace
        wm.progress_begin(0, 100)

        def progress(stage: str, done: int, total: int, detail: str) -> None:
            percent = (100.0 * done) / max(total, 1)
            suffix = f" - {detail}" if detail else ""
            wm.progress_update(percent)
            workspace.status_text_set(f"Untold Export: {stage} {percent:5.1f}%{suffix}")
            print(f"[Untold Exporter] {percent:5.1f}% {stage}{suffix}", flush=True)
            # Force the status bar to redraw now; the UI does not refresh on
            # its own while this blocking export operator is running.
            if not bpy.app.background:
                bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP', iterations=1)

        try:
            result = exporter_bridge().export_animation(
                context=context,
                output_path=output_path,
                scope=self.scope,
                action_mode=self.action_mode,
                convert_orientation=self.convert_orientation,
                source_orientation=self.source_orientation,
                progress_callback=progress,
            )
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            print(f"[Untold Exporter] Error: {exc}", flush=True)
            return {"CANCELLED"}
        finally:
            wm.progress_end()
            workspace.status_text_set(None)

        message = (
            f"Exported {result['clip_count']} clip(s), "
            f"{result['channel_count']} channel(s) to {output_path.name}"
        )
        self.report({"INFO"}, message)
        print(f"[Untold Exporter] {message}", flush=True)
        return {"FINISHED"}


class UNTOLD_OT_export_tiled_scene(bpy.types.Operator):
    bl_idname = "untold.export_tiled_scene"
    bl_label = "Export Untold Tiled Scene"
    bl_options = {"REGISTER"}

    directory: StringProperty(
        name="Scene Folder",
        description="Folder where the scene manifest will be written. Tile payloads go in a tile_exports subfolder",
        subtype="DIR_PATH",
    )

    visible_only: BoolProperty(
        name="Visible Objects Only",
        description="Export visible mesh objects only",
        default=True,
    )

    partitioning_mode: EnumProperty(
        name="Partitioning",
        description="Tile partitioning algorithm",
        items=[
            ("UNIFORM",  "Uniform Grid", "Use regular X/Y/Z tile dimensions"),
            ("QUADTREE", "Quadtree",     "Use floor/quadtree partitioning with semantic tiers"),
            ("KDTREE",   "KD-Tree",      "Use floor/KD-tree partitioning — better balance in clustered scenes"),
        ],
        default="QUADTREE",
    )

    auto_tile_size: BoolProperty(
        name="Uniform Grid: Auto Tile Size",
        description="Let the uniform-grid exporter choose tile dimensions from scene complexity",
        default=True,
    )

    tile_size_x: FloatProperty(
        name="Uniform Grid: Tile Size X",
        description="Manual uniform-grid tile width in Blender/world units. Ignored when Auto Tile Size is enabled",
        default=25.0,
        min=0.001,
    )

    tile_size_y: FloatProperty(
        name="Uniform Grid: Tile Size Y",
        description="Manual uniform-grid tile height in Blender/world units. Usually large to avoid vertical splitting",
        default=10000.0,
        min=0.001,
    )

    tile_size_z: FloatProperty(
        name="Uniform Grid: Tile Size Z",
        description="Manual uniform-grid tile depth in Blender/world units. Ignored when Auto Tile Size is enabled",
        default=25.0,
        min=0.001,
    )

    floor_count: IntProperty(
        name="Tree: Floor Count",
        description="Optional floor count override for quadtree/KD-tree partitioning. Use 0 for auto-detect",
        default=0,
        min=0,
    )

    floor_band_height: FloatProperty(
        name="Tree: Floor Band Height",
        description="Optional per-floor band height override. Use 0 for auto-detect",
        default=0.0,
        min=0.0,
    )

    scene_profile: EnumProperty(
        name="Scene Profile",
        description="Streaming radius profile for semantic tiers",
        items=[
            ("auto", "Auto", "Infer indoor/outdoor streaming bands from the scene"),
            ("indoor", "Indoor", "Use tighter room-scale streaming bands"),
            ("outdoor", "Outdoor", "Use wider city/open-world streaming bands"),
        ],
        default="auto",
    )

    untagged_semantic_tier: EnumProperty(
        name="Untagged Semantic",
        description="Semantic tier used for meshes without an explicit Untold semantic override",
        items=[
            ("Auto", "Auto", "Infer from name, material, and size"),
            ("ExteriorShell", "Exterior Shell", "Treat untagged meshes as exterior shell geometry"),
            ("StructuralInterior", "Structural Interior", "Treat untagged meshes as structural interior geometry"),
            ("RoomContents", "Room Contents", "Treat untagged meshes as room contents"),
            ("FineProps", "Fine Props", "Treat untagged meshes as fine props"),
        ],
        default="Auto",
    )

    use_custom_tier_radii: BoolProperty(
        name="Custom Tier Radii",
        description="Override profile-derived semantic tier stream/unload radii for this tiled export",
        default=False,
    )
    exterior_shell_streaming_radius: FloatProperty(name="Exterior Stream", default=80.0, min=0.0)
    exterior_shell_unload_radius: FloatProperty(name="Exterior Unload", default=130.0, min=0.0)
    exterior_shell_priority: IntProperty(name="Exterior Priority", default=15, min=0)
    structural_interior_streaming_radius: FloatProperty(name="Structural Stream", default=80.0, min=0.0)
    structural_interior_unload_radius: FloatProperty(name="Structural Unload", default=130.0, min=0.0)
    structural_interior_priority: IntProperty(name="Structural Priority", default=15, min=0)
    room_contents_streaming_radius: FloatProperty(name="Room Stream", default=35.0, min=0.0)
    room_contents_unload_radius: FloatProperty(name="Room Unload", default=70.0, min=0.0)
    room_contents_priority: IntProperty(name="Room Priority", default=8, min=0)
    fine_props_streaming_radius: FloatProperty(name="Fine Stream", default=30.0, min=0.0)
    fine_props_unload_radius: FloatProperty(name="Fine Unload", default=60.0, min=0.0)
    fine_props_priority: IntProperty(name="Fine Priority", default=5, min=0)

    generate_hlod: BoolProperty(
        name="Generate HLOD",
        description="Generate simplified coarse HLOD assets for eligible tiles",
        default=False,
    )

    generate_lod: BoolProperty(
        name="Generate LOD",
        description="Generate per-tile LOD assets for eligible tiles",
        default=False,
    )

    use_custom_representation_ranges: BoolProperty(
        name="Custom Rep Ranges",
        description="Override normalized LOD/HLOD switch positions used by tiled export",
        default=False,
    )
    lod1_switch_distance: FloatProperty(name="LOD1 Start (m)", default=90.0, min=1.0, soft_max=2000.0)
    lod1_reduction_ratio: FloatProperty(name="LOD1 Ratio", default=0.50, min=0.01, max=1.0)
    lod2_switch_distance: FloatProperty(name="LOD2 Start (m)", default=150.0, min=1.0, soft_max=2000.0)
    lod2_reduction_ratio: FloatProperty(name="LOD2 Ratio", default=0.20, min=0.01, max=1.0)
    hlod_switch_distance: FloatProperty(name="HLOD Start (m)", default=250.0, min=1.0, soft_max=5000.0)
    hlod_reduction_ratio: FloatProperty(name="HLOD Ratio", default=0.10, min=0.01, max=1.0)

    compress_geometry: BoolProperty(
        name="Compress Geometry",
        description="Compress vertex and index chunks with LZ4 in tile payloads",
        default=False,
    )

    bake_color_management: BoolProperty(
        name="Bake Color Management",
        description=(
            "Bake the scene's active View Transform/Look/Exposure/Gamma into a scene-wide "
            "RGBA16Float LUT referenced from the manifest's colorLUT key, targeting "
            "canonical sRGB output"
        ),
        default=False,
    )

    color_lut_size: IntProperty(
        name="Color LUT Size",
        description="Grid size (N) for the NxNxN color-grading LUT",
        default=32,
        min=4,
        soft_max=64,
    )

    dry_run: BoolProperty(
        name="Dry Run",
        description="Plan the tile partition without writing payload files",
        default=False,
    )

    write_manifest_in_dry_run: BoolProperty(
        name="Write Manifest In Dry Run",
        description="Write the manifest JSON even when Dry Run is enabled",
        default=False,
    )

    def invoke(self, context: bpy.types.Context, event: bpy.types.Event) -> set[str]:
        preview = getattr(context.scene, "untold_tile_preview", None)
        if preview is not None:
            self.visible_only = preview.visible_only
            self.partitioning_mode = preview.partitioning_mode
            self.auto_tile_size = preview.auto_tile_size
            self.tile_size_x = preview.tile_size_x
            self.tile_size_z = preview.tile_size_z
            self.floor_count = preview.floor_count
            self.floor_band_height = preview.floor_band_height
            self.scene_profile = preview.scene_profile
            self.untagged_semantic_tier = preview.untagged_semantic_tier
            self.use_custom_tier_radii = preview.use_custom_tier_radii
            self.exterior_shell_streaming_radius = preview.exterior_shell_streaming_radius
            self.exterior_shell_unload_radius = preview.exterior_shell_unload_radius
            self.exterior_shell_priority = preview.exterior_shell_priority
            self.structural_interior_streaming_radius = preview.structural_interior_streaming_radius
            self.structural_interior_unload_radius = preview.structural_interior_unload_radius
            self.structural_interior_priority = preview.structural_interior_priority
            self.room_contents_streaming_radius = preview.room_contents_streaming_radius
            self.room_contents_unload_radius = preview.room_contents_unload_radius
            self.room_contents_priority = preview.room_contents_priority
            self.fine_props_streaming_radius = preview.fine_props_streaming_radius
            self.fine_props_unload_radius = preview.fine_props_unload_radius
            self.fine_props_priority = preview.fine_props_priority
            self.generate_hlod = preview.generate_hlod
            self.generate_lod = preview.generate_lod
            self.use_custom_representation_ranges = preview.use_custom_representation_ranges
            self.lod1_switch_distance = preview.lod1_switch_distance
            self.lod1_reduction_ratio = preview.lod1_reduction_ratio
            self.lod2_switch_distance = preview.lod2_switch_distance
            self.lod2_reduction_ratio = preview.lod2_reduction_ratio
            self.hlod_switch_distance = preview.hlod_switch_distance
            self.hlod_reduction_ratio = preview.hlod_reduction_ratio
        if not self.directory:
            blend_path = getattr(bpy.data, "filepath", "") or ""
            if blend_path:
                self.directory = str(Path(blend_path).resolve().parent / "TiledScene")
            else:
                self.directory = str(Path.home() / "UntoldTileExport")
        context.window_manager.fileselect_add(self)
        return {"RUNNING_MODAL"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        scene_dir = Path(bpy.path.abspath(self.directory)).expanduser().resolve()

        wm = context.window_manager
        workspace = context.workspace
        wm.progress_begin(0, 100)

        def progress(stage: str, done: int, total: int, detail: str) -> None:
            percent = (100.0 * done) / max(total, 1)
            suffix = f" - {detail}" if detail else ""
            wm.progress_update(percent)
            workspace.status_text_set(f"Untold Export: {stage} {percent:5.1f}%{suffix}")
            print(f"[Untold Exporter] {percent:5.1f}% {stage}{suffix}", flush=True)
            # Force the status bar to redraw now; the UI does not refresh on
            # its own while this blocking export operator is running.
            if not bpy.app.background:
                bpy.ops.wm.redraw_timer(type='DRAW_WIN_SWAP', iterations=1)

        try:
            result = exporter_bridge().export_tiled_scene(
                scene_dir=scene_dir,
                visible_only=self.visible_only,
                partitioning_mode=self.partitioning_mode,
                tile_size_x=self.tile_size_x,
                tile_size_y=self.tile_size_y,
                tile_size_z=self.tile_size_z,
                auto_tile_size=self.auto_tile_size,
                floor_count=self.floor_count,
                floor_band_height=self.floor_band_height,
                scene_profile=self.scene_profile,
                untagged_semantic_tier=self.untagged_semantic_tier,
                tier_radius_overrides=_tier_radius_overrides_from_settings(self),
                lod_level_overrides=_lod_level_overrides_from_settings(self),
                hlod_level_overrides=_hlod_level_overrides_from_settings(self),
                generate_hlod=self.generate_hlod,
                generate_lod=self.generate_lod,
                compress_geometry=self.compress_geometry,
                bake_color_management=self.bake_color_management,
                color_lut_size=self.color_lut_size,
                dry_run=self.dry_run,
                write_manifest_in_dry_run=self.write_manifest_in_dry_run,
                progress_callback=progress,
            )
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            print(f"[Untold Exporter] Error: {exc}", flush=True)
            return {"CANCELLED"}
        finally:
            wm.progress_end()
            workspace.status_text_set(None)

        mode = "planned" if result["dry_run"] else "exported"
        message = (
            f"Tiled scene {mode}: {result['asset_count']} .untold asset(s), "
            f"{result['manifest_count']} manifest file(s) in {scene_dir.name}"
        )
        self.report({"INFO"}, message)
        print(f"[Untold Exporter] {message}", flush=True)
        return {"FINISHED"}


def menu_func_export(self: bpy.types.Menu, context: bpy.types.Context) -> None:
    self.layout.operator(UNTOLD_OT_export_asset.bl_idname, text="Untold (.untold)")
    self.layout.operator(UNTOLD_OT_export_animation.bl_idname, text="Untold Animation (.untold)")
    self.layout.operator(UNTOLD_OT_export_tiled_scene.bl_idname, text="Untold Tiled Scene")


classes = (
    UNTOLD_OT_export_asset,
    UNTOLD_OT_export_animation,
    UNTOLD_OT_export_tiled_scene,
)


def register() -> None:
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)
    object_metadata.register()
    viewport_overlay.register()
    material_fidelity.register()
    color_management.register()


def unregister() -> None:
    color_management.unregister()
    material_fidelity.unregister()
    viewport_overlay.unregister()
    object_metadata.unregister()
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
