//
//  U4DParticleEmitterSphere.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterSphere_hpp
#define U4DParticleEmitterSphere_hpp

#include <stdio.h>
#include "U4DParticleEmitter.h"
#include "U4DParticleSystem.h"
#include "U4DParticle.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleEmitterSphere class creates and allocates memory for the Sphereical Emitter
     */
    class U4DParticleEmitterSphere:public U4DParticleEmitter {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleEmitterSphere();
        
        /**
         @brief class destructor
         */
        ~U4DParticleEmitterSphere();
        
        /**
         @brief computes the velocity of the particle
         
         @param uParticle pointer to the particle object
         */
        void computeVelocity(U4DParticle *uParticle);
        
    };
    
}
#endif /* U4DParticleEmitterSphere_hpp */
