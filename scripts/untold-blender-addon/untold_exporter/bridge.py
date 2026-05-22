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
