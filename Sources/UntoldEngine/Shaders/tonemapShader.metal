//
//  tonemapShader.metal
//  UntoldEngineRTX
//
//  Created by Harold Serrano on 4/1/24.
//

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
                                    constant int &toneMapOperator[[buffer((toneMapPassToneMappingIndex))]]){

    constexpr sampler s(min_filter::nearest, mag_filter::nearest); // Use for base color and normal maps

    float4 color=baseColor.sample(s, vertexOut.uvCoords);

    if(toneMapOperator==1){
        // Apply Uncharted2 Tone Mapping
        color.rgb = filmicToneMapping(color.rgb);

        return color;
    }

    if(toneMapOperator==2){

        // Apply Reinhard Tone Mapping
        color.rgb = reinhardToneMapping(color.rgb);

        return color;
    }

    // Apply ACES Filmic Tone Mapping
    color.rgb = ACESFilmicToneMapping(color.rgb);

    return color;



}
