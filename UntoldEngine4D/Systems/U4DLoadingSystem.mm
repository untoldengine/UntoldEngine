//
//  U4DLoadingSystem.cpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 4/8/23.
//

#include "U4DLoadingSystem.h"
#import <ModelIO/ModelIO.h>
#include "U4DShaderProtocols.h"
#include "U4DComponents.h"
#include "U4DMathUtils.h"
#include "U4DJsonReader.h"
#include "U4DUtilsFunctions.h"
#include <map>
#include <simd/simd.h>

extern U4DEngine::RendererInfo renderInfo;
extern U4DEngine::VoxelPool voxelPool;
extern unsigned long nextVoxelOffset;
extern std::map<std::string, U4DEngine::Voxel> voxelAssetMap;

float scale=0.1;

simd_float4 V0=simd_float4{-1.0,-1.0,1.0,1.0}*scale;
simd_float4 V1=simd_float4{1.0,-1.0,1.0,1.0}*scale;
simd_float4 V2=simd_float4{1.0,1.0,1.0,1.0}*scale;
simd_float4 V3=simd_float4{-1.0,1.0,1.0,1.0}*scale;

simd_float4 V4=simd_float4{-1.0,-1.0,-1.0,1.0}*scale;
simd_float4 V5=simd_float4{1.0,-1.0,-1.0,1.0}*scale;
simd_float4 V6=simd_float4{1.0,1.0,-1.0,1.0}*scale;
simd_float4 V7=simd_float4{-1.0,1.0,-1.0,1.0}*scale;

simd_float4 v0=V0;
simd_float4 v20=V0;
simd_float4 v19=V0;


simd_float4 v1=V1;
simd_float4 v4=V1;
simd_float4 v16=V1;

simd_float4 v2=V2;
simd_float4 v7=V2;
simd_float4 v8=V2;

simd_float4 v3=V3;
simd_float4 v11=V3;
simd_float4 v23=V3;

simd_float4 v15=V4;
simd_float4 v18=V4;
simd_float4 v21=V4;

simd_float4 v5=V5;
simd_float4 v12=V5;
simd_float4 v17=V5;

simd_float4 v6=V6;
simd_float4 v9=V6;
simd_float4 v13=V6;

simd_float4 v10=V7;
simd_float4 v14=V7;
simd_float4 v22=V7;

simd_float4 N0=simd_float4{0,0,1,1.0}; //front
simd_float4 N1=simd_float4{1,0,0,1.0}; //right
simd_float4 N2=simd_float4{0,1,0,1.0}; //top
simd_float4 N3=simd_float4{0,0,-1,1.0}; //back

simd_float4 N4=simd_float4{-1,0,0,1.0}; //left
simd_float4 N5=simd_float4{0,-1,0,1.0}; //bottom

float quadVertexData[] =
{
    0.5, -0.5, 0.0, 1.0,
    -0.5, -0.5, 0.0, 1.0,
    -0.5,  0.5, 0.0, 1.0,

    0.5,  0.5, 0.0, 1.0,
    0.5, -0.5, 0.0, 1.0,
    -0.5,  0.5, 0.0, 1.0
};

simd_float4 vertices[]={v0,v1,v2,v3, //front
                        v4,v5,v6,v7, //right
                        v8,v9,v10,v11, //top
                        v12,v13,v14,v15, //back
                        v20,v21,v22,v23, //left
                        v16,v17,v18,v19}; //bottom

simd_float4 normals[]={N0,N0,N0,N0, //front
                    N1,N1,N1,N1, //right
                    N2,N2,N2,N2, //top
                    N3,N3,N3,N3, //back
                    N4,N4,N4,N4, //left
                    N5,N5,N5,N5};  //bottom

uint16 indices[]={0,1,2,0,2,3, //front
                  4,5,6,4,6,7, //right
                  8,9,10,8,10,11, //top
                  15,14,13,15,13,12, //back
                  20,23,22,20,22,21, //left
                  19,18,17,19,17,16}; //bottom face

