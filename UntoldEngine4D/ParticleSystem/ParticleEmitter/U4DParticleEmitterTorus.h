//
//  U4DParticleEmitterTorus.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterTorus_hpp
#define U4DParticleEmitterTorus_hpp

#include <stdio.h>
#include "U4DParticleEmitter.h"
#include "U4DParticleSystem.h"
#include "U4DParticle.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleEmitterTorus class creates and allocates memory for the Torus Emitter
     */
    class U4DParticleEmitterTorus:public U4DParticleEmitter {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleEmitterTorus();
        
        /**
         @brief class destructor
         */
        ~U4DParticleEmitterTorus();
        
        /**
         @brief computes the velocity of the particle
         
         @param uParticle pointer to the particle object
         */
        void computeVelocity(U4DParticle *uParticle);
        
    };
    
}
#endif /* U4DParticleEmitterTorus_hpp */
