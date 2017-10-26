//
//  U4DParticle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticle_hpp
#define U4DParticle_hpp

#include <stdio.h>
#include "U4DEntity.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    class U4DParticle:public U4DEntity {
        
    private:
        
        /**
         @brief Velocity of 3D model
         */
        U4DVector3n velocity;
        
        /**
         @brief Acceleration of 3D model
         */
        U4DVector3n acceleration;
        
        /**
         @brief Force of 3D model
         */
        U4DVector3n force;
        
        /**
         @brief Mass of 3D model
         */
        float mass;
        
        
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
         @brief document this
         */
        U4DParticleData particleData;
        
        /**
         @brief document this
         
         */
        void setVelocity(U4DVector3n &uVelocity);
        
        void addForce(U4DVector3n& uForce);
        
        /**
         @brief Document this
         */
        void clearForce();
        
        U4DVector3n getVelocity();
        
        void initMass(float uMass);
        
        float getMass();
        
        U4DVector3n getForce();
    };
    
}
#endif /* U4DParticle_hpp */
