from __future__ import annotations

import math

import bpy
import gpu
from bpy.app.handlers import persistent
from gpu_extras.batch import batch_for_shader
from mathutils import Vector
from bpy.props import FloatProperty, BoolProperty, EnumProperty, IntProperty


# ── Global draw state ─────────────────────────────────────────────────────────

_draw_handle = None
_tile_boxes: list[tuple] = []   # [(mn_xyz, mx_xyz, rgba), ...]
_draw_shader = None
_fill_batches: list[tuple] = []  # [(batch, rgba), ...]
_line_batches: list[tuple] = []  # [(batch, rgba), ...]
_preview_object_names: set[str] = set()
_preview_color_mode = "DENSITY"
_mesh_view_state: dict[str, dict] = {}


# ── Color helpers ─────────────────────────────────────────────────────────────

def _heatmap_color(t: float, alpha: float = 0.9) -> tuple:
    """Map t ∈ [0,1] to green → yellow → red."""
    if t < 0.5:
        r = t * 2.0
        g = 0.8
    else:
        r = 1.0
        g = 0.8 * (1.0 - (t - 0.5) * 2.0)
    return (r, g, 0.05, alpha)


def _shared_color() -> tuple:
    return (0.20, 0.45, 0.95, 0.9)


def _runtime_color(state: str) -> tuple:
    colors = {
        "full": (0.10, 0.85, 0.25, 0.9),
        "lod": (1.00, 0.72, 0.08, 0.9),
        "hlod": (0.10, 0.78, 1.00, 0.9),
        "unloaded": (0.42, 0.42, 0.42, 0.55),
        "shared": _shared_color(),
    }
    return colors.get(state, colors["unloaded"])


# ── Geometry helpers ──────────────────────────────────────────────────────────

def _box_line_coords(mn: tuple, mx: tuple) -> list[tuple]:
    x0, y0, z0 = mn
    x1, y1, z1 = mx
    return [
        (x0, y0, z0), (x1, y0, z0),
        (x1, y0, z0), (x1, y1, z0),
        (x1, y1, z0), (x0, y1, z0),
        (x0, y1, z0), (x0, y0, z0),
        (x0, y0, z1), (x1, y0, z1),
        (x1, y0, z1), (x1, y1, z1),
        (x1, y1, z1), (x0, y1, z1),
        (x0, y1, z1), (x0, y0, z1),
        (x0, y0, z0), (x0, y0, z1),
        (x1, y0, z0), (x1, y0, z1),
        (x1, y1, z0), (x1, y1, z1),
        (x0, y1, z0), (x0, y1, z1),
    ]


def _box_floor_tris(mn: tuple, mx: tuple) -> list[tuple]:
    x0, y0, z = mn[0], mn[1], mn[2]
    x1, y1 = mx[0], mx[1]
    return [
        (x0, y0, z), (x1, y0, z), (x1, y1, z),
        (x0, y0, z), (x1, y1, z), (x0, y1, z),
    ]


# ── Quadtree node bound reconstruction ───────────────────────────────────────
#
# Node IDs encode the path from root as child indices separated by underscores.
# Example: "F02_Q_0_3_1"  →  floor 2, child path SW → NE → SE
#
# _QuadNode.subdivide() child order (tilestreamingpartition.py):
#   0 → (min_x, min_y, mid_x, mid_y)   SW
#   1 → (mid_x, min_y, max_x, mid_y)   SE
#   2 → (min_x, mid_y, mid_x, max_y)   NW
#   3 → (mid_x, mid_y, max_x, max_y)   NE
#
# All floors share the same XY root (global scene XY bounds).

def _quadtree_node_xy_bounds(
    node_id: str,
    scene_min_x: float, scene_min_y: float,
    scene_max_x: float, scene_max_y: float,
) -> tuple[float, float, float, float] | None:
    parts = node_id.split('_')
    try:
        q_idx = next(i for i, p in enumerate(parts) if p == 'Q')
    except StopIteration:
        return None

    min_x, min_y = scene_min_x, scene_min_y
    max_x, max_y = scene_max_x, scene_max_y

    for p in parts[q_idx + 1:]:
        if not p.isdigit():
            break
        idx = int(p)
        mid_x = (min_x + max_x) * 0.5
        mid_y = (min_y + max_y) * 0.5
        if idx == 0:
            max_x, max_y = mid_x, mid_y
        elif idx == 1:
            min_x = mid_x; max_y = mid_y
        elif idx == 2:
            max_x = mid_x; min_y = mid_y
        elif idx == 3:
            min_x = mid_x; min_y = mid_y

    return min_x, min_y, max_x, max_y


# ── GPU draw callback ─────────────────────────────────────────────────────────

def _draw_callback() -> None:
    if not _fill_batches and not _line_batches:
        return

    shader = _ensure_draw_shader()
    shader.bind()

    gpu.state.blend_set('ALPHA')
    gpu.state.depth_test_set('LESS_EQUAL')
    gpu.state.depth_mask_set(False)

    for batch, color in _fill_batches:
        shader.uniform_float("color", color)
        batch.draw(shader)

    gpu.state.depth_mask_set(True)

    for batch, color in _line_batches:
        shader.uniform_float("color", color)
        batch.draw(shader)

    gpu.state.blend_set('NONE')
    gpu.state.depth_test_set('NONE')


def _ensure_draw_shader():
    global _draw_shader
    if _draw_shader is None:
        _draw_shader = gpu.shader.from_builtin('UNIFORM_COLOR')
    return _draw_shader


def _rebuild_draw_batches() -> None:
    global _fill_batches, _line_batches
    shader = _ensure_draw_shader()
    _fill_batches = []
    _line_batches = []
    for mn, mx, color in _tile_boxes:
        fill = (color[0], color[1], color[2], color[3] * 0.20)
        _fill_batches.append((
            batch_for_shader(shader, 'TRIS', {"pos": _box_floor_tris(mn, mx)}),
            fill,
        ))
        _line_batches.append((
            batch_for_shader(shader, 'LINES', {"pos": _box_line_coords(mn, mx)}),
            color,
        ))


