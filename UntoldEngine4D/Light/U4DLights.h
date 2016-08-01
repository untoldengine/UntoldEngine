//
//  U4DLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DLights__
#define __UntoldEngine__U4DLights__

#include <iostream>
#include "U4DEntity.h"
#include "U4DVisibleEntity.h"
#include "U4DVertexData.h"


namespace U4DEngine {
    class U4DLights:public U4DVisibleEntity{
        
        private:

            int index;
            
            
        public:
            
            U4DLights();
            
            ~U4DLights();
            
            void draw();
            
            void setLightSphere(float uRadius,int uRings, int uSectors);
            
            U4DVertexData bodyCoordinates;
        
            std::vector<float> lightColor; //the color the light emits
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DLights__) */
