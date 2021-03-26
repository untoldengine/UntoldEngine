//
//  U4DPointLight.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPointLight_hpp
#define U4DPointLight_hpp

#include <stdio.h>
#include <vector>
#include "U4DEntity.h"

namespace U4DEngine{

    typedef struct{
        
        U4DVector3n position;
        U4DVector3n diffuseColor;
        U4DVector3n specularColor;
        float constantAttenuation;
        float linearAttenuation;
        float expAttenuation;
        float energy;
        float falloutDistance;
        
    }POINTLIGHT;

    class U4DPointLight: public U4DEntity{
        
    private:
        
        static U4DPointLight* instance;
        
    protected:
        
        U4DPointLight();
        
        ~U4DPointLight();
        
    public:
        
        
        static U4DPointLight* sharedInstance();
        
        std::vector<POINTLIGHT> pointLightsContainer;
        
        void addLight(U4DVector3n &uLightPosition, U4DVector3n &uDiffuseColor, float uConstantAtten, float uLinearAtten, float uExpAtten, float energy, float falloutDistance);
        
    };

}

#endif /* U4DPointLight_hpp */
