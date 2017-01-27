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

namespace U4DEngine {
    
    
    U4DBoundingVolume::U4DBoundingVolume(){
        
        openGlManager=new U4DOpenGLGeometry(this);
        openGlManager->setShader("geometricShader");
        
        U4DVector4n color(1.0,0.0,0.0,0.1);
        addCustomUniform("Color", color);
    };
    
    
    U4DBoundingVolume::~U4DBoundingVolume(){};
    
    
    U4DBoundingVolume::U4DBoundingVolume(const U4DBoundingVolume& value){};
    
    
    U4DBoundingVolume& U4DBoundingVolume::operator=(const U4DBoundingVolume& value){
        
        return *this;
        
    };
    
    void U4DBoundingVolume::loadRenderingInformation(){

        openGlManager->loadRenderingInformation();
    }

    void U4DBoundingVolume::draw(){
     
        openGlManager->draw();
    }

    void U4DBoundingVolume::setBoundingVolumeColor(U4DVector4n& uColor){
        
        updateUniforms("Color", uColor);
        
    }

}
