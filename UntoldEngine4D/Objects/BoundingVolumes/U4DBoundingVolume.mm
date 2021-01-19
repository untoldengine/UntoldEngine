//
//  U4DBoundingVolume.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DBoundingVolume.h"
#include "U4DCamera.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include <float.h>
#include "U4DRenderGeometry.h"

namespace U4DEngine {
    
    
    U4DBoundingVolume::U4DBoundingVolume():visibility(false){
        
        renderEntity=new U4DRenderGeometry(this);
        
        renderEntity->makePassPipelinePair(U4DEngine::finalPass, "geometrypipeline");
        
    }
    
    
    U4DBoundingVolume::~U4DBoundingVolume(){
        
        delete renderEntity;
        
    }
    
    
    U4DBoundingVolume::U4DBoundingVolume(const U4DBoundingVolume& value){};
    
    
    U4DBoundingVolume& U4DBoundingVolume::operator=(const U4DBoundingVolume& value){
        
        return *this;
        
    };
    
    void U4DBoundingVolume::loadRenderingInformation(){

        renderEntity->loadRenderingInformation();
    }

    void U4DBoundingVolume::updateRenderingInformation(){
        
        renderEntity->updateRenderingInformation();
    }

    void U4DBoundingVolume::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (visibility==true) {
            renderEntity->render(uRenderEncoder);
        }
        
    }
    
    void U4DBoundingVolume::setLineColor(U4DVector4n &lineColor){
        
        renderEntity->setGeometryLineColor(lineColor);
    }
    
    void U4DBoundingVolume::setVisibility(bool uValue){
        
        visibility=uValue;
        
    }
    
    bool U4DBoundingVolume::getVisibility(){
        
        return visibility;
    }

}
