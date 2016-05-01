//
//  U4DDragForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DDragForceGenerator__
#define __UntoldEngine__U4DDragForceGenerator__

#include <iostream>
#include "U4DBodyForceGenerator.h"

namespace U4DEngine {
    
class U4DDragForceGenerator:public U4DBodyForceGenerator{
  
    private:

        //velocity drag coefficient
        float k1;
        
        //velocity squared drag coefficient
        float k2;
        
    public:
        
        U4DDragForceGenerator():k1(1.0),k2(0.9){};
        
        ~U4DDragForceGenerator(){};
        
        void updateForce(U4DDynamicModel *uModel, float dt);
        
        void updateForce(U4DDynamicModel *uModel, U4DVector3n& uGravity, float dt){};
        
        
    };

}

#endif /* defined(__UntoldEngine__U4DDragForceGenerator__) */
