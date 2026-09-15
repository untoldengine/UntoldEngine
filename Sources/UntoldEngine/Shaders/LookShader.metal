//
//  LookShader.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
using namespace metal;

vertex VertexCompositeOutput vertexLookShader(VertexCompositeIn in [[stage_in]]) {
  VertexCompositeOutput out;
  out.position = float4(float3(in.position), 1.0);
  out.uvCoords = in.uvCoords;
  return out;
}

// Samples a color-grading LUT strip baked from a Blender scene's View
// Transform/Look/Exposure/Gamma (see build_identity_lut_grid_pixels in
// scripts/untoldexplorer.py). The strip unwraps a lutSize^3 cube as lutSize
// tiles of lutSize x lutSize laid out side by side along the blue axis.
//
// Each grid sample n (0..lutSize-1) sits at texel center (n + 0.5) / lutSize,
// so hardware bilinear filtering correctly interpolates the red/green axes
// within one tile. It cannot blend across the blue-axis tile boundary, so
// that axis is interpolated manually: sample the two nearest tiles and mix.
inline float3 sampleColorLUT(
  float3 color,
  texture2d<float> lutTexture,
  float shaperMinStops,
  float shaperMaxStops,
  int lutSize
) {
  constexpr sampler lutSampler(min_filter::linear, mag_filter::linear, mip_filter::none, address::clamp_to_edge);

  // Inverse of the Python baker's shaper encode: log2 stops around 18% gray,
  // normalized to [0, 1] over the baked range.
  float3 stops = log2(max(color, 1e-6) / 0.18);
  float3 t = clamp((stops - shaperMinStops) / (shaperMaxStops - shaperMinStops), 0.0, 1.0);

  float lutSizeF = float(lutSize);
  float3 coord = t * (lutSizeF - 1.0);

  float blueLow = floor(coord.b);
  float blueFrac = coord.b - blueLow;
  float blueHigh = min(blueLow + 1.0, lutSizeF - 1.0);

  float atlasWidth = lutSizeF * lutSizeF;
  float v = (coord.g + 0.5) / lutSizeF;
  float uLow  = (blueLow  * lutSizeF + coord.r + 0.5) / atlasWidth;
  float uHigh = (blueHigh * lutSizeF + coord.r + 0.5) / atlasWidth;

  float3 sampleLow  = lutTexture.sample(lutSampler, float2(uLow, v)).rgb;
  float3 sampleHigh = lutTexture.sample(lutSampler, float2(uHigh, v)).rgb;
  return mix(sampleLow, sampleHigh, blueFrac);
}

// Samples an externally-authored standard .cube 3D LUT (see CubeLUTLoader.swift),
// applied as a post-tonemap creative grade. Unlike sampleColorLUT above (which
// bakes Blender's whole View Transform into a custom log2-stops shaper domain
// and replaces the tonemap step entirely), this operates on already-tonemapped,
// bounded [domainMin, domainMax] color and is a real 3D texture, so hardware
// trilinear filtering handles all three axes -- no manual blue-axis blend needed.
inline float3 sampleColorGradeLUT(
  float3 color,
  texture3d<float> gradeLUTTexture,
  float3 domainMin,
  float3 domainMax
) {
  constexpr sampler gradeLUTSampler(min_filter::linear, mag_filter::linear, mip_filter::none, address::clamp_to_edge);
  float3 range = max(domainMax - domainMin, 1e-6);
  float3 t = clamp((color - domainMin) / range, 0.0, 1.0);
  return gradeLUTTexture.sample(gradeLUTSampler, t).rgb;
}

