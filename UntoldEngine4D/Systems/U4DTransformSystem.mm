//
//  TransformSystem.cpp
//  UntoldEnginePro
//
//  Created by Harold Serrano on 3/5/23.
//

#include "U4DTransformSystem.h"
#include "U4DMathUtils.h"
#include "U4DCamera.h"
#include "U4DLight.h"
#include "U4DComponents.h"
#include "U4DShaderProtocols.h"

extern U4DEngine::U4DCamera camera;
extern U4DEngine::U4DLight light;
extern U4DEngine::RendererInfo renderInfo;

namespace U4DEngine {

void translateTo(EntityID entityId, simd_float3 uPosition){
    
    Transform *transform=scene.Get<Transform>(entityId);
    
    transform->localSpace.columns[3]=simd::float4{uPosition.x, uPosition.y, uPosition.z, 1.0};
}

void translateBy(EntityID entityId, simd_float3 uPosition){
    Transform *transform=scene.Get<Transform>(entityId);
    
    transform->localSpace.columns[3][0]+=uPosition.x;
    transform->localSpace.columns[3][1]+=uPosition.y;
    transform->localSpace.columns[3][2]+=uPosition.z;
    
}

void rotateTo(EntityID entityId, float uAngle, simd_float3 uAxis){
    
    Transform *transform=scene.Get<Transform>(entityId);
    
    matrix_float3x3 m=matrix3x3_rotation(radians_from_degrees(uAngle), uAxis);
    
    transform->localSpace.columns[0].xyz=m.columns[0];
    transform->localSpace.columns[1].xyz=m.columns[1];
    transform->localSpace.columns[2].xyz=m.columns[2];
}

void rotateBy(EntityID entityId, float uAngle, simd_float3 uAxis){
    
    Transform *transform=scene.Get<Transform>(entityId);
    
    matrix_float3x3 m=matrix3x3_rotation(radians_from_degrees(uAngle), uAxis);
    
    matrix_float3x3 previousOrientation=(matrix_float3x3){
        {
            {transform->localSpace.columns[0].xyz},
            {transform->localSpace.columns[1].xyz},
            {transform->localSpace.columns[2].xyz}
        }
    };
    
    m=matrix_multiply(m, previousOrientation);
    
    transform->localSpace.columns[0].xyz=m.columns[0];
    transform->localSpace.columns[1].xyz=m.columns[1];
    transform->localSpace.columns[2].xyz=m.columns[2];
}

void scaleBy(EntityID entityId, float uScale){
    Transform *transform=scene.Get<Transform>(entityId);
    matrix_float4x4 s=matrix4x4_scale(uScale, uScale, uScale);
    
    transform->localSpace=matrix_multiply(s, transform->localSpace);
}

void scaleBy(EntityID entityId, float uX, float uY, float uZ){
    Transform *transform=scene.Get<Transform>(entityId);
    
    matrix_float4x4 s=matrix4x4_scale(uX, uY, uZ);
    
    transform->localSpace=matrix_multiply(s, transform->localSpace);
}

void updateVoxelSpace(){
    
    for(EntityID ent:U4DSceneView<Transform,Voxel>(scene)){
        
        Transform *pTransform=scene.Get<Transform>(ent);
        
        if(pTransform->uniformSpace==nullptr){
            //set uniform space
            pTransform->uniformSpace=[renderInfo.device newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        }
        
        UniformSpace uniforms;
        simd_float4x4 viewMatrix=camera.viewSpace;
        matrix_float4x4 modelMatrix = pTransform->localSpace;
        matrix_float4x4 inverseViewMatrix=simd_inverse(viewMatrix);
        matrix_float4x4 normalMatrix=simd_transpose(inverseViewMatrix);
        
        uniforms.projectionSpace = renderInfo.projectionMatrix;
        uniforms.modelViewSpace = matrix_multiply(viewMatrix, modelMatrix);
        uniforms.viewSpace=viewMatrix;
        uniforms.normalSpace=normalMatrix;
        uniforms.modelSpace=modelMatrix;
        
        memcpy(pTransform->uniformSpace.contents, (void*)&uniforms, sizeof(UniformSpace));
        
    }
}

void updateModelUniformBuffer(){
/*
    for(EntityID ent:U4DSceneView<Transform>(scene)){
        
        Transform *pTransform=scene.Get<Transform>(ent);
        
        if(pTransform->uniformSpace==nullptr){
            //set uniform space
            pTransform->uniformSpace=[director.device newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        }
        
        //update uniform
        UniformSpace uniforms;
        simd_float4x4 viewMatrix=camera.viewSpace;
        
        matrix_float4x4 modelMatrix = pTransform->localSpace;
        
        //this section is necessary since the coordinate system of Blender is different than that of Metal
        modelMatrix=simd_mul(pTransform->modelerTransform,modelMatrix);
        
        float y=modelMatrix.columns[3].y;
        float z=modelMatrix.columns[3].z;
        float temp=y;
        y=-z;
        z=temp;
        
        modelMatrix.columns[3].y=y;
        modelMatrix.columns[3].z=z;
        
        
        matrix_float3x3 normalMatrix=matrix3x3_upper_left(viewMatrix);
        normalMatrix=matrix_inverse_transpose(normalMatrix);
        uniforms.modelSpace=modelMatrix;
        uniforms.projectionSpace = director.projectionMatrix;
        uniforms.modelViewSpace = matrix_multiply(viewMatrix, modelMatrix);
        uniforms.normalSpace=normalMatrix;
        uniforms.viewSpace=viewMatrix;
        memcpy(pTransform->uniformSpace.contents, (void*)&uniforms, sizeof(UniformSpace));
        
    }
    */
}

}
