from __future__ import annotations

import importlib
import sys
from pathlib import Path
from typing import Any, Callable

import bpy


ProgressCallback = Callable[[str, int, int, str], None]


def _addon_dir() -> Path:
    return Path(__file__).resolve().parent


def _repo_scripts_dir() -> Path:
    # scripts/untold-blender-addon/untold_exporter/bridge.py -> scripts/
    return _addon_dir().parents[1]


def _ensure_exporter_on_path() -> None:
    repo_scripts = _repo_scripts_dir()
    if (repo_scripts / "untoldexplorer.py").is_file():
        path = str(repo_scripts)
        if path not in sys.path:
            sys.path.insert(0, path)
        return

    vendor_dir = _addon_dir() / "vendor"
    if (vendor_dir / "untoldexplorer.py").is_file():
        path = str(vendor_dir)
        if path not in sys.path:
            sys.path.insert(0, path)
        return

    raise RuntimeError(
        "Unable to locate untoldexplorer.py. Expected it in the repository "
        "scripts directory during development or untold_exporter/vendor in a packaged add-on."
    )


def exporter_module() -> Any:
    _ensure_exporter_on_path()
    module = importlib.import_module("untoldexplorer")
    # Reload during Blender add-on development so script edits are picked up
    # without restarting Blender.
    return importlib.reload(module)


def source_asset_path_for_export(output_path: Path) -> Path:
    blend_path = getattr(bpy.data, "filepath", "") or ""
    if blend_path:
        return Path(bpy.path.abspath(blend_path)).expanduser().resolve()
    return output_path.expanduser().resolve()


def scene_export_candidates(context: Any, scope: str) -> list[object]:
    if scope == "SELECTED":
        return list(context.selected_objects)

    view_layer_object_ids = {obj.as_pointer() for obj in context.view_layer.objects}
    return [
        obj
        for obj in context.scene.objects
        if obj.as_pointer() in view_layer_object_ids
        and not getattr(obj, "hide_get", lambda: False)()
        and getattr(obj, "type", None) in {"MESH", "ARMATURE", "EMPTY"}
    ]


def export_asset(
    *,
    context: Any,
    output_path: Path,
    scope: str,
    file_type_name: str,
    convert_orientation: bool,
    source_orientation: str,
    validate: bool,
    compress_geometry: bool,
    progress_callback: ProgressCallback | None = None,
) -> dict[str, object]:
    module = exporter_module()
    objects = scene_export_candidates(context, scope)
    if not objects:
        raise RuntimeError("No exportable objects were found for the selected scope")

    export_objects = module.prepare_export_objects_from_blender_objects(objects)
    return module.export_objects_to_untold(
        export_objects,
        source_asset_path=source_asset_path_for_export(output_path),
        output_path=output_path,
        file_type_name=file_type_name,
        convert_orientation=convert_orientation,
        source_orientation=source_orientation,
        validate=validate,
        compress_geometry=compress_geometry,
        progress_callback=progress_callback,
    )


def animation_armature_candidates(context: Any, scope: str) -> list[object]:
    if scope == "SELECTED":
        selected = [
            obj
            for obj in context.selected_objects
            if getattr(obj, "type", None) == "ARMATURE"
        ]
        if selected:
            return selected

        selected_meshes = [
            obj
            for obj in context.selected_objects
            if getattr(obj, "type", None) == "MESH"
        ]
        module = exporter_module()
        armatures = []
        seen = set()
        for mesh_object in selected_meshes:
            armature = module.armature_for_mesh(mesh_object)
            if armature is not None and armature.as_pointer() not in seen:
                armatures.append(armature)
                seen.add(armature.as_pointer())
        return armatures

    view_layer_object_ids = {obj.as_pointer() for obj in context.view_layer.objects}
    return [
        obj
        for obj in context.scene.objects
        if obj.as_pointer() in view_layer_object_ids
        and not getattr(obj, "hide_get", lambda: False)()
        and getattr(obj, "type", None) == "ARMATURE"
    ]


def actions_for_armature(armature: object, mode: str) -> list[object]:
    animation_data = getattr(armature, "animation_data", None)
    current_action = getattr(animation_data, "action", None) if animation_data is not None else None
    if mode == "CURRENT":
        return [current_action] if current_action is not None else []

    actions = list(getattr(bpy.data, "actions", []))
    if current_action is not None and current_action not in actions:
        actions.insert(0, current_action)
    return actions


def export_animation(
    *,
    context: Any,
    output_path: Path,
    scope: str,
    action_mode: str,
    convert_orientation: bool,
    source_orientation: str,
    progress_callback: ProgressCallback | None = None,
) -> dict[str, object]:
    module = exporter_module()
    armatures = animation_armature_candidates(context, scope)
    if not armatures:
        raise RuntimeError("No armature was found for animation export")
    if len(armatures) > 1:
        raise RuntimeError("Animation export supports one armature at a time. Select one armature or use Selected Armature scope.")

    armature = armatures[0]
    actions = actions_for_armature(armature, action_mode)
    if not actions:
        raise RuntimeError("No animation actions were found for the selected armature")

    conversion_matrix = module.make_export_orientation_matrix(source_orientation) if convert_orientation else None
    if progress_callback is not None:
        progress_callback("Extract animation", 0, 1, armature.name)
    clips = module.extract_animation_clips_from_armature(
        armature,
        actions,
        conversion_matrix=conversion_matrix,
    )
    return module.export_animation_clips_to_untold(
        clips,
        output_path,
        progress_callback=progress_callback,
    )
