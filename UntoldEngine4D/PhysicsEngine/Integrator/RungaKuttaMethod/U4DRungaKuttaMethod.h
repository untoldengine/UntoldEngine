//
//  U4DRungaKuttaMethod.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DRungaKuttaMethod__
#define __UntoldEngine__U4DRungaKuttaMethod__

#include <iostream>
#include "U4DIntegrator.h"

namespace U4DEngine {
    
class U4DRungaKuttaMethod:public U4DIntegrator{
    
public:
    
    U4DRungaKuttaMethod(){};
    
    ~U4DRungaKuttaMethod(){};
    
    void integrate(U4DDynamicModel *uModel, float dt);
    
    void evaluateLinearAspect(U4DDynamicModel *uModel,U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew);
    
    void evaluateAngularAspect(U4DDynamicModel *uModel,U4DVector3n &uAngularAcceleration,float dt,U4DVector3n &uAngularVelocityNew,U4DQuaternion &uOrientationNew);
};

}

#endif /* defined(__UntoldEngine__U4DRungaKuttaMethod__) */
