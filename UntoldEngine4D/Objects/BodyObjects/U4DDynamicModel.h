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

    float modelKineticEnergy; //kinetic energy of the model

    float timeOfImpact; //time that the model will impact with another object

    bool equilibrium;   //equilibrium state of the model upon collision
    
    bool kineticsEnabled;
    
    bool isAwake;
    
public:
    
    U4DDynamicModel();
    
    ~U4DDynamicModel();
    
    U4DDynamicModel(const U4DDynamicModel& value);
    
    U4DDynamicModel& operator=(const U4DDynamicModel& value);
    
    //Add operations
    
    void addForce(U4DVector3n& uForce);
    
    void addMoment(U4DVector3n& uMoment);
    
    //Behavior operations
    
    void enableKineticsBehavior();
    
    void pauseKineticsBehavior();
    
    void resumeKineticsBehavior();
    
    bool isKineticsBehaviorEnabled();
    
    //Clear operations
    
    void clearForce();
    
    void clearMoment();
    
    //Set operations
    
    void setVelocity(U4DVector3n &uVelocity);
    
    void setAngularVelocity(U4DVector3n& uAngularVelocity);
    
    void setTimeOfImpact(float uTimeOfImpact);
    
    void setAxisOfRotation(U4DVector3n &uAxisOfRotation);
    
    void setAwake(bool uValue);
    
     void setEquilibrium(bool uValue);
    
    //Compute operations
    
    void computeModelKineticEnergy(float dt); //Determines the kinetic motion of the model
    
    //Reset operations
    void resetTimeOfImpact();
    
    //Get operations
    
    U4DVector3n getForce();
    
    U4DVector3n getMoment();
    
    U4DVector3n getVelocity() const;
    
    U4DVector3n getAngularVelocity();
    
    bool getAwake();
    
    float getModelKineticEnergy();
    
    float getTimeOfImpact();
    
    U4DVector3n getAxisOfRotation();
    
    bool getEquilibrium();
    
};

}

#endif /* defined(__UntoldEngine__U4DDynamicModel__) */
