# Material Node Baking — Milestone Plan

## Problem

The exporter (`scripts/untoldexplorer.py`) extracts materials by finding the
Principled BSDF and tracing each socket backwards until it hits an Image
Texture. Only a small set of nodes is understood, and several of those (Mix,
Gamma, Hue/Saturation, curves) are *traced through* — the texture behind them
is found, but the node's math is dropped. Any material using Mix, Math, Map
Range, procedural textures, etc. therefore renders differently in the engine
than in Blender.

## Approach

Instead of teaching the engine (or the exporter) to evaluate arbitrary node
graphs, let Blender evaluate them at export time: for each material whose
graph contains unsupported nodes, use Cycles bake to render the final Base
Color, Roughness, Metallic, and Normal outputs into flat textures, then feed
those into the existing pipeline (`Textures/` directory → `texbake.py` ASTC
conversion → `.untold` reference patching).

Why baking, not a runtime shader-node system:

- **Outputs match by construction.** Blender computes the pixel values; there
  is no node-by-node reimplementation to keep in sync with Blender releases.
- **Zero engine/runtime cost.** The engine stays a fixed-input PBR
  uber-shader. Static batching and tile streaming depend on materials being
  uniform and batchable; arbitrary runtime shader graphs would fragment
  batches and blow up shader permutations.
- A runtime node system is a multi-month project (graph runtime or Metal
  codegen, permutation management, Blender→Untold node translation where many
  nodes do not map 1:1) and is only justified if procedural/animated
  materials become a product goal.

Known trade-offs:

- Baking requires a reasonable UV unwrap; procedural coordinates (Object /
  Generated) get frozen into UV space.
- Procedural detail becomes resolution-bound (bake resolution is
  configurable).
- View-dependent (Fresnel, Layer Weight) and time-dependent (drivers,
  keyframed node values) effects cannot be baked; these are detected and
  reported.
- A shader combined above the Principled BSDF (Mix Shader, Add Shader) is
  not baked — the channel recipes only wire individual Principled inputs
  into Emission and cannot reproduce shader-level blending. See Milestone 3.
- Baking is per mesh instance, not shared across objects using the same
  material, so a material reused across many objects produces one texture
  per object rather than one shared texture. See Milestone 3.
- Export gets slower for a material's first bake, but a persistent,
  content-addressed cache (Milestone 5) skips re-baking anything unchanged
  since the last export.

## Milestone 1 — Node-graph analysis & diagnostics (no behavior change)

Know exactly which materials diverge and why, before baking anything.

- Graph walker in `untoldexplorer.py` classifies each material:
  - `supported` — only nodes the exporter represents faithfully.
  - `bakeable` — static unsupported nodes (Mix, Math, Map Range, procedural
    textures, …) or traced-through nodes whose math is dropped. Export-time
    baking can capture these.
  - `unbakeable` — view-dependent nodes (Fresnel, Layer Weight, Camera Data,
    Light Path) or animated node values (drivers/keyframes). Baking cannot
    represent these.
- Per-material report at export time, including missing/collapsed UV maps
  (baking will need them).

**Done when:** exporting existing problem assets prints an accurate list of
which materials need baking and why.

## Milestone 2 — Base-color bake proof of concept

Validate visual parity before building the rest.

- Bake only base color (Cycles Diffuse pass, direct/indirect disabled) for
  `bakeable` materials, behind an opt-in flag (`--bake-materials`).
- Bake mechanics: temporary image + image-texture node per material, UV
  selection, margin/dilation, sRGB handling.
- Manual validation: side-by-side of Blender viewport vs engine render on
  real assets that currently mismatch.

**Done when:** a Mix-node base color renders identically in Blender and the
engine. **Go/no-go gate for the whole approach.**

## Milestone 3 — Full channel set

- All non-normal channels use the emit-rewire (exact, lighting-free);
  roughness and metallic are packed into one ORM-style image via a temporary
  Combine Color node (R=1, G=roughness, B=metallic) and referenced through
  the format's per-channel sourcing (`roughness_texture_channel` = G,
  `metallic_texture_channel` = B). Normal uses a tangent-space NORMAL bake
  with the original graph intact (Cycles self-bakes include bump/normal-map
  shading normals). Emissive bakes only when the material actually emits.