def _clear_preview_state() -> None:
    global _tile_boxes, _fill_batches, _line_batches, _preview_object_names, _preview_color_mode
    _tile_boxes = []
    _fill_batches = []
    _line_batches = []
    _preview_object_names = set()
    _preview_color_mode = "DENSITY"
    _unregister_draw_handler()


def _register_draw_handler() -> None:
    global _draw_handle
    if _draw_handle is None:
        _draw_handle = bpy.types.SpaceView3D.draw_handler_add(
            _draw_callback, (), 'WINDOW', 'POST_VIEW'
        )


def _unregister_draw_handler() -> None:
    global _draw_handle
    if _draw_handle is not None:
        bpy.types.SpaceView3D.draw_handler_remove(_draw_handle, 'WINDOW')
        _draw_handle = None


def _tag_viewports_redraw(context: bpy.types.Context) -> None:
    for area in context.screen.areas:
        if area.type == 'VIEW_3D':
            area.tag_redraw()


def _tag_all_viewports_redraw() -> None:
    window_manager = getattr(bpy.context, "window_manager", None)
    if window_manager is None:
        return
    for window in window_manager.windows:
        screen = getattr(window, "screen", None)
        if screen is None:
            continue
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                area.tag_redraw()


def _tile_preview_collection_objects() -> set:
    preview_col = bpy.data.collections.get("Tile Preview")
    return set(preview_col.objects) if preview_col else set()


def _viewport_utility_meshes(context: bpy.types.Context) -> list:
    preview_objects = _tile_preview_collection_objects()
    return [
        obj for obj in context.scene.objects
        if obj.type == 'MESH' and obj not in preview_objects
    ]


def _remember_mesh_view_state(context: bpy.types.Context, objects: list) -> None:
    view_layer = context.view_layer
    for obj in objects:
        if obj.name in _mesh_view_state:
            continue
        _mesh_view_state[obj.name] = {
            "display_type": obj.display_type,
            "hide_viewport": obj.hide_viewport,
            "hide_get": obj.hide_get(view_layer=view_layer),
        }


@persistent
def _clear_preview_on_file_event(_dummy=None) -> None:
    global _mesh_view_state
    _clear_preview_state()
    _mesh_view_state = {}
    _tag_all_viewports_redraw()


@persistent
def _clear_preview_when_source_meshes_change(scene, _depsgraph=None) -> None:
    if not _preview_object_names:
        return
    current_mesh_names = {obj.name for obj in scene.objects if obj.type == 'MESH'}
    if not _preview_object_names.issubset(current_mesh_names):
        _clear_preview_state()
        _tag_all_viewports_redraw()


def _register_app_handlers() -> None:
    _unregister_app_handlers()
    if _clear_preview_on_file_event not in bpy.app.handlers.load_pre:
        bpy.app.handlers.load_pre.append(_clear_preview_on_file_event)
    if _clear_preview_on_file_event not in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.append(_clear_preview_on_file_event)
    if _clear_preview_when_source_meshes_change not in bpy.app.handlers.depsgraph_update_post:
        bpy.app.handlers.depsgraph_update_post.append(_clear_preview_when_source_meshes_change)


def _unregister_app_handlers() -> None:
    callbacks = (
        (bpy.app.handlers.load_pre, _clear_preview_on_file_event),
        (bpy.app.handlers.load_post, _clear_preview_on_file_event),
        (bpy.app.handlers.depsgraph_update_post, _clear_preview_when_source_meshes_change),
    )
    for handlers, callback in callbacks:
        callback_names = {callback.__name__}
        for handler in list(handlers):
            if (
                handler is callback
                or (
                    getattr(handler, "__module__", None) == __name__
                    and getattr(handler, "__name__", None) in callback_names
                )
            ):
                handlers.remove(handler)


# ── Scene property group ──────────────────────────────────────────────────────

class UntoldTilePreviewSettings(bpy.types.PropertyGroup):
    partitioning_mode: EnumProperty(
        name="Mode",
        description="Must match what you will use in File > Export > Untold Tiled Scene",
        items=[
            ('UNIFORM',  "Uniform Grid", "Regular XZ grid — fastest, best for open outdoor scenes"),
            ('QUADTREE', "Quadtree",     "Floor + quadtree hierarchy — best for multi-floor buildings"),
            ('KDTREE',   "KD-Tree",      "Floor + KD-tree hierarchy — better balance in clustered scenes"),
        ],
        default='QUADTREE',
    )

    # Uniform grid
    auto_tile_size: BoolProperty(
        name="Auto Tile Size",
        description="Let the exporter choose tile dimensions from scene complexity — matches default export behaviour",
        default=True,
    )
    tile_size_x: FloatProperty(
        name="Tile Size X",
        description="Tile width in world units (Blender X). Only used when Auto Tile Size is off",
        default=25.0, min=0.1,
    )
    tile_size_z: FloatProperty(
        name="Tile Size Z (Depth)",
        description="Tile depth in world units (Blender Y). Only used when Auto Tile Size is off",
        default=25.0, min=0.1,
    )
    spanning_threshold: FloatProperty(
        name="Spanning Threshold",
        description="Objects wider than this many tile-lengths go to the shared bucket (blue)",
        default=4.0, min=1.0, max=32.0,
    )

    # Quadtree / KD-tree
    floor_count: IntProperty(
        name="Floor Count",
        description="Number of floors (0 = auto-detect from object Z dimensions)",
        default=0, min=0,
    )
    floor_band_height: FloatProperty(
        name="Floor Band Height",
        description="Per-floor Z band height in world units (0 = auto-detect)",
        default=0.0, min=0.0,
    )

    scene_profile: EnumProperty(
        name="Scene Profile",
        description="Streaming radius profile used for LOD/HLOD planning and tiled export",
        items=[
            ("auto", "Auto", "Infer indoor/outdoor streaming bands from the scene"),
            ("indoor", "Indoor", "Use tighter room-scale streaming bands"),
            ("outdoor", "Outdoor", "Use wider city/open-world streaming bands"),
        ],
        default="auto",
    )

    generate_hlod: BoolProperty(
        name="Generate HLOD",
        description="Generate far-distance coarse HLOD payloads for eligible tile groups",
        default=False,
    )

    generate_lod: BoolProperty(
        name="Generate LOD",
        description="Generate per-tile intermediate LOD payloads for eligible tile groups",
        default=False,
    )

    runtime_source: EnumProperty(
        name="Distance Source",
        description="Position used to preview which tile representation would be active",
        items=[
            ("CAMERA", "Active Camera", "Use the active scene camera position"),
            ("CURSOR", "3D Cursor", "Use the 3D cursor position"),
            ("SELECTED", "Selected Object", "Use the active selected object position"),
        ],
        default="CAMERA",
    )

    visible_only: BoolProperty(
        name="Visible Objects Only",
        description="Preview only visible mesh objects, matching the default export behaviour",
        default=True,
    )


