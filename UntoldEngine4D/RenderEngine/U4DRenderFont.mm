//
//  U4DRenderFont.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DRenderFont.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DRenderFont::U4DRenderFont(U4DImage *uU4DImage):U4DEngine::U4DRenderImage(uU4DImage){
        
        u4dObject=uU4DImage;
    }
    
    U4DRenderFont::~U4DRenderFont(){
        
    }
    
    void U4DRenderFont::updateRenderingInformation(){
        
        alignedAttributeData();
        
        memcpy(attributeBuffer.contents, (void*)&attributeAlignedContainer[0], sizeof(AttributeAlignedImageData)*attributeAlignedContainer.size());
        
        memcpy(indicesBuffer.contents, (void*)&u4dObject->bodyCoordinates.indexContainer[0], sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size());
        
        clearModelAttributeData();
        
    }
    
    void U4DRenderFont::modifyRenderingInformation(){
        
        alignedAttributeData();
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedImageData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        clearModelAttributeData();
        
    }
    
    void U4DRenderFont::setTextDimension(U4DVector3n &uFontPositionOffset, U4DVector2n &uFontUV, int uTextCount, float uTextWidth,float uTextHeight, float uAtlasWidth,float uAtlasHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        float widthFontTexture=uTextWidth/uAtlasWidth;
        float heightFontTexture=uTextHeight/uAtlasHeight;
        
        float width=uTextWidth/director->getDisplayWidth();
        float height=uTextHeight/director->getDisplayHeight();
        float depth=0.0;
        
        
        //vertices
        U4DVector3n v1(width,height,depth);
        U4DVector3n v4(width,-height,depth);
        U4DVector3n v2(-width,-height,depth);
        U4DVector3n v3(-width,height,depth);
        
        v1+=uFontPositionOffset;
        v2+=uFontPositionOffset;
        v3+=uFontPositionOffset;
        v4+=uFontPositionOffset;
        
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v1);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v4);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v2);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v3);
        
        //texture
        U4DVector2n t4(0.0,0.0);  //top left
        U4DVector2n t1(1.0*widthFontTexture,0.0);  //top right
        U4DVector2n t3(0.0,1.0*heightFontTexture);  //bottom left
        U4DVector2n t2(1.0*widthFontTexture,1.0*heightFontTexture);  //bottom right
        
        t4+=uFontUV;
        t1+=uFontUV;
        t3+=uFontUV;
        t2+=uFontUV;
        
        u4dObject->bodyCoordinates.addUVDataToContainer(t1);
        u4dObject->bodyCoordinates.addUVDataToContainer(t2);
        u4dObject->bodyCoordinates.addUVDataToContainer(t3);
        u4dObject->bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        
        i1.x=i1.x+4*uTextCount;
        i1.y=i1.y+4*uTextCount;
        i1.z=i1.z+4*uTextCount;
        
        i2.x=i2.x+4*uTextCount;
        i2.y=i2.y+4*uTextCount;
        i2.z=i2.z+4*uTextCount;
        
        //index
        u4dObject->bodyCoordinates.addIndexDataToContainer(i1);
        u4dObject->bodyCoordinates.addIndexDataToContainer(i2);
        
        
    }
    
    
    void U4DRenderFont::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            //diffuse texture
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
        
            
        }
        
    }
    
    
    void U4DRenderFont::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
        u4dObject->bodyCoordinates.indexContainer.clear();
    }
    
}