- Divergence is decided **per channel** (`material_bake_plan`): the walker is
  seeded from each Principled input socket, plus a walk of the surface chain
  stopping at the Principled. Channels with view-dependent findings are
  skipped with a warning; a clean channel on a divergent material is never
  baked.
- Divergence found *above* the Principled BSDF (a Mix Shader / Add Shader
  combining it with another shader) makes the **whole material** unbakeable,
  not "every channel": the channel recipes only wire individual Principled
  inputs into Emission, so they have no way to reproduce shader-level
  blending. Attempting to bake per channel in that case would silently
  discard the blend and produce a confidently wrong texture — worse than not
  baking. A real fix would need a different bake strategy entirely (e.g. a
  full "final appearance" bake of the combined surface) and is out of scope
  for now.
- Baking is scoped **per mesh instance**, not shared across every object
  using a material. Two objects sharing a material (e.g. many chairs using
  the same "Wood" material) each get their own baked texture. Sharing one
  texture across instances was tried first and rejected: overlapping UV
  layouts (very common for tiling materials reused across furniture) let one
  object's bake silently overwrite another's in the same image, and
  procedural/object-space nodes can legitimately evaluate differently per
  instance. The tradeoff is more textures and more bake time — no
  cross-object dedup in this version.
- The original node graph is restored after each channel bake, including on
  failure paths. The temp directory holding baked PNGs is owned by
  `bake_divergent_materials()` and removed by
  `cleanup_material_bake_temp_dir()` once `stage_nodes_for_output()` has
  copied them into the final `Textures/` folder.
- `--bake-resolution` is validated (rejects non-positive values, clamps
  above `MAX_BAKE_RESOLUTION`) in both the Python exporter and the Swift CLI.
- Gotcha: bpy node wrappers are transient — graph identity must use
  `as_pointer()`, not `id()`.

**Done when:** a torture-test .blend with nodes on every channel exports with
visual parity, *except* for the documented exclusions: shader-level mixing
above the Principled BSDF, view-dependent nodes (Fresnel, Layer Weight), and
animated/keyframed node values. Those are detected and either skipped with a
clear warning or left to the existing (already-analyzed-as-divergent)
fallback behavior — never silently mis-baked.

## Milestone 4 — Pipeline integration

- Baked PNGs land in `Textures/` with slot-detectable names so `texbake.py`
  and `.untold` reference patching work unchanged.
- Wired `--bake-materials`/`--bake-resolution` through `export-untold`
  (Milestones 2–3), `export-untold-tiles` (`tilestreamingpartition.py`), and
  the Blender addon (`bridge.py` + `__init__.py`, both the single-asset and
  tiled-scene operators). Naming stays distinct: *material bake* (node
  graphs → textures) vs *texture bake* (PNG → ASTC `.utex`).
- **Baking happens per-tile, after clipping — not "before tile partition."**
  Tile clipping (`clip_objects_to_tile`) already runs before
  `export_objects_to_untold()` is called for a given tile, so by the time
  baking sees the geometry it's already a tile-specific clipped fragment,
  not the pristine original object. This is intentional, not a shortcut:
  given per-instance baking (Milestone 3 hardening), baking a fragment's own
  clipped UV footprint is exactly as safe as baking any other mesh instance.
  The tradeoff is the one already documented for per-instance baking: a
  material spanning many tiles bakes once per tile fragment rather than
  once, shared. When `MERGE_BY_MATERIAL` joins several distinct source
  objects sharing a material into one mesh before export, that merged mesh
  is what gets baked as a single unit — correct, since a merge is a
  deliberate scene-authoring decision that already accounts for UV
  compatibility.
- **HLOD/LOD tiles are deliberately excluded from baking.** Both route
  through the same `export_hlod_tile()` wrapper in `tilestreamingpartition.py`
  and always pass `bake_materials=False` regardless of the CLI flag — they're
  decimated stand-ins for geometry already exported (and baked, if
  requested) at full detail; decimation changes UV layout/topology, so
  re-baking would duplicate work and risk a different-looking result.
- Parallel-worker config threading: `--parallel-workers` spawns separate
  Blender subprocesses that receive config via a JSON snapshot/restore
  (`_config_snapshot()`/`_apply_bundle_config()`), not shared Python state.
  `BAKE_MATERIALS`/`BAKE_RESOLUTION` are threaded through both — missing this
  would make the flag silently do nothing whenever a multi-tile export uses
  workers (the default), while appearing to work fine under
  `--parallel-workers 1`. Covered by a dedicated round-trip regression test.