fragment float4 fragmentLookShader(
  VertexCompositeOutput in [[stage_in]],
  texture2d<float> sceneTexture [[texture(0)]],
  texture2d<float> colorLUTTexture [[texture(lookPassColorLUTTextureIndex)]],
  texture3d<float> colorGradeLUTTexture [[texture(colorGradeLUTTextureIndex)]],
  constant float &brightness [[buffer(colorGradingPassBrightnessIndex)]],
  constant float &contrast [[buffer(colorGradingPassContrastIndex)]],
  constant float &saturation [[buffer(colorGradingPassSaturationIndex)]],
  constant float &exposure [[buffer(colorGradingPassExposureIndex)]],
  constant float3 &whiteBalanceCoeffs [[buffer(colorGradingWhiteBalanceCoeffsIndex)]],
  constant bool &enabled [[buffer(colorGradingPassEnabledIndex)]],
  constant bool &colorLUTEnabled [[buffer(colorLUTEnabledIndex)]],
  constant float &colorLUTShaperMinStops [[buffer(colorLUTShaperMinStopsIndex)]],
  constant float &colorLUTShaperMaxStops [[buffer(colorLUTShaperMaxStopsIndex)]],
  constant int &colorLUTSize [[buffer(colorLUTSizeIndex)]],
  constant bool &colorGradeLUTEnabled [[buffer(colorGradeLUTEnabledIndex)]],
  constant float3 &colorGradeLUTDomainMin [[buffer(colorGradeLUTDomainMinIndex)]],
  constant float3 &colorGradeLUTDomainMax [[buffer(colorGradeLUTDomainMaxIndex)]],
  constant int &tonemapOperator [[buffer(tonemapOperatorSelectIndex)]],
  texture2d<float> splatLayer [[texture(lookPassSplatCoverageTextureIndex)]],
  constant int &splatMask [[buffer(lookPassSplatMaskIndex)]],
  texture2d<float> gizmoTexture [[texture(lookPassGizmoTextureIndex)]],
  constant bool &gizmoOverrides [[buffer(lookPassGizmoOverrideIndex)]]
) {
  constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);
  float4 sceneSample = sceneTexture.sample(s, in.uvCoords);
  float3 color = sceneSample.rgb;
  // A Gaussian splat pixel is a finished photograph: blended in the capture's own
  // display-referred space and decoded to linear once in the pre-composite, it must reach the
  // output transform as it is — no grade, no tone map — or every capture is lifted and
  // flattened. The splat pass's layer (premultiplied, in the capture's space; bound when
  // splatMask is set) says how much of the pixel that is and what the splats put there. A
  // pixel the editor's gizmo overrode in the pre-composite holds no splats any more.
  float4 layer = float4(0.0);
  if (splatMask) {
      layer = splatLayer.sample(s, in.uvCoords);
      layer.a = saturate(layer.a);
      if (gizmoOverrides && getLuminance(gizmoTexture.sample(s, in.uvCoords).rgb) > 0.1) {
          layer = float4(0.0);
      }
  }
  const float splat = layer.a;
  if (splat >= 0.999) {
      return float4(sceneSample.rgb, sceneSample.a);
  }
  // Take the splats back out of a partly covered pixel: the composite is layer + (1 − a) ·
  // scene, so the scene behind the splats is what the grade and the tone map apply to, and the
  // layer goes back on top untouched. (Not a lerp between the graded and the raw composite:
  // that passes a · (1 − a) of the scene through un-tone-mapped, a bright fringe along every
  // splat silhouette over an HDR background.)
  float3 splatLinear = float3(0.0);
  if (splat > 0.0) {
      splatLinear = splatSRGBToLinear(layer.rgb / splat) * splat;
      color = max((sceneSample.rgb - splatLinear) / (1.0 - splat), 0.0);
  }

  if (enabled) {
      color *= exposure;
      color = whiteBalance(color, whiteBalanceCoeffs);
      color = colorContrast(color, contrast);
      color *= (1.0 + brightness);
      color = colorSaturation(color, saturation);
  }

  if (colorLUTEnabled) {
      // Replaces the tonemap step entirely: the baked LUT already contains
      // the source scene's full View Transform (including its own tonemap
      // curve), so applying ACES on top would double-compress the image.
      color = sampleColorLUT(max(color, 0.0), colorLUTTexture, colorLUTShaperMinStops, colorLUTShaperMaxStops, colorLUTSize);
  } else if (tonemapOperator == tonemapOperatorAgX) {
      // Tone map ONCE, here.
      color = agxToneMapping(max(color, 0.0));
  } else {
      // Tone map ONCE, here.
      color = ACESFilmicToneMapping(max(color, 0.0));
  }

  // Independent of the branch above: a .cube creative grade layers on top of
  // whichever tonemap just ran (native ACES, or the whole-transform bake).
  if (colorGradeLUTEnabled) {
      color = sampleColorGradeLUT(color, colorGradeLUTTexture, colorGradeLUTDomainMin, colorGradeLUTDomainMax);
  }

  return float4(splatLinear + color * (1.0 - splat), sceneSample.a);
}

