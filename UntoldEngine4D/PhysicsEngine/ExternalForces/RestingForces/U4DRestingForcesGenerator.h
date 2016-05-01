//
//  U4DRestingForces.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DRestingForcesGenerator_hpp
#define U4DRestingForcesGenerator_hpp

#include <stdio.h>
#include "U4DBodyForceGenerator.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    class U4DRestingForcesGenerator:public U4DBodyForceGenerator{
        
    private:
        
    public:
        
        U4DRestingForcesGenerator();
        
        ~U4DRestingForcesGenerator();
        
        void updateForce(U4DDynamicModel *uModel, float dt){};
        
        void updateForce(U4DDynamicModel *uModel, U4DVector3n& uGravity, float dt);
        
        void generateNormalForce(U4DDynamicModel *uModel, U4DVector3n& uGravity);
        
        void generateTorqueForce(U4DDynamicModel *uModel, U4DVector3n& uGravity);
        
    };
}

#endif /* U4DRestingForces_hpp */
