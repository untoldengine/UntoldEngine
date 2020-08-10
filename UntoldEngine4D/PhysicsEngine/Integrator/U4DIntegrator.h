//
//  U4DIntegrator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DIntegrator__
#define __UntoldEngine__U4DIntegrator__

#include <iostream>
#include "U4DDynamicModel.h"


namespace U4DEngine {

/**
 @ingroup physicsengine
 @brief The U4DIntegrator virtual class is in charge of integrating the equation of motion
 */
class U4DIntegrator{
  
public:
  
    /**
     @brief Method which integrates the equation of motion for the entity
     
     @param uModel 3D model entity
     @param dt     Time-step value
     */
    virtual void integrate(U4DEngine::U4DDynamicModel *uModel, float dt)=0;
    
    /**
     @brief Destructor for the class
     */
    virtual ~U4DIntegrator(){};
};

}

#endif /* defined(__UntoldEngine__U4DIntegrator__) */
