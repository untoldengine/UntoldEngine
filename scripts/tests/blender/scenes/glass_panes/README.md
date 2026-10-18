# The glass reference scene

Six panes of glass in front of a striped wall, each with a solid object behind
it, under one of the engine's HDR environments. It is the scene behind the
comparison image of #1308 (glass transmission), and the setup for a golden
image of glass: Blender's render of it and the engine's drawing of the cooked
file show the same view.

The scene is generated, so a change to it is a change to `make_scene.py`.

## What is in it

- Six panes, 1.4 × 1.7 m and 2 cm thick, 1.7 m apart, each a Principled BSDF
  with the values of a kind of glass seen in architectural and vehicle models
  (base color, roughness, transmission, IOR): clear window glass
  (0.911/0.966/0.96, 0.04, 1, 1.46), solar control glass (0.34/0.48/0.53, 0.08,
  0.92, 1.48), channel glass (0.911/0.966/0.96, 0.25, 1, 1.46), a car window
  (0.22/0.30/0.31, 0.06, 0.96, 1.46), a red lens (0.8/0.05/0.02, 0.1, 1, 1.5)
  and black tempered glass (0/0/0, 0, 1, 1.45).
- Behind each pane a sphere or a cube, white, orange or blue.
- A wall of 24 colored stripes 3 m behind the panes, from a texture the script
  generates and packs into the file, so the exporter carries it, and a grey
  floor.
- The camera of the reference view: at (−1.6, −8.2, 1.7) looking at
  (0.1, 0.6, 0.95), vertical field of view 40°.

## Generate it

From the repo root:

```sh
blender --background --factory-startup --python scripts/tests/blender/scenes/glass_panes/make_scene.py -- out/glass_panes.blend
```

## Render the Blender reference

```sh
blender --background out/glass_panes.blend --python scripts/tests/blender/scenes/glass_panes/render_reference.py -- out
```

Cycles, 256 samples, denoised, the Standard view transform, 1920 × 1080 at
50 %. The world is the engine's `teatro_massimo_2k.hdr` (another file can be
given as a second argument) rotated 90° about Z, because the engine reads the
centre of a panorama along its forward axis and Blender along −X; it is the
only light. Writes `out/glass_blender.png` and `out/view.json`, the camera in
engine coordinates. Set `GLASS_SAMPLES=8` for a quick look.

## Cook it and draw it in the engine

```sh
untoldengine export --input out/glass_panes.blend --output out/glass_panes.untold --convert-orientation
```

(or `scripts/export-untold` with the same arguments from the repo root). The
file holds several objects, so the cook writes a `.untoldpack` beside the
`.untold` output. Load the pack, set the environment to the same HDR, and place
the camera from `view.json`: `eye`, `target` and `fov` are in the engine's
coordinates, with the conversion the exporter applied (`--convert-orientation`,
source orientation `blender-native`).

## What to expect

- The exporter writes the black tempered pane as a solid surface: next to
  nothing would show through it. The export log says so.
- The channel glass pane differs from Blender on purpose: Blender blurs what
  is behind rough glass, the engine blurs nothing and shows part of it sharp
  while the rest of the pane glows with the light from behind.
- The other four panes match Blender in tint, reflections and what shows
  through, within the differences of a path tracer and a rasterizer.