# ── Object / AABB helpers ─────────────────────────────────────────────────────

def _collect_objects(context: bpy.types.Context, visible_only: bool) -> list:
    view_layer = context.view_layer
    return [
        obj for obj in context.scene.objects
        if obj.type == 'MESH'
        and (not visible_only or (
            not obj.hide_viewport and not obj.hide_get(view_layer=view_layer)
        ))
    ]


def _compute_aabbs(objects: list, context: bpy.types.Context) -> dict:
    depsgraph = context.evaluated_depsgraph_get()
    result = {}
    for obj in objects:
        eval_obj = obj.evaluated_get(depsgraph)
        mw = eval_obj.matrix_world
        corners = [mw @ Vector(c) for c in eval_obj.bound_box]
        result[obj.name] = (
            Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners))),
            Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners))),
        )
    return result


def _scene_z_range(aabbs: dict) -> tuple[float, float]:
    return (
        min(v[0].z for v in aabbs.values()),
        max(v[1].z for v in aabbs.values()),
    )


def _aabbs_to_module_format(aabbs: dict) -> dict:
    """Convert {name: (Vector_min, Vector_max)} to {name: {"min": tuple, "max": tuple}}."""
    return {
        name: {"min": (mn.x, mn.y, mn.z), "max": (mx.x, mx.y, mx.z)}
        for name, (mn, mx) in aabbs.items()
    }


def _scene_bounds_from_aabbs(aabbs: dict) -> dict:
    return {
        "min": (
            min(v[0].x for v in aabbs.values()),
            min(v[0].y for v in aabbs.values()),
            min(v[0].z for v in aabbs.values()),
        ),
        "max": (
            max(v[1].x for v in aabbs.values()),
            max(v[1].y for v in aabbs.values()),
            max(v[1].z for v in aabbs.values()),
        ),
    }


def _scene_half_diag(scene_bounds: dict) -> float:
    return 0.5 * math.sqrt(
        (scene_bounds["max"][0] - scene_bounds["min"][0]) ** 2 +
        (scene_bounds["max"][1] - scene_bounds["min"][1]) ** 2
    )


# ── Partition builders ────────────────────────────────────────────────────────

def _build_uniform_boxes(objects: list, aabbs: dict, settings) -> tuple[list, dict]:
    """Delegate classification to tilestreamingpartition.build_assignments so all
    spanning rules (OVERLAP_THRESHOLD, SPLIT_MAX_TILES, SPLIT_SPANNING_OBJECTS)
    and auto tile sizing match the actual exporter."""
    from . import bridge as _bridge
    module = _bridge.tile_exporter_module()

    tile_x = settings.tile_size_x
    tile_z = settings.tile_size_z

    # Propagate preview settings to module globals so build_assignments
    # uses the same classification thresholds as the UI exposes.
    module.SPANNING_THRESHOLD_TILES = settings.spanning_threshold
    module.TILE_SIZE_X = tile_x
    module.TILE_SIZE_Z = tile_z

    object_bounds = _aabbs_to_module_format(aabbs)
    scene_bounds = _scene_bounds_from_aabbs(aabbs)
    origin_y = scene_bounds["min"][2]   # Blender Z height → tile Y

    if settings.auto_tile_size:
        tile_x, tile_z, _ = module.choose_auto_tile_size(
            objects, object_bounds, scene_bounds, origin_y, module.TILE_SIZE_Y
        )
        module.TILE_SIZE_X = tile_x
        module.TILE_SIZE_Z = tile_z

    # Same world-aligned snap as tilestreamingpartition.py
    origin_x = math.floor(scene_bounds["min"][0] / tile_x) * tile_x   # Blender X
    origin_z = math.floor(scene_bounds["min"][1] / tile_z) * tile_z   # Blender Y depth → tile Z

    tile_assignments, shared_objects, _ = module.build_assignments(
        objects, object_bounds,
        origin_x, origin_y, origin_z,
        tile_x, module.TILE_SIZE_Y, tile_z,
    )

    scene_min_z, scene_max_z = _scene_z_range(aabbs)
    max_count = max((len(v) for v in tile_assignments.values()), default=1)
    boxes: list[tuple] = []

    for (tx, ty, tz), objs in tile_assignments.items():
        t  = (len(objs) - 1) / max(max_count - 1, 1)
        tb = module.tile_bounds_from_coord(
            tx, ty, tz, origin_x, origin_y, origin_z,
            tile_x, module.TILE_SIZE_Y, tile_z,
        )
        # tile_bounds keys: min_x/max_x = Blender X, min_z/max_z = Blender Y depth
        mn = (tb["min_x"], tb["min_z"], scene_min_z)
        mx = (tb["max_x"], tb["max_z"], scene_max_z)
        boxes.append((mn, mx, _heatmap_color(t)))

    for obj in shared_objects:
        mn_v, mx_v = aabbs[obj.name]
        boxes.append(((mn_v.x, mn_v.y, mn_v.z), (mx_v.x, mx_v.y, mx_v.z), _shared_color()))

    return boxes, {
        "tiles":  len(tile_assignments),
        "shared": len(shared_objects),
        "max":    max_count,
        "avg":    sum(len(v) for v in tile_assignments.values()) / max(len(tile_assignments), 1),
        "tile_x": tile_x,
        "tile_z": tile_z,
    }


