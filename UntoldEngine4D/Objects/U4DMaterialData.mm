//
//  U4DMaterialData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#include "U4DMaterialData.h"

namespace U4DEngine {
    
    U4DMaterialData::U4DMaterialData(){}
    
    U4DMaterialData::~U4DMaterialData(){}
    
    void U4DMaterialData::addDiffuseMaterialDataToContainer(U4DColorData& uData){
        
        diffuseMaterialColorContainer.push_back(uData);
    }
    
    void U4DMaterialData::addSpecularMaterialDataToContainer(U4DColorData& uData){
        
        specularMaterialColorContainer.push_back(uData);
        
    }
    
    void U4DMaterialData::addDiffuseIntensityMaterialDataToContainer(float &uData){
        diffuseMaterialIntensityContainer.push_back(uData);
    }
    
    void U4DMaterialData::addSpecularIntensityMaterialDataToContainer(float &uData){
        specularMaterialIntensityContainer.push_back(uData);
    }
    
    void U4DMaterialData::addSpecularHardnessMaterialDataToContainer(float &uData){
        specularMaterialHardnessContainer.push_back(uData);
    }
    
    void U4DMaterialData::addMaterialIndexDataToContainer(float &uData){
        materialIndexColorContainer.push_back(uData);
    }
    
}
