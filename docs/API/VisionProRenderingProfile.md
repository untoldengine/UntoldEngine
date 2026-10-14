# The Vision Pro Rendering Profile, As Measured

What a mixed-immersion frame on Apple Vision Pro needs to look like RealityKit's, and
what the headset actually hands the engine. Everything here was measured on the device in
October 2026 (visionOS 26, display cadence 90, 96 or 100 Hz) with a dartboard and a
calibration panel shown by both renderers in the same room, and is kept so the numbers do
not have to be found twice. The viewer app that produced them is UntoldArcade's viewer.

## The profile

The settings a mixed-immersion space wants, with the calls that set them:

| Setting | Value | Why |
| --- | --- | --- |
| Render path | `setRendering(.renderPath(.forward))` | The geometry lights itself once per fragment; matches RealityKit's cost on the headset. Deferred and hybrid stay for many lights, projected decals and the G-buffer effects. |
| Anti-aliasing | `.msaaTaa`, 4 samples | Multisampled geometry with the temporal resolve on top; the foveation makes the periphery coarse, and the resolve hides it. |
| Foveation | on (the compositor's rasterization rate maps) | The frame draws at the display's own resolution only where the eyes look. |
| Tone map | `setPostFX(.tonemapOperator(.none))` | RealityKit applies no curve below white in a mixed space; a filmic curve compresses whites and lifts blacks against the room. |
| Primaries | `setPostFX(.colorPrimaries(.displayP3))` | RealityKit shows sRGB-specified colour with the display's P3 primaries; the look pass applies the P3→sRGB matrix after the grade to do the same. |
| Lighting | real-world estimate, contribution 1 | ARKit's environment probe, prefiltered on the device, lights the scene as the room does. |
| Light transition | `lightingSmoothingTimeConstant` 3 s | A new estimate fades in instead of switching the light's direction and colour in one frame. |
| Sun | off | The room's light is the probe's; a sun over it doubles the key light. |
| Occlusion culling | on, camera step 0.5 | The depth pyramid is built only for a frame whose depth could hide something. |
| Texture budget | 1536 MB | Under the default 200 MB the streaming shed tiers of a 4K object under the wearer's eyes. |

A full-immersion space is different: no passthrough to match, so a tone map (ACES or AgX)
is right again, the room light makes no sense, and the primaries are a taste.

## Rendered on a Mac, shown on the headset

A remote immersive space, where the Mac renders through Compositor Services and the headset
shows the frames, splits the table in two:

- **Presentation follows the display.** The frame is still composited on the headset next
  to the same passthrough, so the no tone map, the P3 primaries, the premultiplied alpha and
  the room light from the probe stay exactly the headset's values, whichever machine renders.
- **Budget follows the renderer.** The render path, the anti-aliasing and its samples, the
  shadow taps, the texture budget, the LOD distances and the tile light stage are the Mac's
  to raise: full shadow taps, more samples, deferred with many lights if the game wants it.
  Foveation depends on whether the remote layer hands the Mac the headset's rate maps; if it
  does not, render uniformly at the quality the Mac affords.
- **What the Mac does not buy back.** The cadence is still the headset's, so every frame
  must still be delivered on time or the compositor repeats one; and the link adds latency,
  which makes posing animation for the frame's presentation time matter more, not less.

Whether the environment probe and the rate maps reach a remote renderer has not been tested.
In a profile system this is a third entry: the mixed-immersion presentation with the Mac's
budget.

## How RealityKit shows a mixed-immersion scene

Measured on a panel of swatches that both renderers built from the same numbers (two grey
rows and two colour rows, one row through RealityKit's post-process tone map and one with
`applyPostProcessToneMap: false`, and a white, a black and a chrome sphere):

- **No curve below white.** RealityKit's tone-mapped row and its exact row read the same
  in a room: greys 0, 23, 49, 73, 111, 147, 196, 246 of 255 for inputs 0, 0.1, 0.2, 0.3,
  0.45, 0.6, 0.8 and 1. The engine with `.none` reads the same within two counts.
- **P3 primaries.** Its colours are the Display P3 → sRGB matrix of their sRGB values: a
  board red of (0.72, 0.13, 0.11) shows as (192, 0, 8), the board's cream (0.93, 0.85, 0.62)
  as (231, 207, 145). With `.displayP3` the engine reads the same values to the count. The
  system's colour pipeline is Display P3 (WWDC24 session 10092); an sRGB-format layer is
  converted and keeps its colour, which is why the matrix is needed to match.
- **Sunlight is RealityKit's own adaptation.** In a sunlit train its panel went part
  transparent (dark greys lifted by the passthrough), its exact row fell back to plain sRGB,
  its tone-mapped row gained a curve and its white sphere read half as bright. None of that
  is a target; the match above holds in rooms, which is where a game is played.

## The room probe

- ARKit's `EnvironmentProbeAnchor` hands over an `rgba16Float` cube of **8×8 texels a face
  with 4 mips**, and a `cameraScaleReference`. The engine's intensity scale is the reference
  over 1000, calibrated against RealityKit lighting the same object: 2350 in a dim room,
  8200 to 11400 in a restaurant, 14000 to 22000 in a sunlit train. The engine's ambient
  intensity (0.4 by default) multiplies it.
- **Estimates arrive in a burst** of two or three when the provider starts and then not at
  all in a still room; in a moving train, seven in thirty seconds. The engine keeps the
  newest estimate pending until the prefilter in flight finishes (the second of the burst is
  the better one) and fades towards it over the transition time constant, re-prefiltering a
  blended cube every 0.1 s, about a millisecond of GPU a step.
- **The maps are convolved, not sampled.** Importance sampling an eight-texel probe with
  128 samples a texel left the irradiance map with the structure of the sample set: with a
  window's light in one texel, a white sphere showed ridges and spirals. The irradiance now
  comes from the probe's first nine spherical harmonics over a fixed quadrature of 1024
  directions, the rougher specular mips (roughness 0.25 and up) from the same directions
  weighted by the GGX lobe; the sharper mips keep importance sampling.
- **The prefilter's frame.** The maps are read with a y-up equirect lookup and were written
  in a z-pole frame; the two compose to a fixed turn of the axes, applied to the cube's
  sample direction. Without it the ceiling lit the left of a sphere and what was behind the
  wearer lit its underside. `XRProbeOrientationTests` holds it.
- **What RealityKit does that we do not get.** Its chrome reflects a sharp, legible room;
  ours reflects the eight-texel probe. The source of its reflections is not exposed.

## Measuring

- **Captures.** The headset's direct captures come through as sRGB-tagged images whose
  greys read 0.96 of the value shown (246 for white); the saturated colours are converted
  correctly. A screenshot taken inside the headset of two captures shown in Photos is not
  comparable: it de-widens the saturated colours by exactly the matrix. Compare renderers
  within one capture, made the same way, and read patch means, not single pixels.
- **The calibration panel** is the instrument: greys at 0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.8, 1;
  pure red, green and blue, the board's cream (0.93, 0.85, 0.62), red (0.72, 0.13, 0.11) and
  green (0.16, 0.50, 0.28), a yellow (1, 0.85, 0.2) and a salmon (0.9, 0.6, 0.5); a white
  rough sphere, a black one (0.03) and a chrome one; a backing of 0.35. On the engine side
  every swatch is an emissive black metal (no diffuse, no reflection, the colour as given).
- **A pass** logs the frame's GPU time with and without the object, the frame rate against
  the cadence, the frame's CPU phases, the GPU time per pass, the probe's scale and reference,
  publishes and per-face light, dark frames, and the look state (render path, primaries, tone
  map, encode) when the space opens.

## What the device does

The dartboard (744 draws, 741k triangles, 4K textures) on the forward path with `.msaaTaa`
and foveation: 10.3 to 10.7 ms of GPU a frame, of which the empty frame is 4.0 to 4.7 and
the object 6.3 to 7.5; 94 of 100 Hz, 90 of 90. The frame's CPU: loop 10.5 ms, the game
update 1.0, the wait for the compositor's optimal input time 6.2 to 6.4, the encode 3.1 to
3.6. Passes: forward 7.0 (vertex 2.0, fragment 5.0), temporal resolve 2.1, depth pyramid
1.6, shadows 0.6, post 0.5. Dark frames: none to one in a thirty-second pass. A debug build
measures the compiler, not the engine: the headset numbers only mean something with
`-O` and the engine stats enabled.

## Motion

A smooth path judders on the headset for two reasons that a keyframe system would not
cure: the game update runs before the loop's wait for the compositor, so an object posed
from the wall clock belongs to an instant a varying 6 to 7 ms behind the frame's
presentation time (the head is posed for the presentation time; objects should be too), and
a dropped frame makes the compositor repeat an image, after which an animation driven by
accumulated deltas takes a double step. The fix is to hand the frame's predicted
presentation time to the game and sample every animation at it.

## Pitfalls met on the way

- The culling's compute read the entity list and the frustum of a frame two slots old: an
  object leaving the list made the next one vanish for a frame.
- A test that hides a scene channel's render mode and does not restore it leaves every later
  render test drawing nothing; the mode is global.
- `thread` is a Metal keyword; a kernel parameter cannot be called that.
- The pinch ray of a spatial event follows the gaze, not the hand: an object that rides it
  does not move sideways with the hand. RealityKit's drag is the hand's displacement, one to
  one on every axis.
- The viewer's Controls window placed the object thirty degrees to the right to stay out of
  its own way, which read as a placement bug; a measurement pass placed it straight ahead.