def _build_tree_boxes(objects: list, aabbs: dict, settings, use_kdtree: bool) -> tuple[list, dict]:
    """Use tilestreamingpartition's inline annotation then build_quadtree_assignments
    so tier-based grouping and shared-bucket routing exactly match the exporter."""
    from . import bridge as _bridge
    module = _bridge.tile_exporter_module()

    module.INLINE_FLOOR_COUNT_OVERRIDE       = settings.floor_count       if settings.floor_count > 0       else None
    module.INLINE_FLOOR_BAND_HEIGHT_OVERRIDE = settings.floor_band_height if settings.floor_band_height > 0.0 else None

    object_bounds = _aabbs_to_module_format(aabbs)

    if use_kdtree:
        metadata = module.compute_inline_kdtree_metadata(objects, object_bounds)
    else:
        metadata = module.compute_inline_quadtree_metadata(objects, object_bounds)

    if not metadata:
        return [], {}

    # build_quadtree_assignments handles (node_id, tier) grouping and the
    # ExteriorShell-only rule for shared-bucket routing, matching the exporter.
    node_tier_groups, shared_objects, _ = module.build_quadtree_assignments(
        objects, object_bounds, inline_metadata=metadata
    )

    scene_min_x = min(v[0].x for v in aabbs.values())
    scene_min_y = min(v[0].y for v in aabbs.values())
    scene_max_x = max(v[1].x for v in aabbs.values())
    scene_max_y = max(v[1].y for v in aabbs.values())
    scene_min_z, scene_max_z = _scene_z_range(aabbs)

    max_count = max((len(v) for v in node_tier_groups.values()), default=1)
    boxes: list[tuple] = []

    for (node_id, _tier), objs in node_tier_groups.items():
        t     = (len(objs) - 1) / max(max_count - 1, 1)
        color = _heatmap_color(t)
        z_min = min(aabbs[obj.name][0].z for obj in objs)
        z_max = max(aabbs[obj.name][1].z for obj in objs)

        if not use_kdtree:
            bounds = _quadtree_node_xy_bounds(
                node_id, scene_min_x, scene_min_y, scene_max_x, scene_max_y
            )
            if bounds:
                nx0, ny0, nx1, ny1 = bounds
                boxes.append(((nx0, ny0, z_min), (nx1, ny1, z_max), color))
                continue

        # KD-tree: use union AABB (split positions are data-driven, not reconstructable)
        x_min = min(aabbs[obj.name][0].x for obj in objs)
        y_min = min(aabbs[obj.name][0].y for obj in objs)
        x_max = max(aabbs[obj.name][1].x for obj in objs)
        y_max = max(aabbs[obj.name][1].y for obj in objs)
        boxes.append(((x_min, y_min, z_min), (x_max, y_max, z_max), color))

    for obj in shared_objects:
        mn_v, mx_v = aabbs[obj.name]
        boxes.append(((mn_v.x, mn_v.y, mn_v.z), (mx_v.x, mx_v.y, mx_v.z), _shared_color()))

    return boxes, {
        "tiles":  len(node_tier_groups),
        "nodes":  len({node_id for node_id, _tier in node_tier_groups}),
        "shared": len(shared_objects),
        "max":    max_count,
        "avg":    sum(len(v) for v in node_tier_groups.values()) / max(len(node_tier_groups), 1),
    }


