//
//  U4DRestingForces.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRestingForcesGenerator_hpp
#define U4DRestingForcesGenerator_hpp

#include <stdio.h>
#include "U4DBodyForceGenerator.h"
#include "U4DVector3n.h"
#include "U4DDynamicAction.h"

namespace U4DEngine {
    
    /**
     @ingroup physicsengine
     @brief The U4DGravityForceGenerator class is in charge of updating gravitational forces acting on a 3D entity
     */
    class U4DRestingForcesGenerator:public U4DBodyForceGenerator{
        
    private:
        
    public:
       
        /**
         @brief Constructor for the class
         */
        U4DRestingForcesGenerator();
        
        /**
         @brief Destructor for the class
         */
        ~U4DRestingForcesGenerator();
        
        
        /**
         @brief Method which updates the force acting on the entity
         
         @param uAction Dynamic action
         @param dt     Time-step value
         */
        void updateForce(U4DDynamicAction *uAction, float dt);
        
        /**
         @brief Method which computes the resting normal force acting on the 3D entity
         
         @param uAction Dynamic action
         */
        void generateNormalForce(U4DDynamicAction *uAction);
        
        /**
         @brief Method which computes the torque force acting on the 3D entity
         
         @param uAction Dynamic action
         */
        void generateTorqueForce(U4DDynamicAction *uAction);
        
    };
}

#endif /* U4DRestingForces_hpp */
