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
    float3 position [[attribute(envPassPositionIndex)]];
    float3 normals [[attribute(envPassNormalIndex)]];
    float2 texCoords [[attribute(envPassUVIndex)]];
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

struct VertexDebugOutput{
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

typedef struct{

    float4 position [[attribute(modelPassVerticesIndex)]];
    float4 normals [[attribute(modelPassNormalIndex)]];
    float2 uv [[attribute(modelPassUVIndex)]];
    float4 tangent [[attribute(modelPassTangentIndex)]];
    ushort4 jointIndices [[attribute(modelPassJointIdIndex)]];
    float4 jointWeights [[attribute(modelPassJointWeightsIndex)]];
    
    
}VertexInModel;

typedef struct{
    float4 position [[position]];
    float4 shadowCoords;
    float4 vPosition;
    float4 verticesInMVSpace;
    float3 normalVectorInMVSpace;
    float3 normal;
    float3 tbNormal; //used in tbn
    float4 tangent;
    float2 uvCoords;

  }VertexOutModel;

typedef struct{
    float4 position [[attribute(0)]];
}GeometryInModel;

typedef struct{
    float4 position [[position]];
}GeometryOutModel;

typedef struct{
    float3 position [[attribute(lightVisualPassPositionIndex)]];
    float2 uv [[attribute(lightVisualPassUVIndex)]];
}LightVisualInModel;

typedef struct{
    float4 position [[position]];
    float2 uvCoords;
}LightVisualOutModel;

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

typedef struct
{
    float4 color [[color(0)]];
    float4 normals [[color(1)]];
    float4 positions [[color(2)]];

} FragmentModelOut;

typedef struct{

    float4 position [[attribute(modelPassVerticesIndex)]];
    float4 normals [[attribute(modelPassNormalIndex)]];
    
}VertexInOutline;

typedef struct{
    float4 position [[position]];
    float3 normal;
}VertexOutOutline;

#endif /* ShaderStructs_h */
