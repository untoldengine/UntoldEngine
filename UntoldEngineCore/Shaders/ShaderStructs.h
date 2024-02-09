//
//  ShaderStructs.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/25/23.
//

#ifndef ShaderStructs_h
#define ShaderStructs_h

using namespace metal;

struct VertexEnvIn{
    float3 position [[attribute(0)]];
    float3 normals [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexEnvOut{

    float4 position [[position]];
    float3 normals;
    float2 texCoords;
};

struct VertexCompositeIn{
    float3 position [[attribute(0)]];
    float2 uvCoords [[attribute(1)]];
};

struct VertexCompositeOutput{
    float4 position [[position]];
    float2 uvCoords;
};

struct IBLFragmentOut{
    float4 irradiance [[color(0)]];
    float4 specular [[color(1)]];
    float4 brdfMap [[color(2)]];
};

typedef struct
{
    float3 position [[attribute(0)]];
    float3 normals [[attribute(1)]];
    float3 color [[attribute(2)]];
    float roughness [[attribute(3)]];
    float metallic [[attribute(4)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float4 color [[flat]];
    float4 vPosition;
    float4 verticesInMVSpace;
    float4 shadowCoords;
    float3 normalVectorInMVSpace;
    float3 normal [[flat]];
    float roughness;
    float metallic;
    float3 pColor;
} VertexOut;

typedef struct
{
    float3 position [[attribute(0)]];
} VertexFeedback;

typedef struct
{
    float4 position [[position]];
    
} VertexOutFeedback;

typedef struct
{
    float3 position [[attribute(0)]];
} VertexPlane;

typedef struct
{
    float4 position [[position]];
    
} VertexOutPlane;

typedef struct
{
    float4 albedo [[color(0)]];
    float4 normals [[color(1)]];
    float4 positions [[color(2)]];
} FragmentVoxelOut;

#endif /* ShaderStructs_h */
