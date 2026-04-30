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

fragment float4 fragmentLookShader(
  VertexCompositeOutput in [[stage_in]],
  texture2d<float> sceneTexture [[texture(0)]],
  constant float &brightness [[buffer(colorGradingPassBrightnessIndex)]],
  constant float &contrast [[buffer(colorGradingPassContrastIndex)]],
  constant float &saturation [[buffer(colorGradingPassSaturationIndex)]],
  constant float &exposure [[buffer(colorGradingPassExposureIndex)]],
  constant float3 &whiteBalanceCoeffs [[buffer(colorGradingWhiteBalanceCoeffsIndex)]],
  constant bool &enabled [[buffer(colorGradingPassEnabledIndex)]]
) {
  constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);
  float4 sceneSample = sceneTexture.sample(s, in.uvCoords);
  float3 color = sceneSample.rgb;

  if (enabled) {
      color *= exposure;
      color = whiteBalance(color, whiteBalanceCoeffs);
      color = colorContrast(color, contrast);
      color *= (1.0 + brightness);
      color = colorSaturation(color, saturation);
  }

  // Tone map ONCE, here.
  color = ACESFilmicToneMapping(max(color, 0.0));
  return float4(color, sceneSample.a);
}

