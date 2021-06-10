//
//  U4DDragForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DDragForceGenerator__
#define __UntoldEngine__U4DDragForceGenerator__

#include <iostream>
#include "U4DBodyForceGenerator.h"

namespace U4DEngine {
    
/**
 @ingroup physicsengine
 @brief The U4DGravityForceGenerator class is in charge of updating gravitational forces acting on a 3D entity
 */
class U4DDragForceGenerator:public U4DBodyForceGenerator{
  
    private:
        
    public:

    /**
     @brief Constructor for the class
     */
    U4DDragForceGenerator();
    
    /**
     @brief Destructor for the class
     */
    ~U4DDragForceGenerator();

    /**
     @brief Method which updates the force acting on the entity
     
     @param uAction Dynamic action
     @param dt     Time-step value
     */
    void updateForce(U4DDynamicAction *uAction, float dt);
        
    };

}

#endif /* defined(__UntoldEngine__U4DDragForceGenerator__) */