def _build_lod_plan(objects: list, aabbs: dict, settings) -> dict:
    from . import bridge as _bridge
    module = _bridge.tile_exporter_module()

    if not settings.generate_hlod and not settings.generate_lod:
        return {"enabled": False}

    object_bounds = _aabbs_to_module_format(aabbs)
    scene_bounds = _scene_bounds_from_aabbs(aabbs)
    scene_half_diag = _scene_half_diag(scene_bounds)
    base_tile = max(settings.tile_size_x, settings.tile_size_z, 1.0)
    streaming_r, unload_r = module.compute_streaming_defaults(base_tile, scene_half_diag)

    hlod_levels = module.validate_hlod_levels() if settings.generate_hlod else []
    lod_levels = module.validate_lod_levels() if settings.generate_lod else []
    active_hlod = module.compute_hlod_switch_distances(streaming_r, unload_r, hlod_levels)
    active_lod = module.compute_lod_switch_distances(streaming_r, unload_r, active_hlod, lod_levels)

    mode = settings.partitioning_mode
    if mode == 'UNIFORM':
        tile_x = settings.tile_size_x
        tile_z = settings.tile_size_z
        module.TILE_SIZE_X = tile_x
        module.TILE_SIZE_Z = tile_z
        origin_y = scene_bounds["min"][2]
        if settings.auto_tile_size:
            tile_x, tile_z, _ = module.choose_auto_tile_size(
                objects, object_bounds, scene_bounds, origin_y, module.TILE_SIZE_Y
            )
        origin_x = math.floor(scene_bounds["min"][0] / tile_x) * tile_x
        origin_z = math.floor(scene_bounds["min"][1] / tile_z) * tile_z
        tile_assignments, _shared_objects, _ = module.build_assignments(
            objects, object_bounds,
            origin_x, origin_y, origin_z,
            tile_x, module.TILE_SIZE_Y, tile_z,
        )
        eligible_groups = len([objs for objs in tile_assignments.values() if objs])
        skipped_groups = 0
        resolved_profile = settings.scene_profile
        by_tier = {}
    else:
        use_kdtree = mode == 'KDTREE'
        module.INLINE_FLOOR_COUNT_OVERRIDE = settings.floor_count if settings.floor_count > 0 else None
        module.INLINE_FLOOR_BAND_HEIGHT_OVERRIDE = settings.floor_band_height if settings.floor_band_height > 0.0 else None
        if use_kdtree:
            metadata = module.compute_inline_kdtree_metadata(objects, object_bounds)
        else:
            metadata = module.compute_inline_quadtree_metadata(objects, object_bounds)
        node_tier_groups, _shared_objects, _metadata_map = module.build_quadtree_assignments(
            objects, object_bounds, inline_metadata=metadata
        )
        resolved_profile = module.infer_streaming_profile(
            True, node_tier_groups, scene_half_diag, base_tile
        ) if settings.scene_profile == "auto" else settings.scene_profile
        module.init_tier_radii(scene_half_diag, resolved_profile)
        eligible_tiers = set(module.HLOD_LOD_TIERS)
        eligible_groups = sum(
            1 for (_node_id, tier), objs in node_tier_groups.items()
            if objs and tier in eligible_tiers
        )
        skipped_groups = sum(
            1 for (_node_id, tier), objs in node_tier_groups.items()
            if objs and tier not in eligible_tiers
        )
        by_tier = {}
        for (_node_id, tier), objs in node_tier_groups.items():
            if objs:
                by_tier[tier] = by_tier.get(tier, 0) + 1

    return {
        "enabled": True,
        "mode": mode,
        "profile": resolved_profile,
        "eligible_groups": eligible_groups,
        "skipped_groups": skipped_groups,
        "hlod_levels": active_hlod,
        "lod_levels": active_lod,
        "hlod_assets": eligible_groups * len(active_hlod),
        "lod_assets": eligible_groups * len(active_lod),
        "by_tier": by_tier,
    }


def _distance_source_position(context: bpy.types.Context, settings) -> tuple[Vector | None, str]:
    if settings.runtime_source == "CAMERA":
        camera = context.scene.camera
        if camera is None:
            return None, "Active Camera"
        return camera.matrix_world.translation.copy(), "Active Camera"
    if settings.runtime_source == "CURSOR":
        return context.scene.cursor.location.copy(), "3D Cursor"
    active = context.object
    if active is None:
        return None, "Selected Object"
    return active.matrix_world.translation.copy(), "Selected Object"


def _runtime_ladder(module, streaming_r: float, unload_r: float, settings, eligible: bool) -> tuple[list, list]:
    if not eligible:
        return [], []
    hlod_levels = module.validate_hlod_levels() if settings.generate_hlod else []
    lod_levels = module.validate_lod_levels() if settings.generate_lod else []
    active_hlod = module.compute_hlod_switch_distances(streaming_r, unload_r, hlod_levels)
    active_lod = module.compute_lod_switch_distances(streaming_r, unload_r, active_hlod, lod_levels)
    return active_hlod, active_lod


def _build_uniform_runtime_boxes(objects: list, aabbs: dict, settings, source_pos: Vector) -> tuple[list, dict]:
    from . import bridge as _bridge
    module = _bridge.tile_exporter_module()

    tile_x = settings.tile_size_x
    tile_z = settings.tile_size_z
    module.SPANNING_THRESHOLD_TILES = settings.spanning_threshold
    module.TILE_SIZE_X = tile_x
    module.TILE_SIZE_Z = tile_z

    object_bounds = _aabbs_to_module_format(aabbs)
    scene_bounds = _scene_bounds_from_aabbs(aabbs)
    origin_y = scene_bounds["min"][2]

    if settings.auto_tile_size:
        tile_x, tile_z, _ = module.choose_auto_tile_size(
            objects, object_bounds, scene_bounds, origin_y, module.TILE_SIZE_Y
        )
        module.TILE_SIZE_X = tile_x
        module.TILE_SIZE_Z = tile_z

    origin_x = math.floor(scene_bounds["min"][0] / tile_x) * tile_x
    origin_z = math.floor(scene_bounds["min"][1] / tile_z) * tile_z

    tile_assignments, shared_objects, _ = module.build_assignments(
        objects, object_bounds,
        origin_x, origin_y, origin_z,
        tile_x, module.TILE_SIZE_Y, tile_z,
    )

    scene_min_z, scene_max_z = _scene_z_range(aabbs)
    scene_half_diag = _scene_half_diag(scene_bounds)
    streaming_r, unload_r = module.compute_streaming_defaults(max(tile_x, tile_z, 1.0), scene_half_diag)
    active_hlod, active_lod = _runtime_ladder(
        module, streaming_r, unload_r, settings, bool(settings.generate_hlod or settings.generate_lod)
    )
    stats = {"full": 0, "lod": 0, "hlod": 0, "unloaded": 0, "shared": len(shared_objects)}
    boxes: list[tuple] = []

    for tx, ty, tz in tile_assignments.keys():
        tb = module.tile_bounds_from_coord(
            tx, ty, tz, origin_x, origin_y, origin_z,
            tile_x, module.TILE_SIZE_Y, tile_z,
        )
        mn = (tb["min_x"], tb["min_z"], scene_min_z)
        mx = (tb["max_x"], tb["max_z"], scene_max_z)
        distance = module.distance_to_aabb(
            (source_pos.x, source_pos.y, source_pos.z),
            {"min": mn, "max": mx},
        )
        state = module.classify_runtime_representation(distance, unload_r, active_hlod, active_lod)
        stats[state] += 1
        boxes.append((mn, mx, _runtime_color(state)))

    for obj in shared_objects:
        mn_v, mx_v = aabbs[obj.name]
        boxes.append(((mn_v.x, mn_v.y, mn_v.z), (mx_v.x, mx_v.y, mx_v.z), _runtime_color("shared")))

    return boxes, stats


