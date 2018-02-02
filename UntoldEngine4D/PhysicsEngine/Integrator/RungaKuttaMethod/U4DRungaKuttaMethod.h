//
//  U4DRungaKuttaMethod.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DRungaKuttaMethod__
#define __UntoldEngine__U4DRungaKuttaMethod__

#include <iostream>
#include "U4DIntegrator.h"


namespace U4DEngine {

/**
 @brief The U4DRungaKuttaMethod class is in charge of integrating the equation of motion
 */
class U4DRungaKuttaMethod:public U4DIntegrator{
    
public:

    /**
     @brief Constructor for the class
     */
    U4DRungaKuttaMethod();
    
    /**
     @brief Destructor for the class
     */
    ~U4DRungaKuttaMethod();
    
    /**
     @brief Method which integrates the equation of motion for the entity
     
     @param uModel 3D model entity
     @param dt     Time-step value
     */
    void integrate(U4DDynamicModel *uModel, float dt);
    
    /**
     @brief Method used to calculate the linear velocity of the entity
     
     @param uModel              3D model entity
     @param uLinearAcceleration 3D model Linear Acceleration
     @param dt                  time-step value
     @param uVnew               3D model new velocity
     @param uSnew               3D model new position
     */
    void evaluateLinearAspect(U4DDynamicModel *uModel,U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew);
    
    /**
     @brief Method used to calculate the angular velocity of the entity
     
     @param uModel               3D model entity
     @param uAngularAcceleration 3D model angular acceleration
     @param dt                   Time-step value
     @param uAngularVelocityNew  3D model new angular velocity
     @param uOrientationNew      3D mdoel new orientation
     */
    void evaluateAngularAspect(U4DDynamicModel *uModel,U4DVector3n &uAngularAcceleration,float dt,U4DVector3n &uAngularVelocityNew,U4DQuaternion &uOrientationNew);
};

}

#endif /* defined(__UntoldEngine__U4DRungaKuttaMethod__) */
