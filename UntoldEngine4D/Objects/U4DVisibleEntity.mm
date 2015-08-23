//
//  U4DVisibleEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DVisibleEntity.h"

namespace U4DEngine {
    
void U4DVisibleEntity::loadRenderingInformation(){
    openGlManager->loadRenderingInformation();
}

void U4DVisibleEntity::addCustomUniform(const char* uName,std::vector<float> uData){
    
    CustomUniforms customUniform;
    
    customUniform.name=uName;
    customUniform.data=uData;
    
    openGlManager->addCustomUniforms(customUniform);
    
}

void U4DVisibleEntity::addCustomUniform(const char* uName,U4DVector3n uData){
    
    //create the vector
    std::vector<float> data{uData.getX(),uData.getY(),uData.getZ()};

    
    addCustomUniform(uName, data);

}

void U4DVisibleEntity::addCustomUniform(const char* uName,U4DVector4n uData){
    
    //create the vector
    std::vector<float> data{uData.getX(),uData.getY(),uData.getZ(),uData.getW()};
    
    addCustomUniform(uName, data);
    
}


void U4DVisibleEntity::updateUniforms(const char* uName,std::vector<float> uData){
    
    openGlManager->updateCustomUniforms(uName, uData);
    
}

void U4DVisibleEntity::updateUniforms(const char* uName,U4DVector3n uData){
    
    //create the vector
    std::vector<float> data{uData.getX(),uData.getY(),uData.getZ()};
    
    updateUniforms(uName, data);
}

void U4DVisibleEntity::updateUniforms(const char* uName,U4DVector4n uData){
    
    //create the vector
    std::vector<float> data{uData.getX(),uData.getY(),uData.getZ(),uData.getW()};
    
    updateUniforms(uName, data);
}

}



