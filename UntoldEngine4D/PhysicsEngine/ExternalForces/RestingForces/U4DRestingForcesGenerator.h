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
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    /**
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
         
         @param uModel 3D model entity
         @param dt     Time-step value
         */
        void updateForce(U4DDynamicModel *uModel, float dt);
        
        /**
         @brief Method which computes the resting normal force acting on the 3D entity
         
         @param uModel 3D model entity
         */
        void generateNormalForce(U4DDynamicModel *uModel);
        
        /**
         @brief Method which computes the torque force acting on the 3D entity
         
         @param uModel 3D model entity
         */
        void generateTorqueForce(U4DDynamicModel *uModel);
        
    };
}

#endif /* U4DRestingForces_hpp */