namespace U4DEngine {

bool loadAsset(EntityID entityId, std::string fileName, std::string assetName, std::string textureName){
    
//    Graphics *pGraphics=scene.Get<Graphics>(entityId);
//    Transform *pTransform=scene.Get<Transform>(entityId);
//    
//    if(pGraphics==nullptr || pTransform==nullptr) return false;
//    
//    
//    NSString* pathToFile = [NSString stringWithUTF8String:fileName.c_str()];
//    
//    NSString* pathFileName = [[pathToFile lastPathComponent] stringByDeletingPathExtension];
//    NSString* pathExtension = [pathToFile pathExtension];
//    
//    NSString *assetURL=[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@", pathFileName] ofType:pathExtension];
//    
//    NSURL *url=[NSURL fileURLWithPath:assetURL];
//    
//    //load assets into metal objects
//    NSError *error=nullptr;
//    
//    MTKMeshBufferAllocator *meshBufferAllocator=[[MTKMeshBufferAllocator alloc] initWithDevice: director.device];
//    
//    MDLVertexDescriptor *vertexDescriptor=MTKModelIOVertexDescriptorFromMetal(model3DPipeline.vertexDescriptor);
//    
//    vertexDescriptor.attributes[VertexAttributePosition].name=MDLVertexAttributePosition;
//    vertexDescriptor.attributes[VertexAttributeTexcoord].name=MDLVertexAttributeTextureCoordinate;
//    vertexDescriptor.attributes[VertexAttributeNormals].name=MDLVertexAttributeNormal;
//    
//    MDLAsset *asset=[[MDLAsset alloc] initWithURL:url vertexDescriptor:vertexDescriptor bufferAllocator:meshBufferAllocator];
//    
//    //check if the upAxis is up-this is necessary when loaing from Blender
//    simd_float3 upAxis=simd_float3{0.0,1.0,0.0};
//    MDLTransform *transform;
//    if(upAxis.y!=asset.upAxis.y){
//        
//        // The up axis is not the Y-axis, so we need to fix the orientation
//        simd_float4x4 rotation = matrix4x4_rotation(-M_PI / 2, simd_float3{1, 0, 0});
//        
//        transform = [[MDLTransform alloc] initWithMatrix:rotation];
//    
//        for(MDLMesh *mesh in [asset childObjectsOfClass:[MDLMesh class]]){
//            mesh.transform=transform;
//        }
//    }
//    
//    //get all models objects in the asset catalog
//    NSArray<MDLObject *> *mdlMeshes=[asset childObjectsOfClass:[MDLMesh class]];
//    
//    MDLMesh *model=nullptr;
//    
//    NSString* modelName = [NSString stringWithUTF8String:assetName.c_str()];
//    
//    for(MDLMesh *m in mdlMeshes){
//        if ([[m name] isEqualToString:modelName]) {
//            
//            model=m;
//            
//            break;
//        }
//    }
//    
//    //add normal data
//    [model addNormalsWithAttributeNamed:vertexDescriptor.attributes[VertexAttributeNormals].name creaseThreshold:0.4];
//    
//    //create the MTKMesh
//    pGraphics->mesh=[[MTKMesh alloc] initWithMesh:model device:director.device error:&error];
//    
//    if(!pGraphics->mesh || error){
//
//        std::string errorDesc= std::string([error.localizedDescription UTF8String]);
//        
//        printf("Error: The Model Mesh was unable to be created. %s",errorDesc.c_str());
//        
//        return false;
//    }
//    
//    assert(model.submeshes.count==pGraphics->mesh.submeshes.count);
//    
//    //load texture
//    NSString* pathTextureToFile = [NSString stringWithUTF8String:textureName.c_str()];
//    
//    NSString* pathTextureFileName = [[pathTextureToFile lastPathComponent] stringByDeletingPathExtension];
//    NSString* pathTextureExtension = [pathTextureToFile pathExtension];
//    
//    NSString* textureURLString = [[NSBundle mainBundle]
//                 pathForResource:[NSString stringWithFormat:@"%@", pathTextureFileName]
//                 ofType:pathTextureExtension];
//    
//    NSURL *textureURL = [NSURL fileURLWithPath:textureURLString];
//    pGraphics->texture=loadTextures(textureURL);
//    pTransform->modelerTransform=model.transform.matrix;
//    return true;
}

id<MTLTexture> loadTextures(NSURL *url){
    
    NSError *error;
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice: renderInfo.device];
    
    id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url options:nil error:&error];
    
    if(!texture)
    {
        NSLog(@"Error creating the texture from %@: %@", url.absoluteString, error.localizedDescription);
        return nil;
    }
    return texture;
}

void loadVoxelAsset(std::string filename){

    //read voxel json
    std::vector<VoxelData> voxelData=readVoxelFile(filename);
    
    //check if voxel data is already in the map
    auto found=voxelAssetMap.find(filename);
    
    if (found != voxelAssetMap.end()) {
        printf("Voxel asset found in map.");
        return;
    }
    
    //load voxel into gpu
    
    Voxel voxel;
    voxel.size=(unsigned int)voxelData.size();
    voxel.offset=nextVoxelOffset;
    
    voxelAssetMap.insert(std::make_pair(filename, voxel));
    
    for(int i=0;i<voxelData.size();i++){
        unsigned int guid=voxelData[i].guid;
        simd_float3 color=voxelData[i].color;
        simd_float3 material=voxelData[i].material;
        insertVoxelIntoGPU(guid, color, material);
    }
    
}

