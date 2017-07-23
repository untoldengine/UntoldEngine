//
//  U4DBoundingVolume.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DBoundingVolume.h"
#include "U4DCamera.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include <float.h>
#include "U4DRenderGeometry.h"

namespace U4DEngine {
    
    
    U4DBoundingVolume::U4DBoundingVolume(){
        
        renderManager=new U4DRenderGeometry(this);
        setShader("vertexGeometryShader", "fragmentGeometryShader");
        
    };
    
    
    U4DBoundingVolume::~U4DBoundingVolume(){};
    
    
    U4DBoundingVolume::U4DBoundingVolume(const U4DBoundingVolume& value){};
    
    
    U4DBoundingVolume& U4DBoundingVolume::operator=(const U4DBoundingVolume& value){
        
        return *this;
        
    };
    
    void U4DBoundingVolume::loadRenderingInformation(){

        renderManager->loadRenderingInformation();
    }

    void U4DBoundingVolume::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
    }
    
    void U4DBoundingVolume::setLineColor(U4DVector4n &lineColor){
        
        renderManager->setGeometryLineColor(lineColor);
    }

}
