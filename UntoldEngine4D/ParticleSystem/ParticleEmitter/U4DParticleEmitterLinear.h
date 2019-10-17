//
//  U4DParticleEmitterLinear.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterLinear_hpp
#define U4DParticleEmitterLinear_hpp

#include <stdio.h>
#include "U4DParticleEmitter.h"
#include "U4DParticleSystem.h"
#include "U4DParticle.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleEmitterLinear class creates and allocates memory for the Linear Emitter
     */
    class U4DParticleEmitterLinear:public U4DParticleEmitter {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleEmitterLinear();
        
        /**
         @brief class destructor
         */
        ~U4DParticleEmitterLinear();
        
        
        /**
         @brief computes the velocity of the particle

         @param uParticle pointer to the particle object
         */
        void computeVelocity(U4DParticle *uParticle);
        
        /**
         @brief computes the radial acceleration of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        void computeRadialAcceleration(U4DParticle *uParticle);
        
        /**
         @brief computes the tangential acceleration of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        void computeTangentialAcceleration(U4DParticle *uParticle);
        
    };
    
}

#endif /* U4DParticleEmitterLinear_hpp */
