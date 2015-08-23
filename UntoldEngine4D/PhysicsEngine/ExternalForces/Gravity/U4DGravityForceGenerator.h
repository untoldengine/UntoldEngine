//
//  GravityForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DGravityForceGenerator__
#define __UntoldEngine__U4DGravityForceGenerator__

#include <iostream>
#include "U4DEntityManager.h"
#include "U4DBodyForceGenerator.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
class U4DGravityForceGenerator:public U4DBodyForceGenerator{
  
private:
    
    U4DVector3n gravity;
    
public:
    
    U4DGravityForceGenerator();
    
    ~U4DGravityForceGenerator();
    
    void updateForce(U4DDynamicModel *uModel, float dt);
    
    void setGravity(U4DVector3n& uGravity);
    
    U4DVector3n getGravity();
    
    
};
    
}

#endif /* defined(__UntoldEngine__GravityForceGenerator__) */
