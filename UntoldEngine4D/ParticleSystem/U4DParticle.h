//
//  U4DParticle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticle_hpp
#define U4DParticle_hpp

#include <stdio.h>
#include "U4DEntity.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticle class contains all the kinetic properties of a 3D particle
     */
    class U4DParticle:public U4DEntity {
        
    private:
        
        /**
         @brief Velocity of 3D particle
         */
        U4DVector3n velocity;
        
        /**
         @brief Acceleration of 3D particle
         */
        U4DVector3n acceleration;
        
        /**
         @brief Force of 3D particle
         */
        U4DVector3n force;
        
        /**
         @brief Mass of 3D particle
         */
        float mass;
        
        /**
         @brief particle's gravity
         */
        U4DVector3n gravity;
        
        /**
         @brief particle's radial acceleration
         */
        float particleRadialAcceleration;
        
        /**
         @brief particle's tangential acceleration
         */
        float particleTangentialAcceleration;
        
    public:
        
        /**
         @brief Constructor of class
         */
        U4DParticle();
        
        /**
         @brief Destructor of class
         */
        ~U4DParticle();
        
        /**
         @brief The particle Data contains information such as start-color, end-color, emit angle, life and speed of the 3D particle
         */
        U4DParticleData particleData;
        
        
        /**
         @brief sets the velocity of the 3D particle

         @param uVelocity velocity vector
         */
        void setVelocity(U4DVector3n &uVelocity);
        
        
        /**
         @brief adds the new force acting on the 3D particle on the current forces

         @param uForce force vector
         */
        void addForce(U4DVector3n& uForce);
        
        
        /**
         @brief clears all forces
         @details clears all forces currently acting on the particle. However, the only forces acting on the particle is gravity. No need to add other forces.
         */
        void clearForce();
        
        
        /**
         @brief current velocity of the 3D Particle

         @return velocity vector
         */
        U4DVector3n getVelocity();
        
        
        /**
         @brief initializes the 3D particle with a mass. Default mass is 1.0

         @param uMass mass value
         */
        void initMass(float uMass);
        
        
        /**
         @brief gets current mass of 3D particle

         @return mass value
         */
        float getMass();
        
        
        /**
         @brief gets the current sum of all forces acting on the 3D particle

         @return force vector
         */
        U4DVector3n getForce();
        
        /**
         @brief gets the gravity of the particle
         
         @return gravity vector
         */
        U4DVector3n getGravity();
        
        /**
         @brief sets the gravity of the particle
         @param uGravity gravity vector
         */
        void setGravity(U4DVector3n &uGravity);
        
        /**
         @brief sets the particle radial acceleration
         @param particle radial acceleration magnitude
         */
        void setParticleRadialAcceleration(float uParticleRadialAcceleration);

        /**
         @brief sets the particle tangential acceleration
         @param particle tangential acceleration magnitude
         */
        void setParticleTangentialAcceleration(float uParticleTangentialAcceleration);

        /**
         @brief gets the particle radial acceleration
         @return radial acceleration magnitude
         */
        float getParticleRadialAcceleration();
        
        /**
         @brief gets the particle tangent acceleration
         @return tangent acceleration magnitude
         */
        float getParticleTangentialAcceleration();
        
    };
    
}
#endif /* U4DParticle_hpp */
