//
//  U4DMaterialData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DMaterialData__
#define __UntoldEngine__U4DMaterialData__

#include <iostream>
#include <vector>
#include "U4DColorData.h"

namespace U4DEngine {
    
class U4DMaterialData{
    
    private:
        
    public:
        U4DMaterialData(){};
        ~U4DMaterialData(){};
        
        std::vector<U4DColorData> diffuseMaterialColorContainer;
        std::vector<U4DColorData> specularMaterialColorContainer;
        std::vector<float> diffuseMaterialIntensityContainer;
        std::vector<float> specularMaterialIntensityContainer;
        std::vector<float> materialIndexColorContainer;
        
        void addDiffuseMaterialDataToContainer(U4DColorData& uData);
        void addSpecularMaterialDataToContainer(U4DColorData& uData);
        void addDiffuseIntensityMaterialDataToContainer(float &uData);
        void addSpecularIntensityMaterialDataToContainer(float &uData);
        void addMaterialIndexDataToContainer(float &uData);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DMaterialData__) */