- **Found and fixed a real Blender API bug while verifying this**:
  `scene_context()`'s `bpy.context.temp_override(scene=..., view_layer=...)`
  redirects `bpy.context.scene`/`view_layer` for plain data access, but not
  `bpy.context.window.scene` — and `bpy.ops.object.bake()` validates selected
  objects against the window's scene internally, not the overridden context
  attribute. Baking inside a per-tile temp-scene context therefore failed
  with `"Object '<unrelated object from the real window scene>' is not in
  view layer"` even though nothing from that scene was selected. Fixed by
  setting `window.scene`/`window.view_layer` as plain setup/teardown around
  the `temp_override` block, not nested inside it — mutating those
  attributes while a `temp_override` is already active on the context stack
  crashes Blender outright (verified empirically; this was the first code
  path in the pipeline to call an operator with real view-layer validation
  requirements from inside `scene_context()`).

**Done when:** one command takes a node-heavy .blend to a correct on-device
render on both the single-asset and tile-streaming paths. Verified end to
end on a synthetic 4-tile scene (`--parallel-workers 1`, matching the
addon's own fixed worker count): correct per-channel classification,
pixel-exact bakes, and correct per-tile-fragment texture references in each
`.untold` file.

## Milestone 5 — Performance & caching

- **Cache** (`MaterialBakeCache`): a persistent, content-addressed cache
  keyed by `(material node tree fingerprint, mesh UV fingerprint, object
  world-transform fingerprint, resolution, channel)`. Stored next to the
  source asset as `.untold_bake_cache_<name>/` (a manifest.json plus
  hash-named PNGs), not next to the export output — one source asset
  commonly exports to many output locations (repeated single-asset exports,
  every tile in a tiled scene) that should all share one cache. `--no-bake-cache`
  (CLI, tile pipeline, and addon) forces a fresh bake regardless.
  - The node-tree fingerprint hashes the *whole* tree (node types, unlinked
    input default values, **and output socket default values** — constant
    nodes like `ShaderNodeRGB`/`ShaderNodeValue` store their configured
    value on the output socket, not an input; missing this was a real bug
    caught during verification, where editing an RGB node's color didn't
    invalidate the cache) plus link topology, rather than just the subgraph
    feeding one channel. Simpler, and safe to over-invalidate rather than
    risk under-invalidating (serving a stale bake).
  - Including the object's own UV and transform fingerprints in the key
    means two objects sharing a material (per-instance baking, Milestone 3)
    get independent cache entries — no risk of the cache reintroducing the
    cross-object correctness bug that per-instance baking exists to prevent.
    Verified directly against the two-shared-instance test scene from
    Milestone 4: distinct cache misses on first bake, distinct cache hits
    on re-export, correct distinct pixel values preserved through the
    round trip.
- **Per-material resolution override**: a material's `["untold_bake_resolution"]`
  custom property overrides the global `--bake-resolution` default for that
  material only (validated/clamped the same way as the global flag).
  Verified two materials in one export baking at different resolutions
  (256 vs. the 1024 default) correctly.
- **Denoiser: deliberately not added.** Verified empirically that both
  bake types used (`EMIT` for base_color/orm/emissive, `NORMAL`) are
  already byte-identical across repeated bakes of the same noise-driven
  material at `samples=1` — there is no Monte Carlo noise to denoise,
  since emission of a deterministic node graph has nothing stochastic to
  sample. Adding a denoiser would be complexity with no measurable benefit
  for this architecture (and could blur genuine texture detail).

**Done when:** re-exporting an unchanged scene skips all bakes — verified:
byte-identical output textures between two consecutive exports of an
unchanged scene, and selective re-baking (4 hits / 1 miss) when exactly one
material was edited between exports, with the re-baked texture's pixel
values confirmed to reflect the new value, not stale data.

## Milestone 6 — UX, docs, and guardrails

- Addon UI: bake toggle, resolution picker (Milestone 4/5) — plus a new
  pre-export "Untold Materials" panel (`material_fidelity.py`, a 3D-viewport
  sidebar tab) listing every bakeable/unbakeable material with its specific
  offending node and reason, and any mesh missing a UV map. Reuses Milestone
  1's `analyze_material`/`compute_material_fidelity` — the panel shows
  exactly what `--bake-materials` would do, without exporting. Manually
  triggered (a "Scan Materials" button), not automatic, since re-analyzing
  the whole scene on every UI redraw would be wasteful.
- `compute_material_fidelity()` extracted from `material_fidelity_report_lines()`
  as a behavior-preserving refactor, so the console report and the addon
  panel share one analysis path instead of two.
- Docs: a new "Material Node Baking" section in
  `docs/API/UsingBlenderAddon.md` (supported nodes, UV requirements,
  limitations, the new panel, per-material resolution override, cache
  behavior) plus matching property documentation in
  `scripts/untold-blender-addon/README.md`, which had never listed the
  `bake_materials`/`bake_resolution`/`bake_cache` properties added in
  Milestones 4–5.

**Done when:** the documented workflow gets a node-heavy asset from Blender
to device with no engineer involvement. Verified: registered the addon in a
real headless Blender session, built a scene with one supported, two
bakeable, and one unbakeable material (one missing a UV map), ran the scan
operator, and confirmed the panel's backing state matches expectations
exactly — correct counts, correct per-material classification, correct UV
warning. Also verified clean unregister/re-register, matching the addon's
live-reload development workflow.

## Sequencing

Milestones 1–2 are deliberately small; Milestone 2's parity gate validates
the approach with minimal sunk cost. Milestones 5 and 6 can be reordered or
trimmed depending on whether this stays an internal tool or becomes a
user-facing feature.

## Status

- [x] Milestone 1 — analyzer + export-time report (`analyze_material`,
      `material_fidelity_report_lines` in `untoldexplorer.py`)
- [x] Milestone 2 — base-color emit-rewire bake behind `--bake-materials`;
      verified pixel-exact against computed expectations on a constant-mix
      material
- [x] Milestone 3 — per-channel bake plan (`material_bake_plan`) + ORM
      packing + tangent-space normal bake (`bake_divergent_materials`);
      ORM and emissive verified pixel-exact, normal verified to capture
      procedural bump. Post-review hardening: shader-level divergence above
      the Principled BSDF is now unbakeable (was silently mis-baked before);
      baking is scoped per mesh instance, not shared across objects using
      the same material (was a silent-corruption risk under overlapping
      UVs); the bake temp directory is now cleaned up after staging (was
      leaked); `--bake-resolution` is validated in both the CLI and
      exporter. Verified against a real Blender scene with a Mix Shader
      above the Principled BSDF (confirmed skipped, no texture produced)
      and two objects sharing one bakeable material with per-instance
      differing values (confirmed each object bakes independently and
      correctly, no cross-object overwrite).
- [x] Milestone 4 — wired `--bake-materials`/`--bake-resolution` through
      `export-untold-tiles`/`tilestreamingpartition.py` (base tile + shared
      bucket only, not HLOD/LOD) and both Blender addon export operators;
      fixed a real `scene_context()`/`bpy.ops.object.bake()` window-scene
      bug found during verification; parallel-worker config threading
      covered by a dedicated regression test; verified end-to-end on a
      synthetic 4-tile scene with pixel-exact bakes
- [x] Milestone 5 — persistent content-addressed bake cache
      (`MaterialBakeCache`) keyed by node-tree fingerprint (incl. output
      socket values — found and fixed a real bug where constant-value
      nodes like ShaderNodeRGB were invisible to the original inputs-only
      fingerprint) + mesh UV/transform fingerprint + resolution + channel;
      per-material `["untold_bake_resolution"]` override; `--no-bake-cache`
      escape hatch in the CLI, tile pipeline, and addon. Denoiser
      deliberately not added — verified both bake types are already
      byte-identical across repeated bakes (no Monte Carlo noise to
      denoise). Verified end-to-end: byte-identical unchanged re-export,
      surgical single-material invalidation with pixel-exact re-bake, and
      cache correctness preserved on the per-instance shared-material test
      scene from Milestone 4.
- [x] Milestone 6 — pre-export "Untold Materials" panel in the Blender
      addon (scan button + per-material bakeable/unbakeable list with
      reasons + UV warnings), built on a new `compute_material_fidelity()`
      shared with the console report; user-facing docs added to
      `docs/API/UsingBlenderAddon.md` and
      `scripts/untold-blender-addon/README.md`. Verified end-to-end via
      real addon registration in headless Blender.
