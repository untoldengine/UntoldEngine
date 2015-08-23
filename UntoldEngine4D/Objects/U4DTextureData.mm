//
//  U4DTextureData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DTextureData.h"

namespace U4DEngine {
    
void U4DTextureData::setEmissionTexture(std::string uData){
    
    emissionTexture=uData;
}

void U4DTextureData::setDiffuseTexture(std::string uData){
    
    diffuseTexture=uData;
}

void U4DTextureData::setAmbientTexture(std::string uData){
    
    ambientTexture=uData;
}

void U4DTextureData::setSpecularTexture(std::string uData){
    
    specularTexture=uData;
}

void U4DTextureData::setNormalBumpTexture(std::string uData){
    
    normalBumpTexture=uData;
}

}