void insertVoxelIntoGPU(unsigned int uGuid, simd_float3 color, simd_float3 material){

    //determin the voxel coordinate, i.e. uGuid->(x,y,z)
    simd_uint3 voxelCoord=indexTo3DGridMap(uGuid, sizeOfChunk, sizeOfChunk, sizeOfChunk);

    simd_float4 voxelOrigin=simd_make_float4(float(voxelCoord.x), float(voxelCoord.y), float(voxelCoord.z),1.0f);
    voxelOrigin.x*=2.0*scale;
    voxelOrigin.y*=2.0*scale;
    voxelOrigin.z*=2.0*scale;
    
    //offset from untold engine editor
    float planeScale=sizeOfChunk*scale*2.0;
    simd_float3 modelOffset=simd_make_float3(-(planeScale/2.0 - scale),scale,-(planeScale/2.0 - scale));
    voxelOrigin.xyz+=modelOffset;
    
    simd_float4 newVertices[numOfVerticesPerBlock];

    for(int i=0;i<numOfVerticesPerBlock;i++){
        newVertices[i]=voxelOrigin+vertices[i];
        newVertices[i].w=1.0;
    }

    //set the indices

    uint16 newIndices[numOfIndicesPerBlock];

    for(int i=0;i<numOfIndicesPerBlock;i++){
        newIndices[i]=indices[i]+uint16(numOfVerticesPerBlock*nextVoxelOffset);
        
    }
    
    simd_float4 newColor[numOfVerticesPerBlock];
    
    for(int i=0;i<numOfVerticesPerBlock;i++){
        newColor[i]=simd_float4{color.r,color.g,color.b,1.0};
    }
    
    simd_float4 newMaterial[numOfIndicesPerBlock];
    
    for(int i=0;i<numOfVerticesPerBlock;i++){
        newMaterial[i]=simd_make_float4(material.r,material.g,material.b,1.0);
    }

    simd_float4 *targetOriginMemtory=(simd_float4*)voxelPool.originBuffer.contents;
    memcpy(targetOriginMemtory+nextVoxelOffset, &voxelOrigin, sizeof(simd_float4));
    
    simd_float4 *targetVertexMemory=(simd_float4*)voxelPool.vertexBuffer.contents;
    memcpy(targetVertexMemory+nextVoxelOffset*numOfVerticesPerBlock, &newVertices[0], sizeof(simd_float4)*numOfVerticesPerBlock);
    
    simd_float4 *targetNormalMemory=(simd_float4*)voxelPool.normalBuffer.contents;
    memcpy(targetNormalMemory+nextVoxelOffset*numOfVerticesPerBlock, &normals[0], sizeof(simd_float4)*numOfVerticesPerBlock);

    simd_float4 *targetColorMemory=(simd_float4*)voxelPool.colorBuffer.contents;
    memcpy(targetColorMemory+nextVoxelOffset*numOfVerticesPerBlock, &newColor[0], sizeof(simd_float4)*numOfVerticesPerBlock);
    
    simd_float4 *targetMaterialMemory=(simd_float4*)voxelPool.materialBuffer.contents;
    memcpy(targetMaterialMemory+nextVoxelOffset*numOfVerticesPerBlock, &newMaterial[0], sizeof(simd_float4)*numOfVerticesPerBlock);
    
    uint16* targetIndicesMemory=(uint16*)voxelPool.indicesBuffer.contents;
    memcpy(targetIndicesMemory+nextVoxelOffset*numOfIndicesPerBlock, &newIndices[0], sizeof(uint16)*numOfIndicesPerBlock);
    
    ++nextVoxelOffset;
}

void addVoxelsToEntity(EntityID entityId, std::string filename){
    Voxel voxel;
    
    loadVoxelAsset(filename);
    
    auto found=voxelAssetMap.find(filename);
    
    if (found != voxelAssetMap.end()) {
        voxel=found->second;
    } else {
        printf("Voxel asset not found in the map.");
        return;
    }
    
    Voxel *pVoxel=scene.Get<Voxel>(entityId);
    pVoxel->size=voxel.size;
    pVoxel->offset=voxel.offset;
    
}

}
