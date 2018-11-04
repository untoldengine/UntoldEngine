//
//  U4DParticlePhysics.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/22/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticlePhysics_hpp
#define U4DParticlePhysics_hpp

#include <stdio.h>
#include "U4DVector3n.h"

namespace U4DEngine {
    
    class U4DParticle;
    
}

namespace U4DEngine {

    /**
     @ingroup particlesystem
     @brief The U4DParticlePhysics class is in charge of simulating gravity forces on 3D particles
     */
    class U4DParticlePhysics {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticlePhysics();
        
        /**
         @brief class destructor
         */
        ~U4DParticlePhysics();
        
        
        /**
         @brief updates the forces affecting the 3D particle.
         @details the only forces affecting a 3D particle is gravitational force

         @param uParticle pointer to particle
         @param uGravity reference to gravity
         @param dt time-step
         */
        void updateForce(U4DParticle *uParticle, U4DVector3n &uGravity, float dt);
        
        
        /**
         @brief Integrates the equation of motion
         @details Computes the final velocity and position for the 3D particle. Note, only linear velocity is computed.

         @param uParticle pointer to 3D particle
         @param dt time-step
         */
        void integrate(U4DParticle *uParticle, float dt);
        
        
        /**
         @brief evaluates the final velocity and position of the 3D particle. Note, only linear velocity is computed.

         @param uModel pointer to the 3D particle
         @param uLinearAcceleration linear acceleration
         @param dt time-step
         @param uVnew reference to new velocity
         @param uSnew reference to new positon
         */
        void evaluateLinearAspect(U4DParticle *uModel, U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew);
        
    };
    
}


#endif /* U4DParticlePhysics_hpp */