def _build_tree_runtime_boxes(
    objects: list,
    aabbs: dict,
    settings,
    source_pos: Vector,
    use_kdtree: bool,
) -> tuple[list, dict]:
    from . import bridge as _bridge
    module = _bridge.tile_exporter_module()

    module.INLINE_FLOOR_COUNT_OVERRIDE = settings.floor_count if settings.floor_count > 0 else None
    module.INLINE_FLOOR_BAND_HEIGHT_OVERRIDE = settings.floor_band_height if settings.floor_band_height > 0.0 else None

    object_bounds = _aabbs_to_module_format(aabbs)
    metadata = (
        module.compute_inline_kdtree_metadata(objects, object_bounds)
        if use_kdtree
        else module.compute_inline_quadtree_metadata(objects, object_bounds)
    )
    if not metadata:
        return [], {}

    node_tier_groups, shared_objects, _ = module.build_quadtree_assignments(
        objects, object_bounds, inline_metadata=metadata
    )

    scene_bounds = _scene_bounds_from_aabbs(aabbs)
    scene_half_diag = _scene_half_diag(scene_bounds)
    base_tile = max(settings.tile_size_x, settings.tile_size_z, 1.0)
    resolved_profile = module.infer_streaming_profile(
        True, node_tier_groups, scene_half_diag, base_tile
    ) if settings.scene_profile == "auto" else settings.scene_profile
    module.init_tier_radii(scene_half_diag, resolved_profile)

    scene_min_x = min(v[0].x for v in aabbs.values())
    scene_min_y = min(v[0].y for v in aabbs.values())
    scene_max_x = max(v[1].x for v in aabbs.values())
    scene_max_y = max(v[1].y for v in aabbs.values())
    eligible_tiers = set(module.HLOD_LOD_TIERS)
    stats = {"full": 0, "lod": 0, "hlod": 0, "unloaded": 0, "shared": len(shared_objects)}
    boxes: list[tuple] = []

    for (node_id, tier), objs in node_tier_groups.items():
        if not objs:
            continue

        distance_aabb = module.object_union_aabb(objs, object_bounds)
        distance_mn = distance_aabb["min"]
        distance_mx = distance_aabb["max"]
        z_min = distance_mn[2]
        z_max = distance_mx[2]
        if not use_kdtree:
            bounds = _quadtree_node_xy_bounds(
                node_id, scene_min_x, scene_min_y, scene_max_x, scene_max_y
            )
            if bounds:
                nx0, ny0, nx1, ny1 = bounds
                mn = (nx0, ny0, z_min)
                mx = (nx1, ny1, z_max)
            else:
                mn = None
                mx = None
        else:
            mn = None
            mx = None

        if mn is None or mx is None:
            mn = distance_mn
            mx = distance_mx

        radii = module.tier_streaming_radii(tier)
        streaming_r = float(radii.get("streaming", 1.0))
        unload_r = float(radii.get("unload", max(2.0, streaming_r * 1.5)))
        active_hlod, active_lod = _runtime_ladder(
            module, streaming_r, unload_r, settings, tier in eligible_tiers
        )
        distance = module.distance_to_aabb(
            (source_pos.x, source_pos.y, source_pos.z),
            distance_aabb,
        )
        state = module.classify_runtime_representation(distance, unload_r, active_hlod, active_lod)
        stats[state] += 1
        boxes.append((mn, mx, _runtime_color(state)))

    for obj in shared_objects:
        mn_v, mx_v = aabbs[obj.name]
        boxes.append(((mn_v.x, mn_v.y, mn_v.z), (mx_v.x, mx_v.y, mx_v.z), _runtime_color("shared")))

    stats["profile"] = resolved_profile
    return boxes, stats


# ── Operators ─────────────────────────────────────────────────────────────────

