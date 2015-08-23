//
//  U4DPointLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 1/3/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DPointLight__
#define __UntoldEngine__U4DPointLight__

#include <iostream>
#include "U4DLights.h"

namespace U4DEngine {
    
class U4DPointLight:public U4DLights{

private:
    
public:
    
    U4DPointLight(){};
    ~U4DPointLight(){};
    
    float intensityFalloffDistance;
    float linearAttenuation;
    float quadraticAttenuation;
    
};
    
}

#endif /* defined(__UntoldEngine__U4DPointLight__) */
