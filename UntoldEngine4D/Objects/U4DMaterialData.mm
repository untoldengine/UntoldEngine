//
//  U4DMaterialData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DMaterialData.h"

namespace U4DEngine {
    
void U4DMaterialData::addEmissionMaterialDataToContainer(float uData){
    
    emissionMaterialColorContainer.push_back(uData);
}

void U4DMaterialData::addDiffuseMaterialDataToContainer(float uData){
    
    diffuseMaterialColorContainer.push_back(uData);
}

void U4DMaterialData::addSpecularMaterialDataToContainer(float uData){
    
    specularMaterialColorContainer.push_back(uData);
    
}

void U4DMaterialData::addAmbientMaterialDataToContainer(float uData){
    
    ambientMaterialColorContainer.push_back(uData);
    
}

void U4DMaterialData::setShininessOfMaterial(float uData){
    
    shininessOfMaterial=uData;
}

}
