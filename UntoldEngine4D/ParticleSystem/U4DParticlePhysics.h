//
//  U4DParticlePhysics.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticlePhysics_hpp
#define U4DParticlePhysics_hpp

#include <stdio.h>
#include "U4DVector3n.h"

namespace U4DEngine {
    
    class U4DParticle;
    
}

namespace U4DEngine {

    class U4DParticlePhysics {
        
    private:
        
    public:
        
        U4DParticlePhysics();
        
        ~U4DParticlePhysics();
        
        void updateForce(U4DParticle *uParticle, U4DVector3n &uGravity, float dt);
        
        /**
         @brief Document this
         */
        void integrate(U4DParticle *uParticle, float dt);
        
        /**
         @brief Document this
         */
        void evaluateLinearAspect(U4DParticle *uModel, U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew);
        
    };
    
}


#endif /* U4DParticlePhysics_hpp */
