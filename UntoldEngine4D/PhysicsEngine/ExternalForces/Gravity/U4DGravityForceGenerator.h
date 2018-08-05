//
//  GravityForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DGravityForceGenerator__
#define __UntoldEngine__U4DGravityForceGenerator__

#include <iostream>
#include "U4DEntityManager.h"
#include "U4DBodyForceGenerator.h"


namespace U4DEngine {
    
    class U4DVector3n;
    class U4DDynamicModel;
    
}

namespace U4DEngine {
    
    /**
     @brief The U4DGravityForceGenerator class is in charge of updating gravitational forces acting on a 3D entity
     */
    class U4DGravityForceGenerator:public U4DBodyForceGenerator{
      
    private:
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DGravityForceGenerator();
        
        /**
         @brief Destructor for the class
         */
        ~U4DGravityForceGenerator();
        
        /**
         @brief Method which updates the force acting on the entity
         
         @param uModel 3D model entity
         @param dt     Time-step value
         */
        void updateForce(U4DDynamicModel *uModel, float dt);

    };
        
}

#endif /* defined(__UntoldEngine__GravityForceGenerator__) */
