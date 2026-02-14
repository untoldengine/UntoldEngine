//
//  OutputTransformShader.metal
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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

fragment float4 fragmentOutputTransformShader(
  VertexCompositeOutput in [[stage_in]],
  texture2d<float> lookTexture [[texture(0)]],
  constant int &encodingMode [[buffer(outputTransformPassEncodingModeIndex)]]
) {
  constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);

  float4 c = lookTexture.sample(s, in.uvCoords);
  c.rgb = max(c.rgb, 0.0);

  if (encodingMode == 1) {
      c.rgb = linearToSRGB(c.rgb);
  }

  return c;
}

