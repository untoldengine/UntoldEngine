//
//  U4DRenderPolygon.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/2/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderPolygon.h"

namespace U4DEngine{

U4DRenderPolygon::U4DRenderPolygon(U4DMesh *uU4DGeometricObject):U4DEngine::U4DRenderGeometry(uU4DGeometricObject),u4dObject(uU4DGeometricObject){
    
}

U4DRenderPolygon::~U4DRenderPolygon(){
    [uniformGeometryBuffer release];
    
    uniformGeometryBuffer=nil;
}

void U4DRenderPolygon::render(id <MTLRenderCommandEncoder> uRenderEncoder){
    
    if (eligibleToRender==true) {
    
        updateSpaceUniforms();
        
        //encode the buffers
        [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
        
        [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:viSpaceBuffer];
        
        [uRenderEncoder setFragmentBuffer:uniformGeometryBuffer offset:0 atIndex:fiGeometryBuffer];
        
        //set the draw command
        [uRenderEncoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:[attributeBuffer length]/sizeof(AttributeAlignedGeometryData)];
        
    }
}

}
