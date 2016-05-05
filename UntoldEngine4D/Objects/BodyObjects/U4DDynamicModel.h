//
//  U4DDynamicModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DDynamicModel__
#define __UntoldEngine__U4DDynamicModel__

#include <iostream>
#include <vector>
#include "U4DStaticModel.h"
#include "U4DVector3n.h"
#include "U4DPlane.h"

namespace U4DEngine {

class U4DBodyForceGenerator;

}

namespace U4DEngine {
/**
 *  Class in charge of all movable objects in the game such as characters, bullets, etc
 */
class U4DDynamicModel:public U4DStaticModel{
    
private:
    
protected:
    
    U4DVector3n velocity;
    
    U4DVector3n acceleration;

    U4DVector3n force;

    U4DVector3n angularVelocity;
 
    U4DVector3n moment;
    
    U4DVector3n axisOfRotation; //axis of rotation for the model.

    float energyMotion; //kinetic energy of the model

    float timeOfImpact; //time that the model will impact with another object

    bool equilibrium;   //equilibrium state of the model upon collision
    
    bool affectedByPhysics;
    
    bool isAwake;
    
public:
    
    U4DDynamicModel();
    
    ~U4DDynamicModel();
    
    U4DDynamicModel(const U4DDynamicModel& value);
    
    U4DDynamicModel& operator=(const U4DDynamicModel& value);
    
    void clearForce();
    
    void addForce(U4DVector3n& uForce);
    
    U4DVector3n getForce();
    
    U4DVector3n getMoment();
    
    void addMoment(U4DVector3n& uMoment);
    
    void clearMoment();

    U4DVector3n getVelocity() const;
    
    void setVelocity(U4DVector3n &uVelocity);
    
    U4DVector3n getAngularVelocity();
    
    void setAngularVelocity(U4DVector3n& uAngularVelocity);
    
    void setAwake(bool uValue);
    
    bool getAwake();
    
    void determineEnergyMotion(float dt); //Determines the kinetic motion of the model
    
    float getEnergyMotion();
    
    void determineAwakeCondition(); //Determines if the model should go to sleep or stay awake
    
    void applyPhysics(bool uValue);
    
    bool isPhysicsApplied();
    
    void setTimeOfImpact(float uTimeOfImpact);
    
    float getTimeOfImpact();
    
    void setAxisOfRotation(U4DVector3n &uAxisOfRotation);
    
    U4DVector3n getAxisOfRotation();
    
    void setEquilibrium(bool uValue);
    
    bool getEquilibrium();
    
    void resetTimeOfImpact();
    
};

}

#endif /* defined(__UntoldEngine__U4DDynamicModel__) */
