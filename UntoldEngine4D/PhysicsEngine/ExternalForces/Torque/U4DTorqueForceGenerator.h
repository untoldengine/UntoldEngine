//
//  U4DTorqueForceGenerator.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#ifndef U4DTorqueForceGenerator_hpp
#define U4DTorqueForceGenerator_hpp

#include <stdio.h>
#include "U4DBodyForceGenerator.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    class U4DTorqueForceGenerator:public U4DBodyForceGenerator{
        
    private:
        
        U4DVector3n torque;
        U4DVector3n gravity;
        
    public:
        
        U4DTorqueForceGenerator();
        
        ~U4DTorqueForceGenerator();
        
        void updateForce(U4DDynamicModel *uModel, float dt);
        
        void setTorque(U4DVector3n& uTorque);
        
        U4DVector3n getTorque();
        
        void setGravity(U4DVector3n& uGravity);
        
        U4DVector3n getGravity();
    };
    
}

#endif /* U4DTorqueForceGenerator_hpp */
