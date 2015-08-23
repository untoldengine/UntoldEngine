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

namespace U4DEngine {
    
class U4DMaterialData{
    
private:
    
public:
    U4DMaterialData(){};
    ~U4DMaterialData(){};
    
    std::vector<float> emissionMaterialColorContainer;
    std::vector<float> diffuseMaterialColorContainer;
    std::vector<float> ambientMaterialColorContainer;
    std::vector<float> specularMaterialColorContainer;
    float shininessOfMaterial=0.0;
    
    void addEmissionMaterialDataToContainer(float uData);
    void addDiffuseMaterialDataToContainer(float uData);
    void addSpecularMaterialDataToContainer(float uData);
    void addAmbientMaterialDataToContainer(float uData);
    void setShininessOfMaterial(float uData);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DMaterialData__) */
