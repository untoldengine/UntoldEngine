//
//  U4DIntegrator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DIntegrator__
#define __UntoldEngine__U4DIntegrator__

#include <iostream>
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
class U4DIntegrator{
  
public:
    
    virtual void integrate(U4DEngine::U4DDynamicModel *uModel, float dt)=0;
    ~U4DIntegrator(){};
};

}

#endif /* defined(__UntoldEngine__U4DIntegrator__) */
