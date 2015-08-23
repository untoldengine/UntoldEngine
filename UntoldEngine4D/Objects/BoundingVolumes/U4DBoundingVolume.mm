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
#import <GLKit/GLKit.h>

namespace U4DEngine {
    
void U4DBoundingVolume::setGeometry(){

    openGlManager->loadRenderingInformation();
}

void U4DBoundingVolume::draw(){
 
    openGlManager->draw();
}

void U4DBoundingVolume::setGeometryColor(U4DVector4n& uColor){
    
    updateUniforms("Color", uColor);
    
}

void U4DBoundingVolume::setBoundingType(BOUNDINGTYPE uType){
    
    boundingType=uType;
}

BOUNDINGTYPE U4DBoundingVolume::getBoundingType(){
    
    return boundingType;
}

}