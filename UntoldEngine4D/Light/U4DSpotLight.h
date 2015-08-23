//
//  U4DSpotLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 1/3/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSpotLight__
#define __UntoldEngine__U4DSpotLight__

#include <iostream>
#include "U4DLights.h"

namespace U4DEngine {
    
class U4DSpotLight:public U4DLights{
    
private:
    
public:
    U4DSpotLight(){}
    ~U4DSpotLight(){}
    
    float spotSize;
};
}

#endif /* defined(__UntoldEngine__U4DSpotLight__) */
