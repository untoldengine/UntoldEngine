//
//  U4DEulerMethod.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DEulerMethod__
#define __UntoldEngine__U4DEulerMethod__

#include <iostream>
#include "U4DIntegrator.h"

namespace U4DEngine {
    
class U4DEulerMethod:public U4DIntegrator{
    
public:
    
    U4DEulerMethod(){};
    ~U4DEulerMethod(){};
    void integrate(U4DDynamicModel *uModel, float dt);
    
};

}

#endif /* defined(__UntoldEngine__U4DEulerMethod__) */
