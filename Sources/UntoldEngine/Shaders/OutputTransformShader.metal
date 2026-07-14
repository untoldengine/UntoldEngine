//
//  OutputTransformShader.metal
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
using namespace metal;

inline float3 linearToSRGB(float3 x) {
  float3 lo = x * 12.92;
  float3 hi = 1.055 * pow(max(x, 0.0), float3(1.0 / 2.4)) - 0.055;
  return select(lo, hi, x > 0.0031308);
}

vertex VertexCompositeOutput vertexOutputTransformShader(VertexCompositeIn in [[stage_in]]) {
  VertexCompositeOutput out;
  out.position = float4(float3(in.position), 1.0);
  out.uvCoords = in.uvCoords;
  return out;
}

struct OutputTransformFragmentOut {
  float4 color [[color(0)]];
  float depth [[depth(any)]];
};

fragment OutputTransformFragmentOut fragmentOutputTransformShader(
  VertexCompositeOutput in [[stage_in]],
  texture2d<float> lookTexture [[texture(0)]],
  depth2d<float> sourceDepthTexture [[texture(1)]],
  constant int &encodingMode [[buffer(outputTransformPassEncodingModeIndex)]]
) {
  constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);
  constexpr sampler depthSampler(min_filter::nearest, mag_filter::nearest, address::clamp_to_edge);

  float4 c = lookTexture.sample(s, in.uvCoords);
  c.rgb = max(c.rgb, 0.0);

  if (encodingMode == 1) {
      c.rgb = linearToSRGB(c.rgb);
  }

  float depth = sourceDepthTexture.sample(depthSampler, in.uvCoords);

  OutputTransformFragmentOut out;
  out.color = c;
  // Reverse-Z: sky pixels carry the clear value 0.0 = infinite distance. The
  // visionOS compositor reprojects using view distance (near/depth), so exactly
  // 0.0 divides to infinity and those pixels are discarded (rendered black).
  // Clamp to a finite far depth (~1km) that is visually indistinguishable from
  // infinity but valid for the compositor's reprojection.
  out.depth = max(depth, 1e-4);
  return out;
}
