//
//  U4DRenderWorld.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderWorld.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DRenderWorld::U4DRenderWorld(U4DWorld *uU4DWorld){
        
        u4dObject=uU4DWorld;
    }
    
    U4DRenderWorld::~U4DRenderWorld(){
        
    }
    
    U4DDualQuaternion U4DRenderWorld::getEntitySpace(){
        
        return u4dObject->getLocalSpace();
        
    }
    
    
    bool U4DRenderWorld::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            eligibleToRender=false;
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedWorldData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderWorld::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=getEntitySpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n worldSpace(1,0,0,0,
                               0,1,0,0,
                               0,0,1,0,
                               0,0,0,1);
        
        //YOU NEED TO MODIFY THIS SO THAT IT USES THE U4DCAMERA Position
        U4DEngine::U4DMatrix4n viewSpace=camera->getLocalSpace().transformDualQuaternionToMatrix4n();
        //viewSpace.invert();
        
        U4DMatrix4n modelWorldSpace=worldSpace*modelSpace;
        
        U4DMatrix4n modelWorldViewSpace=viewSpace*modelWorldSpace;
        
        U4DMatrix4n perspectiveProjection=director->getPerspectiveSpace();
        
        //Note, the perspective projection space has to be inverted to create
        //the infinite grid
        perspectiveProjection.invert();
        
        U4DMatrix4n mvpSpace=perspectiveProjection*modelWorldViewSpace;
        
        U4DNumerical numerical;
        
        //matrix_float4x4 mvpSpaceSIMD=numerical.convertToSIMD(mvpSpace);
        matrix_float4x4 projectionSpaceSIMD=numerical.convertToSIMD(perspectiveProjection);
        matrix_float4x4 viewSpaceSIMD=numerical.convertToSIMD(viewSpace);
        
        UniformSpace uniformSpace;
        uniformSpace.projectionSpace=projectionSpaceSIMD;
        uniformSpace.viewSpace=viewSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderWorld::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:viSpaceBuffer];
            
            [uRenderEncoder setFragmentBuffer:uniformSpaceBuffer offset:0 atIndex:fiSpaceBuffer];
            
            [uRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
            
        }
        
    }
    
    void U4DRenderWorld::alignedAttributeData(){
        
        for(int i=0;i<u4dObject->bodyCoordinates.getVerticesDataFromContainer().size();i++){
            
            AttributeAlignedWorldData attributeAlignedData;
            
            attributeAlignedData.position.x=u4dObject->bodyCoordinates.verticesContainer.at(i).x;
            attributeAlignedData.position.y=u4dObject->bodyCoordinates.verticesContainer.at(i).y;
            attributeAlignedData.position.z=u4dObject->bodyCoordinates.verticesContainer.at(i).z;
            attributeAlignedData.position.w=1.0;
            
            attributeAlignedContainer.push_back(attributeAlignedData);
        }
        
        gridVertexCount=(int)u4dObject->bodyCoordinates.verticesContainer.size();
        
    }
    
    void U4DRenderWorld::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        
    }
    
}