class UNTOLD_OT_preview_tiles(bpy.types.Operator):
    bl_idname  = "untold.preview_tiles"
    bl_label   = "Preview Tiles"
    bl_description = (
        "Draw a colour-coded tile grid in the 3D viewport. "
        "Green = low density, red = high density, blue = shared bucket"
    )
    bl_options = {"REGISTER"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        global _tile_boxes, _preview_object_names, _preview_color_mode

        # Always clear any existing overlay first so a failed or empty preview
        # never leaves stale boxes from a previous run visible.
        _clear_preview_state()
        _tag_viewports_redraw(context)

        settings = context.scene.untold_tile_preview
        objects  = _collect_objects(context, settings.visible_only)

        if not objects:
            self.report({'WARNING'}, "No mesh objects found for the selected scope")
            return {'CANCELLED'}

        aabbs = _compute_aabbs(objects, context)
        mode  = settings.partitioning_mode

        try:
            if mode == 'UNIFORM':
                boxes, stats = _build_uniform_boxes(objects, aabbs, settings)
            elif mode == 'QUADTREE':
                boxes, stats = _build_tree_boxes(objects, aabbs, settings, use_kdtree=False)
            else:  # KDTREE
                boxes, stats = _build_tree_boxes(objects, aabbs, settings, use_kdtree=True)
        except Exception as exc:
            self.report({'ERROR'}, f"Preview failed: {exc}")
            return {'CANCELLED'}

        if not boxes:
            self.report({'WARNING'}, "No tile assignments computed — check settings")
            return {'CANCELLED'}

        _tile_boxes = boxes
        _preview_color_mode = "DENSITY"
        _preview_object_names = {obj.name for obj in objects}
        _rebuild_draw_batches()
        _register_draw_handler()
        _tag_viewports_redraw(context)

        mode_label = {"UNIFORM": "uniform grid", "QUADTREE": "quadtree", "KDTREE": "KD-tree"}[mode]
        extra = ""
        if mode == 'UNIFORM' and settings.auto_tile_size:
            extra = f" | auto tile {stats['tile_x']:.1f}×{stats['tile_z']:.1f}"
        elif mode != 'UNIFORM':
            extra = f" | {stats['nodes']} spatial nodes"
        unit_label = "tiles" if mode == 'UNIFORM' else "tile-tier pairs"
        avg_label = "obj/tile" if mode == 'UNIFORM' else "obj/pair"
        self.report(
            {'INFO'},
            f"Tile preview ({mode_label}): {stats['tiles']} {unit_label} | "
            f"{stats['shared']} shared | avg {stats['avg']:.1f} {avg_label} | "
            f"max {stats['max']}{extra}"
        )
        return {'FINISHED'}


class UNTOLD_OT_preview_runtime_bands(bpy.types.Operator):
    bl_idname = "untold.preview_runtime_bands"
    bl_label = "Preview Runtime Bands"
    bl_description = "Color tiles by the representation active at the selected distance source"
    bl_options = {"REGISTER"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        global _tile_boxes, _preview_object_names, _preview_color_mode

        _clear_preview_state()
        _tag_viewports_redraw(context)

        settings = context.scene.untold_tile_preview
        source_pos, source_label = _distance_source_position(context, settings)
        if source_pos is None:
            self.report({'WARNING'}, f"No {source_label.lower()} available for runtime preview")
            return {'CANCELLED'}

        objects = _collect_objects(context, settings.visible_only)
        if not objects:
            self.report({'WARNING'}, "No mesh objects found for the selected scope")
            return {'CANCELLED'}

        aabbs = _compute_aabbs(objects, context)
        mode = settings.partitioning_mode

        try:
            if mode == 'UNIFORM':
                boxes, stats = _build_uniform_runtime_boxes(objects, aabbs, settings, source_pos)
            elif mode == 'QUADTREE':
                boxes, stats = _build_tree_runtime_boxes(
                    objects, aabbs, settings, source_pos, use_kdtree=False
                )
            else:
                boxes, stats = _build_tree_runtime_boxes(
                    objects, aabbs, settings, source_pos, use_kdtree=True
                )
        except Exception as exc:
            self.report({'ERROR'}, f"Runtime preview failed: {exc}")
            return {'CANCELLED'}

        if not boxes:
            self.report({'WARNING'}, "No runtime bands computed — check settings")
            return {'CANCELLED'}

        _tile_boxes = boxes
        _preview_color_mode = "RUNTIME"
        _preview_object_names = {obj.name for obj in objects}
        _rebuild_draw_batches()
        _register_draw_handler()
        _tag_viewports_redraw(context)

        profile = f" | profile {stats['profile']}" if stats.get("profile") else ""
        self.report(
            {'INFO'},
            f"Runtime bands from {source_label}: full {stats['full']} | LOD {stats['lod']} | "
            f"HLOD {stats['hlod']} | unloaded {stats['unloaded']} | shared {stats['shared']}{profile}"
        )
        return {'FINISHED'}


class UNTOLD_OT_clear_tile_preview(bpy.types.Operator):
    bl_idname  = "untold.clear_tile_preview"
    bl_label   = "Clear"
    bl_description = "Remove the tile grid overlay from the viewport"
    bl_options = {"REGISTER"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        _clear_preview_state()
        _tag_viewports_redraw(context)
        self.report({'INFO'}, "Tile preview cleared")
        return {'FINISHED'}


class UNTOLD_OT_preview_lod_plan(bpy.types.Operator):
    bl_idname = "untold.preview_lod_plan"
    bl_label = "Preview LOD Plan"
    bl_description = "Report tile-level LOD/HLOD payloads that tiled export will generate"
    bl_options = {"REGISTER"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        settings = context.scene.untold_tile_preview
        objects = _collect_objects(context, settings.visible_only)
        if not objects:
            self.report({'WARNING'}, "No mesh objects found for the selected scope")
            return {'CANCELLED'}

        aabbs = _compute_aabbs(objects, context)
        try:
            plan = _build_lod_plan(objects, aabbs, settings)
        except Exception as exc:
            self.report({'ERROR'}, f"LOD plan failed: {exc}")
            return {'CANCELLED'}

        if not plan.get("enabled"):
            self.report({'WARNING'}, "Enable Generate HLOD or Generate LOD first")
            return {'CANCELLED'}

        total_assets = plan["hlod_assets"] + plan["lod_assets"]
        hlod_switches = [l["switch_distance"] for l in plan["hlod_levels"]]
        lod_switches = [l["switch_distance"] for l in plan["lod_levels"]]
        tier_summary = ""
        if plan["by_tier"]:
            tier_summary = " | " + ", ".join(
                f"{tier}:{count}" for tier, count in sorted(plan["by_tier"].items())
            )
        self.report(
            {'INFO'},
            f"LOD plan: {total_assets} payloads for {plan['eligible_groups']} eligible groups "
            f"({plan['skipped_groups']} skipped) | profile {plan['profile']} | "
            f"HLOD {hlod_switches} | LOD {lod_switches}{tier_summary}"
        )
        return {'FINISHED'}


class UNTOLD_OT_meshes_to_bounds(bpy.types.Operator):
    bl_idname = "untold.meshes_to_bounds"
    bl_label = "Set Meshes To Bounds"
    bl_description = "Draw scene meshes as viewport bounding boxes while keeping them exportable"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        objects = _viewport_utility_meshes(context)
        if not objects:
            self.report({'WARNING'}, "No mesh objects found")
            return {'CANCELLED'}

        _remember_mesh_view_state(context, objects)
        for obj in objects:
            obj.display_type = 'BOUNDS'
            obj.hide_viewport = False
            obj.hide_set(False, view_layer=context.view_layer)

        _tag_viewports_redraw(context)
        self.report({'INFO'}, f"Set {len(objects)} mesh objects to bounds display")
        return {'FINISHED'}


class UNTOLD_OT_hide_meshes_for_preview(bpy.types.Operator):
    bl_idname = "untold.hide_meshes_for_preview"
    bl_label = "Hide Meshes"
    bl_description = "Hide scene meshes in the viewport so the tile overlay can be inspected"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        objects = _viewport_utility_meshes(context)
        if not objects:
            self.report({'WARNING'}, "No mesh objects found")
            return {'CANCELLED'}

        _remember_mesh_view_state(context, objects)
        for obj in objects:
            obj.hide_set(True, view_layer=context.view_layer)

        _tag_viewports_redraw(context)
        self.report(
            {'INFO'},
            f"Hid {len(objects)} mesh objects in the viewport. Restore before rerunning with Visible Objects Only."
        )
        return {'FINISHED'}


class UNTOLD_OT_restore_mesh_display(bpy.types.Operator):
    bl_idname = "untold.restore_mesh_display"
    bl_label = "Restore Mesh Display"
    bl_description = "Restore mesh display and viewport hide states saved by the tile preview utilities"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context: bpy.types.Context) -> set[str]:
        global _mesh_view_state

        if not _mesh_view_state:
            self.report({'WARNING'}, "No saved mesh display state to restore")
            return {'CANCELLED'}

        restored = 0
        view_layer = context.view_layer
        for name, state in list(_mesh_view_state.items()):
            obj = bpy.data.objects.get(name)
            if obj is None:
                continue
            obj.display_type = state["display_type"]
            obj.hide_viewport = state["hide_viewport"]
            obj.hide_set(state["hide_get"], view_layer=view_layer)
            restored += 1

        _mesh_view_state = {}
        _tag_viewports_redraw(context)
        self.report({'INFO'}, f"Restored viewport display for {restored} mesh objects")
        return {'FINISHED'}


# ── Sidebar panel ─────────────────────────────────────────────────────────────

class UNTOLD_PT_tile_preview(bpy.types.Panel):
    bl_label      = "Tile Preview"
    bl_idname     = "UNTOLD_PT_tile_preview"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category   = 'Untold'

    def draw(self, context: bpy.types.Context) -> None:
        layout   = self.layout
        settings = context.scene.untold_tile_preview
        mode     = settings.partitioning_mode

        layout.prop(settings, "partitioning_mode")
        layout.prop(settings, "visible_only")
        layout.separator(factor=0.5)

        if mode == 'UNIFORM':
            col = layout.column(align=True)
            col.label(text="Grid")
            col.prop(settings, "auto_tile_size")
            sub = col.column(align=True)
            sub.enabled = not settings.auto_tile_size
            sub.prop(settings, "tile_size_x")
            sub.prop(settings, "tile_size_z")
            col.prop(settings, "spanning_threshold")
        else:
            col = layout.column(align=True)
            col.label(text="Floor detection")
            col.prop(settings, "floor_count")
            col.prop(settings, "floor_band_height")
            col.label(text="(0 = auto-detect)", icon='INFO')

        layout.separator()
        col = layout.column(align=True)
        col.label(text="LOD")
        col.prop(settings, "scene_profile")
        col.prop(settings, "generate_hlod")
        col.prop(settings, "generate_lod")
        col.operator("untold.preview_lod_plan", icon='MOD_DECIM', text="Preview LOD Plan")

        layout.separator()
        col = layout.column(align=True)
        col.label(text="Runtime")
        col.prop(settings, "runtime_source")
        col.operator("untold.preview_runtime_bands", icon='VIEW_CAMERA', text="Preview Runtime Bands")

        layout.separator()
        col = layout.column(align=True)
        col.label(text="Viewport")
        col.operator("untold.meshes_to_bounds", icon='MESH_CUBE', text="Set Meshes To Bounds")
        row = col.row(align=True)
        row.operator("untold.hide_meshes_for_preview", icon='HIDE_ON', text="Hide Meshes")
        row.operator("untold.restore_mesh_display", icon='FILE_REFRESH', text="Restore")

        layout.separator()

        row = layout.row(align=True)
        row.operator("untold.preview_tiles", icon='OVERLAY', text="Preview Tiles")
        row.operator("untold.clear_tile_preview", icon='X', text="")

        if _tile_boxes:
            layout.separator(factor=0.5)
            box = layout.box()
            col = box.column(align=True)
            col.scale_y = 0.8
            if _preview_color_mode == "RUNTIME":
                col.label(text="Runtime")
                col.label(text="  Green  -  full tile")
                col.label(text="  Orange  -  LOD")
                col.label(text="  Cyan  -  HLOD")
                col.label(text="  Gray  -  unloaded")
                col.label(text="  Blue  -  shared bucket")
            else:
                col.label(text="Density")
                col.label(text="  Green  -  low")
                col.label(text="  Yellow  -  medium")
                col.label(text="  Red  -  high")
                col.label(text="  Blue  -  shared bucket")


# ── Registration ──────────────────────────────────────────────────────────────

classes = (
    UntoldTilePreviewSettings,
    UNTOLD_PT_tile_preview,
    UNTOLD_OT_preview_tiles,
    UNTOLD_OT_clear_tile_preview,
    UNTOLD_OT_preview_lod_plan,
    UNTOLD_OT_preview_runtime_bands,
    UNTOLD_OT_meshes_to_bounds,
    UNTOLD_OT_hide_meshes_for_preview,
    UNTOLD_OT_restore_mesh_display,
)


def register() -> None:
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.untold_tile_preview = bpy.props.PointerProperty(
        type=UntoldTilePreviewSettings
    )
    _register_app_handlers()


def unregister() -> None:
    _unregister_app_handlers()
    _clear_preview_state()
    del bpy.types.Scene.untold_tile_preview
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
