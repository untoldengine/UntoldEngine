from pathlib import Path
import importlib

import bpy
from bpy.props import BoolProperty, EnumProperty, FloatProperty, IntProperty, StringProperty
from bpy_extras.io_utils import ExportHelper

from . import bridge
from . import viewport_overlay


def exporter_bridge():
    return importlib.reload(bridge)


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
            ("tile", "Tile", "Standard runtime asset/tile payload"),
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

    validate: BoolProperty(
        name="Write Validation JSON",
        description="Write a companion validation JSON file for debugging and tests",
        default=False,
    )

    compress_geometry: BoolProperty(
        name="Compress Geometry",
        description="Compress vertex and index chunks with LZ4 if the lz4 Python package is available",
        default=False,
    )

    bake_textures: BoolProperty(
        name="Bake Textures To .utex",
        description="After export, bake staged textures to engine-native .utex files and patch the .untold references",
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

        def progress(stage: str, done: int, total: int, detail: str) -> None:
            if stage == "Compress geometry" and done >= total:
                compression_summary["detail"] = detail
            if total > 1:
                print(f"[Untold Exporter] {stage} {done}/{total} - {detail}", flush=True)
            else:
                print(f"[Untold Exporter] {stage} - {detail}", flush=True)

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
                bake_textures=self.bake_textures,
                texture_quality=self.texture_quality,
                keep_texture_temp=self.keep_texture_temp,
                progress_callback=progress,
            )
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            print(f"[Untold Exporter] Error: {exc}", flush=True)
            return {"CANCELLED"}

        message = (
            f"Exported {result['mesh_count']} mesh(es), "
            f"{result['vertex_count']} vertices to {output_path.name}"
        )
        if compression_summary["detail"]:
            message += f" | Geometry: {compression_summary['detail']}"
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

        def progress(stage: str, done: int, total: int, detail: str) -> None:
            if total > 1:
                print(f"[Untold Exporter] {stage} {done}/{total} - {detail}", flush=True)
            else:
                print(f"[Untold Exporter] {stage} - {detail}", flush=True)

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

    compress_geometry: BoolProperty(
        name="Compress Geometry",
        description="Compress vertex and index chunks with LZ4 in tile payloads",
        default=False,
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
                generate_hlod=self.generate_hlod,
                generate_lod=self.generate_lod,
                compress_geometry=self.compress_geometry,
                dry_run=self.dry_run,
                write_manifest_in_dry_run=self.write_manifest_in_dry_run,
            )
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            print(f"[Untold Exporter] Error: {exc}", flush=True)
            return {"CANCELLED"}

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
    viewport_overlay.register()


def unregister() -> None:
    viewport_overlay.unregister()
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
