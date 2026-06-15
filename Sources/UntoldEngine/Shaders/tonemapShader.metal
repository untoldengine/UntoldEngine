//
//  tonemapShader.metal
//  UntoldEngineRTX
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
using namespace metal;
#import "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

vertex VertexCompositeOutput vertexTonemappingShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentTonemappingShader(VertexCompositeOutput vertexOut [[stage_in]],
                                    texture2d<float> baseColor [[texture(toneMapPassColorTextureIndex)]],
                                    constant int &toneMapOperator[[buffer((toneMapPassToneMappingIndex))]],
                                          constant float &exposure[[buffer(toneMapPassExposureIndex)]],
                                          constant float &gamma[[buffer(toneMapPassGammaIndex)]]){

    constexpr sampler s(min_filter::nearest, mag_filter::nearest); // Use for base color and normal maps

    float4 color=baseColor.sample(s, vertexOut.uvCoords);

    color.rgb *= exposure;
    
    if(toneMapOperator==1){
        // Apply Uncharted2 Tone Mapping
        color.rgb = filmicToneMapping(color.rgb);

    } else if(toneMapOperator==2){

        // Apply Reinhard Tone Mapping
        color.rgb = reinhardToneMapping(color.rgb);

    } else{
        
        // Apply ACES Filmic Tone Mapping
        color.rgb = ACESFilmicToneMapping(color.rgb);
    }
    
    float alpha = color.a;
    color.rgb = pow(color.rgb, float3(1.0/gamma));
    color.a = alpha;
    
    return color;

}
